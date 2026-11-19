class_name Terminal
extends StaticBody2D
## Cogitator terminal. Interacting opens the terminal UI with the pages from
## data/terminals.json. Some terminals set mission flags or save the game.

var level: Level
var term_id := "1"
var cell := Vector2i.ZERO
var data: Dictionary = {}
var interact_radius := 56.0
var t := 0.0
var cv: IsoView

const T := 32


func setup(p_level: Level, id: String, p_cell: Vector2i) -> void:
	level = p_level
	term_id = id
	cell = p_cell
	data = ItemDB.terminals.get(id, {})
	position = Vector2(cell.x * T + T * 0.5, cell.y * T + T * 0.5)


func _ready() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, 26)
	cs.shape = r
	add_child(cs)
	cv = IsoView.attach(self, false)
	add_to_group("interactable")
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3   # also lights the floor layer
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.color = _screen_color()
	light.energy = 0.8
	light.texture_scale = 1.2
	light.position = Vector2(0, -30)
	light.scale = Vector2(1.0, 0.6)
	cv.add_child(light)
	t = randf() * 10.0


func read_flag() -> String:
	return GameState.area_flag("read:%s:%d,%d" % [term_id, cell.x, cell.y])


func _screen_color() -> Color:
	match String(data.get("type", "log")):
		"save":
			return Color(0.3, 0.7, 1.0)
		"power", "research", "cause", "nav":
			return Color(1.0, 0.7, 0.2)
	return Color(0.35, 1.0, 0.45)


func interact_text() -> String:
	if String(data.get("type", "")) == "save":
		return "Save progress (Field Uplink)"
	if String(data.get("type", "")) == "nav":
		return "Nav console: plot a course"
	return "Access terminal: " + String(data.get("title", "Terminal"))


func interact(_player: Node) -> void:
	Audio.play_ui("terminal")
	if String(data.get("type", "")) == "nav":
		Events.open_nav.emit()
		return
	Events.open_terminal.emit(term_id, self)


func _process(delta: float) -> void:
	t += delta
	if int(t * 8.0) != int((t - delta) * 8.0):
		if cv != null: cv.redraw_if_visible()


func _render() -> void:
	var sc := _screen_color()
	var read := GameState.has_flag(read_flag())
	# cabinet block, console facing the camera
	Iso.box(cv, Vector2.ZERO, Vector2(11, 11), 26.0, Color(0.17, 0.16, 0.15), Color(0.12, 0.11, 0.1), Color(0.08, 0.075, 0.07), Color(0.38, 0.29, 0.13))
	cv.draw_rect(Rect2(-15, -40, 30, 14), Color(0.17, 0.16, 0.15))
	# angled screen
	cv.draw_rect(Rect2(-11, -38, 22, 11), Color(sc.r * 0.15, sc.g * 0.15, sc.b * 0.15))
	for i in 3:
		var ln := 4.0 + float((int(t * 8.0) + i * 5) % 14)
		cv.draw_line(Vector2(-9, -35 + i * 3), Vector2(-9 + ln, -35 + i * 3), Color(sc.r, sc.g, sc.b, 0.85), 1.0)
	# keys / dials
	for i in 4:
		cv.draw_rect(Rect2(-11 + i * 6, -20, 4, 3), Color(0.25, 0.23, 0.2))
	cv.draw_circle(Vector2(8, -10), 3.0, Color(0.3, 0.27, 0.22))
	var blink := int(t * 2.0) % 2 == 0
	var lc := Color(1.0, 0.2, 0.1) if not read else Color(0.3, 0.6, 0.3)
	if blink or read:
		cv.draw_circle(Vector2(-8, -9), 2.0, lc)
	# skull finial
	cv.draw_circle(Vector2(0, -44), 4.0, Color(0.5, 0.46, 0.4))
	cv.draw_circle(Vector2(-1.5, -44.5), 1.0, Color(0.05, 0.05, 0.05))
	cv.draw_circle(Vector2(1.5, -44.5), 1.0, Color(0.05, 0.05, 0.05))
	if not read and not String(data.get("type", "")) in ["save", "nav"]:
		var bob := sin(t * 3.0) * 3.0
		cv.draw_colored_polygon(PackedVector2Array([Vector2(-5, -58 + bob), Vector2(5, -58 + bob), Vector2(0, -51 + bob)]), Color(1.0, 0.8, 0.3, 0.9))
