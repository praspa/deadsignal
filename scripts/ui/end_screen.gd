class_name EndScreen
extends Screen
## Death and victory screens.

signal action(id: String)

var title: Label
var body: Label
var box: VBoxContainer
var load_btn: Button


func _ready() -> void:
	dim.color = Color(0, 0, 0, 0.75)
	make_panel(Vector2(560, 360))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	title = UiTheme.title_label("", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(520, 80)
	box.add_child(body)
	load_btn = UiTheme.button("Load Last Save", _emit.bind("load"))
	box.add_child(load_btn)
	box.add_child(UiTheme.button("Main Menu", _emit.bind("menu")))


func show_death() -> void:
	title.text = "SIGNAL LOST"
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
	body.text = "Your vitals have flatlined. Kharon Outpost keeps another body."
	load_btn.visible = true
	load_btn.disabled = not GameState.has_save()
	open()


func show_victory() -> void:
	title.text = "EXTRACTION COMPLETE"
	title.add_theme_color_override("font_color", UiTheme.BRASS)
	var mins := int(GameState.play_time) / 60
	var secs := int(GameState.play_time) % 60
	body.text = "WARDEN is silenced and the Dead Signal recording is sealed.\nOverwatch is pulling you out.\n\nLevel %d  —  Time %d:%02d\n\nThank you for playing the Dead Signal demo." % [GameState.level, mins, secs]
	load_btn.visible = false
	open()


func _emit(id: String) -> void:
	action.emit(id)
