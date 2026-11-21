class_name BroodKing
extends BroodEnemy
## Boss of Kessar VII and the end of act 1's Brood arc. Huge, armoured and
## mobile (unlike the stationary Queen). Phases by health:
##   1 (100-60%) stalks the operative: wide claw swipe, charges across the arena
##               (a charge into a stone pillar smashes it and leaves him dazed)
##   2 (60-25%)  also climbs the crater wall, out of reach, hurling boulders and
##               calling the brood in, then drops back down with a shockwave
##   3 (< 25%)   enraged: faster, and a stunning roar
## Disruptor Pulse / Concussion interrupt his telegraphs and pull him off the wall.
## Drops the King's Crest, the game's first Unique item.

const SWIPE_ARC := 1.1
const CHARGE_SPEED := 660.0
const CLIMB_TIME := 7.0

var active := false
var phase := 1
var act := "chase"
var act_t := 0.0
var cd := 2.0
var charge_cd := 3.0
var climb_cd := 2.0
var roar_cd := 6.0
var throw_t := 0.0
var add_t := 0.0
var aim := Vector2.RIGHT
var arena_rect := Rect2()
var perch := Vector2.ZERO


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	if level != null and level.rooms.has("arena"):
		var ar: Rect2i = level.rooms["arena"]
		arena_rect = Rect2(Vector2(ar.position) * Level.T, Vector2(ar.size) * Level.T).grow(-Level.T * 2)


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
		if _target_alive() and global_position.distance_to(target.global_position) < float(def.get("detect", 520)) and _los_to(target.global_position):
			_activate()
		queue_redraw()
		return
	Events.boss_bar.emit(display_name, hp, max_hp, true)
	var f := hp / max_hp
	var np := 1 if f > 0.6 else (2 if f > 0.25 else 3)
	if np != phase:
		phase = np
		Fx.text(get_parent(), Iso.sp(global_position, 140), "HE CLIMBS" if phase == 2 else "ENRAGED", Color(1.0, 0.4, 0.2), 1.4)
		Audio.play("zombie_snarl", global_position, 0.35, 6.0)
		Events.screen_shake.emit(10.0)
	var fast := 1.35 if phase == 3 else 1.0
	cd -= delta * fast
	charge_cd -= delta * fast
	climb_cd -= delta
	roar_cd -= delta * fast
	if is_stunned():
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	act_t -= delta * (fast if act.ends_with("_tele") else 1.0)
	match act:
		"chase":
			_chase_step(delta, fast)
		"swipe_tele":
			velocity = Vector2.ZERO
			if _target_alive() and act_t > 0.25:
				aim = (target.global_position - global_position).normalized()
				facing = aim.angle()
			if act_t <= 0.0:
				_swipe()
		"charge_tele":
			velocity = Vector2.ZERO
			if _target_alive() and act_t > 0.3:
				aim = (target.global_position - global_position).normalized()
				facing = aim.angle()
			if act_t <= 0.0:
				act = "charge"
				act_t = 1.0
				charge_hit = false
				Audio.play("zombie_snarl", global_position, 0.4, 4.0)
		"charge":
			_charge_step(delta)
		"roar_tele":
			velocity = Vector2.ZERO
			if act_t <= 0.0:
				_roar()
		"climb":
			_climb_step(delta)
	if act != "climb":
		move_and_slide()
	queue_redraw()


func _activate() -> void:
	active = true
	aggro = true
	Audio.music("boss")
	Audio.play("zombie_snarl", global_position, 0.3, 8.0)
	Events.screen_shake.emit(12.0)
	Events.msg("The Brood King rises.", Color(1.0, 0.45, 0.3))


func _chase_step(delta: float, fast: float) -> void:
	if not _target_alive():
		velocity = Vector2.ZERO
		return
	var to := target.global_position - global_position
	var d := to.length()
	facing = to.angle()
	velocity = to / maxf(d, 0.001) * speed * fast if d > float(def.get("swipe_range", 150)) * 0.7 else Vector2.ZERO
	if cd > 0.0:
		return
	if phase >= 2 and climb_cd <= 0.0:
		_start_climb()
	elif phase == 3 and roar_cd <= 0.0 and d < float(def.get("roar_radius", 170)) * 1.2:
		act = "roar_tele"
		act_t = 0.8
		roar_cd = 9.0
		Audio.play("zombie_snarl", global_position, 0.3, 2.0)
	elif d < float(def.get("swipe_range", 150)):
		act = "swipe_tele"
		act_t = float(def.get("telegraph", 0.75))
		aim = to / maxf(d, 0.001)
	elif charge_cd <= 0.0 and d > 180.0:
		act = "charge_tele"
		act_t = 0.9
		aim = to / maxf(d, 0.001)
		charge_cd = 6.0
	cd = float(def.get("cooldown", 1.2))


func _swipe() -> void:
	var r := float(def.get("swipe_range", 150))
	Fx.slash(get_parent(), Iso.sp(global_position, 30), aim.angle(), r * 0.8, SWIPE_ARC * 2.0, Color(0.9, 0.85, 0.6))
	Audio.play("swing_heavy", global_position, 0.5, 4.0)
	Events.screen_shake.emit(6.0)
	if _target_alive():
		var to := target.global_position - global_position
		if to.length() < r + 12.0 and absf(aim.angle_to(to)) < SWIPE_ARC:
			var h := _make_hit(def.get("dmg", [24, 34]))
			h["dir"] = to.normalized()
			h["knockback"] = 360.0
			target.call("take_hit", h)
	act = "chase"
	cd = float(def.get("recover", 0.7))


## The charge: hits the operative once; a stone pillar in the way is smashed and
## leaves him dazed and exposed; a wall stops him dazed too.
func _charge_step(delta: float) -> void:
	velocity = aim * CHARGE_SPEED
	if not charge_hit and _target_alive() and global_position.distance_to(target.global_position) < radius + 18.0:
		charge_hit = true
		var h := _make_hit(def.get("charge_dmg", [30, 42]))
		h["dir"] = aim
		h["knockback"] = 460.0
		target.call("take_hit", h)
		Events.screen_shake.emit(10.0)
	if level != null:
		var ahead: Vector2i = level.world_to_cell(global_position + aim * (radius + 10.0))
		if level.ch(ahead.x, ahead.y) == "+" and _pillar_standing(ahead):
			level.break_pillar(ahead)
			_dazed("SMASHED A PILLAR", 2.0)
			return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is StaticBody2D and col.get_normal().dot(-aim) > 0.5:
			_dazed("DAZED", 1.2)
			return
	if act_t <= 0.0:
		act = "chase"
		cd = 0.8


func _pillar_standing(cell: Vector2i) -> bool:
	for n in level.world.get_children():
		if n is Prop and (n as Prop).cell == cell and (n as Prop).kind == "+":
			return not (n as Prop).broken
	return false


func _dazed(txt: String, t: float) -> void:
	velocity = Vector2.ZERO
	act = "chase"
	cd = t
	apply_status("stun")
	vulnerable_t = t
	Events.screen_shake.emit(12.0)
	Audio.play("explosion", global_position, 0.6)
	Fx.text(get_parent(), Iso.sp(global_position, 140), txt, Color(1.0, 0.9, 0.5), 1.2)


func _roar() -> void:
	var r := float(def.get("roar_radius", 170))
	Fx.ring(get_parent(), Iso.sp(global_position, 20), r, Color(1.0, 0.45, 0.25), 0.6, 14.0)
	Events.screen_shake.emit(14.0)
	Audio.play("zombie_snarl", global_position, 0.25, 10.0)
	if _target_alive() and target.global_position.distance_to(global_position) < r:
		(target as Actor).apply_status("stun")
	act = "chase"
	cd = 1.0


# ---------------------------------------------------------------- climbing

func _start_climb() -> void:
	act = "climb"
	act_t = CLIMB_TIME
	climb_cd = 16.0 if phase == 2 else 12.0
	throw_t = 1.2
	add_t = 2.0
	buried = true                  # out of reach up on the crater wall
	collision_layer = 0
	# the nearest point on the arena's edge
	var c := arena_rect.get_center() if arena_rect.size != Vector2.ZERO else global_position
	var dir := (global_position - c).normalized() if global_position.distance_to(c) > 1.0 else Vector2.UP
	perch = c + dir * (arena_rect.size.x * 0.5 if arena_rect.size != Vector2.ZERO else 200.0)
	global_position = perch
	Fx.burst(get_parent(), Iso.sp(perch, 20), Color(0.4, 0.36, 0.3), 30, 260.0)
	Audio.play("explosion", perch, 0.5, -4.0)


func _climb_step(delta: float) -> void:
	velocity = Vector2.ZERO
	throw_t -= delta
	add_t -= delta
	if throw_t <= 0.0 and _target_alive():
		throw_t = 1.4 if phase == 2 else 1.0
		var b := BroodEnemy.Boulder.new()
		b.setup(global_position, target.global_position, _make_hit(def.get("boulder_dmg", [22, 32])), 60.0)
		get_parent().add_child(b)
		Audio.play("swing_heavy", global_position, 0.45)
	if add_t <= 0.0:
		add_t = 3.5
		if get_tree().get_nodes_in_group("enemies").size() < 12:
			for i in 2:
				var kind := "stalker" if randf() < 0.4 else "swarmling"
				var p := perch + Vector2.from_angle(randf() * TAU) * 60.0
				if arena_rect.size != Vector2.ZERO:
					p = p.clamp(arena_rect.position, arena_rect.end)
				var e: Enemy = level.call("spawn_enemy", kind, p, "")
				e.call_deferred("become_aggro")
	if act_t <= 0.0:
		_land(true)


## Drops off the wall near the operative: a shockwave where he lands.
func _land(with_shock: bool) -> void:
	buried = false
	collision_layer = Combat.LAYER_ENEMY
	var to := target.global_position if _target_alive() else arena_rect.get_center()
	var p := global_position.lerp(to, 0.75)
	if arena_rect.size != Vector2.ZERO:
		p = p.clamp(arena_rect.position, arena_rect.end)
	global_position = p
	Fx.ring(get_parent(), Iso.sp(p), 130.0, Color(0.6, 0.5, 0.35), 0.5, 12.0)
	Fx.burst(get_parent(), Iso.sp(p, 6), Color(0.42, 0.38, 0.32), 36, 320.0)
	Events.screen_shake.emit(14.0)
	Audio.play("explosion", p, 0.45)
	if with_shock and _target_alive() and target.global_position.distance_to(p) < 130.0:
		var h := _make_hit(def.get("dmg", [24, 34]))
		h["dir"] = (target.global_position - p).normalized()
		h["knockback"] = 400.0
		target.call("take_hit", h)
	act = "chase"
	cd = 1.2


func interrupt() -> void:
	if act in ["swipe_tele", "charge_tele", "roar_tele"]:
		_dazed("INTERRUPTED", 1.0)
	elif act == "climb":
		_land(false)
		_dazed("PULLED DOWN", 1.5)


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
	Events.screen_shake.emit(16.0)
	Fx.ring(get_parent(), Iso.sp(global_position, 30), 300.0, Color(0.6, 1.0, 0.3), 0.9, 16.0)
	if level != null:
		var il := GameState.area_level() + 1
		level.call("drop_item", level.call("scatter", global_position), {"kind": "item", "item": ItemDB.generate_unique("kings_crest", il)})
		level.call("boss_loot", global_position)
	GameState.set_flag("king:dead")


# ---------------------------------------------------------------- drawing

func _render_body() -> void:
	if act == "swipe_tele" and not dead:
		Iso.ground(cv)
		var r := float(def.get("swipe_range", 150))
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.from_angle(aim.angle() - SWIPE_ARC + SWIPE_ARC * 2.0 * i / 12.0) * r)
		cv.draw_colored_polygon(pts, Color(1.0, 0.4, 0.2, 0.2 + 0.2 * (1.0 - clampf(act_t / 0.75, 0, 1))))
		cv.draw_set_transform(Vector2.ZERO)
	elif act == "charge_tele" and not dead:
		Iso.ground(cv)
		cv.draw_line(Vector2.ZERO, aim * 420.0, Color(1.0, 0.35, 0.2, 0.35), 18.0)
		cv.draw_set_transform(Vector2.ZERO)
	elif act == "roar_tele" and not dead:
		Iso.ground(cv)
		cv.draw_arc(Vector2.ZERO, float(def.get("roar_radius", 170)), 0, TAU, 32, Color(1.0, 0.4, 0.2, 0.7), 2.5)
		cv.draw_set_transform(Vector2.ZERO)
	var c := Color(0.2, 0.17, 0.15)
	if dead:
		_corpse(46.0, c)
		return
	var lift := Vector2(0, -90) if buried else Vector2.ZERO
	if not buried:
		_shadow(50.0)
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var charging := act == "charge"
	var breathe := sin(anim_t * 1.4) * 2.0
	var body := Vector2(-6 * fx, -44 + breathe) + lift
	_legs(body + Vector2(0, 26), 40.0, 3, _col(c.darkened(0.3)), 0.6 if not charging else 1.8)
	# massive armoured body
	Shade.ball(cv, body + Vector2(-16 * fx, 4), 30.0, _col(c))
	Shade.ball(cv, body + Vector2(10 * fx, -6), 28.0, _col(c.lightened(0.05)))
	for i in 4:
		cv.draw_arc(body + Vector2((-20 + i * 12) * fx, -16 + absf(i - 1.5) * 4.0), 14.0, PI * 1.15, PI * 1.85, 10, _col(c.lightened(0.25)), 3.0)
	# head with the crest of horns (the Crest the operative will take)
	var head := body + Vector2(34 * fx, -6 + (10 if charging else 0))
	Shade.ball(cv, head, 17.0, _col(c.lightened(0.12)))
	for k in 6:
		var a := -PI * 0.5 + (k - 2.5) * 0.32
		var base := head + Vector2(-4 * fx, -10)
		cv.draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(4, 0), base + Vector2.from_angle(a) * (26.0 - absf(k - 2.5) * 3.0)]), _col(Color(0.82, 0.72, 0.52)))
	var ec := Color(1.0, 0.3, 0.1) if act.ends_with("_tele") or phase == 3 else Color(1.0, 0.7, 0.2)
	for i in 3:
		cv.draw_circle(head + Vector2((4 + i * 4) * fx, -2 + i), 2.5, ec)
	cv.draw_line(head + Vector2(12 * fx, 6), head + Vector2(28 * fx, 14), _col(Color(0.85, 0.8, 0.65)), 5.0)
	cv.draw_line(head + Vector2(12 * fx, 10), head + Vector2(26 * fx, 22), _col(Color(0.85, 0.8, 0.65)), 4.0)
	if buried:
		cv.draw_line(body + Vector2(0, 30), body + Vector2(0, 90), Color(0.4, 0.35, 0.28, 0.4), 3.0)   # dust trailing down the wall
	if is_stunned():
		_draw_overlay()
