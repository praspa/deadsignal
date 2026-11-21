class_name AbilityIcon
## Procedural icons for abilities and Doctrine skills (HUD ability bar and the
## Doctrine screen). Roughly 36x36 px around `c`.


static func color_of(id: String) -> Color:
	match id:
		"pulse":
			return Color(0.55, 0.8, 1.0)
		"overcharge":
			return Color(1.0, 0.55, 0.15)
		"roll":
			return Color(0.8, 0.8, 0.75)
	if id.begins_with("sb_"):
		return Color(1.0, 0.6, 0.25)
	if id.begins_with("gl_"):
		return Color(0.95, 0.85, 0.45)
	if id.begins_with("vg_"):
		return Color(0.9, 0.35, 0.3)
	return Color(0.8, 0.8, 0.75)


static func draw(d: CanvasItem, id: String, c: Vector2, col: Color) -> void:
	match id:
		"roll":
			d.draw_arc(c, 13.0, PI * 0.2, PI * 1.7, 16, col, 4.0)
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(10, -14), c + Vector2(18, -6), c + Vector2(8, -4)]), col)
		"overcharge":
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(3, -17), c + Vector2(-9, 2), c + Vector2(0, 2), c + Vector2(-4, 17), c + Vector2(9, -3), c + Vector2(0, -3)]), col)
		"pulse":
			d.draw_circle(c, 4.0, col)
			d.draw_arc(c, 10.0, 0, TAU, 20, col, 2.0)
			d.draw_arc(c, 16.0, 0, TAU, 24, col, 2.0)
		"sb_concussion":
			d.draw_circle(c + Vector2(0, 3), 9.0, col)
			d.draw_rect(Rect2(c + Vector2(-3, -10), Vector2(6, 5)), col.darkened(0.3))
			d.draw_line(c + Vector2(3, -8), c + Vector2(10, -13), col, 2.0)
			for k in 3:
				d.draw_arc(c + Vector2(0, 3), 12.0 + k * 3.0, -0.6 + k * 2.1, 0.2 + k * 2.1, 6, col.darkened(0.2), 1.5)
		"sb_semtex":
			d.draw_rect(Rect2(c + Vector2(-10, -6), Vector2(20, 12)), col.darkened(0.25))
			d.draw_rect(Rect2(c + Vector2(-10, -6), Vector2(20, 12)), col, false, 1.5)
			d.draw_circle(c + Vector2(6, -1), 2.5, Color(1.0, 0.25, 0.1))
			d.draw_line(c + Vector2(-6, 6), c + Vector2(-10, 13), col, 2.0)
			d.draw_line(c + Vector2(6, 6), c + Vector2(10, 13), col, 2.0)
		"sb_incendiary":
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 12), c + Vector2(9, 12), c + Vector2(6, -2), c + Vector2(0, -16), c + Vector2(-6, -2)]), col)
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 12), c + Vector2(4, 12), c + Vector2(0, 0)]), Color(1.0, 0.9, 0.5))
		"sb_strike":
			d.draw_arc(c, 13.0, 0, TAU, 24, col, 2.0)
			d.draw_line(c + Vector2(-17, 0), c + Vector2(17, 0), col, 1.5)
			d.draw_line(c + Vector2(0, -17), c + Vector2(0, 17), col, 1.5)
			d.draw_circle(c, 3.0, col)
		"gl_mark":
			d.draw_arc(c, 11.0, 0, TAU, 20, col, 2.0)
			for k in 4:
				var dv := Vector2.from_angle(k * PI * 0.5)
				d.draw_line(c + dv * 7.0, c + dv * 16.0, col, 2.0)
			d.draw_circle(c, 2.5, Color(1.0, 0.25, 0.15))
		"gl_deadeye":
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(-15, 0), c + Vector2(0, -9), c + Vector2(15, 0), c + Vector2(0, 9)]), col.darkened(0.4))
			d.draw_circle(c, 5.5, col)
			d.draw_circle(c, 2.2, Color(0.1, 0.08, 0.05))
		"vg_charge":
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -12), c + Vector2(10, 0), c + Vector2(-6, 12), c + Vector2(-2, 0)]), col)
			for k in 3:
				d.draw_line(c + Vector2(-16 + k * 3, -7 + k * 7), c + Vector2(-9 + k * 3, -7 + k * 7), col.darkened(0.2), 2.0)
		"vg_litany":
			d.draw_line(c + Vector2(0, -15), c + Vector2(0, 15), col, 3.0)
			d.draw_line(c + Vector2(-9, -6), c + Vector2(9, -6), col, 3.0)
			d.draw_arc(c, 15.0, 0, TAU, 24, col.darkened(0.2), 1.5)
		_:
			# passives: a doctrine sigil
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(c + Vector2.from_angle(k * TAU / 6.0 - PI * 0.5) * 13.0)
			pts.append(pts[0])
			d.draw_polyline(pts, col, 2.0)
			d.draw_circle(c, 4.0, col)
