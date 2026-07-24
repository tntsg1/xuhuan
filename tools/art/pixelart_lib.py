"""
Shared pixel-realistic shading toolkit for Pixel Observatory part art.

House style (matched to assets/telescope_parts/cassegrain/*.png):
  * 500x500 RGBA, fully transparent background
  * three-quarter view, single light source from the UPPER-LEFT
  * deep navy / black bodies, brass-gold structure, brushed silver optics,
    cyan instrument glow
  * everything rendered at SS x supersample then Lanczos-downsampled, so
    silhouettes are anti-aliased rather than jagged geometric shapes.

Nothing here draws a bare rectangle or circle as a finished element: every
surface gets a gradient ramp, a specular hit, contact shading and edge wear.
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 3                      # supersample factor
CANVAS = 500                # final sprite size
LIGHT = (-0.62, -0.78)      # normalised light direction (upper-left)

# ---------------------------------------------------------------- palettes
NAVY_DARK = (10, 16, 28)
NAVY = (18, 29, 48)
NAVY_LIT = (34, 52, 80)
BLACK = (6, 9, 15)

GOLD_HI = (240, 214, 140)
GOLD = (201, 162, 74)
GOLD_MID = (160, 124, 52)
GOLD_DARK = (92, 68, 26)

SILVER_HI = (238, 244, 250)
SILVER = (200, 210, 220)
SILVER_MID = (140, 152, 166)
SILVER_DARK = (74, 84, 98)

CYAN_HI = (170, 240, 255)
CYAN = (97, 216, 255)
CYAN_DARK = (30, 96, 130)

COPPER = (176, 108, 60)
RED_WARN = (198, 78, 52)
GREEN_OK = (103, 215, 139)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ramp(stops, t):
    """stops = [(pos, color), ...] sorted by pos."""
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        if t <= p1:
            span = max(1e-6, p1 - p0)
            return lerp(c0, c1, (t - p0) / span)
    return stops[-1][1]


def new_layer(size=None):
    s = size or CANVAS * SS
    return Image.new("RGBA", (s, s), (0, 0, 0, 0))


def finish(layer, size=CANVAS):
    """Downsample the supersampled layer to the final sprite size."""
    return layer.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- surfaces
def radial_metal(size, inner, outer, stops, streaks=0, streak_seed=1,
                 center=None, squash=1.0):
    """A brushed metal annulus/disc: radial ramp + angular brush streaks."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx, cy = center or (size / 2.0, size / 2.0)
    rnd = random.Random(streak_seed)
    brush = [rnd.uniform(-1.0, 1.0) for _ in range(720)]
    for y in range(size):
        dy = (y - cy) / squash
        for x in range(size):
            dx = x - cx
            d = math.hypot(dx, dy)
            if d > outer or d < inner:
                continue
            t = (d - inner) / max(1e-6, outer - inner)
            col = ramp(stops, t)
            if streaks:
                ang = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
                b = brush[int(ang * 719) % 720] * streaks
                col = (max(0, min(255, col[0] + int(b))),
                       max(0, min(255, col[1] + int(b))),
                       max(0, min(255, col[2] + int(b))))
            # directional light term
            if d > 1e-6:
                nx, ny = dx / d, dy / d
                lam = nx * LIGHT[0] + ny * LIGHT[1]
                shade = int(26 * lam)
                col = (max(0, min(255, col[0] + shade)),
                       max(0, min(255, col[1] + shade)),
                       max(0, min(255, col[2] + shade)))
            px[x, y] = col + (255,)
    return img


def specular(size, cx, cy, rx, ry, strength=110, rot=0.0):
    """Soft elliptical specular bloom, added on top of a surface."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(255, 255, 255, strength))
    if rot:
        img = img.rotate(rot, resample=Image.BICUBIC, center=(cx, cy))
    return img.filter(ImageFilter.GaussianBlur(max(2, rx * 0.42)))


def contact_shadow(size, cx, cy, rx, ry, strength=150):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(0, 0, 0, strength))
    return img.filter(ImageFilter.GaussianBlur(rx * 0.35))


def bevel_disc(size, cx, cy, r, face_stops, rim_w, rim_stops, squash=1.0):
    """A disc with a shaded face and a raised rim (brass ring look)."""
    base = radial_metal(size, 0, r, face_stops, streaks=10, squash=squash,
                        center=(cx, cy))
    rim = radial_metal(size, r - rim_w, r, rim_stops, streaks=6, squash=squash,
                       center=(cx, cy))
    base.alpha_composite(rim)
    return base


def rivets(layer, points, r, color=GOLD_HI, shadow=True):
    d = ImageDraw.Draw(layer)
    for (x, y) in points:
        if shadow:
            d.ellipse([x - r * 1.15, y - r * 1.15, x + r * 1.15, y + r * 1.15],
                      fill=BLACK + (170,))
        d.ellipse([x - r, y - r, x + r, y + r], fill=lerp(color, GOLD_DARK, 0.25) + (255,))
        d.ellipse([x - r * 0.5, y - r * 0.62, x + r * 0.28, y + r * 0.18],
                  fill=lerp(color, (255, 255, 255), 0.45) + (255,))


def ring_points(cx, cy, r, n, squash=1.0, phase=0.0):
    out = []
    for i in range(n):
        a = phase + i * 2 * math.pi / n
        out.append((cx + math.cos(a) * r, cy + math.sin(a) * r * squash))
    return out


def bevel_box(layer, box, top_c, face_c, side_c, depth, outline=None, radius=0):
    """Isometric-ish slab: front face + top face + right side face."""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(layer)
    # right side
    d.polygon([(x1, y0), (x1 + depth, y0 - depth * 0.55), (x1 + depth, y1 - depth * 0.55), (x1, y1)],
              fill=side_c + (255,))
    # top
    d.polygon([(x0, y0), (x0 + depth, y0 - depth * 0.55), (x1 + depth, y0 - depth * 0.55), (x1, y0)],
              fill=top_c + (255,))
    # face
    if radius:
        d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=face_c + (255,))
    else:
        d.rectangle([x0, y0, x1, y1], fill=face_c + (255,))
    if outline:
        if radius:
            d.rounded_rectangle([x0, y0, x1, y1], radius=radius, outline=outline + (255,), width=max(2, depth // 6))
        else:
            d.rectangle([x0, y0, x1, y1], outline=outline + (255,), width=max(2, depth // 6))


def vertical_gradient(layer, box, top_c, bottom_c, mask_shape="rect", radius=0):
    x0, y0, x1, y1 = [int(v) for v in box]
    h = max(1, y1 - y0)
    grad = Image.new("RGBA", (max(1, x1 - x0), h), (0, 0, 0, 0))
    gp = grad.load()
    for y in range(h):
        c = lerp(top_c, bottom_c, y / h)
        for x in range(grad.width):
            gp[x, y] = c + (255,)
    mask = Image.new("L", grad.size, 0)
    md = ImageDraw.Draw(mask)
    if mask_shape == "ellipse":
        md.ellipse([0, 0, grad.width - 1, h - 1], fill=255)
    elif radius:
        md.rounded_rectangle([0, 0, grad.width - 1, h - 1], radius=radius, fill=255)
    else:
        md.rectangle([0, 0, grad.width - 1, h - 1], fill=255)
    layer.paste(grad, (x0, y0), mask)


def hexagon(cx, cy, r, rot=0.0, squash=1.0):
    pts = []
    for i in range(6):
        a = rot + i * math.pi / 3
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * squash))
    return pts


def gold_hex_segment(layer, cx, cy, r, seed=0, squash=0.9):
    """One beryllium/gold JWST mirror segment with radial sheen + bevel."""
    d = ImageDraw.Draw(layer)
    outer = hexagon(cx, cy, r, rot=math.pi / 6, squash=squash)
    d.polygon(outer, fill=GOLD_DARK + (255,))
    inner = hexagon(cx, cy, r * 0.90, rot=math.pi / 6, squash=squash)
    d.polygon(inner, fill=GOLD + (255,))
    # sheen: bright toward the light, deeper away
    rnd = random.Random(seed)
    for i in range(9):
        t = i / 9.0
        rr = r * (0.88 - t * 0.80)
        off = r * 0.10 * t
        c = lerp(GOLD_HI, GOLD_MID, t * 0.9 + rnd.uniform(-0.04, 0.04))
        d.polygon(hexagon(cx + LIGHT[0] * off, cy + LIGHT[1] * off, rr,
                          rot=math.pi / 6, squash=squash), fill=c + (255,))
    # rim highlight on the lit edges
    d.line(outer[2:5], fill=lerp(GOLD_HI, (255, 255, 255), 0.35) + (255,), width=max(2, int(r * 0.05)))
    d.line(outer[:2], fill=GOLD_DARK + (255,), width=max(2, int(r * 0.05)))


def starfield(layer, box, count=90, seed=3, color=(210, 226, 245)):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    for _ in range(count):
        x = rnd.uniform(x0, x1)
        y = rnd.uniform(y0, y1)
        r = rnd.choice([1, 1, 1, 2, 2, 3])
        a = rnd.randint(90, 235)
        d.ellipse([x - r, y - r, x + r, y + r], fill=color + (a,))


def noise_overlay(layer, amount=8, seed=7):
    """Subtle luminance grain so flat areas never read as vector fills."""
    rnd = random.Random(seed)
    w, h = layer.size
    small = Image.new("L", (w // 4, h // 4))
    sp = small.load()
    for y in range(small.height):
        for x in range(small.width):
            sp[x, y] = 128 + rnd.randint(-amount, amount)
    small = small.resize((w, h), Image.BILINEAR)
    base = layer.convert("RGBA")
    grain = Image.merge("RGBA", (small, small, small, layer.split()[3]))
    out = ImageChops.overlay(base, grain)
    out.putalpha(layer.split()[3])
    return out


def drop_shadow(layer, offset=(10, 14), blur=18, alpha=120):
    a = layer.split()[3].filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: int(v * alpha / 255)))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(sh, offset, sh)
    out.alpha_composite(layer)
    return out


def trim_to_canvas(img, margin=14, size=CANVAS):
    """Centre the artwork and guarantee the part is never clipped."""
    bbox = img.split()[3].getbbox()
    if not bbox:
        return img.resize((size, size), Image.LANCZOS)
    art = img.crop(bbox)
    avail = size - margin * 2
    scale = min(avail / art.width, avail / art.height, 1.0e9)
    nw, nh = max(1, int(art.width * scale)), max(1, int(art.height * scale))
    art = art.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(art, ((size - nw) // 2, (size - nh) // 2), art)
    return out
