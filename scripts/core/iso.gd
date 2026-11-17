class_name Iso
## 2:1 isometric projection layer (Diablo II style).
##
## The game simulates everything on a flat square grid ("world" space: physics,
## pathing, AI, combat). Nothing in world space is drawn directly. Each visible
## entity owns an IsoView placed at its projected "screen" position inside a
## y-sorted view root; screen y equals isometric depth, so plain y-sorting gives
## correct back-to-front ordering.
##
##   world (x, y)  ->  screen (x - y, (x + y) / 2)
## A 32x32 world tile becomes a 64x32 diamond.

## Projects world-space offsets/directions onto the ground plane on screen.
const M := Transform2D(Vector2(1.0, 0.5), Vector2(-1.0, 0.5), Vector2.ZERO)

## Container for all IsoViews (y-sorted). Set by Game before the level is built.
static var view_root: Node2D
## Container for one-shot screen effects (drawn above the world).
static var fx_root: Node2D
## Screen-space area around the camera; dynamic views outside it skip redraws.
## An empty rect disables culling.
static var cull_rect := Rect2()


static func to_screen(p: Vector2) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5)


static func to_world(s: Vector2) -> Vector2:
	return Vector2(s.y + s.x * 0.5, s.y - s.x * 0.5)


## Screen point for a world ground position, raised `height` pixels.
static func sp(p: Vector2, height: float = 0.0) -> Vector2:
	return to_screen(p) - Vector2(0.0, height)


## Projects a world direction / offset (linear part only).
static func dir(v: Vector2) -> Vector2:
	return to_screen(v)


## Screen-space angle of a world-space angle.
static func angle(a: float) -> float:
	return to_screen(Vector2.from_angle(a)).angle()


## Screen offset from world point `origin` to world point `p`.
static func rel(p: Vector2, origin: Vector2) -> Vector2:
	return to_screen(p - origin)


## Converts a screen-relative input vector (stick / WASD) to a world direction
## of the same magnitude, so "up" moves up the screen.
static func input_to_world(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return v
	return to_world(Vector2(v.x, v.y * 0.5)).normalized() * v.length()


## Sets the canvas item's draw transform so world-space offsets drawn next are
## projected onto the floor around screen point `at` (circles become 2:1 ellipses).
static func ground(ci: CanvasItem, at: Vector2 = Vector2.ZERO) -> void:
	ci.draw_set_transform_matrix(Transform2D(M.x, M.y, at))


## Draws a block standing on the ground: footprint centred on `center` (world
## offset) with half extents `half`, `height` pixels tall.
## Colours: top, left face (world south side), right face (world east side).
static func box(ci: CanvasItem, center: Vector2, half: Vector2, height: float, top: Color, left: Color, right: Color, trim := Color(0, 0, 0, 0), lift := 0.0) -> void:
	var up := Vector2(0, -height)
	var l := Vector2(0, -lift)
	var a := to_screen(center + Vector2(-half.x, -half.y)) + l
	var b := to_screen(center + Vector2(half.x, -half.y)) + l
	var c := to_screen(center + Vector2(half.x, half.y)) + l
	var d := to_screen(center + Vector2(-half.x, half.y)) + l
	# faces darken toward the floor (contact shading); no outlines, shape comes
	# from the lit / shadowed tones and a highlight on the edges facing the light
	var ld := left.darkened(0.35)
	var rd := right.darkened(0.35)
	ci.draw_polygon(PackedVector2Array([d, c, c + up, d + up]), PackedColorArray([ld, ld, left, left]))
	ci.draw_polygon(PackedVector2Array([c, b, b + up, c + up]), PackedColorArray([rd, rd, right, right]))
	ci.draw_colored_polygon(PackedVector2Array([a + up, b + up, c + up, d + up]), top)
	ci.draw_line(d + up, c + up, top.lightened(0.2), 1.0)
	ci.draw_line(c + up, c, left.lightened(0.12), 1.0)
	ci.draw_polyline(PackedVector2Array([d, c, b]), Color(0, 0, 0, 0.45), 1.0)
	if trim.a > 0.0:
		# a worn metal band along the far edges of the lid
		var t := Color(trim.r, trim.g, trim.b, 0.55)
		ci.draw_polyline(PackedVector2Array([d + up, a + up, b + up]), t, 1.0)


## Transform for drawing on a vertical face. Local x runs along the world axis
## `axis` (Vector2.RIGHT or Vector2.DOWN) in world pixels from world offset
## `start`; local y is screen pixels (negative = up).
static func face(ci: CanvasItem, start: Vector2, axis: Vector2) -> void:
	ci.draw_set_transform_matrix(Transform2D(to_screen(axis), Vector2(0, 1), to_screen(start)))
