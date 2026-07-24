"""
Driver: renders every Space Infrared Observatory + FAST part sprite and the
seven assembly blueprint boards, then writes data/art_manifest.json.

    python tools/art/build_space_fast_art.py
"""
from __future__ import annotations

import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from pixelart_lib import *          # noqa: F401,F403
import generate_space_fast_parts as G
from instruments import nircam, nirspec, miri, fgs_niriss, isim_package
from generate_space_fast_parts import (
    save, blueprint, dashed_rect, save_blueprint, MANIFEST, ROOT, S, C,
    segmented_primary_array, space_secondary_mirror, fine_steering_mirror,
    tertiary_mirror_module, space_sunshield, space_telescope_bus,
    deployable_tower, deployment_hinges, _instrument, solar_array,
    communication_antenna, thermal_radiator, instrument_bay,
    infrared_detector_module, fast_active_dish, reflector_panel_segment,
    panel_actuator, suspended_feed_cabin, feed_cabin_receiver,
    feed_cabin_cable_system, cable_tension_controller, _rack,
    _rows_spectrum, _rows_pulse, _rows_rfi, _rows_timing, _rows_data,
    _rows_terminal,
)

SPACE_DIR = "assets/telescope_parts/space_segmented"
FAST_DIR = "assets/telescope_parts/fast_radio"


# ------------------------------------------------------------ blueprint art
def _bp_line(d, pts, w=3, col=(97, 216, 255)):
    d.line(pts, fill=col + (255,), width=w)


def _bp_leader(d, box, anchor):
    """Thin leader line from a dashed slot box to the drawing it labels."""
    cx = box[0] + box[2] / 2.0
    cy = box[1] + box[3] / 2.0
    d.line([(cx, cy), anchor], fill=(97, 216, 255, 150), width=2)


def _bp_space_main(d, W, H):
    cx, cy = W * 0.5, H * 0.52
    # stacked observatory elevation: sunshield below, optics above
    for i in range(5):
        off = i * 16
        _bp_line(d, [(cx - 300 + off * 0.5, cy + 120 - off),
                     (cx, cy + 60 - off),
                     (cx + 300 - off * 0.5, cy + 120 - off)], 3)
    _bp_line(d, [(cx - 170, cy - 40), (cx + 170, cy - 40)], 4)
    for k in range(-2, 3):
        _bp_line(d, [(cx + k * 70, cy - 40), (cx + k * 70, cy - 130)], 3)
    d.arc([cx - 170, cy - 210, cx + 170, cy - 60], 200, 340, fill=(97, 216, 255, 255), width=4)
    _bp_line(d, [(cx, cy - 190), (cx, cy - 250)], 3)
    d.ellipse([cx - 34, cy - 268, cx + 34, cy - 236], outline=(97, 216, 255, 255), width=3)
    # bus + arrays
    d.rectangle([cx - 90, cy + 130, cx + 90, cy + 210], outline=(97, 216, 255, 255), width=3)


def _bp_mirror(d, W, H):
    cx, cy = W * 0.5, H * 0.50
    r = 44
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
        y = cy + r * 1.5 * rr
        pts = [(x + math.cos(math.pi / 6 + i * math.pi / 3) * r,
                y + math.sin(math.pi / 6 + i * math.pi / 3) * r) for i in range(6)]
        d.polygon(pts, outline=(97, 216, 255, 255))
        d.line(pts + [pts[0]], fill=(97, 216, 255, 255), width=3)
    # fold lines for the two side wings
    for sx in (-1, 1):
        _bp_line(d, [(cx + sx * w * 1.5, cy - 150), (cx + sx * w * 1.5, cy + 150)], 2, (216, 168, 77))


def _bp_instruments(d, W, H):
    cx, cy = W * 0.5, H * 0.52
    d.rectangle([cx - 150, cy - 110, cx + 150, cy + 110], outline=(97, 216, 255, 255), width=4)
    for i in range(2):
        for j in range(2):
            d.rectangle([cx - 130 + i * 140, cy - 90 + j * 100,
                         cx - 130 + i * 140 + 120, cy - 90 + j * 100 + 80],
                        outline=(97, 216, 255, 200), width=3)
    # light entering from the top into the bay
    for k in (-1, 0, 1):
        _bp_line(d, [(cx + k * 60, cy - 240), (cx + k * 22, cy - 112)], 3, (216, 168, 77))


def _bp_thermal(d, W, H):
    cx, cy = W * 0.5, H * 0.52
    for i in range(5):
        off = i * 22
        _bp_line(d, [(cx - 250 + off * 0.4, cy + 40 - off), (cx, cy - 10 - off),
                     (cx + 250 - off * 0.4, cy + 40 - off)], 3)
    # sun side arrows (hot) and cold side
    for k in range(-2, 3):
        _bp_line(d, [(cx + k * 80, cy + 150), (cx + k * 80, cy + 70)], 3, (216, 168, 77))
    d.arc([cx - 120, cy - 210, cx + 120, cy - 90], 200, 340, fill=(97, 216, 255, 255), width=4)


def _bp_fast_main(d, W, H):
    cx, cy = W * 0.5, H * 0.56
    d.arc([cx - 320, cy - 150, cx + 320, cy + 190], 0, 180, fill=(97, 216, 255, 255), width=5)
    _bp_line(d, [(cx - 320, cy + 20), (cx + 320, cy + 20)], 3)
    for k in range(-5, 6):
        x = cx + k * 58
        yy = cy + 20 + (1 - (abs(k) / 5.0) ** 2) * 150
        _bp_line(d, [(x, cy + 20), (x, yy)], 2)
    # six towers + cables to the cabin
    for sx in (-1, 1):
        _bp_line(d, [(cx + sx * 330, cy - 190), (cx + sx * 330, cy + 30)], 4, (216, 168, 77))
        _bp_line(d, [(cx + sx * 330, cy - 190), (cx, cy - 120)], 2)
    d.rectangle([cx - 44, cy - 140, cx + 44, cy - 96], outline=(97, 216, 255, 255), width=3)


def _bp_feed(d, W, H):
    cx, cy = W * 0.5, H * 0.52
    pts = [(cx + math.cos(math.pi / 6 + i * math.pi / 3) * 96,
            cy + math.sin(math.pi / 6 + i * math.pi / 3) * 78) for i in range(6)]
    d.line(pts + [pts[0]], fill=(97, 216, 255, 255), width=4)
    for sx in (-1.0, -0.4, 0.4, 1.0):
        _bp_line(d, [(cx + sx * 96, cy - 70), (cx + sx * 300, cy - 210)], 2)
    _bp_line(d, [(cx, cy + 78), (cx, cy + 150)], 4)
    d.arc([cx - 70, cy + 130, cx + 70, cy + 200], 0, 180, fill=(216, 168, 77, 255), width=4)


def _bp_signal(d, W, H):
    cx, cy = W * 0.5, H * 0.52
    # signal chain: horn -> receiver -> backend -> recorder
    y = cy + 20
    for i in range(4):
        x = 120 + i * 220
        d.rectangle([x - 60, y - 40, x + 60, y + 40], outline=(97, 216, 255, 255), width=3)
        if i < 3:
            _bp_line(d, [(x + 60, y), (x + 160, y)], 3, (216, 168, 77))
            d.polygon([(x + 160, y), (x + 144, y - 9), (x + 144, y + 9)], fill=(216, 168, 77, 255))
    # a folded pulse profile under the chain
    prof = []
    for k in range(120):
        t = k / 119.0
        px = 150 + t * 600
        py = y + 170 - (max(0.0, math.sin(((t * 2.0) % 1.0) * math.pi)) ** 12) * 90
        prof.append((px, py))
    d.line(prof, fill=(103, 215, 139, 255), width=3)


SPACE_PARTS = [
    ("segmented_primary_array", segmented_primary_array,
     "18-segment gold-coated beryllium primary mirror array"),
    ("deployable_secondary_mirror", space_secondary_mirror,
     "Convex secondary mirror on deployable tripod struts"),
    ("fine_steering_mirror", fine_steering_mirror,
     "Gimballed fine steering mirror for line-of-sight stabilisation"),
    ("tertiary_mirror_module", tertiary_mirror_module,
     "Fixed tertiary mirror module folding light toward the instruments"),
    ("five_layer_sunshield", space_sunshield,
     "Five-layer tennis-court sunshield, kite planform"),
    ("space_telescope_bus", space_telescope_bus,
     "Spacecraft bus: power, propulsion, avionics and comms"),
    ("deployable_tower", deployable_tower,
     "Deployable tower separating the cold optics from the warm bus"),
    ("deployment_hinges", deployment_hinges,
     "Motorised hinge set for wing and sunshield deployment"),
    ("infrared_instrument_package", isim_package,
     "ISIM integrated science instrument package"),
    ("nircam_instrument", nircam,
     "NIRCam near-infrared camera (0.6-5 micron imaging)"),
    ("nirspec_instrument", nirspec,
     "NIRSpec near-infrared multi-object spectrograph"),
    ("miri_instrument", miri,
     "MIRI mid-infrared imager and spectrograph (5-28 micron, ~7 K)"),
    ("fgs_niriss_instrument", fgs_niriss,
     "FGS/NIRISS fine guidance sensor and near-IR imager-slitless spectrograph"),
    ("solar_array", solar_array,
     "Photovoltaic wing on the sun-facing side of the sunshield"),
    ("communication_antenna", communication_antenna,
     "Steerable high-gain antenna for the science downlink"),
    ("thermal_radiator", thermal_radiator,
     "Passive radiator rejecting instrument heat to deep space"),
    ("instrument_bay", instrument_bay,
     "Instrument bay frame carrying four cold instrument slots"),
    ("infrared_detector_module", infrared_detector_module,
     "HgCdTe infrared detector module with its cold shield"),
]

FAST_PARTS = [
    ("fast_active_dish", fast_active_dish,
     "500 m active primary reflector set in its karst basin"),
    ("reflector_panel_segment", reflector_panel_segment,
     "Perforated triangular reflector panel of the active surface"),
    ("panel_actuator", panel_actuator,
     "Down-tied screw-jack actuator that shapes the active surface"),
    ("suspended_feed_cabin", suspended_feed_cabin,
     "Cable-suspended feed cabin riding above the dish"),
    ("feed_cabin_receiver", feed_cabin_receiver,
     "Cryogenic corrugated feed horn and receiver front end"),
    ("feed_cabin_cable_system", feed_cabin_cable_system,
     "Six-tower cable-drive suspension for the feed cabin"),
    ("cable_tension_controller", cable_tension_controller,
     "Winch and tension controller for the support cables"),
    ("radio_frequency_receiver", lambda: _rack(_rows_spectrum, CYAN, 1),
     "Wideband radio-frequency receiver front end"),
    ("signal_spectrum_monitor", lambda: _rack(_rows_spectrum, CYAN, 2, 2),
     "Live spectrum monitor across the tuned band"),
    ("radio_signal_processor", lambda: _rack(_rows_data, GREEN_OK, 3),
     "Digital backend channelising and integrating the signal"),
    ("pulsar_timing_console", lambda: _rack(_rows_pulse, GREEN_OK, 4),
     "Pulsar folding and timing console"),
    ("rfi_monitor", lambda: _rack(_rows_rfi, RED_WARN, 5, 2),
     "Radio-frequency-interference monitor"),
    ("data_recording_console", lambda: _rack(_rows_timing, GOLD_HI, 6),
     "Observation data recorder and archive console"),
    ("observatory_control_terminal", lambda: _rack(_rows_terminal, CYAN, 7, 4),
     "Observatory master control terminal"),
]

BLUEPRINTS = [
    ("space_main_blueprint", 880, 700, _bp_space_main, "Space telescope main assembly board",
     {"sunshield": [96, 452, 160, 130], "optical_tube_assembly": [352, 60, 190, 150],
      "spacecraft_bus": [628, 452, 160, 130], "solar_array": [96, 90, 160, 130]}),
    ("space_mirror_blueprint", 900, 660, _bp_mirror, "Mirror wing deployment board",
     {"segmented_primary_array": [368, 236, 172, 150], "deployable_secondary_mirror": [400, 26, 120, 110],
      "tertiary_mirror_module": [70, 300, 120, 110], "fine_steering_mirror": [710, 300, 120, 110],
      "deployable_tower": [420, 500, 110, 120], "deployment_hinges": [70, 60, 120, 110]}),
    ("space_instrument_blueprint", 880, 640, _bp_instruments, "Science instrument bay board",
     {"instrument_bay": [348, 244, 180, 150], "nircam_instrument": [70, 60, 130, 120],
      "nirspec_instrument": [676, 60, 130, 120], "miri_instrument": [70, 452, 130, 120],
      "fgs_niriss_instrument": [676, 452, 130, 120], "infrared_detector_module": [376, 60, 130, 120]}),
    ("space_thermal_blueprint", 880, 620, _bp_thermal, "Thermal and sunshield system board",
     {"five_layer_sunshield": [330, 340, 220, 160], "thermal_radiator": [70, 110, 140, 120],
      "space_telescope_bus": [666, 110, 140, 120], "communication_antenna": [666, 400, 140, 120]}),
    ("fast_main_blueprint", 900, 660, _bp_fast_main, "FAST observatory main board",
     {"fast_active_dish": [330, 372, 240, 160], "suspended_feed_cabin": [386, 118, 128, 116],
      "feed_cabin_cable_system": [60, 96, 140, 120], "observatory_control_terminal": [700, 460, 140, 120]}),
    ("fast_feed_blueprint", 880, 640, _bp_feed, "Feed cabin alignment board",
     {"suspended_feed_cabin": [360, 246, 160, 140], "feed_cabin_receiver": [70, 70, 130, 120],
      "cable_tension_controller": [676, 70, 130, 120], "panel_actuator": [70, 450, 130, 120],
      "reflector_panel_segment": [676, 450, 130, 120]}),
    ("fast_signal_blueprint", 900, 620, _bp_signal, "Radio signal processing chain board",
     {"radio_frequency_receiver": [56, 70, 150, 130], "signal_spectrum_monitor": [276, 70, 150, 130],
      "radio_signal_processor": [496, 70, 150, 130], "rfi_monitor": [716, 70, 150, 130],
      "pulsar_timing_console": [276, 420, 150, 130], "data_recording_console": [496, 420, 150, 130]}),
]


def main():
    print("=== SPACE INFRARED OBSERVATORY PARTS ===")
    for name, fn, note in SPACE_PARTS:
        save(fn(), SPACE_DIR, name, note, "part_sprite")
    print("=== FAST RADIO PARTS ===")
    for name, fn, note in FAST_PARTS:
        save(fn(), FAST_DIR, name, note, "part_sprite")

    print("=== BLUEPRINT BOARDS ===")
    for name, w, h, art, note, slots in BLUEPRINTS:
        img, d = blueprint(w, h, None)
        art(d, w, h)
        for box in slots.values():
            dashed_rect(d, (box[0], box[1], box[0] + box[2], box[1] + box[3]))
        save_blueprint(img, name, note, slots)

    with open(os.path.join(ROOT, "data", "art_manifest.json"), "w", encoding="utf-8") as f:
        json.dump({
            "generated_by": "tools/art/build_space_fast_art.py",
            "style": ("pixel-realistic astronomy UI; deep navy / black / gold / silver / cyan; "
                      "single light source upper-left; consistent 3/4 perspective; "
                      "500x500 RGBA transparent part sprites"),
            "all_temporary_art": True,
            "how_to_replace": ("Drop a final PNG at the same res_path. Keep it 500x500 RGBA with a "
                               "transparent background and one centred, uncropped part. Then set "
                               "temporary_art=false here. No code or level-data change is required, "
                               "because icon_path already points at this path."),
            "assets": MANIFEST,
        }, f, indent=2, ensure_ascii=False)
    print("\nmanifest: data/art_manifest.json (%d assets)" % len(MANIFEST))


if __name__ == "__main__":
    main()
