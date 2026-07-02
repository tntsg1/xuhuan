extends CanvasLayer

var _paused := false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/ResumeBtn.pressed.connect(_on_resume)
	$Panel/RestartBtn.pressed.connect(_on_restart)
	$Panel/MenuBtn.pressed.connect(_on_menu)


func _input(event):
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_pause()


func _pause():
	_paused = true
	visible = true
	get_tree().paused = true


func _resume():
	_paused = false
	visible = false
	get_tree().paused = false


func _on_resume():
	_resume()


func _on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
