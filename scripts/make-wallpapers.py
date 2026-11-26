#!/usr/bin/env python3
"""Render the original VYLO wallpapers procedurally (needs numpy and Pillow).

Deterministic: the same script gives the same pictures.
    python3 scripts/make-wallpapers.py [name ...]
Writes image/config/rootfs/usr/share/wallpapers/vylo/<name>.jpg
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2560, 1440
OUT = pathlib.Path(__file__).resolve().parents[1] / "image/config/rootfs/usr/share/wallpapers/vylo"
VIOLET, CYAN, STAR = (113, 59, 250), (55, 217, 255), (197, 174, 255)


def noise(rng, scale, octaves=5, stretch=1.0):
    """Fractal value noise in 0..1."""
    total, amp, norm = np.zeros((H, W), np.float32), 1.0, 0.0
    for o in range(octaves):
        gx = max(2, int(W / scale * 2 ** o / stretch))
        gy = max(2, int(H / scale * 2 ** o))
        grid = Image.fromarray((rng.random((gy, gx)) * 255).astype(np.uint8))
        total += amp * np.asarray(grid.resize((W, H), Image.BICUBIC), np.float32) / 255
        norm += amp
        amp *= 0.55
    return total / norm


def sky(top, bottom):
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    return np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t + np.zeros((H, W, 3), np.float32)


def glow(img, cx, cy, rx, ry, colour, strength, texture=None):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    a = np.exp(-(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)) * strength
    if texture is not None:
        a = a * np.clip((texture - 0.32) * 2.6, 0, 1.4)
    a = np.clip(a, 0, 1)[..., None]
    return img + (np.array(colour, np.float32) - img * 0.35) * a


def stars(rng, img, count, limit=H):
    layer = np.zeros((H, W), np.float32)
    xs, ys = rng.integers(0, W, count), rng.integers(0, limit, count)
    layer[ys, xs] = rng.random(count) ** 3 * 255
    soft = np.asarray(Image.fromarray(layer.astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6)), np.float32)
    return img + (layer * 0.9 + soft * 2.2)[..., None] * np.array([0.9, 0.9, 1.0], np.float32)


def to_image(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def light_layer(base, draw_fn, blur, colour):
    """Additive soft light: draw a mask, blur it, add the colour."""
    mask = Image.new("L", (W, H), 0)
    draw_fn(ImageDraw.Draw(mask))
    if blur:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(mask, np.float32)[..., None] / 255
    return to_image(np.asarray(base, np.float32) + a * np.array(colour, np.float32))


def comet(base, box, start, end):
    for blur, width, strength in ((18, 16, 0.7), (4, 5, 0.9), (0, 2, 0.9)):
        base = light_layer(base, lambda d: d.arc(box, start, end, fill=255, width=width), blur,
                           tuple(c * strength for c in STAR))
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    rx, ry = (box[2] - box[0]) / 2, (box[3] - box[1]) / 2
    x, y = cx + rx * math.cos(math.radians(end)), cy + ry * math.sin(math.radians(end))
    for blur, r, k in ((26, 22, 1.0), (5, 9, 1.0), (0, 4, 1.0)):
        base = light_layer(base, lambda d: d.ellipse((x - r, y - r, x + r, y + r), fill=255), blur,
                           (230 * k, 225 * k, 255 * k))
    return base


def island(rng, base, cx, top, width, depth, rock, rim, falls=0):
    """A floating rock: flat ragged top, tapering underside, lit upper edge."""
    n = 90
    xs = np.linspace(-0.5, 0.5, n)
    upper = [(cx + x * width, top + rng.normal(0, depth * 0.012) + abs(x) ** 3 * depth * 0.5) for x in xs]
    lower = []
    for x in xs[::-1]:
        taper = max(0.0, 1 - (abs(x) * 2) ** 1.4)
        jag = 1 + 0.55 * abs(math.sin(x * 23 + cx)) * rng.random()
        lower.append((cx + x * width * 0.97, top + depth * 0.08 + depth * taper * jag * 0.75))
    shape = upper + lower
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(shape, fill=255)
    tex = noise(rng, 140, 5, 0.35)
    fade = np.clip((np.arange(H, dtype=np.float32) - top) / (depth * 0.9), 0, 1)[:, None]
    body = np.array(rock, np.float32) * (0.55 + tex[..., None] * 0.9) + fade[..., None] * np.array([22, 8, 52], np.float32)
    base.paste(to_image(body), (0, 0), mask)
    base = light_layer(base, lambda d: d.line(upper, fill=255, width=4), 2, tuple(c * 0.75 for c in rim))
    base = light_layer(base, lambda d: d.line(upper, fill=255, width=14), 20, tuple(c * 0.35 for c in rim))
    for i in range(falls):
        x = cx + width * (-0.28 + 0.56 * (i + 0.5) / falls) + rng.normal(0, width * 0.03)
        length = depth * rng.uniform(0.9, 1.45)
        for blur, wd, k in ((16, 34, 0.45), (3, 13, 0.6), (0, 3, 0.55)):
            def draw(d, x=x, wd=wd, length=length):
                for s in range(-wd // 2, wd // 2 + 1, 3):
                    d.line([(x + s, top + 6), (x + s * 2.1 + rng.normal(0, 3), top + length * rng.uniform(0.75, 1))],
                           fill=int(rng.uniform(70, 255)), width=2)
            base = light_layer(base, draw, blur, (150 * k, 185 * k, 255 * k))
    return base


def observatory(base, cx, ground):
    d = ImageDraw.Draw(base)
    dark, mid = (18, 10, 44), (30, 18, 70)
    for x, w, h in ((-170, 70, 120), (110, 60, 150), (180, 44, 90)):
        d.rectangle((cx + x, ground - h, cx + x + w, ground + 10), fill=dark)
        d.pieslice((cx + x, ground - h - w // 2, cx + x + w, ground - h + w // 2), 180, 360, fill=mid)
    d.rectangle((cx - 110, ground - 190, cx + 110, ground + 10), fill=dark)
    d.rectangle((cx - 126, ground - 200, cx + 126, ground - 184), fill=mid)
    d.pieslice((cx - 105, ground - 310, cx + 105, ground - 90), 180, 360, fill=mid)
    d.line((cx, ground - 340, cx, ground - 305), fill=mid, width=6)
    windows = [(cx + x, ground - y) for x in (-70, -30, 40, 80) for y in (150, 95, 45)]
    for blur, k in ((9, 0.8), (0, 0.9)):
        def lights(m):
            for x, y in windows:
                m.rounded_rectangle((x - 4, y - 12, x + 4, y + 12), 4, fill=255)
            m.polygon([(cx - 8, ground - 190), (cx - 5, ground - 300), (cx + 8, ground - 300), (cx + 10, ground - 190)], fill=255)
        base = light_layer(base, lights, blur, tuple(c * k for c in CYAN))
    return light_layer(base, lambda m: m.arc((cx - 105, ground - 310, cx + 105, ground - 90), 180, 360, fill=255, width=3), 2, STAR)


def planet(base, cx, cy, r):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    dist = np.hypot(x - cx, y - cy)
    light = np.clip(((x - cx) * -0.6 + (y - cy) * -0.8) / r * 0.5 + 0.5, 0, 1)
    colour = np.array([20, 10, 52], np.float32) + light[..., None] ** 2 * np.array([150, 110, 215], np.float32)
    a = np.clip(r - dist, 0, 1)[..., None] * 0.92
    arr = np.asarray(base, np.float32)
    return to_image(arr * (1 - a) + colour * a)


def observatory_isles(rng):
    img = sky((10, 6, 30), (44, 20, 96))
    tex, tex2 = noise(rng, 900, 6), noise(rng, 420, 6)
    img = glow(img, W * 0.50, H * 0.62, W * 0.34, H * 0.30, (168, 112, 255), 0.95, tex)
    img = glow(img, W * 0.22, H * 0.30, W * 0.24, H * 0.20, VIOLET, 0.75, tex2)
    img = glow(img, W * 0.82, H * 0.20, W * 0.22, H * 0.18, (40, 120, 220), 0.55, tex)
    img = stars(rng, img, 4200, int(H * 0.8))
    base = to_image(img)
    base = planet(base, W * 0.30, H * 0.33, 190)
    base = comet(base, (int(W * 0.43), int(H * 0.02), int(W * 0.86), int(H * 0.58)), 70, -118 + 360)
    base = island(rng, base, W * 0.47, H * 0.66, 300, 110, (40, 22, 88), STAR, 1)
    base = island(rng, base, W * 0.72, H * 0.50, 760, 360, (24, 13, 60), STAR, 3)
    base = observatory(base, int(W * 0.72), int(H * 0.50))
    base = island(rng, base, W * 0.12, H * 0.70, 720, 430, (17, 8, 42), VIOLET, 2)
    mist = noise(rng, 600, 5, 2.2)
    arr = np.asarray(base, np.float32)
    band = np.exp(-(((np.arange(H) - H * 0.93) / (H * 0.12)) ** 2))[:, None]
    a = np.clip(band * np.clip((mist - 0.3) * 2.2, 0, 1), 0, 0.85)[..., None]
    return to_image(arr * (1 - a) + np.array([126, 88, 220], np.float32) * a)


def nebula_drift(rng):
    img = sky((12, 8, 32), (14, 10, 40))
    a, b = noise(rng, 1100, 7, 1.8), noise(rng, 500, 6)
    img = glow(img, W * 0.35, H * 0.55, W * 0.40, H * 0.28, VIOLET, 0.95, a)
    img = glow(img, W * 0.68, H * 0.42, W * 0.30, H * 0.24, (40, 170, 230), 0.75, b)
    img = glow(img, W * 0.55, H * 0.50, W * 0.12, H * 0.10, STAR, 0.6, a)
    return comet(to_image(stars(rng, img, 5200)), (int(W * 0.06), int(H * 0.10), int(W * 0.94), int(H * 1.30)), 200, 292)


def deep_void(rng):
    """Calm and light on resources: a gradient, a few stars, one orbit."""
    img = glow(sky((16, 11, 37), (9, 6, 22)), W * 0.5, H * 1.05, W * 0.5, H * 0.45, (74, 38, 170), 0.8)
    base = to_image(stars(rng, img, 700))
    return light_layer(base, lambda d: d.arc((-400, 880, W + 400, 2300), 200, 340, fill=255, width=3), 3,
                       tuple(c * 0.55 for c in CYAN))


WALLPAPERS = {"observatory-isles": observatory_isles, "nebula-drift": nebula_drift, "deep-void": deep_void}


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (name, render) in enumerate(WALLPAPERS.items()):
        if names and name not in names:
            continue
        render(np.random.default_rng(29 + index)).save(OUT / f"{name}.jpg", quality=90, optimize=True)
        print("wrote", OUT / f"{name}.jpg")


if __name__ == "__main__":
    main(sys.argv[1:])
