#!/usr/bin/env python3
"""Build the paper family's backdrop plates from public-domain source scans.

A *plate* is the desktop's picture: one engraving, chart, map or woodblock,
reduced to nothing but ink density. The PNG holds black pixels and an alpha
channel — no paper of its own — so PaperBackground can lay it on the variant's
`paper` token and tint it with the variant's `ink` token. One asset therefore
serves hairline, ledger and broadsheet, light and dusk, and a live variant
switch re-tints it with no reload.

    scripts/paper/fetch_plates.py                 # fetch (cached) + rebuild all
    scripts/paper/fetch_plates.py --only hokusai-great-wave --sheet
    scripts/paper/fetch_plates.py --no-fetch      # rebuild from the cache only

Writes:
    assets/images/paper-plates/<slug>.png         the plates
    modules/paper/common/paper_plates_data.js     the catalog PaperPlates reads

Sources are Wikimedia Commons files that are public domain or CC0 — the
generator records each one's title, creator, licence and description URL in the
catalog, and refuses anything it cannot confirm as free.

The image work, in order:
  1. luminance → ink density, with the paper white point taken from a high
     percentile so foxed and yellowed scans still land on clean paper;
  2. crop to the drawing: the ink mass is box-blurred first, so a scan's hairline
     plate frame and its caption type melt away and only the picture survives;
  3. for `bleed` plates, a focus crop to screen aspect — the window of the plate
     carrying the most ink, which is reliably the composition and not a margin;
  4. normalise ink coverage to a target mean BY GAMMA, so a delicate Ortelius
     map and a black Piranesi aquatint hang at the same weight while both keep
     their solid darks — a linear scale would leave a flat grey wash;
  5. downscale, quantise alpha to 16 levels and write LA PNG. At the 7–13 %
     opacity these are drawn at, 16 levels are indistinguishable from 256 and
     compress about three times smaller.
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from html import unescape

import numpy as np
from PIL import Image, ImageFilter

Image.MAX_IMAGE_PIXELS = None

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "images", "paper-plates")
OUT_JS = os.path.join(ROOT, "modules", "paper", "common", "paper_plates_data.js")
CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "quickshell", "paper-plates-src")

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "quickshell-ii paper-plates generator (personal desktop theme)"}
FREE = ("public domain", "pd", "cc0")

# Ink coverage every plate is normalised to. A motif covers roughly half the
# wall, so it needs a heavier plate than a bleed to carry the same weight in the
# room.
TARGET_INK = {"bleed": 0.115, "motif": 0.155}

# Screen aspect the `bleed` focus crop aims at. Between 16:9 and 21:9 — a plate
# cropped to 1.72 fills either without losing much to PreserveAspectCrop.
BLEED_ASPECT = 1.72

# ---------------------------------------------------------------- the catalog
#
# layout:  "bleed" fills the screen (landscape scenes, maps, charts)
#          "motif" is a print laid on the sheet at `scale` of screen height
# crop:    False keeps the whole scan — for one already trimmed to the picture,
#          or whose composition the margin trimmer reads wrong
# align:   motif horizontal placement — "center" | "left" | "right"
# weight:  hand nudge on opacity, for a plate that wants more or less presence
#          than the normaliser gives it. The catalog's `weight` is this times the
#          automatic balance (see main()); leave it out unless you have looked
# smooth:  Gaussian radius applied before quantising; tonal aquatints and
#          half-tone scans carry sensor noise that costs a lot of PNG bytes
PLATES = [
    # -- woodblock ---------------------------------------------------------
    ("hokusai-great-wave",
     "File:Katsushika Hokusai - Thirty-Six Views of Mount Fuji- The Great Wave Off the Coast of Kanagawa - Google Art Project.jpg",
     dict(layout="bleed", smooth=0.5)),
    ("hokusai-tama-river",
     "File:冨嶽三十六景 武州玉川-Fuji—The Tama River, Musashi Province, from the series Thirty-six Views of Mount Fuji (Fugaku sanjūrokkei) MET DP140975.jpg",
     dict(layout="bleed", smooth=0.5)),
    ("hokusai-hodogaya",
     "File:冨嶽三十六景 東海道保土ケ谷-Hodogaya on the Tōkaidō (Tōkaidō Hodogaya), from the series Thirty-six Views of Mount Fuji (Fugaku sanjūrokkei) MET DP141025.jpg",
     dict(layout="bleed", smooth=0.5)),
    # -- the heavens -------------------------------------------------------
    ("cellarius-christian-constellations",
     "File:1660 celestial chart representing the constellations according to Christian symbolism.jpg",
     dict(layout="bleed", smooth=0.6)),
    # -- maps --------------------------------------------------------------
    ("ortelius-tartary",
     "File:Tartary from Theatrum orbis terrarum, by Abraham Ortelius.jpg",
     dict(layout="bleed")),
    ("ortelius-flandria",
     "File:Theatrum orbis terrarum - Flandria.jpg",
     dict(layout="bleed")),
    # -- architecture and machines -----------------------------------------
    ("piranesi-sawhorse",
     "File:The Sawhorse, from Carceri d'invenzione (Imaginary Prisons) MET DP828186.jpg",
     dict(layout="bleed", smooth=0.6)),
    ("encyclopedie-plate-2-087",
     "File:Encyclopedie volume 2-087.png",
     dict(layout="motif", scale=0.94)),
    ("encyclopedie-plate-4-295",
     "File:Encyclopedie volume 4-295.png",
     dict(layout="motif", scale=0.92)),
    ("encyclopedie-plate-5-241",
     "File:Encyclopedie volume 5-241.png",
     dict(layout="motif", scale=0.92)),
    # -- Haeckel, Kunstformen der Natur ------------------------------------
    ("haeckel-discomedusae",
     "File:Haeckel Discomedusae 8.jpg",
     dict(layout="motif", scale=0.94)),
    ("haeckel-siphonophorae",
     "File:Haeckel Siphonophorae.jpg",
     dict(layout="motif", scale=0.94)),
    ("haeckel-echinidea",
     "File:Echinidea. - Igelsterne LCCN2015648942.jpg",
     dict(layout="motif", scale=0.94)),
    ("haeckel-acephala",
     "File:Acephala. - Muscheln LCCN2014645038.jpg",
     dict(layout="motif", scale=0.94)),
    ("haeckel-orchidae",
     "File:Haeckel Orchidae.jpg",
     dict(layout="motif", scale=0.94)),
    # -- birds, roses and insects ------------------------------------------
    ("audubon-carolina-parrot",
     "File:26 Carolina Parrot.jpg",
     dict(layout="motif", scale=0.92)),
    ("redoute-rosa-muscosa",
     "File:RosaMuscosa Alba-Rosier-mousseux-a-fleurs-blanches.jpg",
     dict(layout="motif", scale=0.9)),
    ("redoute-rosa-centifolia",
     "File:Rosa centifolia Burgundiaca.jpg",
     dict(layout="motif", scale=0.9)),
    ("merian-surinam-plate-1",
     "File:Metamorphosis insectorum surinamensium (Pl. 1) BHL41398750.jpg",
     dict(layout="motif", scale=0.92)),
    ("merian-surinam-plate-7",
     "File:Metamorphosis insectorum surinamensium (Pl. 7) BHL41398732.jpg",
     dict(layout="motif", scale=0.92)),
]


# ------------------------------------------------------------------ fetching

def api(params):
    url = API + "?" + urllib.parse.urlencode(dict(params, format="json", action="query"))
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers=UA)
            return json.load(urllib.request.urlopen(req, timeout=60))
        except Exception:
            if attempt == 3:
                raise
            time.sleep(4 * (attempt + 1))


def download(url, dest):
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers=UA)
            data = urllib.request.urlopen(req, timeout=240).read()
            break
        except Exception:
            if attempt == 4:
                raise
            # Commons throttles hard when it has to render a 12000 px scan down.
            time.sleep(8 * (attempt + 1))
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def plain(value, cap=160):
    """extmetadata values arrive as HTML fragments with Wikidata blobs stapled on.

    A raw ObjectName reads
      "Japanese: 『神奈川沖浪裏』<br>The Great Wave…title QS:P1476,ja:…label QS:…"
    so: tags to spaces, entities decoded, and everything from the first Wikidata
    statement marker onwards thrown away.
    """
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = unescape(text)
    text = re.split(r"\b(?:title|label|date|caption) QS:", text)[0]
    text = re.sub(r"\s+", " ", text).strip(" ;,.-")
    return text if len(text) <= cap else text[:cap].rstrip() + "…"


def source_of(slug, title, width=2600, fetch=True):
    """Cached source scan + its provenance. Returns (path, credit) or None."""
    scan = os.path.join(CACHE, slug + ".img")
    meta = os.path.join(CACHE, slug + ".json")
    if os.path.exists(scan) and os.path.exists(meta):
        with open(meta) as f:
            return scan, json.load(f)
    if not fetch:
        print(f"  {slug}: not cached, skipped (--no-fetch)")
        return None

    page = list(api({"titles": title, "prop": "imageinfo",
                     "iiprop": "url|size|extmetadata",
                     "iiurlwidth": str(width)})["query"]["pages"].values())[0]
    if "missing" in page:
        print(f"  {slug}: NOT ON COMMONS — {title}")
        return None
    info = page["imageinfo"][0]
    ext = info.get("extmetadata", {})
    licence = plain(ext.get("LicenseShortName", {}).get("value", ""))
    if not any(tag in licence.lower() for tag in FREE):
        print(f"  {slug}: refused, licence is {licence!r}")
        return None

    credit = {
        "title": plain(ext.get("ObjectName", {}).get("value", "")) or page["title"][5:],
        "artist": plain(ext.get("Artist", {}).get("value", "")),
        "date": plain(ext.get("DateTimeOriginal", {}).get("value", "")),
        "licence": licence,
        "source": info.get("descriptionurl", ""),
    }
    with open(meta, "w") as f:
        json.dump(credit, f, indent=1, ensure_ascii=False)
    if os.path.exists(scan):
        # Scan already downloaded; this pass only refreshed the provenance.
        return scan, credit
    nbytes = download(info.get("thumburl") or info["url"], scan)
    print(f"  {slug}: {info['width']}x{info['height']} → {nbytes // 1024} KB [{licence}]")
    time.sleep(4)
    return scan, credit


# ------------------------------------------------------------------ ink plate

def ink_density(img, white_pct=97.0, black_pct=1.0, gamma=1.35, floor=0.10, inset=0.02):
    """Luminance → ink, 0 = paper, 1 = solid. `floor` is the soft knee that
    turns a yellowed page and JPEG mush into true paper."""
    g = np.asarray(img.convert("L"), dtype=np.float32)
    if inset > 0:
        dy, dx = int(g.shape[0] * inset), int(g.shape[1] * inset)
        g = g[dy:g.shape[0] - dy, dx:g.shape[1] - dx]
    white, black = np.percentile(g, white_pct), np.percentile(g, black_pct)
    if white - black < 8:  # a flat scan: fall back to its real range
        white, black = float(g.max()), float(g.min())
    a = np.clip((white - g) / max(white - black, 1e-3), 0.0, 1.0) ** gamma
    return np.clip((a - floor) / (1.0 - floor), 0.0, 1.0)


def ink_mass(a, frac=0.02):
    """Ink blurred until hairlines and caption type stop counting as content."""
    radius = max(3, int(min(a.shape) * frac))
    im = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(radius))
    return np.asarray(im, dtype=np.float32) / 255.0


def ink_extent(profile, rel=0.10, floor=0.015, least=0.40):
    """The outermost lines of `profile` that still carry drawing.

    Relative to the profile's own peak, not "any ink at all": a book scan keeps a
    printed frame around the plate and a caption under it, and both survive an
    any-ink test — which then crops to the PAGE and leaves the picture as a stamp
    in a white field. Blurred at `ink_mass`'s radius a hairline frame carries
    almost no mass, so a threshold at a tenth of the peak drops it and keeps even
    the sparse extremities of a drawing.

    Guarded by `least`: if what survives spans less than that fraction of the
    axis the profile is telling us something we do not understand (a plate that
    is one dense blot on an otherwise busy page), and we keep everything.
    """
    top = float(profile.max())
    if top <= 1e-4:
        return 0, len(profile)
    keep = np.where(profile > max(floor, rel * top))[0]
    if len(keep) < least * len(profile):
        return 0, len(profile)
    return int(keep[0]), int(keep[-1]) + 1


def crop_to_drawing(a, pad=0.012):
    """Trim the page down to the picture on it."""
    mass = ink_mass(a, 0.035)
    y0, y1 = ink_extent(mass.mean(axis=1))
    x0, x1 = ink_extent(mass.mean(axis=0))
    py, px = int(a.shape[0] * pad), int(a.shape[1] * pad)
    return a[max(0, y0 - py):min(a.shape[0], y1 + py),
             max(0, x0 - px):min(a.shape[1], x1 + px)]


def focus_crop(a, aspect=BLEED_ASPECT, steps=48):
    """The window of `aspect` carrying the most ink — i.e. the composition."""
    h, w = a.shape
    if w / h >= aspect:
        cw, ch = int(round(h * aspect)), h
    else:
        cw, ch = w, int(round(w / aspect))
    if cw >= w and ch >= h:
        return a
    mass = ink_mass(a, 0.03)
    x = y = 0
    if cw < w:
        stride = max(1, (w - cw) // steps)
        x = max(range(0, w - cw + 1, stride), key=lambda i: mass[:, i:i + cw].mean())
    if ch < h:
        stride = max(1, (h - ch) // steps)
        y = max(range(0, h - ch + 1, stride), key=lambda i: mass[i:i + ch, :].mean())
    return a[y:y + ch, x:x + cw]


def normalise(a, target, lo=0.30, hi=9.0):
    """One weight for the whole wall — by GAMMA, never by a linear scale.

    Every plate has to hang at the same visual weight, but a plate whose ink is
    simply multiplied down loses its solid blacks along with its mid-tones, and
    what is left is a flat grey wash with no picture in it. `a ** g` pins 1 → 1:
    the deepest bite of the engraving stays solid and only the mid-tones thin
    out, which is exactly what an engraving looks like printed lighter.

    Returns the curved plate and the exponent used, which is worth printing —
    an exponent at either clamp means the plate is a long way off the rest. The
    range is wide on purpose: a tonal aquatint needs a hard exponent before its
    washes stop dominating, and what is left is the etched line, which is the
    part worth hanging.
    """
    mean = float(a.mean())
    if mean <= 1e-4:
        return a, 1.0
    # mean(a ** g) falls monotonically in g, so bisect for the exponent that
    # lands on the target. Twenty rounds gets well inside a quantisation step.
    lo_g, hi_g = lo, hi
    if float((a ** hi_g).mean()) > target:
        g = hi_g
    elif float((a ** lo_g).mean()) < target:
        g = lo_g
    else:
        for _ in range(20):
            g = 0.5 * (lo_g + hi_g)
            if float((a ** g).mean()) > target:
                lo_g = g
            else:
                hi_g = g
        g = 0.5 * (lo_g + hi_g)
    return np.clip(a ** g, 0.0, 1.0), g


def build(src, dest, layout="bleed", scale=0.92, align="center", weight=1.0,
          smooth=0.0, crop=True, max_px=1600, levels=16):
    a = ink_density(Image.open(src))
    if crop:
        a = crop_to_drawing(a)
    if layout == "bleed":
        a = focus_crop(a)
    target = TARGET_INK["motif" if layout == "motif" else "bleed"]
    a, gamma = normalise(a, target)

    h, w = a.shape
    factor = min(max_px / w, max_px / h, 1.0)
    alpha = Image.fromarray((a * 255).astype(np.uint8))
    if factor < 1.0:
        alpha = alpha.resize((round(w * factor), round(h * factor)), Image.LANCZOS)
    if smooth:
        alpha = alpha.filter(ImageFilter.GaussianBlur(smooth))
    if levels < 256:
        step = 256 / levels
        q = np.round(np.asarray(alpha, dtype=np.float32) / step) * step
        alpha = Image.fromarray(np.clip(q, 0, 255).astype(np.uint8))

    ink = Image.new("L", alpha.size, 0)
    Image.merge("LA", (ink, alpha)).save(dest, optimize=True, compress_level=9)
    return dict(width=alpha.size[0], height=alpha.size[1], gamma=round(gamma, 3),
                bytes=os.path.getsize(dest),
                mean=round(float(np.asarray(alpha).mean()) / 255, 4),
                target=target,
                solid=round(float((np.asarray(alpha) > 220).mean()), 4))


# -------------------------------------------------------------------- output

JS_HEADER = '''.pragma library
/*
 * Backdrop plate catalog for the "paper" panel family.
 *
 * Auto-generated by scripts/paper/fetch_plates.py — do not edit by hand; edit
 * the PLATES list in that script and re-run it.
 *
 * Every entry names a PNG in assets/images/paper-plates/ that carries ink
 * density in its alpha channel and nothing else. PaperBackground lays it on the
 * variant's `paper` and tints it with the variant's `ink`, so one asset serves
 * all three variants in both light and dusk, and re-tints live on a switch.
 *
 *   file    basename under assets/images/paper-plates/
 *   layout  "bleed" fills the screen | "motif" is a print laid on the sheet
 *   align   motif placement: "center" | "left" | "right"
 *   scale   motif height as a fraction of screen height
 *   weight  per-plate opacity multiplier, on top of the variant's base opacity
 *   aspect  width / height, so a surface can lay a plate out before it loads
 *   title / artist / date / licence / source — provenance, all public domain
 *
 * PaperPlates.qml is what surfaces should use; it picks the plate of the day
 * out of this list.
 */
'''


def write_js(entries):
    lines = [JS_HEADER, "var plates = [\n"]
    for e in entries:
        lines.append("    {\n")
        for key in ("file", "layout", "align", "scale", "weight", "aspect",
                    "title", "artist", "date", "licence", "source"):
            value = e[key]
            if isinstance(value, str):
                value = json.dumps(value, ensure_ascii=False)
            lines.append(f"        {key}: {value},\n")
        lines[-1] = lines[-1].rstrip(",\n") + "\n"
        lines.append("    },\n")
    lines[-1] = "    }\n"
    lines.append("];\n\n")
    lines.append("/// The number of plates in the collection.\n")
    lines.append("function count() {\n    return plates.length;\n}\n\n")
    lines.append('''/**
 * The plate for a given day. `day` is a whole number of days — any monotonic
 * day counter works; PaperPlates feeds it days-since-epoch, so the picture
 * changes at local midnight and every screen agrees on it.
 *
 * The stride is a step of 7 through the list rather than a hash: with 7 and a
 * collection whose size is not a multiple of it, consecutive days land far
 * apart in the list (so yesterday's Haeckel is not followed by another Haeckel)
 * while every plate still comes up exactly once per full cycle.
 */
function forDay(day) {
    if (plates.length === 0)
        return null;
    var stride = (plates.length % 7 === 0) ? 5 : 7;
    return plates[Math.abs(Math.floor(day) * stride) % plates.length];
}

/// Look a plate up by its `file` name, for a pinned pick. Null when unknown.
function byFile(file) {
    for (var i = 0; i < plates.length; i++) {
        if (plates[i].file === file)
            return plates[i];
    }
    return null;
}
''')
    with open(OUT_JS, "w") as f:
        f.write("".join(lines))


def contact_sheet(entries, path, plate_dir=OUT_DIR, tile_w=760):
    """A quick look at the collection as it will actually hang: light and dusk."""
    def rgb(h):
        h = h.lstrip("#")
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

    W, H = 1600, 900
    tiles = []
    for e in entries:
        alpha_src = Image.open(os.path.join(plate_dir, e["file"])).split()[-1]
        for paper, ink, base in (("#FAF8F3", "#1C1A17", 0.11), ("#1B1917", "#EDE7DA", 0.13)):
            if e["layout"] == "bleed":
                f = max(W / alpha_src.width, H / alpha_src.height)
                a = alpha_src.resize((round(alpha_src.width * f), round(alpha_src.height * f)),
                                     Image.LANCZOS)
                a = a.crop(((a.width - W) // 2, (a.height - H) // 2,
                            (a.width - W) // 2 + W, (a.height - H) // 2 + H))
            else:
                f = H * e["scale"] / alpha_src.height
                m = alpha_src.resize((round(alpha_src.width * f), round(alpha_src.height * f)),
                                     Image.LANCZOS)
                a = Image.new("L", (W, H), 0)
                x = {"center": (W - m.width) // 2, "left": int(W * 0.07),
                     "right": W - m.width - int(W * 0.07)}[e["align"]]
                a.paste(m, (x, (H - m.height) // 2))
            op = base * e["weight"]
            faded = Image.fromarray((np.asarray(a, dtype=np.float32) * op).astype(np.uint8))
            tile = Image.composite(Image.new("RGB", (W, H), rgb(ink)),
                                   Image.new("RGB", (W, H), rgb(paper)), faded)
            tiles.append(tile.resize((tile_w, round(H * tile_w / W)), Image.LANCZOS))

    cols, gap = 2, 6
    th = tiles[0].height
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tile_w + (cols + 1) * gap, rows * th + (rows + 1) * gap),
                      (70, 70, 70))
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet.paste(t, (gap + c * (tile_w + gap), gap + r * (th + gap)))
    sheet.save(path, quality=86)
    print(f"contact sheet → {path} ({sheet.size[0]}x{sheet.size[1]})")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--only", action="append", default=[], metavar="SLUG",
                    help="build just these plates (repeatable)")
    ap.add_argument("--no-fetch", action="store_true",
                    help="build from the download cache only")
    ap.add_argument("--out", default=OUT_DIR, help="plate output directory")
    ap.add_argument("--sheet", nargs="?", const="/tmp/paper-plates-sheet.jpg",
                    metavar="PATH", help="also render a contact sheet to review")
    ap.add_argument("--no-js", action="store_true", help="skip the catalog rewrite")
    args = ap.parse_args()

    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(args.out, exist_ok=True)
    wanted = [p for p in PLATES if not args.only or p[0] in args.only]
    if args.only and len(wanted) != len(set(args.only)):
        unknown = set(args.only) - {p[0] for p in wanted}
        sys.exit(f"unknown plate(s): {', '.join(sorted(unknown))}")

    print(f"source scans in {CACHE}")
    entries, total = [], 0
    for slug, title, opts in wanted:
        got = source_of(slug, title, fetch=not args.no_fetch)
        if not got:
            continue
        scan, credit = got
        dest = os.path.join(args.out, slug + ".png")
        stats = build(scan, dest, **opts)
        total += stats["bytes"]
        print(f"  {slug:34} {stats['width']}x{stats['height']:<5} "
              f"{stats['bytes'] // 1024:4} KB  γ {stats['gamma']:.2f}  ink {stats['mean']:.3f}  "
              f"solid {stats['solid']:.3f}")
        # A plate with genuinely solid blacks (a machine engraving's shadows)
        # cannot be curved down to the target without destroying the blacks that
        # make it a picture, so whatever coverage gamma could not take off is
        # taken off the opacity instead. Clamped: past these bounds the plate is
        # simply a different kind of thing and should be looked at by eye.
        balance = min(1.8, max(0.55, stats["target"] / max(stats["mean"], 1e-3)))
        entries.append(dict(
            file=slug + ".png",
            layout=opts.get("layout", "bleed"),
            align=opts.get("align", "center"),
            scale=round(opts.get("scale", 0.92), 3),
            weight=round(opts.get("weight", 1.0) * balance, 3),
            aspect=round(stats["width"] / stats["height"], 4),
            **credit))

    print(f"{len(entries)} plates, {total // 1024} KB total")
    if entries and not args.no_js and not args.only:
        write_js(entries)
        print(f"catalog → {OUT_JS}")
    elif args.only:
        print("catalog left alone (--only)")
    if args.sheet and entries:
        contact_sheet(entries, args.sheet, args.out)


if __name__ == "__main__":
    main()
