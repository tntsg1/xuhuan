extends Control
## Learning Journal — 学习日志（重新设计版）

const QUALITY_COLORS := {
	"Excellent": Color(0.30, 0.95, 0.50),
	"Good": Color(0.50, 0.85, 0.30),
	"Fair": Color(0.95, 0.80, 0.20),
	"Poor": Color(1.0, 0.50, 0.20),
	"Failed": Color(1.0, 0.25, 0.25),
}

var _scroll: ScrollContainer
var _entry_list: VBoxContainer


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Subtle grid dots
	for i in range(60):
		var dot := ColorRect.new()
		dot.color = Color(0.08, 0.07, 0.10, 0.4)
		dot.position = Vector2(fmod(float(i * 151), 1024.0), fmod(float(i * 89), 768.0))
		dot.size = Vector2(2, 2)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)

	# Top bar
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.08, 0.10, 0.15, 0.90)
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1024, 56)
	add_child(top_bar)

	var title := _make_label("📖  Club Logbook", 24)
	title.position = Vector2(28, 10)
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.80))
	add_child(title)

	var subtitle := _make_label("俱乐部观测日志", 14)
	subtitle.position = Vector2(300, 18)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
	add_child(subtitle)

	# Back button — top right, clean
	var back_btn := Button.new()
	back_btn.text = GameManager.text("←  Back", "←  返回")
	back_btn.position = Vector2(850, 10)
	back_btn.size = Vector2(150, 36)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

	# Scrollable entries
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(28, 72)
	_scroll.size = Vector2(968, 680)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_entry_list = VBoxContainer.new()
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_entry_list)

	_populate()


func _populate() -> void:
	var entries: Array = GameManager.progress.get("journal_entries", [])

	if entries.is_empty():
		var empty := _make_label("No observations recorded yet.\n还没有观测记录。\n\nComplete a mission to see your first entry here!", 16)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.position = Vector2(180, 180)
		empty.size = Vector2(600, 120)
		_entry_list.add_child(empty)
		return

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var name_en: String = str(entry.get("object_name_en", ""))
		var name_zh: String = str(entry.get("object_name_zh", ""))
		if name_en == "" and name_zh == "":
			continue  # skip empty entries

		var quality: String = str(entry.get("observation_quality", "Good"))
		var assembly: float = float(entry.get("assembly_score", 0.0))
		var learn_en: String = str(entry.get("learning_text_en", ""))
		var learn_zh: String = str(entry.get("learning_text_zh", ""))
		# Unlocked concept card, e.g. "Concept: How Your Eye Forms an Image"
		var concept_en: String = str(entry.get("concept_title_en", ""))
		var concept_zh: String = str(entry.get("concept_title_zh", ""))
		if concept_en != "":
			learn_en = "Concept: " + concept_en + "\n" + learn_en
		if concept_zh != "":
			learn_zh = "学到的原理：" + concept_zh + "\n" + learn_zh

		_entry_list.add_child(_build_entry_card(i + 1, name_en, name_zh, quality, assembly, learn_en, learn_zh))


func _build_entry_card(num: int, name_en: String, name_zh: String, quality: String, assembly: float, learn_en: String, learn_zh: String) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(940, 120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Card background
	var card_bg := ColorRect.new()
	card_bg.color = Color(0.07, 0.06, 0.10, 0.85)
	card_bg.position = Vector2.ZERO
	card_bg.size = Vector2(940, 130)
	card.add_child(card_bg)

	# Left accent bar (color-coded by quality)
	var accent := ColorRect.new()
	accent.color = QUALITY_COLORS.get(quality, Color(0.5, 0.5, 0.5))
	accent.position = Vector2(0, 0)
	accent.size = Vector2(5, 130)
	card.add_child(accent)

	# Entry number
	var num_label := _make_label("#%d" % num, 13)
	num_label.position = Vector2(18, 10)
	num_label.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	card.add_child(num_label)

	# Object name (large)
	var name_text := name_en
	if name_zh != "":
		name_text += "  /  " + name_zh
	var name_label := _make_label(name_text, 19)
	name_label.position = Vector2(54, 10)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	card.add_child(name_label)

	# Quality badge
	var badge_bg := ColorRect.new()
	var qc := Color(0.5, 0.5, 0.5)
	if QUALITY_COLORS.has(quality):
		qc = QUALITY_COLORS[quality]
	badge_bg.color = Color(qc.r, qc.g, qc.b, 0.20)
	badge_bg.position = Vector2(740, 6)
	badge_bg.size = Vector2(88, 22)
	card.add_child(badge_bg)

	var badge := _make_label(quality, 12)
	badge.position = Vector2(746, 8)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", qc)
	card.add_child(badge)

	# Assembly score
	var asm_label := _make_label("Assembly: %d" % int(assembly), 13)
	asm_label.position = Vector2(838, 8)
	asm_label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.65))
	card.add_child(asm_label)

	# Learning text
	var learn_full := learn_en
	if learn_zh != "":
		learn_full += "\n" + learn_zh
	var learn_label := _make_label(learn_full, 14)
	learn_label.position = Vector2(54, 40)
	learn_label.size = Vector2(870, 80)
	learn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learn_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.70))
	card.add_child(learn_label)

	# Adjust card height based on text content
	var lines := float(maxf(1.0, ceilf(float(learn_full.length()) / 80.0)))
	card_bg.size.y = 60.0 + lines * 18.0
	accent.size.y = card_bg.size.y
	card.custom_minimum_size.y = card_bg.size.y + 4

	return card


func _go_back() -> void:
	if GameManager.has_method("set_observatory_spawn"):
		GameManager.set_observatory_spawn("journal")
	GameManager.go("observatory")


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _on_language_changed() -> void:
	_build()
