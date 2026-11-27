#!/usr/bin/env python3
"""Build the VYLO logo set from the master artwork (needs numpy and Pillow).

The master is assets/brand/source/vylo-logo-original.png, drawn on black.
  * PNG files are cut from it, with the black turned into transparency, so the
    glow is exactly the original. Use these large (boot, login, installer).
  * SVG files are a flat tracing of the same shapes, for small sizes, single
    colour use and anything that must scale.
    python3 scripts/make-logo.py
"""
import pathlib

import numpy as np
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "brand"
SOURCE = OUT / "source" / "vylo-logo-original.png"
VOID, WHITE = "#100B25", "#F4F2FF"

# Coordinates below are pixels of the master artwork.
LEFT_ARM = "M519 495 H566 L653 633 L636 677 Z"
RIGHT_ARM = "M708 495 H747 L636 677 L653 633 L636 606 Z"
FACET = "M708 495 H747 L636 606 Z"
STAR = ("M747 438 L751 481 L757 487 L806 491 L757 495 L751 501 L747 546 "
        "L743 501 L737 495 L690 491 L737 487 L743 481 Z")
WORD = ("M460 729 H471.5 L494.5 761 L517.5 729 H529 L499.5 770 H490 Z "
        "M564 729 H576 L594 745 L612 729 H624 L598 752.5 V770 H590 V752.5 Z "
        "M665 729 H673.5 V762 H715 V770 H665 Z "
        "M765 729 H800 Q812 729 812 741 V758 Q812 770 800 770 H765 Q753 770 753 758 V741 Q753 729 765 729 Z "
        "M767 737 Q761.5 737 761.5 742 V757 Q761.5 762 767 762 H798 Q803.5 762 803.5 757 V742 Q803.5 737 798 737 Z")

DEFS = """<defs>
<linearGradient id="l" gradientUnits="userSpaceOnUse" x1="530" y1="495" x2="640" y2="677">
<stop offset="0" stop-color="#b45cff"/><stop offset="0.3" stop-color="#6a0ff5"/><stop offset="0.75" stop-color="#5a00ee"/><stop offset="1" stop-color="#e3c4ff"/></linearGradient>
<linearGradient id="r" gradientUnits="userSpaceOnUse" x1="747" y1="495" x2="645" y2="630">
<stop offset="0" stop-color="#8a2cff"/><stop offset="1" stop-color="#35009e"/></linearGradient>
<linearGradient id="f" gradientUnits="userSpaceOnUse" x1="747" y1="495" x2="650" y2="590">
<stop offset="0" stop-color="#f0d9ff"/><stop offset="1" stop-color="#6a14f0"/></linearGradient>
</defs>"""


def mark(mono=None, star=True):
    left, right, facet, spark = (mono,) * 4 if mono else ("url(#l)", "url(#r)", "url(#f)", "#f3e6ff")
    body = f'<path d="{LEFT_ARM}" fill="{left}"/><path d="{RIGHT_ARM}" fill="{right}"/>'
    body += f'<path d="{FACET}" fill="{facet}"/>'
    if star:
        body += f'<path d="{STAR}" fill="{spark}"/>'
    return body


def svg(name, box, body, size=None):
    x, y, w, h = box
    width, height = size or (w, h)
    (OUT / name).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="{x} {y} {w} {h}" role="img" aria-label="VYLO">{DEFS}{body}</svg>\n')


def cut(name, box):
    """Crop the master and un-mix it from black: alpha is the brightest channel."""
    rgb = np.asarray(Image.open(SOURCE).convert("RGB").crop(box), np.float32)
    alpha = rgb.max(axis=2)
    alpha = np.clip((alpha - 3) * 255 / 252, 0, 255)  # drop near-black noise
    colour = np.where(alpha[..., None] > 0, rgb * 255 / np.maximum(alpha, 1)[..., None], 0)
    # Fade the crop edges so no rectangle shows around the glow.
    h, w = alpha.shape
    ramp = lambda n: np.clip(np.minimum(np.arange(n), np.arange(n)[::-1]) / 28, 0, 1)
    alpha = alpha * ramp(h)[:, None] * ramp(w)[None, :]
    rgba = np.dstack([np.clip(colour, 0, 255), alpha]).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(OUT / name, optimize=True)


def main():
    cut("vylo-logo-stacked.png", (370, 330, 910, 830))  # mark, glow and wordmark
    cut("vylo-mark-glow.png", (430, 340, 910, 710))
    mark_box = (500, 428, 316, 270)
    svg("vylo-mark.svg", mark_box, mark())
    svg("vylo-mark-mono.svg", mark_box, mark(WHITE))
    svg("vylo-mark-small.svg", (513, 466, 240, 240), mark(star=False), (256, 256))
    svg("vylo-app-icon.svg", (493, 436, 280, 280),
        f'<rect x="497" y="440" width="272" height="272" rx="62" fill="#07040f" stroke="#3b1a86" stroke-width="3"/>'
        f'<g transform="translate(633 580) scale(0.86) translate(-640 -562)">{mark()}</g>', (256, 256))
    svg("vylo-wordmark.svg", (460, 729, 352, 41), f'<path d="{WORD}" fill="{WHITE}" fill-rule="evenodd"/>')
    lockup = (440, 425, 396, 360)
    svg("vylo-logo.svg", lockup, mark() + f'<path d="{WORD}" fill="#9a3dff" fill-rule="evenodd"/>')
    svg("vylo-logo-dark.svg", lockup, mark(VOID) + f'<path d="{WORD}" fill="{VOID}" fill-rule="evenodd"/>')
    print("wrote the logo set to", OUT)
    boot_images()


def boot_images():
    """Logo copies for the login screen and boot splash, from the PNG artwork."""
    config = OUT.parents[1] / "image/config/rootfs-vylo/usr/share"
    art = Image.open(OUT / "vylo-logo-stacked.png").convert("RGBA")
    art = art.crop(art.getbbox())
    for folder, width in (("sddm/themes/vylo", 360), ("plymouth/themes/vylo", 300)):
        height = round(art.height * width / art.width)
        art.resize((width, height), Image.LANCZOS).save(config / folder / "logo.png", optimize=True)
    dot = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse((0, 0, 39, 39), fill=(113, 59, 250, 255))
    dot.resize((10, 10), Image.LANCZOS).save(config / "plymouth/themes/vylo/dot.png")


if __name__ == "__main__":
    main()
