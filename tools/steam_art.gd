extends Node
## Renders Steam library artwork (and the game icon) from a staged in-game scene.
##   godot --path . -- --steam-art        (needs a display, not --headless)
## Writes steam_art/*.png at Steam's custom-artwork sizes and icon.png (project icon):
##   icon.png            256x256    shortcut icon (Properties -> icon)
##   capsule.png         600x900    portrait library grid
##   wide_capsule.png    920x430    wide grid / recently played
##   hero.png            1920x620   banner behind the game page (no title; Steam overlays the logo)
##   logo.png            1280x720   transparent title drawn over the hero
## Always uses layout 1 so the art doesn't change between runs.

const OUT := "res://steam_art/"
const CAPTURE := Vector2i(1920, 1200)   # rendered at 1.5x for crisp crops

const BONE := Color(0.86, 0.82, 0.72)
const RUST := Color(0.62, 0.12, 0.08)
const SIGNAL := Color(0.95, 0.2, 0.12)
const INK := Color(0.03, 0.025, 0.025)

var main: Node
var game: Game
var font: SystemFont


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	main = get_parent()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "Sans"])
	font.font_weight = 700
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
	get_window().size = CAPTURE
	GameState.save_path = "user://steam_art_save.json"
	await frames(3)
	GameState.new_game()
	GameState.map_variant = 1
	GameState.set_flag("power")
	main.call("start_game")
	await frames(3)
	game = main.get("current")
	var shots := await _stage_and_capture()
	_compose(shots)
	for k in 4:
		await frames(1)
	for job in _jobs:
		var img: Image = (job[1] as SubViewport).get_texture().get_image()
		var path := ProjectSettings.globalize_path(OUT + String(job[0]) + ".png")
		img.save_png(path)
		print("wrote ", path, "  ", img.get_size())
		if job[0] == "icon":
			img.save_png(ProjectSettings.globalize_path("res://icon.png"))
			print("wrote res://icon.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()


# ------------------------------------------------------------- staging ---

## The marine holding the generator hall against a heavy and two researchers.
func _stage_and_capture() -> Dictionary:
	var lvl := game.level
	var p := game.player
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Boss:
			e.queue_free()
	for d in get_tree().get_nodes_in_group("loot"):
		d.queue_free()
	await frames(2)
	var c := lvl.room_center("generator")
	p.global_position = c
	# enemies come at him from the upper right of the screen
	var foes := [["heavy", Vector2(210, -70)], ["researcher", Vector2(120, -150)], ["researcher", Vector2(300, 10)], ["drone", Vector2(330, -170)]]
	var spawned: Array = []
	for f in foes:
		var e: Enemy = lvl.spawn_enemy(f[0], c + Iso.to_world(f[1]), "art_%d" % spawned.size())
		spawned.append(e)
	game.hud.visible = false
	var labels := get_tree().root.find_child("LootLabels", true, false) as CanvasItem
	if labels != null:
		labels.visible = false
	game.set_process(false)
	lvl.canvas_mod.color = lvl.canvas_mod.color * 1.5
	var cam := game.camera
	cam.position_smoothing_enabled = false
	Iso.cull_rect = Rect2()
	var heavy: Enemy = spawned[0]
	for k in 40:
		p.hp = p.max_hp
		await frames(1)
	# freeze the foes mid-advance, all facing the marine
	for e in spawned:
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.facing = (p.global_position - e.global_position).angle()
		e.anim_t = 0.35
	p.aim_override = heavy.global_position
	while lvl.baker.pending() > 0:
		await frames(5)
	var cs := Iso.sp(c, 20)   # the marine on screen; foes span ~330 px right, ~170 px up
	var shots := {}
	# [name, camera offset from the marine, zoom]
	var views := [
		["hero", Vector2(-40, -75), 1.6],      # action in the right half, left kept for Steam's logo
		["wide", Vector2(-30, -80), 1.4],      # title goes on the left
		["capsule", Vector2(90, -110), 1.8],   # action low, title on top
		["icon", Vector2(2, 12), 5.0],         # marine alone, close up
	]
	for v in views:
		if v[0] == "icon":
			for e in spawned:
				e.visible = false
			p.aim_override = p.global_position + Vector2(60, 25)
		cam.global_position = cs + (v[1] as Vector2)
		cam.zoom = Vector2(v[2], v[2])
		cam.reset_smoothing()
		for k in 3:
			p.hp = p.max_hp
			await frames(1)
		p.fire("primary")
		await frames(2)
		await RenderingServer.frame_post_draw
		shots[v[0]] = get_viewport().get_texture().get_image()
	return shots


# --------------------------------------------------------- composition ---

var _jobs: Array = []


func _add_job(name: String, size: Vector2i, transparent: bool, bg: Image, crop: Rect2i, kind: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(bg.get_region(crop))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(size)
		vp.add_child(tr)
	var art := Art.new()
	art.kind = kind
	art.font = font
	art.size = Vector2(size)
	vp.add_child(art)
	add_child(vp)
	_jobs.append([name, vp])


func _compose(shots: Dictionary) -> void:
	var W := CAPTURE.x
	var H := CAPTURE.y
	# hero: 1920x620 band through the action
	_add_job("hero", Vector2i(1920, 620), false, shots["hero"], Rect2i(0, int(H * 0.5 - 310), W, 620), "hero")
	# wide capsule 920x430 (crop 1920x897)
	var wh := int(W * 430.0 / 920.0)
	_add_job("wide_capsule", Vector2i(920, 430), false, shots["wide"], Rect2i(0, (H - wh) / 2, W, wh), "wide")
	# portrait capsule 600x900 (crop 800x1200)
	_add_job("capsule", Vector2i(600, 900), false, shots["capsule"], Rect2i((W - 800) / 2, 0, 800, H), "capsule")
	# icon 256 (square crop of the close-up)
	_add_job("icon", Vector2i(256, 256), false, shots["icon"], Rect2i((W - H) / 2, 0, H, H), "icon")
	_add_job("logo", Vector2i(1280, 720), true, null, Rect2i(), "logo")


class Art extends Control:
	var kind := ""
	var font: Font

	func _draw() -> void:
		var w := size.x
		var h := size.y
		match kind:
			"hero":
				_vignette(0.75, 0.0)
			"wide":
				_vignette(0.7, 0.0)
				_shade_side(true, 0.62)
				_title(Vector2(w * 0.27, h * 0.45), 74.0, false)
			"capsule":
				_vignette(0.65, 0.0)
				_shade_band(0.0, 0.34, 0.85)
				_shade_band(1.0, 0.24, 0.6)
				_title(Vector2(w * 0.5, h * 0.15), 104.0, true)
			"icon":
				_vignette(0.6, 0.0)
				_icon_frame()
			"logo":
				_title(Vector2(w * 0.5, h * 0.5), 200.0, true)

	## Darkened edges so the art reads as a framed image, not a screenshot.
	func _vignette(strength: float, _unused: float) -> void:
		var w := size.x
		var h := size.y
		var steps := 24
		for i in steps:
			var t := float(i) / steps
			var a := pow(1.0 - t, 2.2) * strength
			var inset := Vector2(w, h) * 0.18 * t
			var col := Color(0, 0, 0, a / steps * 3.0)
			# four edge strips per ring
			draw_rect(Rect2(0, 0, w, inset.y + 2), col)
			draw_rect(Rect2(0, h - inset.y - 2, w, inset.y + 2), col)
			draw_rect(Rect2(0, 0, inset.x + 2, h), col)
			draw_rect(Rect2(w - inset.x - 2, 0, inset.x + 2, h), col)

	## Fades one side to black (behind the title on the wide capsule).
	func _shade_side(left: bool, frac: float) -> void:
		var w := size.x
		var h := size.y
		var n := 40
		for i in n:
			var t := float(i) / n
			var x := w * frac * t
			var a := 0.85 * pow(1.0 - t, 1.4)
			var rx := x if left else w - x - w * frac / n
			draw_rect(Rect2(rx, 0, w * frac / n + 1, h), Color(0, 0, 0, a))

	## Fades the top (edge 0) or bottom (edge 1) to black.
	func _shade_band(edge: float, frac: float, strength: float) -> void:
		var w := size.x
		var h := size.y
		var n := 40
		for i in n:
			var t := float(i) / n
			var bh := h * frac / n
			var y := h * frac * t if edge == 0.0 else h - h * frac * t - bh
			draw_rect(Rect2(0, y, w, bh + 1), Color(0, 0, 0, strength * pow(1.0 - t, 1.3)))

	## A heartbeat trace that flatlines: the "dead signal".
	func _signal_line(from: Vector2, length: float, amp: float, col: Color, width: float) -> void:
		var pts := PackedVector2Array()
		var beats := [0.12, 0.34, 0.52]
		pts.append(from)
		for b in beats:
			var x: float = from.x + length * b
			var s: float = amp * (1.0 - b * 0.9)   # each beat weaker than the last
			pts.append(Vector2(x - length * 0.025, from.y))
			pts.append(Vector2(x - length * 0.012, from.y + s * 0.25))
			pts.append(Vector2(x, from.y - s))
			pts.append(Vector2(x + length * 0.014, from.y + s * 0.55))
			pts.append(Vector2(x + length * 0.028, from.y))
		pts.append(from + Vector2(length, 0))
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.25), width * 3.5, true)
		draw_polyline(pts, col, width, true)

	## "DEAD SIGNAL": worn bone lettering, dark outline, red glow, flatline underneath.
	func _title(c: Vector2, fs: float, stacked: bool) -> void:
		var lines := ["DEAD", "SIGNAL"] if stacked else ["DEAD SIGNAL"]
		var lh := fs * 0.92
		var top := c.y - lh * (lines.size() - 1) * 0.5 + fs * 0.34
		var widest := 0.0
		for i in lines.size():
			var t: String = lines[i]
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
			widest = maxf(widest, tw)
			var p := Vector2(c.x - tw * 0.5, top + i * lh)
			# red glow
			for g in 3:
				draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), int(fs * (0.1 + g * 0.09)), Color(RUST.r, RUST.g, RUST.b, 0.16))
			draw_string_outline(font, p + Vector2(0, fs * 0.03), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), int(fs * 0.09), INK)
			draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), BONE)
		var ly := top + (lines.size() - 1) * lh + fs * 0.28
		_signal_line(Vector2(c.x - widest * 0.5, ly), widest, fs * 0.26, SIGNAL, maxf(2.0, fs * 0.03))
		var sub := "KHARON OUTPOST"
		var sfs := int(fs * 0.2)
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var sp := Vector2(c.x - sw * 0.5, ly + fs * 0.42)
		draw_string_outline(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, maxi(2, int(sfs * 0.25)), INK)
		draw_string(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(0.7, 0.62, 0.48))

	## Rusted plate frame with a flatline across the bottom.
	func _icon_frame() -> void:
		var s := size.x
		var b := s * 0.045
		var col := Color(0.24, 0.19, 0.15)
		draw_rect(Rect2(0, 0, s, b), col)
		draw_rect(Rect2(0, s - b, s, b), col)
		draw_rect(Rect2(0, 0, b, s), col)
		draw_rect(Rect2(s - b, 0, b, s), col)
		draw_rect(Rect2(b, b, s - b * 2, s - b * 2), Color(0, 0, 0, 0.9), false, 2.0)
		for corner in [Vector2(b * 0.5, b * 0.5), Vector2(s - b * 0.5, b * 0.5), Vector2(b * 0.5, s - b * 0.5), Vector2(s - b * 0.5, s - b * 0.5)]:
			draw_circle(corner, b * 0.28, Color(0.5, 0.42, 0.3))
		draw_rect(Rect2(b, s * 0.78, s - b * 2, s * 0.22 - b), Color(0, 0, 0, 0.55))
		_signal_line(Vector2(b * 1.6, s * 0.89), s - b * 3.2, s * 0.09, SIGNAL, 2.5)
