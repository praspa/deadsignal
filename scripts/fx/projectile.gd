class_name Projectile
extends Node2D
## Ray-swept projectile: moves each physics frame and raycasts the travelled
## segment so fast rounds never tunnel through thin targets.

var velocity := Vector2.ZERO
var hit: Dictionary = {}
var mask := Combat.LAYER_WORLD
var max_dist := 600.0
var travelled := 0.0
var color := Color(1.0, 0.8, 0.4)
var thickness := 2.0
var length := 14.0
var explode_radius := 0.0        # > 0 => AOE on impact
var explode_mask := 0
var exclude: Array[RID] = []
var glow := false
var draw_offset := Vector2(0, -16)  # visual height above the ground-plane track
var cv: IsoView
var start_from: Variant = null   # first ray starts here (shooter body) so point-blank shots connect
var on_impact: Callable          # optional: called with the impact position (e.g. acid pools)
var pierce := 0                  # bodies it can pass through after hitting them (Gunline: Deadeye)


static func fire(parent: Node, from: Vector2, vel: Vector2, h: Dictionary, msk: int, dist: float, col: Color) -> Projectile:
	var p := Projectile.new()
	p.position = from
	p.velocity = vel
	p.hit = h
	p.mask = msk
	p.max_dist = dist
	p.color = col
	parent.add_child(p)
	p.cv = IsoView.attach(p)
	return p


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var from := global_position
	var to := from + step
	if start_from != null:
		from = start_from
		start_from = null
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
	var res := space.intersect_ray(q)
	if not res.is_empty():
		var col: Object = res["collider"]
		var pos: Vector2 = res["position"]
		if col != null and col.has_method("take_hit"):
			hit["dir"] = velocity.normalized()
			var landed: bool = col.take_hit(hit)
			if not landed:
				# evaded / invulnerable: let the round continue past this body
				exclude.append((col as CollisionObject2D).get_rid())
				global_position = to
				travelled += step.length()
				return
			Fx.burst(get_parent(), Iso.sp(pos) + draw_offset, color, 6, 140.0, -velocity.normalized(), 0.9)
			if pierce > 0:
				pierce -= 1
				exclude.append((col as CollisionObject2D).get_rid())
				hit = hit.duplicate()
				global_position = to
				travelled += step.length()
				return
		else:
			Fx.burst(get_parent(), Iso.sp(pos) + draw_offset, Color(1.0, 0.75, 0.35), 5, 120.0, (res["normal"] as Vector2), 1.0, 1.6)
		_impact(pos)
		return
	global_position = to
	travelled += step.length()
	if travelled >= max_dist:
		_impact(global_position)
	queue_redraw()


func _impact(pos: Vector2) -> void:
	if on_impact.is_valid():
		on_impact.call(pos)
	if explode_radius > 0.0:
		Fx.ring(get_parent(), Iso.sp(pos), explode_radius, Color(1.0, 0.45, 0.1), 0.45, 10.0)
		Audio.play("explosion", pos)
		Fx.burst(get_parent(), Iso.sp(pos), Color(1.0, 0.6, 0.2), 18, 260.0)
		var tree := get_tree()
		for group in ["player", "enemies"]:
			if (group == "player" and (explode_mask & Combat.LAYER_PLAYER) == 0) or (group == "enemies" and (explode_mask & Combat.LAYER_ENEMY) == 0):
				continue
			for n in tree.get_nodes_in_group(group):
				var a := n as Node2D
				if a == null:
					continue
				var d := a.global_position.distance_to(pos)
				if d <= explode_radius:
					var h := hit.duplicate()
					h["amount"] = float(hit["amount"]) * (1.0 - 0.5 * d / explode_radius)
					h["dir"] = (a.global_position - pos).normalized()
					h["knockback"] = 220.0
					a.call("take_hit", h)
		Events.screen_shake.emit(6.0)
	queue_free()


func _render() -> void:
	var o := draw_offset
	var sdir := Iso.dir(velocity).normalized()
	var tail := o - sdir * length
	if glow:
		var g := color
		g.a = 0.3
		cv.draw_line(tail, o, g, thickness * 4.0)
		cv.draw_circle(o, thickness * 2.2, g)
	cv.draw_line(tail, o, color, thickness)
	cv.draw_circle(o, thickness * 0.8, Color(1, 1, 0.9))
