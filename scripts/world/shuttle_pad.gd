class_name ShuttlePad
extends StaticBody2D
## Landing beacon at a mission site's start point: interacting with it flies
## the operative back to the ship.

signal board

var interact_radius := 60.0
var t := 0.0
var cv: IsoView


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 0
	cv = IsoView.attach(self)
	cv.z_index = -1
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.color = Color(0.4, 0.75, 1.0)
	light.energy = 0.7
	light.scale = Vector2(1.0, 0.6)
	cv.add_child(light)


func interact_text() -> String:
	return "Board shuttle (return to the %s)" % GameState.location_name("ship")


func interact(_player: Node) -> void:
	board.emit()


func _process(delta: float) -> void:
	t += delta
	if cv != null:
		cv.redraw_if_visible()


func _render() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	Iso.ground(cv)
	cv.draw_circle(Vector2.ZERO, 22.0, Color(0.1, 0.1, 0.1, 0.6))
	cv.draw_arc(Vector2.ZERO, 22.0, 0, TAU, 28, Color(0.4, 0.75, 1.0, 0.35 + 0.4 * pulse), 2.0)
	cv.draw_arc(Vector2.ZERO, 14.0, 0, TAU, 20, Color(0.4, 0.75, 1.0, 0.25), 1.0)
	for i in 4:
		var a := TAU * i / 4.0 + t * 0.6
		cv.draw_circle(Vector2.from_angle(a) * 22.0, 2.0, Color(1.0, 0.75, 0.3, 0.9))
	cv.draw_set_transform(Vector2.ZERO)
	Iso.box(cv, Vector2.ZERO, Vector2(3, 3), 18.0, Color(0.3, 0.28, 0.25), Color(0.2, 0.19, 0.17), Color(0.13, 0.12, 0.11))
	cv.draw_circle(Vector2(0, -21), 2.5, Color(0.4, 0.8, 1.0, 0.5 + 0.5 * pulse))
