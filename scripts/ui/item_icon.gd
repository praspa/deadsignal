class_name ItemIcon
## Procedural item silhouettes, so an item's type can be recognised at a glance
## (rifle, shotgun, pistol, maul, blade, helm, breastplate, gauntlets, boots,
## utility devices). Drawn in screen space around `at`, roughly 30x20 px at
## scale 1, with the rarity colour as trim / outline.

const DARK := Color(0.1, 0.1, 0.11)
const METAL := Color(0.24, 0.24, 0.26)
const METAL_HI := Color(0.4, 0.39, 0.38)
const WOOD := Color(0.32, 0.2, 0.11)
const LEATHER := Color(0.22, 0.16, 0.11)


static func draw(ci: CanvasItem, item: Dictionary, at: Vector2, s: float = 1.0, rc: Color = Color.WHITE) -> void:
	ci.draw_set_transform(at, 0.0, Vector2(s, s))
	var base := String(item.get("base", ""))
	var slot := String(item.get("slot", ""))
	if item.has("weapon"):
		match String(item["weapon"].get("type", "")):
			"rifle":
				_rifle(ci, rc)
			"shotgun":
				_shotgun(ci, rc)
			"energy":
				_pistol(ci, rc)
			_:
				if base == "chainblade":
					_blade(ci, rc)
				else:
					_maul(ci, rc)
	else:
		match slot:
			"head":
				_helm(ci, rc, base == "rebreather_helm")
				if String(item.get("unique", "")) == "kings_crest":
					# the King's crest of horns over the helm
					for k in 5:
						var ang := -PI * 0.5 + (k - 2) * 0.38
						var b0 := Vector2(0, -8)
						ci.draw_colored_polygon(PackedVector2Array([b0 + Vector2(-2.5, 0), b0 + Vector2(2.5, 0), b0 + Vector2.from_angle(ang) * (13.0 - absf(k - 2) * 2.0)]), Color(0.85, 0.75, 0.55))
			"body":
				_breastplate(ci, rc)
			"gloves":
				_gauntlet(ci, rc)
			"boots":
				_boots(ci, rc)
			_:
				_utility(ci, rc, base)
	ci.draw_set_transform(Vector2.ZERO)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, fill: Color, rc: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, rc, 1.2)


static func _rifle(ci: CanvasItem, rc: Color) -> void:
	_outline(ci, PackedVector2Array([Vector2(-16, -2), Vector2(-10, -4), Vector2(8, -4), Vector2(10, -6), Vector2(14, -6), Vector2(14, -3), Vector2(18, -3), Vector2(18, -1), Vector2(8, -1), Vector2(4, 1), Vector2(-9, 1), Vector2(-16, 4)]), METAL, rc)
	_outline(ci, PackedVector2Array([Vector2(-1, 1), Vector2(3, 1), Vector2(4, 8), Vector2(0, 8)]), DARK, rc)      # magazine
	ci.draw_rect(Rect2(-5, 1, 3, 4), DARK)                                                                    # grip
	ci.draw_line(Vector2(-4, -5), Vector2(3, -5), METAL_HI, 2.0)                                              # sight rail


static func _shotgun(ci: CanvasItem, rc: Color) -> void:
	_outline(ci, PackedVector2Array([Vector2(-16, 0), Vector2(-10, -3), Vector2(-4, -3), Vector2(-4, 3), Vector2(-9, 3), Vector2(-15, 5)]), WOOD, rc)  # stock
	_outline(ci, PackedVector2Array([Vector2(-4, -4), Vector2(17, -4), Vector2(17, 0), Vector2(-4, 1)]), METAL, rc)                                      # barrels
	ci.draw_line(Vector2(-3, -2), Vector2(16, -2), DARK, 1.0)
	_outline(ci, PackedVector2Array([Vector2(3, 1), Vector2(11, 1), Vector2(11, 4), Vector2(3, 4)]), WOOD, rc)                                          # pump


static func _pistol(ci: CanvasItem, rc: Color) -> void:
	_outline(ci, PackedVector2Array([Vector2(-10, -5), Vector2(10, -5), Vector2(12, -2), Vector2(10, 0), Vector2(-3, 0), Vector2(-5, 8), Vector2(-10, 8), Vector2(-8, 0), Vector2(-10, -1)]), METAL, rc)
	ci.draw_rect(Rect2(-2, -4, 8, 3), Color(0.3, 0.7, 1.0, 0.95))     # power cell
	ci.draw_circle(Vector2(11, -2.5), 1.8, Color(0.6, 0.9, 1.0))


static func _maul(ci: CanvasItem, rc: Color) -> void:
	ci.draw_line(Vector2(-14, 6), Vector2(6, -2), LEATHER, 3.0)
	ci.draw_line(Vector2(-14, 6), Vector2(-9, 4), DARK, 3.5)
	_outline(ci, PackedVector2Array([Vector2(3, -9), Vector2(12, -9), Vector2(15, -4), Vector2(12, 1), Vector2(3, 1), Vector2(1, -4)]), METAL, rc)
	ci.draw_circle(Vector2(8, -4), 2.5, Color(0.5, 0.8, 1.0, 0.95))   # shock core


static func _blade(ci: CanvasItem, rc: Color) -> void:
	_outline(ci, PackedVector2Array([Vector2(-6, -1), Vector2(14, -6), Vector2(17, -5), Vector2(-4, 3)]), Color(0.6, 0.58, 0.54), rc)
	for i in 6:
		var p := Vector2(-3, -1).lerp(Vector2(14, -6), float(i) / 6.0)
		ci.draw_line(p, p + Vector2(1, -2.5), DARK, 1.2)                # chain teeth
	ci.draw_rect(Rect2(-9, -3, 4, 7), Color(0.55, 0.42, 0.18))          # guard
	ci.draw_line(Vector2(-14, 4), Vector2(-8, 1), LEATHER, 3.0)


static func _helm(ci: CanvasItem, rc: Color, rebreather: bool) -> void:
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(Vector2(cos(a) * 9.0, sin(a) * 9.0 + 1.0))
	dome.append(Vector2(9, 7))
	dome.append(Vector2(-9, 7))
	_outline(ci, dome, METAL, rc)
	if rebreather:
		ci.draw_rect(Rect2(-6, -3, 12, 3), Color(0.8, 0.15, 0.1))         # eye lenses strip
		_outline(ci, PackedVector2Array([Vector2(-4, 2), Vector2(4, 2), Vector2(3, 8), Vector2(-3, 8)]), DARK, rc)  # filter grille
		for i in 3:
			ci.draw_line(Vector2(-2.5, 4 + i * 1.5), Vector2(2.5, 4 + i * 1.5), METAL_HI, 0.8)
	else:
		ci.draw_rect(Rect2(-8, -2, 16, 3), DARK)                          # visor slit
		ci.draw_line(Vector2(0, -8), Vector2(0, -2), rc, 1.5)             # crest ridge


static func _breastplate(ci: CanvasItem, rc: Color) -> void:
	_outline(ci, PackedVector2Array([Vector2(-11, -8), Vector2(-4, -6), Vector2(4, -6), Vector2(11, -8), Vector2(10, 2), Vector2(6, 9), Vector2(-6, 9), Vector2(-10, 2)]), METAL, rc)
	ci.draw_circle(Vector2(-11, -6), 4.5, Color(0.45, 0.07, 0.06))       # pauldrons
	ci.draw_circle(Vector2(11, -6), 4.5, Color(0.45, 0.07, 0.06))
	ci.draw_line(Vector2(-6, -1), Vector2(-1, 1), Color(0.6, 0.48, 0.2), 1.5)   # aquila
	ci.draw_line(Vector2(6, -1), Vector2(1, 1), Color(0.6, 0.48, 0.2), 1.5)
	ci.draw_circle(Vector2(0, 1), 1.6, Color(0.6, 0.48, 0.2))
	ci.draw_line(Vector2(0, 3), Vector2(0, 8), DARK, 1.0)


static func _gauntlet(ci: CanvasItem, rc: Color) -> void:
	_outline(ci, PackedVector2Array([Vector2(-10, 3), Vector2(-10, -4), Vector2(-3, -6), Vector2(-3, 5)]), DARK, rc)   # cuff
	_outline(ci, PackedVector2Array([Vector2(-3, -6), Vector2(5, -6), Vector2(7, -3), Vector2(7, 4), Vector2(-3, 5)]), METAL, rc)  # back of hand
	for i in 4:
		var y := -5.0 + i * 2.6
		ci.draw_line(Vector2(7, y), Vector2(12, y + 0.5), METAL_HI, 2.0)  # fingers
	ci.draw_line(Vector2(0, 4), Vector2(4, 8), METAL_HI, 2.2)             # thumb


static func _boots(ci: CanvasItem, rc: Color) -> void:
	for off in [Vector2(-5, -1), Vector2(4, 1)]:
		var o: Vector2 = off
		_outline(ci, PackedVector2Array([o + Vector2(-4, -9), o + Vector2(2, -9), o + Vector2(2, 2), o + Vector2(8, 3), o + Vector2(8, 6), o + Vector2(-4, 6)]), METAL, rc)
		ci.draw_rect(Rect2(o.x - 4, o.y + 4, 12, 2), DARK)                  # sole
		ci.draw_line(o + Vector2(-4, -4), o + Vector2(2, -4), METAL_HI, 1.0)


static func _utility(ci: CanvasItem, rc: Color, base: String) -> void:
	match base:
		"injector":
			_outline(ci, PackedVector2Array([Vector2(-12, -2), Vector2(6, -2), Vector2(6, 2), Vector2(-12, 2)]), Color(0.75, 0.75, 0.72), rc)
			ci.draw_rect(Rect2(-9, -1, 10, 2), Color(0.3, 0.9, 0.4))         # serum
			ci.draw_line(Vector2(6, 0), Vector2(13, 0), METAL_HI, 1.0)       # needle
			ci.draw_line(Vector2(-12, -4), Vector2(-12, 4), DARK, 2.0)
		"capacitor":
			_outline(ci, PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(6, 8), Vector2(-6, 8)]), DARK, rc)
			for i in 3:
				ci.draw_rect(Rect2(-5, -6 + i * 5, 10, 2), Color(1.0, 0.7, 0.2))
		"refractor":
			ci.draw_circle(Vector2.ZERO, 6.0, DARK)
			ci.draw_arc(Vector2.ZERO, 6.0, 0, TAU, 16, rc, 1.2)
			ci.draw_circle(Vector2.ZERO, 3.0, Color(0.8, 0.5, 1.0))
			ci.draw_arc(Vector2.ZERO, 9.5, -0.6, 2.2, 12, Color(0.8, 0.5, 1.0, 0.7), 1.2)
		_:  # auspex
			_outline(ci, PackedVector2Array([Vector2(-9, -7), Vector2(9, -7), Vector2(9, 7), Vector2(-9, 7)]), DARK, rc)
			ci.draw_rect(Rect2(-7, -5, 10, 8), Color(0.1, 0.35, 0.15))
			ci.draw_arc(Vector2(-2, -1), 3.0, 0, TAU, 10, Color(0.4, 1.0, 0.5), 1.0)
			ci.draw_circle(Vector2(6, -3), 1.3, Color(1.0, 0.3, 0.1))
			ci.draw_circle(Vector2(6, 2), 1.3, METAL_HI)
