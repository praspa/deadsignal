class_name WallTile
extends Node2D
## One isometric wall block (Diablo II style): top cap plus the two faces that
## can be seen from the camera (world-south face on the left, world-east face on
## the right). Lives in the y-sorted view root at its tile's projected centre,
## so actors behind it are hidden and actors in front overlap it. Level fades
## blocks standing between the camera and the player (wall cutaway).
##
## Tiles that look identical share one baked, normal-mapped texture (see
## signature()); until it is baked, or when running headless, the block is
## drawn as vectors.

var level: Level
var cx := 0
var cy := 0
var fade := 1.0
var ci: CanvasItem   # draw target for the current paint() call

const T := 32
const HS := 16.0
const BAKE_ORIGIN := Vector2(-34, -Level.WALL_H - 18)   # top-left of the baked image, local coords
const BAKE_SIZE := Vector2i(68, int(Level.WALL_H) + 36)

const TRIM := Color(0.27, 0.23, 0.16)          # tarnished brass
const GLOW_ON := Color(0.62, 0.56, 0.42)
const GLOW_OFF := Color(0.55, 0.12, 0.07)


func setup(p_level: Level, x: int, y: int) -> void:
	level = p_level
	cx = x
	cy = y
	position = Iso.to_screen(level.tile_center(x, y))
	material = level.normal_material


func set_fade(target: float, delta: float) -> bool:
	fade = move_toward(fade, target, delta * 4.0)
	modulate.a = fade
	return absf(fade - target) > 0.001


## Deco category for a face: 0 none, 1 window, 2 skull, 3 pipes, 4 warning light, 5 banner.
static func _deco_cat(hsh: int) -> int:
	match hsh % 13:
		0, 5:
			return 1
		2:
			return 2
		8, 9:
			return 3
		11:
			return 4
		4:
			return 5
	return 0


func _face_state(open: bool, inside: bool) -> int:
	return 0 if not open else (2 if inside else 1)


## Everything that affects how this block looks; equal signatures share a texture.
func signature() -> String:
	var hsh := Level.hash2(cx, cy)
	var s_state := _face_state(not level.is_wall(cx, cy + 1), level.is_floor(cx, cy + 1))
	var e_state := _face_state(not level.is_wall(cx + 1, cy), level.is_floor(cx + 1, cy))
	var s_deco := _deco_cat(hsh) if s_state == 2 else 0
	var e_deco := _deco_cat(hsh / 7) if e_state == 2 else 0
	var trims := int(level.is_wall(cx, cy - 1)) | int(level.is_wall(cx + 1, cy)) << 1 | int(level.is_wall(cx, cy + 1)) << 2 | int(level.is_wall(cx - 1, cy)) << 3
	var lit := level.powered and (s_deco == 1 or s_deco == 4 or e_deco == 1 or e_deco == 4)
	return "%d%d%d%d%d%d%d%d" % [s_state, e_state, s_deco, e_deco, trims, (hsh % 100) / 25, int(hsh % 5 == 0), int(lit)]


func _draw() -> void:
	var tex := level.wall_texture(signature(), self)
	if tex != null:
		draw_texture(tex, BAKE_ORIGIN)
	else:
		paint(self)


## Draws the block onto `target` (itself, or a Baker canvas).
func paint(target: CanvasItem) -> void:
	ci = target
	var H := Level.WALL_H
	var up := Vector2(0, -H)
	var hsh := Level.hash2(cx, cy)
	var a := Iso.to_screen(Vector2(-HS, -HS))   # north corner (top of diamond)
	var b := Iso.to_screen(Vector2(HS, -HS))    # east corner
	var c := Iso.to_screen(Vector2(HS, HS))     # south corner
	var d := Iso.to_screen(Vector2(-HS, HS))    # west corner
	var south_open := not level.is_wall(cx, cy + 1)
	var east_open := not level.is_wall(cx + 1, cy)
	var v := float((hsh % 100) / 25) / 4.0
	if south_open:
		var inside := level.is_floor(cx, cy + 1)
		# lit face (light from the upper left)
		_face(Vector2(-HS, HS), Vector2.RIGHT, Color(0.175, 0.163, 0.155) if inside else Color(0.06, 0.057, 0.058), inside, _deco_cat(hsh) if inside else 0, hsh)
	if east_open:
		var inside2 := level.is_floor(cx + 1, cy)
		# shadowed face
		_face(Vector2(HS, -HS), Vector2.DOWN, Color(0.108, 0.1, 0.097) if inside2 else Color(0.035, 0.033, 0.034), inside2, _deco_cat(hsh / 7) if inside2 else 0, hsh / 7)
	# top cap: dark, worn, lighter toward the lit corner
	var top := PackedVector2Array([a + up, b + up, c + up, d + up])
	var base_top := Color(0.11, 0.104, 0.104).lerp(Color(0.135, 0.125, 0.122), v)
	ci.draw_polygon(top, PackedColorArray([base_top.lightened(0.08), base_top, base_top.darkened(0.25), base_top.lightened(0.04)]))
	if not level.is_wall(cx, cy - 1):
		ci.draw_line(a + up, b + up, TRIM, 1.0)
	if not level.is_wall(cx + 1, cy):
		ci.draw_line(b + up, c + up, TRIM.darkened(0.35), 1.0)
	if not level.is_wall(cx, cy + 1):
		ci.draw_line(c + up, d + up, TRIM.lightened(0.1), 1.0)
	if not level.is_wall(cx - 1, cy):
		ci.draw_line(d + up, a + up, TRIM, 1.0)
	if hsh % 5 == 0:
		Iso.ground(ci, up)
		ci.draw_rect(Rect2(-8, -8, 16, 16), Color(0.05, 0.045, 0.048))
		ci.draw_line(Vector2(-8, -8), Vector2(8, -8), Color(0.11, 0.1, 0.1), 1.0)
		ci.draw_set_transform(Vector2.ZERO)


## Draws a vertical face; local x runs 0..T along the wall, y from -H (top) to 0.
func _face(start: Vector2, axis: Vector2, base: Color, inside: bool, deco: int, hsh: int) -> void:
	var H := Level.WALL_H
	Iso.face(ci, start, axis)
	ci.draw_rect(Rect2(0, -H, T, H), base)
	# buttress ribs: lit edge + shadowed edge instead of outlines
	for i in range(4, T, 9):
		ci.draw_line(Vector2(i, -H + 3), Vector2(i, -7), base.lightened(0.06), 2.0)
		ci.draw_line(Vector2(i + 2, -H + 3), Vector2(i + 2, -7), base.darkened(0.3), 1.0)
	# grime: streaks running down from the top, heavier toward the floor
	for k in 2:
		var gx := float((hsh >> (k * 3)) % 26) + 3.0
		ci.draw_line(Vector2(gx, -H + 2), Vector2(gx + 1, -H * 0.35), Color(0.02, 0.025, 0.015, 0.35), 2.0 + k)
	var clear := Color(0, 0, 0, 0)
	var soot := Color(0.0, 0.0, 0.0, 0.55)
	ci.draw_polygon(PackedVector2Array([Vector2(0, -16), Vector2(T, -16), Vector2(T, 0), Vector2(0, 0)]), PackedColorArray([clear, clear, soot, soot]))
	ci.draw_rect(Rect2(0, -6, T, 6), base.darkened(0.45))
	ci.draw_line(Vector2(0, -H + 1), Vector2(T, -H + 1), base.lightened(0.1), 1.5)
	if inside:
		_deco(deco)
	ci.draw_set_transform(Vector2.ZERO)


func _deco(deco: int) -> void:
	var H := Level.WALL_H
	var powered := level.powered
	var m := -H * 0.5   # vertical middle of the face
	match deco:
		1:
			# gothic lancet window with emergency / powered glow
			var glow := GLOW_ON if powered else GLOW_OFF
			var win := PackedVector2Array([Vector2(10, m + 14), Vector2(10, m - 6), Vector2(16, m - 15), Vector2(22, m - 6), Vector2(22, m + 14)])
			ci.draw_colored_polygon(win, Color(glow.r * 0.4, glow.g * 0.4, glow.b * 0.4))
			ci.draw_line(Vector2(11, m + 13), Vector2(21, m - 5), Color(glow.r * 0.55, glow.g * 0.55, glow.b * 0.55, 0.6), 2.0)   # cracked pane
			ci.draw_line(Vector2(16, m - 14), Vector2(16, m + 14), Color(0.04, 0.04, 0.04), 1.5)
			ci.draw_line(Vector2(10, m), Vector2(22, m), Color(0.04, 0.04, 0.04), 1.5)
			win.append(win[0])
			ci.draw_polyline(win, TRIM, 1.0)
		2:
			# skull relief with brass wings (shaded, no outline)
			ci.draw_circle(Vector2(16, m - 2), 6.0, Color(0.2, 0.19, 0.16))
			ci.draw_circle(Vector2(15, m - 3), 5.0, Color(0.33, 0.31, 0.26))
			ci.draw_rect(Rect2(12, m + 2, 8, 4), Color(0.26, 0.24, 0.2))
			ci.draw_circle(Vector2(13.5, m - 3), 1.7, Color(0.03, 0.03, 0.03))
			ci.draw_circle(Vector2(18.5, m - 3), 1.7, Color(0.03, 0.03, 0.03))
			ci.draw_line(Vector2(3, m - 4), Vector2(9, m - 1), TRIM, 2.0)
			ci.draw_line(Vector2(23, m - 1), Vector2(29, m - 4), TRIM, 2.0)
		3:
			# corroded conduit pipes
			ci.draw_line(Vector2(0, m - 6), Vector2(T, m - 6), Color(0.15, 0.11, 0.08), 4.0)
			ci.draw_line(Vector2(0, m - 7), Vector2(T, m - 7), Color(0.22, 0.16, 0.11), 1.0)
			ci.draw_line(Vector2(0, m + 2), Vector2(T, m + 2), Color(0.1, 0.095, 0.095), 3.0)
			ci.draw_circle(Vector2(8, m - 6), 2.5, TRIM)
			ci.draw_line(Vector2(8, m - 4), Vector2(9, m + 10), Color(0.12, 0.09, 0.04, 0.5), 2.0)   # rust drip
		4:
			# warning light
			var lc := Color(0.35, 0.75, 0.4) if powered else Color(0.85, 0.2, 0.08)
			ci.draw_circle(Vector2(16, m - 8), 3.0, lc)
			ci.draw_circle(Vector2(16, m - 8), 6.0, Color(lc.r, lc.g, lc.b, 0.2))
		5:
			# tattered purity-seal banner
			var bc := Color(0.24, 0.06, 0.05)
			var bh := H * 0.55
			ci.draw_rect(Rect2(11, -H + 4, 10, bh), bc)
			ci.draw_rect(Rect2(17, -H + 4, 4, bh), bc.darkened(0.35))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(11, -H + 4 + bh), Vector2(21, -H + 4 + bh), Vector2(18, -H + 9 + bh), Vector2(15, -H + 5 + bh), Vector2(13, -H + 10 + bh)]), bc)
			ci.draw_circle(Vector2(16, -H + 12), 3.0, TRIM)
