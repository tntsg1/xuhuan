"""Build non-destructive, loop-safe night horizon assets.

The source PNGs in assets/horizon stay untouched.  This pass repairs color
contamination in translucent edge pixels by borrowing color from nearby
opaque artwork.  It never keys pixels by "black" or "white", so lamps, snow,
dark metal, and night silhouettes remain part of the image.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "horizon"
OUTPUT_DIR = SOURCE_DIR / "processed"
MANIFEST_PATH = OUTPUT_DIR / "processing_manifest.json"

LAYER_GRADE = {
    "far_": {"exposure": 0.88, "saturation": 0.62, "tint": (0.78, 0.86, 1.00)},
    "mid_": {"exposure": 0.90, "saturation": 0.72, "tint": (0.84, 0.90, 1.00)},
    "near_": {"exposure": 0.92, "saturation": 0.80, "tint": (0.90, 0.93, 1.00)},
    "cloud_": {"exposure": 0.48, "saturation": 0.30, "tint": (0.62, 0.72, 0.92)},
}


def _grade_for(name: str) -> dict:
    for prefix, grade in LAYER_GRADE.items():
        if name.startswith(prefix):
            return grade
    return {"exposure": 0.78, "saturation": 0.72, "tint": (0.78, 0.86, 1.00)}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _nearby_opaque_color(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Estimate clean edge RGB from opaque neighbors using normalized blur."""
    seed_weight = np.clip((alpha.astype(np.float32) - 128.0) / 96.0, 0.0, 1.0)
    seed_alpha = Image.fromarray(np.uint8(seed_weight * 255.0), "L")
    # Two radii fill both fine pixel fringes and wider antialiased mattes.
    weight_blur = np.asarray(seed_alpha.filter(ImageFilter.GaussianBlur(4.0)), dtype=np.float32)
    weight_blur += np.asarray(seed_alpha.filter(ImageFilter.GaussianBlur(10.0)), dtype=np.float32) * 0.35
    estimate = np.zeros_like(rgb, dtype=np.float32)
    for channel in range(3):
        weighted = np.uint8(np.clip(rgb[:, :, channel] * seed_weight, 0.0, 255.0))
        channel_img = Image.fromarray(weighted, "L")
        channel_blur = np.asarray(channel_img.filter(ImageFilter.GaussianBlur(4.0)), dtype=np.float32)
        channel_blur += np.asarray(channel_img.filter(ImageFilter.GaussianBlur(10.0)), dtype=np.float32) * 0.35
        # Both blurred images use the same 0..255 sample scale. Dividing by
        # weight_blur / 255 would multiply the reconstructed edge colour by
        # 255 and drive every translucent fringe toward white.
        estimate[:, :, channel] = channel_blur / np.maximum(weight_blur, 0.001)
    return np.clip(estimate, 0.0, 255.0)


def _repair_edges(rgba: np.ndarray) -> np.ndarray:
    result = rgba.astype(np.float32)
    alpha = rgba[:, :, 3]
    estimate = _nearby_opaque_color(rgba[:, :, :3].astype(np.float32), alpha)
    # Opaque artwork is never recolored by this operation.  Replacement rises
    # only through the antialiased fringe where matte contamination is visible.
    fringe = np.clip((224.0 - alpha.astype(np.float32)) / 192.0, 0.0, 1.0)
    fringe *= (alpha > 5).astype(np.float32)
    result[:, :, :3] = (
        result[:, :, :3] * (1.0 - fringe[:, :, None])
        + estimate * fringe[:, :, None]
    )
    result[alpha <= 5, :3] = 0.0
    result[alpha <= 5, 3] = 0.0
    return np.uint8(np.clip(result, 0.0, 255.0))


def _night_grade(rgba: np.ndarray, grade: dict) -> np.ndarray:
    result = rgba.astype(np.float32)
    rgb = result[:, :, :3] / 255.0
    alpha = result[:, :, 3] / 255.0
    luma = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    saturation = float(grade["saturation"])
    tint = np.asarray(grade["tint"], dtype=np.float32)
    cooled = (luma[:, :, None] * (1.0 - saturation) + rgb * saturation)
    cooled *= tint[None, None, :] * float(grade["exposure"])

    # Keep small, opaque amber lights warm while broad bright daytime surfaces
    # remain cooled.  Alpha and spatial compactness are implicit safeguards.
    warm = np.clip((rgb[:, :, 0] - rgb[:, :, 2] - 0.05) * 3.0, 0.0, 1.0)
    warm *= np.clip((luma - 0.12) * 2.5, 0.0, 1.0)
    warm *= np.clip((alpha - 0.55) * 2.2, 0.0, 1.0)
    warm_rgb = rgb * float(grade["exposure"]) * np.asarray((1.0, 0.88, 0.68), dtype=np.float32)
    rgb = cooled * (1.0 - warm[:, :, None] * 0.68) + warm_rgb * (warm[:, :, None] * 0.68)
    result[:, :, :3] = np.clip(rgb * 255.0, 0.0, 255.0)
    return np.uint8(result)


def _make_horizontal_loop(rgba: np.ndarray) -> np.ndarray:
    """Match the left/right edges without introducing a rectangular matte."""
    result = rgba.astype(np.float32)
    width = rgba.shape[1]
    blend_width = min(96, max(12, width // 24))
    for x in range(blend_width):
        opposite = width - 1 - x
        edge_weight = 1.0 - x / float(blend_width)
        average = (result[:, x] + result[:, opposite]) * 0.5
        mix = edge_weight * 0.82
        result[:, x] = result[:, x] * (1.0 - mix) + average * mix
        result[:, opposite] = result[:, opposite] * (1.0 - mix) + average * mix
    # The exact boundary pixels match, so nearest-neighbor sampling cannot
    # reveal a one-pixel bright or dark seam.
    boundary = (result[:, 0] + result[:, -1]) * 0.5
    result[:, 0] = boundary
    result[:, -1] = boundary
    return np.uint8(np.clip(result, 0.0, 255.0))


def _soften_clipped_top(rgba: np.ndarray) -> np.ndarray:
    """Turn an AI-cropped top boundary into a short natural alpha taper."""
    result = rgba.copy()
    alpha = result[:, :, 3]
    if np.count_nonzero(alpha[0] > 5) == 0:
        return result
    fade_rows = min(10, result.shape[0])
    for y in range(fade_rows):
        weight = (y / float(max(fade_rows - 1, 1))) ** 1.35
        result[y, :, 3] = np.uint8(result[y, :, 3].astype(np.float32) * weight)
    result[0, :, 3] = 0
    result[0, :, :3] = 0
    return result


def _stats(rgba: np.ndarray) -> dict:
    alpha = rgba[:, :, 3]
    rgb = rgba[:, :, :3]
    semi = (alpha > 0) & (alpha < 255)
    return {
        "width": int(rgba.shape[1]),
        "height": int(rgba.shape[0]),
        "transparent_fraction": round(float(np.mean(alpha == 0)), 6),
        "semi_transparent_fraction": round(float(np.mean(semi)), 6),
        "bright_semi_pixels": int(np.count_nonzero(semi & (rgb.mean(axis=2) > 210))),
        "opaque_dark_pixels": int(np.count_nonzero((alpha > 240) & (rgb.mean(axis=2) < 8))),
        "top_edge_visible_pixels": int(np.count_nonzero(alpha[0] > 5)),
        "left_right_alpha_mae": round(float(np.mean(np.abs(alpha[:, 0].astype(np.float32) - alpha[:, -1].astype(np.float32)))), 4),
    }


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    records = []
    for source in sorted(SOURCE_DIR.glob("*.png")):
        with Image.open(source) as opened:
            rgba = np.asarray(opened.convert("RGBA"))
        before = _stats(rgba)
        grade = _grade_for(source.name)
        processed = _repair_edges(rgba)
        processed = _night_grade(processed, grade)
        processed = _make_horizontal_loop(processed)
        processed = _soften_clipped_top(processed)
        output = OUTPUT_DIR / source.name
        Image.fromarray(processed, "RGBA").save(output, optimize=True)
        records.append(
            {
                "source": source.relative_to(ROOT).as_posix(),
                "output": output.relative_to(ROOT).as_posix(),
                "source_sha256": _sha256(source),
                "processing": [
                    "alpha-preserving nearest-opaque edge color repair",
                    "layer-aware night grade with warm-light preservation",
                    "horizontal seam matching",
                ],
                "grade": grade,
                "before": before,
                "after": _stats(processed),
            }
        )
    MANIFEST_PATH.write_text(
        json.dumps(
            {
                "note": "Generated assets. Source files are retained unchanged.",
                "assets": records,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Processed {len(records)} horizon assets -> {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
