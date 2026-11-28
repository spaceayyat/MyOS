#!/usr/bin/env python3
"""Make cosmos-<accent>.jpg from assets/wallpapers/<accent>.jpg (needs numpy
and Pillow): crop to 16:9, enlarge to 1920x1080, sharpen a little."""
import pathlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/wallpapers"
OUT = ROOT / "image/config/rootfs/usr/share/wallpapers/vylo"
SIZE = (1920, 1080)
# Where to cut when a picture is taller than 16:9: 0 keeps the top, 1 the bottom.
KEEP = {"indigo": 0.5, "lilac": 0.5, "cyan": 0.45, "rose": 0.85, "amber": 0.5}


def convert(name, keep):
    image = Image.open(SOURCE / f"{name}.jpg").convert("RGB")
    width, height = image.size
    tall = round(width * 9 / 16)
    if height > tall:
        top = round((height - tall) * keep)
        image = image.crop((0, top, width, top + tall))
    else:
        wide = round(height * 16 / 9)
        left = (width - wide) // 2
        image = image.crop((left, 0, left + wide, height))
    image = image.resize(SIZE, Image.LANCZOS)
    image = image.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=3))
    # A trace of grain hides the blocks that enlarging brings out.
    grain = np.random.default_rng(7).normal(0, 1.4, (SIZE[1], SIZE[0], 1))
    pixels = np.clip(np.asarray(image, np.float32) + grain, 0, 255).astype(np.uint8)
    Image.fromarray(pixels).save(OUT / f"cosmos-{name}.jpg", quality=90, optimize=True)


for accent, keep in KEEP.items():
    convert(accent, keep)
    print("wrote cosmos-" + accent)
