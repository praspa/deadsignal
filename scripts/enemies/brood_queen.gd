class_name BroodQueen
extends BroodEnemy
## Boss of the Kessar IV hive. Mostly stationary; three phases by health:
##   1 (100-60%) acid spray cone + calls Swarmlings out of the chamber's eggs
##   2 (60-25%)  also burrows: ripples track the operative, she bursts up under them
##   3 (< 25%)   enraged: faster, and every emergence leaves a ring of acid pools
## Disruptor Pulse cancels a spray and forces her out of a burrow, dazed.

const SPRAY_HALF_ANGLE := 0.5
const EMERGE_RADIUS := 80.0

var active := false
var phase := 1
var act := "idle"
var act_t := 1.5
var summon_t := 6.0
var burrow_cd := 4.0
var spray_dir := Vector2.RIGHT
var ripple := Vector2.ZERO
var arena_rect := Rect2()


func _ready() -> void:
	super._ready()
	add_to_group("boss")


func _physics_process(delta: float) -> void:
	anim_t += delta
	if dead:
		dead_t += delta
		queue_redraw()
		return
	flash = maxf(0.0, flash - delta)
	vulnerable_t = maxf(0.0, vulnerable_t - delta)
	process_statuses(delta)
	if dead:
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
	if not active:
		if _target_alive() and global_position.distance_to(target.global_position) < float(def.get("detect", 460)) and _los_to(target.global_position):
			_activate()
		queue_redraw()
		return
	Events.boss_bar.emit(display_name, hp, max_hp, true)
	var f := hp / max_hp
	var new_phase := 1 if f > 0.6 else (2 if f > 0.25 else 3)
	if new_phase != phase:
		phase = new_phase
		Fx.text(get_parent(), Iso.sp(global_position, 110), "ENRAGED" if phase == 3 else "SHE BURROWS", Color(1.0, 0.4, 0.2), 1.3)
		Audio.play("zombie_snarl", global_position, 0.4, 4.0)
	if is_stunned():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var speed_k := 0.6 if phase == 3 else 1.0
	summon_t -= delta
	if summon_t <= 0.0:
		summon_t = 12.0 * speed_k
		_summon()
	burrow_cd -= delta
	act_t -= delta
	match act:
		"idle":
			if _target_alive():
				facing = (target.global_position - global_position).angle()
			if act_t <= 0.0:
				_choose_action()
		"spray_tele":
			if _target_alive() and act_t > 0.35:
				spray_dir = (target.global_position - global_position).normalized()
				facing = spray_dir.angle()
			if act_t <= 0.0:
				_spray()
		"burrow":
			if _target_alive():
				ripple = ripple.move_toward(target.global_position, 210.0 * delta)
			global_position = ripple   # she tunnels: Disruptor Pulse can reach her down there
			if act_t <= 0.0:
				act = "emerge_tele"
				act_t = 0.7
				Audio.play("explosion", ripple, 0.5, -8.0)
		"emerge_tele":
			if act_t <= 0.0:
				_emerge_at(ripple, true)
	velocity = Vector2.ZERO
	queue_redraw()


func _activate() -> void:
	active = true
	aggro = true
	Audio.music("boss")
	Audio.play("zombie_snarl", global_position, 0.4, 6.0)
	Events.screen_shake.emit(8.0)
	Events.msg("The Brood Queen stirs.", Color(1.0, 0.5, 0.3))


func _choose_action() -> void:
	var cd := float(def.get("cooldown", 1.6)) * (0.6 if phase == 3 else 1.0)
	var d := global_position.distance_to(target.global_position) if _target_alive() else 9999.0
	if phase >= 2 and burrow_cd <= 0.0:
		act = "burrow"
		act_t = 2.0
		ripple = global_position
		burrow_cd = 9.0 if phase == 2 else 6.0
		buried = true
		collision_layer = 0
		Fx.burst(get_parent(), Iso.sp(global_position, 6), Color(0.4, 0.36, 0.3), 30, 240.0)
		Audio.play("explosion", global_position, 0.45, -4.0)
	elif d < float(def.get("spray_range", 280)) * 1.3:
		act = "spray_tele"
		act_t = float(def.get("telegraph", 0.9)) * (0.8 if phase == 3 else 1.0)
		Audio.play("zombie_snarl", global_position, 0.55)
	else:
		# too far for the spray: lob acid at the operative instead
		for i in (3 if phase == 3 else 2):
			var aim: Vector2 = target.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			_spit(aim)
		act = "idle"
		act_t = cd + 0.6


## Acid cone in front of her: damage if the operative is in it, pools along it.
func _spray() -> void:
	var rng := float(def.get("spray_range", 280))
	Audio.play("impact_flesh", global_position, 0.5, 4.0)
	Events.screen_shake.emit(4.0)
	for k in 12:
		var a := spray_dir.angle() + randf_range(-SPRAY_HALF_ANGLE, SPRAY_HALF_ANGLE)
		Fx.burst(get_parent(), Iso.sp(global_position + Vector2.from_angle(a) * randf_range(40, rng), 10), Color(0.55, 0.9, 0.2), 3, 90.0)
	if _target_alive():
		var to := target.global_position - global_position
		if to.length() < rng + 10.0 and absf(spray_dir.angle_to(to)) < SPRAY_HALF_ANGLE:
			var h := _make_hit(def.get("dmg", [14, 20]))
			h["dir"] = spray_dir
			h["knockback"] = 160.0
			h["status"] = "toxin"
			h["status_chance"] = 0.6
			target.call("take_hit", h)
	for i in 3:
		AcidPool.spawn(get_parent(), global_position + spray_dir.rotated(randf_range(-0.3, 0.3)) * (90.0 + i * 70.0), 32.0, 7.0, 3.5)
	act = "idle"
	act_t = float(def.get("recover", 0.8)) + float(def.get("cooldown", 1.6)) * (0.6 if phase == 3 else 1.0)


func _emerge_at(p: Vector2, with_damage: bool) -> void:
	buried = false
	collision_layer = Combat.LAYER_ENEMY
	if arena_rect.size != Vector2.ZERO:
		p = p.clamp(arena_rect.position, arena_rect.end)
	global_position = p
	Fx.burst(get_parent(), Iso.sp(p, 6), Color(0.42, 0.38, 0.32), 36, 300.0)
	Fx.ring(get_parent(), Iso.sp(p), EMERGE_RADIUS, Color(0.6, 0.5, 0.35), 0.5, 10.0)
	Events.screen_shake.emit(10.0)
	Audio.play("explosion", p, 0.5)
	if with_damage and _target_alive() and target.global_position.distance_to(p) < EMERGE_RADIUS:
		var h := _make_hit(def.get("burrow_dmg", [20, 28]))
		h["dir"] = (target.global_position - p).normalized()
		h["knockback"] = 360.0
		target.call("take_hit", h)
	if phase == 3:
		for i in 6:
			AcidPool.spawn(get_parent(), p + Vector2.from_angle(i * TAU / 6.0) * 110.0, 30.0, 7.0, 4.0)
	act = "idle"
	act_t = 1.2


## Calls the brood: the nearest unhatched eggs hatch, else Swarmlings crawl out of her.
func _summon() -> void:
	var eggs: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BroodEnemy and (e as BroodEnemy).kind == "egg" and not (e as BroodEnemy).dead \
				and (e as Node2D).global_position.distance_to(global_position) < 420.0:
			eggs.append(e)
	eggs.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	Audio.play("zombie_groan", global_position, 0.5, 4.0)
	if eggs.is_empty():
		for i in 2:
			var s: Enemy = level.call("spawn_enemy", "swarmling", global_position + Vector2.from_angle(randf() * TAU) * (radius + 14.0), "")
			s.call_deferred("become_aggro")
		return
	for i in mini(2, eggs.size()):
		(eggs[i] as BroodEnemy).start_hatch()


func interrupt() -> void:
	if act == "spray_tele":
		act = "idle"
		act_t = 1.5
		apply_status("stun", 1.2)
		Fx.text(get_parent(), Iso.sp(global_position, 110), "INTERRUPTED", Color(0.6, 0.85, 1.0), 1.0)
	elif act == "burrow" or act == "emerge_tele":
		_emerge_at(ripple, false)
		apply_status("stun", 1.5)
		vulnerable_t = 1.5
		Fx.text(get_parent(), Iso.sp(global_position, 110), "FORCED OUT", Color(0.6, 0.85, 1.0), 1.0)


func take_hit(hit: Dictionary) -> bool:
	if not active and not dead:
		_activate()
	return super.take_hit(hit)


func die() -> void:
	if dead:
		return
	buried = false
	super.die()
	Events.boss_bar.emit(display_name, 0.0, max_hp, false)
	Audio.music(String(GameState.location_def().get("music", "")), 3.0)
	Events.screen_shake.emit(14.0)
	Fx.ring(get_parent(), Iso.sp(global_position, 20), 260.0, Color(0.6, 1.0, 0.3), 0.8, 14.0)
	if level != null:
		level.call("boss_loot", global_position)
	GameState.set_flag("kessar:queen")


# ---------------------------------------------------------------- drawing

func _render_body() -> void:
	# telegraphs live on the floor
	if act == "spray_tele" and not dead:
		Iso.ground(cv)
		var r := float(def.get("spray_range", 280))
		var a0 := spray_dir.angle() - SPRAY_HALF_ANGLE
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.from_angle(a0 + SPRAY_HALF_ANGLE * 2.0 * i / 12.0) * r)
		var k := 1.0 - clampf(act_t / 0.9, 0.0, 1.0)
		cv.draw_colored_polygon(pts, Color(0.55, 0.9, 0.2, 0.12 + 0.18 * k))
		cv.draw_set_transform(Vector2.ZERO)
	if buried:
		Iso.ground(cv)
		var k2 := 1.0 if act == "emerge_tele" else 0.0
		for i in 3:
			var rr := fmod(anim_t * 40.0 + i * 14.0, 42.0)
			cv.draw_arc(Vector2.ZERO, rr, 0, TAU, 20, Color(0.55, 0.48, 0.38, 0.6 - rr / 70.0), 2.0)
		if k2 > 0.0:
			cv.draw_circle(Vector2.ZERO, EMERGE_RADIUS, Color(0.9, 0.3, 0.1, 0.2))
			cv.draw_arc(Vector2.ZERO, EMERGE_RADIUS, 0, TAU, 32, Color(1.0, 0.4, 0.2, 0.8), 2.0)
		cv.draw_set_transform(Vector2.ZERO)
		return
	var c := Color(0.28, 0.24, 0.22)
	if dead:
		_corpse(40.0, c)
		return
	_shadow(46.0, 0.5)
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var breathe := sin(anim_t * 1.6) * 2.0
	var tele := act == "spray_tele"
	# huge egg sac behind her, veined and glowing
	var sac := Vector2(-26 * fx, -26)
	Shade.ball(cv, sac, 30.0 + breathe, _col(Color(0.5, 0.45, 0.34)))
	for i in 5:
		var a := float(i) * 1.2 + 0.4
		cv.draw_line(sac + Vector2.from_angle(a) * 8.0, sac + Vector2.from_angle(a) * 26.0, Color(0.55, 0.9, 0.25, 0.35), 2.0)
	cv.draw_circle(sac + Vector2(-6 * fx, -6), 10.0, Color(0.7, 1.0, 0.4, 0.18 + 0.08 * sin(anim_t * 3.0)))
	# legs
	_legs(Vector2(4 * fx, -10), 30.0, 3, _col(c.darkened(0.35)), 0.3)
	# armoured thorax and crested head
	var thorax := Vector2(10 * fx, -40)
	Shade.ball(cv, thorax, 20.0, _col(c))
	for i in 3:
		cv.draw_arc(thorax + Vector2(0, -6 + i * 7), 16.0 - i * 2.0, PI * 1.15, PI * 1.85, 10, _col(c.lightened(0.25)), 2.0)
	var head := thorax + Vector2(20 * fx, -14 + (6 if tele else 0))
	Shade.ball(cv, head, 13.0, _col(c.lightened(0.1)))
	for i in 4:
		cv.draw_line(head + Vector2(-4 * fx, -8), head + Vector2((-12 + i * 6) * fx, -26 - absf(i - 1.5) * 4.0), _col(Color(0.6, 0.55, 0.45)), 3.0)
	var jaw := 0.8 if tele else 0.3
	cv.draw_line(head + Vector2(8 * fx, 2), head + Vector2.from_angle(-jaw) * 22.0 * Vector2(fx, 1) + Vector2(8 * fx, 2), _col(Color(0.75, 0.7, 0.58)), 4.0)
	cv.draw_line(head + Vector2(8 * fx, 4), head + Vector2.from_angle(jaw) * 22.0 * Vector2(fx, 1) + Vector2(8 * fx, 4), _col(Color(0.75, 0.7, 0.58)), 4.0)
	var ec := Color(1.0, 0.25, 0.1) if tele or phase == 3 else Color(0.9, 0.7, 0.2)
	for i in 3:
		cv.draw_circle(head + Vector2((2 + i * 3) * fx, -4 + i), 1.8, ec)
	if tele:
		cv.draw_circle(head + Vector2(14 * fx, 4), 8.0, Color(0.6, 1.0, 0.2, 0.45))
	if is_stunned():
		_draw_overlay()
