class_name AttrIcon
extends Control
## Procedural brass icon for an attribute on the character sheet:
##   STR  dumbbell        DEX  crosshair
##   INT  brain           WIL  shield
## Drawn in a SIZE x SIZE box. Add with AttrIcon.attach(button, "str"): the
## button gets a blank icon of the same size to make room, and this control
## is laid over it.

const SIZE := 40.0
const LIGHT := Color(0.86, 0.68, 0.32)
const MID := Color(0.62, 0.48, 0.22)
const DARK := Color(0.2, 0.15, 0.08)

static var _spacer: ImageTexture

var attr := "str"


static func attach(b: Button, a: String) -> AttrIcon:
	if _spacer == null:
		_spacer = ImageTexture.create_from_image(Image.create(int(SIZE), int(SIZE), false, Image.FORMAT_RGBA8))
	b.icon = _spacer
	b.add_theme_constant_override("h_separation", 12)
	var ic := AttrIcon.new()
	ic.attr = a
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size = Vector2(SIZE, SIZE)
	b.add_child(ic)
	# sit exactly over the spacer: left content margin, centred vertically
	ic.position = Vector2(14, (b.custom_minimum_size.y - SIZE) * 0.5)
	return ic


func _draw() -> void:
	match attr:
		"str":
			_dumbbell()
		"dex":
			_crosshair()
		"int":
			_brain()
		"wil":
			_shield()


func _dumbbell() -> void:
	draw_rect(Rect2(8, 18.5, 24, 3), MID)                         # bar
	for side in [-1.0, 1.0]:
		var cx: float = 20.0 + side * 11.0
		draw_rect(Rect2(cx - 2.5, 9, 5, 22), LIGHT)               # big plate
		draw_rect(Rect2(cx - 2.5, 9, 5, 22), DARK, false, 1.0)
		var ox: float = cx + side * 5.0
		draw_rect(Rect2(ox - 2, 13, 4, 14), MID)                  # outer plate
		draw_rect(Rect2(ox - 2, 13, 4, 14), DARK, false, 1.0)
		var ix: float = cx - side * 4.5
		draw_rect(Rect2(ix - 1, 16, 2, 8), MID)                   # collar


func _crosshair() -> void:
	var c := Vector2(20, 20)
	draw_arc(c, 12.0, 0.0, TAU, 32, LIGHT, 2.0, true)
	draw_arc(c, 5.0, 0.0, TAU, 20, MID, 1.5, true)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 7.0, c + d * 18.0, LIGHT, 2.0, true)
	draw_circle(c, 1.8, LIGHT)


func _brain() -> void:
	var lobes := [[Vector2(12, 17), 7.0], [Vector2(20, 12), 7.5], [Vector2(28, 17), 7.0],
		[Vector2(14, 25), 6.5], [Vector2(26, 25), 6.5], [Vector2(20, 21), 8.0]]
	for l in lobes:                                               # dark rim, then fill
		draw_circle(l[0], float(l[1]) + 1.2, DARK)
	for l in lobes:
		draw_circle(l[0], float(l[1]), LIGHT)
	draw_rect(Rect2(21, 29, 4, 6), MID)                           # stem
	draw_line(Vector2(20, 6), Vector2(20, 30), DARK, 1.5, true)   # the two halves
	for f in [[Vector2(13, 15), 0.6], [Vector2(26, 15), 2.5], [Vector2(14, 24), -0.4], [Vector2(26, 24), 3.6]]:
		draw_arc(f[0], 3.5, float(f[1]), float(f[1]) + 2.4, 8, DARK, 1.3, true)   # folds


func _shield() -> void:
	var pts := PackedVector2Array([Vector2(9, 7), Vector2(31, 7), Vector2(31, 20), Vector2(20, 35), Vector2(9, 20)])
	draw_colored_polygon(pts, MID)
	var inner := PackedVector2Array([Vector2(20, 7), Vector2(31, 7), Vector2(31, 20), Vector2(20, 35)])
	draw_colored_polygon(inner, LIGHT)                            # lit half
	pts.append(pts[0])
	draw_polyline(pts, DARK, 1.5, true)
	draw_polyline(PackedVector2Array([Vector2(14, 22), Vector2(20, 16), Vector2(26, 22)]), DARK, 2.0, true)   # chevron, pointing up
