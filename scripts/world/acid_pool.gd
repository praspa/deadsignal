class_name AcidPool
extends Node2D
## A pool of brood acid on the floor: burns the operative standing in it
## (damage over time, chance of toxin) and fades after a few seconds.

var radius := 34.0
var dps := 6.0
var life := 3.0
var age := 0.0
var tick := 0.0
var cv: IsoView


static func spawn(parent: Node, pos: Vector2, r: float, p_dps: float, p_life: float) -> AcidPool:
	var a := AcidPool.new()
	a.position = pos
	a.radius = r
	a.dps = p_dps
	a.life = p_life
	parent.add_child(a)
	return a


func _ready() -> void:
	add_to_group("acid")
	cv = IsoView.attach(self)
	cv.z_index = -1
	Fx.burst(get_parent(), Iso.sp(global_position, 4), Color(0.55, 0.9, 0.2), 10, 120.0)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	tick -= delta
	if tick <= 0.0:
		tick = 0.5
		var p := get_tree().get_first_node_in_group("player") as Actor
		if p != null and not p.dead and p.global_position.distance_to(global_position) < radius:
			var h := Combat.make_hit(dps * 0.5, null, false)
			h["dot"] = true
			h["status"] = "toxin"
			h["status_chance"] = 0.25
			h["color"] = Color(0.55, 0.9, 0.2)
			p.take_hit(h)


func _render() -> void:
	var fade := clampf((life - age) / 0.6, 0.0, 1.0)
	Iso.ground(cv)
	cv.draw_circle(Vector2.ZERO, radius, Color(0.25, 0.45, 0.05, 0.45 * fade))
	cv.draw_circle(Vector2(-4, -3), radius * 0.6, Color(0.5, 0.85, 0.15, 0.35 * fade))
	for i in 4:
		var a := age * 2.0 + i * 1.6
		cv.draw_circle(Vector2(cos(a) * radius * 0.5, sin(a * 1.3) * radius * 0.4), 2.5, Color(0.8, 1.0, 0.4, 0.6 * fade))
	cv.draw_set_transform(Vector2.ZERO)
