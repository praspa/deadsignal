class_name MainMenu
extends Control
## Title screen with an animated "dead signal" waveform.

signal action(id: String)

const CONTROLS_TEXT := """[color=#c9a54a]KEYBOARD & MOUSE[/color]
WASD — move        Mouse — aim
LMB — primary weapon        RMB — secondary / melee
Space — Tactical Roll        Q — Overcharge        F — Disruptor Pulse
R — reload        E — interact / pick up        H — use stim-pack
X — swap primary/secondary        I / Tab — inventory        C — character        J — journal
Esc — pause        F5 — quick save        F9 — quick load        Alt (hold) — show all loot names

[color=#c9a54a]CONTROLLER[/color]
Left stick — move        Right stick — aim (with light aim assist)
RT — primary        LT — secondary        A — roll
LB — Overcharge        RB — Disruptor Pulse        X — reload
Y — interact        D-Up — stim        D-Down — swap weapons
D-Left — character        D-Right / Back — inventory        Start — pause (Journal is in the pause menu)        L3 (hold) — loot names
Menus: d-pad / left stick to move, A to select, B to go back
[color=#888]PlayStation: A = Cross, B = Circle, X = Square, Y = Triangle, Back = Share, Start = Options[/color]"""

var t := 0.0
var embers: Array = []
var font: Font
var box: VBoxContainer
var continue_btn: Button
var controls: RichTextLabel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 60:
		embers.append([Vector2(randf() * 1280, randf() * 800), randf_range(8, 30), randf_range(1, 2.5)])
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(80, 380)
	box.custom_minimum_size = Vector2(320, 0)
	add_child(box)
	var new_btn := UiTheme.button("New Game", _emit.bind("new"))
	continue_btn = UiTheme.button("Continue", _emit.bind("continue"))
	continue_btn.disabled = not GameState.has_save()
	var ctrl_btn := UiTheme.button("Controls", _toggle_controls)
	var quit_btn := UiTheme.button("Quit", _emit.bind("quit"))
	for b in [continue_btn, new_btn, ctrl_btn, quit_btn]:
		b.custom_minimum_size = Vector2(320, 48)
		b.add_theme_font_size_override("font_size", 20)
		box.add_child(b)
	controls = RichTextLabel.new()
	controls.bbcode_enabled = true
	controls.position = Vector2(470, 360)
	controls.size = Vector2(760, 380)
	controls.add_theme_font_size_override("normal_font_size", 15)
	controls.text = CONTROLS_TEXT
	controls.visible = false
	var bg := Panel.new()
	bg.position = controls.position - Vector2(16, 16)
	bg.size = controls.size + Vector2(32, 32)
	bg.visible = false
	bg.name = "ControlsBG"
	add_child(bg)
	add_child(controls)
	await get_tree().process_frame
	if not continue_btn.disabled:
		continue_btn.grab_focus()
	else:
		new_btn.grab_focus()


func _toggle_controls() -> void:
	controls.visible = not controls.visible
	(get_node("ControlsBG") as Control).visible = controls.visible


func _emit(id: String) -> void:
	action.emit(id)


func _process(delta: float) -> void:
	t += delta
	for e in embers:
		e[0] += Vector2(sin(t + e[1]) * 6.0, -float(e[1])) * delta
		if (e[0] as Vector2).y < -10:
			e[0] = Vector2(randf() * 1280, 810)
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.025, 0.02, 0.025))
	# red horizon glow
	for i in 12:
		var a := 0.03 * (12 - i) / 12.0
		draw_rect(Rect2(0, vs.y * 0.5 + i * 22, vs.x, 22), Color(0.6, 0.06, 0.03, a * 3.0))
	# gothic spires silhouette
	var base_y := vs.y * 0.62
	for i in 14:
		var x := 520.0 + i * 55.0
		var hgt := 80.0 + float((i * 37) % 90) + (60.0 if i == 7 else 0.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 22, base_y), Vector2(x + 22, base_y), Vector2(x + 14, base_y - hgt * 0.7), Vector2(x, base_y - hgt), Vector2(x - 14, base_y - hgt * 0.7)]), Color(0.1, 0.075, 0.08))
		if i % 3 == 0:
			var flick := 0.5 + 0.5 * sin(t * 2.0 + i)
			draw_circle(Vector2(x, base_y - hgt * 0.5), 2.0, Color(1.0, 0.2, 0.1, 0.4 + 0.5 * flick))
	draw_rect(Rect2(0, base_y, vs.x, vs.y - base_y), Color(0.045, 0.035, 0.04))
	# the dead signal: flat line with three pulses, then silence
	var y0 := 250.0
	var pts := PackedVector2Array()
	var cycle := fmod(t * 0.6, 1.0)
	for i in 300:
		var x := 60.0 + i * 3.9
		var u := float(i) / 300.0
		var y := y0
		for k in 3:
			var center := 0.18 + k * 0.08
			var dd := (u - center) * 60.0
			y -= exp(-dd * dd) * 38.0 * (1.0 if k != 1 else 1.4)
		y += sin(u * 140.0 + t * 8.0) * 0.8
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(0.5, 0.05, 0.03, 0.5), 5.0)
	draw_polyline(pts, Color(1.0, 0.2, 0.1, 0.9), 1.6)
	var sweep_x := 60.0 + cycle * 300.0 * 3.9
	draw_circle(Vector2(sweep_x, pts[mini(int(cycle * 300.0), 299)].y), 4.0, Color(1, 0.6, 0.5))
	# title
	draw_string_outline(font, Vector2(80, 150), "DEAD SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 8, Color(0, 0, 0))
	draw_string(font, Vector2(80, 150), "DEAD SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(0.78, 0.62, 0.3))
	draw_string(font, Vector2(84, 186), "THE KHARON OUTPOST INCIDENT  —  VERTICAL SLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.55, 0.5))
	draw_line(Vector2(80, 200), Vector2(700, 200), UiTheme.BRASS_DIM, 2.0)
	for e in embers:
		draw_circle(e[0], float(e[2]), Color(1.0, 0.4, 0.15, 0.35))
	draw_string(font, Vector2(80, vs.y - 24), "Mouse / keyboard or controller.  Arrow keys or d-pad to navigate menus, Enter or A / Cross to select.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.42, 0.4))
