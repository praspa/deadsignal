class_name HiveHole
extends StaticBody2D
## The resin-crusted sinkhole between Kessar IV's surface and the Brood hive.
## On the surface it leads down; in the hive the same opening climbs back up.

signal use(dest: String)

var dest := "kessar_hive"
var interact_radius := 64.0
var t := 0.0
var cv: IsoView


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("hive_hole")
	collision_layer = 0
	collision_mask = 0
	cv = IsoView.attach(self)
	cv.z_index = -1
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.color = Color(0.55, 0.9, 0.3)
	light.energy = 0.5
	light.texture_scale = 1.3
	light.scale = Vector2(1.0, 0.6)
	cv.add_child(light)


func going_down() -> bool:
	return dest == "kessar_hive"


func interact_text() -> String:
	return "Descend into the hive" if going_down() else "Climb back up to the surface"


func interact(_player: Node) -> void:
	use.emit(dest)


func _process(delta: float) -> void:
	t += delta


func _render() -> void:
	Iso.ground(cv)
	# resin crust, then the dark throat with a faint glow deep inside
	cv.draw_circle(Vector2.ZERO, 30.0, Color(0.3, 0.27, 0.2))
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		cv.draw_circle(Vector2.from_angle(a) * 26.0, 7.0, Color(0.38, 0.34, 0.26))
	cv.draw_circle(Vector2.ZERO, 20.0, Color(0.05, 0.05, 0.04))
	cv.draw_circle(Vector2.ZERO, 11.0, Color(0.3, 0.55, 0.15, 0.25 + 0.1 * sin(t * 2.0)))
	cv.draw_circle(Vector2.ZERO, 6.0, Color(0.02, 0.02, 0.02))
	cv.draw_set_transform(Vector2.ZERO)
	if not going_down():
		# a rope of resin and roots to climb
		cv.draw_line(Vector2(-4, 0), Vector2(-2, -46), Color(0.45, 0.38, 0.28), 3.0)
		cv.draw_line(Vector2(5, 0), Vector2(3, -46), Color(0.4, 0.34, 0.25), 2.0)
