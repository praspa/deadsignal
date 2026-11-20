class_name LandingBeacon
extends Node2D
## Uplink beacon (Diablo's waypoint): reaching it links this zone as a landing
## point of its star map destination, permanently (flag "beacon:<location>").
## Afterwards Descend on the star map can drop the operative straight here.

const RANGE := 110.0

var zone := ""
var t := 0.0
var cv: IsoView
var light: PointLight2D


func _ready() -> void:
	add_to_group("landing_beacon")
	cv = IsoView.attach(self)
	light = PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.energy = 0.7
	light.texture_scale = 1.2
	light.scale = Vector2(1.0, 0.6)
	light.position = Vector2(0, -30)
	cv.add_child(light)


func linked() -> bool:
	return GameState.has_flag("beacon:" + zone)


func _process(delta: float) -> void:
	t += delta
	light.color = Color(0.4, 0.8, 1.0) if linked() else Color(1.0, 0.35, 0.2)
	if linked():
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and not bool(p.get("dead")) and p.global_position.distance_to(global_position) < RANGE:
		GameState.set_flag("beacon:" + zone)
		Fx.ring(get_parent(), Iso.sp(global_position, 6), 90.0, Color(0.5, 0.85, 1.0), 0.6, 8.0)
		Audio.play("terminal", global_position, 0.8)
		Events.msg("Landing beacon linked: %s. You can now descend here from the star map." % GameState.location_name(zone), Color(0.5, 0.85, 1.0))


func _render() -> void:
	var on := linked()
	var glow := Color(0.4, 0.8, 1.0) if on else Color(1.0, 0.35, 0.2)
	var blink := 0.5 + 0.5 * sin(t * (3.0 if on else 7.0))
	# tripod mast with a small dish, status light on top
	Iso.ground(cv)
	cv.draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.35))
	cv.draw_arc(Vector2.ZERO, 16.0, 0, TAU, 20, Color(glow.r, glow.g, glow.b, 0.3 + 0.3 * blink), 1.5)
	cv.draw_set_transform(Vector2.ZERO)
	for a in [-0.8, 0.0, 0.8]:
		cv.draw_line(Vector2(sin(a) * 10.0, 2), Vector2(0, -30), Color(0.45, 0.48, 0.52), 1.5)
	cv.draw_line(Vector2(0, -30), Vector2(0, -42), Color(0.55, 0.58, 0.62), 2.0)
	cv.draw_arc(Vector2(4, -38), 7.0, -PI * 0.6, PI * 0.6, 10, Color(0.65, 0.68, 0.72), 2.0)
	cv.draw_circle(Vector2(0, -44), 2.5, Color(glow.r, glow.g, glow.b, 0.4 + 0.6 * blink))
