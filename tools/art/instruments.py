"""
Distinct silhouettes for the four JWST science instruments plus the ISIM
package. Each one is built from different hardware, not a recoloured box:

  NIRCam   - twin imaging modules side by side, coronagraph mask wheel
  NIRSpec  - wide spectrograph body, micro-shutter grid, dispersing prism wedge
  MIRI     - tall cryostat drum, cooler lines, heat exchanger stack
  FGS/NIRISS - twin small apertures on a guider bench with a reticle window
  ISIM     - open frame holding four instrument bays
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelart_lib import *  # noqa: F401,F403
from generate_space_fast_parts import _plate, _cyl, _strut, S, C, _screen


def _cold_aperture(L, cx, cy, r, accent, squash=0.95):
    L.alpha_composite(bevel_disc(S, cx, cy, r,
                                 [(0.0, lerp(accent, (255, 255, 255), 0.55)),
                                  (0.42, accent), (1.0, lerp(accent, BLACK, 0.6))],
                                 r * 0.20, [(0.0, GOLD), (1.0, GOLD_DARK)], squash=squash))
    L.alpha_composite(specular(S, cx - r * 0.34, cy - r * 0.36, r * 0.34, r * 0.18, 130, rot=-30))


def _fins(L, x0, x1, y0, y1, n=6):
    d = ImageDraw.Draw(L)
    for i in range(n):
        x = x0 + i * (x1 - x0) / n
        w = (x1 - x0) / n * 0.55
        vertical_gradient(L, (x, y0, x + w, y1), SILVER_HI, SILVER_DARK)
        d.line([(x, y0), (x, y1)], fill=(255, 255, 255, 150), width=3)


def nircam():
    """Twin imaging modules + filter/coronagraph wheel."""
    L = new_layer()
    d = ImageDraw.Draw(L)
    accent = (236, 150, 90)
    body = (C - S * 0.215, C - S * 0.115, C + S * 0.215, C + S * 0.145)
    bevel_box(L, body, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.5), int(S * 0.038),
              outline=GOLD_DARK, radius=14)
    # two identical optical modules (NIRCam is a two-module instrument)
    for sx in (-1, 1):
        cx = C + sx * S * 0.105
        _cyl(L, cx, C - S * 0.145, S * 0.115, S * 0.085, NAVY, NAVY_LIT, SILVER_MID)
        _cold_aperture(L, cx, C - S * 0.030, S * 0.072, accent)
    # filter wheel on the right flank
    wx, wy, wr = C + S * 0.205, C + S * 0.055, S * 0.072
    L.alpha_composite(bevel_disc(S, wx, wy, wr,
                                 [(0.0, SILVER), (1.0, SILVER_DARK)],
                                 wr * 0.22, [(0.0, GOLD), (1.0, GOLD_DARK)]))
    for i in range(8):
        a = i * math.pi / 4
        d.ellipse([wx + math.cos(a) * wr * 0.55 - wr * 0.16,
                   wy + math.sin(a) * wr * 0.55 - wr * 0.16,
                   wx + math.cos(a) * wr * 0.55 + wr * 0.16,
                   wy + math.sin(a) * wr * 0.55 + wr * 0.16],
                  fill=lerp(accent, BLACK, 0.35 + 0.06 * i) + (255,))
    _fins(L, body[0] + S * 0.03, body[2] - S * 0.10, C + S * 0.085, C + S * 0.135, 5)
    rivets(L, [(body[0] + S * 0.020, body[1] + S * 0.020), (body[2] - S * 0.020, body[1] + S * 0.020),
               (body[0] + S * 0.020, body[3] - S * 0.020)], S * 0.010)
    return L


def nirspec():
    """Wide spectrograph: micro-shutter array + prism wedge + dispersed fan."""
    L = new_layer()
    d = ImageDraw.Draw(L)
    accent = (150, 190, 255)
    body = (C - S * 0.245, C - S * 0.100, C + S * 0.245, C + S * 0.150)
    bevel_box(L, body, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.5), int(S * 0.034),
              outline=GOLD_DARK, radius=14)
    # entrance aperture on the left
    _cold_aperture(L, C - S * 0.170, C + S * 0.010, S * 0.070, accent)
    # micro-shutter array: a fine addressable grid
    mx0, my0 = C - S * 0.070, C - S * 0.062
    mw, mh = S * 0.135, S * 0.128
    vertical_gradient(L, (mx0, my0, mx0 + mw, my0 + mh), (48, 58, 88), (16, 20, 36), radius=4)
    for i in range(9):
        for j in range(8):
            cx0 = mx0 + 6 + i * (mw - 12) / 9
            cy0 = my0 + 6 + j * (mh - 12) / 8
            open_shutter = (i * 5 + j * 3) % 7 < 2
            d.rectangle([cx0, cy0, cx0 + (mw - 12) / 9 - 4, cy0 + (mh - 12) / 8 - 4],
                        fill=(lerp(accent, (255, 255, 255), 0.35) if open_shutter
                              else lerp((40, 50, 76), BLACK, 0.35)) + (255,))
    d.rounded_rectangle((mx0, my0, mx0 + mw, my0 + mh), radius=4, outline=GOLD + (255,), width=4)
    # prism wedge and the dispersed fan it throws
    px = C + S * 0.105
    d.polygon([(px, C - S * 0.072), (px + S * 0.078, C + S * 0.048), (px - S * 0.030, C + S * 0.048)],
              fill=lerp(SILVER, accent, 0.35) + (255,))
    d.polygon([(px, C - S * 0.072), (px + S * 0.078, C + S * 0.048), (px - S * 0.030, C + S * 0.048)],
              outline=GOLD + (255,), width=4)
    for i in range(6):
        col = lerp((255, 96, 64), (96, 160, 255), i / 5.0)
        d.line([(px + S * 0.040, C + S * 0.048),
                (C + S * 0.225, C + S * 0.020 + i * S * 0.017)], fill=col + (200,), width=4)
    rivets(L, [(body[0] + S * 0.020, body[1] + S * 0.020), (body[2] - S * 0.020, body[3] - S * 0.020)],
           S * 0.010)
    return L


def miri():
    """Tall cryostat drum with cooler plumbing and a heat-exchanger stack."""
    L = new_layer()
    d = ImageDraw.Draw(L)
    accent = (120, 220, 235)
    # cryostat drum (vertical)
    dx0, dy0, dx1, dy1 = C - S * 0.125, C - S * 0.215, C + S * 0.125, C + S * 0.130
    vertical_gradient(L, (dx0, dy0, dx1, dy1), NAVY_LIT, lerp(NAVY, BLACK, 0.45), radius=40)
    d.rounded_rectangle((dx0, dy0, dx1, dy1), radius=40, outline=GOLD_DARK + (255,), width=6)
    # chilled bands around the drum
    for i in range(4):
        y = dy0 + S * 0.055 + i * S * 0.070
        d.line([(dx0 + 8, y), (dx1 - 8, y)], fill=lerp(CYAN_DARK, SILVER_MID, 0.4) + (220,), width=6)
        d.line([(dx0 + 8, y - 5), (dx1 - 8, y - 5)], fill=(255, 255, 255, 90), width=3)
    # cold aperture on top
    _cold_aperture(L, C, dy0 + S * 0.010, S * 0.088, accent, squash=0.60)
    # frost bloom at the cold end
    L.alpha_composite(specular(S, C, dy0 + S * 0.012, S * 0.105, S * 0.045, 60))
    # cryocooler lines looping to a heat exchanger
    for sx in (-1, 1):
        pts = [(C + sx * S * 0.120, C - S * 0.060)]
        for k in range(1, 9):
            t = k / 8.0
            pts.append((C + sx * (S * 0.120 + math.sin(t * math.pi) * S * 0.085),
                        C - S * 0.060 + t * S * 0.215))
        d.line(pts, fill=COPPER + (255,), width=int(S * 0.016))
        d.line(pts, fill=lerp(COPPER, (255, 255, 255), 0.4) + (140,), width=4)
    # heat exchanger stack at the base
    _fins(L, C - S * 0.150, C + S * 0.150, C + S * 0.150, C + S * 0.225, 8)
    d.rounded_rectangle((C - S * 0.160, C + S * 0.140, C + S * 0.160, C + S * 0.160),
                        radius=8, fill=lerp(SILVER_DARK, NAVY, 0.4) + (255,))
    return L


def fgs_niriss():
    """Guider bench: twin small apertures + reticle window, low and wide."""
    L = new_layer()
    d = ImageDraw.Draw(L)
    accent = (140, 230, 160)
    body = (C - S * 0.250, C - S * 0.070, C + S * 0.250, C + S * 0.120)
    bevel_box(L, body, NAVY_LIT, NAVY, lerp(NAVY, BLACK, 0.5), int(S * 0.032),
              outline=GOLD_DARK, radius=12)
    # optical bench rails
    for y in (C + S * 0.060, C + S * 0.095):
        d.line([(body[0] + S * 0.02, y), (body[2] - S * 0.02, y)], fill=SILVER_MID + (200,), width=5)
    # two guider apertures
    for sx in (-1, 1):
        _cold_aperture(L, C + sx * S * 0.150, C - S * 0.005, S * 0.062, accent)
    # central reticle window with crosshair + guide star
    wx0, wy0, wx1, wy1 = C - S * 0.082, C - S * 0.060, C + S * 0.082, C + S * 0.045
    d.rounded_rectangle((wx0, wy0, wx1, wy1), radius=8, fill=(6, 18, 14) + (255,))
    d.rounded_rectangle((wx0, wy0, wx1, wy1), radius=8, outline=GOLD + (255,), width=5)
    mx, my = (wx0 + wx1) / 2, (wy0 + wy1) / 2
    d.line([(wx0 + 10, my), (wx1 - 10, my)], fill=accent + (170,), width=3)
    d.line([(mx, wy0 + 10), (mx, wy1 - 10)], fill=accent + (170,), width=3)
    d.rectangle([mx - S * 0.022, my - S * 0.022, mx + S * 0.022, my + S * 0.022],
                outline=GREEN_OK + (255,), width=4)
    rnd = random.Random(4)
    for _ in range(14):
        sx_ = rnd.uniform(wx0 + 12, wx1 - 12)
        sy_ = rnd.uniform(wy0 + 12, wy1 - 12)
        r_ = rnd.choice([2, 2, 3])
        d.ellipse([sx_ - r_, sy_ - r_, sx_ + r_, sy_ + r_], fill=(220, 240, 255, 210))
    d.ellipse([mx - 5, my - 5, mx + 5, my + 5], fill=GOLD_HI + (255,))
    return L


def isim_package():
    """Open ISIM frame carrying four instrument bays + harness trunk."""
    L = new_layer()
    d = ImageDraw.Draw(L)
    frame = (C - S * 0.240, C - S * 0.180, C + S * 0.240, C + S * 0.175)
    # open truss frame rather than a solid box
    d.rounded_rectangle(frame, radius=16, outline=lerp(GOLD_DARK, SILVER_DARK, 0.35) + (255,),
                        width=int(S * 0.028))
    vertical_gradient(L, (frame[0] + S * 0.026, frame[1] + S * 0.026,
                          frame[2] - S * 0.026, frame[3] - S * 0.026),
                      lerp(NAVY, BLACK, 0.25), BLACK, radius=10)
    accents = [(236, 150, 90), (150, 190, 255), (120, 220, 235), (140, 230, 160)]
    for i in range(2):
        for j in range(2):
            bx = frame[0] + S * 0.050 + i * S * 0.225
            by = frame[1] + S * 0.050 + j * S * 0.165
            bw, bh = S * 0.185, S * 0.128
            vertical_gradient(L, (bx, by, bx + bw, by + bh), NAVY_LIT, NAVY, radius=8)
            d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=8, outline=GOLD_DARK + (255,), width=4)
            _cold_aperture(L, bx + bw * 0.32, by + bh * 0.46, bh * 0.30, accents[i * 2 + j])
            for k in range(4):
                d.line([(bx + bw * 0.60 + k * bw * 0.09, by + bh * 0.22),
                        (bx + bw * 0.60 + k * bw * 0.09, by + bh * 0.78)],
                       fill=SILVER_MID + (200,), width=4)
    # harness trunk down the middle
    d.line([(C, frame[1] + S * 0.030), (C, frame[3] - S * 0.030)],
           fill=lerp(COPPER, BLACK, 0.3) + (255,), width=int(S * 0.020))
    rivets(L, [(frame[0] + S * 0.024, frame[1] + S * 0.024), (frame[2] - S * 0.024, frame[1] + S * 0.024),
               (frame[0] + S * 0.024, frame[3] - S * 0.024), (frame[2] - S * 0.024, frame[3] - S * 0.024)],
           S * 0.011)
    return L
