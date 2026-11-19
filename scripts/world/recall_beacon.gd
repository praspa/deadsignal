class_name RecallBeacon
extends Node2D
## Marker left where the operative recalled from: the ship's teleport pad
## returns them here. Purely visual; the beacon itself is GameState.beacon.

var t := 0.0
var cv: IsoView


func _ready() -> void:
	add_to_group("recall_beacon")
	cv = IsoView.attach(self)
	cv.z_index = -1
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.color = Color(0.4, 0.75, 1.0)
	light.energy = 0.6
	light.scale = Vector2(1.0, 0.6)
	cv.add_child(light)


func _process(delta: float) -> void:
	t += delta


func _render() -> void:
	var blink := 0.5 + 0.5 * sin(t * 5.0)
	Iso.ground(cv)
	cv.draw_arc(Vector2.ZERO, 14.0, 0, TAU, 20, Color(0.4, 0.75, 1.0, 0.4 + 0.5 * blink), 2.0)
	cv.draw_set_transform(Vector2.ZERO)
	cv.draw_line(Vector2(0, 0), Vector2(0, -14), Color(0.5, 0.55, 0.6), 2.0)
	cv.draw_circle(Vector2(0, -16), 3.0, Color(0.5, 0.85, 1.0, 0.4 + 0.6 * blink))
