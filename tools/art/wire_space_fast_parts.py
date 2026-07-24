"""
Wires the generated Space Infrared Observatory + FAST art into
data/advanced_telescope_parts.json.

Rules honoured here:
  * the SEVEN pre-existing part ids are kept exactly as they are (they are
    referenced by required_part_ids / unlock_parts across L66-L85 and by old
    saves) - they only gain a real icon_path and lose is_placeholder;
  * every new part uses a space/radio-specific `type`; none of them reuse the
    refractor/newtonian eyepiece, objective, focuser, finder or tripod types;
  * unlock_level respects the family floors the timeline test enforces
    (space_segmented >= 65, fast_radio >= 75), which also fixes the stale
    unlock_level=55 leak on the four original space parts. NOTE: the value must
    also be a level that still EXISTS in campaign_order - the gregorian block
    L56-L65 was retired, so order_index(65) is -1 and a part pinned to 65 would
    never unlock at all. The space family therefore starts at L66;
  * every icon_path points at a file that actually exists.

    python tools/art/wire_space_fast_parts.py
"""
from __future__ import annotations

import io
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PARTS = os.path.join(ROOT, "data", "advanced_telescope_parts.json")
SPACE_ICON = "res://assets/telescope_parts/space_segmented/%s.png"
FAST_ICON = "res://assets/telescope_parts/fast_radio/%s.png"


def sp(pid, art, ptype, role, en, zh, den, dzh, unlock, quality, extra=None):
    d = {
        "id": pid,
        "type": ptype,
        "name_en": en,
        "name_zh": zh,
        "description_en": den,
        "description_zh": dzh,
        "telescope_family": "space_segmented",
        "optical_role": role,
        "quality": quality,
        "unlock_level": unlock,
        "is_placeholder": False,
        "temporary_art": True,
        "icon_path": SPACE_ICON % art,
    }
    if extra:
        d.update(extra)
    return d


def fa(pid, art, ptype, role, en, zh, den, dzh, unlock, quality, extra=None):
    d = {
        "id": pid,
        "type": ptype,
        "name_en": en,
        "name_zh": zh,
        "description_en": den,
        "description_zh": dzh,
        "telescope_family": "fast_radio",
        "optical_role": role,
        "quality": quality,
        "unlock_level": unlock,
        "is_placeholder": False,
        "temporary_art": True,
        "icon_path": FAST_ICON % art,
    }
    if extra:
        d.update(extra)
    return d


# ---- the four original space ids keep their id/type, gain art + correct unlock
EXISTING_SPACE = {
    "segmented_primary_array": ("segmented_primary_array", 66),
    "space_secondary_mirror": ("deployable_secondary_mirror", 66),
    "infrared_instrument_package": ("infrared_instrument_package", 66),
    "space_sunshield": ("five_layer_sunshield", 66),
}
EXISTING_FAST = {
    "fast_active_dish": ("fast_active_dish", 75),
    "fast_feed_cabin": ("suspended_feed_cabin", 75),
    "fast_signal_processor": ("radio_signal_processor", 75),
}

NEW_SPACE = [
    sp("space_fine_steering_mirror", "fine_steering_mirror", "steering_mirror", "fine_steering",
       "Fine Steering Mirror", "精细导向镜",
       "Tips a few microradians at a time to hold the target still on the detector.",
       "以微弧度级别快速偏转，把目标稳定地压在探测器同一位置上。", 66, 92,
       {"pointing_stability": 95}),
    sp("space_tertiary_mirror", "tertiary_mirror_module", "tertiary_mirror", "tertiary",
       "Tertiary Mirror Module", "三级反射镜组件",
       "Folds the beam from the secondary toward the instrument bay.",
       "把副镜反射回来的光束折向仪器舱。", 66, 90),
    sp("space_bus", "space_telescope_bus", "spacecraft_bus", "bus",
       "Space Telescope Bus", "航天器平台",
       "Carries power, propulsion, avionics and the downlink on the warm sun side.",
       "位于向阳的热面，承载供电、推进、航电与数据下行。", 66, 88,
       {"station_keeping": 90}),
    sp("space_deployable_tower", "deployable_tower", "deployable_tower", "tower",
       "Deployable Tower", "可展开塔架",
       "Extends after launch to separate the cold optics from the warm bus.",
       "入轨后伸展，把低温光学部分与温热平台分开。", 66, 86),
    sp("space_deployment_hinges", "deployment_hinges", "deployment_hinges", "hinges",
       "Deployment Hinges", "展开铰链组",
       "Motorised hinges that unfold the mirror wings and the sunshield.",
       "带电机的铰链，负责展开镜翼与遮阳罩。", 66, 84),
    sp("space_nircam", "nircam_instrument", "nircam", "near_infrared_imager",
       "NIRCam Instrument", "NIRCam 近红外相机",
       "Near-infrared camera, 0.6-5 microns. Best for imaging stars, galaxies and star-forming regions.",
       "近红外相机，覆盖 0.6-5 微米，最适合拍摄恒星、星系与恒星形成区的图像。", 67, 94,
       {"band": "near_infrared", "mode": "imaging",
        "wavelength_min_um": 0.6, "wavelength_max_um": 5.0}),
    sp("space_nirspec", "nirspec_instrument", "nirspec", "near_infrared_spectrograph",
       "NIRSpec Instrument", "NIRSpec 近红外光谱仪",
       "Near-infrared spectrograph. Splits light into a spectrum to read composition, temperature, motion and redshift.",
       "近红外光谱仪，把光分解成光谱，用来读出成分、温度、运动速度与红移。", 68, 94,
       {"band": "near_infrared", "mode": "spectroscopy",
        "wavelength_min_um": 0.6, "wavelength_max_um": 5.3}),
    sp("space_miri", "miri_instrument", "miri", "mid_infrared_instrument",
       "MIRI Instrument", "MIRI 中红外仪器",
       "Mid-infrared imager and spectrograph, 5-28 microns. Sees cold dust and planet-forming disks, but needs about 7 K.",
       "中红外成像与光谱仪，覆盖 5-28 微米，可观测冷尘埃与行星形成盘，但需要约 7K 的极低温。", 69, 95,
       {"band": "mid_infrared", "mode": "imaging_spectroscopy",
        "wavelength_min_um": 5.0, "wavelength_max_um": 28.0,
        "requires_active_cooling": True, "max_operating_temp_k": 7.0}),
    sp("space_fgs_niriss", "fgs_niriss_instrument", "fgs_niriss", "guidance_and_imaging",
       "FGS/NIRISS Guidance Instrument", "FGS/NIRISS 导星与成像仪",
       "Fine Guidance Sensor keeps the pointing locked; NIRISS adds slitless near-infrared imaging and spectroscopy.",
       "精细导星敏感器负责锁定指向；NIRISS 提供无缝隙近红外成像与光谱观测。", 70, 92,
       {"band": "near_infrared", "mode": "guidance",
        "wavelength_min_um": 0.8, "wavelength_max_um": 5.0}),
    sp("space_solar_array", "solar_array", "solar_array", "power",
       "Solar Array", "太阳能电池阵",
       "Photovoltaic wing on the sun-facing side of the sunshield.",
       "安装在遮阳罩向阳一侧的光伏板。", 66, 82),
    sp("space_antenna", "communication_antenna", "antenna", "downlink",
       "Communication Antenna", "通信天线",
       "Steerable high-gain antenna that sends the science data home.",
       "可指向的高增益天线，把科学数据传回地面。", 66, 80),
    sp("space_radiator", "thermal_radiator", "radiator", "thermal",
       "Thermal Radiator", "热辐射散热器",
       "Radiates instrument heat away to deep space on the cold side.",
       "在冷面把仪器热量辐射到深空。", 67, 88,
       {"cooling_power": 90}),
    sp("space_instrument_bay", "instrument_bay", "instrument_bay", "bay",
       "Instrument Bay", "仪器舱",
       "The cold frame that holds the four science instruments.",
       "承载四台科学仪器的低温框架。", 67, 86),
    sp("space_detector_module", "infrared_detector_module", "detector_module", "detector",
       "Infrared Detector Module", "红外探测器模块",
       "Converts infrared photons into electrons, read out frame by frame.",
       "把红外光子转换成电子信号，逐帧读出。", 68, 90),
]

NEW_FAST = [
    fa("fast_panel_segment", "reflector_panel_segment", "panel_segment", "reflector_panel",
       "Reflector Panel Segment", "反射面板单元",
       "One perforated triangular panel of the 500 m active surface.",
       "500 米主动反射面上的一块三角形冲孔面板。", 76, 84),
    fa("fast_panel_actuator", "panel_actuator", "panel_actuator", "surface_actuator",
       "Panel Actuator", "面板促动器",
       "Down-tied jack that pulls panels into a 300 m parabola aimed at the target.",
       "下拉式促动器，把面板拉成朝向目标的 300 米瞬时抛物面。", 76, 86),
    fa("fast_feed_receiver", "feed_cabin_receiver", "feed_receiver", "front_end",
       "Feed Cabin Receiver", "馈源舱接收机",
       "Cryogenic feed horn and low-noise front end inside the cabin.",
       "馈源舱内的低温馈源喇叭与低噪声前端。", 77, 92,
       {"system_temperature_k": 20.0}),
    fa("fast_cable_system", "feed_cabin_cable_system", "cable_system", "suspension",
       "Feed Cabin Cable System", "馈源舱索驱动系统",
       "Six tower cables that fly the feed cabin across the dish.",
       "六座塔的钢索，牵引馈源舱在反射面上方移动。", 76, 88),
    fa("fast_tension_controller", "cable_tension_controller", "tension_controller", "cable_control",
       "Cable Tension Controller", "缆索张力控制器",
       "Keeps cable tension inside limits while the cabin moves.",
       "在馈源舱移动时把缆索张力保持在安全范围内。", 77, 85),
    fa("fast_rf_receiver", "radio_frequency_receiver", "rf_receiver", "receiver_chain",
       "Radio Frequency Receiver", "射频接收机",
       "Wideband front end. Sets the observing band and the gain.",
       "宽带前端，决定观测频段与增益。", 77, 90,
       {"band_min_mhz": 70.0, "band_max_mhz": 3000.0}),
    fa("fast_spectrum_monitor", "signal_spectrum_monitor", "spectrum_monitor", "spectrum",
       "Signal Spectrum Monitor", "频谱监视器",
       "Shows the live spectrum so you can place the band away from interference.",
       "显示实时频谱，帮助把观测频段放在干扰之外。", 78, 88),
    fa("fast_pulsar_console", "pulsar_timing_console", "timing_console", "pulsar_timing",
       "Pulsar Timing Console", "脉冲星计时终端",
       "Folds the time series at a trial period and searches dispersion measure.",
       "按试验周期折叠时间序列，并搜索色散量。", 78, 93),
    fa("fast_rfi_monitor", "rfi_monitor", "rfi_monitor", "interference",
       "RFI Monitor", "射电干扰监视器",
       "Flags man-made peaks: radar, satellites, phones, power lines.",
       "标记人造干扰峰：雷达、卫星、手机与电网噪声。", 79, 90),
    fa("fast_data_recorder", "data_recording_console", "data_recorder", "archive",
       "Data Recording Console", "数据记录终端",
       "Records the integrated observation into the archive.",
       "把积分完成的观测记录进档案库。", 79, 84),
    fa("fast_control_terminal", "observatory_control_terminal", "control_terminal", "control",
       "Observatory Control Terminal", "观测站控制终端",
       "Master console: target list, schedule and observation state.",
       "总控台：目标列表、观测计划与状态。", 76, 82),
]


def main():
    parts = json.load(io.open(PARTS, encoding="utf-8"))
    by_id = {p["id"]: p for p in parts}

    for pid, (art, unlock) in EXISTING_SPACE.items():
        p = by_id[pid]
        p["icon_path"] = SPACE_ICON % art
        p["is_placeholder"] = False
        p["temporary_art"] = True
        p["unlock_level"] = unlock
    for pid, (art, unlock) in EXISTING_FAST.items():
        p = by_id[pid]
        p["icon_path"] = FAST_ICON % art
        p["is_placeholder"] = False
        p["temporary_art"] = True
        p["unlock_level"] = unlock

    added = 0
    for p in NEW_SPACE + NEW_FAST:
        if p["id"] in by_id:
            by_id[p["id"]].update(p)
        else:
            parts.append(p)
            added += 1

    # every icon must resolve on disk
    missing = []
    for p in parts:
        icon = str(p.get("icon_path", ""))
        if icon.startswith("res://"):
            rel = icon[len("res://"):]
            if not os.path.exists(os.path.join(ROOT, rel)):
                missing.append((p["id"], icon))
    if missing:
        raise SystemExit("MISSING ICONS: %s" % missing)

    with io.open(PARTS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(parts, f, ensure_ascii=False, indent=2)

    space = [p for p in parts if p.get("telescope_family") == "space_segmented"]
    fast = [p for p in parts if p.get("telescope_family") == "fast_radio"]
    print("added %d new parts; total %d" % (added, len(parts)))
    print("space_segmented: %d parts, all icons present" % len(space))
    print("fast_radio:      %d parts, all icons present" % len(fast))
    banned = {"eyepiece", "objective", "focus_knob", "finder_scope", "tripod"}
    bad = [p["id"] for p in space + fast if p.get("type") in banned]
    print("parts reusing banned optical types: %s" % (bad or "none"))


if __name__ == "__main__":
    main()
