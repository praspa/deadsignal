class_name LootContainer
extends StaticBody2D
## Supply crate (common) or strongbox (better loot). Opened once; state is saved.

var level: Level
var cell := Vector2i.ZERO
var strong := false
var opened := false
var interact_radius := 54.0
var cv: IsoView
var glow: PointLight2D   # subtle gold glow while unopened, so containers stand out in the dark
var t := 0.0

const T := 32


func setup(p_level: Level, p_cell: Vector2i, p_strong: bool) -> void:
	level = p_level
	cell = p_cell
	strong = p_strong
	position = Vector2(cell.x * T + T * 0.5, cell.y * T + T * 0.5)


func flag() -> String:
	return GameState.area_flag("box:%d,%d" % [cell.x, cell.y])


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
		glow = PointLight2D.new()
		glow.range_item_cull_mask = 3   # lights the floor around it too
		glow.height = 150.0
		glow.texture = LightUtil.radial(128)
		glow.color = Color(1.0, 0.78, 0.32)
		glow.texture_scale = 1.1 if not strong else 1.3
		glow.energy = 0.0
		glow.position = Vector2(0, -12)
		glow.scale = Vector2(1.0, 0.6)
		cv.add_child(glow)
		t = randf() * TAU


func _process(delta: float) -> void:
	if glow == null:
		return
	t += delta
	var base := 0.95 if strong else 0.75
	glow.energy = base + 0.2 * sin(t * 1.8)   # slow, soft pulse
	if cv != null:
		cv.redraw_if_visible()


func interact_text() -> String:
	return "Open strongbox" if strong else "Search supply crate"


func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	GameState.set_flag(flag())
	remove_from_group("interactable")
	if glow != null:
		var tw := create_tween()
		tw.tween_property(glow, "energy", 0.0, 0.4)
		tw.tween_callback(glow.queue_free)
		glow = null
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
		# faint gold rim on the lid, pulsing with the glow
		var ga := 0.35 + 0.2 * sin(t * 1.8)
		var lid := PackedVector2Array()
		for p in [Vector2(-half.x - 1, -half.y - 1), Vector2(half.x + 1, -half.y - 1), Vector2(half.x + 1, half.y + 1), Vector2(-half.x - 1, half.y + 1), Vector2(-half.x - 1, -half.y - 1)]:
			lid.append(Iso.to_screen(p) - Vector2(0, 21))
		cv.draw_polyline(lid, Color(1.0, 0.8, 0.35, ga), 1.5)
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
