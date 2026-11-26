#!/usr/bin/env python3
"""Write the VYLO logo set (original artwork) as SVG files into assets/brand/.

The shapes live here so every variant stays consistent. Run after editing:
    python3 scripts/make-logo.py
"""
import math
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "brand"
VOID, VIOLET, CYAN, STAR, WHITE = "#100B25", "#713BFA", "#37D9FF", "#C5AEFF", "#F4F2FF"

# The mark is drawn on a 256 x 256 grid.
LEFT = "M34 52 L90 52 L136 164 L122 212 Z"
RIGHT = "M122 212 L136 164 L182 52 L226 40 L146 212 Z"
RX, RY, TILT, CX, CY = 118, 40, -18, 128, 124


def point(deg):
    t, a = math.radians(deg), math.radians(TILT)
    x, y = RX * math.cos(t), RY * math.sin(t)
    return (CX + x * math.cos(a) - y * math.sin(a),
            CY + x * math.sin(a) + y * math.cos(a))


def arc(start, end):
    (x1, y1), (x2, y2) = point(start), point(end)
    large = 1 if (end - start) % 360 > 180 else 0
    return f"M{x1:.1f} {y1:.1f} A{RX} {RY} {TILT} {large} 1 {x2:.1f} {y2:.1f}"


def sparkle(x, y, r):
    s = r * 0.22
    return (f"M{x:.1f} {y-r:.1f} L{x+s:.1f} {y-s:.1f} L{x+r:.1f} {y:.1f} L{x+s:.1f} {y+s:.1f} "
            f"L{x:.1f} {y+r:.1f} L{x-s:.1f} {y+s:.1f} L{x-r:.1f} {y:.1f} L{x-s:.1f} {y-s:.1f} Z")


DEFS = f"""<defs>
<linearGradient id="l" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{STAR}"/><stop offset="0.45" stop-color="{VIOLET}"/><stop offset="1" stop-color="#4a1fc4"/></linearGradient>
<linearGradient id="r" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="{VIOLET}"/><stop offset="1" stop-color="{CYAN}"/></linearGradient>
<linearGradient id="o" gradientUnits="userSpaceOnUse" x1="16" y1="170" x2="240" y2="80"><stop offset="0" stop-color="{VIOLET}"/><stop offset="1" stop-color="{CYAN}"/></linearGradient>
</defs>"""


def mark(mono=None, ring=True):
    left, right, orbit, star = (mono,) * 4 if mono else ("url(#l)", "url(#r)", "url(#o)", WHITE)
    parts = []
    if ring:  # the far half of the orbit passes behind the letter
        parts.append(f'<path d="{arc(190, 345)}" fill="none" stroke="{orbit}" stroke-width="5" stroke-linecap="round" opacity="0.65"/>')
    parts.append(f'<path d="{LEFT}" fill="{left}"/><path d="{RIGHT}" fill="{right}"/>')
    if ring:
        parts.append(f'<path d="{arc(8, 168)}" fill="none" stroke="{orbit}" stroke-width="8" stroke-linecap="round"/>')
        x, y = point(347)
        parts.append(f'<path d="{sparkle(x, y, 17)}" fill="{star}"/>')
    return "".join(parts)


def wordmark(colour):
    return (f'<g fill="none" stroke="{colour}" stroke-width="13" stroke-linejoin="miter" stroke-linecap="butt">'
            '<path d="M4 4 L36 76 L68 4"/><path d="M92 4 L122 42 L152 4 M122 40 V80"/>'
            '<path d="M180 0 V73.5 H232"/><rect x="262" y="6.5" width="74" height="67" rx="30"/></g>')


def svg(name, w, h, body, defs=True):
    (OUT / name).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        f'role="img" aria-label="VYLO">{DEFS if defs else ""}{body}</svg>\n')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    svg("vylo-mark.svg", 256, 256, mark())
    svg("vylo-mark-mono.svg", 256, 256, mark(WHITE), defs=False)
    # Without the orbit: stays readable at 16-32 px.
    svg("vylo-mark-small.svg", 256, 256,
        f'<g transform="translate(128 128) scale(1.22) translate(-130 -126)">{mark(ring=False)}</g>')
    svg("vylo-app-icon.svg", 256, 256,
        f'<rect x="4" y="4" width="248" height="248" rx="58" fill="{VOID}" stroke="{VIOLET}" stroke-width="3"/>'
        f'<g transform="translate(128 128) scale(0.84) translate(-128 -128)">{mark()}</g>')
    for name, colour in (("vylo-logo.svg", WHITE), ("vylo-logo-dark.svg", VOID)):
        svg(name, 660, 256, mark() + f'<g transform="translate(290 90)">{wordmark(colour)}</g>')
    svg("vylo-logo-stacked.svg", 400, 380,
        f'<g transform="translate(72 0)">{mark()}</g><g transform="translate(30 270)">{wordmark(WHITE)}</g>')
    print("wrote", len(list(OUT.glob("*.svg"))), "logo files to", OUT)


if __name__ == "__main__":
    main()
