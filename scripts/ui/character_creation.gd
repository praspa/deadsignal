class_name CharacterCreation
extends Control
## New Game -> name, race and class. Hovering (mouse) or focusing (keyboard /
## controller) a race or class shows its details; the preview shows the
## operative as the hovered / selected race. Locked classes are greyed out.

signal begin(player_name: String, class_id: String, race_id: String)
signal back

const COL_W := 330.0
const ROW_H := 44.0
const PREVIEW_FEET := Vector2(190, 196)   # where the operative stands in the preview stage

var font: Font
var name_edit: LineEdit
var dice_btn: Button
var race_buttons: Array[Button] = []
var class_buttons: Array[Button] = []
var begin_btn: Button
var back_btn: Button
var detail_title: Label
var detail_status: Label
var detail_body: RichTextLabel
var preview_view: IsoView
var puppet: Player
var selected_race := GameState.DEFAULT_RACE
var selected_class := "combat_specialist"
var shown_race := GameState.DEFAULT_RACE   # race on the preview (hovered or selected)
var done := false                          # Begin / Back already fired: ignore further input
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# --- name: random sci-fi name, editable, with a reroll button
	var name_label := UiTheme.title_label("NAME", 16)
	name_label.position = Vector2(80, 150)
	add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.text = GameState.random_name()
	name_edit.placeholder_text = GameState.DEFAULT_NAME
	name_edit.max_length = GameState.NAME_MAX
	name_edit.position = Vector2(80, 178)
	name_edit.custom_minimum_size = Vector2(COL_W * 2 + 30 - 120, ROW_H)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.05, 0.045, 0.045), UiTheme.BRASS_DIM, 1))
	name_edit.add_theme_stylebox_override("focus", UiTheme.panel_style(Color(0.05, 0.045, 0.045), Color(0.95, 0.75, 0.35), 2))
	name_edit.add_theme_color_override("font_color", UiTheme.TEXT)
	name_edit.add_theme_color_override("font_placeholder_color", UiTheme.TEXT_DIM)
	name_edit.text_submitted.connect(func(_s: String) -> void: begin_btn.grab_focus())
	add_child(name_edit)
	dice_btn = UiTheme.button("Random", _reroll_name)
	dice_btn.position = Vector2(80 + COL_W * 2 + 30 - 110, 178)
	dice_btn.custom_minimum_size = Vector2(110, ROW_H)
	add_child(dice_btn)

	# --- race and class columns
	var race_col := _column("RACE", Vector2(80, 250))
	var class_col := _column("CLASS", Vector2(80 + COL_W + 30, 250))
	var race_group := ButtonGroup.new()
	for r in GameState.RACES:
		var b := _option_button(String(r["name"]), race_group, true, String(r["id"]) == selected_race)
		b.set_meta("race_id", String(r["id"]))
		b.pressed.connect(_select_race.bind(String(r["id"])))
		race_col.add_child(b)
		race_buttons.append(b)
	var class_group := ButtonGroup.new()
	for c in GameState.CLASSES:
		var avail := bool(c["available"])
		var label := String(c["name"]) if avail else "%s   [LOCKED]" % c["name"]
		var b := _option_button(label, class_group, avail, String(c["id"]) == selected_class)
		b.set_meta("class_id", String(c["id"]))
		b.pressed.connect(_select_class.bind(String(c["id"])))
		class_col.add_child(b)
		class_buttons.append(b)

	# --- right: preview + details
	var panel := PanelContainer.new()
	panel.position = Vector2(800, 150)
	panel.custom_minimum_size = Vector2(400, 510)
	add_child(panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	panel.add_child(dv)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(380, 210)
	stage.clip_contents = true
	dv.add_child(stage)
	_make_preview(stage)
	detail_title = UiTheme.title_label("", 26)
	dv.add_child(detail_title)
	detail_status = Label.new()
	detail_status.add_theme_font_size_override("font_size", 13)
	dv.add_child(detail_status)
	dv.add_child(HSeparator.new())
	detail_body = RichTextLabel.new()
	detail_body.bbcode_enabled = true
	detail_body.fit_content = true
	detail_body.scroll_active = false
	detail_body.custom_minimum_size = Vector2(380, 0)
	detail_body.add_theme_font_size_override("normal_font_size", 15)
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

	_link_focus()
	_show_race(selected_race)
	name_edit.grab_focus.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(puppet):
		puppet.free()


func _column(title: String, pos: Vector2) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.position = pos
	col.custom_minimum_size = Vector2(COL_W, 0)
	col.add_child(UiTheme.title_label(title, 16))
	add_child(col)
	return col


func _option_button(text: String, group: ButtonGroup, enabled: bool, pressed: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(COL_W, ROW_H)
	b.add_theme_font_size_override("font_size", 18)
	b.toggle_mode = true
	b.button_group = group
	b.disabled = not enabled
	b.button_pressed = pressed
	b.mouse_entered.connect(_show_for.bind(b))
	b.focus_entered.connect(_show_for.bind(b))
	b.mouse_exited.connect(_show_current)
	b.focus_exited.connect(_show_current.call_deferred)
	return b


## The operative drawn by the real Player art, through its own IsoView, so the
## preview always matches the game. The puppet Player never enters the tree.
func _make_preview(stage: Control) -> void:
	puppet = Player.new()
	preview_view = IsoView.new()
	preview_view.target = puppet
	preview_view.position = PREVIEW_FEET
	preview_view.scale = Vector2(2.4, 2.4)
	puppet.cv = preview_view
	stage.add_child(preview_view)
	# after add_child: entering the tree turns _process back on, and IsoView's
	# _process would move the view to the (unplaced) puppet's world position
	preview_view.set_process(false)


## d-pad / arrows: name -> races; races <-> classes; columns -> Back / Begin.
func _link_focus() -> void:
	name_edit.focus_neighbor_right = name_edit.get_path_to(dice_btn)
	dice_btn.focus_neighbor_left = dice_btn.get_path_to(name_edit)
	dice_btn.focus_neighbor_bottom = dice_btn.get_path_to(class_buttons[0])
	name_edit.focus_neighbor_bottom = name_edit.get_path_to(race_buttons[0])
	race_buttons[0].focus_neighbor_top = race_buttons[0].get_path_to(name_edit)
	class_buttons[0].focus_neighbor_top = class_buttons[0].get_path_to(dice_btn)
	for i in race_buttons.size():
		var b := race_buttons[i]
		b.focus_neighbor_right = b.get_path_to(class_buttons[mini(i, class_buttons.size() - 1)])
		b.focus_neighbor_left = b.get_path_to(back_btn)
	for i in class_buttons.size():
		var b := class_buttons[i]
		b.focus_neighbor_left = b.get_path_to(race_buttons[mini(i, race_buttons.size() - 1)])
		b.focus_neighbor_right = b.get_path_to(begin_btn)
	var last_race := race_buttons[race_buttons.size() - 1]
	var last_class := class_buttons[class_buttons.size() - 1]
	last_race.focus_neighbor_bottom = last_race.get_path_to(back_btn)
	last_class.focus_neighbor_bottom = last_class.get_path_to(begin_btn)
	back_btn.focus_neighbor_top = back_btn.get_path_to(last_race)
	back_btn.focus_neighbor_right = back_btn.get_path_to(begin_btn)
	begin_btn.focus_neighbor_top = begin_btn.get_path_to(last_class)
	begin_btn.focus_neighbor_left = begin_btn.get_path_to(back_btn)


func _reroll_name() -> void:
	name_edit.text = GameState.random_name()


func _select_race(id: String) -> void:
	selected_race = id
	_show_race(id)


func _select_class(id: String) -> void:
	if GameState.is_class_available(id):
		selected_class = id
	_show_class(id)


func _show_for(b: Button) -> void:
	if b.has_meta("race_id"):
		_show_race(String(b.get_meta("race_id")))
	elif b.has_meta("class_id"):
		_show_class(String(b.get_meta("class_id")))


## Whatever the player is pointing at now: the focused race / class, else the
## selected race. Keeps the panel from sticking on a class they moved away from.
func _show_current() -> void:
	if not is_inside_tree():
		return
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and (f.has_meta("race_id") or f.has_meta("class_id")):
		_show_for(f as Button)
	else:
		_show_race(selected_race)


func _show_race(id: String) -> void:
	var r := GameState.race_info(id)
	if r.is_empty():
		return
	shown_race = id
	detail_title.text = String(r["name"]).to_upper()
	detail_title.add_theme_color_override("font_color", UiTheme.BRASS)
	var chosen := id == selected_race
	detail_status.text = "RACE  ·  SELECTED" if chosen else "RACE"
	detail_status.add_theme_color_override("font_color", UiTheme.BRASS if chosen else UiTheme.TEXT_DIM)
	detail_body.text = String(r["description"]) + "\n\n[color=#c9a54a]Attributes:[/color]  " + GameState.race_mod_text(id)


func _show_class(id: String) -> void:
	var c := GameState.class_info(id)
	if c.is_empty():
		return
	shown_race = selected_race
	detail_title.text = String(c["name"]).to_upper()
	if bool(c["available"]):
		var chosen := id == selected_class
		detail_status.text = "CLASS  ·  SELECTED" if chosen else "CLASS"
		detail_status.add_theme_color_override("font_color", UiTheme.BRASS if chosen else UiTheme.TEXT_DIM)
		var skills := ", ".join(PackedStringArray(c.get("skills", [])))
		detail_body.text = "%s\n\n[color=#c9a54a]SKILLS[/color]  %s" % [c.get("description", ""), skills]
		detail_title.add_theme_color_override("font_color", UiTheme.BRASS)
	else:
		detail_status.text = "CLASS  ·  LOCKED"
		detail_status.add_theme_color_override("font_color", UiTheme.BLOOD.lightened(0.3))
		detail_body.text = "[color=#777]Personnel file classified.\nThis class is not yet available.[/color]"
		detail_title.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))


func _on_begin() -> void:
	if done:
		return
	done = true
	begin.emit(GameState.clean_name(name_edit.text), selected_class, selected_race)


func _on_back() -> void:
	if done:
		return
	done = true
	back.emit()


## Runs before the GUI: a focused LineEdit would otherwise swallow both the
## down arrow / d-pad and Esc / B, trapping keyboard and controller players.
func _input(event: InputEvent) -> void:
	if done:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
	elif event.is_action_pressed("ui_down") and get_viewport().gui_get_focus_owner() == name_edit:
		get_viewport().set_input_as_handled()
		race_buttons[0].grab_focus()


func _process(delta: float) -> void:
	t += delta
	# slow turntable, so every race reads from the front, side and back
	puppet.race = shown_race
	puppet.aim_dir = Vector2.from_angle(t * 0.7)
	preview_view.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.025, 0.02, 0.025))
	for i in 12:
		var a := 0.03 * (12 - i) / 12.0
		draw_rect(Rect2(0, vs.y * 0.62 + i * 22, vs.x, 22), Color(0.6, 0.06, 0.03, a * 3.0))
	draw_string_outline(font, Vector2(80, 100), "NEW OPERATIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 6, Color(0, 0, 0))
	draw_string(font, Vector2(80, 100), "NEW OPERATIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(0.78, 0.62, 0.3))
	draw_line(Vector2(80, 120), Vector2(1200, 120), UiTheme.BRASS_DIM, 2.0)
	draw_string(font, Vector2(80, vs.y - 24), "Hover or move focus over a race or class to read its file.  Esc / B to go back.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.42, 0.4))
