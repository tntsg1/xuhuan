extends Node

var levels: Array = []


func load_levels(level_data: Array) -> void:
	levels = level_data


func get_level(level_number: int) -> Dictionary:
	for level in levels:
		if int(level.get("level_number", 0)) == level_number:
			return level
	if levels.is_empty():
		return {}
	return levels[min(levels.size() - 1, max(0, level_number - 1))]


func is_final_level(level_number: int) -> bool:
	return level_number >= levels.size()


func get_max_level() -> int:
	return levels.size()
