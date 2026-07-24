"""
Generates the Space Infrared Observatory (JWST-class) and FAST radio part
sprites, plus their assembly blueprints.

  python tools/art/generate_space_fast_parts.py

Output:
  assets/telescope_parts/space_segmented/*.png   500x500 RGBA
  assets/telescope_parts/fast_radio/*.png        500x500 RGBA
  assets/assembly/*_blueprint.png                blueprint boards
  data/art_manifest.json                         manifest of every asset

All sprites are AGENT-DRAWN TEMPORARY ART (temporary_art: true in the
manifest) but are fully shaded, single-subject, transparent-background and
free of checkerboards, borders or baked text.
"""
from __future__ import annotations

import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelart_lib import *  # noqa: F401,F403

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
S = CANVAS * SS
C = S / 2.0

MANIFEST = []


# ============================================================ helpers
def _layer():
    return new_layer()


def _plate(layer, box, base, lit, radius=18, outline=NAVY_DARK, grain=True):
    """Shaded machined plate: vertical ramp + top highlight + dark base."""
    vertical_gradient(layer, box, lit, base, radius=radius)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=radius, outline=outline + (255,), width=6)
    x0, y0, x1, y1 = box
    d.line([(x0 + radius, y0 + 4), (x1 - radius, y0 + 4)],
           fill=lerp(lit, (255, 255, 255), 0.45) + (150,), width=5)


def _screen(layer, box, glow=CYAN, dark=(4, 16, 24), rows=None):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=10, fill=dark + (255,))
    d.rounded_rectangle(box, radius=10, outline=GOLD_DARK + (255,), width=5)
    if rows:
        rows(d, box)
    # glass sheen
    d.polygon([(x0 + 8, y1 - 8), (x0 + 8, y0 + 8), (x0 + (x1 - x0) * 0.45, y0 + 8)],
              fill=(255, 255, 255, 26))


def _cyl(layer, cx, cy, w, h, body=NAVY, lit=NAVY_LIT, cap=SILVER_MID):
    """Horizontal cylinder with an elliptical lit cap."""
    d = ImageDraw.Draw(layer)
    vertical_gradient(layer, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2),
                      lerp(lit, (255, 255, 255), 0.18), lerp(body, BLACK, 0.35))
    d.ellipse([cx + w / 2 - h * 0.22, cy - h / 2, cx + w / 2 + h * 0.22, cy + h / 2],
              fill=lerp(body, BLACK, 0.2) + (255,))
    d.ellipse([cx - w / 2 - h * 0.22, cy - h / 2, cx - w / 2 + h * 0.22, cy + h / 2],
              fill=cap + (255,))
    d.ellipse([cx - w / 2 - h * 0.13, cy - h * 0.34, cx - w / 2 + h * 0.13, cy + h * 0.34],
              fill=lerp(cap, BLACK, 0.5) + (255,))


def _strut(layer, p0, p1, w, c=SILVER_MID):
    d = ImageDraw.Draw(layer)
    d.line([p0, p1], fill=lerp(c, BLACK, 0.45) + (255,), width=int(w))
    d.line([p0, p1], fill=c + (255,), width=int(w * 0.55))


def save(layer, folder, name, note, kind, margin=16):
    img = noise_overlay(layer, amount=7, seed=hash(name) % 999)
    img = drop_shadow(img, offset=(9 * SS // 3, 12 * SS // 3), blur=16, alpha=105)
    img = finish(img)
    img = trim_to_canvas(img, margin=margin)
    out_dir = os.path.join(ROOT, folder)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".png")
    img.save(path)
    bbox = img.split()[3].getbbox()
    MANIFEST.append({
        "name": name + ".png",
        "path": (folder + "/" + name + ".png").replace("\\", "/"),
        "res_path": "res://" + (folder + "/" + name + ".png").replace("\\", "/"),
        "purpose": note,
        "kind": kind,
        "size": list(img.size),
        "content_bbox": list(bbox) if bbox else None,
        "transparent_background": True,
        "temporary_art": True,
        "status": "complete_usable_temporary",
    })
    print(f"  {name}.png  bbox={bbox}")


# ============================================================ SPACE PARTS
def segmented_primary_array():
    L = _layer()
    r = S * 0.115
    # JWST honeycomb: 18 segments, centre segment absent (secondary shadow)
    coords = []
    for q in range(-2, 3):
        for rr in range(-2, 3):
            if abs(q + rr) > 2:
                continue
            coords.append((q, rr))
    # drop the true centre and keep an 18-tile ring pattern
    coords = [c for c in coords if c != (0, 0)]
    coords = coords[:18]
    w = r * math.sqrt(3)
    for i, (q, rr) in enumerate(coords):
        x = C + w * (q + rr / 2.0)
        y = C + r * 1.5 * rr * 0.92
        gold_hex_segment(L, x, y, r * 0.97, seed=i, squash=0.92)
    L.alpha_composite(specular(S, C - S * 0.10, C - S * 0.12, S * 0.20, S * 0.11, 52, rot=-24))
    return L


def space_secondary_mirror():
    L = _layer()
    R = S * 0.20
    # support struts first (behind)
    for a in (-0.55, 0.55, math.pi / 2):
        _strut(L, (C + math.cos(a) * R * 2.5, C + math.sin(a) * R * 2.5 + S * 0.06),
               (C, C), S * 0.022, SILVER_MID)
    L.alpha_composite(contact_shadow(S, C, C + R * 0.9, R * 1.05, R * 0.3, 120))
    disc = bevel_disc(S, C, C, R,
                      [(0.0, GOLD_HI), (0.45, GOLD), (1.0, GOLD_MID)],
                      R * 0.16,
                      [(0.0, GOLD_MID), (0.5, SILVER_MID), (1.0, GOLD_DARK)],
                      squash=0.96)
    L.alpha_composite(disc)
    L.alpha_composite(specular(S, C - R * 0.34, C - R * 0.38, R * 0.42, R * 0.26, 128, rot=-30))
    rivets(L, ring_points(C, C, R * 0.9, 12, squash=0.96), S * 0.008)
    return L


def fine_steering_mirror():
    L = _layer()
    R = S * 0.145
    # gimbal yoke
    d = ImageDraw.Draw(L)
    d.arc([C - R * 1.5, C - R * 1.5, C + R * 1.5, C + R * 1.5], 200, 340,
          fill=SILVER_MID + (255,), width=int(S * 0.030))
    for s in (-1, 1):
        _cyl(L, C + s * R * 1.5, C + R * 0.15, R * 0.5, R * 0.34, NAVY, NAVY_LIT, COPPER)
    L.alpha_composite(bevel_disc(S, C, C - R * 0.1, R,
                                 [(0.0, SILVER_HI), (0.5, SILVER), (1.0, SILVER_DARK)],
                                 R * 0.15,
                                 [(0.0, GOLD), (1.0, GOLD_DARK)], squash=0.94))
    L.alpha_composite(specular(S, C - R * 0.3, C - R * 0.45, R * 0.36, R * 0.2, 140, rot=-28))
    # actuator legs
    for a in (-2.2, -0.94, 1.57):
        _strut(L, (C + math.cos(a) * R * 0.8, C + math.sin(a) * R * 0.8),
               (C + math.cos(a) * R * 1.9, C + math.sin(a) * R * 1.9 + S * 0.05),
               S * 0.018, COPPER)
    return L


def tertiary_mirror_module():
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.20, C - S * 0.14, C + S * 0.20, C + S * 0.17)
    _plate(L, box, NAVY, NAVY_LIT, radius=22)
    # angled mirror inside an open bay
    d.polygon([(C - S * 0.14, C + S * 0.10), (C + S * 0.02, C - S * 0.09),
               (C + S * 0.15, C - S * 0.03), (C - S * 0.02, C + S * 0.13)],
              fill=SILVER_MID + (255,))
    d.polygon([(C - S * 0.125, C + S * 0.095), (C + S * 0.017, C - S * 0.077),
               (C + S * 0.132, C - S * 0.026), (C - S * 0.014, C + S * 0.118)],
              fill=SILVER_HI + (255,))
    d.polygon([(C - S * 0.125, C + S * 0.095), (C + S * 0.017, C - S * 0.077),
               (C + S * 0.05, C - S * 0.055)], fill=(255, 255, 255, 90))
    rivets(L, [(box[0] + S * 0.03, box[1] + S * 0.03), (box[2] - S * 0.03, box[1] + S * 0.03),
               (box[0] + S * 0.03, box[3] - S * 0.03), (box[2] - S * 0.03, box[3] - S * 0.03)],
           S * 0.010)
    return L


def space_sunshield():
    L = _layer()
    d = ImageDraw.Draw(L)
    # five kite membranes, hottest (sun side) at the bottom
    tints = [(168, 142, 96), (150, 132, 104), (128, 124, 112), (108, 118, 122), (86, 110, 130)]
    for i in range(5):
        off = (4 - i) * S * 0.043
        span = S * 0.40 - i * S * 0.012
        pts = [(C - span, C + off), (C, C - S * 0.16 + off * 0.55),
               (C + span, C + off), (C, C + S * 0.20 + off * 0.55)]
        base = tints[i]
        d.polygon(pts, fill=lerp(base, BLACK, 0.42) + (255,))
        inner = [(C - span * 0.94, C + off), (C, C - S * 0.148 + off * 0.55),
                 (C + span * 0.94, C + off), (C, C + S * 0.185 + off * 0.55)]
        d.polygon(inner, fill=base + (255,))
        # membrane crease highlights
        for k in range(1, 5):
            t = k / 5.0
            x = C - span * 0.94 + span * 1.88 * t
            d.line([(x, C + off - S * 0.005), (C, C + S * 0.185 + off * 0.55)],
                   fill=lerp(base, (255, 255, 255), 0.30) + (70,), width=3)
        d.line([(C - span, C + off), (C, C - S * 0.16 + off * 0.55)],
               fill=lerp(base, (255, 255, 255), 0.5) + (170,), width=4)
    # spreader booms
    _strut(L, (C - S * 0.42, C + S * 0.175), (C + S * 0.42, C + S * 0.175), S * 0.020, SILVER_MID)
    return L


def space_telescope_bus():
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.19, C - S * 0.13, C + S * 0.19, C + S * 0.16)
    bevel_box(L, box, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.45), int(S * 0.045),
              outline=GOLD_DARK, radius=14)
    # thermal blanket quilting
    for i in range(1, 6):
        y = box[1] + (box[3] - box[1]) * i / 6.0
        d.line([(box[0] + 10, y), (box[2] - 10, y)], fill=lerp(NAVY, GOLD_DARK, 0.35) + (140,), width=4)
    for i in range(1, 5):
        x = box[0] + (box[2] - box[0]) * i / 5.0
        d.line([(x, box[1] + 10), (x, box[3] - 10)], fill=lerp(NAVY, GOLD_DARK, 0.28) + (110,), width=3)
    # propulsion nozzles
    for s in (-1, 1):
        d.polygon([(C + s * S * 0.10 - S * 0.022, box[3]), (C + s * S * 0.10 + S * 0.022, box[3]),
                   (C + s * S * 0.10 + S * 0.034, box[3] + S * 0.055),
                   (C + s * S * 0.10 - S * 0.034, box[3] + S * 0.055)],
                  fill=SILVER_DARK + (255,))
    rivets(L, [(box[0] + S * 0.022, box[1] + S * 0.022), (box[2] - S * 0.022, box[1] + S * 0.022),
               (box[0] + S * 0.022, box[3] - S * 0.022), (box[2] - S * 0.022, box[3] - S * 0.022)],
           S * 0.011)
    return L


def deployable_tower():
    L = _layer()
    # telescoping mast: three nested stages
    widths = [S * 0.115, S * 0.086, S * 0.060]
    ys = [(C + S * 0.20, C + S * 0.02), (C + S * 0.05, C - S * 0.12), (C - S * 0.09, C - S * 0.24)]
    for w, (y0, y1) in zip(widths, ys):
        vertical_gradient(L, (C - w, y1, C + w, y0), NAVY_LIT, lerp(NAVY, BLACK, 0.4), radius=12)
        d = ImageDraw.Draw(L)
        d.rounded_rectangle((C - w, y1, C + w, y0), radius=12, outline=GOLD_DARK + (255,), width=5)
        d.line([(C - w * 0.55, y1 + 8), (C - w * 0.55, y0 - 8)],
               fill=lerp(SILVER_MID, (255, 255, 255), 0.3) + (120,), width=5)
        rivets(L, [(C - w * 0.62, y1 + S * 0.016), (C + w * 0.62, y1 + S * 0.016)], S * 0.009)
    d = ImageDraw.Draw(L)
    d.rounded_rectangle((C - S * 0.16, C + S * 0.20, C + S * 0.16, C + S * 0.245),
                        radius=10, fill=lerp(GOLD_DARK, BLACK, 0.3) + (255,))
    return L


def deployment_hinges():
    L = _layer()
    d = ImageDraw.Draw(L)
    # two plates joined by a knuckle
    for ang, ox, oy in ((-0.36, -S * 0.115, -S * 0.02), (0.36, S * 0.115, -S * 0.02)):
        plate = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        _plate(plate, (C + ox - S * 0.115, C + oy - S * 0.045,
                       C + ox + S * 0.115, C + oy + S * 0.045),
               NAVY, NAVY_LIT, radius=12)
        plate = plate.rotate(math.degrees(ang), resample=Image.BICUBIC, center=(C, C))
        L.alpha_composite(plate)
    # knuckle barrel
    _cyl(L, C, C, S * 0.10, S * 0.075, SILVER_DARK, SILVER_MID, GOLD)
    d.ellipse([C - S * 0.020, C - S * 0.020, C + S * 0.020, C + S * 0.020],
              fill=lerp(GOLD_DARK, BLACK, 0.4) + (255,))
    rivets(L, [(C - S * 0.155, C - S * 0.055), (C + S * 0.155, C - S * 0.055)], S * 0.011)
    return L


def _instrument(accent, glyph, seed, tall=False):
    """Shared chassis for the four science instruments; accent = optics colour."""
    L = _layer()
    d = ImageDraw.Draw(L)
    w, h = (S * 0.165, S * 0.20) if tall else (S * 0.19, S * 0.165)
    box = (C - w, C - h, C + w, C + h)
    bevel_box(L, box, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.5), int(S * 0.040),
              outline=GOLD_DARK, radius=16)
    # cold aperture
    ar = min(w, h) * 0.52
    L.alpha_composite(bevel_disc(S, C, C - h * 0.16, ar,
                                 [(0.0, lerp(accent, (255, 255, 255), 0.5)),
                                  (0.45, accent), (1.0, lerp(accent, BLACK, 0.55))],
                                 ar * 0.20,
                                 [(0.0, GOLD), (1.0, GOLD_DARK)], squash=0.95))
    L.alpha_composite(specular(S, C - ar * 0.32, C - h * 0.16 - ar * 0.34,
                               ar * 0.34, ar * 0.19, 130, rot=-30))
    # radiator fins along the bottom
    for i in range(6):
        x = box[0] + w * 0.18 + i * (w * 1.64 / 6.0)
        d.rectangle([x, C + h * 0.42, x + w * 0.10, C + h * 0.86],
                    fill=lerp(SILVER_MID, BLACK, 0.25) + (255,))
        d.line([(x, C + h * 0.42), (x, C + h * 0.86)], fill=SILVER_HI + (160,), width=3)
    # harness connector
    d.rounded_rectangle([box[2] - w * 0.26, box[1] + h * 0.16, box[2] + w * 0.16, box[1] + h * 0.52],
                        radius=8, fill=COPPER + (255,))
    # glyph badge: distinguishes the four instruments without baked words
    gx, gy, gr = C + w * 0.52, C + h * 0.10, min(w, h) * 0.20
    d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=lerp(accent, BLACK, 0.55) + (255,))
    d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], outline=GOLD + (255,), width=4)
    rnd = random.Random(seed)
    if glyph == "grid":                       # NIRCam - imaging pixels
        for i in range(3):
            for j in range(3):
                d.rectangle([gx - gr * 0.6 + i * gr * 0.42, gy - gr * 0.6 + j * gr * 0.42,
                             gx - gr * 0.6 + i * gr * 0.42 + gr * 0.28,
                             gy - gr * 0.6 + j * gr * 0.42 + gr * 0.28],
                            fill=lerp(accent, (255, 255, 255), 0.5) + (255,))
    elif glyph == "prism":                    # NIRSpec - dispersed spectrum
        for i in range(5):
            d.line([(gx - gr * 0.6, gy - gr * 0.5 + i * gr * 0.25),
                    (gx + gr * 0.6, gy - gr * 0.5 + i * gr * 0.25)],
                   fill=lerp((255, 90, 60), (90, 160, 255), i / 4.0) + (255,), width=5)
    elif glyph == "cryo":                     # MIRI - cold / snowflake
        for a in range(6):
            an = a * math.pi / 3
            d.line([(gx, gy), (gx + math.cos(an) * gr * 0.66, gy + math.sin(an) * gr * 0.66)],
                   fill=CYAN_HI + (255,), width=4)
    else:                                     # FGS/NIRISS - guide reticle
        d.ellipse([gx - gr * 0.42, gy - gr * 0.42, gx + gr * 0.42, gy + gr * 0.42],
                  outline=GREEN_OK + (255,), width=4)
        d.line([(gx - gr * 0.72, gy), (gx + gr * 0.72, gy)], fill=GREEN_OK + (255,), width=3)
        d.line([(gx, gy - gr * 0.72), (gx, gy + gr * 0.72)], fill=GREEN_OK + (255,), width=3)
    return L


def solar_array():
    L = _layer()
    d = ImageDraw.Draw(L)
    # tilted photovoltaic wing
    wing = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wing)
    x0, y0, x1, y1 = C - S * 0.30, C - S * 0.135, C + S * 0.30, C + S * 0.135
    vertical_gradient(wing, (x0, y0, x1, y1), (44, 62, 108), (16, 26, 52), radius=8)
    cols, rows_n = 8, 3
    for i in range(cols):
        for j in range(rows_n):
            cx0 = x0 + 10 + i * (x1 - x0 - 20) / cols
            cy0 = y0 + 10 + j * (y1 - y0 - 20) / rows_n
            cw = (x1 - x0 - 20) / cols - 8
            ch = (y1 - y0 - 20) / rows_n - 8
            shade = 0.10 + 0.16 * ((i + j) % 2)
            wd.rectangle([cx0, cy0, cx0 + cw, cy0 + ch],
                         fill=lerp((58, 86, 150), (22, 34, 70), shade) + (255,))
            wd.line([(cx0, cy0), (cx0 + cw, cy0)], fill=(150, 190, 255, 120), width=3)
    wd.rounded_rectangle([x0, y0, x1, y1], radius=8, outline=GOLD_DARK + (255,), width=6)
    wing = wing.rotate(-13, resample=Image.BICUBIC, center=(C, C))
    L.alpha_composite(wing)
    L.alpha_composite(specular(S, C - S * 0.12, C - S * 0.07, S * 0.19, S * 0.055, 44, rot=-13))
    # yoke
    _strut(L, (C - S * 0.30, C + S * 0.10), (C - S * 0.40, C + S * 0.17), S * 0.024, SILVER_MID)
    return L


def communication_antenna():
    L = _layer()
    R = S * 0.185
    L.alpha_composite(contact_shadow(S, C, C + R * 0.95, R, R * 0.26, 110))
    dish = radial_metal(S, 0, R, [(0.0, SILVER_HI), (0.55, SILVER), (1.0, SILVER_DARK)],
                        streaks=12, streak_seed=5, center=(C, C - S * 0.02), squash=0.82)
    L.alpha_composite(dish)
    d = ImageDraw.Draw(L)
    d.ellipse([C - R, C - S * 0.02 - R * 0.82, C + R, C - S * 0.02 + R * 0.82],
              outline=GOLD + (255,), width=int(S * 0.016))
    L.alpha_composite(specular(S, C - R * 0.35, C - R * 0.42, R * 0.40, R * 0.22, 120, rot=-30))
    # feed horn on a tripod
    for a in (-2.4, -0.75, 1.6):
        _strut(L, (C + math.cos(a) * R * 0.72, C - S * 0.02 + math.sin(a) * R * 0.58),
               (C, C - S * 0.20), S * 0.014, SILVER_MID)
    d.polygon([(C - S * 0.030, C - S * 0.185), (C + S * 0.030, C - S * 0.185),
               (C + S * 0.018, C - S * 0.245), (C - S * 0.018, C - S * 0.245)],
              fill=GOLD + (255,))
    # mast
    _cyl(L, C, C + R * 0.92, S * 0.045, S * 0.055, NAVY, NAVY_LIT, GOLD_DARK)
    return L


def thermal_radiator():
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.21, C - S * 0.155, C + S * 0.21, C + S * 0.155)
    _plate(L, box, lerp(SILVER_DARK, NAVY, 0.4), SILVER_MID, radius=14)
    # vertical heat-rejection fins
    n = 11
    for i in range(n):
        x = box[0] + S * 0.022 + i * (S * 0.42 - S * 0.044) / (n - 1)
        vertical_gradient(L, (x - S * 0.010, box[1] + S * 0.020, x + S * 0.010, box[3] - S * 0.020),
                          SILVER_HI, SILVER_DARK)
        d.line([(x - S * 0.010, box[1] + S * 0.020), (x - S * 0.010, box[3] - S * 0.020)],
               fill=(255, 255, 255, 130), width=3)
    # cold plumbing
    d.line([(box[0] + S * 0.03, box[3] + S * 0.006), (box[2] - S * 0.03, box[3] + S * 0.006)],
           fill=COPPER + (255,), width=int(S * 0.016))
    return L


def instrument_bay():
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.225, C - S * 0.17, C + S * 0.225, C + S * 0.17)
    bevel_box(L, box, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.5), int(S * 0.038),
              outline=GOLD_DARK, radius=16)
    # four empty instrument slots with rails
    for i in range(2):
        for j in range(2):
            sx = box[0] + S * 0.030 + i * S * 0.215
            sy = box[1] + S * 0.030 + j * S * 0.160
            d.rounded_rectangle([sx, sy, sx + S * 0.185, sy + S * 0.128], radius=10,
                                fill=lerp(BLACK, NAVY, 0.35) + (255,))
            d.rounded_rectangle([sx, sy, sx + S * 0.185, sy + S * 0.128], radius=10,
                                outline=lerp(GOLD_DARK, SILVER_DARK, 0.4) + (255,), width=4)
            d.line([(sx + S * 0.012, sy + S * 0.114), (sx + S * 0.173, sy + S * 0.114)],
                   fill=SILVER_MID + (200,), width=4)
            d.ellipse([sx + S * 0.150, sy + S * 0.012, sx + S * 0.170, sy + S * 0.032],
                      fill=CYAN_DARK + (255,))
    return L


def infrared_detector_module():
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.175, C - S * 0.145, C + S * 0.175, C + S * 0.145)
    _plate(L, box, lerp(NAVY, BLACK, 0.35), NAVY_LIT, radius=12)
    # detector die: HgCdTe mosaic under a cold shield
    dbox = (C - S * 0.115, C - S * 0.095, C + S * 0.115, C + S * 0.095)
    vertical_gradient(L, dbox, (52, 46, 70), (16, 14, 26), radius=6)
    for i in range(4):
        for j in range(4):
            cx0 = dbox[0] + 8 + i * (S * 0.23 - 16) / 4
            cy0 = dbox[1] + 8 + j * (S * 0.19 - 16) / 4
            cw = (S * 0.23 - 16) / 4 - 6
            ch = (S * 0.19 - 16) / 4 - 6
            t = ((i * 3 + j * 5) % 7) / 7.0
            d.rectangle([cx0, cy0, cx0 + cw, cy0 + ch],
                        fill=lerp((92, 74, 120), (34, 30, 56), t) + (255,))
    d.rounded_rectangle(dbox, radius=6, outline=GOLD + (255,), width=5)
    L.alpha_composite(specular(S, C - S * 0.06, C - S * 0.055, S * 0.075, S * 0.030, 66, rot=-22))
    # gold bond wires to the flex harness
    for i in range(7):
        x = dbox[0] + S * 0.020 + i * S * 0.032
        d.line([(x, dbox[3]), (x + S * 0.010, box[3] - S * 0.014)], fill=GOLD_HI + (220,), width=3)
    return L


# ============================================================ FAST PARTS
def fast_active_dish():
    L = _layer()
    R = S * 0.285
    L.alpha_composite(contact_shadow(S, C, C + R * 0.62, R * 1.0, R * 0.22, 130))
    # karst-valley parabolic bowl: dark rim, brighter concave centre
    bowl = radial_metal(S, 0, R, [(0.0, lerp(SILVER_MID, NAVY, 0.30)),
                                  (0.42, lerp(SILVER, NAVY, 0.12)),
                                  (0.80, SILVER_MID), (1.0, SILVER_DARK)],
                        streaks=9, streak_seed=11, center=(C, C), squash=0.58)
    L.alpha_composite(bowl)
    d = ImageDraw.Draw(L)
    # triangular panel tessellation
    rnd = random.Random(4)
    for ring in range(1, 6):
        rr = R * ring / 5.0
        n = 10 + ring * 6
        pts = ring_points(C, C, rr, n, squash=0.58)
        for i, p in enumerate(pts):
            q = pts[(i + 1) % n]
            d.line([p, q], fill=lerp(SILVER_DARK, BLACK, 0.25) + (150,), width=3)
        if ring < 5:
            outer = ring_points(C, C, R * (ring + 1) / 5.0, n, squash=0.58)
            for i in range(0, n, 1):
                d.line([pts[i], outer[i]], fill=lerp(SILVER_DARK, BLACK, 0.2) + (120,), width=3)
    d.ellipse([C - R, C - R * 0.58, C + R, C + R * 0.58], outline=GOLD_DARK + (255,), width=int(S * 0.014))
    L.alpha_composite(specular(S, C - R * 0.30, C - R * 0.16, R * 0.42, R * 0.14, 62, rot=-12))
    # feed cabin suspended above the bowl
    for sx in (-1, 1):
        _strut(L, (C + sx * R * 0.98, C - R * 0.34), (C, C - R * 0.60), S * 0.010, SILVER_MID)
    d.rounded_rectangle([C - S * 0.045, C - R * 0.66, C + S * 0.045, C - R * 0.55],
                        radius=8, fill=GOLD + (255,))
    return L


def reflector_panel_segment():
    L = _layer()
    d = ImageDraw.Draw(L)
    # a single triangular perforated aluminium panel, ¾ view
    pts = [(C - S * 0.24, C + S * 0.14), (C + S * 0.24, C + S * 0.14), (C, C - S * 0.19)]
    d.polygon(pts, fill=SILVER_DARK + (255,))
    inner = [(C - S * 0.215, C + S * 0.125), (C + S * 0.215, C + S * 0.125), (C, C - S * 0.165)]
    d.polygon(inner, fill=SILVER_MID + (255,))
    # sheen gradient across the face
    for i in range(14):
        t = i / 14.0
        y = C - S * 0.165 + t * S * 0.29
        halfw = S * 0.215 * t
        d.line([(C - halfw, y), (C + halfw, y)],
               fill=lerp(SILVER_HI, SILVER_DARK, t * 0.85) + (255,), width=int(S * 0.023))
    # perforation grid
    rnd = random.Random(9)
    for j in range(9):
        t = (j + 1) / 10.0
        y = C - S * 0.155 + t * S * 0.275
        halfw = S * 0.195 * t
        n = max(2, int(halfw / (S * 0.020)))
        for k in range(-n, n + 1):
            x = C + k * S * 0.020
            d.ellipse([x - S * 0.0045, y - S * 0.0045, x + S * 0.0045, y + S * 0.0045],
                      fill=lerp(SILVER_DARK, BLACK, 0.55) + (200,))
    d.polygon(pts, outline=GOLD_DARK + (255,), width=6)
    rivets(L, [(C - S * 0.215, C + S * 0.115), (C + S * 0.215, C + S * 0.115), (C, C - S * 0.155)],
           S * 0.011)
    return L


def panel_actuator():
    L = _layer()
    d = ImageDraw.Draw(L)
    # screw-jack actuator: motor can + extending rod + clevis
    _cyl(L, C, C + S * 0.10, S * 0.20, S * 0.115, NAVY, NAVY_LIT, COPPER)
    for i in range(5):
        y = C + S * 0.055 + i * S * 0.018
        d.line([(C - S * 0.095, y), (C + S * 0.095, y)], fill=lerp(NAVY, BLACK, 0.5) + (170,), width=3)
    # rod
    vertical_gradient(L, (C - S * 0.026, C - S * 0.20, C + S * 0.026, C + S * 0.05),
                      SILVER_HI, SILVER_DARK, radius=8)
    d.rounded_rectangle((C - S * 0.026, C - S * 0.20, C + S * 0.026, C + S * 0.05),
                        radius=8, outline=SILVER_DARK + (255,), width=4)
    # thread detail
    for i in range(9):
        y = C - S * 0.185 + i * S * 0.020
        d.line([(C - S * 0.026, y), (C + S * 0.026, y - S * 0.006)], fill=(255, 255, 255, 90), width=3)
    # clevis head
    d.rounded_rectangle((C - S * 0.052, C - S * 0.245, C + S * 0.052, C - S * 0.185),
                        radius=10, fill=GOLD + (255,))
    d.ellipse([C - S * 0.019, C - S * 0.228, C + S * 0.019, C - S * 0.190],
              fill=lerp(BLACK, NAVY, 0.3) + (255,))
    return L


def suspended_feed_cabin():
    L = _layer()
    d = ImageDraw.Draw(L)
    # six support cables converging upward
    for i, sx in enumerate((-1.0, -0.55, -0.18, 0.18, 0.55, 1.0)):
        d.line([(C + sx * S * 0.40, C - S * 0.34), (C + sx * S * 0.115, C - S * 0.075)],
               fill=lerp(SILVER_MID, NAVY, 0.35) + (230,), width=4)
    # cabin body: hexagonal drum
    pts = hexagon(C, C + S * 0.02, S * 0.155, rot=math.pi / 6, squash=0.82)
    d.polygon(pts, fill=lerp(NAVY, BLACK, 0.35) + (255,))
    inner = hexagon(C, C + S * 0.02, S * 0.140, rot=math.pi / 6, squash=0.82)
    d.polygon(inner, fill=NAVY + (255,))
    for i in range(8):
        t = i / 8.0
        d.polygon(hexagon(C + LIGHT[0] * S * 0.012 * t, C + S * 0.02 + LIGHT[1] * S * 0.012 * t,
                          S * 0.140 * (1 - t * 0.9), rot=math.pi / 6, squash=0.82),
                  fill=lerp(NAVY_LIT, NAVY, t) + (255,))
    d.polygon(pts, outline=GOLD + (255,), width=6)
    # receiver drum underneath
    _cyl(L, C, C + S * 0.155, S * 0.115, S * 0.070, SILVER_DARK, SILVER_MID, GOLD)
    d.ellipse([C - S * 0.040, C + S * 0.185, C + S * 0.040, C + S * 0.225],
              fill=lerp(CYAN_DARK, BLACK, 0.35) + (255,))
    # status lamps
    for k, col in enumerate((GREEN_OK, CYAN, GOLD)):
        d.ellipse([C - S * 0.060 + k * S * 0.058, C - S * 0.045,
                   C - S * 0.036 + k * S * 0.058, C - S * 0.021], fill=col + (255,))
    return L


def feed_cabin_receiver():
    L = _layer()
    d = ImageDraw.Draw(L)
    # corrugated feed horn pointing down-left, on a cooled base
    box = (C - S * 0.145, C - S * 0.02, C + S * 0.145, C + S * 0.175)
    _plate(L, box, lerp(NAVY, BLACK, 0.3), NAVY_LIT, radius=14)
    horn = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(horn)
    for i in range(11):
        t = i / 10.0
        halfw = S * 0.035 + t * S * 0.105
        y = C - S * 0.045 - t * S * 0.175
        c = lerp(SILVER_HI, SILVER_DARK, t * 0.8)
        hd.ellipse([C - halfw, y - S * 0.020, C + halfw, y + S * 0.020], fill=c + (255,))
    hd.ellipse([C - S * 0.140, C - S * 0.245, C + S * 0.140, C - S * 0.190],
               fill=lerp(CYAN_DARK, BLACK, 0.45) + (255,))
    hd.ellipse([C - S * 0.140, C - S * 0.245, C + S * 0.140, C - S * 0.190],
               outline=GOLD + (255,), width=6)
    L.alpha_composite(horn)
    L.alpha_composite(specular(S, C - S * 0.055, C - S * 0.165, S * 0.055, S * 0.022, 110, rot=-18))
    # cryo lines
    for sx in (-1, 1):
        d.line([(C + sx * S * 0.10, C + S * 0.02), (C + sx * S * 0.16, C + S * 0.16)],
               fill=COPPER + (255,), width=int(S * 0.014))
    return L


def feed_cabin_cable_system():
    L = _layer()
    d = ImageDraw.Draw(L)
    # three tower heads with pulleys and catenary cables
    for i, sx in enumerate((-1, 0, 1)):
        tx = C + sx * S * 0.235
        ty = C - S * 0.155 + abs(sx) * S * 0.035
        _cyl(L, tx, ty, S * 0.055, S * 0.055, NAVY, NAVY_LIT, SILVER_MID)
        L.alpha_composite(bevel_disc(S, tx, ty, S * 0.048,
                                     [(0.0, SILVER_HI), (1.0, SILVER_DARK)],
                                     S * 0.014, [(0.0, GOLD), (1.0, GOLD_DARK)]))
        d.ellipse([tx - S * 0.012, ty - S * 0.012, tx + S * 0.012, ty + S * 0.012],
                  fill=lerp(BLACK, NAVY, 0.3) + (255,))
    # catenaries down to a common node
    node = (C, C + S * 0.175)
    for sx in (-1, 0, 1):
        tx = C + sx * S * 0.235
        ty = C - S * 0.155 + abs(sx) * S * 0.035
        pts = []
        for k in range(21):
            t = k / 20.0
            x = tx + (node[0] - tx) * t
            y = ty + (node[1] - ty) * t + math.sin(t * math.pi) * S * 0.045
            pts.append((x, y))
        d.line(pts, fill=lerp(SILVER_MID, NAVY, 0.25) + (255,), width=6)
        d.line(pts, fill=SILVER_HI + (120,), width=2)
    _cyl(L, node[0], node[1], S * 0.115, S * 0.058, NAVY, NAVY_LIT, GOLD)
    return L


def cable_tension_controller():
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.20, C - S * 0.145, C + S * 0.20, C + S * 0.155)
    _plate(L, box, NAVY, NAVY_LIT, radius=16)
    # winch drum with wound cable
    _cyl(L, C - S * 0.045, C + S * 0.035, S * 0.185, S * 0.115, SILVER_DARK, SILVER_MID, GOLD)
    for i in range(12):
        x = C - S * 0.135 + i * S * 0.0155
        d.line([(x, C - S * 0.020), (x, C + S * 0.090)], fill=lerp(COPPER, BLACK, 0.30) + (230,), width=4)
    # tension gauge
    gx, gy, gr = C + S * 0.128, C - S * 0.070, S * 0.055
    d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=lerp(BLACK, NAVY, 0.35) + (255,))
    d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], outline=GOLD + (255,), width=5)
    d.arc([gx - gr * 0.68, gy - gr * 0.68, gx + gr * 0.68, gy + gr * 0.68], 150, 30,
          fill=GREEN_OK + (255,), width=5)
    d.line([(gx, gy), (gx + math.cos(-0.9) * gr * 0.6, gy + math.sin(-0.9) * gr * 0.6)],
           fill=RED_WARN + (255,), width=5)
    return L


def _rack(title_rows, accent=CYAN, seed=1, knobs=3):
    """Shared control-rack chassis for the FAST electronics."""
    L = _layer()
    d = ImageDraw.Draw(L)
    box = (C - S * 0.205, C - S * 0.185, C + S * 0.205, C + S * 0.185)
    bevel_box(L, box, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.5), int(S * 0.036),
              outline=GOLD_DARK, radius=16)
    scr = (box[0] + S * 0.030, box[1] + S * 0.030, box[2] - S * 0.030, box[1] + S * 0.215)
    _screen(L, scr, glow=accent, rows=title_rows)
    # ventilation + knobs strip
    for i in range(knobs):
        kx = box[0] + S * 0.055 + i * S * 0.085
        ky = box[3] - S * 0.070
        d.ellipse([kx - S * 0.026, ky - S * 0.026, kx + S * 0.026, ky + S * 0.026],
                  fill=lerp(SILVER_MID, BLACK, 0.35) + (255,))
        d.ellipse([kx - S * 0.026, ky - S * 0.026, kx + S * 0.026, ky + S * 0.026],
                  outline=GOLD + (255,), width=4)
        d.line([(kx, ky), (kx + math.cos(-1.1 + i) * S * 0.017, ky + math.sin(-1.1 + i) * S * 0.017)],
               fill=GOLD_HI + (255,), width=4)
    for i in range(7):
        vx = box[2] - S * 0.130 + i * S * 0.016
        d.line([(vx, box[3] - S * 0.098), (vx, box[3] - S * 0.032)],
               fill=lerp(BLACK, NAVY, 0.35) + (255,), width=4)
    rivets(L, [(box[0] + S * 0.020, box[1] + S * 0.020), (box[2] - S * 0.020, box[1] + S * 0.020),
               (box[0] + S * 0.020, box[3] - S * 0.020), (box[2] - S * 0.020, box[3] - S * 0.020)],
           S * 0.010)
    return L


def _rows_spectrum(d, box):
    x0, y0, x1, y1 = box
    rnd = random.Random(21)
    base = y1 - S * 0.018
    n = 46
    for i in range(n):
        x = x0 + S * 0.014 + i * (x1 - x0 - S * 0.028) / n
        h = rnd.uniform(0.05, 0.30) * (y1 - y0)
        if i in (12, 13, 29):
            h = (y1 - y0) * rnd.uniform(0.55, 0.82)
        col = CYAN if i not in (12, 13, 29) else GOLD_HI
        d.line([(x, base), (x, base - h)], fill=col + (255,), width=4)
    d.line([(x0 + S * 0.010, base), (x1 - S * 0.010, base)], fill=CYAN_DARK + (255,), width=3)


def _rows_pulse(d, box):
    x0, y0, x1, y1 = box
    mid = (y0 + y1) / 2.0
    pts = []
    for i in range(120):
        t = i / 119.0
        x = x0 + S * 0.012 + t * (x1 - x0 - S * 0.024)
        ph = (t * 3.0) % 1.0
        y = mid - (max(0.0, math.sin(ph * math.pi)) ** 14) * (y1 - y0) * 0.40
        y += math.sin(t * 40) * (y1 - y0) * 0.03
        pts.append((x, y))
    d.line(pts, fill=GREEN_OK + (255,), width=4)


def _rows_rfi(d, box):
    x0, y0, x1, y1 = box
    base = y1 - S * 0.018
    rnd = random.Random(33)
    for i in range(40):
        x = x0 + S * 0.014 + i * (x1 - x0 - S * 0.028) / 40
        h = rnd.uniform(0.04, 0.18) * (y1 - y0)
        d.line([(x, base), (x, base - h)], fill=CYAN_DARK + (255,), width=4)
    for xf, col in ((0.28, RED_WARN), (0.52, RED_WARN), (0.78, GOLD_HI)):
        x = x0 + S * 0.014 + xf * (x1 - x0 - S * 0.028)
        d.line([(x, base), (x, y0 + S * 0.020)], fill=col + (255,), width=6)
        d.ellipse([x - S * 0.010, y0 + S * 0.012, x + S * 0.010, y0 + S * 0.032], fill=col + (255,))


def _rows_timing(d, box):
    x0, y0, x1, y1 = box
    for j in range(5):
        y = y0 + S * 0.020 + j * (y1 - y0 - S * 0.040) / 4
        d.line([(x0 + S * 0.014, y), (x1 - S * 0.014, y)], fill=CYAN_DARK + (200,), width=3)
    rnd = random.Random(12)
    for j in range(5):
        y = y0 + S * 0.020 + j * (y1 - y0 - S * 0.040) / 4
        x = x0 + S * 0.030 + (0.34 + rnd.uniform(-0.02, 0.02)) * (x1 - x0)
        d.ellipse([x - S * 0.009, y - S * 0.009, x + S * 0.009, y + S * 0.009], fill=GOLD_HI + (255,))


def _rows_data(d, box):
    x0, y0, x1, y1 = box
    rnd = random.Random(77)
    for j in range(6):
        y = y0 + S * 0.018 + j * (y1 - y0 - S * 0.036) / 5
        w = rnd.uniform(0.25, 0.86) * (x1 - x0 - S * 0.030)
        d.line([(x0 + S * 0.015, y), (x0 + S * 0.015 + w, y)], fill=GREEN_OK + (215,), width=5)
    d.rectangle([x1 - S * 0.050, y0 + S * 0.016, x1 - S * 0.018, y0 + S * 0.048],
                fill=GOLD_HI + (255,))


def _rows_terminal(d, box):
    x0, y0, x1, y1 = box
    rnd = random.Random(55)
    for j in range(7):
        y = y0 + S * 0.016 + j * (y1 - y0 - S * 0.032) / 6
        segs = rnd.randint(2, 4)
        x = x0 + S * 0.016
        for _ in range(segs):
            w = rnd.uniform(0.08, 0.26) * (x1 - x0)
            d.line([(x, y), (x + w, y)], fill=CYAN + (200,), width=4)
            x += w + S * 0.018
    d.rectangle([x0 + S * 0.016, y1 - S * 0.034, x0 + S * 0.034, y1 - S * 0.014],
                fill=CYAN_HI + (255,))


# ============================================================ BLUEPRINTS
def blueprint(width, height, title_slots, seed=1):
    """Navy grid board with cyan line art + dashed slot boxes (no baked text)."""
    W, H = width, height
    img = Image.new("RGBA", (W, H), (10, 20, 38, 255))
    d = ImageDraw.Draw(img)
    for x in range(0, W, 26):
        d.line([(x, 0), (x, H)], fill=(28, 54, 92, 255), width=1)
    for y in range(0, H, 26):
        d.line([(0, y), (W, y)], fill=(28, 54, 92, 255), width=1)
    for x in range(0, W, 130):
        d.line([(x, 0), (x, H)], fill=(38, 74, 122, 255), width=2)
    for y in range(0, H, 130):
        d.line([(0, y), (W, y)], fill=(38, 74, 122, 255), width=2)
    return img, d


def dashed_rect(d, box, color=(97, 216, 255), width=3, dash=14, gap=10):
    x0, y0, x1, y1 = box
    def seg(a, b, horiz):
        pos = a
        while pos < b:
            end = min(pos + dash, b)
            if horiz:
                d.line([(pos, y0), (end, y0)], fill=color + (255,), width=width)
                d.line([(pos, y1), (end, y1)], fill=color + (255,), width=width)
            else:
                d.line([(x0, pos), (x0, end)], fill=color + (255,), width=width)
                d.line([(x1, pos), (x1, end)], fill=color + (255,), width=width)
            pos = end + gap
    seg(x0, x1, True)
    seg(y0, y1, False)


def save_blueprint(img, name, note, slots):
    out_dir = os.path.join(ROOT, "assets", "assembly")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".png")
    img.save(path)
    MANIFEST.append({
        "name": name + ".png",
        "path": "assets/assembly/" + name + ".png",
        "res_path": "res://assets/assembly/" + name + ".png",
        "purpose": note,
        "kind": "assembly_blueprint",
        "size": list(img.size),
        "slots": slots,
        "transparent_background": False,
        "temporary_art": True,
        "status": "complete_usable_temporary",
    })
    print(f"  {name}.png  {img.size} slots={len(slots)}")
