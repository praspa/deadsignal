class_name Boss
extends Enemy
## WARDEN: the facility's corrupted security intelligence.
## Phase 1: spiral barrage, sweeping laser, seismic slam.
## Phase 2 (<66%): + drone summons, bullet nova.
## Phase 3 (<33%): faster, double laser, triple slams.
## A Disruptor Pulse interrupts its current pattern and exposes the core (+50% damage).

var active := false
var pattern := ""
var pat_t := 0.0
var pat_step := 0
var fire_acc := 0.0
var spiral_ang := 0.0
var laser_ang := 0.0
var laser_from := 0.0
var laser_to := 0.0
var laser_dual := false
var laser_tick := 0.0
var slam_points: Array = []
var exposed_t := 0.0
var interrupt_cd := 0.0
var idle_t := 1.5
var phase := 1
var arena_rect := Rect2()
var last_pattern := ""
var death_seq := 0.0

const CORE_OFFSET := Vector2(0, -64)


func setup(p_kind: String, p_level: Node, p_spawn_id: String) -> void:
	super.setup(p_kind, p_level, p_spawn_id)


var core_light: PointLight2D


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	# the core's baleful glow lights the arena around it
	core_light = PointLight2D.new()
	core_light.texture = LightUtil.radial(256)
	core_light.texture_scale = 1.6
	core_light.color = Color(0.9, 0.2, 0.12)
	core_light.energy = 0.9
	core_light.height = 150.0
	core_light.range_item_cull_mask = 3
	core_light.position = CORE_OFFSET
	core_light.scale = Vector2(1.0, 0.6)
	cv.add_child(core_light)


func status_resist() -> float:
	return 0.6


func apply_status(sname: String, power: float = 1.0) -> void:
	if sname == "stun":
		return  # WARDEN cannot be stunned, only interrupted
	super.apply_status(sname, power)


## Screen-space position of the floating core (used for effects).
func core_pos() -> Vector2:
	return Iso.sp(global_position) + CORE_OFFSET + Vector2(0, sin(anim_t * 1.6) * 5.0)


func _physics_process(delta: float) -> void:
	anim_t += delta
	if core_light != null:
		var pulse := 0.85 + 0.15 * sin(anim_t * 6.0)
		core_light.energy = (0.0 if dead_t >= 2.4 else randf_range(0.3, 1.3)) if dead else pulse
		core_light.color = Color(0.4, 0.75, 1.0) if exposed_t > 0.0 else Color(0.9, 0.2 + 0.1 * float(phase - 1), 0.12)
	if dead:
		dead_t += delta
		_death_sequence(delta)
		queue_redraw()
		return
	flash = maxf(0.0, flash - delta)
	exposed_t = maxf(0.0, exposed_t - delta)
	interrupt_cd = maxf(0.0, interrupt_cd - delta)
	process_statuses(delta)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
	if not active:
		if _target_alive() and global_position.distance_to(target.global_position) < 560.0 and _los_to(target.global_position):
			_activate()
		queue_redraw()
		return
	if not _target_alive():
		pattern = ""
		queue_redraw()
		return
	var new_phase := 1
	if hp < max_hp * 0.33:
		new_phase = 3
	elif hp < max_hp * 0.66:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		Events.msg("[WARDEN] %s" % ["", "", "CONTAINMENT PROTOCOL ESCALATING.", "YOU WILL BE KEPT. YOU WILL BE KEPT. YOU WILL BE KEPT."][phase], Color(1.0, 0.3, 0.25))
		Audio.play_screen("boss_alarm", core_pos())
		Fx.ring(get_parent(), core_pos(), 220.0, Color(1.0, 0.25, 0.1), 0.6, 10.0)
		Events.screen_shake.emit(10.0)
	_move(delta)
	_run_pattern(delta)
	velocity += apply_knockback(delta) * 0.2
	move_and_slide()
	Events.boss_bar.emit(display_name, hp, max_hp, true)
	queue_redraw()


func _activate() -> void:
	active = true
	aggro = true
	idle_t = 1.6
	Events.boss_bar.emit(display_name, hp, max_hp, true)
	Events.msg("[WARDEN] INTRUDER. YOU HAVE HEARD THE SIGNAL. YOU WILL BE CONTAINED.", Color(1.0, 0.3, 0.25))
	Audio.play_screen("boss_alarm", core_pos())
	Audio.music("boss", 0.8)
	Events.screen_shake.emit(8.0)


func _move(_delta: float) -> void:
	var spd := speed * (1.6 if phase == 3 else 1.0)
	if pattern == "laser" or pattern == "spiral":
		spd *= 0.25
	var to := target.global_position - global_position
	var d := to.length()
	var keep := float(def.get("keep_distance", 220))
	var want := Vector2.ZERO
	if d > keep + 60.0:
		want = to.normalized()
	elif d < keep - 60.0:
		want = -to.normalized()
	else:
		want = to.normalized().orthogonal() * (1.0 if sin(anim_t * 0.4) > 0.0 else -1.0)
	velocity = want * spd
	if arena_rect.size != Vector2.ZERO:
		var p := global_position + velocity * 0.3
		if not arena_rect.has_point(p):
			velocity = (arena_rect.get_center() - global_position).normalized() * spd


func _pick_pattern() -> String:
	var options: Array = ["spiral", "laser", "slam"]
	if phase >= 2:
		options.append("nova")
		var drones := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e.get("kind") == "drone":
				drones += 1
		if drones < 3:
			options.append("summon")
	options.erase(last_pattern)
	return options[randi() % options.size()]


func _run_pattern(delta: float) -> void:
	if pattern == "":
		idle_t -= delta
		if idle_t <= 0.0:
			_start_pattern(_pick_pattern())
		return
	pat_t += delta
	match pattern:
		"spiral":
			if pat_t < 0.7:
				return
			fire_acc += delta
			var interval := 0.09 if phase == 1 else 0.07
			var arms := 2 + phase
			while fire_acc >= interval:
				fire_acc -= interval
				spiral_ang += 0.23 if phase < 3 else 0.3
				for i in arms:
					var a := spiral_ang + TAU * float(i) / float(arms)
					_bullet(a, 230.0 + 30.0 * phase, Color(1.0, 0.25, 0.15))
			if pat_t > 3.4:
				_end_pattern()
		"laser":
			var tele := 1.1
			if pat_t < tele:
				laser_ang = laser_from
				return
			if pat_step == 0:
				pat_step = 1
				Audio.play_screen("boss_laser", core_pos())
			var t := (pat_t - tele) / 1.7
			laser_ang = lerpf(laser_from, laser_to, clampf(t, 0.0, 1.0))
			laser_tick -= delta
			_laser_damage(laser_ang)
			if laser_dual:
				_laser_damage(laser_ang + PI)
			if t >= 1.0:
				_end_pattern()
		"slam":
			var tele2 := 1.0 if phase < 3 else 0.8
			if pat_step < slam_points.size() and pat_t >= tele2 + pat_step * 0.35:
				_slam(slam_points[pat_step])
				pat_step += 1
			if pat_step >= slam_points.size():
				_end_pattern()
		"nova":
			if pat_t >= 0.8 and pat_step == 0:
				pat_step = 1
				for i in 28:
					_bullet(TAU * i / 28.0, 200.0, Color(1.0, 0.55, 0.15))
			if pat_t >= 1.4 and pat_step == 1 and phase == 3:
				pat_step = 2
				for i in 28:
					_bullet(TAU * (i + 0.5) / 28.0, 240.0, Color(1.0, 0.55, 0.15))
			if pat_t >= 1.8:
				_end_pattern()
		"summon":
			if pat_t >= 0.9 and pat_step == 0:
				pat_step = 1
				Audio.play_screen("robot_chatter", core_pos(), 0.5)
				for i in 2:
					var off := Vector2.from_angle(randf() * TAU) * 70.0
					level.call("spawn_enemy", "drone", global_position + off, "")
				Fx.ring(get_parent(), core_pos(), 120.0, Color(1.0, 0.2, 0.2), 0.5, 6.0)
				Events.msg("[WARDEN] DEPLOYING SENTRIES.", Color(1.0, 0.3, 0.25))
			if pat_t >= 1.3:
				_end_pattern()


func _start_pattern(p: String) -> void:
	pattern = p
	last_pattern = p
	pat_t = 0.0
	pat_step = 0
	fire_acc = 0.0
	match p:
		"laser":
			Audio.play_screen("boss_charge", core_pos())
			var base := (target.global_position - global_position).angle()
			var sweep := 1.5 if phase < 3 else 1.9
			var dir := 1.0 if randf() < 0.5 else -1.0
			laser_from = base - sweep * 0.5 * dir
			laser_to = base + sweep * 0.5 * dir
			laser_dual = phase == 3
			laser_tick = 0.0
		"slam":
			slam_points = [target.global_position]
			if phase == 3:
				slam_points.append(target.global_position + Vector2(randf_range(-120, 120), randf_range(-80, 80)))
				slam_points.append(target.global_position + Vector2(randf_range(-120, 120), randf_range(-80, 80)))


func _end_pattern() -> void:
	pattern = ""
	idle_t = randf_range(0.7, 1.2) if phase < 3 else randf_range(0.35, 0.7)


func interrupt() -> void:
	if interrupt_cd > 0.0:
		return
	interrupt_cd = 5.0
	exposed_t = 3.0
	pattern = ""
	idle_t = 1.6
	Fx.text(get_parent(), core_pos() + Vector2(0, -40), "SYSTEMS DISRUPTED", Color(0.6, 0.85, 1.0), 1.2)


func _modify_incoming(amount: float, _hit: Dictionary) -> float:
	if not active:
		return amount * 0.25
	return amount * (1.5 if exposed_t > 0.0 else 1.0)


func _on_damaged(_hit: Dictionary, _amount: float) -> void:
	Audio.play_screen("impact_metal", core_pos(), 0.6)
	Fx.burst(get_parent(), core_pos() + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(1.0, 0.7, 0.3), 4, 140.0)


func _bullet(a: float, spd: float, col: Color) -> void:
	var from := global_position + Vector2.from_angle(a) * 36.0
	var h := _make_hit(def.get("dmg", [10, 14]))
	var p := Projectile.fire(get_parent(), from, Vector2.from_angle(a) * spd, h, Combat.LAYER_WORLD | Combat.LAYER_PLAYER, 1100.0, col)
	p.draw_offset = Vector2(0, -34)
	p.thickness = 4.5
	p.length = 6.0
	p.glow = true
	Audio.play_screen("boss_shot", core_pos())


func _laser_end(a: float) -> Vector2:
	var from := global_position
	var to := from + Vector2.from_angle(a) * 1100.0
	var q := PhysicsRayQueryParameters2D.create(from, to, Combat.LAYER_WORLD)
	var res := get_world_2d().direct_space_state.intersect_ray(q)
	return res["position"] if not res.is_empty() else to


func _laser_damage(a: float) -> void:
	if laser_tick > 0.0:
		return
	var from := global_position
	var end := _laser_end(a)
	var p := target.global_position
	var closest := Geometry2D.get_closest_point_to_segment(p, from, end)
	if closest.distance_to(p) < 18.0:
		laser_tick = 0.18
		var h := Combat.make_hit(randf_range(14, 18), self)
		h["dir"] = Vector2.from_angle(a).orthogonal()
		h["knockback"] = 80.0
		h["status"] = "burn"
		h["status_chance"] = 0.3
		target.call("take_hit", h)


func _slam(at: Vector2) -> void:
	var r := 115.0
	Fx.ring(get_parent(), Iso.sp(at), r, Color(1.0, 0.35, 0.1), 0.45, 12.0)
	Fx.burst(get_parent(), Iso.sp(at), Color(0.6, 0.5, 0.4), 22, 280.0)
	Events.screen_shake.emit(9.0)
	Audio.play("explosion", at, 0.7)
	if _target_alive() and target.global_position.distance_to(at) < r:
		var h := Combat.make_hit(randf_range(28, 38), self)
		h["dir"] = (target.global_position - at).normalized()
		h["knockback"] = 380.0
		target.call("take_hit", h)


func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	remove_from_group("enemies")
	pattern = ""
	_shape.set_deferred("disabled", true)
	Events.boss_bar.emit(display_name, 0.0, max_hp, false)
	Events.msg("[WARDEN] C O N T A I N . . . . . .", Color(1.0, 0.3, 0.25))
	Audio.play_screen("robot_death", core_pos(), 0.45)
	Audio.music("", 3.0)
	for n in get_parent().get_children():
		if n is Projectile and (n as Projectile).mask & Combat.LAYER_PLAYER:
			n.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("spawn_id") == "":
			e.call("take_hit", Combat.make_hit(9999.0, null))


func _death_sequence(delta: float) -> void:
	death_seq += delta
	if death_seq > 0.18 and dead_t < 2.4:
		death_seq = 0.0
		var p := core_pos() + Vector2(randf_range(-50, 50), randf_range(-50, 40))
		Fx.burst(get_parent(), p, Color(1.0, 0.6, 0.2), 14, 240.0)
		Fx.ring(get_parent(), p, 50.0, Color(1.0, 0.4, 0.1), 0.35, 6.0)
		Events.screen_shake.emit(5.0)
		Audio.play_screen("explosion", p, randf_range(0.9, 1.2), -4.0)
	if dead_t >= 2.4 and not GameState.has_flag("boss"):
		Fx.ring(get_parent(), core_pos(), 300.0, Color(1.0, 0.9, 0.7), 0.8, 16.0)
		Events.screen_shake.emit(16.0)
		Audio.play_screen("explosion", core_pos(), 0.55, 3.0)
		Audio.music("level", 4.0)
		GameState.add_xp(int(def.get("xp", 300)))
		Fx.text(get_parent(), core_pos(), "+%d XP" % int(def.get("xp", 300)), Color(0.7, 0.6, 1.0), 1.5)
		GameState.set_flag(GameState.area_flag("k:" + spawn_id))
		level.call("boss_loot", global_position)
		GameState.set_flag("boss")


# ---------------------------------------------------------------- drawing

func _render_body() -> void:
	var bob := sin(anim_t * 1.6) * 5.0
	var c := CORE_OFFSET + Vector2(0, bob)
	var dying := dead and dead_t < 2.4
	if dead and not dying:
		_draw_wreck()
		return
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	cv.draw_circle(Vector2.ZERO, 56.0, Color(0, 0, 0, 0.5))
	cv.draw_set_transform(Vector2.ZERO)
	var iron := _col(Color(0.13, 0.12, 0.13))
	var iron_hi := _col(Color(0.24, 0.22, 0.22))
	var brass := _col(Color(0.42, 0.34, 0.19))
	var phase_col: Color = [Color(1.0, 0.15, 0.1), Color(1.0, 0.15, 0.1), Color(1.0, 0.45, 0.1), Color(1.0, 0.85, 0.6)][phase]
	if exposed_t > 0.0:
		phase_col = Color(0.5, 0.85, 1.0)
	# hanging cables to the floor
	for i in 5:
		var x := -30.0 + i * 15.0
		var sway := sin(anim_t * 2.0 + i) * 4.0
		cv.draw_line(c + Vector2(x, 20), Vector2(x * 0.7 + sway, -2), Color(0.08, 0.08, 0.08), 2.0)
	# rotating armour ring
	var rot := anim_t * (0.4 + 0.25 * phase)
	for i in 6:
		var a0 := rot + TAU * i / 6.0
		cv.draw_arc(c, 50.0, a0, a0 + 0.75, 8, iron_hi, 12.0)
		cv.draw_arc(c, 56.0, a0, a0 + 0.75, 8, brass, 2.0)
	# gothic spires
	for i in 5:
		var sx := -32.0 + i * 16.0
		var h := 34.0 + (12.0 if i == 2 else 0.0) - absf(i - 2) * 4.0
		var base_y := c.y - 22.0
		cv.draw_colored_polygon(PackedVector2Array([Vector2(c.x + sx - 6, base_y), Vector2(c.x + sx + 6, base_y), Vector2(c.x + sx, base_y - h)]), iron)
		cv.draw_line(Vector2(c.x + sx, base_y), Vector2(c.x + sx, base_y - h), brass, 1.0)
	# main hull (octagon)
	var hull := PackedVector2Array()
	for i in 8:
		hull.append(c + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * 34.0)
	Shade.poly(cv, hull, iron.lightened(0.08))
	hull.append(hull[0])
	cv.draw_polyline(hull, brass.darkened(0.3), 1.0)
	# skull face plate
	Shade.ball(cv, c + Vector2(0, 10), 16.0, _col(Color(0.52, 0.49, 0.42)))
	cv.draw_rect(Rect2(c.x - 9, c.y + 18, 18, 9), _col(Color(0.55, 0.5, 0.42)))
	for i in 5:
		cv.draw_line(Vector2(c.x - 8 + i * 4, c.y + 20), Vector2(c.x - 8 + i * 4, c.y + 27), Color(0.15, 0.12, 0.1), 1.0)
	cv.draw_circle(c + Vector2(-6, 8), 4.0, Color(0.05, 0.03, 0.03))
	cv.draw_circle(c + Vector2(6, 8), 4.0, Color(0.05, 0.03, 0.03))
	# core eye
	var glow := 0.5 + 0.5 * sin(anim_t * 6.0)
	cv.draw_circle(c + Vector2(0, -8), 22.0, Color(phase_col.r, phase_col.g, phase_col.b, 0.15 + 0.1 * glow))
	cv.draw_circle(c + Vector2(0, -8), 12.0, Color(0.1, 0.02, 0.02))
	cv.draw_circle(c + Vector2(0, -8), 9.0, phase_col)
	var look := Vector2.ZERO
	if _target_alive():
		look = Iso.dir(target.global_position - global_position).normalized() * 3.0
	cv.draw_rect(Rect2(c.x - 1.5 + look.x, c.y - 15 + look.y, 3, 14), Color(0.1, 0.0, 0.0))
	# weapon arms
	for side in [-1.0, 1.0]:
		var sh := c + Vector2(side * 34.0, 4.0)
		var tip := sh + Vector2(side * 22.0, 14.0)
		cv.draw_line(sh, tip, iron_hi, 7.0)
		cv.draw_circle(tip, 6.0, iron)
		cv.draw_circle(tip, 2.5, phase_col)
	# pattern telegraphs
	if not dead:
		_draw_telegraphs(c)


func _draw_telegraphs(c: Vector2) -> void:
	match pattern:
		"spiral", "nova", "summon":
			if pat_t < 0.8:
				var f := pat_t / 0.8
				cv.draw_arc(c + Vector2(0, -8), 20.0 + 40.0 * (1.0 - f), 0, TAU, 32, Color(1.0, 0.3, 0.1, f), 3.0)
		"laser":
			var core := c + Vector2(0, -8)
			for k in (2 if laser_dual else 1):
				var a := laser_ang + PI * k
				var end := Iso.rel(_laser_end(a), global_position) + Vector2(0, -20)
				if pat_t < 1.1:
					cv.draw_line(core, end, Color(1.0, 0.1, 0.05, 0.25 + 0.4 * pat_t), 1.5)
				else:
					cv.draw_line(core, end, Color(1.0, 0.2, 0.1, 0.35), 22.0)
					cv.draw_line(core, end, Color(1.0, 0.45, 0.25, 0.9), 9.0)
					cv.draw_line(core, end, Color(1.0, 0.95, 0.85), 3.0)
		"slam":
			var tele := 1.0 if phase < 3 else 0.8
			for i in slam_points.size():
				if i < pat_step:
					continue
				var p := Iso.rel(slam_points[i], global_position)
				var f := clampf((pat_t - i * 0.35) / tele, 0.0, 1.0)
				Iso.ground(cv, p)
				cv.draw_circle(Vector2.ZERO, 115.0 * f, Color(1.0, 0.25, 0.05, 0.15))
				cv.draw_arc(Vector2.ZERO, 115.0, 0, TAU, 40, Color(1.0, 0.3, 0.05, 0.8), 2.5)
				cv.draw_set_transform(Vector2.ZERO)


func _draw_wreck() -> void:
	cv.draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, 0.5))
	cv.draw_circle(Vector2.ZERO, 50.0, Color(0.06, 0.05, 0.05))
	for i in 7:
		var a := TAU * i / 7.0
		cv.draw_line(Vector2.ZERO, Vector2.from_angle(a) * 55.0, Color(0.2, 0.18, 0.16), 6.0)
	cv.draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.05, 0.03))
	cv.draw_set_transform(Vector2.ZERO)
