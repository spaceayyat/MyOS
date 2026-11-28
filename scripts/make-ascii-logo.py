#!/usr/bin/env python3
"""Draw the VYLO mark with half-block characters, for fastfetch.

Made from assets/brand/vylo-mark.svg. "$1" and "$2" are fastfetch's colour
slots: the upper part of the mark takes the first, the lower part the second.
Needs rsvg-convert and Pillow.  Usage: python3 scripts/make-ascii-logo.py
"""
import io
import pathlib
import subprocess

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "image/config/rootfs-vylo/usr/share/vylo/fastfetch/logo.txt"
COLUMNS = 30


def main() -> None:
    png = subprocess.run(
        ["rsvg-convert", "-w", "600", str(ROOT / "assets/brand/vylo-mark.svg")],
        check=True, capture_output=True).stdout
    alpha = Image.open(io.BytesIO(png)).getchannel("A")
    # One character holds two square pixels, one above the other.
    rows = round(COLUMNS * alpha.height / alpha.width / 2)
    small = alpha.resize((COLUMNS, rows * 2), Image.BOX)
    lines = []
    for row in range(rows):
        line = ""
        for x in range(COLUMNS):
            top = small.getpixel((x, row * 2)) >= 128
            bottom = small.getpixel((x, row * 2 + 1)) >= 128
            line += {(True, True): "█", (True, False): "▀",
                     (False, True): "▄", (False, False): " "}[top, bottom]
        colour = "$1" if row < rows * 0.55 else "$2"
        lines.append(colour + line.rstrip())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(OUT.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
