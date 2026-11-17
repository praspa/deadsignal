class_name Shade
## Volume shading for procedural art: shapes are defined by a shadow tone, a
## lit tone and an edge highlight from the scene's key light (upper left),
## instead of flat fills with bright outlines.

const LIGHT_DIR := Vector2(-0.6, -0.8)   # toward the key light, screen space


static func shadow_of(c: Color) -> Color:
	return c.darkened(0.5)


static func light_of(c: Color) -> Color:
	return c.lightened(0.16)


## Sphere-ish blob: shadow disc, lit disc offset toward the light, small specular.
static func ball(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, shadow_of(col))
	ci.draw_circle(c + LIGHT_DIR * r * 0.18, r * 0.8, col)
	ci.draw_circle(c + LIGHT_DIR * r * 0.45, r * 0.3, light_of(col))


## Convex polygon: shadow fill, lit fill shrunk toward the light, highlight on
## the edges that face the light.
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, shadow_of(col))
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(pts.size())
	var lit := PackedVector2Array()
	for p in pts:
		lit.append(cen + (p - cen) * 0.84 + LIGHT_DIR * 1.2)
	ci.draw_colored_polygon(lit, col)
	var hi := light_of(col)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var mid := (a + b) * 0.5
		var n := (mid - cen).normalized()
		if n.dot(LIGHT_DIR) > 0.35:
			ci.draw_line(a.lerp(b, 0.1), a.lerp(b, 0.9), hi, 1.0)


## Thick limb / rod: shadow stroke with a narrower lit stroke on the light side.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, shadow_of(col), w)
	var off := LIGHT_DIR * w * 0.18
	ci.draw_line(a + off, b + off, col, w * 0.55)


## Axis-aligned box face with a top-left lit edge and bottom-right shadow edge.
static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r, col)
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), light_of(col), 1.0)
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), light_of(col), 1.0)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, shadow_of(col), 1.0)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, shadow_of(col), 1.0)
