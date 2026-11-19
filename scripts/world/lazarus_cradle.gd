class_name LazarusCradle
extends StaticBody2D
## Regeneration pod in the ship's medbay. When the operative dies on a mission
## they wake here (see Game._wake_in_cradle). Talking to it just describes it.

var interact_radius := 60.0
var t := 0.0
var cv: IsoView


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cradle")
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 28)
	cs.shape = r
	add_child(cs)
	cv = IsoView.attach(self)
	var light := PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.color = Color(0.35, 1.0, 0.7)
	light.energy = 0.7
	light.texture_scale = 1.1
	light.scale = Vector2(1.0, 0.6)
	light.position = Vector2(0, -24)
	cv.add_child(light)


func interact_text() -> String:
	return "Inspect the Lazarus Cradle"


func interact(_player: Node) -> void:
	Events.msg("The Lazarus Cradle. If you die out there, your suit's bio-link drags you back here. It costs creds and a little of what you've learned.", Color(0.5, 1.0, 0.75))


func _process(delta: float) -> void:
	t += delta


func _render() -> void:
	var metal := Color(0.32, 0.36, 0.42)
	# plinth
	Iso.box(cv, Vector2.ZERO, Vector2(13, 13), 8.0, metal.lightened(0.15), metal, metal.darkened(0.35), Color(0.75, 0.8, 0.88))
	# glass tube with regen fluid and bubbles
	var bottom := -8.0
	var top := -50.0
	cv.draw_rect(Rect2(-10, top, 20, bottom - top), Color(0.15, 0.6, 0.45, 0.35))
	for i in 5:
		var y := bottom - fmod(t * 18.0 + i * 9.0, bottom - top)   # rises, wraps at the top
		cv.draw_circle(Vector2(-6 + i * 3, y), 1.2, Color(0.7, 1.0, 0.85, 0.6))
	cv.draw_line(Vector2(-10, top), Vector2(-10, bottom), Color(0.75, 0.9, 0.95, 0.5), 1.0)
	cv.draw_line(Vector2(10, top), Vector2(10, bottom), Color(0.75, 0.9, 0.95, 0.3), 1.0)
	cv.draw_line(Vector2(-6, top + 2), Vector2(-6, bottom - 4), Color(1, 1, 1, 0.25), 2.0)   # glass glint
	# cap and med-arm
	Iso.box(cv, Vector2.ZERO, Vector2(12, 12), 6.0, metal.lightened(0.2), metal.darkened(0.05), metal.darkened(0.3), Color(0, 0, 0, 0), 50.0)
	cv.draw_line(Vector2(10, -54), Vector2(20, -44), metal.lightened(0.1), 2.5)
	cv.draw_line(Vector2(20, -44), Vector2(14, -34), metal.lightened(0.1), 2.0)
	cv.draw_circle(Vector2(0, -59), 2.0, Color(0.4, 1.0, 0.7, 0.6 + 0.4 * sin(t * 3.0)))
