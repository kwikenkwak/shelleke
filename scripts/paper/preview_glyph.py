#!/usr/bin/env python3
"""Render paper glyphs at TRUE size, the way PaperIcon draws them.

A glyph that reads fine in an editor at 400 px can be a smudge — or a letter of
the alphabet — in a 15-17 px bar chip, and that is the only size that matters.
This rig draws candidates exactly as modules/paper/widgets/PaperIcon.qml does:
the 16- or 20-unit drawing scaled to the chip size, stroked at a CONSTANT
1.25 px apparent width (the theme's `icon.stroke`), round caps and joins, on the
dusk-paper ground. It is what settled the `earbuds` drawing; see the note above
MANUAL in extract_icons.py.

  ./preview_glyph.py                        # the family's audio glyphs, 8x
  ./preview_glyph.py battery wifi --size 15 # any glyphs from the data file
  ./preview_glyph.py --variant hairline

Output lands in /tmp/paper-glyphs/ as one montage plus a PNG per glyph.
"""
import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "../../modules/paper/common/paper_icons_data.js")
OUT = "/tmp/paper-glyphs"

# Dusk Paper, which is where a thin stroke is hardest to hold together.
BG, INK = "#221f1b", "#e6ded0"
STROKE = 1.25  # PaperTheme.icon.stroke — apparent pixels, at every size


def load_sets():
    """Pull the three `var <variant> = {...};` blocks out of the JS library."""
    src = open(DATA, encoding="utf-8").read()
    sets = {}
    for variant in ("hairline", "ledger", "broadsheet"):
        m = re.search(r"var %s = \{(.*?)\n\};" % variant, src, re.S)
        if not m:
            continue
        glyphs = {}
        for line in m.group(1).splitlines():
            lm = re.match(r'\s*"([A-Za-z0-9]+)": \{ "vb": (\d+), "p": (\[.*\]) \},\s*$', line)
            if lm:
                glyphs[lm.group(1)] = (int(lm.group(2)), json.loads(lm.group(3)))
        sets[variant] = glyphs
    return sets


def svg(parts, vb, size):
    """One glyph as an SVG string. `parts` is the data file's `p` list."""
    sw = STROKE * vb / float(size)
    body = "".join(
        '<path d="%s" fill="%s"/>' % (p["d"], INK) if p.get("f") else
        '<path d="%s" fill="none" stroke="%s" stroke-width="%.4f"'
        ' stroke-linecap="round" stroke-linejoin="round"/>' % (p["d"], INK, sw)
        for p in parts)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<rect width="100%%" height="100%%" fill="%s"/>%s</svg>' % (size, size, vb, vb, BG, body))


def render(name, parts, vb, size, zoom):
    os.makedirs(OUT, exist_ok=True)
    stem = os.path.join(OUT, name)
    open(stem + ".svg", "w").write(svg(parts, vb, size))
    subprocess.run(["magick", "-background", BG, stem + ".svg", stem + ".png"], check=True)
    # Nearest-neighbour, so what you judge is the real pixel grid magnified.
    subprocess.run(["magick", stem + ".png", "-filter", "point",
                    "-resize", "%d%%" % (zoom * 100), stem + "_big.png"], check=True)
    return stem + "_big.png"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("glyphs", nargs="*", default=[], help="glyph names (default: the audio set)")
    ap.add_argument("--variant", default="broadsheet", choices=["hairline", "ledger", "broadsheet"])
    ap.add_argument("--size", type=int, default=17, help="rendered edge in px (the chip asks for 15-17)")
    ap.add_argument("--zoom", type=int, default=8, help="magnification of the saved preview")
    args = ap.parse_args()

    sets = load_sets()
    glyphs = args.glyphs or ["earbuds", "headphones", "speaker", "battery", "bluetooth"]
    outs = []
    for name in glyphs:
        entry = sets[args.variant].get(name)
        if entry is None:
            print("no %s drawing of %r" % (args.variant, name), file=sys.stderr)
            continue
        vb, parts = entry
        outs.append(render("%s-%s-%d" % (name, args.variant, args.size), parts, vb, args.size, args.zoom))
    if not outs:
        return 1
    sheet = os.path.join(OUT, "sheet.png")
    subprocess.run(["magick", "montage", "-background", "#111", "-tile", "%d x1" % len(outs),
                    "-geometry", "+8+8", *outs, sheet], check=True)
    print(sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
