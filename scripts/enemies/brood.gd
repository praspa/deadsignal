class_name BroodEnemy
extends Enemy
## Kessar IV's creatures. Reuses Enemy's state machine (and its "lunge" attack)
## and adds the Brood's own moves, all data-driven from data/enemies.json:
##   spit   (Spitter)    arcing acid glob that leaves an acid pool
##   charge (Broodguard) telegraphed straight-line rush; stunned + vulnerable on hitting a wall
##   hatch  (Egg)        hatches Swarmlings when the operative comes close
##   ambush (Burrower)   buried under the ash until the operative is near
##   drop   (Wall Crawler) clings to a wall, then drops onto the operative (shadow telegraph)
## Infested Miners behave like Mutated Researchers with their own look; Infested
## Militia fire their old rifles, badly. Champions ("champion" in the data, e.g.
## the Brood Lieutenant) get a named health bar; the Lieutenant drops Last
## Water's Civic Hall access card.

var buried := false          # burrower under the ash
var emerge_t := 0.0          # > 0: ash bubbling, about to erupt
var hatch_t := 0.0           # > 0: egg wobbling, about to hatch
var charge_dir := Vector2.ZERO
var charge_hit := false
var vulnerable_t := 0.0      # broodguard after slamming into a wall
var drop_target := Vector2.ZERO   # wall crawler: where it will land


func _ready() -> void:
	super._ready()
	var amb = def.get("ambush", false)
	if spawn_id != "" and ((amb is bool and amb) or amb is String):
		buried = true
		collision_layer = 0
	if def.has("champion"):
		display_name = "%s [%s]" % [display_name, String(def["champion"])]
		add_to_group("champion")


func _physics_process(delta: float) -> void:
	vulnerable_t = maxf(0.0, vulnerable_t - delta)
	if buried:
		anim_t += delta
		if target == null or not is_instance_valid(target):
			target = get_tree().get_first_node_in_group("player") as Node2D
		if emerge_t > 0.0:
			emerge_t -= delta
			if emerge_t <= 0.0:
				_emerge()
		elif _target_alive() and global_position.distance_to(target.global_position) < float(def.get("detect", 110)):
			if str(def.get("ambush", "")) == "drop":
				drop_target = target.global_position   # the shadow on the ground is the warning
				emerge_t = 0.6
				Audio.play("zombie_snarl", global_position, 1.5)
			else:
				emerge_t = 0.45   # the telegraph: ash bubbles, then it erupts
				Audio.play("zombie_snarl", global_position, 0.7)
		queue_redraw()
		return
	if kind == "egg" and not dead:
		_egg_step(delta)
		return
	super._physics_process(delta)
	if def.has("champion") and not dead and aggro:
		Events.boss_bar.emit(display_name, hp, max_hp, true)


func take_hit(hit: Dictionary) -> bool:
	if buried:
		return false
	return super.take_hit(hit)


func become_aggro() -> void:
	if buried or kind == "egg":
		return
	super.become_aggro()


func _modify_incoming(amount: float, hit: Dictionary) -> float:
	if vulnerable_t > 0.0:
		amount *= 1.5
	if hit.get("source") is Player and not bool(def.get("primate", false)):
		amount *= 1.0 + GameState.equip_stat("brood_dmg_pct") / 100.0   # the King's Crest
	return super._modify_incoming(amount, hit)


# ---------------------------------------------------------------- ambush / eggs

func _emerge() -> void:
	buried = false
	collision_layer = Combat.LAYER_ENEMY
	if str(def.get("ambush", "")) == "drop":
		_drop_from_wall()
		return
	Fx.burst(get_parent(), Iso.sp(global_position, 4), Color(0.45, 0.42, 0.38), 22, 200.0)
	Events.screen_shake.emit(4.0)
	Audio.play("explosion", global_position, 1.6, -10.0)
	super.become_aggro()
	if _target_alive():
		# erupts straight into a bite
		telegraph_target = target.global_position
		attack_variant = "lunge"
		attack_cd = 0.0
		_begin_attack()


## Wall Crawler lands where its shadow was: hurts and knocks back on a hit.
func _drop_from_wall() -> void:
	if level != null and not level.astar.is_point_solid(level.world_to_cell(drop_target)):
		global_position = drop_target
	Fx.burst(get_parent(), Iso.sp(global_position, 4), Color(0.5, 0.45, 0.38), 14, 160.0)
	Audio.play("impact_flesh", global_position, 1.3)
	if _target_alive() and target.global_position.distance_to(global_position) < 40.0:
		var h := _make_hit(def.get("drop_dmg", [10, 16]))
		h["dir"] = (target.global_position - global_position).normalized()
		h["knockback"] = 200.0
		target.call("take_hit", h)
	super.become_aggro()
	attack_cd = 0.4


func die() -> void:
	if dead:
		return
	super.die()
	if def.has("champion"):
		Events.boss_bar.emit(display_name, 0.0, max_hp, false)
	if kind == "lieutenant" and level != null:
		# the Civic Hall access card, fused into its carapace
		level.call("drop_item", global_position + Vector2(0, 18), {"kind": "quest", "flag": "lastwater:card", "name": "Civic Hall access card"})


func _egg_step(delta: float) -> void:
	anim_t += delta
	flash = maxf(0.0, flash - delta)
	show_bar_t = maxf(0.0, show_bar_t - delta)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
	if hatch_t > 0.0:
		hatch_t -= delta
		if hatch_t <= 0.0:
			hatch()
	elif _target_alive() and global_position.distance_to(target.global_position) < float(def.get("detect", 150)) and _los_to(target.global_position):
		start_hatch()
	queue_redraw()


func start_hatch() -> void:
	if hatch_t > 0.0 or dead:
		return
	hatch_t = float(def.get("hatch_time", 1.2))


## Bursts open: Swarmlings come out already hunting. The egg is spent (no XP).
func hatch() -> void:
	if dead:
		return
	var n: Array = def.get("hatch", [2, 3])
	for i in randi_range(int(n[0]), int(n[1])):
		var e: Enemy = level.call("spawn_enemy", "swarmling", global_position + Vector2.from_angle(randf() * TAU) * 14.0, "")
		e.call_deferred("become_aggro")
	Audio.play("impact_flesh", global_position, 0.7)
	Fx.blood(get_parent(), Iso.sp(global_position, 10), Vector2.UP, _blood_color())
	def = def.duplicate()
	def["xp"] = 0
	def["ammo_chance"] = 0.0
	die()


# ---------------------------------------------------------------- attacks

func _start_telegraph() -> void:
	super._start_telegraph()
	if attack_variant == "charge":
		Audio.play("zombie_snarl", global_position, 0.5)
	elif attack_variant == "thornback":
		# close: pound the ground; far: hurl a boulder. Beats its chest either way.
		var d := global_position.distance_to(target.global_position) if _target_alive() else 999.0
		attack_variant = "pound" if d < float(def.get("pound_radius", 110)) * 0.9 else "boulder"
		Audio.play("zombie_snarl", global_position, _voice_pitch(), -2.0)


## A thrown boulder that lands where the operative was (shadow telegraph), splash damage.
func _boulder(at: Vector2) -> void:
	var b := Boulder.new()
	b.setup(global_position, at, _make_hit(def.get("boulder_dmg", [20, 30])), 55.0)
	get_parent().add_child(b)
	Audio.play("swing_heavy", global_position, 0.6)


class Boulder extends Node2D:
	const FLIGHT := 0.9
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var hit: Dictionary = {}
	var r := 55.0
	var t := 0.0
	var cv: IsoView

	func setup(p_from: Vector2, p_to: Vector2, p_hit: Dictionary, p_r: float) -> void:
		from = p_from
		to = p_to
		position = p_to
		hit = p_hit
		r = p_r

	func _ready() -> void:
		cv = IsoView.attach(self)

	func _physics_process(delta: float) -> void:
		t += delta
		if t >= FLIGHT:
			Fx.burst(get_parent(), Iso.sp(to, 4), Color(0.4, 0.37, 0.33), 20, 220.0)
			Events.screen_shake.emit(5.0)
			Audio.play("explosion", to, 0.9, -6.0)
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p != null and p.global_position.distance_to(to) < r:
				var h := hit.duplicate()
				h["dir"] = (p.global_position - to).normalized()
				h["knockback"] = 240.0
				p.call("take_hit", h)
			queue_free()

	func _render() -> void:
		var k := t / FLIGHT
		Iso.ground(cv)
		cv.draw_circle(Vector2.ZERO, r * (0.4 + 0.6 * k), Color(0, 0, 0, 0.2 + 0.3 * k))
		cv.draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(0.9, 0.5, 0.3, 0.4 * k), 1.5)
		cv.draw_set_transform(Vector2.ZERO)
		# the rock itself, falling in from above along its arc
		var off := Iso.to_screen(from - to) * (1.0 - k) + Vector2(0, -sin(k * PI) * 120.0 - (1.0 - k) * 30.0)
		Shade.ball(cv, off, 8.0, Color(0.42, 0.4, 0.36))


func _begin_attack() -> void:
	match attack_variant:
		"stone":
			# Gibberer: a hurled rock, arcing a little short or long
			state = S.ATTACK
			var aim := telegraph_target + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			var pr := Projectile.fire(get_parent(), global_position, (aim - global_position).normalized() * float(def.get("projectile_speed", 380)),
				_make_hit(def.get("dmg", [6, 9])), Combat.LAYER_WORLD | Combat.LAYER_PLAYER, global_position.distance_to(aim) + 40.0, Color(0.55, 0.5, 0.42))
			pr.exclude = [get_rid()]
			pr.thickness = 4.0
			pr.length = 3.0
			pr.draw_offset = Vector2(0, -20)
			Audio.play("swing", global_position, 1.6, -6.0)
			_end_attack()
		"pound":
			# Thornback: fists into the ground, a shockwave ring
			state = S.ATTACK
			var r := float(def.get("pound_radius", 110))
			Fx.ring(get_parent(), Iso.sp(global_position), r, Color(0.6, 0.5, 0.35), 0.45, 12.0)
			Fx.burst(get_parent(), Iso.sp(global_position, 4), Color(0.45, 0.4, 0.32), 24, 260.0)
			Events.screen_shake.emit(7.0)
			Audio.play("explosion", global_position, 0.6, -4.0)
			if _target_alive() and target.global_position.distance_to(global_position) < r:
				var h := _make_hit(def.get("dmg", [16, 24]))
				h["dir"] = (target.global_position - global_position).normalized()
				h["knockback"] = 340.0
				target.call("take_hit", h)
			_end_attack()
		"boulder":
			state = S.ATTACK
			_boulder(telegraph_target)
			_end_attack()
		"bolt":
			state = S.ATTACK
			_shoot(telegraph_target, Color(1.0, 0.75, 0.3), 3.0, float(def.get("spread", 0.04)))
			_end_attack()
		"spit":
			state = S.ATTACK
			_spit(telegraph_target)
			_end_attack()
		"charge":
			state = S.ATTACK
			charge_dir = (telegraph_target - global_position).normalized()
			facing = charge_dir.angle()
			charge_hit = false
			state_t = float(def.get("charge_time", 0.7))
		_:
			super._begin_attack()


func _attack_step(delta: float) -> void:
	if attack_variant != "charge":
		super._attack_step(delta)
		return
	state_t -= delta
	velocity = charge_dir * float(def.get("charge_speed", 500))
	if not charge_hit and _target_alive() and global_position.distance_to(target.global_position) < radius + 16.0:
		charge_hit = true
		var h := _make_hit(def.get("dmg", [16, 24]))
		h["dir"] = charge_dir
		h["knockback"] = 380.0
		target.call("take_hit", h)
		Events.screen_shake.emit(6.0)
	# slammed into rock: dazed and exposed
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is StaticBody2D and col.get_normal().dot(-charge_dir) > 0.5:
			apply_status("stun", 1.5)
			vulnerable_t = 1.5
			Events.screen_shake.emit(5.0)
			Audio.play("impact_metal", global_position, 0.5)
			Fx.text(get_parent(), Iso.sp(global_position, 60), "DAZED", Color(1.0, 0.9, 0.5), 0.9)
			_end_attack()
			return
	if state_t <= 0.0:
		_end_attack()


## Lobbed acid: hurts on a direct hit and leaves a burning pool where it lands.
func _spit(at: Vector2) -> void:
	var from := global_position + Vector2.from_angle(facing) * radius
	var dist := from.distance_to(at)
	var p := Projectile.fire(get_parent(), from, (at - from).normalized() * float(def.get("projectile_speed", 300)),
		_make_hit(def.get("dmg", [6, 9])), Combat.LAYER_PLAYER, dist, Color(0.55, 0.9, 0.2))
	p.exclude = [get_rid()]
	p.thickness = 5.0
	p.length = 5.0
	p.glow = true
	p.draw_offset = Vector2(0, -22)
	var dps := float(def.get("pool_dps", 6))
	var life := float(def.get("pool_time", 3.0))
	var parent := get_parent()
	p.on_impact = func(pos: Vector2) -> void:
		AcidPool.spawn(parent, pos, 34.0, dps, life)
	Audio.play("impact_flesh", global_position, 1.5, -4.0)


# ---------------------------------------------------------------- drawing

func _render_body() -> void:
	match kind:
		"swarmling":
			_draw_swarmling()
		"spitter":
			_draw_spitter()
		"broodguard":
			_draw_broodguard()
		"miner":
			_draw_miner()
		"burrower":
			_draw_burrower()
		"egg":
			_draw_egg()
		"militia":
			_draw_militia()
		"crawler":
			_draw_crawler()
		"lieutenant":
			_draw_lieutenant()
		"stalker":
			_draw_stalker()
		"gibberer":
			_draw_gibberer()
		"thornback", "elder_thornback":
			_draw_thornback()
	if not dead and not buried:
		_draw_overlay()


func _chitin(c: Color) -> Color:
	return _col(c)


func _corpse(r: float, c: Color) -> void:
	var f := minf(dead_t * 3.0, 1.0)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	cv.draw_circle(Vector2.ZERO, r * (0.6 + 0.6 * f), Color(_blood_color().r, _blood_color().g, _blood_color().b, 0.55))
	cv.draw_set_transform(Vector2.ZERO)
	cv.draw_circle(Vector2(0, -3), r * 0.55, c.darkened(0.5))
	for i in 4:
		var a := float(i) * 0.8 + 0.4
		cv.draw_line(Vector2(0, -3), Vector2(cos(a) * r, -3 - sin(a) * r * 0.4), c.darkened(0.4), 1.5)


func _legs(center: Vector2, r: float, n: int, c: Color, speed_mult := 1.0) -> void:
	var moving := velocity.length() > 20.0
	for i in n:
		for side in [-1.0, 1.0]:
			var ph := anim_t * 22.0 * speed_mult + i * 1.7 + (0.0 if side > 0 else PI)
			var step := sin(ph) * 3.0 if moving else 0.0
			var base := center + Vector2(side * r * 0.5, (float(i) - (n - 1) * 0.5) * r * 0.35)
			var knee := base + Vector2(side * r * 0.7, -r * 0.35 + step * 0.4)
			var foot := knee + Vector2(side * r * 0.4 + step, r * 0.7)
			cv.draw_polyline(PackedVector2Array([base, knee, foot]), c, 1.6)


func _draw_swarmling() -> void:
	var c := Color(0.32, 0.27, 0.2)
	if dead:
		_corpse(8.0, c)
		return
	_shadow(9.0)
	var tele := state == S.TELEGRAPH
	var bob := sin(anim_t * 18.0) * 1.0
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var body := Vector2(0, -8 + bob)
	_legs(body + Vector2(0, 2), 8.0, 3, _chitin(c.darkened(0.3)), 1.4)
	Shade.ball(cv, body, 6.5, _chitin(c))
	Shade.ball(cv, body + Vector2(-5 * fx, 1), 5.0, _chitin(c.darkened(0.1)))   # abdomen
	var head := body + Vector2(6 * fx, -1)
	Shade.ball(cv, head, 3.8, _chitin(c.lightened(0.1)))
	var mc := Color(1.0, 0.3, 0.15) if tele else Color(0.8, 0.75, 0.6)
	cv.draw_line(head, head + Vector2(5 * fx, -2), mc, 1.4)
	cv.draw_line(head, head + Vector2(5 * fx, 2), mc, 1.4)
	cv.draw_circle(head + Vector2(1.5 * fx, -1.5), 1.0, Color(0.9, 0.7, 0.2))


func _draw_spitter() -> void:
	var c := Color(0.36, 0.33, 0.22)
	if dead:
		_corpse(12.0, c)
		return
	_shadow(12.0)
	var tele := state == S.TELEGRAPH
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var rear := -6.0 if tele else 0.0
	var body := Vector2(-2 * fx, -12)
	_legs(body + Vector2(0, 6), 11.0, 3, _chitin(c.darkened(0.35)))
	# bloated acid sac, glowing, swelling when about to spit
	var sac := 9.0 + (2.5 if tele else 0.0) + sin(anim_t * 3.0) * 0.6
	Shade.ball(cv, body + Vector2(-4 * fx, -2), sac, _chitin(Color(0.42, 0.5, 0.18)))
	cv.draw_circle(body + Vector2(-5 * fx, -4), sac * 0.5, Color(0.65, 1.0, 0.3, 0.35 + (0.3 if tele else 0.0)))
	var head := body + Vector2(8 * fx, -6 + rear)
	Shade.ball(cv, head, 5.0, _chitin(c.lightened(0.05)))
	cv.draw_circle(head + Vector2(4 * fx, 0), 2.2, Color(0.15, 0.2, 0.05))   # maw
	if tele:
		cv.draw_circle(head + Vector2(4 * fx, 0), 4.0, Color(0.6, 1.0, 0.2, 0.4))


func _draw_broodguard() -> void:
	var c := Color(0.25, 0.22, 0.2)
	if dead:
		_corpse(16.0, c)
		return
	_shadow(17.0)
	var tele := state == S.TELEGRAPH
	var charging := state == S.ATTACK and attack_variant == "charge"
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var paw := sin(anim_t * 20.0) * 2.0 if tele else 0.0
	var body := Vector2(0, -16)
	_legs(body + Vector2(0, 8), 15.0, 3, _chitin(c.darkened(0.3)), 0.8 if not charging else 2.0)
	# armoured carapace plates
	Shade.ball(cv, body + Vector2(-6 * fx, 0), 12.0, _chitin(c))
	Shade.ball(cv, body + Vector2(3 * fx, -2), 11.0, _chitin(c.lightened(0.06)))
	for i in 3:
		var px := body + Vector2((-10 + i * 7) * fx, -10 + absf(i - 1) * 2.0)
		cv.draw_arc(px, 6.0, PI * 1.1, PI * 1.9, 8, _chitin(c.lightened(0.25)), 1.5)
	# horned head, lowered when charging
	var head := body + Vector2(13 * fx, 2 + (4 if charging else 0) + paw * 0.3)
	Shade.ball(cv, head, 7.0, _chitin(c.lightened(0.12)))
	cv.draw_line(head + Vector2(3 * fx, -3), head + Vector2(13 * fx, -9), _chitin(Color(0.7, 0.66, 0.55)), 3.0)
	cv.draw_line(head + Vector2(3 * fx, 1), head + Vector2(12 * fx, 4), _chitin(Color(0.7, 0.66, 0.55)), 2.0)
	var ec := Color(1.0, 0.25, 0.1) if tele or charging else Color(0.9, 0.6, 0.15)
	cv.draw_circle(head + Vector2(2 * fx, -3), 1.6, ec)
	if tele:
		# dust kicked up while pawing the ground
		cv.draw_circle(Vector2(-8 * fx, -2), 5.0 + paw, Color(0.5, 0.45, 0.4, 0.3))


func _draw_miner() -> void:
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	if dead:
		var f := minf(dead_t * 2.5, 1.0)
		cv.draw_set_transform(Vector2(0, -4), PI * 0.5 * f * fx, Vector2.ONE)
		cv.draw_rect(Rect2(-6, -22, 12, 22), Color(0.55, 0.38, 0.15))
		cv.draw_circle(Vector2(0, -25), 5.5, Color(0.75, 0.6, 0.15))
		cv.draw_set_transform(Vector2.ZERO)
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45))
		cv.draw_circle(Vector2(6 * fx, 0), 14.0 * f, Color(0.3, 0.42, 0.08, 0.6))
		cv.draw_set_transform(Vector2.ZERO)
		return
	_shadow(12.0)
	var tele := state == S.TELEGRAPH
	var lunging := state == S.ATTACK
	var walk := sin(anim_t * 13.0) * 4.0 if velocity.length() > 20 else 0.0
	var shake := Vector2(randf_range(-1.5, 1.5), 0) if tele else Vector2.ZERO
	var hunch := 5.0 if not lunging else 11.0
	# legs (work trousers)
	cv.draw_line(Vector2(-3, -12), Vector2(-4 + walk * 0.5, 0), _col(Color(0.22, 0.2, 0.17)), 3.5)
	cv.draw_line(Vector2(3, -12), Vector2(4 - walk * 0.5, 0), _col(Color(0.22, 0.2, 0.17)), 3.5)
	# orange hi-vis overalls, torn by growths
	var top := Vector2(hunch * fx, -30) + shake
	var suit := PackedVector2Array([top + Vector2(-7, 0), top + Vector2(7, 0), Vector2(8, -11), Vector2(-8, -11)])
	Shade.poly(cv, suit, _col(Color(0.55, 0.32, 0.1)))
	cv.draw_line(top + Vector2(-6, 6), top + Vector2(6, 6), _col(Color(0.75, 0.7, 0.45)), 2.0)   # reflective stripe
	# brood growth bursting out of the back
	for i in 3:
		var gp := top + Vector2((-4 + i * 3) * -fx, 2 + i * 3)
		Shade.ball(cv, gp, 3.5 - i * 0.6, _col(Color(0.42, 0.36, 0.3)))
	cv.draw_circle(top + Vector2(-3 * fx, 4), 1.8, Color(0.7, 1.0, 0.3, 0.7))
	# arms: one clawed, one dragging a pick
	var shoulder := top + Vector2(5 * fx, 3)
	var reach := 17.0 if not lunging else 25.0
	var arm_ang := facing + (-0.9 if tele else 0.3) * fx
	var hand := shoulder + Vector2.from_angle(arm_ang) * reach
	Shade.limb(cv, shoulder, hand, 4.5, _col(Color(0.55, 0.32, 0.1)))
	for i in 3:
		cv.draw_line(hand, hand + Vector2.from_angle(arm_ang + (i - 1) * 0.45) * 7.0, _col(Color(0.5, 0.45, 0.35)), 1.5)
	var off := top + Vector2(-5 * fx, 3)
	var pick := off + Vector2(-6 * fx, 15)
	cv.draw_line(off, pick, _col(Color(0.55, 0.32, 0.1)), 3.0)
	cv.draw_line(pick + Vector2(-4 * fx, -3), pick + Vector2(5 * fx, 2), _col(Color(0.35, 0.35, 0.38)), 2.0)
	# hard hat with a dead lamp, face half swallowed
	var head := top + Vector2(4 * fx, -6)
	Shade.ball(cv, head, 6.0, _col(Color(0.5, 0.42, 0.36)))
	cv.draw_arc(head + Vector2(0, -1), 7.0, PI, TAU, 10, _col(Color(0.78, 0.62, 0.15)), 4.0)
	cv.draw_circle(head + Vector2(5 * fx, -4), 1.5, Color(0.25, 0.25, 0.2))
	var eye := Color(1.0, 0.2, 0.1) if tele else Color(0.6, 1.0, 0.3)
	cv.draw_circle(head + Vector2(3 * fx, 0), 1.5, eye)
	if tele:
		cv.draw_circle(head, 12.0, Color(1.0, 0.1, 0.05, 0.18))


func _draw_burrower() -> void:
	var c := Color(0.4, 0.36, 0.3)
	if buried:
		# barely visible ash mound; bubbles violently just before erupting
		var k := 1.0 if emerge_t > 0.0 else 0.0
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		cv.draw_circle(Vector2.ZERO, 12.0 + k * 4.0, Color(0.0, 0.0, 0.0, 0.12 + k * 0.2))
		cv.draw_set_transform(Vector2.ZERO)
		if k > 0.0:
			for i in 5:
				var a := anim_t * 9.0 + i * 1.3
				cv.draw_circle(Vector2(cos(a) * 9.0, sin(a * 1.3) * 3.0 - 2.0), 2.5, Color(0.55, 0.5, 0.45, 0.8))
		return
	if dead:
		_corpse(13.0, c)
		return
	_shadow(14.0)
	var tele := state == S.TELEGRAPH
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var body := Vector2(0, -12)
	_legs(body + Vector2(0, 6), 12.0, 2, _chitin(c.darkened(0.35)))
	# segmented, flattened body crusted with ash
	for i in 4:
		Shade.ball(cv, body + Vector2((-9 + i * 5) * fx, sin(anim_t * 6.0 + i) * 1.2), 6.5 - absf(i - 2) * 0.8, _chitin(c.lightened(i * 0.03)))
	var head := body + Vector2(11 * fx, -1)
	Shade.ball(cv, head, 6.0, _chitin(c.lightened(0.1)))
	var jaw := 0.7 if tele or state == S.ATTACK else 0.25
	cv.draw_line(head, head + Vector2.from_angle(-jaw) * 9.0 * Vector2(fx, 1), _chitin(Color(0.8, 0.75, 0.6)), 2.0)
	cv.draw_line(head, head + Vector2.from_angle(jaw) * 9.0 * Vector2(fx, 1), _chitin(Color(0.8, 0.75, 0.6)), 2.0)


func _draw_egg() -> void:
	var c := Color(0.42, 0.4, 0.3)
	if dead:
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		cv.draw_circle(Vector2.ZERO, 12.0, Color(0.3, 0.42, 0.1, 0.5))
		cv.draw_set_transform(Vector2.ZERO)
		cv.draw_arc(Vector2(0, -6), 8.0, PI * 1.1, PI * 1.9, 8, c.darkened(0.3), 2.0)
		return
	_shadow(11.0)
	var wob := sin(anim_t * 30.0) * (2.0 if hatch_t > 0.0 else 0.0)
	var pulse := sin(anim_t * 2.0) * 0.6
	for i in 3:
		var off := Vector2((i - 1) * 7.0 + wob * (1 if i == 1 else -0.5), -9 - (4 if i == 1 else 0))
		Shade.ball(cv, off, 6.0 + pulse + (1.0 if i == 1 else 0.0), _col(c.lightened(i * 0.04)))
		cv.draw_circle(off + Vector2(-1, -1), 2.5, Color(0.7, 0.95, 0.4, 0.25 + (0.35 if hatch_t > 0.0 else 0.0)))
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	cv.draw_circle(Vector2.ZERO, 13.0, Color(0.25, 0.22, 0.15, 0.4))   # resin base
	cv.draw_set_transform(Vector2.ZERO)


## Infested Militia: duster coat and wide-brimmed hat, growths through the
## coat, still carrying a long rifle they fire wildly.
func _draw_militia() -> void:
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var coat := Color(0.42, 0.33, 0.22)
	if dead:
		var f := minf(dead_t * 2.5, 1.0)
		cv.draw_set_transform(Vector2(0, -4), PI * 0.5 * f * fx, Vector2.ONE)
		cv.draw_rect(Rect2(-6, -24, 12, 24), coat)
		cv.draw_set_transform(Vector2.ZERO)
		cv.draw_line(Vector2(-14 * fx, -2), Vector2(4 * fx, 2), Color(0.3, 0.22, 0.14), 4.0)   # hat on the ground
		return
	_shadow(12.0)
	var tele := state == S.TELEGRAPH
	var walk := sin(anim_t * 10.0) * 3.0 if velocity.length() > 20 else 0.0
	cv.draw_line(Vector2(-3, -13), Vector2(-4 + walk * 0.5, 0), _col(Color(0.24, 0.2, 0.16)), 3.5)
	cv.draw_line(Vector2(3, -13), Vector2(4 - walk * 0.5, 0), _col(Color(0.24, 0.2, 0.16)), 3.5)
	var top := Vector2(2 * fx, -32)
	var duster := PackedVector2Array([top + Vector2(-7, 0), top + Vector2(7, 0), Vector2(10, -6), Vector2(-10, -6)])
	Shade.poly(cv, duster, _col(coat))
	cv.draw_line(top + Vector2(-2, 4), Vector2(-3, -10), Color(0.25, 0.18, 0.12), 1.0)
	Shade.ball(cv, top + Vector2(-5 * fx, 6), 3.5, _col(Color(0.42, 0.38, 0.3)))             # growth bursting out
	cv.draw_circle(top + Vector2(-5 * fx, 5), 1.4, Color(0.7, 1.0, 0.3, 0.7))
	# rifle levelled at the target
	var aim := Vector2.from_angle(facing) if tele or state == S.ATTACK else Vector2(fx, 0.35).normalized()
	var grip := top + Vector2(5 * fx, 7)
	cv.draw_line(grip - aim * 6.0, grip + aim * 20.0, _col(Color(0.18, 0.16, 0.15)), 3.0)
	cv.draw_line(grip - aim * 6.0, grip + aim * 4.0, _col(Color(0.35, 0.22, 0.12)), 4.0)
	Shade.limb(cv, top + Vector2(5 * fx, 2), grip, 3.5, _col(coat))
	var head := top + Vector2(2 * fx, -6)
	Shade.ball(cv, head, 5.5, _col(Color(0.55, 0.45, 0.38)))
	cv.draw_line(head + Vector2(-9, -2), head + Vector2(9, -2), _col(Color(0.3, 0.22, 0.14)), 3.0)  # hat brim
	cv.draw_rect(Rect2(head + Vector2(-5, -8), Vector2(10, 6)), _col(Color(0.32, 0.24, 0.15)))
	cv.draw_circle(head + Vector2(3 * fx, 1), 1.4, Color(1.0, 0.2, 0.1) if tele else Color(0.6, 1.0, 0.3))
	if tele:
		cv.draw_circle(grip + aim * 20.0, 4.0, Color(1.0, 0.7, 0.3, 0.5))


## Wall Crawler: a long flat many-legged bug. Before it drops it clings high on
## a wall; its shadow appears on the ground where it will land.
func _draw_crawler() -> void:
	var c := Color(0.3, 0.27, 0.22)
	if buried:
		var up := Vector2(0, -44)
		if emerge_t > 0.0:
			var off := Iso.to_screen(drop_target - global_position)
			var k := 1.0 - emerge_t / 0.6
			cv.draw_set_transform(off, 0.0, Vector2(1.0, 0.45))
			cv.draw_circle(Vector2.ZERO, 8.0 + 12.0 * k, Color(0, 0, 0, 0.25 + 0.35 * k))
			cv.draw_set_transform(Vector2.ZERO)
		for i in 3:
			cv.draw_line(up + Vector2(-7, -3 + i * 3), up + Vector2(7, -3 + i * 3), _chitin(c.darkened(0.3)), 1.2)
		Shade.ball(cv, up, 5.0, _chitin(c))
		Shade.ball(cv, up + Vector2(0, -6), 3.5, _chitin(c.lightened(0.1)))
		return
	if dead:
		_corpse(10.0, c)
		return
	_shadow(10.0)
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var body := Vector2(0, -6)
	_legs(body + Vector2(0, 2), 10.0, 4, _chitin(c.darkened(0.3)), 1.6)
	for i in 3:
		Shade.ball(cv, body + Vector2((-6 + i * 5) * fx, 0), 4.5, _chitin(c.lightened(i * 0.04)))
	cv.draw_line(body + Vector2(9 * fx, -1), body + Vector2(15 * fx, -4), _chitin(Color(0.75, 0.7, 0.55)), 1.5)


## The Brood Lieutenant: an oversized, spined Broodguard with the Civic Hall's
## access card glinting in its carapace.
func _draw_lieutenant() -> void:
	var c := Color(0.3, 0.2, 0.18)
	if dead:
		_corpse(22.0, c)
		return
	_shadow(23.0)
	var tele := state == S.TELEGRAPH
	var charging := state == S.ATTACK and attack_variant == "charge"
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var body := Vector2(0, -22)
	_legs(body + Vector2(0, 10), 20.0, 3, _chitin(c.darkened(0.3)), 0.9 if not charging else 2.2)
	Shade.ball(cv, body + Vector2(-8 * fx, 0), 16.0, _chitin(c))
	Shade.ball(cv, body + Vector2(5 * fx, -3), 14.0, _chitin(c.lightened(0.06)))
	for i in 5:
		var sp := body + Vector2((-16 + i * 7) * fx, -12 - absf(i - 2) * 2.0)
		cv.draw_line(sp, sp + Vector2(-2 * fx, -12 + absf(i - 2) * 2.0), _chitin(Color(0.75, 0.68, 0.5)), 2.5)   # spines
	# the access card, fused into the carapace
	var card := body + Vector2(-2 * fx, -6)
	cv.draw_rect(Rect2(card - Vector2(4, 3), Vector2(8, 6)), Color(0.85, 0.7, 0.3))
	cv.draw_rect(Rect2(card - Vector2(3, 2), Vector2(3, 2)), Color(0.3, 0.25, 0.15))
	var head := body + Vector2(17 * fx, 3 + (5 if charging else 0))
	Shade.ball(cv, head, 9.0, _chitin(c.lightened(0.12)))
	cv.draw_line(head + Vector2(4 * fx, -4), head + Vector2(18 * fx, -12), _chitin(Color(0.8, 0.74, 0.6)), 4.0)
	cv.draw_line(head + Vector2(4 * fx, 2), head + Vector2(16 * fx, 6), _chitin(Color(0.8, 0.74, 0.6)), 3.0)
	cv.draw_circle(head + Vector2(3 * fx, -4), 2.0, Color(1.0, 0.25, 0.1) if tele or charging else Color(1.0, 0.6, 0.15))
	cv.draw_arc(Vector2(0, -2), radius + 8.0, 0, TAU, 24, Color(1.0, 0.6, 0.2, 0.25 + 0.15 * sin(anim_t * 4.0)), 2.0)   # champion aura


## Canopy Stalker: a long-limbed brood hunter that hangs in the trees, then drops.
func _draw_stalker() -> void:
	var c := Color(0.18, 0.26, 0.14)
	if buried:
		var up := Vector2(0, -50)
		if emerge_t > 0.0:
			var off := Iso.to_screen(drop_target - global_position)
			var k := 1.0 - emerge_t / 0.6
			cv.draw_set_transform(off, 0.0, Vector2(1.0, 0.45))
			cv.draw_circle(Vector2.ZERO, 9.0 + 14.0 * k, Color(0, 0, 0, 0.25 + 0.35 * k))
			cv.draw_set_transform(Vector2.ZERO)
		cv.draw_line(up + Vector2(0, -18), up, Color(0.25, 0.3, 0.2, 0.6), 1.0)   # hanging thread
		Shade.ball(cv, up, 6.0, _chitin(c))
		cv.draw_circle(up + Vector2(2, 2), 1.2, Color(1.0, 0.6, 0.2))
		return
	if dead:
		_corpse(12.0, c)
		return
	_shadow(12.0)
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	var body := Vector2(0, -16)
	_legs(body + Vector2(0, 8), 16.0, 2, _chitin(c.darkened(0.25)), 1.3)
	Shade.ball(cv, body, 8.0, _chitin(c))
	Shade.ball(cv, body + Vector2(-7 * fx, 2), 6.0, _chitin(c.darkened(0.1)))
	var head := body + Vector2(9 * fx, -4)
	Shade.ball(cv, head, 4.5, _chitin(c.lightened(0.15)))
	cv.draw_line(head, head + Vector2(10 * fx, 6), _chitin(Color(0.75, 0.7, 0.5)), 2.0)   # scythe arm
	cv.draw_circle(head + Vector2(2 * fx, -1), 1.3, Color(1.0, 0.6, 0.2))


## Gibberer: a small, quick, long-armed primate with a pale face, always a rock in hand.
func _draw_gibberer() -> void:
	var fur := Color(0.32, 0.24, 0.17)
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	if dead:
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		cv.draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.05, 0.03, 0.5))
		cv.draw_set_transform(Vector2.ZERO)
		Shade.ball(cv, Vector2(0, -4), 6.0, fur.darkened(0.3))
		return
	_shadow(9.0)
	var tele := state == S.TELEGRAPH
	var hop := absf(sin(anim_t * 12.0)) * 3.0 if velocity.length() > 20 else 0.0
	var body := Vector2(0, -12 - hop)
	Shade.limb(cv, body + Vector2(-2, 4), Vector2(-4, 0), 2.6, _col(fur.darkened(0.2)))
	Shade.limb(cv, body + Vector2(2, 4), Vector2(4, 0), 2.6, _col(fur.darkened(0.2)))
	Shade.ball(cv, body, 6.5, _col(fur))
	var head := body + Vector2(3 * fx, -8)
	Shade.ball(cv, head, 4.6, _col(fur.lightened(0.05)))
	cv.draw_circle(head + Vector2(1.5 * fx, 0.5), 2.6, _col(Color(0.72, 0.62, 0.52)))           # pale face
	cv.draw_circle(head + Vector2(2.5 * fx, 0), 0.9, Color(0.08, 0.05, 0.04))
	cv.draw_line(head + Vector2(1 * fx, 2.4), head + Vector2(3.5 * fx, 2.2), Color(0.25, 0.08, 0.06), 1.0)
	var arm_up := tele or state == S.ATTACK
	var hand := body + (Vector2(-4 * fx, -16) if arm_up else Vector2(8 * fx, 6))
	Shade.limb(cv, body + Vector2(4 * fx, -2), hand, 2.4, _col(fur))
	Shade.ball(cv, hand + Vector2(0, -2), 3.0, Color(0.45, 0.42, 0.36))                         # the rock
	Shade.limb(cv, body + Vector2(-4 * fx, -2), body + Vector2(-8 * fx, 7), 2.4, _col(fur))
	cv.draw_line(body + Vector2(-5 * fx, 3), body + Vector2(-14 * fx, -4 + sin(anim_t * 8.0) * 3.0), _col(fur.darkened(0.2)), 2.0)   # tail


## Thornback: a huge, armoured ape brute with a ridge of bony thorns down its back.
## The Elder is bigger and greyer, with an aura (champion).
func _draw_thornback() -> void:
	var elder := kind == "elder_thornback"
	var fur := Color(0.26, 0.2, 0.16) if not elder else Color(0.45, 0.42, 0.38)
	var plate := Color(0.42, 0.38, 0.33)
	var s := 1.25 if elder else 1.0
	var fx := 1.0 if cos(facing) >= 0.0 else -1.0
	if dead:
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		cv.draw_circle(Vector2.ZERO, 20.0 * s, Color(0.35, 0.05, 0.03, 0.55))
		cv.draw_set_transform(Vector2.ZERO)
		Shade.ball(cv, Vector2(0, -8) * s, 14.0 * s, fur.darkened(0.3))
		return
	_shadow(19.0 * s)
	var tele := state == S.TELEGRAPH
	var pounding := attack_variant == "pound" and (tele or state == S.ATTACK)
	var breathe := sin(anim_t * 2.0) * 1.0
	var body := Vector2(-2 * fx, -26 + breathe) * s
	# knuckle-walking forearms, thick legs
	for side in [-1.0, 1.0]:
		var sh := body + Vector2(side * 11, 4) * s
		var fist := Vector2(side * 13 + 6 * fx, -2 - (14 if pounding and tele else 0)) * s
		Shade.limb(cv, sh, fist, 6.0 * s, _col(fur))
		Shade.ball(cv, fist, 4.8 * s, _col(fur.darkened(0.15)))
		Shade.limb(cv, body + Vector2(side * 6, 14) * s, Vector2(side * 7, 0) * s, 5.5 * s, _col(fur.darkened(0.2)))
	Shade.ball(cv, body, 15.0 * s, _col(fur))
	Shade.ball(cv, body + Vector2(0, -4) * s, 12.0 * s, _col(fur.lightened(0.05)))
	for i in 5:   # bony thorns down the back
		var tp := body + Vector2((-10 + i * 5) * -fx, -12 + absf(i - 2) * 2.5) * s
		cv.draw_colored_polygon(PackedVector2Array([tp + Vector2(-2.5, 2) * s, tp + Vector2(2.5, 2) * s, tp + Vector2(-1 * fx, -8) * s]), _col(plate.lightened(0.1)))
	var head := body + Vector2(12 * fx, -6) * s
	Shade.ball(cv, head, 7.0 * s, _col(fur.darkened(0.1)))
	cv.draw_arc(head + Vector2(0, -2) * s, 6.0 * s, PI * 1.1, PI * 1.9, 8, _col(plate), 3.0 * s)   # armoured brow
	var ec := Color(1.0, 0.25, 0.1) if tele else Color(0.9, 0.7, 0.3)
	cv.draw_circle(head + Vector2(2 * fx, 0) * s, 1.4 * s, ec)
	cv.draw_line(head + Vector2(3 * fx, 3) * s, head + Vector2(7 * fx, 3) * s, Color(0.9, 0.86, 0.75), 1.5)   # tusks
	if tele and not pounding:
		Shade.ball(cv, body + Vector2(-4 * fx, -26) * s, 7.0 * s, Color(0.42, 0.4, 0.36))   # boulder overhead
	if elder:
		cv.draw_arc(Vector2(0, -4), radius + 8.0, 0, TAU, 24, Color(1.0, 0.6, 0.2, 0.25 + 0.15 * sin(anim_t * 4.0)), 2.0)

