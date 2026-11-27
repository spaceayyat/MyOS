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
VIOLET, CYAN, STAR = (74, 71, 255), (55, 217, 255), (197, 174, 255)


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


def island(rng, base, cx, top, width, depth, rock, rim, falls=0, crystals=0):
    """A floating rock: uneven top, broken underside split into lit and shaded
    facets, a few hanging stones and crystals."""
    n = 26
    xs = np.linspace(-0.5, 0.5, n)
    upper = [(cx + x * width,
              top + rng.normal(0, depth * 0.018) - math.cos(x * 7) * depth * 0.02 + abs(x) ** 3 * depth * 0.45)
             for x in xs]
    lower = []
    for i, x in enumerate(xs[::-1]):
        taper = max(0.0, 1 - (abs(x - 0.06) * 1.9) ** 1.3)
        spike = rng.uniform(1.0, 1.35) if i % 3 == 1 else rng.uniform(0.62, 0.9)
        lower.append((cx + x * width * 0.96 + rng.normal(0, width * 0.008),
                      top + depth * 0.1 + depth * taper * spike * 0.8))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(upper + lower, fill=255)

    # Facets: narrow planes running from the top edge down to each broken point.
    paint = Image.new("RGB", (W, H), rock)
    d = ImageDraw.Draw(paint)
    under = lower[::-1]
    for i in range(n - 1):
        k = rng.uniform(0.55, 1.55) * (1.25 if i < n * 0.45 else 0.85)  # light from the left
        mid = under[i + (i % 2)]
        shade = tuple(min(255, int(c * k)) for c in rock)
        d.polygon([upper[i], upper[i + 1], (mid[0], mid[1] + 20)], fill=shade)
        low = tuple(min(255, int(c * k * 0.7)) for c in rock)
        d.polygon([upper[i + 1], under[i + 1], (mid[0], mid[1] + 20)], fill=low)
    grain = noise(rng, 70, 5, 0.6)
    body = np.asarray(paint.filter(ImageFilter.GaussianBlur(0.8)), np.float32) * (0.72 + grain[..., None] * 0.56)
    fade = np.clip((np.arange(H, dtype=np.float32) - top) / (depth * 1.1), 0, 1)[:, None, None]
    haze = np.array([66, 40, 130], np.float32)
    body = body * (1 - fade * 0.6) + haze * fade * 0.6      # the tip melts into the sky
    base.paste(to_image(body), (0, 0), mask)

    base = light_layer(base, lambda d: d.line(upper, fill=255, width=3, joint="curve"), 1.2,
                       tuple(c * 0.55 for c in rim))
    base = light_layer(base, lambda d: d.line(upper[: n // 2 + 3], fill=255, width=12), 16,
                       tuple(c * 0.24 for c in rim))

    for _ in range(crystals):
        i = int(rng.integers(3, n - 4))
        x, y = upper[i][0] + rng.uniform(-8, 8), upper[i][1] + 3
        h, w = rng.uniform(depth * 0.07, depth * 0.17), rng.uniform(5, 11)
        lean = rng.uniform(-9, 9)
        shard = [(x - w, y), (x + lean - w * 0.2, y - h), (x + lean + w * 0.5, y - h * 0.8), (x + w, y)]
        for blur, k in ((12, 0.45), (0, 0.6)):
            base = light_layer(base, lambda d: d.polygon(shard, fill=255), blur, tuple(c * k for c in CYAN))

    d = ImageDraw.Draw(base)
    for _ in range(int(width / 110)):                       # loose stones underneath
        x = cx + rng.uniform(-0.45, 0.45) * width
        y = top + depth * rng.uniform(0.85, 1.45)
        r = rng.uniform(3, 15)
        angles = np.sort(rng.uniform(0, 2 * math.pi, 6))
        pts = [(x + math.cos(t) * r * rng.uniform(0.6, 1.2), y + math.sin(t) * r * rng.uniform(0.5, 1.0)) for t in angles]
        d.polygon(pts, fill=tuple(int(c * rng.uniform(0.9, 1.5)) for c in rock))

    for i in range(falls):
        x = cx + width * (-0.30 + 0.5 * (i + 0.35) / falls) + rng.normal(0, width * 0.03)
        edge = upper[min(n - 1, max(0, int((x - cx) / width * (n - 1) + (n - 1) / 2)))][1]
        length = depth * rng.uniform(0.85, 1.35)
        for blur, spread, k in ((14, 26, 0.30), (2.5, 9, 0.42), (0.6, 4, 0.40)):
            def draw(d, x=x, spread=spread, length=length, edge=edge):
                for _ in range(spread):
                    off = rng.normal(0, spread * 0.35)
                    start = edge + 4 + rng.uniform(0, length * 0.25)
                    d.line([(x + off, start), (x + off * 2.0, start + length * rng.uniform(0.3, 0.8))],
                           fill=int(rng.uniform(60, 220)), width=1 if spread < 6 else 2)
                d.line([(x - 2, edge + 3), (x + 2, edge + 3)], fill=255, width=4)
            base = light_layer(base, draw, blur, (150 * k, 190 * k, 255 * k))
    return base


def observatory(rng, base, cx, ground):
    """A small observatory: stone drum, ribbed dome with its slit open, a
    telescope, two side buildings and warm-lit windows."""
    s = 2  # draw at twice the size, then scale down for smooth edges
    layer = Image.new("RGBA", (W * s, H * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def rect(x0, y0, x1, y1, c):
        d.rectangle([(cx + x0) * s, (ground + y0) * s, (cx + x1) * s, (ground + y1) * s], fill=c)

    def dome(x, base_y, r, c):
        d.pieslice([(cx + x - r) * s, (ground + base_y - r) * s, (cx + x + r) * s, (ground + base_y + r) * s],
                   180, 360, fill=c)

    shade, wall, lit, trim = (19, 11, 44), (33, 21, 74), (55, 38, 112), (96, 74, 166)
    for x, w, h in ((-176, 76, 74), (96, 62, 112), (150, 40, 58)):       # side buildings
        rect(x, -h, x + w, 14, wall)
        rect(x + w * 0.55, -h, x + w, 14, shade)
        dome(x + w / 2, -h, w / 2 + 3, lit)
        rect(x - 4, -h - 3, x + w + 4, -h + 3, trim)
    rect(-98, -150, 98, 14, wall)                                          # drum
    rect(-98, -150, -58, 14, lit)
    rect(46, -150, 98, 14, shade)
    for y in (-118, -78, -38):                                             # stone courses
        d.line([(cx - 98) * s, (ground + y) * s, (cx + 98) * s, (ground + y) * s], fill=(25, 15, 58), width=2)
    rect(-112, -163, 112, -148, trim)
    rect(-106, -171, 106, -163, shade)
    for x in range(-100, 101, 25):                                         # balcony rail
        rect(x, -186, x + 2, -171, trim)
    rect(-108, -188, 108, -184, trim)
    dome(0, -170, 90, lit)
    for k in (0.82, 0.55, 0.28):                                           # dome ribs
        d.arc([(cx - 90 * k) * s, (ground - 260) * s, (cx + 90 * k) * s, (ground - 80) * s], 180, 360, fill=wall, width=4)
    slit = [(-4, -170), (12, -259), (40, -249), (24, -170)]
    d.polygon([((cx + x) * s, (ground + y) * s) for x, y in slit], fill=(9, 5, 24))
    d.line([((cx + 16) * s, (ground - 214) * s), ((cx + 68) * s, (ground - 292) * s)], fill=trim, width=13 * s)
    d.line([((cx + 60) * s, (ground - 280) * s), ((cx + 76) * s, (ground - 304) * s)], fill=(150, 125, 214), width=18 * s)
    d.line([((cx - 128) * s, (ground - 150) * s), ((cx - 128) * s, (ground - 235) * s)], fill=trim, width=2 * s)
    d.pieslice([(cx - 28) * s, (ground - 46) * s, (cx + 8) * s, (ground - 10) * s], 180, 360, fill=(255, 206, 140))
    rect(-28, -28, 8, 14, (255, 190, 118))
    rect(-11, -42, -9, 14, wall)
    small = layer.resize((W, H), Image.LANCZOS)
    base.paste(small, (0, 0), small)

    warm = (255, 196, 128)
    windows = [(x, y) for x in (-82, -52, 28, 66) for y in (-122, -82)]
    windows += [(-152, -44), (-128, -44), (112, -80), (136, -80), (124, -44), (168, -30)]
    lit_windows = [w for w in windows if rng.random() > 0.2]
    for blur, k in ((10, 0.55), (0, 0.85)):
        def lights(m):
            for x, y in lit_windows:
                m.rounded_rectangle((cx + x - 4, ground + y - 8, cx + x + 4, ground + y + 8), 4, fill=255)
            if blur:
                m.ellipse((cx - 36, ground - 40, cx + 16, ground + 18), fill=200)
        base = light_layer(base, lights, blur, tuple(c * k for c in warm))
    base = light_layer(base, lambda m: m.ellipse((cx - 130, ground - 238, cx - 124, ground - 232), fill=255), 4, CYAN)
    base = light_layer(base, lambda m: m.polygon([(cx + 72, ground - 302), (cx + 330, ground - 560), (cx + 372, ground - 520),
                                                  (cx + 82, ground - 296)], fill=70), 14, CYAN)
    return light_layer(base, lambda m: m.arc((cx - 90, ground - 260, cx + 90, ground - 80), 182, 285, fill=255, width=3), 1.5, STAR)


def planet(rng, base, cx, cy, r):
    """A banded planet with a soft day side, a thin atmosphere and a ring."""
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    nx, ny = (x - cx) / r, (y - cy) / r
    dist = np.hypot(nx, ny)
    nz = np.sqrt(np.clip(1 - dist ** 2, 0, 1))
    light = np.clip(nx * -0.55 + ny * -0.55 + nz * 0.62, 0, 1)
    swirl = noise(rng, 220, 5, 3.0)
    bands = 0.5 + 0.5 * np.sin((ny * 0.94 + nx * 0.34) * 17 + swirl * 7)
    day = np.array([98, 66, 176], np.float32) + bands[..., None] * np.array([70, 62, 66], np.float32)
    colour = np.array([17, 9, 44], np.float32) + (day - 17) * (light ** 1.25)[..., None]
    colour *= (0.86 + noise(rng, 90, 5)[..., None] * 0.28)
    arr = np.asarray(base, np.float32)
    halo = np.exp(-((np.clip(dist - 1, 0, None) / 0.07) ** 2)) * (dist > 1) * np.clip(0.5 - (nx + ny) * 0.5, 0, 1)
    arr = arr + halo[..., None] * np.array([110, 80, 190], np.float32)
    a = np.clip((1 - dist) * r, 0, 1)[..., None]
    arr = arr * (1 - a) + colour * a
    # ring: a thin tilted ellipse that passes behind the top and over the front
    tilt = math.radians(-18)
    u = nx * math.cos(tilt) + ny * math.sin(tilt)
    v = (-nx * math.sin(tilt) + ny * math.cos(tilt)) / 0.22
    rr = np.hypot(u, v)
    ring = np.clip(1 - np.abs(rr - 1.62) / 0.24, 0, 1) * (0.55 + 0.45 * np.sin(rr * 95))
    ring *= np.where((v < 0) & (dist < 1.0), 0.0, 1.0)
    ra = np.clip(ring * 0.62, 0, 1)[..., None]
    return to_image(arr * (1 - ra) + np.array([200, 178, 250], np.float32) * ra)


def observatory_isles(rng):
    img = sky((9, 6, 28), (42, 19, 92))
    tex, tex2 = noise(rng, 900, 7), noise(rng, 360, 7)
    img = glow(img, W * 0.50, H * 0.64, W * 0.36, H * 0.30, (160, 104, 250), 0.9, tex)
    img = glow(img, W * 0.18, H * 0.28, W * 0.26, H * 0.22, VIOLET, 0.7, tex2)
    img = glow(img, W * 0.78, H * 0.18, W * 0.22, H * 0.18, (40, 120, 220), 0.5, tex)
    img = glow(img, W * 0.47, H * 0.70, W * 0.16, H * 0.09, (255, 150, 190), 0.30, tex2)
    dust = np.clip((noise(rng, 520, 7, 2.4) - 0.52) * 3.2, 0, 1)
    img = img * (1 - 0.45 * dust[..., None] * np.exp(-(((np.arange(H) - H * 0.46) / (H * 0.2)) ** 2))[:, None, None])
    img = stars(rng, img, 4200, int(H * 0.82))
    base = to_image(img)
    for sx, sy, size in ((0.13, 0.15, 34), (0.43, 0.11, 22), (0.89, 0.35, 18)):   # a few bright stars
        px, py = int(W * sx), int(H * sy)
        def flare(d, px=px, py=py, size=size):
            d.polygon([(px - size, py), (px, py - 2), (px + size, py), (px, py + 2)], fill=255)
            d.polygon([(px, py - size), (px + 2, py), (px, py + size), (px - 2, py)], fill=255)
            d.ellipse((px - 3, py - 3, px + 3, py + 3), fill=255)
        base = light_layer(light_layer(base, flare, 5, STAR), flare, 0, (210, 200, 240))
    base = planet(rng, base, W * 0.25, H * 0.31, 175)
    base = comet(base, (int(W * 0.34), int(H * 0.06), int(W * 0.70), int(H * 0.60)), 118, 242)
    base = island(rng, base, W * 0.40, H * 0.64, 250, 100, (46, 27, 98), STAR, 1, 1)
    base = island(rng, base, W * 0.575, H * 0.56, 640, 330, (36, 21, 82), STAR, 2, 5)
    base = observatory(rng, base, int(W * 0.585), int(H * 0.56) - 4)
    base = island(rng, base, W * 0.91, H * 0.73, 520, 250, (28, 15, 66), VIOLET, 1, 2)
    base = island(rng, base, W * 0.08, H * 0.71, 700, 420, (22, 11, 54), VIOLET, 2, 4)
    mist = noise(rng, 600, 6, 2.2)
    arr = np.asarray(base, np.float32)
    band = np.exp(-(((np.arange(H) - H * 0.95) / (H * 0.13)) ** 2))[:, None]
    a = np.clip(band * np.clip((mist - 0.3) * 2.2, 0, 1), 0, 0.82)[..., None]
    arr = arr * (1 - a) + np.array([118, 82, 205], np.float32) * a
    arr += rng.normal(0, 1.6, (H, W, 1))                      # fine film grain
    return to_image(arr)


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


# ---- Orbit hills: a flat, poster-like scene in the colour of each accent ------
ACCENTS = {"indigo": (74, 71, 255), "lilac": (194, 120, 255), "cyan": (55, 200, 245),
           "rose": (255, 111, 168), "amber": (255, 176, 74)}
S = 2  # supersampling for smooth edges


def mix(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def wobble(rng, n, amount, knots=24):
    """Smooth random offsets, like an unsteady hand."""
    return np.interp(np.linspace(0, knots - 1, n), np.arange(knots), rng.normal(0, amount, knots))


def painted(rng, img, polygon, top, bottom, strokes=0):
    """Fill a shape with a vertical colour change, brush streaks and soft grain."""
    mask = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(mask).polygon([(x * S, y * S) for x, y in polygon], fill=255)
    mask = mask.resize((W, H), Image.LANCZOS)
    ys = [p[1] for p in polygon]
    y0, y1 = max(0, min(ys)), min(H, max(ys))
    t = np.clip((np.arange(H, dtype=np.float32) - y0) / max(1, y1 - y0), 0, 1)[:, None, None]
    body = np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t + np.zeros((H, W, 3), np.float32)
    if strokes:
        streak = noise(rng, 46, 4, 7.0) - 0.5
        body = body + streak[..., None] * strokes
    img.paste(to_image(body), (0, 0), mask)
    return img


def ridge(rng, base_y, height, waves, tilt=0.0):
    xs = np.linspace(-40, W + 40, 260)
    phase = rng.uniform(0, 6.28, 3)
    ys = (base_y + tilt * (xs / W - 0.5)
          + height * np.sin(xs / W * waves * 6.28 + phase[0])
          + height * 0.45 * np.sin(xs / W * waves * 13.7 + phase[1])
          + wobble(rng, len(xs), height * 0.09, 70))
    return list(zip(xs, ys)) + [(W + 40, H + 40), (-40, H + 40)]


def hand_circle(rng, cx, cy, r, rough=0.004):
    angles = np.linspace(0, 2 * math.pi, 220, endpoint=False)
    radius = r + wobble(rng, 221, r * rough, 18)[:-1]
    return [(cx + math.cos(a) * rr, cy + math.sin(a) * rr) for a, rr in zip(angles, radius)]


def brush_orbit(rng, img, cx, cy, rx, ry, tilt, start, end, colour, width):
    """An orbit drawn with one brush stroke that swells and thins."""
    layer = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(layer)
    n = 1400
    shake = wobble(rng, n, 1.6, 30)
    for i, a in enumerate(np.linspace(math.radians(start), math.radians(end), n)):
        u, v = math.cos(a) * (rx + shake[i]), math.sin(a) * (ry + shake[i])
        x = cx + u * math.cos(tilt) - v * math.sin(tilt)
        y = cy + u * math.sin(tilt) + v * math.cos(tilt)
        r = max(0.6, width * math.sin(math.pi * (i + 20) / (n + 40)) ** 0.8) * S / 2
        d.ellipse((x * S - r, y * S - r, x * S + r, y * S + r), fill=235)
    layer = layer.resize((W, H), Image.LANCZOS)
    img.paste(Image.new("RGB", (W, H), colour), (0, 0), layer)
    return img


def sparkle(d, x, y, r, colour):
    pts = []
    for k in range(8):
        a, rr = k * math.pi / 4, r if k % 2 == 0 else r * 0.17
        pts.append(((x + math.cos(a) * rr) * S, (y + math.sin(a) * rr) * S))
    d.polygon(pts, fill=colour)


def orbit_hills(rng, accent):
    night = (11, 8, 30)
    paper = (244, 238, 255)
    img = to_image(sky(mix(night, accent, 0.05), mix(night, accent, 0.46)))

    # stars, each placed with its own size
    layer = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(360):
        x, y = rng.uniform(0, W), rng.uniform(0, H * 0.66) ** 1.0
        r = rng.choice([1.0, 1.4, 1.9, 2.8], p=[0.55, 0.28, 0.13, 0.04])
        alpha = int(rng.uniform(80, 235) * (1 - 0.6 * y / H))
        d.ellipse(((x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S), fill=paper + (alpha,))
    for x, y, r in ((300, 250, 26), (1420, 170, 18), (1710, 520, 13), (880, 110, 11), (2330, 130, 15), (190, 700, 10)):
        sparkle(d, x, y, r, paper + (235,))
    small = layer.resize((W, H), Image.LANCZOS)
    img.paste(small, (0, 0), small)

    # the moon: a warm disc with a shaded side and a few craters
    cx, cy, r = W * 0.36, H * 0.40, 285
    img = to_image(glow(np.asarray(img, np.float32), cx, cy, r * 1.9, r * 1.9, accent, 0.38))
    moon = hand_circle(rng, cx, cy, r)
    img = painted(rng, img, moon, mix(paper, accent, 0.20), mix(paper, accent, 0.62), 16)
    shade = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shade).polygon(moon, fill=255)
    cut = Image.new("L", (W, H), 0)
    ImageDraw.Draw(cut).polygon(hand_circle(rng, cx - 96, cy - 70, r * 1.02), fill=255)
    crescent = np.clip(np.asarray(shade, np.int16) - np.asarray(cut, np.int16), 0, 255).astype(np.uint8)
    img.paste(Image.new("RGB", (W, H), mix(accent, night, 0.18)), (0, 0),
              Image.fromarray((crescent * 0.62).astype(np.uint8)))
    for dx, dy, cr in ((-110, -60, 44), (-20, 74, 27), (-160, 62, 19), (48, -142, 23), (-62, -168, 11)):
        img = painted(rng, img, hand_circle(rng, cx + dx, cy + dy, cr, 0.03),
                      mix(paper, accent, 0.52), mix(paper, accent, 0.40), 8)

    img = brush_orbit(rng, img, cx, cy + 10, r * 1.78, r * 0.46, math.radians(-17), -28, 212, mix(paper, accent, 0.15), 11)
    px, py = cx + r * 1.50, cy - r * 0.66
    img = painted(rng, img, hand_circle(rng, px, py, 38, 0.02), mix(paper, accent, 0.35), accent, 12)

    # hills, far to near
    img = painted(rng, img, ridge(rng, H * 0.665, 46, 1.2), mix(night, accent, 0.62), mix(night, accent, 0.34), 14)
    far = ridge(rng, H * 0.735, 62, 0.8, -90)
    img = painted(rng, img, far, mix(night, accent, 0.44), mix(night, accent, 0.20), 14)

    # a small observatory on the second ridge, one window lit
    ox = W * 0.655
    ground = float(np.interp(ox, [p[0] for p in far[:-2]], [p[1] for p in far[:-2]])) + 6
    dark = mix(night, accent, 0.10)
    layer = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    def box(x0, y0, x1, y1, fill):
        d.rectangle(((ox + x0) * S, (ground + y0) * S, (ox + x1) * S, (ground + y1) * S), fill=fill + (255,))
    box(-54, -62, 54, 22, dark)
    box(54, -30, 112, 22, dark)
    box(-64, -70, 64, -60, dark)
    d.pieslice(((ox - 52) * S, (ground - 118) * S, (ox + 52) * S, (ground - 14) * S), 180, 360, fill=dark + (255,))
    d.line(((ox + 8) * S, (ground - 98) * S, (ox + 72) * S, (ground - 150) * S), fill=dark + (255,), width=17 * S)
    box(-14, -40, 12, -8, (255, 201, 132))
    box(-2, -40, 0, -8, dark)
    box(74, -14, 86, 2, (255, 201, 132))
    small = layer.resize((W, H), Image.LANCZOS)
    img.paste(small, (0, 0), small)

    img = painted(rng, img, ridge(rng, H * 0.83, 54, 1.05, 70), mix(night, accent, 0.28), mix(night, accent, 0.12), 12)
    near = ridge(rng, H * 0.925, 44, 0.7, -40)
    img = painted(rng, img, near, mix(night, accent, 0.14), night, 10)

    # grass tufts along the nearest ridge
    d = ImageDraw.Draw(img)
    for x, y in near[:-2:2]:
        for _ in range(int(rng.integers(0, 4))):
            gx = x + rng.uniform(-14, 14)
            d.line((gx, y + 8, gx + rng.uniform(-7, 7), y - rng.uniform(5, 22)), fill=mix(night, accent, 0.14), width=2)

    # paper grain
    arr = np.asarray(img, np.float32)
    grain = (noise(rng, 7, 2) - 0.5) * 13 + (noise(rng, 330, 3) - 0.5) * 7
    return to_image(arr + grain[..., None])


WALLPAPERS = {**{f"orbit-hills-{name}": (lambda rng, c=colour: orbit_hills(rng, c))
                 for name, colour in ACCENTS.items()},
              "observatory-isles": observatory_isles, "nebula-drift": nebula_drift, "deep-void": deep_void}


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    for name, render in WALLPAPERS.items():
        if names and name not in names:
            continue
        # One scene keeps the same shapes in every colour.
        seed = {"nebula-drift": 30, "deep-void": 31}.get(name, 11 if name.startswith("orbit-hills") else 29)
        render(np.random.default_rng(seed)).save(OUT / f"{name}.jpg", quality=90, optimize=True)
        print("wrote", OUT / f"{name}.jpg")


if __name__ == "__main__":
    main(sys.argv[1:])
