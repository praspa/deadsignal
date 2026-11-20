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


func setup(p_key: String, p_data: Dictionary) -> void:
	key = p_key
	data = p_data


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("zone_exit")
	collision_layer = 0
	collision_mask = 0
	cv = IsoView.attach(self)
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.energy = 0.55
	light.texture_scale = 1.0
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
		return
	# a road gate: chevrons on the ground pointing onward, a lantern post
	Iso.ground(cv)
	for i in 3:
		var y := -10.0 + i * 8.0
		cv.draw_polyline(PackedVector2Array([Vector2(-10, y + 6), Vector2(0, y), Vector2(10, y + 6)]), Color(glow.r, glow.g, glow.b, 0.25 + 0.5 * fmod(pulse + i * 0.33, 1.0)), 2.0)
	cv.draw_set_transform(Vector2.ZERO)
	cv.draw_line(Vector2(16, 0), Vector2(16, -34), Color(0.35, 0.28, 0.2), 2.0)
	cv.draw_circle(Vector2(16, -36), 3.0, glow)
