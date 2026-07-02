extends RefCounted
class_name ObservationSystem


static func evaluate(stats: Dictionary, celestial_object: Dictionary) -> Dictionary:
	var light_ratio := _ratio(float(stats.get("light_score", 0.0)), float(celestial_object.get("required_light_score", 1.0)))
	var clarity_ratio := _ratio(float(stats.get("clarity_score", 0.0)), float(celestial_object.get("required_clarity", 1.0)))
	var stability_ratio := _ratio(float(stats.get("stability_score", 0.0)), float(celestial_object.get("required_stability", 1.0)))
	var min_ratio = min(light_ratio, min(clarity_ratio, stability_ratio))
	var quality := "Failed"
	if min_ratio >= 1.3:
		quality = "Excellent"
	elif min_ratio >= 1.0:
		quality = "Good"
	elif min_ratio >= 0.75:
		quality = "Fair"
	elif min_ratio >= 0.45:
		quality = "Poor"
	var visual_effect := "clear"
	var feedback_en := "Good observation. Identify the object to complete the mission."
	var feedback_zh := "观测效果不错。识别目标即可完成任务。"
	if light_ratio < clarity_ratio and light_ratio < stability_ratio:
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
	elif quality == "Poor" or quality == "Failed":
		feedback_en = "The target is too hard to see. Return to the workshop and improve the telescope."
		feedback_zh = "目标太难看清。回到组装台改进望远镜。"
	return {
		"quality": quality,
		"success": quality == "Excellent" or quality == "Good",
		"visual_effect": visual_effect,
		"feedback_en": feedback_en,
		"feedback_zh": feedback_zh,
		"ratios": {
			"light": light_ratio,
			"clarity": clarity_ratio,
			"stability": stability_ratio
		}
	}


static func _ratio(value: float, required: float) -> float:
	return value / max(1.0, required)
