class_name PauseMenu
extends Screen
## Pause menu: resume, open sub-screens, save / load, controls, quit.

signal action(id: String)

var box: VBoxContainer
var controls_lbl: RichTextLabel


func _ready() -> void:
	make_panel(Vector2(420, 570))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var t := UiTheme.title_label("— PAUSED —", 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for pair in [["Resume", "resume"], ["Inventory", "inventory"], ["Character", "character"], ["Journal", "journal"], ["Save Game", "save"],
			["Load Last Save", "load"], ["Controls", "controls"], ["Quit to Main Menu", "menu"], ["Quit to Desktop", "quit"]]:
		var b := UiTheme.button(pair[0], _emit.bind(pair[1]))
		b.custom_minimum_size = Vector2(0, 42)
		box.add_child(b)
	controls_lbl = RichTextLabel.new()
	controls_lbl.bbcode_enabled = true
	controls_lbl.fit_content = true
	controls_lbl.visible = false
	controls_lbl.add_theme_font_size_override("normal_font_size", 13)
	controls_lbl.text = MainMenu.CONTROLS_TEXT
	box.add_child(controls_lbl)


func refresh() -> void:
	controls_lbl.visible = false
	for c in box.get_children():
		if c is Button and (c as Button).text == "Load Last Save":
			(c as Button).disabled = not GameState.has_save()


func _emit(id: String) -> void:
	if id == "controls":
		controls_lbl.visible = not controls_lbl.visible
		panel.custom_minimum_size = Vector2(560, 760) if controls_lbl.visible else Vector2(420, 570)
		panel.size = panel.custom_minimum_size
		_center_panel()
		return
	action.emit(id)
