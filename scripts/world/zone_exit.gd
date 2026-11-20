class_name ZoneExit
extends StaticBody2D
## A walkable transition to another zone of the same destination (requirements
## 15.11), defined in data/locations.json under the location's "exits":
##   "Y": {"to": "lastwater_streets", "arrive": "Y", "text": "Into the city",
##         "look": "gate" | "door", "requires": "<flag>", "locked": "<message>"}
## The operative arrives beside the matching exit char in the destination zone.

signal use(dest: String, arrive: String)

var key := ""
var data: Dictionary = {}
var interact_radius := 64.0
var t := 0.0
var cv: IsoView
var near := false
static var _font: Font


func setup(p_key: String, p_data: Dictionary) -> void:
	key = p_key
	data = p_data


func _ready() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	add_to_group("interactable")
	add_to_group("zone_exit")
	collision_layer = 0
	collision_mask = 0
	cv = IsoView.attach(self)
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.energy = 1.1
	light.texture_scale = 1.8
	light.scale = Vector2(1.0, 0.6)
	light.position = Vector2(0, -20)
	light.color = Color(1.0, 0.75, 0.35) if is_open() else Color(1.0, 0.3, 0.2)
	cv.add_child(light)


func is_open() -> bool:
	var req := String(data.get("requires", ""))
	return req == "" or GameState.has_flag(req)


func interact_text() -> String:
	return String(data.get("text", "Go")) if is_open() else String(data.get("text", "Go")) + " (sealed)"


func interact(_player: Node) -> void:
	if not is_open():
		Events.msg(String(data.get("locked", "Sealed.")), Color(0.9, 0.45, 0.3))
		Audio.play("door", global_position, 0.6)
		return
	use.emit(String(data["to"]), String(data.get("arrive", key)))


func _process(delta: float) -> void:
	t += delta
	var p := get_tree().get_first_node_in_group("player") as Node2D
	near = p != null and p.global_position.distance_to(global_position) < 420.0


func _render() -> void:
	var open := is_open()
	var glow := Color(1.0, 0.75, 0.35) if open else Color(1.0, 0.3, 0.2)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	if String(data.get("look", "gate")) == "door":
		# a heavy civic door set in the wall: frame, panels, card reader
		Iso.box(cv, Vector2.ZERO, Vector2(14, 4), 46.0, Color(0.42, 0.34, 0.24), Color(0.32, 0.25, 0.18), Color(0.22, 0.17, 0.12), Color(0.6, 0.5, 0.3))
		Iso.face(cv, Vector2(-14, 4), Vector2.RIGHT)
		cv.draw_rect(Rect2(4, -40, 9, 36), Color(0.2, 0.16, 0.12))
		cv.draw_rect(Rect2(15, -40, 9, 36), Color(0.2, 0.16, 0.12))
		cv.draw_rect(Rect2(25, -26, 3, 5), glow if open else Color(glow.r, glow.g, glow.b, 0.4 + 0.6 * pulse))
		cv.draw_set_transform(Vector2.ZERO)
		if near:
			_label(-62.0, glow, open)
		return
	# a town gate: two timber posts, a crossbeam with a sign, lanterns, and
	# chevrons on the ground pointing through it
	Iso.ground(cv)
	for i in 3:
		var y := -14.0 + i * 10.0
		cv.draw_polyline(PackedVector2Array([Vector2(-12, y + 7), Vector2(0, y), Vector2(12, y + 7)]), Color(glow.r, glow.g, glow.b, 0.3 + 0.6 * fmod(pulse + i * 0.33, 1.0)), 3.0)
	cv.draw_set_transform(Vector2.ZERO)
	var wood := Color(0.42, 0.3, 0.18)
	for px in [-26.0, 26.0]:
		Iso.box(cv, Iso.to_world(Vector2(px, 0)), Vector2(3, 3), 64.0, wood.lightened(0.1), wood, wood.darkened(0.35))
		cv.draw_circle(Vector2(px, -50), 4.0, glow)
		cv.draw_circle(Vector2(px, -50), 9.0, Color(glow.r, glow.g, glow.b, 0.2 + 0.1 * pulse))
	cv.draw_rect(Rect2(-30, -66, 60, 6), wood.darkened(0.1))
	cv.draw_rect(Rect2(-20, -62, 40, 12), Color(0.3, 0.22, 0.14))
	cv.draw_string(_font, Vector2(-20, -53), String(data.get("sign", "")), HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.95, 0.85, 0.6))
	if near:
		_label(-80.0, glow, open)


## Where this leads, floating above it while the operative is in the area.
func _label(y: float, col: Color, open: bool) -> void:
	var txt := ">> " + String(data.get("text", "Go")) + ("" if open else " (sealed)")
	cv.draw_string(_font, Vector2(-90, y + 1), txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(0, 0, 0, 0.8))
	cv.draw_string(_font, Vector2(-90, y), txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, col)
