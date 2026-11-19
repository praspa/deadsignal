class_name Enemy
extends Actor
## Data-driven enemy. Archetype stats come from data/enemies.json; behaviour
## is a small state machine: IDLE -> CHASE -> TELEGRAPH -> ATTACK -> RECOVER.

enum S { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVER }

var kind := "drone"
var def: Dictionary = {}
var spawn_id := ""
var display_name := ""
var radius := 12.0
var speed := 100.0
var state: int = S.IDLE
var state_t := 0.0
var attack_cd := 0.0
var aggro := false
var target: Node2D = null
var level: Node = null
var path := PackedVector2Array()
var path_i := 0
var path_t := 0.0
var perceive_t := 0.0
var has_los := false
var facing := 0.0
var anim_t := 0.0
var telegraph_target := Vector2.ZERO
var attack_variant := ""
var strafe_dir := 1.0
var show_bar_t := 0.0
var home := Vector2.ZERO
var wander_to := Vector2.ZERO
var wander_t := 0.0
var lunge_dir := Vector2.ZERO
var lunge_hit_done := false
var burst_left := 0
var burst_t := 0.0
var dead_t := 0.0
var voice_t := randf_range(1.5, 7.0)
var _shape: CollisionShape2D


func setup(p_kind: String, p_level: Node, p_spawn_id: String) -> void:
	kind = p_kind
	level = p_level
	spawn_id = p_spawn_id
	def = ItemDB.enemies.get(kind, {})
	display_name = String(def.get("name", kind))
	max_hp = float(def.get("hp", 50))
	hp = max_hp
	armor = float(def.get("armor", 0))
	radius = float(def.get("radius", 12))
	speed = float(def.get("speed", 100))


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Combat.LAYER_ENEMY
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY | Combat.LAYER_PLAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_shape = CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	_shape.shape = c
	add_child(_shape)
	cv = IsoView.attach(self)
	home = global_position
	wander_to = home
	anim_t = randf() * 10.0
	strafe_dir = 1.0 if randf() < 0.5 else -1.0
	facing = randf() * TAU


func _physics_process(delta: float) -> void:
	anim_t += delta
	if dead:
		dead_t += delta
		if dead_t < 1.0:
			queue_redraw()
		return
	flash = maxf(0.0, flash - delta)
	show_bar_t = maxf(0.0, show_bar_t - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	process_statuses(delta)
	if dead:
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
	voice_t -= delta
	if voice_t <= 0.0:
		voice_t = randf_range(2.5, 5.5) if aggro else randf_range(5.0, 11.0)
		_voice()
	perceive_t -= delta
	if perceive_t <= 0.0:
		perceive_t = 0.2 + randf() * 0.05
		_perceive()
	if is_stunned():
		if state == S.TELEGRAPH or state == S.ATTACK:
			state = S.RECOVER
			state_t = 0.4
		velocity = apply_knockback(delta)
		move_and_slide()
		queue_redraw()
		return
	_think(delta)
	velocity = velocity * slow_factor() + apply_knockback(delta)
	move_and_slide()
	queue_redraw()


# ---------------------------------------------------------------- perception

func _target_alive() -> bool:
	return target != null and is_instance_valid(target) and not bool(target.get("dead"))


func _perceive() -> void:
	if not _target_alive():
		has_los = false
		if aggro:
			aggro = false
			state = S.IDLE
		return
	var d := global_position.distance_to(target.global_position)
	has_los = d < 900.0 and _los_to(target.global_position)
	if not aggro and ((d < float(def.get("detect", 350)) and has_los) or d < 70.0):
		become_aggro()


func _los_to(p: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -8), p + Vector2(0, -8), Combat.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func become_aggro() -> void:
	if aggro or dead:
		return
	aggro = true
	if kind == "researcher":
		Audio.play("zombie_snarl", global_position)
	else:
		Audio.play("robot_alert", global_position, _voice_pitch())
	state = S.CHASE
	attack_cd = randf_range(0.2, 0.8)
	Fx.text(get_parent(), Iso.sp(global_position, 56), "!", Color(1.0, 0.25, 0.2), 1.4)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and (e as Node2D).global_position.distance_to(global_position) < 260.0:
			e.call_deferred("become_aggro")


func interrupt() -> void:
	if state == S.TELEGRAPH or state == S.ATTACK:
		state = S.RECOVER
		state_t = 0.8
		burst_left = 0
		Fx.text(get_parent(), Iso.sp(global_position, 60), "INTERRUPTED", Color(0.6, 0.85, 1.0), 0.85)


# ---------------------------------------------------------------- behaviour

func _think(delta: float) -> void:
	velocity = Vector2.ZERO
	match state:
		S.IDLE:
			_idle(delta)
		S.CHASE:
			_chase(delta)
		S.TELEGRAPH:
			state_t -= delta
			_face_toward(target.global_position if _target_alive() else telegraph_target, delta)
			if _target_alive() and state_t > float(def.get("telegraph", 0.5)) * 0.3:
				telegraph_target = target.global_position
			if kind == "drone":
				velocity = Vector2.from_angle(facing).orthogonal() * strafe_dir * speed * 0.25
			if state_t <= 0.0:
				_begin_attack()
		S.ATTACK:
			_attack_step(delta)
		S.RECOVER:
			state_t -= delta
			if kind == "drone" and _target_alive():
				velocity = (global_position - target.global_position).normalized().orthogonal() * strafe_dir * speed * 0.6
			if state_t <= 0.0:
				state = S.CHASE
				attack_cd = float(def.get("cooldown", 1.0)) * randf_range(0.75, 1.25)


func _idle(delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(1.5, 4.0)
		wander_to = home + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	var to := wander_to - global_position
	if to.length() > 6.0:
		velocity = to.normalized() * speed * 0.3
		_face_toward(wander_to, delta)


func _chase(delta: float) -> void:
	if not _target_alive():
		state = S.IDLE
		return
	var tp := target.global_position
	var to := tp - global_position
	var d := to.length()
	_face_toward(tp, delta)
	if has_los and d <= float(def.get("attack_range", 100)) and attack_cd <= 0.0:
		_start_telegraph()
		return
	var keep := float(def.get("keep_distance", 0))
	if has_los:
		var dir := to / maxf(d, 0.001)
		if keep > 0.0 and d < keep * 0.8:
			velocity = (-dir + dir.orthogonal() * strafe_dir * 0.8).normalized() * speed * 0.8
		elif keep > 0.0 and d < keep * 1.15:
			velocity = dir.orthogonal() * strafe_dir * speed * 0.7
			if randf() < 0.01:
				strafe_dir = -strafe_dir
		else:
			velocity = dir * speed
		path = PackedVector2Array()
	else:
		path_t -= delta
		if path_t <= 0.0 or path_i >= path.size():
			path_t = 0.6
			path = level.call("find_path", global_position, tp)
			path_i = 1
		if path_i < path.size():
			var wp := path[path_i]
			var tw := wp - global_position
			if tw.length() < 12.0:
				path_i += 1
			velocity = tw.normalized() * speed
		else:
			velocity = to.normalized() * speed


func _face_toward(p: Vector2, delta: float) -> void:
	var want := (p - global_position).angle()
	var tr := float(def.get("turn_rate", 0.0))
	if tr > 0.0:
		facing = rotate_toward(facing, want, tr * delta)
	else:
		facing = want


func _start_telegraph() -> void:
	state = S.TELEGRAPH
	state_t = float(def.get("telegraph", 0.5))
	telegraph_target = target.global_position
	attack_variant = String(def.get("attack", ""))
	if kind == "heavy":
		var d := global_position.distance_to(target.global_position)
		attack_variant = "grenade" if (d > 180.0 and randf() < 0.4) else "burst"
		if attack_variant == "grenade":
			state_t *= 1.15


func _begin_attack() -> void:
	state = S.ATTACK
	state_t = 0.0
	match attack_variant:
		"bolt":
			_shoot(telegraph_target, Color(1.0, 0.2, 0.15), 3.0)
			_end_attack()
		"lunge":
			Audio.play("zombie_snarl", global_position, 1.1)
			lunge_dir = (telegraph_target - global_position).normalized()
			facing = lunge_dir.angle()
			lunge_hit_done = false
			state_t = 0.3
		"burst":
			burst_left = 5
			burst_t = 0.0
		"grenade":
			var p := Projectile.fire(get_parent(), global_position, (telegraph_target - global_position).normalized() * 420.0,
				_make_hit(def.get("grenade_dmg", [25, 35])), Combat.LAYER_WORLD, global_position.distance_to(telegraph_target), Color(1.0, 0.55, 0.15))
			p.explode_radius = float(def.get("grenade_radius", 75))
			Audio.play("grenade_launch", global_position)
			p.explode_mask = Combat.LAYER_PLAYER
			p.thickness = 5.0
			p.length = 6.0
			p.glow = true
			p.draw_offset = Vector2(0, -24)
			_end_attack()
		_:
			_end_attack()


func _attack_step(delta: float) -> void:
	match attack_variant:
		"lunge":
			state_t -= delta
			velocity = lunge_dir * float(def.get("lunge_speed", 450))
			if not lunge_hit_done and _target_alive() and global_position.distance_to(target.global_position) < radius + 22.0:
				lunge_hit_done = true
				var h := _make_hit(def.get("dmg", [10, 15]))
				h["status"] = def.get("status", "")
				h["status_chance"] = float(def.get("status_chance", 0.0))
				h["dir"] = lunge_dir
				h["knockback"] = 120.0
				target.call("take_hit", h)
				Fx.slash(get_parent(), Iso.sp(global_position, 14), lunge_dir.angle(), 26.0, 1.6, Color(0.6, 1.0, 0.3))
			if state_t <= 0.0:
				_end_attack()
		"burst":
			burst_t -= delta
			if burst_t <= 0.0 and burst_left > 0:
				burst_left -= 1
				burst_t = 0.09
				if _target_alive():
					telegraph_target = telegraph_target.lerp(target.global_position, 0.25)
				_shoot(telegraph_target, Color(1.0, 0.7, 0.2), 4.0, 0.12)
			if burst_left <= 0:
				_end_attack()
		_:
			_end_attack()


func _end_attack() -> void:
	state = S.RECOVER
	state_t = float(def.get("recover", 0.5))
	if randf() < 0.3:
		strafe_dir = -strafe_dir


func _make_hit(range_arr) -> Dictionary:
	var lo := float(range_arr[0])
	var hi := float(range_arr[1])
	var h := Combat.make_hit(randf_range(lo, hi), self, false)
	return h


func _shoot(at: Vector2, col: Color, thick: float, spread: float = 0.04) -> void:
	var from := global_position + Vector2.from_angle(facing) * radius
	var dir := (at - from).normalized().rotated(randf_range(-spread, spread))
	var p := Projectile.fire(get_parent(), from, dir * float(def.get("projectile_speed", 400)), _make_hit(def.get("dmg", [8, 12])),
		Combat.LAYER_WORLD | Combat.LAYER_PLAYER, 900.0, col)
	p.start_from = global_position
	p.exclude = [get_rid()]
	p.draw_offset = Vector2(0, -24 if kind == "heavy" else -26)
	Audio.play("heavy_shot" if kind == "heavy" else "enemy_bolt", global_position)
	p.thickness = thick
	p.glow = true
	p.length = 12.0


# ---------------------------------------------------------------- damage

func _modify_incoming(amount: float, hit: Dictionary) -> float:
	var fs := float(def.get("front_shield", 0.0))
	if fs > 0.0 and not is_stunned() and not hit.get("dot", false):
		var dir: Vector2 = hit.get("dir", Vector2.ZERO)
		if dir != Vector2.ZERO and Vector2.from_angle(facing).dot(-dir) > 0.35:
			Fx.burst(get_parent(), Iso.sp(global_position + Vector2.from_angle(facing) * (radius + 6), 20), Color(1.0, 0.85, 0.4), 6, 160.0, -dir, 0.8, 1.5)
			Audio.play("impact_metal", global_position, 1.3)
			if randf() < 0.25:
				Fx.text(get_parent(), Iso.sp(global_position, 64), "SHIELDED", Color(0.75, 0.75, 0.75), 0.8)
			return amount * fs
	return amount


func _on_damaged(hit: Dictionary, _amount: float) -> void:
	show_bar_t = 4.0
	if not aggro:
		become_aggro()
	if not hit.get("dot", false):
		var dir: Vector2 = hit.get("dir", Vector2.ZERO)
		if kind == "researcher":
			Audio.play("impact_flesh", global_position)
			if randf() < 0.5:
				Audio.play("zombie_hurt", global_position)
		else:
			Audio.play("impact_metal", global_position, 0.8 if kind == "heavy" else 1.0)
			if randf() < 0.35:
				Audio.play("robot_hurt", global_position, _voice_pitch())
		if kind == "drone":
			Fx.burst(get_parent(), Iso.sp(global_position, 26), Color(1.0, 0.8, 0.3), 5, 150.0, dir, 0.9, 1.5)
		elif kind == "researcher":
			Fx.blood(get_parent(), Iso.sp(global_position, 16), dir, Color(0.3, 0.5, 0.08))
		else:
			Fx.burst(get_parent(), Iso.sp(global_position, 22), Color(1.0, 0.75, 0.35), 5, 140.0, dir, 0.9, 1.5)


func die() -> void:
	if dead:
		return
	super.die()
	remove_from_group("enemies")
	state = S.IDLE
	velocity = Vector2.ZERO
	_shape.set_deferred("disabled", true)
	cv.z_index = -1
	if spawn_id != "":
		GameState.set_flag(GameState.area_flag("k:" + spawn_id))
	GameState.add_xp(int(def.get("xp", 10)))
	Fx.text(get_parent(), Iso.sp(global_position, 50), "+%d XP" % int(def.get("xp", 10)), Color(0.7, 0.6, 1.0), 0.85)
	if kind == "researcher":
		Audio.play("zombie_death", global_position)
	else:
		Audio.play("robot_death", global_position, _voice_pitch())
	if kind == "drone":
		Fx.burst(get_parent(), Iso.sp(global_position, 24), Color(1.0, 0.6, 0.2), 16, 220.0)
	else:
		Fx.blood(get_parent(), Iso.sp(global_position, 12), Vector2.UP, Color(0.35, 0.03, 0.02) if kind != "researcher" else Color(0.25, 0.4, 0.05))
	if level != null:
		level.call("enemy_loot", global_position, def)


# ---------------------------------------------------------------- sound

## Robots get deeper as they get bigger.
func _voice_pitch() -> float:
	return {"heavy": 0.72, "boss": 0.5}.get(kind, 1.0)


## Idle noise: researchers groan, machines chatter. Only when the player is near.
func _voice() -> void:
	if target == null or global_position.distance_to(target.global_position) > 650.0:
		return
	if kind == "researcher":
		Audio.play("zombie_groan", global_position, randf_range(0.9, 1.1))
	else:
		Audio.play("robot_chatter", global_position, _voice_pitch())


# ---------------------------------------------------------------- drawing

func _col(c: Color) -> Color:
	if flash > 0.0:
		return c.lerp(Color.WHITE, 0.75)
	return c


## Called by the IsoView; see Player._render().
func _render() -> void:
	var wf := facing
	facing = Iso.angle(wf)
	_render_body()
	facing = wf


func _render_body() -> void:
	match kind:
		"drone":
			_draw_drone()
		"researcher":
			_draw_researcher()
		"heavy":
			_draw_heavy()
	if not dead:
		_draw_overlay()


func _draw_overlay() -> void:
	var sc := status_color()
	if sc.a > 0.0:
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		cv.draw_arc(Vector2.ZERO, radius + 6.0, 0, TAU, 24, Color(sc.r, sc.g, sc.b, 0.75), 2.0)
		cv.draw_set_transform(Vector2.ZERO)
	if is_stunned():
		var top := _top()
		for i in 3:
			var a := anim_t * 5.0 + i * TAU / 3.0
			cv.draw_circle(Vector2(cos(a) * 12.0, top - 6 + sin(a) * 4.0), 2.0, Color(1, 1, 0.6))
	if show_bar_t > 0.0 or hp < max_hp:
		var top2 := _top() - 10.0
		var w := 34.0 + radius
		cv.draw_rect(Rect2(-w * 0.5 - 1, top2 - 1, w + 2, 6), Color(0, 0, 0, 0.8))
		cv.draw_rect(Rect2(-w * 0.5, top2, w * hp / max_hp, 4), Color(0.75, 0.1, 0.08))


func _top() -> float:
	return {"drone": -44.0, "researcher": -42.0, "heavy": -58.0}.get(kind, -50.0)


func _shadow(r: float, a: float = 0.45) -> void:
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	cv.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, a))
	cv.draw_set_transform(Vector2.ZERO)


func _draw_drone() -> void:
	if dead:
		var f := minf(dead_t * 3.0, 1.0)
		var p := Vector2(0, lerpf(-26.0, -4.0, f))
		cv.draw_circle(p, 8.0, Color(0.35, 0.32, 0.28))
		cv.draw_circle(p + Vector2(3, -2), 2.0, Color(0.1, 0.05, 0.05))
		cv.draw_line(p + Vector2(-10, 4), p + Vector2(10, -3), Color(0.25, 0.2, 0.15), 2.0)
		return
	var bob := sin(anim_t * 4.0) * 3.0
	_shadow(10.0, 0.35)
	var c := Vector2(0, -26 + bob)
	var tele := state == S.TELEGRAPH
	# rotor / suspensor fins
	var spin := anim_t * 30.0
	for side in [-1.0, 1.0]:
		var hub := c + Vector2(side * 13.0, -2.0)
		cv.draw_line(c + Vector2(side * 6.0, 0), hub, _col(Color(0.3, 0.25, 0.15)), 2.0)
		cv.draw_set_transform(hub, 0.0, Vector2(1.0, 0.35))
		cv.draw_arc(Vector2.ZERO, 7.0, spin, spin + 2.0, 6, Color(0.6, 0.6, 0.6, 0.5), 1.5)
		cv.draw_set_transform(Vector2.ZERO)
	# brass halo frame
	cv.draw_arc(c, 12.0, PI * 1.1, PI * 1.9, 12, _col(Color(0.4, 0.33, 0.19)), 2.5)
	# skull
	Shade.ball(cv, c, 9.0, _col(Color(0.6, 0.57, 0.5)))
	cv.draw_rect(Rect2(c.x - 5, c.y + 5, 10, 5), _col(Color(0.62, 0.57, 0.47)))
	for i in 4:
		cv.draw_line(Vector2(c.x - 4 + i * 2.6, c.y + 6), Vector2(c.x - 4 + i * 2.6, c.y + 10), Color(0.2, 0.18, 0.15), 1.0)
	var look := Vector2.from_angle(facing) * 2.0
	cv.draw_circle(c + Vector2(-3.5, -1) + look, 2.6, Color(0.08, 0.06, 0.05))
	var eye_r := 3.0 + (2.5 * (1.0 - state_t / maxf(0.01, float(def.get("telegraph", 0.5)))) if tele else 0.0)
	var eye_c := Color(1.0, 0.15, 0.1)
	cv.draw_circle(c + Vector2(3.5, -1) + look, eye_r + 3.0, Color(1.0, 0.1, 0.05, 0.25))
	cv.draw_circle(c + Vector2(3.5, -1) + look, eye_r, eye_c)
	cv.draw_line(c + Vector2(0, -9), c + Vector2(-3, -17), Color(0.4, 0.35, 0.25), 1.5)
	cv.draw_circle(c + Vector2(-3, -17), 1.5, Color(1.0, 0.3, 0.1) if int(anim_t * 3.0) % 2 == 0 else Color(0.3, 0.1, 0.05))
	if tele:
		var to := Iso.rel(telegraph_target, global_position) + Vector2(0, -16) - c
		cv.draw_line(c, c + to.limit_length(400.0), Color(1.0, 0.1, 0.05, 0.35), 1.0)


func _draw_researcher() -> void:
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	if dead:
		var f := minf(dead_t * 2.5, 1.0)
		cv.draw_set_transform(Vector2(0, -4), PI * 0.5 * f * fx, Vector2.ONE)
		cv.draw_rect(Rect2(-6, -22, 12, 22), Color(0.55, 0.53, 0.47))
		cv.draw_circle(Vector2(0, -25), 5.0, Color(0.6, 0.55, 0.48))
		cv.draw_set_transform(Vector2.ZERO)
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45))
		cv.draw_circle(Vector2(6 * fx, 0), 14.0 * f, Color(0.2, 0.32, 0.05, 0.6))
		cv.draw_set_transform(Vector2.ZERO)
		return
	_shadow(12.0)
	var tele := state == S.TELEGRAPH
	var lunging := state == S.ATTACK
	var sway := sin(anim_t * 7.0) * 2.0
	var shake := Vector2(randf_range(-1.5, 1.5), 0) if tele else Vector2.ZERO
	var hunch := 6.0 if not lunging else 12.0
	var walk := sin(anim_t * 14.0) * 4.0 if velocity.length() > 20 else 0.0
	# legs
	cv.draw_line(Vector2(-3, -12), Vector2(-4 + walk * 0.5, 0), _col(Color(0.2, 0.18, 0.16)), 3.0)
	cv.draw_line(Vector2(3, -12), Vector2(4 - walk * 0.5, 0), _col(Color(0.2, 0.18, 0.16)), 3.0)
	# lab coat (stained, torn)
	var top := Vector2(hunch * fx, -30) + shake
	var coat := PackedVector2Array([top + Vector2(-7, 0), top + Vector2(7, 0), Vector2(9, -10), Vector2(5 + sway, -6), Vector2(1, -11), Vector2(-4 - sway, -6), Vector2(-9, -10)])
	Shade.poly(cv, coat, _col(Color(0.5, 0.48, 0.42)))
	cv.draw_line(top + Vector2(-2, 6), Vector2(-3, -12), Color(0.38, 0.06, 0.04, 0.8), 3.0)  # blood streak
	cv.draw_line(top + Vector2(3, 3), Vector2(6, -13), Color(0.3, 0.42, 0.1, 0.7), 2.0)
	# mutated arm (oversized) toward facing
	var shoulder := top + Vector2(5 * fx, 3)
	var reach := 18.0 if not lunging else 26.0
	var arm_ang := facing + (-0.9 if tele else 0.3) * fx
	var elbow := shoulder + Vector2.from_angle(arm_ang) * reach * 0.55 + Vector2(0, 4)
	var hand := elbow + Vector2.from_angle(arm_ang + 0.4 * fx) * reach * 0.6
	Shade.limb(cv, shoulder, elbow, 5.0, _col(Color(0.62, 0.52, 0.48)))
	Shade.limb(cv, elbow, hand, 4.5, _col(Color(0.62, 0.5, 0.45)))
	cv.draw_line(shoulder, hand, Color(0.4, 0.95, 0.3, 0.6), 1.0)  # glowing veins
	for i in 3:
		var ca := arm_ang + (float(i) - 1.0) * 0.45
		cv.draw_line(hand, hand + Vector2.from_angle(ca) * 8.0, _col(Color(0.85, 0.82, 0.7)), 1.5)
	# withered other arm
	cv.draw_line(top + Vector2(-5 * fx, 3), top + Vector2(-8 * fx, 14), _col(Color(0.6, 0.52, 0.48)), 3.0)
	# head (pale, bulging, jutting forward)
	var head := top + Vector2(4 * fx, -6)
	Shade.ball(cv, head, 6.5, _col(Color(0.62, 0.58, 0.51)))
	cv.draw_circle(head + Vector2(-3 * fx, -3), 3.5, _col(Color(0.65, 0.55, 0.5)))  # growth
	var eye_col := Color(1.0, 0.2, 0.1) if tele else Color(0.6, 1.0, 0.3)
	cv.draw_circle(head + Vector2(3 * fx, -1), 1.6, eye_col)
	cv.draw_circle(head + Vector2(0.5 * fx, -1.5), 1.3, eye_col)
	cv.draw_line(head + Vector2(1 * fx, 3), head + Vector2(5 * fx, 2.5), Color(0.15, 0.05, 0.05), 1.5)
	if tele:
		cv.draw_circle(head, 12.0, Color(1.0, 0.1, 0.05, 0.18))


func _draw_heavy() -> void:
	if dead:
		cv.draw_set_transform(Vector2(0, -6), facing, Vector2(1, 0.7))
		cv.draw_rect(Rect2(-18, -14, 36, 28), Color(0.16, 0.17, 0.19))
		cv.draw_rect(Rect2(12, -16, 6, 32), Color(0.35, 0.3, 0.15))
		cv.draw_set_transform(Vector2.ZERO)
		return
	_shadow(21.0, 0.5)
	var tele := state == S.TELEGRAPH
	var walk := sin(anim_t * 6.0) * 3.0 if velocity.length() > 10 else 0.0
	Shade.rect(cv, Rect2(-11, -16 + walk * 0.4, 8, 16 - walk * 0.4), _col(Color(0.14, 0.14, 0.15)))
	Shade.rect(cv, Rect2(3, -16 - walk * 0.4, 8, 16 + walk * 0.4), _col(Color(0.11, 0.11, 0.12)))
	cv.draw_rect(Rect2(-12, -5, 10, 5), _col(Color(0.08, 0.08, 0.09)))
	cv.draw_rect(Rect2(2, -5, 10, 5), _col(Color(0.08, 0.08, 0.09)))
	cv.draw_set_transform(Vector2(0, -28), facing, Vector2(1.0, 0.8))
	var body := Color(0.19, 0.2, 0.22)
	# armored torso
	Shade.rect(cv, Rect2(-18, -15, 30, 30), _col(body))
	cv.draw_rect(Rect2(-24, -10, 7, 20), _col(Color(0.1, 0.1, 0.11)))  # power plant
	# shoulder plates
	Shade.ball(cv, Vector2(-4, -16), 9.0, _col(Color(0.25, 0.26, 0.28)))
	Shade.ball(cv, Vector2(-4, 16), 9.0, _col(Color(0.25, 0.26, 0.28)))
	# heavy cannon on right
	cv.draw_rect(Rect2(0, 8, 32, 8), _col(Color(0.09, 0.09, 0.1)))
	cv.draw_rect(Rect2(6, 6, 12, 12), _col(Color(0.25, 0.25, 0.27)))
	cv.draw_circle(Vector2(32, 12), 3.5, Color(1.0, 0.4, 0.1) if tele else Color(0.15, 0.1, 0.08))
	# front shield plate with hazard chevrons
	var shield_c := Color(0.42, 0.36, 0.17) if not is_stunned() else Color(0.22, 0.2, 0.14)
	cv.draw_arc(Vector2(-2, 0), 22.0, -0.9, 0.9, 12, _col(shield_c), 7.0)
	for i in 4:
		var a := -0.7 + i * 0.47
		cv.draw_line(Vector2.from_angle(a) * 19.0 + Vector2(-2, 0), Vector2.from_angle(a + 0.15) * 25.0 + Vector2(-2, 0), Color(0.08, 0.08, 0.08), 2.5)
	# head with triple lenses
	cv.draw_circle(Vector2(2, 0), 7.5, _col(Color(0.16, 0.17, 0.19)))
	for i in 3:
		cv.draw_circle(Vector2(7, -3.5 + i * 3.5), 1.4, Color(1.0, 0.15, 0.1))
	cv.draw_set_transform(Vector2.ZERO)
	if tele:
		var frac := 1.0 - state_t / maxf(0.01, float(def.get("telegraph", 0.9)))
		if attack_variant == "burst":
			var from := Vector2(0, -24) + Vector2.from_angle(facing) * 30.0
			var to := Iso.rel(telegraph_target, global_position) + Vector2(0, -16)
			cv.draw_line(from, from + (to - from).normalized() * 700.0, Color(1.0, 0.1, 0.05, 0.25 + frac * 0.5), 1.0 + frac * 2.0)
		else:
			var gp := Iso.rel(telegraph_target, global_position)
			var r := float(def.get("grenade_radius", 75))
			Iso.ground(cv, gp)
			cv.draw_circle(Vector2.ZERO, r * frac, Color(1.0, 0.3, 0.05, 0.18))
			cv.draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1.0, 0.3, 0.05, 0.7), 2.0)
			cv.draw_set_transform(Vector2.ZERO)
