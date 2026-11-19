class_name CrewNpc
extends StaticBody2D
## A member of the ship's crew. Placeholder for now: stands at their post and
## says a line from data/crew.json when spoken to. Their services (vendor,
## decryption, healing, sealed salvage) hook in here later.

var crew_id := "Q"
var data: Dictionary = {}
var interact_radius := 60.0
var line_i := 0
var t := 0.0
var cv: IsoView


func setup(p_id: String, pos: Vector2) -> void:
	crew_id = p_id
	data = ItemDB.crew.get(p_id, {})
	position = pos


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("crew")
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0
	cs.shape = c
	add_child(cs)
	cv = IsoView.attach(self)
	t = randf() * 10.0
	line_i = randi() % maxi(1, (data.get("lines", []) as Array).size())


func display_name() -> String:
	return String(data.get("name", "Crew"))


func interact_text() -> String:
	return "Talk to " + display_name()


func interact(_player: Node) -> void:
	var lines: Array = data.get("lines", [])
	if lines.is_empty():
		return
	Events.msg("%s: \"%s\"" % [display_name(), String(lines[line_i % lines.size()])], Color(0.85, 0.78, 0.6))
	line_i += 1


func _process(delta: float) -> void:
	t += delta
	if cv != null:
		cv.redraw_if_visible()


func _render() -> void:
	var col: Array = data.get("color", [0.3, 0.3, 0.3])
	var cloth := Color(float(col[0]), float(col[1]), float(col[2]))
	var breathe := sin(t * 1.7) * 0.8
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45))
	cv.draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.45))
	cv.draw_set_transform(Vector2.ZERO)
	# legs, torso (work coat), shoulders, head
	Iso.box(cv, Vector2.ZERO, Vector2(5, 3.5), 16.0, cloth.darkened(0.3), cloth.darkened(0.45), cloth.darkened(0.6))
	Iso.box(cv, Vector2.ZERO, Vector2(6.5, 4.5), 16.0 + breathe, cloth.lightened(0.1), cloth, cloth.darkened(0.3), Color(0.4, 0.32, 0.18), 15.0)
	Iso.box(cv, Vector2.ZERO, Vector2(8, 4.5), 3.0, cloth.lightened(0.15), cloth.darkened(0.05), cloth.darkened(0.35), Color(0, 0, 0, 0), 30.0 + breathe)
	var head := Vector2(0, -38 + breathe)
	cv.draw_circle(head + Vector2(0, 1), 5.5, Color(0.22, 0.17, 0.14))
	cv.draw_circle(head, 5.0, Color(0.55, 0.43, 0.35))
	cv.draw_circle(head + Vector2(1.5, -1.0), 2.0, Color(0.65, 0.52, 0.42))
