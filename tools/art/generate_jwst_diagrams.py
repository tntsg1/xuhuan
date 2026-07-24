"""
Five structurally-correct JWST teaching diagrams (schematic, temporary art but
scientifically accurate - the L2 diagram in particular obeys the brief: JWST
orbits the SUN near Sun-Earth L2, ~1.5 million km from Earth, NOT the Earth).

    python tools/art/generate_jwst_diagrams.py

Output: assets/learning_diagrams/jwst_*.png (1024x560 RGBA, English labels baked
in; the Chinese explanation lives in the learning card text, not the image).
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "learning_diagrams")
W, H = 1024, 560

NAVY = (12, 22, 40)
GRID = (26, 46, 78)
CYAN = (97, 216, 255)
GOLD = (216, 168, 77)
GOLD_HI = (240, 214, 140)
WHITE = (232, 238, 246)
MUTED = (150, 170, 196)
ORANGE = (236, 150, 90)
RED = (224, 102, 74)
GREEN = (103, 215, 139)
BLUE = (120, 165, 255)


def _font(size):
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            continue
    return ImageFont.load_default()


F_TITLE = _font(30)
F_LABEL = _font(19)
F_SMALL = _font(15)


def _board():
    img = Image.new("RGBA", (W, H), NAVY + (255,))
    d = ImageDraw.Draw(img)
    for x in range(0, W, 32):
        d.line([(x, 0), (x, H)], fill=GRID + (255,), width=1)
    for y in range(0, H, 32):
        d.line([(0, y), (W, y)], fill=GRID + (255,), width=1)
    return img, d


def _text(d, pos, s, font=F_LABEL, fill=WHITE, anchor="la"):
    d.text(pos, s, font=font, fill=fill + (255,), anchor=anchor)


def _hex(d, cx, cy, r, outline, fill=None, width=3):
    pts = [(cx + math.cos(math.pi / 6 + i * math.pi / 3) * r,
            cy + math.sin(math.pi / 6 + i * math.pi / 3) * r) for i in range(6)]
    if fill:
        d.polygon(pts, fill=fill + (255,))
    d.line(pts + [pts[0]], fill=outline + (255,), width=width)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name + ".png")
    img.save(p)
    print("  %s.png" % name)


# ---------------------------------------------------------------- 1. spectrum
def spectrum():
    img, d = _board()
    _text(d, (W / 2, 30), "INFRARED: SEEING HEAT FROM SPACE", F_TITLE, GOLD_HI, "ma")
    # EM spectrum bar
    x0, x1, y = 80, 944, 150
    bands = [("Gamma", (150, 90, 200)), ("X-ray", (120, 130, 220)), ("UV", (150, 170, 255)),
             ("Visible", (120, 220, 160)), ("Infrared", ORANGE), ("Microwave", (200, 140, 90)), ("Radio", (150, 110, 80))]
    bw = (x1 - x0) / len(bands)
    for i, (name, col) in enumerate(bands):
        bx = x0 + i * bw
        d.rectangle([bx, y, bx + bw - 2, y + 40], fill=col + (255,))
        _text(d, (bx + bw / 2, y + 58), name, F_SMALL, WHITE if name != "Visible" else GREEN, "ma")
    # highlight the tiny visible slice vs the wide infrared JWST works in
    vx = x0 + 3 * bw
    d.rectangle([vx, y - 6, vx + bw, y + 46], outline=GREEN + (255,), width=3)
    _text(d, (vx + bw / 2, y - 26), "eye sees only this", F_SMALL, GREEN, "ma")
    ix = x0 + 4 * bw
    d.rectangle([ix, y - 6, ix + bw, y + 46], outline=CYAN + (255,), width=4)
    _text(d, (ix + bw / 2, y - 26), "JWST works here", F_SMALL, CYAN, "ma")
    # cold dust cloud glowing in infrared
    d.ellipse([360, 300, 660, 470], fill=(30, 26, 40, 255))
    for r, c in [(150, (60, 40, 44)), (110, (110, 70, 55)), (70, (180, 110, 70)), (36, (236, 170, 110))]:
        d.ellipse([510 - r, 385 - int(r * 0.55), 510 + r, 385 + int(r * 0.55)], fill=c + (255,))
    _text(d, (510, 300), "cold dust + young stars glow in infrared", F_SMALL, ORANGE, "ma")
    # visible-light blocked, infrared passes
    _text(d, (150, 360), "visible light:", F_SMALL, GREEN, "la")
    d.line([(150, 390), (350, 390)], fill=GREEN + (255,), width=4)
    for k in range(6):
        d.line([(200 + k * 20, 386), (206 + k * 20, 394)], fill=RED + (255,), width=3)
    _text(d, (150, 404), "blocked by dust", F_SMALL, RED, "la")
    _text(d, (700, 360), "infrared:", F_SMALL, CYAN, "la")
    d.line([(700, 390), (900, 390)], fill=CYAN + (255,), width=4)
    d.polygon([(900, 390), (884, 383), (884, 397)], fill=CYAN + (255,))
    _text(d, (700, 404), "passes through, reaches us", F_SMALL, CYAN, "la")
    _text(d, (W / 2, 510), "Colours in JWST images are false-colour: they show infrared bands, not eye colours.", F_SMALL, MUTED, "ma")
    save(img, "jwst_spectrum")


# ---------------------------------------------------------------- 2. mirror
def mirror():
    img, d = _board()
    _text(d, (W / 2, 30), "18-SEGMENT GOLD PRIMARY MIRROR", F_TITLE, GOLD_HI, "ma")
    cx, cy, r = 380, 320, 52
    coords = []
    for q in range(-2, 3):
        for rr in range(-2, 3):
            if abs(q + rr) > 2:
                continue
            coords.append((q, rr))
    coords = [c for c in coords if c != (0, 0)][:18]
    w = r * math.sqrt(3)
    for (q, rr) in coords:
        x = cx + w * (q + rr / 2.0)
        yy = cy + r * 1.5 * rr
        _hex(d, x, yy, r * 0.96, GOLD, fill=(150, 120, 52), width=3)
        _hex(d, x, yy, r * 0.7, GOLD_HI, width=2)
    _text(d, (cx, cy + 210), "18 hexagonal beryllium segments,\ngold-coated for infrared", F_SMALL, GOLD_HI, "ma")
    # secondary mirror on tripod + light path
    sx, sy = 380, 120
    for a in (-0.7, 0.7, math.pi / 2):
        d.line([(cx + math.cos(a) * 150, cy + math.sin(a) * 90), (sx, sy)], fill=MUTED + (255,), width=3)
    d.ellipse([sx - 22, sy - 16, sx + 22, sy + 16], fill=(180, 190, 205, 255), outline=GOLD + (255,), width=3)
    _text(d, (sx + 34, sy - 8), "secondary mirror", F_SMALL, CYAN, "la")
    # incoming light + fold to instruments
    for k in range(-2, 3):
        d.line([(720, 150 + k * 20), (560, 300)], fill=CYAN + (200,), width=2)
    _text(d, (740, 150), "infrared light in", F_SMALL, CYAN, "la")
    d.line([(cx, cy), (cx, 470)], fill=CYAN + (255,), width=3)
    d.polygon([(cx, 470), (cx - 7, 454), (cx + 7, 454)], fill=CYAN + (255,))
    _text(d, (cx + 12, 450), "to instruments", F_SMALL, CYAN, "la")
    # wavefront note
    _text(d, (760, 300), "Each segment is nudged by\nactuators until 18 star images\nmerge into ONE sharp point\n(wavefront alignment).", F_SMALL, WHITE, "la")
    save(img, "jwst_mirror")


# ---------------------------------------------------------------- 3. L2 orbit
def l2():
    img, d = _board()
    _text(d, (W / 2, 26), "WHERE JWST LIVES: SUN-EARTH L2", F_TITLE, GOLD_HI, "ma")
    # Sun (left)
    sun = (110, 300)
    for r, c in [(70, (120, 80, 20)), (52, (200, 140, 40)), (38, (250, 210, 90))]:
        d.ellipse([sun[0] - r, sun[1] - r, sun[0] + r, sun[1] + r], fill=c + (255,))
    _text(d, (sun[0], sun[1] + 86), "SUN", F_LABEL, GOLD_HI, "ma")
    # Earth's orbit arc around the sun
    d.arc([sun[0] - 560, sun[1] - 230, sun[0] + 560, sun[1] + 230], 300, 60, fill=(60, 90, 140, 255), width=2)
    # Earth
    earth = (620, 300)
    d.ellipse([earth[0] - 26, earth[1] - 26, earth[0] + 26, earth[1] + 26], fill=(70, 120, 200, 255), outline=(150, 190, 255, 255), width=2)
    _text(d, (earth[0], earth[1] + 44), "EARTH", F_LABEL, BLUE, "ma")
    # Moon near Earth (same side, sunward-ish)
    moon = (556, 250)
    d.ellipse([moon[0] - 10, moon[1] - 10, moon[0] + 10, moon[1] + 10], fill=(180, 185, 195, 255))
    _text(d, (moon[0] - 4, moon[1] - 30), "Moon", F_SMALL, MUTED, "ma")
    # dashed Sun-Earth line extended to L2
    l2p = (860, 300)
    for x in range(sun[0], l2p[0], 22):
        d.line([(x, 300), (x + 11, 300)], fill=(90, 110, 150, 255), width=2)
    # distance bracket Earth -> L2
    d.line([(earth[0], 360), (l2p[0], 360)], fill=MUTED + (255,), width=2)
    _text(d, ((earth[0] + l2p[0]) / 2, 372), "~1.5 million km", F_SMALL, MUTED, "ma")
    # halo orbit ellipse around L2 (JWST orbits the SUN, loops around L2)
    d.ellipse([l2p[0] - 46, l2p[1] - 70, l2p[0] + 46, l2p[1] + 70], outline=CYAN + (255,), width=2)
    _text(d, (l2p[0], l2p[1] - 92), "L2  (halo orbit)", F_SMALL, CYAN, "ma")
    # JWST with sunshield facing the SUN/EARTH/MOON side
    jx, jy = l2p[0], l2p[1] - 40
    _hex(d, jx, jy - 6, 15, GOLD, fill=(150, 120, 52), width=2)
    for i in range(5):
        d.line([(jx - 42 + i * 3, jy + 20 + i * 5), (jx + 42 - i * 3, jy + 20 + i * 5)], fill=ORANGE + (255,), width=3)
    _text(d, (jx + 30, jy), "JWST", F_SMALL, GOLD_HI, "la")
    # sunshield always between the cold optics and Sun+Earth+Moon
    d.line([(sun[0] + 40, 300), (jx, jy + 30)], fill=(200, 150, 60, 120), width=1)
    _text(d, (W / 2, 470), "JWST ORBITS THE SUN near L2 - it does NOT orbit the Earth.", F_LABEL, GREEN, "ma")
    _text(d, (W / 2, 500), "The sunshield keeps the Sun, Earth and Moon all on one warm side; the mirror stays cold.", F_SMALL, MUTED, "ma")
    save(img, "jwst_l2")


# ---------------------------------------------------------------- 4. instruments
def instruments():
    img, d = _board()
    _text(d, (W / 2, 30), "FOUR SCIENCE INSTRUMENTS", F_TITLE, GOLD_HI, "ma")
    items = [
        ("NIRCam", "Near-infrared camera", "0.6-5 um imaging: stars, galaxies", ORANGE),
        ("NIRSpec", "Near-infrared spectrograph", "splits light: composition, redshift", BLUE),
        ("MIRI", "Mid-infrared, needs ~7 K", "5-28 um: cold dust, molecules", CYAN),
        ("FGS/NIRISS", "Fine guidance + niche imaging", "keeps pointing locked", GREEN),
    ]
    for i, (name, role, band, col) in enumerate(items):
        bx = 70 + (i % 2) * 470
        by = 96 + (i // 2) * 200
        d.rounded_rectangle([bx, by, bx + 420, by + 168], radius=12, fill=(18, 32, 54, 255), outline=col + (255,), width=3)
        # a small distinct glyph per instrument
        gx, gy = bx + 60, by + 84
        d.ellipse([gx - 38, gy - 38, gx + 38, gy + 38], outline=col + (255,), width=3)
        if name == "NIRCam":
            for a in range(3):
                for b in range(3):
                    d.rectangle([gx - 20 + a * 15, gy - 20 + b * 15, gx - 8 + a * 15, gy - 8 + b * 15], fill=col + (255,))
        elif name == "NIRSpec":
            for k in range(5):
                d.line([(gx - 24, gy - 20 + k * 10), (gx + 24, gy - 20 + k * 10)],
                       fill=(int(255 - k * 30), int(120 + k * 20), int(80 + k * 40), 255), width=4)
        elif name == "MIRI":
            for a in range(6):
                an = a * math.pi / 3
                d.line([(gx, gy), (gx + math.cos(an) * 30, gy + math.sin(an) * 30)], fill=col + (255,), width=3)
        else:
            d.line([(gx - 30, gy), (gx + 30, gy)], fill=col + (255,), width=2)
            d.line([(gx, gy - 30), (gx, gy + 30)], fill=col + (255,), width=2)
            d.rectangle([gx - 12, gy - 12, gx + 12, gy + 12], outline=col + (255,), width=3)
        _text(d, (bx + 120, by + 26), name, F_LABEL, col, "la")
        _text(d, (bx + 120, by + 60), role, F_SMALL, WHITE, "la")
        _text(d, (bx + 120, by + 92), band, F_SMALL, MUTED, "la")
    _text(d, (W / 2, 536), "The right instrument for the target decides your data - and your final SNR.", F_SMALL, MUTED, "ma")
    save(img, "jwst_instruments_diagram")


# ---------------------------------------------------------------- 5. false colour
def false_colour():
    img, d = _board()
    _text(d, (W / 2, 30), "FALSE-COLOUR: DATA, NOT A PHOTO", F_TITLE, GOLD_HI, "ma")
    filters = [("Near-IR filter", ORANGE, "R", RED), ("Mid-IR filter", BLUE, "G", GREEN), ("Dust filter", (120, 220, 180), "B", (110, 150, 255))]
    for i, (fname, fcol, chan, ccol) in enumerate(filters):
        y = 120 + i * 110
        d.rounded_rectangle([80, y, 300, y + 78], radius=10, fill=(18, 32, 54, 255), outline=fcol + (255,), width=3)
        _text(d, (190, y + 26), fname, F_SMALL, fcol, "ma")
        _text(d, (190, y + 50), "one infrared band", F_SMALL, MUTED, "ma")
        d.line([(300, y + 39), (430, y + 39)], fill=MUTED + (255,), width=3)
        d.polygon([(430, y + 39), (416, y + 32), (416, y + 46)], fill=MUTED + (255,))
        d.rounded_rectangle([440, y + 6, 540, y + 72], radius=8, fill=ccol + (255,))
        _text(d, (490, y + 39), chan, F_TITLE, (10, 15, 25), "mm")
    # composite
    d.rounded_rectangle([640, 130, 900, 430], radius=12, fill=(8, 14, 26, 255), outline=GOLD + (255,), width=3)
    import random
    rnd = random.Random(5)
    for _ in range(500):
        a = rnd.uniform(0, math.tau)
        rr = rnd.random() ** 0.5 * 120
        px, py = 770 + math.cos(a) * rr, 280 + math.sin(a) * rr * 0.9
        col = rnd.choice([(220, 120, 90), (120, 200, 140), (110, 150, 255), (240, 200, 150)])
        d.ellipse([px - 2, py - 2, px + 2, py + 2], fill=col + (255,))
    _text(d, (770, 446), "science image", F_SMALL, GOLD_HI, "ma")
    _text(d, (W / 2, 500), "Colours map infrared bands to R/G/B. Red does NOT mean the object is red -", F_SMALL, MUTED, "ma")
    _text(d, (W / 2, 526), "you read dust, gas and stars from the filter combination.", F_SMALL, MUTED, "ma")
    save(img, "jwst_false_colour_diagram")


def main():
    print("JWST teaching diagrams:")
    spectrum()
    mirror()
    l2()
    instruments()
    false_colour()
    print("done ->", OUT)


if __name__ == "__main__":
    main()
