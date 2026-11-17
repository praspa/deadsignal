class_name LootContainer
extends StaticBody2D
## Supply crate (common) or strongbox (better loot). Opened once; state is saved.

var level: Level
var cell := Vector2i.ZERO
var strong := false
var opened := false
var interact_radius := 54.0
var cv: IsoView

const T := 32


func setup(p_level: Level, p_cell: Vector2i, p_strong: bool) -> void:
	level = p_level
	cell = p_cell
	strong = p_strong
	position = Vector2(cell.x * T + T * 0.5, cell.y * T + T * 0.5)


func flag() -> String:
	return "box:%d,%d" % [cell.x, cell.y]


func _ready() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, 26)
	cs.shape = r
	add_child(cs)
	cv = IsoView.attach(self, false)
	opened = GameState.has_flag(flag())
	if not opened:
		add_to_group("interactable")


func interact_text() -> String:
	return "Open strongbox" if strong else "Search supply crate"


func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	GameState.set_flag(flag())
	remove_from_group("interactable")
	level.container_loot(global_position + Vector2(10, 10), strong)
	Audio.play("crate", global_position, 0.85 if strong else 1.0)
	Fx.burst(get_parent(), Iso.sp(global_position, 16), Color(0.7, 0.6, 0.4), 10, 120.0)
	GameState.add_xp(10 if strong else 4)
	if cv != null: cv.queue_redraw()


func _render() -> void:
	var body := Color(0.2, 0.19, 0.14) if not strong else Color(0.16, 0.15, 0.17)
	var trim := Color(0.32, 0.27, 0.16) if not strong else Color(0.38, 0.32, 0.19)
	var half := Vector2(13, 10) if not strong else Vector2(11, 11)
	Iso.box(cv, Vector2.ZERO, half, 16.0, body.lightened(0.1), body, body.darkened(0.3), trim)
	if opened:
		# lid flung open behind the box, dark interior
		Iso.box(cv, Vector2(0, -half.y - 2), Vector2(half.x, 2), 14.0, body.darkened(0.2), body.darkened(0.3), body.darkened(0.4), trim, 12.0)
		var a := Iso.to_screen(Vector2(-half.x + 2, -half.y + 2)) - Vector2(0, 16)
		var b := Iso.to_screen(Vector2(half.x - 2, -half.y + 2)) - Vector2(0, 16)
		var c := Iso.to_screen(Vector2(half.x - 2, half.y - 2)) - Vector2(0, 16)
		var d := Iso.to_screen(Vector2(-half.x + 2, half.y - 2)) - Vector2(0, 16)
		cv.draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color(0.03, 0.03, 0.03))
	else:
		Iso.box(cv, Vector2.ZERO, half + Vector2(1, 1), 5.0, body.lightened(0.15), body.lightened(0.05), body.darkened(0.15), trim, 16.0)
		# front latch / hazard stripe on the camera-facing side
		Iso.face(cv, Vector2(-half.x, half.y), Vector2.RIGHT)
		if strong:
			cv.draw_rect(Rect2(half.x - 4, -14, 8, 8), trim)
			cv.draw_circle(Vector2(half.x, -10), 2.0, Color(1.0, 0.25, 0.1))
		else:
			cv.draw_line(Vector2(0, -8), Vector2(half.x * 2, -8), trim, 1.5)
			cv.draw_line(Vector2(6, -16), Vector2(6, 0), trim, 1.0)
			cv.draw_line(Vector2(half.x * 2 - 6, -16), Vector2(half.x * 2 - 6, 0), trim, 1.0)
		cv.draw_set_transform(Vector2.ZERO)
