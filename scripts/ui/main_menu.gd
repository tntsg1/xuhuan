extends Control
## Pixel Observatory — Main Menu

func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Deep night sky background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Stars
	for i in range(90):
		var star := ColorRect.new()
		var bright := 0.5 + fmod(float(i), 5.0) * 0.1
		star.color = Color(bright, bright + 0.03, 0.92 + fmod(float(i), 3.0) * 0.04, 0.7 + fmod(float(i * 7), 3.0) * 0.1)
		star.size = Vector2(2 + fmod(float(i), 2.0), 2 + fmod(float(i), 2.0))
		star.position = Vector2(fmod(float(i * 131), 1020.0) + 4, fmod(float(i * 67), 740.0) + 8)
		add_child(star)

	# Floating island silhouette at bottom
	var island := ColorRect.new()
	island.color = Color(0.04, 0.06, 0.03)
	island.position = Vector2(162, 580)
	island.size = Vector2(700, 120)
	add_child(island)
	var island_top := ColorRect.new()
	island_top.color = Color(0.06, 0.10, 0.04)
	island_top.position = Vector2(182, 560)
	island_top.size = Vector2(660, 24)
	add_child(island_top)

	# Small telescope silhouette on island
	var tele := ColorRect.new()
	tele.color = Color(0.12, 0.15, 0.20)
	tele.position = Vector2(448, 470)
	tele.size = Vector2(160, 80)
	add_child(tele)
	var tele_tube := ColorRect.new()
	tele_tube.color = Color(0.18, 0.22, 0.30)
	tele_tube.position = Vector2(468, 462)
	tele_tube.size = Vector2(120, 12)
	add_child(tele_tube)

	# Menu panel
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.04, 0.05, 0.08, 0.88)
	panel_bg.position = Vector2(272, 92)
	panel_bg.size = Vector2(480, 440)
	add_child(panel_bg)

	var panel_border := ColorRect.new()
	panel_border.color = Color(0.22, 0.35, 0.50, 0.4)
	panel_border.position = Vector2(270, 90)
	panel_border.size = Vector2(484, 444)
	add_child(panel_border)

	var box := VBoxContainer.new()
	box.size = Vector2(440, 380)
	box.position = Vector2(292, 122)
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	var title := _label("Pixel Observatory\n像素观测站", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := _label(GameManager.text(
		"Build your telescope, observe the night sky, and learn how astronomers explore the universe.",
		"组装望远镜，观察夜空，学习天文学家如何探索宇宙。"
	), 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var new_button := _button(GameManager.text("New Game", "新游戏"))
	new_button.pressed.connect(_on_new_game)
	box.add_child(new_button)

	var continue_button := _button(GameManager.text("Continue", "继续"))
	continue_button.disabled = not GameManager.has_save()
	continue_button.pressed.connect(_on_continue)
	box.add_child(continue_button)

	var language_button := _button(GameManager.text("Language: EN + 中文", "语言：EN + 中文"))
	language_button.pressed.connect(_on_language)
	box.add_child(language_button)

	var quit_button := _button(GameManager.text("Quit", "退出"))
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

	# Version text
	var version := _label("v0.2 — Made with Godot 4 + Sprout Lands + Tiny Swords", 11)
	version.position = Vector2(292, 542)
	version.size = Vector2(440, 20)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	add_child(version)


func _on_new_game() -> void:
	GameManager.new_game()
	# Astronomy Club opening scene: Maya welcomes the new member.
	if GameManager.try_story_event("intro", "observatory"):
		return
	GameManager.go("observatory")


func _on_continue() -> void:
	GameManager.go("observatory")


func _on_language() -> void:
	GameManager.cycle_language()
	_build()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(400, 50)
	button.add_theme_font_size_override("font_size", 17)
	return button
