extends SceneTree

const ROOTS := ["res://scripts", "res://data"]
const BAD_TEXT := ["�", "锟斤拷", "鍒嗙粍", "瑙傛祴鍦扮偣", "鑿滃崟", "瑙︽帶", "鏈涜繙闀滃浘閴"]
var failures := 0


func _initialize() -> void:
	for root_path in ROOTS:
		_scan_directory(root_path)
	print("UTF8 TEXT SCAN TEST PASS" if failures == 0 else "UTF8 TEXT SCAN TEST FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_fail("cannot scan " + path)
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := path.path_join(name)
			if directory.current_is_dir():
				_scan_directory(child)
			elif name.ends_with(".gd") or name.ends_with(".json") or name.ends_with(".tscn"):
				_scan_file(child)
		name = directory.get_next()
	directory.list_dir_end()


func _scan_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot read " + path)
		return
	var contents := file.get_as_text()
	for marker in BAD_TEXT:
		if contents.contains(marker):
			_fail("mojibake marker '%s' in %s" % [marker, path])


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)
