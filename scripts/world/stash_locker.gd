class_name StashLocker
extends StaticBody2D
## The cargo locker in the ship's hold: opens the stash screen, where items
## move between the operative's pack and the ship (GameState.stash).

var interact_radius := 62.0
var cv: IsoView


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 30)
	cs.shape = r
	add_child(cs)
	cv = IsoView.attach(self, false)


func interact_text() -> String:
	return "Open cargo locker (stash)"


func interact(_player: Node) -> void:
	Audio.play("crate", global_position, 0.8)
	Events.open_stash.emit()


func _render() -> void:
	var body := Color(0.3, 0.34, 0.4)
	Iso.box(cv, Vector2.ZERO, Vector2(14, 12), 30.0, body.lightened(0.15), body, body.darkened(0.35), Color(0.75, 0.8, 0.88))
	# hazard band and a status lamp on the camera-facing side
	Iso.face(cv, Vector2(-14, 12), Vector2.RIGHT)
	cv.draw_rect(Rect2(2, -12, 24, 4), Color(0.6, 0.48, 0.12))
	cv.draw_line(Vector2(14, -28), Vector2(14, -4), Color(0.12, 0.13, 0.15), 1.5)
	cv.draw_circle(Vector2(22, -22), 1.8, Color(0.35, 0.95, 0.5))
	cv.draw_set_transform(Vector2.ZERO)
