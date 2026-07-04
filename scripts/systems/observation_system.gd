extends RefCounted
class_name ObservationSystem


static func evaluate(stats: Dictionary, celestial_object: Dictionary, extra_context: Dictionary = {}) -> Dictionary:
	var observation_mode := str(extra_context.get("observation_mode", "telescope"))
	if observation_mode == "naked_eye":
		return _evaluate_naked_eye(celestial_object)
	return _evaluate_telescope(stats, celestial_object, extra_context)


static func _evaluate_naked_eye(celestial_object: Dictionary) -> Dictionary:
	# Naked-eye viewing ignores telescope stats entirely. What matters is
	# whether the object is bright enough for human eyes.
	var visible := bool(celestial_object.get("naked_eye_visible", false))
	var brightness := float(celestial_object.get("brightness", 0.0))
	var object_type := str(celestial_object.get("type_en", "")).to_lower()

	var quality := "Failed"
	var feedback_en := "This object is far too faint for naked eyes. A telescope is needed."
	var feedback_zh := "这个目标对肉眼来说太暗了，需要望远镜。"
	var visual_effect := "clear"

	if not visible:
		quality = "Failed"
		visual_effect = "dim"
	elif brightness >= 90.0:
		quality = "Excellent"
		feedback_en = "The Moon is bright enough to see with your eyes, but a telescope reveals more detail."
		feedback_zh = "月亮足够亮，肉眼就能看见，但望远镜能揭示更多细节。"
	elif brightness >= 60.0:
		quality = "Good"
		feedback_en = "Bright objects like this are within reach of your naked eyes."
		feedback_zh = "像这样的明亮目标，肉眼就能看到。"
		if object_type.contains("planet"):
			feedback_en = "To your eyes a planet is just a steady bright point. A telescope shows its disk."
			feedback_zh = "在肉眼里行星只是一个稳定的亮点，望远镜才能看到它的圆面。"
	else:
		quality = "Fair"
		visual_effect = "dim"
		feedback_en = "You can barely make it out. Your eyes collect only a little light."
		feedback_zh = "勉强能看到。眼睛能收集的光很有限。"

	return {
		"quality": quality,
		"success": quality == "Excellent" or quality == "Good",
		"visual_effect": visual_effect,
		"feedback_en": feedback_en,
		"feedback_zh": feedback_zh,
		"observation_mode": "naked_eye",
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}
	}


static func _evaluate_telescope(stats: Dictionary, celestial_object: Dictionary, extra_context: Dictionary) -> Dictionary:
	var focus_error := float(extra_context.get("focus_error", 0.0))
	var requires_focus := bool(extra_context.get("requires_focus", false))
	var focus_tolerance := float(extra_context.get("focus_tolerance", 0.06))
	var minimum_success_quality := str(extra_context.get("minimum_success_quality", "Good"))

	# Out-of-focus optics lose clarity before anything else.
	var effective_clarity := float(stats.get("clarity_score", 0.0)) - focus_error * 120.0
	effective_clarity = clampf(effective_clarity, 0.0, 100.0)

	var light_ratio := _ratio(float(stats.get("light_score", 0.0)), float(celestial_object.get("required_light_score", 1.0)))
	var clarity_ratio := _ratio(effective_clarity, float(celestial_object.get("required_clarity", 1.0)))
	var stability_ratio := _ratio(float(stats.get("stability_score", 0.0)), float(celestial_object.get("required_stability", 1.0)))
	var min_ratio: float = min(light_ratio, min(clarity_ratio, stability_ratio))
	var quality := "Failed"
	if min_ratio >= 1.3:
		quality = "Excellent"
	elif min_ratio >= 1.0:
		quality = "Good"
	elif min_ratio >= 0.75:
		quality = "Fair"
	elif min_ratio >= 0.45:
		quality = "Poor"

	var out_of_focus := requires_focus and focus_error > focus_tolerance
	if out_of_focus:
		# You cannot claim a top-quality observation with a blurred image.
		if quality == "Excellent" or quality == "Good":
			quality = "Fair"
	var success := (not out_of_focus) and _quality_rank(quality) >= _quality_rank(minimum_success_quality)

	var visual_effect := "clear"
	var feedback_en := "Good observation. Identify the object to complete the mission."
	var feedback_zh := "观测效果不错。识别目标即可完成任务。"
	if out_of_focus:
		visual_effect = "blurry"
		feedback_en = "The image is out of focus. Adjust the focus knob until the target becomes sharp."
		feedback_zh = "图像失焦了。请转动调焦旋钮，直到目标变清晰。"
	elif light_ratio < clarity_ratio and light_ratio < stability_ratio:
		visual_effect = "dim"
		feedback_en = "This object is dim with the current telescope. A larger objective lens would collect more light."
		feedback_zh = "这个目标在当前望远镜里偏暗。更大口径的物镜能收集更多光。"
	elif clarity_ratio < stability_ratio:
		visual_effect = "blurry"
		feedback_en = "The image is blurry. Better alignment or lower magnification can improve clarity."
		feedback_zh = "图像有些模糊。更好的安装对齐或更低倍率能提升清晰度。"
	elif stability_ratio < 1.0:
		visual_effect = "shaky"
		feedback_en = "The telescope is shaking. A stable mount makes planets and stars easier to observe."
		feedback_zh = "望远镜正在抖动。稳定支架会让行星和恒星更容易观测。"
	elif quality == "Excellent":
		feedback_en = "Excellent observation. Your telescope setup is comfortably above the target requirements."
		feedback_zh = "优秀观测。你的望远镜配置明显高于目标要求。"
	elif quality == "Fair":
		feedback_en = "The target is barely visible. You can study it, but this is not strong enough for mission completion."
		feedback_zh = "目标勉强可见。你能看到它，但还不足以完成任务。"
		if success:
			feedback_en = "The target is faint but usable for this first deep-sky observation. Identify it to complete the mission."
		else:
			feedback_en = "Focus is aligned, but this deep-sky target is still too faint for this mission. Upgrade aperture or stability."
	elif quality == "Poor" or quality == "Failed":
		feedback_en = "The target is too hard to see. Return to the workshop and improve the telescope."
		feedback_zh = "目标太难看清。回到组装台改进望远镜。"
	return {
		"quality": quality,
		"success": success,
		"visual_effect": visual_effect,
		"feedback_en": feedback_en,
		"feedback_zh": feedback_zh,
		"observation_mode": "telescope",
		"focus_error": focus_error,
		"out_of_focus": out_of_focus,
		"effective_clarity": effective_clarity,
		"ratios": {
			"light": light_ratio,
			"clarity": clarity_ratio,
			"stability": stability_ratio
		}
	}


static func _ratio(value: float, required: float) -> float:
	return value / max(1.0, required)


static func _quality_rank(quality: String) -> int:
	match quality:
		"Failed":
			return 0
		"Poor":
			return 1
		"Fair":
			return 2
		"Good":
			return 3
		"Excellent":
			return 4
	return 3
