class_name FloorChunk
extends Node2D
## Draws a square chunk of floor tiles plus floor decals (blood, corpses,
## extraction pad). Tiles are authored in world space and projected through
## Iso.M, so they render as isometric diamonds. Draw commands are cached by the
## engine until redraw, and chunks outside the camera are culled automatically.

var level: Level
var cx := 0
var cy := 0
var size := 16

const T := 32
const SOLID_DECOR := "opgtcC0123456789"   # tiles with a standing object: ambient-occlusion blob

var ci: CanvasItem   # draw target for the current paint() call


func setup(p_level: Level, p_cx: int, p_cy: int, p_size: int) -> void:
	level = p_level
	cx = p_cx
	cy = p_cy
	size = p_size


## True when the chunk has any non-void tile worth drawing.
func has_content() -> bool:
	for y in range(cy, mini(cy + size, level.h)):
		for x in range(cx, mini(cx + size, level.w)):
			if level.is_floor(x, y):
				return true
	return false


## Screen-space bounding box of the projected chunk, with room for decals.
func screen_rect() -> Rect2:
	var m := 20.0
	var x0 := float(cx - (cy + size)) * T
	var y0 := float(cx + cy) * T * 0.5
	return Rect2(x0 - m, y0 - m, size * T * 2.0 + m * 2.0, size * T + m * 2.0)


func _draw() -> void:
	paint(self)


## Draws the chunk onto `target` (itself, or a Baker canvas).
func paint(target: CanvasItem) -> void:
	ci = target
	ci.draw_set_transform_matrix(Iso.M)
	for y in range(cy, mini(cy + size, level.h)):
		for x in range(cx, mini(cx + size, level.w)):
			if level.ch(x, y) == " ":
				_draw_void(x, y)
			elif level.is_floor(x, y):
				_draw_tile(x, y)


## Space between rooms.
func _draw_void(x: int, y: int) -> void:
	# outside the facility: near-black abyss, as in classic isometric ARPGs
	ci.draw_rect(Rect2(x * T, y * T, T, T), Color(0.012, 0.01, 0.012))


func _draw_tile(x: int, y: int) -> void:
	var r := Rect2(x * T, y * T, T, T)
	var hsh := Level.hash2(x, y)
	var v := float(hsh % 100) / 100.0
	var style := level.floor_style(x, y)
	var c := level.ch(x, y)
	match style:
		",":
			var base := Color(0.13, 0.115, 0.1).lerp(Color(0.17, 0.15, 0.13), v if WallTile.natural == "" else 0.4 + v * 0.15)
			ci.draw_rect(r, base)
			for i in 3:
				var hh := Level.hash2(x * 7 + i, y * 13 - i)
				var p := r.position + Vector2(hh % 30 + 1, (hh / 31) % 30 + 1)
				var gs := 2.0 + float(hh % 3) * 2.0
				ci.draw_rect(Rect2(p, Vector2(gs, gs)), Color(0.08, 0.07, 0.06, 0.8))
			if hsh % 9 == 0:
				ci.draw_line(r.position + Vector2(4, 6), r.position + Vector2(20, 18), Color(0.06, 0.05, 0.05), 1.0)
				ci.draw_line(r.position + Vector2(20, 18), r.position + Vector2(27, 29), Color(0.06, 0.05, 0.05), 1.0)
			if hsh % 17 == 0:
				ci.draw_circle(r.get_center(), 9.0, Color(0.1, 0.09, 0.08, 0.7))
		"_":
			ci.draw_rect(r, Color(0.075, 0.075, 0.085))
			for i in range(3, T, 5):
				ci.draw_line(r.position + Vector2(2, i), r.position + Vector2(T - 2, i), Color(0.15, 0.15, 0.16).lerp(Color(0.19, 0.18, 0.17), v), 2.0)
			ci.draw_rect(r, Color(0.04, 0.04, 0.045), false, 2.0)
		_:
			var base := Color(0.145, 0.14, 0.135).lerp(Color(0.175, 0.165, 0.155), v)
			ci.draw_rect(r, base)
			ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(0.07, 0.065, 0.065), false, 1.0)
			ci.draw_line(r.position + Vector2(2, 2), r.position + Vector2(T - 3, 2), Color(0.22, 0.21, 0.2, 0.5), 1.0)
			for p in [Vector2(4, 4), Vector2(T - 4, 4), Vector2(4, T - 4), Vector2(T - 4, T - 4)]:
				ci.draw_rect(Rect2(r.position + p - Vector2(1.3, 1.3), Vector2(2.6, 2.6)), Color(0.27, 0.25, 0.22))
			if hsh % 37 == 0:
				# drain grate
				ci.draw_rect(Rect2(r.position + Vector2(9, 9), Vector2(14, 14)), Color(0.05, 0.05, 0.05))
				for i in 3:
					ci.draw_line(r.position + Vector2(10, 12 + i * 4), r.position + Vector2(22, 12 + i * 4), Color(0.2, 0.19, 0.17), 1.0)
			if hsh % 9 == 0:
				ci.draw_circle(r.position + Vector2(hsh % 20 + 6, (hsh / 7) % 20 + 6), 7.0 + float(hsh % 5), Color(0.05, 0.045, 0.04, 0.35))
			if hsh % 23 == 0:
				ci.draw_line(r.position + Vector2(3, 28), r.position + Vector2(28, 3), Color(0.06, 0.06, 0.06, 0.7), 1.0)
	# door thresholds get hazard striping
	if Level.DOOR_REQ.has(c):
		ci.draw_rect(r, Color(0.06, 0.06, 0.06))
		for i in range(-T, T, 8):
			ci.draw_line(r.position + Vector2(i, T), r.position + Vector2(i + T, 0), Color(0.55, 0.45, 0.1, 0.55), 3.0)
	_contact_shade(x, y, r, c)
	match c:
		"b":
			_blood(r.get_center(), hsh, 1.0)
		"k":
			_blood(r.get_center() + Vector2(4, 4), hsh, 1.3)
			_corpse(r.get_center(), hsh)
		"X":
			ci.draw_rect(r, Color(0.05, 0.12, 0.12))
			ci.draw_rect(r.grow(-3), Color(0.15, 0.6, 0.55, 0.35), false, 2.0)
			ci.draw_line(r.position + Vector2(8, 20), r.position + Vector2(16, 12), Color(0.3, 0.9, 0.8, 0.6), 2.0)
			ci.draw_line(r.position + Vector2(16, 12), r.position + Vector2(24, 20), Color(0.3, 0.9, 0.8, 0.6), 2.0)
		"v":
			ci.draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(20, 20)), Color(0.04, 0.04, 0.04))
			for i in 4:
				ci.draw_line(r.position + Vector2(7, 9 + i * 5), r.position + Vector2(25, 9 + i * 5), Color(0.22, 0.2, 0.18), 1.5)


func _blood(center: Vector2, hsh: int, s: float) -> void:
	var col := Color(0.28, 0.02, 0.02, 0.85)
	ci.draw_circle(center, 9.0 * s, col)
	for i in 5:
		var hh := Level.hash2(hsh + i, i * 3)
		var off := Vector2(float(hh % 28) - 14.0, float((hh / 29) % 22) - 11.0) * s
		ci.draw_circle(center + off, 2.0 + float(hh % 5) * s, col)
	ci.draw_line(center, center + Vector2(float(hsh % 30) - 15.0, 18.0) * s, Color(0.22, 0.02, 0.02, 0.7), 4.0)


func _corpse(center: Vector2, hsh: int) -> void:
	var ang := float(hsh % 628) / 100.0
	ci.draw_set_transform_matrix(Iso.M * Transform2D(ang, Vector2(1.0, 0.7), 0.0, center))
	var lab := hsh % 2 == 0
	var body := Color(0.5, 0.48, 0.43) if lab else Color(0.16, 0.17, 0.16)
	ci.draw_rect(Rect2(-12, -6, 22, 12), body)
	ci.draw_line(Vector2(10, -4), Vector2(18, -9), body, 4.0)
	ci.draw_line(Vector2(10, 4), Vector2(17, 10), body, 4.0)
	ci.draw_line(Vector2(-12, -3), Vector2(-22, -5), Color(0.12, 0.1, 0.1), 4.0)
	ci.draw_line(Vector2(-12, 3), Vector2(-21, 7), Color(0.12, 0.1, 0.1), 4.0)
	ci.draw_circle(Vector2(14, 0), 5.0, Color(0.55, 0.47, 0.42) if lab else Color(0.25, 0.25, 0.24))
	ci.draw_set_transform_matrix(Iso.M)


## Darkens the floor where it meets walls and under standing objects, so
## geometry sits in the scene instead of floating on it.
func _contact_shade(x: int, y: int, r: Rect2, c: String) -> void:
	var dark := Color(0, 0, 0, 0.6)
	var clear := Color(0, 0, 0, 0)
	var w := 12.0
	if level.is_wall(x, y - 1):
		ci.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(T, 0), r.position + Vector2(T, w), r.position + Vector2(0, w)]), PackedColorArray([dark, dark, clear, clear]))
	if level.is_wall(x - 1, y):
		ci.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w, T), r.position + Vector2(0, T)]), PackedColorArray([dark, clear, clear, dark]))
	if level.is_wall(x, y + 1):
		ci.draw_polygon(PackedVector2Array([r.position + Vector2(0, T - w), r.position + Vector2(T, T - w), r.end, r.position + Vector2(0, T)]), PackedColorArray([clear, clear, dark, dark]))
	if level.is_wall(x + 1, y):
		ci.draw_polygon(PackedVector2Array([r.position + Vector2(T - w, 0), r.position + Vector2(T, 0), r.end, r.position + Vector2(T - w, T)]), PackedColorArray([clear, dark, dark, clear]))
	if SOLID_DECOR.contains(c):
		for rad in [22.0, 17.0, 12.0]:
			ci.draw_circle(r.get_center(), rad, Color(0, 0, 0, 0.2))
