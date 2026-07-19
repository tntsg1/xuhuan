extends RefCounted
class_name AssemblyManager

const CORE_ORDER := ["tripod", "mount", "tube", "objective", "eyepiece"]
const REQUIRED_CORE := ["tripod", "mount", "tube", "objective", "eyepiece"]


static func can_install(part_type: String, assembly_state: Dictionary) -> Dictionary:
	var order_index := CORE_ORDER.find(part_type)
	if order_index == -1:
		if part_type == "focus_knob":
			# The focus knob mounts on the eyepiece holder, so the eyepiece
			# must already be in place.
			if not bool(assembly_state.get("eyepiece", {}).get("installed", false)):
				return {
					"ok": false,
					"reason": "Install Eyepiece first. The focus knob moves the eyepiece.\n请先安装目镜。调焦旋钮用来移动目镜。"
				}
			return {"ok": true, "reason": ""}
		return {"ok": part_type == "finder_scope", "reason": ""}
	for i in range(order_index):
		var required_type: String = CORE_ORDER[i]
		if not bool(assembly_state.get(required_type, {}).get("installed", false)):
			return {
				"ok": false,
				"reason": "Install " + required_type.capitalize() + " first.\n请先安装 " + _zh_name(required_type) + "。"
			}
	return {"ok": true, "reason": ""}


static func alignment_from_wrong_attempts(wrong_attempts: int) -> int:
	if wrong_attempts <= 0:
		return 100
	if wrong_attempts == 1:
		return 85
	return 70


static func is_complete(assembly_state: Dictionary, required_parts: Array = []) -> bool:
	for part_type in _required_list(required_parts):
		if not bool(assembly_state.get(part_type, {}).get("installed", false)):
			return false
	return true


static func missing_parts(assembly_state: Dictionary, required_parts: Array = []) -> Array:
	var missing: Array = []
	for part_type in _required_list(required_parts):
		if not bool(assembly_state.get(part_type, {}).get("installed", false)):
			missing.append(part_type)
	return missing


static func _required_list(required_parts: Array) -> Array:
	# Legacy refractor levels use their default core. Advanced telescope
	# families provide a complete independent required_parts contract.
	if not required_parts.is_empty():
		return required_parts.duplicate()
	var required := REQUIRED_CORE.duplicate()
	for part_value in required_parts:
		var part := str(part_value)
		if not required.has(part):
			required.append(part)
	return required


static func _zh_name(part_type: String) -> String:
	var names := {
		"tripod": "三脚架",
		"mount": "支架",
		"tube": "镜筒",
		"objective": "物镜",
		"eyepiece": "目镜",
		"finder_scope": "寻星镜",
		"focus_knob": "调焦旋钮"
	}
	return names.get(part_type, part_type)
