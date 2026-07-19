from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


SOURCE_DIR = Path(r"C:\Users\tntsg\Downloads\tw\suc")
PROJECT_DIR = Path(__file__).resolve().parents[1]
ASSET_ROOT = PROJECT_DIR / "assets" / "ui" / "observation" / "suc"
ORIGINAL_DIR = ASSET_ROOT / "source"
PROCESSED_DIR = ASSET_ROOT / "processed"

# Runtime images are kept at roughly twice their 1024x768 display size. Godot
# performs the final nearest-neighbour presentation without loading 1254px UI
# icons into 50px controls.
RUNTIME_LIMITS = {
    "1.2.png": (560, 560),
    "2.png": (560, 560),
    "3.1.png": (560, 560),
    "azimuth_scale_bar.png": (760, 96),
    "altitude_scale_bar.png": (104, 680),
    "azimuth_pointer.png": (96, 128),
    "altitude_pointer.png": (96, 128),
    "azimuth_knob.png": (160, 160),
    "altitude_knob.png": (160, 160),
    "focus_knob_ui.png": (192, 192),
    "tracking_rate_knob.png": (192, 192),
    "mode_eye_icon.png": (192, 192),
    "mode_finder_icon.png": (192, 192),
    "mode_scope_icon.png": (192, 192),
    "target_approach_ring.png": (256, 256),
    "target_lock_ring.png": (256, 256),
    "tracking_enabled_icon.png": (160, 160),
    "azimuth_pointer-removebg-preview.png": (96, 128),
    "altitude_pointer-removebg-preview.png": (96, 128),
    "mode_eye_icon-removebg-preview.png": (192, 192),
    "target_approach_ring-removebg-preview (1).png": (256, 256),
    "target_lock_ring-removebg-preview.png": (256, 256),
    "tracking_rate_knob-removebg-preview (1).png": (192, 192),
}

SOURCE_RUNTIME_ALIASES = {
    "azimuth_pointer-removebg-preview.png": "azimuth_pointer.png",
    "altitude_pointer-removebg-preview.png": "altitude_pointer.png",
    "mode_eye_icon-removebg-preview.png": "mode_eye_icon.png",
    "target_approach_ring-removebg-preview (1).png": "target_approach_ring.png",
    "target_lock_ring-removebg-preview.png": "target_lock_ring.png",
    "tracking_rate_knob-removebg-preview (1).png": "tracking_rate_knob.png",
}

USAGE = {
    "1.2.png": "Naked Eye central transparent aiming overlay",
    "2.png": "Finder Scope central transparent aiming overlay",
    "3.1.png": "Main Telescope central transparent aiming overlay",
    "azimuth_scale_bar.png": "top azimuth scale shell",
    "altitude_scale_bar.png": "left altitude scale shell",
    "azimuth_pointer.png": "horizontal target-offset pointer",
    "altitude_pointer.png": "vertical target-offset pointer (rotated at runtime)",
    "azimuth_knob.png": "live azimuth status knob",
    "altitude_knob.png": "live altitude status knob",
    "focus_knob_ui.png": "telescope focus status knob",
    "tracking_rate_knob.png": "tracking-rate status knob",
    "mode_eye_icon.png": "Eye mode button icon",
    "mode_finder_icon.png": "Finder mode button icon",
    "mode_scope_icon.png": "Scope mode button icon",
    "target_approach_ring.png": "near-target cyan ring",
    "target_lock_ring.png": "centered/success gold ring",
    "tracking_enabled_icon.png": "tracking-enabled status icon",
    "azimuth_pointer-removebg-preview.png": "transparent replacement for horizontal target-offset pointer",
    "altitude_pointer-removebg-preview.png": "transparent replacement for vertical target-offset pointer",
    "mode_eye_icon-removebg-preview.png": "transparent replacement for Eye mode button icon",
    "target_approach_ring-removebg-preview (1).png": "transparent replacement for near-target cyan ring",
    "target_lock_ring-removebg-preview.png": "transparent replacement for centered/success gold ring",
    "tracking_rate_knob-removebg-preview (1).png": "transparent replacement for tracking-rate status knob",
    "ChatGPT Image 2026年7月18日 21_22_48.png": "layout reference only; contains baked values and text",
}

RETICLE_RUNTIME_NAMES = {
    "1.2.png": "1.png",
    "2.png": "2.png",
    "3.1.png": "3.png",
}

DERIVED_USAGE = {
    "azimuth_scale_shell.png": "fixed top brass shell with baked ticks removed",
    "altitude_scale_shell.png": "fixed left brass shell with baked ticks removed",
    "azimuth_tick_major.png": "live scrolling top major tick cropped from supplied art",
    "azimuth_tick_minor.png": "live scrolling top minor tick cropped from supplied art",
    "altitude_tick_major.png": "live scrolling left major tick cropped from supplied art",
    "altitude_tick_minor.png": "live scrolling left minor tick cropped from supplied art",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def alpha_bbox(alpha: Image.Image, threshold: int = 8):
    return alpha.point(lambda value: 255 if value >= threshold else 0).getbbox()


def remove_baked_neutral_background(
    image: Image.Image,
    saturation_threshold: int = 13,
    dilation_size: int = 9,
    clear_center_radius: int = 0,
) -> Image.Image:
    """Recover transparency from generated RGB art with a gray/checkerboard background.

    The supplied foreground uses saturated navy, brass and cyan. We retain those
    pixels, then expand the mask a few pixels to retain black outlines and white
    highlights enclosed by the colored silhouette. This avoids color-keying a
    single checker color and keeps pixel edges deterministic.
    """
    rgb = image.convert("RGB")
    red, green, blue = rgb.split()
    maximum = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    minimum = ImageChops.darker(ImageChops.darker(red, green), blue)
    saturation = ImageChops.subtract(maximum, minimum)
    color_seed = saturation.point(lambda value: 255 if value >= saturation_threshold else 0)
    # Preserve dark engraved/outlined pixels only when they are close to the
    # saturated foreground; neutral generated backgrounds remain transparent.
    silhouette = color_seed.filter(ImageFilter.MaxFilter(dilation_size))
    alpha = ImageChops.lighter(color_seed, silhouette)

    # Scope art needs an unobstructed optical center so a locked planet is
    # never covered by the reticle's decorative hub.
    if clear_center_radius > 0:
        pixels = alpha.load()
        center_x, center_y = image.width // 2, image.height // 2
        radius_squared = clear_center_radius * clear_center_radius
        for y in range(max(0, center_y - clear_center_radius), min(image.height, center_y + clear_center_radius + 1)):
            for x in range(max(0, center_x - clear_center_radius), min(image.width, center_x + clear_center_radius + 1)):
                if (x - center_x) ** 2 + (y - center_y) ** 2 <= radius_squared:
                    pixels[x, y] = 0
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def clean_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 0 if value < 8 else value)
    rgba.putalpha(alpha)
    return rgba


def fit_nearest(image: Image.Image, limit: tuple[int, int]) -> Image.Image:
    max_width, max_height = limit
    scale = min(max_width / image.width, max_height / image.height, 1.0)
    if scale >= 1.0:
        return image
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.NEAREST)


def is_brass(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha >= 40 and red >= 80 and green >= 45 and red > blue * 1.15


def isolated_brass_crop(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    cropped = image.crop(box).convert("RGBA")
    pixels = []
    for pixel in cropped.getdata():
        pixels.append(pixel if is_brass(pixel) else (0, 0, 0, 0))
    cropped.putdata(pixels)
    bbox = alpha_bbox(cropped.getchannel("A"), threshold=1)
    if bbox is None:
        raise RuntimeError(f"No tick pixels recovered from {box}")
    return cropped.crop(bbox)


def remove_baked_ticks(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    shell = image.copy().convert("RGBA")
    pixels = shell.load()
    left, top, right, bottom = box
    for y in range(top, bottom):
        for x in range(left, right):
            if is_brass(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
    return shell


def create_scale_derivatives(records: list[dict]) -> None:
    azimuth = Image.open(PROCESSED_DIR / "azimuth_scale_bar.png").convert("RGBA")
    altitude = Image.open(PROCESSED_DIR / "altitude_scale_bar.png").convert("RGBA")
    derived = {
        "azimuth_scale_shell.png": remove_baked_ticks(azimuth, (55, 30, 705, 44)),
        "altitude_scale_shell.png": remove_baked_ticks(altitude, (39, 88, 54, 590)),
        "azimuth_tick_major.png": isolated_brass_crop(azimuth, (195, 31, 202, 43)),
        "azimuth_tick_minor.png": isolated_brass_crop(azimuth, (181, 34, 188, 43)),
        "altitude_tick_major.png": isolated_brass_crop(altitude, (39, 116, 54, 123)),
        "altitude_tick_minor.png": isolated_brass_crop(altitude, (40, 143, 53, 150)),
    }
    for name, image in derived.items():
        path = PROCESSED_DIR / name
        image.save(path, optimize=True)
        records.append({
            "source_name": None,
            "derived_from": "azimuth_scale_bar.png" if name.startswith("azimuth") else "altitude_scale_bar.png",
            "runtime_asset": path.relative_to(PROJECT_DIR).as_posix(),
            "runtime_size": list(image.size),
            "runtime_has_alpha": True,
            "processing": "pixel crop from supplied art" if "tick_" in name else "baked brass tick removal",
            "resize_filter": "none",
            "usage": DERIVED_USAGE[name],
        })


def create_reticle_variants(records: list[dict]) -> None:
    subprocess.run([sys.executable, str(PROJECT_DIR / "tools" / "build_aim_reticle_variants.py")], check=True)
    variants = {
        "eye_large_center.png": ("1.2.png + generated center-ring crop", "Eye overlay with enlarged transparent target aperture"),
        "eye_precise_reticle.png": ("programmatic brass/cyan pixel art", "Eye overlay aligned one-to-one with the real screen lock radius"),
        "finder_second_ring.png": ("generated crop from 2.png", "Finder overlay retaining only the second circle"),
        "scope_center_tolerance.png": ("3.1.png", "Scope overlay with a center frame matching the real lock tolerance"),
    }
    for name, (derived_from, usage) in variants.items():
        path = PROCESSED_DIR / name
        with Image.open(path) as image:
            runtime_size = list(image.size)
        records.append({
            "source_name": None,
            "derived_from": derived_from,
            "runtime_asset": path.relative_to(PROJECT_DIR).as_posix(),
            "runtime_size": runtime_size,
            "runtime_has_alpha": True,
            "processing": "generated edit + chroma removal + nearest-neighbor compositing",
            "resize_filter": "nearest-neighbor",
            "usage": usage,
        })


def main() -> None:
    ORIGINAL_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    records = []

    for source in sorted(SOURCE_DIR.glob("*.png")):
        original_copy = ORIGINAL_DIR / source.name
        shutil.copy2(source, original_copy)
        with Image.open(source) as opened:
            opened.load()
            original_mode = opened.mode
            original_size = opened.size
            has_alpha = "A" in opened.getbands()
            original_alpha_bbox = alpha_bbox(opened.getchannel("A")) if has_alpha else None

            record = {
                "source_name": source.name,
                "source_path": str(source),
                "project_original": original_copy.relative_to(PROJECT_DIR).as_posix(),
                "sha256": sha256(source),
                "original_size": list(original_size),
                "original_mode": original_mode,
                "original_has_alpha": has_alpha,
                "original_alpha_bbox_at_8": list(original_alpha_bbox) if original_alpha_bbox else None,
                "usage": USAGE.get(
                    source.name,
                    "layout reference only; contains baked values and text"
                    if source.name.startswith("ChatGPT Image ")
                    else "unclassified",
                ),
            }

            if source.name not in RUNTIME_LIMITS:
                record.update({
                    "runtime_asset": None,
                    "processing": "source archive only",
                    "reason_not_used": "Reference composite contains baked coordinates, values, and instructions.",
                })
                records.append(record)
                continue

            # All three central reticles contain a generated neutral matte.
            # Reconstruct alpha from the brass/cyan artwork so neither the
            # light nor dark checkerboard reaches the game.
            if source.name == "3.1.png":
                rgba = remove_baked_neutral_background(opened, saturation_threshold=16, dilation_size=7, clear_center_radius=24)
            elif source.name == "2.png":
                rgba = remove_baked_neutral_background(opened)
            else:
                rgba = clean_alpha(opened) if has_alpha else remove_baked_neutral_background(opened)
            bbox = alpha_bbox(rgba.getchannel("A"))
            if bbox is None:
                raise RuntimeError(f"No foreground recovered from {source.name}")
            cropped = rgba.crop(bbox)
            runtime = fit_nearest(cropped, RUNTIME_LIMITS[source.name])
            runtime_name = RETICLE_RUNTIME_NAMES.get(source.name, SOURCE_RUNTIME_ALIASES.get(source.name, source.name))
            runtime_path = PROCESSED_DIR / runtime_name
            runtime.save(runtime_path, optimize=True)
            record.update({
                "runtime_asset": runtime_path.relative_to(PROJECT_DIR).as_posix(),
                "runtime_name": runtime_name,
                "crop_rect": list(bbox),
                "cropped_size": list(cropped.size),
                "runtime_size": list(runtime.size),
                "runtime_has_alpha": True,
                "processing": (
                    "native alpha threshold + transparent trim"
                    if source.name == "1.2.png"
                    else "neutral matte removal + transparent trim"
                    if source.name in RETICLE_RUNTIME_NAMES
                    else ("alpha threshold + transparent trim" if has_alpha else "neutral background removal + transparent trim")
                ),
                "resize_filter": "nearest-neighbor",
            })
            records.append(record)

    create_scale_derivatives(records)
    create_reticle_variants(records)
    manifest = {
        "source_directory": str(SOURCE_DIR),
        "source_files_unchanged": True,
        "runtime_filter": "nearest-neighbor",
        "records": records,
    }
    manifest_path = ASSET_ROOT / "asset_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Imported {len(list(SOURCE_DIR.glob('*.png')))} source PNG files and {len(DERIVED_USAGE) + 4} derived runtime files")
    print(manifest_path)


if __name__ == "__main__":
    main()
