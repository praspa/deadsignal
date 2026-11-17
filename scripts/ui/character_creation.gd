class_name CharacterCreation
extends Control
## New Game -> pick a name and a class. Hovering (mouse) or focusing (keyboard /
## controller) a class shows its details; locked classes are greyed out.

signal begin(player_name: String, class_id: String)
signal back

var font: Font
var name_edit: LineEdit
var class_buttons: Array[Button] = []
var begin_btn: Button
var back_btn: Button
var detail_title: Label
var detail_status: Label
var detail_body: RichTextLabel
var selected_id := "combat_specialist"
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# --- left column: name + class list
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.position = Vector2(80, 170)
	left.custom_minimum_size = Vector2(400, 0)
	add_child(left)
	left.add_child(UiTheme.title_label("NAME", 16))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = GameState.DEFAULT_NAME
	name_edit.max_length = GameState.NAME_MAX
	name_edit.custom_minimum_size = Vector2(400, 44)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.05, 0.045, 0.045), UiTheme.BRASS_DIM, 1))
	name_edit.add_theme_stylebox_override("focus", UiTheme.panel_style(Color(0.05, 0.045, 0.045), Color(0.95, 0.75, 0.35), 2))
	name_edit.add_theme_color_override("font_color", UiTheme.TEXT)
	name_edit.add_theme_color_override("font_placeholder_color", UiTheme.TEXT_DIM)
	name_edit.text_submitted.connect(func(_s: String) -> void: begin_btn.grab_focus())
	left.add_child(name_edit)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	left.add_child(gap)
	left.add_child(UiTheme.title_label("CLASS", 16))
	var group := ButtonGroup.new()
	for c in GameState.CLASSES:
		var id := String(c["id"])
		var avail := bool(c["available"])
		var b := UiTheme.button(String(c["name"]) if avail else "%s   [LOCKED]" % c["name"], _select.bind(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(400, 50)
		b.add_theme_font_size_override("font_size", 19)
		b.toggle_mode = true
		b.button_group = group
		b.disabled = not avail
		b.button_pressed = id == selected_id
		b.mouse_entered.connect(_show.bind(id))
		b.mouse_exited.connect(_show_focused_or_selected)
		b.focus_entered.connect(_show.bind(id))
		b.set_meta("class_id", id)
		left.add_child(b)
		class_buttons.append(b)

	# --- right: class details
	var panel := PanelContainer.new()
	panel.position = Vector2(540, 170)
	panel.custom_minimum_size = Vector2(660, 470)
	add_child(panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	panel.add_child(dv)
	detail_title = UiTheme.title_label("", 30)
	dv.add_child(detail_title)
	detail_status = Label.new()
	detail_status.add_theme_font_size_override("font_size", 14)
	dv.add_child(detail_status)
	dv.add_child(HSeparator.new())
	detail_body = RichTextLabel.new()
	detail_body.bbcode_enabled = true
	detail_body.fit_content = true
	detail_body.scroll_active = false
	detail_body.custom_minimum_size = Vector2(620, 0)
	detail_body.add_theme_font_size_override("normal_font_size", 17)
	dv.add_child(detail_body)

	# --- bottom buttons
	back_btn = UiTheme.button("Back", _on_back)
	back_btn.position = Vector2(80, 690)
	back_btn.custom_minimum_size = Vector2(180, 48)
	back_btn.add_theme_font_size_override("font_size", 20)
	add_child(back_btn)
	begin_btn = UiTheme.button("Begin Mission", _on_begin)
	begin_btn.position = Vector2(940, 690)
	begin_btn.custom_minimum_size = Vector2(260, 48)
	begin_btn.add_theme_font_size_override("font_size", 20)
	add_child(begin_btn)

	# explicit focus links so d-pad / arrows move sensibly between the columns
	var first: Button = class_buttons[0]
	var last: Button = class_buttons[class_buttons.size() - 1]
	name_edit.focus_neighbor_bottom = name_edit.get_path_to(first)
	first.focus_neighbor_top = first.get_path_to(name_edit)
	last.focus_neighbor_bottom = last.get_path_to(begin_btn)
	for b in class_buttons:
		b.focus_neighbor_right = b.get_path_to(begin_btn)
		b.focus_neighbor_left = b.get_path_to(back_btn)
	begin_btn.focus_neighbor_top = begin_btn.get_path_to(first)
	begin_btn.focus_neighbor_left = begin_btn.get_path_to(back_btn)
	back_btn.focus_neighbor_top = back_btn.get_path_to(last)
	back_btn.focus_neighbor_right = back_btn.get_path_to(begin_btn)

	_show(selected_id)
	await get_tree().process_frame
	name_edit.grab_focus()


func _select(id: String) -> void:
	if GameState.is_class_available(id):
		selected_id = id
	_show(id)


func _show_focused_or_selected() -> void:
	var f := get_viewport().gui_get_focus_owner()
	_show(String(f.get_meta("class_id")) if f != null and f.has_meta("class_id") else selected_id)


func _show(id: String) -> void:
	var c := GameState.class_info(id)
	if c.is_empty():
		return
	detail_title.text = String(c["name"]).to_upper()
	if bool(c["available"]):
		var chosen := id == selected_id
		detail_status.text = "SELECTED" if chosen else "AVAILABLE"
		detail_status.add_theme_color_override("font_color", UiTheme.BRASS if chosen else UiTheme.TEXT_DIM)
		var skills := ", ".join(PackedStringArray(c.get("skills", [])))
		detail_body.text = "%s\n\n[color=#c9a54a]SKILLS[/color]\n%s" % [c.get("description", ""), skills]
		detail_title.add_theme_color_override("font_color", UiTheme.BRASS)
	else:
		detail_status.text = "LOCKED"
		detail_status.add_theme_color_override("font_color", UiTheme.BLOOD.lightened(0.3))
		detail_body.text = "[color=#777]Personnel file classified.\nThis class is not yet available.[/color]"
		detail_title.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))


func _on_begin() -> void:
	begin.emit(GameState.clean_name(name_edit.text), selected_id)


func _on_back() -> void:
	back.emit()


## Runs before the GUI: a focused LineEdit would otherwise swallow both the
## down arrow / d-pad and Esc / B, trapping keyboard and controller players.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
	elif event.is_action_pressed("ui_down") and get_viewport().gui_get_focus_owner() == name_edit:
		get_viewport().set_input_as_handled()
		class_buttons[0].grab_focus()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.025, 0.02, 0.025))
	for i in 12:
		var a := 0.03 * (12 - i) / 12.0
		draw_rect(Rect2(0, vs.y * 0.62 + i * 22, vs.x, 22), Color(0.6, 0.06, 0.03, a * 3.0))
	draw_string_outline(font, Vector2(80, 110), "NEW OPERATIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 6, Color(0, 0, 0))
	draw_string(font, Vector2(80, 110), "NEW OPERATIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(0.78, 0.62, 0.3))
	draw_line(Vector2(80, 130), Vector2(1200, 130), UiTheme.BRASS_DIM, 2.0)
	# faint scanline sweep over the dossier
	var sy := 170.0 + fmod(t * 60.0, 470.0)
	draw_rect(Rect2(540, sy, 660, 2), Color(1.0, 0.3, 0.15, 0.08))
	draw_string(font, Vector2(80, vs.y - 24), "Hover or move focus over a class to read its file.  Esc / B to go back.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.42, 0.4))
