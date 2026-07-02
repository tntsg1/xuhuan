extends RefCounted
class_name TelescopeMath

const CORE_PARTS := ["tripod", "mount", "tube", "objective", "eyepiece"]


static func calculate(parts: Dictionary, assembly_state: Dictionary) -> Dictionary:
	var tripod: Dictionary = _dict_value(parts.get("tripod", {}))
	var mount: Dictionary = _dict_value(parts.get("mount", {}))
	var tube: Dictionary = _dict_value(parts.get("tube", {}))
	var objective: Dictionary = _dict_value(parts.get("objective", {}))
	var eyepiece: Dictionary = _dict_value(parts.get("eyepiece", {}))
	if objective.is_empty() or eyepiece.is_empty():
		return _empty_stats()

	var objective_focal: float = float(objective.get("focal_length_mm", 1.0))
	var eyepiece_focal: float = maxf(1.0, float(eyepiece.get("focal_length_mm", 1.0)))
	var aperture: float = float(objective.get("aperture_mm", 1.0))
	var magnification: float = objective_focal / eyepiece_focal
	var light_score: float = clampf(aperture / 120.0 * 100.0, 0.0, 100.0)
	var base_stability: float = float(mount.get("stability", 0.0)) * 0.65 + float(tripod.get("stability_bonus", 0.0)) * 0.35
	var base_quality: float = float(objective.get("quality", 0.0)) * 0.4
	base_quality += float(eyepiece.get("quality", 0.0)) * 0.3
	base_quality += float(tube.get("alignment_quality", 0.0)) * 0.2
	base_quality += float(mount.get("stability", 0.0)) * 0.1
	var useful_limit: float = aperture * 2.0
	var assembly_score: float = get_assembly_score(assembly_state)
	var clarity: float = base_quality * assembly_score / 100.0
	if magnification > useful_limit:
		clarity -= (magnification - useful_limit) * 0.5
	clarity = clampf(clarity, 0.0, 100.0)
	var mount_state: Dictionary = _dict_value(assembly_state.get("mount", {}))
	var mount_alignment: float = float(mount_state.get("alignment_score", 0.0))
	var stability: float = clampf(base_stability * mount_alignment / 100.0, 0.0, 100.0)
	var field_of_view: float = float(eyepiece.get("field_of_view", 0.0)) / maxf(1.0, magnification) * 20.0
	return {
		"magnification": snapped(magnification, 0.1),
		"light_score": snapped(light_score, 0.1),
		"stability_score": snapped(stability, 0.1),
		"clarity_score": snapped(clarity, 0.1),
		"field_of_view": snapped(field_of_view, 0.1),
		"assembly_score": snapped(assembly_score, 0.1),
		"useful_magnification_limit": snapped(useful_limit, 0.1)
	}


static func get_assembly_score(assembly_state: Dictionary) -> float:
	var scores: Array[float] = []
	for part_type in CORE_PARTS:
		var entry: Dictionary = _dict_value(assembly_state.get(part_type, {}))
		if bool(entry.get("installed", false)):
			scores.append(float(entry.get("alignment_score", 0.0)))
	var finder: Dictionary = _dict_value(assembly_state.get("finder_scope", {}))
	if bool(finder.get("installed", false)):
		scores.append(float(finder.get("alignment_score", 0.0)))
	if scores.is_empty():
		return 0.0
	var total: float = 0.0
	for score in scores:
		total += score
	return total / float(scores.size())


static func _empty_stats() -> Dictionary:
	return {
		"magnification": 0.0,
		"light_score": 0.0,
		"stability_score": 0.0,
		"clarity_score": 0.0,
		"field_of_view": 0.0,
		"assembly_score": 0.0,
		"useful_magnification_limit": 0.0
	}


static func _dict_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
