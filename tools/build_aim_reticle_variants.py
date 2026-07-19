from pathlib import Path
from math import cos, pi, sin

from PIL import Image, ImageDraw


PROJECT_DIR = Path(__file__).resolve().parents[1]
ASSET_DIR = PROJECT_DIR / "assets" / "ui" / "observation" / "suc"
GENERATED_DIR = ASSET_DIR / "generated"
PROCESSED_DIR = ASSET_DIR / "processed"


def threshold_bbox(image: Image.Image, threshold: int = 24):
    alpha = image.getchannel("A")
    return alpha.point(lambda value: 255 if value >= threshold else 0).getbbox()


def build_finder_ring() -> None:
    source = Image.open(GENERATED_DIR / "finder_second_ring_alpha.png").convert("RGBA")
    bbox = threshold_bbox(source)
    if bbox is None:
        raise RuntimeError("Finder ring generation has no visible pixels")
    ring = source.crop(bbox).resize((230, 230), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (560, 560), (0, 0, 0, 0))
    canvas.alpha_composite(ring, ((canvas.width - ring.width) // 2, (canvas.height - ring.height) // 2))
    canvas.save(PROCESSED_DIR / "finder_second_ring.png", optimize=True)


def build_eye_large_center() -> None:
    base = Image.open(PROCESSED_DIR / "1.png").convert("RGBA")
    generated = Image.open(GENERATED_DIR / "eye_large_center_alpha.png").convert("RGBA")
    generated = generated.resize(base.size, Image.Resampling.NEAREST)
    center_x = base.width // 2
    center_y = base.height // 2

    base_pixels = base.load()
    generated_pixels = generated.load()
    for y in range(base.height):
        for x in range(base.width):
            radius_squared = (x - center_x) ** 2 + (y - center_y) ** 2
            if radius_squared <= 18 ** 2:
                base_pixels[x, y] = (0, 0, 0, 0)
            if 31 ** 2 <= radius_squared <= 44 ** 2:
                pixel = generated_pixels[x, y]
                if pixel[3] > 0:
                    base_pixels[x, y] = pixel

    base.save(PROCESSED_DIR / "eye_large_center.png", optimize=True)


def build_eye_precise_reticle() -> None:
    size = 410
    center = size // 2
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    dark_cyan = (28, 67, 75, 235)
    pale_cyan = (154, 194, 184, 225)
    dark_brass = (75, 51, 17, 240)
    brass = (192, 137, 31, 245)
    bright_brass = (246, 211, 126, 255)

    def circle(radius: int, under_color, line_color) -> None:
        box = (center - radius, center - radius, center + radius, center + radius)
        draw.ellipse(box, outline=under_color, width=3)
        draw.ellipse(box, outline=line_color, width=1)

    # Wide naked-eye field boundary, a quieter navigation ring, and the
    # exact 64 px lock boundary. All share the same pixel center as Godot.
    circle(196, dark_cyan, pale_cyan)
    circle(132, dark_brass, brass)
    circle(64, dark_brass, bright_brass)

    for angle_index in range(24):
        angle = angle_index * pi / 12.0
        is_cardinal = angle_index % 6 == 0
        inner = 126 if is_cardinal else 129
        outer = 139 if is_cardinal else 135
        color = bright_brass if is_cardinal else brass
        draw.line(
            (
                round(center + cos(angle) * inner),
                round(center + sin(angle) * inner),
                round(center + cos(angle) * outer),
                round(center + sin(angle) * outer),
            ),
            fill=color,
            width=2 if is_cardinal else 1,
        )

    for angle_index in range(4):
        angle = angle_index * pi / 2.0
        tick_inner = 57
        tick_outer = 72
        x1 = round(center + cos(angle) * tick_inner)
        y1 = round(center + sin(angle) * tick_inner)
        x2 = round(center + cos(angle) * tick_outer)
        y2 = round(center + sin(angle) * tick_outer)
        draw.line((x1, y1, x2, y2), fill=bright_brass, width=2)
        # Small brass diamond gives the hand-built observatory style without
        # filling or obscuring the optical center.
        dx = round(center + cos(angle) * 68)
        dy = round(center + sin(angle) * 68)
        draw.polygon([(dx, dy - 3), (dx + 3, dy), (dx, dy + 3), (dx - 3, dy)], outline=bright_brass)

    canvas.save(PROCESSED_DIR / "eye_precise_reticle.png", optimize=True)


def build_scope_tolerance_center() -> None:
    base = Image.open(PROCESSED_DIR / "3.png").convert("RGBA")
    center_x = base.width // 2
    center_y = base.height // 2

    # Use the larger projected 0.5-degree radius so every valid lock position
    # is inside the aperture while the optical reference remains circular.
    # The artwork is displayed at 410/560 of source height. A 92 px source
    # radius becomes about 67 px on screen, covering the larger vertical
    # projection of the real 0.5-degree tolerance.
    inner_radius = 92
    pixels = base.load()
    for y in range(center_y - inner_radius, center_y + inner_radius + 1):
        for x in range(center_x - inner_radius, center_x + inner_radius + 1):
            if (x - center_x) ** 2 + (y - center_y) ** 2 <= inner_radius ** 2:
                pixels[x, y] = (0, 0, 0, 0)

    draw = ImageDraw.Draw(base)
    draw.ellipse(
        (center_x - 96, center_y - 96, center_x + 96, center_y + 96),
        outline=(82, 57, 24, 255),
        width=3,
    )
    draw.ellipse(
        (center_x - 94, center_y - 94, center_x + 94, center_y + 94),
        outline=(246, 218, 142, 255),
        width=2,
    )
    base.save(PROCESSED_DIR / "scope_center_tolerance.png", optimize=True)


if __name__ == "__main__":
    build_finder_ring()
    build_eye_large_center()
    build_eye_precise_reticle()
    build_scope_tolerance_center()
    print(PROCESSED_DIR / "finder_second_ring.png")
    print(PROCESSED_DIR / "eye_large_center.png")
    print(PROCESSED_DIR / "eye_precise_reticle.png")
    print(PROCESSED_DIR / "scope_center_tolerance.png")
