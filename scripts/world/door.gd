class_name Door
extends StaticBody2D
## A blast-door tile. Opens automatically when the player approaches and its
## requirement flag (if any) is set. Once open it stays open (saved as a flag).

var level: Level
var cell := Vector2i.ZERO
var requirement := ""
var is_open := false
var open_t := 0.0
var interact_radius := 64.0
var horizontal := true   # true: door spans a corridor running north-south
var _shape: CollisionShape2D
var cv: IsoView

const T := 32
const REQ_TEXT := {
	"power": "Mag-locked — main power is offline.",
	"research": "Sealed — Xenolab credentials required (research archive).",
	"cause": "SECURITY CORE — authorisation required (Dr. Varrow's credentials).",
	"boss": "CONTAINMENT VAULT — locked by WARDEN.",
}


func setup(p_level: Level, p_cell: Vector2i, req: String) -> void:
	level = p_level
	cell = p_cell
	requirement = req
	position = Vector2(cell.x * T + T * 0.5, cell.y * T + T * 0.5)
	horizontal = level.is_wall(cell.x - 1, cell.y) or Level.DOOR_REQ.has(level.ch(cell.x - 1, cell.y)) or Level.DOOR_REQ.has(level.ch(cell.x + 1, cell.y))


func _ready() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(T, T)
	_shape.shape = r
	add_child(_shape)
	cv = IsoView.attach(self, false)
	if GameState.has_flag(Level.door_flag(cell.x, cell.y)):
		is_open = true
		open_t = 1.0
		_shape.disabled = true
	elif requirement != "":
		add_to_group("interactable")


func unlocked() -> bool:
	return requirement == "" or GameState.has_flag(requirement)


func _physics_process(delta: float) -> void:
	if is_open:
		if open_t < 1.0:
			open_t = minf(1.0, open_t + delta * 3.0)
			if cv != null: cv.queue_redraw()
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if unlocked() and p.global_position.distance_to(global_position) < 80.0:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	level.set_cell_solid(cell, false)
	GameState.set_flag(Level.door_flag(cell.x, cell.y))
	remove_from_group("interactable")
	Audio.play("door", global_position)
	if requirement != "":
		Fx.burst(get_parent(), Iso.sp(global_position, 20), Color(0.4, 1.0, 0.5), 8, 120.0)


func interact_text() -> String:
	return "Locked bulkhead" if not unlocked() else "Bulkhead"


func interact(_player: Node) -> void:
	if not unlocked():
		Events.msg(REQ_TEXT.get(requirement, "Locked."), Color(0.9, 0.45, 0.3))


func _render() -> void:
	var H := Level.WALL_H
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var perp := Vector2(axis.y, axis.x)
	var hw := T * 0.5
	var lift := open_t * (H - 8.0)
	var trim := Color(0.27, 0.23, 0.15)
	if open_t < 1.0:
		# panel (drawn on the doorway's centre plane) slides up into the lintel
		Iso.face(cv, -axis * hw, axis)
		var pr := Rect2(0, -H + lift, T, H - lift)
		if pr.size.y > 0.0:
			cv.draw_rect(pr, Color(0.13, 0.12, 0.11))
			var y := pr.position.y + 4.0
			while y < pr.end.y - 3.0:
				cv.draw_line(Vector2(2, y), Vector2(T - 2, y), Color(0.09, 0.085, 0.08), 2.0)
				y += 7.0
			cv.draw_line(Vector2(hw, pr.position.y), Vector2(hw, pr.end.y), Color(0.05, 0.05, 0.05), 2.0)
			# hazard band
			var band := Rect2(0, maxf(pr.position.y, -18.0), T, 7)
			if band.position.y < pr.end.y:
				cv.draw_rect(band, Color(0.4, 0.33, 0.1))
				for i in range(-T, T * 2, 8):
					cv.draw_line(Vector2(i * 0.5, band.end.y), Vector2(i * 0.5 + 5, band.position.y), Color(0.05, 0.05, 0.05), 2.0)
			cv.draw_line(Vector2(0, pr.position.y), Vector2(0, pr.end.y), Color(0.2, 0.19, 0.17), 1.0)   # lit edge
			var lc := Color(0.25, 1.0, 0.35) if unlocked() else Color(1.0, 0.15, 0.08)
			if requirement != "" or not unlocked():
				cv.draw_circle(Vector2(hw, pr.position.y + 9), 3.0, lc)
				cv.draw_circle(Vector2(hw, pr.position.y + 9), 7.0, Color(lc.r, lc.g, lc.b, 0.25))
		cv.draw_set_transform(Vector2.ZERO)
	# lintel spanning the doorway
	Iso.box(cv, Vector2.ZERO, axis * hw + perp * 7.0, 9.0, Color(0.16, 0.15, 0.14), Color(0.12, 0.11, 0.1), Color(0.08, 0.075, 0.07), trim, H - 9.0)
