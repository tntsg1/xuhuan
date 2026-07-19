from pathlib import Path

from PIL import Image


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


if __name__ == "__main__":
    build_finder_ring()
    build_eye_large_center()
    print(PROCESSED_DIR / "finder_second_ring.png")
    print(PROCESSED_DIR / "eye_large_center.png")
