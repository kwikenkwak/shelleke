#!/usr/bin/env python3
"""Extract the three paper variants' icon sets into a single QML JS library.

  A (hairline)   design/paper-a-hairline/widgets.html    <symbol id="i-NAME" viewBox="0 0 16 16">
  B (ledger)     design/paper-b-ledger/widgets.html      <symbol id="i-NAME" viewBox="0 0 16 16">
  C (broadsheet) design/paper-c-broadsheet/tokens.html   <div class="icc"><svg viewBox="0 0 20 20">…<div class="nm">NAME</div>

Every primitive (path / rect / circle / ellipse) is converted to an SVG path `d`
string so PaperIcon only ever has to feed PathSvg. Parts are tagged filled or
stroked.
"""
import re, json, os, sys
from collections import OrderedDict

DESIGN = "/home/willem/.config/quickshell/ii/design"
OUT = "/home/willem/.config/quickshell/ii/modules/paper/common/paper_icons_data.js"


def num(s, default=0.0):
    if s is None:
        return default
    return float(s)


def fmt(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return s if s else "0"


def attrs(tag):
    return dict(re.findall(r'([a-zA-Z-]+)\s*=\s*"([^"]*)"', tag))


def rect_to_path(a):
    x, y = num(a.get("x")), num(a.get("y"))
    w, h = num(a.get("width")), num(a.get("height"))
    rx = num(a.get("rx"), 0.0)
    ry = num(a.get("ry"), rx)
    if rx <= 0 or ry <= 0:
        return "M%s %sH%sV%sH%sZ" % (fmt(x), fmt(y), fmt(x + w), fmt(y + h), fmt(x))
    rx = min(rx, w / 2.0)
    ry = min(ry, h / 2.0)
    return (
        "M%s %s" % (fmt(x + rx), fmt(y))
        + "H%s" % fmt(x + w - rx)
        + "A%s %s 0 0 1 %s %s" % (fmt(rx), fmt(ry), fmt(x + w), fmt(y + ry))
        + "V%s" % fmt(y + h - ry)
        + "A%s %s 0 0 1 %s %s" % (fmt(rx), fmt(ry), fmt(x + w - rx), fmt(y + h))
        + "H%s" % fmt(x + rx)
        + "A%s %s 0 0 1 %s %s" % (fmt(rx), fmt(ry), fmt(x), fmt(y + h - ry))
        + "V%s" % fmt(y + ry)
        + "A%s %s 0 0 1 %s %s" % (fmt(rx), fmt(ry), fmt(x + rx), fmt(y))
        + "Z"
    )


def ellipse_to_path(cx, cy, rx, ry):
    return (
        "M%s %s" % (fmt(cx - rx), fmt(cy))
        + "A%s %s 0 0 1 %s %s" % (fmt(rx), fmt(ry), fmt(cx + rx), fmt(cy))
        + "A%s %s 0 0 1 %s %s" % (fmt(rx), fmt(ry), fmt(cx - rx), fmt(cy))
        + "Z"
    )


def parse_body(body, default_filled=False):
    """body: inner markup of a <symbol>/<svg>. -> list of (d, filled)"""
    parts = []
    for tag in re.findall(r"<(?:path|rect|circle|ellipse)\b[^>]*/?>", body):
        a = attrs(tag)
        name = re.match(r"<([a-z]+)", tag).group(1)
        fill = a.get("fill")
        stroke = a.get("stroke")
        # An element is a solid mark when it explicitly paints a fill.
        filled = default_filled
        if fill is not None:
            filled = fill.lower() not in ("none", "transparent")
        if stroke is not None and stroke.lower() == "none" and fill is None:
            filled = True
        if name == "path":
            d = a.get("d", "")
        elif name == "rect":
            d = rect_to_path(a)
        elif name == "circle":
            r = num(a.get("r"))
            d = ellipse_to_path(num(a.get("cx")), num(a.get("cy")), r, r)
        else:  # ellipse
            d = ellipse_to_path(num(a.get("cx")), num(a.get("cy")),
                                num(a.get("rx")), num(a.get("ry")))
        if d:
            parts.append((d.strip(), filled))
    return parts


def parse_symbols(path):
    h = open(path, encoding="utf-8").read()
    out = OrderedDict()
    for m in re.finditer(r"<symbol\b([^>]*)>(.*?)</symbol>", h, re.S):
        a = attrs("<symbol " + m.group(1) + ">")
        ident = a.get("id", "")
        if not ident.startswith("i-"):
            continue
        vb = a.get("viewBox", "0 0 16 16").split()
        size = float(vb[2])
        out[ident[2:]] = (size, parse_body(m.group(2)))
    return out


def parse_c(path):
    h = open(path, encoding="utf-8").read()
    out = OrderedDict()
    start = h.find('class="icg"')
    if start < 0:
        return out
    seg = h[start:]
    for m in re.finditer(
        r'<div class="icc">\s*<svg[^>]*viewBox="([^"]*)"[^>]*>(.*?)</svg>\s*<div class="nm">([^<]*)</div>',
        seg, re.S,
    ):
        vb = m.group(1).split()
        size = float(vb[2])
        out[m.group(3).strip()] = (size, parse_body(m.group(2)))
    return out


# ---- canonical naming -------------------------------------------------------
# The three variants name the same concepts differently. Everything is
# normalised to lowerCamelCase; `ALIASES` below is emitted into the JS so
# surface code can use any of the spelling variants it finds in a SPEC.
CANON = {
    # A (kebab) -> canonical
    "chev-d": "chevD", "chev-u": "chevU", "chev-l": "chevL", "chev-r": "chevR",
    "arrow-r": "arrowR", "arrow-l": "arrowL", "arrow-u": "arrowU", "arrow-d": "arrowD",
    "speaker-x": "speakerOff", "mic-off": "micOff", "wifi-off": "wifiOff",
    "bell-off": "bellOff", "bat-chg": "batCharging", "fullscr": "fullscreen",
    "bt": "bluetooth",
    # B
    "speakeroff": "speakerOff", "micoff": "micOff", "wifioff": "wifiOff",
    "cloud": "cloud", "lines": "lines", "grip": "grip", "apps": "apps",
    # C
    "monitor": "display", "expand": "fullscreen",
}


def canon(n):
    return CANON.get(n, n)


def main():
    sets = OrderedDict()
    sets["hairline"] = parse_symbols(os.path.join(DESIGN, "paper-a-hairline/widgets.html"))
    sets["ledger"] = parse_symbols(os.path.join(DESIGN, "paper-b-ledger/widgets.html"))
    sets["broadsheet"] = parse_c(os.path.join(DESIGN, "paper-c-broadsheet/tokens.html"))

    canonical = OrderedDict()
    raw_names = OrderedDict()
    for variant, glyphs in sets.items():
        canonical[variant] = OrderedDict()
        for name, (size, parts) in glyphs.items():
            c = canon(name)
            raw_names.setdefault(c, set()).add(name)
            canonical[variant][c] = {
                "vb": size,
                "p": [{"d": d, "f": 1} if f else {"d": d} for d, f in parts],
            }

    allnames = sorted({n for v in canonical.values() for n in v})
    # coverage report
    print("total canonical glyphs:", len(allnames))
    for v in canonical:
        missing = [n for n in allnames if n not in canonical[v]]
        print("  %-11s %3d glyphs, missing %2d: %s" % (v, len(canonical[v]), len(missing), " ".join(missing)))

    aliases = {}
    for c, raws in raw_names.items():
        for r in raws:
            if r != c:
                aliases[r] = c
    # a few extra convenience aliases used by the specs' prose
    aliases.update({
        "bt": "bluetooth", "chevDown": "chevD", "chevUp": "chevU",
        "chevLeft": "chevL", "chevRight": "chevR", "fullscr": "fullscreen",
        "monitor": "display", "expand": "fullscreen",
    })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(HEADER)
        f.write("var aliases = %s;\n\n" % json.dumps(dict(sorted(aliases.items())), indent=4))
        f.write("var names = %s;\n\n" % json.dumps(allnames, indent=4))
        for v in canonical:
            f.write("var %s = {\n" % v)
            for n in sorted(canonical[v]):
                g = canonical[v][n]
                f.write('    "%s": { "vb": %s, "p": [%s] },\n' % (
                    n, fmt(g["vb"]),
                    ", ".join(
                        ('{"d":"%s","f":1}' % p["d"]) if p.get("f") else ('{"d":"%s"}' % p["d"])
                        for p in g["p"]
                    ),
                ))
            f.write("};\n\n")
        f.write(FOOTER)
    print("wrote", OUT)


HEADER = '''.pragma library
/*
 * Icon path data for the "paper" panel family.
 *
 * Auto-generated by scripts/paper/extract_icons.py from the three design
 * previews' inline SVG:
 *   hairline    design/paper-a-hairline/widgets.html   (16-unit grid, 76 glyphs)
 *   ledger      design/paper-b-ledger/widgets.html     (16-unit grid, 65 glyphs)
 *   broadsheet  design/paper-c-broadsheet/tokens.html  (20-unit grid, 64 glyphs)
 *
 * Every variant keeps its OWN drawing of every glyph — the three sets really do
 * differ (B's `wifi` has a filled dot, C's `battery` is a wider 20-grid body,
 * A's `gear` is a finer 16-grid cog), and preserving them is what makes a live
 * variant switch look like a different set of pens rather than a recolour.
 *
 * Shape of the data:
 *   <variant>[name] = { vb: <viewBox edge, 16 or 20>,
 *                       p: [ { d: "<svg path data>", f: 1? }, … ] }
 *   `f: 1` marks a SOLID part (a Wi-Fi dot, a transport triangle); parts
 *   without it are stroked with the theme's icon stroke.
 *
 * Names are lowerCamelCase and unified across the three variants; `aliases`
 * maps every spelling that appears in the SPECs (kebab-case A names, C's
 * `monitor`/`expand`, …) onto the canonical name. Use `resolve(variant, name)`.
 */

'''

FOOTER = '''var sets = {
    "hairline": hairline,
    "ledger": ledger,
    "broadsheet": broadsheet
};

// Order to fall back through when a variant does not draw a glyph. Falling back
// is deliberate: a surface may ask for `laptop` (drawn only by A) in any variant
// and still get a glyph in the right visual key rather than an empty box.
var fallbackOrder = {
    "hairline": ["hairline", "ledger", "broadsheet"],
    "ledger": ["ledger", "hairline", "broadsheet"],
    "broadsheet": ["broadsheet", "ledger", "hairline"]
};

/** Canonicalise a glyph name (accepts any variant's spelling). */
function canonical(name) {
    return aliases[name] !== undefined ? aliases[name] : name;
}

/**
 * Resolve a glyph for a variant, falling back to the other variants' drawings.
 * Returns null when no variant draws it.
 */
function resolve(variant, name) {
    var n = canonical(name);
    var order = fallbackOrder[variant] || fallbackOrder["hairline"];
    for (var i = 0; i < order.length; i++) {
        var g = sets[order[i]][n];
        if (g !== undefined)
            return g;
    }
    return null;
}

/** true when `name` is drawable in some variant. */
function has(name) {
    return resolve("hairline", name) !== null;
}

/**
 * What PaperIcon actually consumes: one concatenated stroked path and one
 * concatenated filled path, plus the viewBox edge they are drawn on.
 * Concatenation is safe — SVG subpaths just append, and every part of a glyph
 * shares the same pen. Returns { vb, stroke, fill }; empty strings draw nothing.
 */
function paths(variant, name) {
    var g = resolve(variant, name);
    if (g === null)
        return { vb: 16, stroke: "", fill: "" };
    var s = [], f = [];
    for (var i = 0; i < g.p.length; i++) {
        if (g.p[i].f)
            f.push(g.p[i].d);
        else
            s.push(g.p[i].d);
    }
    return { vb: g.vb, stroke: s.join(" "), fill: f.join(" ") };
}
'''


if __name__ == "__main__":
    main()
