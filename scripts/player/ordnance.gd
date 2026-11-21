class_name Ordnance
## The Siegebreaker Doctrine's explosives (requirements 15.14). Pure abilities:
## thrown and planted charges, no weapons. Numbers come from data/doctrines.json
## ("dmg": [base, per level], "radius", "range"), scaled by Intelligence and the
## Blast Discipline passive (GameState.explosive_mult / explosive_radius_mult).
##   sb_concussion  arcing grenade: blast, knockback, short daze
##   sb_semtex      sticky charge: clings to the enemy it hits, big blast after 1.5 s
##   sb_incendiary  canister: burning zone for 5 s (+25% vs the Brood)
##   sb_strike      Danger Close: 2 s targeting marker, then an orbital barrage
## Shrapnel and Chain Reaction (passives) hook into every blast via explode().

const DAZE := 0.8


static func _def(id: String) -> Dictionary:
	return GameState.skill_def(id)


static func damage(id: String) -> float:
	var d: Array = _def(id).get("dmg", [20, 4])
	return (float(d[0]) + float(d[1]) * float(GameState.level)) * GameState.explosive_mult()


static func radius(id: String) -> float:
	return float(_def(id).get("radius", 90)) * GameState.explosive_radius_mult()


## Throws / triggers an ordnance ability from the player toward `aim`.
static func use(id: String, p: Player, aim: Vector2) -> void:
	var world := p.get_parent()
	var from := p.global_position
	var to := aim
	var rng := float(_def(id).get("range", 400))
	if from.distance_to(to) > rng:
		to = from + (to - from).normalized() * rng
	match id:
		"sb_concussion":
			var land_c := func(pos: Vector2) -> void:
				Ordnance.explode(world, pos, Ordnance.radius(id), Ordnance.damage(id), 280.0, DAZE, p, true, Color(1.0, 0.85, 0.5))
			_lob(world, p, to, Color(0.95, 0.85, 0.5), land_c)
			Audio.play("grenade_launch", from, 1.2)
		"sb_semtex":
			var land_s := func(pos: Vector2) -> void:
				var c := SemtexCharge.new()
				c.setup(pos, Ordnance.radius(id), Ordnance.damage(id), p)
				world.add_child(c)
			_lob(world, p, to, Color(1.0, 0.45, 0.2), land_s, true)
			Audio.play("grenade_launch", from, 0.9)
		"sb_incendiary":
			var land_i := func(pos: Vector2) -> void:
				var z := FireZone.new()
				z.setup(pos, Ordnance.radius(id), Ordnance.damage(id), float(Ordnance._def(id).get("duration", 5)), p)
				world.add_child(z)
			_lob(world, p, to, Color(1.0, 0.5, 0.1), land_i)
			Audio.play("grenade_launch", from, 0.8)
		"sb_strike":
			var s := OrbitalStrike.new()
			s.setup(to, radius(id), damage(id), p)
			world.add_child(s)
			Events.msg("[OVERWATCH] Danger close. Strike inbound. Get clear!", Color(0.55, 0.85, 1.0))


## A thrown charge: flies over enemies (walls stop it) to the target point. With
## `stick`, it stops on the first enemy it touches instead.
static func _lob(world: Node, p: Player, to: Vector2, col: Color, on_land: Callable, stick := false) -> void:
	var from := p.global_position
	var mask := Combat.LAYER_WORLD | (Combat.LAYER_ENEMY if stick else 0)
	var h := Combat.make_hit(0.0, p, false)
	var pr := Projectile.fire(world, from, (to - from).normalized() * 560.0, h, mask, maxf(8.0, from.distance_to(to)), col)
	pr.exclude = [p.get_rid()]
	pr.thickness = 4.0
	pr.length = 4.0
	pr.glow = true
	pr.draw_offset = Vector2(0, -20)
	pr.on_impact = on_land


## A blast from the operative's ordnance: damages and knocks back enemies in
## `r`, optionally dazes them. Shrapnel adds a ring of fragments outside the
## blast; Chain Reaction makes enemies it kills explode too (no further chains).
static func explode(world: Node, pos: Vector2, r: float, dmg: float, kb: float, daze: float, src: Node, chain_ok: bool, col := Color(1.0, 0.6, 0.25)) -> void:
	Fx.ring(world, Iso.sp(pos), r, col, 0.45, 10.0)
	Fx.burst(world, Iso.sp(pos, 6), col, 22, 280.0)
	Audio.play("explosion", pos, randf_range(0.9, 1.1))
	Events.screen_shake.emit(minf(10.0, 3.0 + r * 0.04))
	var shrapnel := GameState.has_skill("sb_shrapnel")
	var killed: Array = []
	for e in world.get_tree().get_nodes_in_group("enemies"):
		var en := e as Actor
		if en == null or en.dead:
			continue
		var d := en.global_position.distance_to(pos)
		var reach := r + float(en.get("radius"))
		var amount := 0.0
		if d <= reach:
			amount = dmg * (1.0 - 0.4 * clampf(d / reach, 0.0, 1.0))
		elif shrapnel and d <= reach * 1.5:
			amount = dmg * 0.35
		if amount <= 0.0:
			continue
		var h := Combat.make_hit(amount, src, randf() < GameState.crit_chance() * 0.5)
		h["dir"] = (en.global_position - pos).normalized()
		h["knockback"] = kb if d <= reach else kb * 0.3
		h["color"] = col
		h["explosive"] = true
		en.take_hit(h)
		if d <= reach and daze > 0.0 and not en.dead:
			en.apply_status("stun")
		if en.dead:
			killed.append(en.global_position)
	if shrapnel:
		Fx.burst(world, Iso.sp(pos, 8), Color(0.85, 0.8, 0.7), 14, 420.0)
	if chain_ok and GameState.has_skill("sb_chain"):
		for kp in killed:
			explode(world, kp, 50.0 * GameState.explosive_radius_mult(), dmg * 0.4, 160.0, 0.0, src, false, Color(1.0, 0.45, 0.2))


# ---------------------------------------------------------------- charges

## Semtex: clings to the enemy it landed on (or sits on the floor), beeps, blows.
class SemtexCharge extends Node2D:
	const FUSE := 1.5
	var r := 110.0
	var dmg := 60.0
	var src: Node
	var host: Node2D = null
	var offset := Vector2.ZERO
	var t := 0.0
	var cv: IsoView

	func setup(pos: Vector2, p_r: float, p_dmg: float, p_src: Node) -> void:
		position = pos
		r = p_r
		dmg = p_dmg
		src = p_src

	func _ready() -> void:
		add_to_group("player_ordnance")
		var best := 30.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Actor
			if en != null and not en.dead and en.global_position.distance_to(global_position) < best:
				best = en.global_position.distance_to(global_position)
				host = en
		if host != null:
			offset = global_position - host.global_position
		cv = IsoView.attach(self)

	func _physics_process(delta: float) -> void:
		t += delta
		if host != null and is_instance_valid(host) and not bool(host.get("dead")):
			global_position = host.global_position + offset
		if int(t * 6.0) != int((t - delta) * 6.0):
			Audio.play_ui("terminal", 1.8 + t * 0.4, -14.0)
		if t >= FUSE:
			Ordnance.explode(get_parent(), global_position, r, dmg, 360.0, 0.0, src, true, Color(1.0, 0.5, 0.2))
			queue_free()

	func _render() -> void:
		var h := -18.0 if host != null else -4.0
		cv.draw_rect(Rect2(-4, h - 3, 8, 6), Color(0.35, 0.3, 0.22))
		var blink := int(t * (6.0 + t * 8.0)) % 2 == 0
		cv.draw_circle(Vector2(0, h - 4), 2.0, Color(1.0, 0.25, 0.1) if blink else Color(0.4, 0.1, 0.05))


## Incendiary: a burning zone; enemies standing in it burn (+25% vs organics).
class FireZone extends Node2D:
	var r := 85.0
	var dps := 10.0
	var life := 5.0
	var src: Node
	var t := 0.0
	var tick := 0.0
	var cv: IsoView
	var light: PointLight2D

	func setup(pos: Vector2, p_r: float, p_dps: float, p_life: float, p_src: Node) -> void:
		position = pos
		r = p_r
		dps = p_dps
		life = p_life
		src = p_src

	func _ready() -> void:
		add_to_group("player_ordnance")
		cv = IsoView.attach(self)
		cv.z_index = -1
		light = PointLight2D.new()
		light.range_item_cull_mask = 3
		light.height = 150.0
		light.texture = LightUtil.radial(256)
		light.color = Color(1.0, 0.5, 0.15)
		light.energy = 1.0
		light.texture_scale = r / 110.0
		light.scale = Vector2(1.0, 0.6)
		cv.add_child(light)
		Audio.play("explosion", global_position, 1.4, -6.0)

	func _physics_process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
			return
		light.energy = (0.8 + 0.25 * sin(t * 11.0)) * clampf((life - t) / 0.8, 0.0, 1.0)
		tick -= delta
		if tick > 0.0:
			return
		tick = 0.5
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Actor
			if en == null or en.dead or en.global_position.distance_to(global_position) > r + float(en.get("radius")):
				continue
			var mult := 1.25 if bool((en as Enemy).def.get("organic", false)) or (en as Enemy).kind == "researcher" else 1.0
			var h := Combat.make_hit(dps * 0.5 * mult, src, false)
			h["dot"] = true
			h["pierce_armor"] = true
			h["color"] = Color(1.0, 0.5, 0.1)
			en.take_hit(h)
			en.apply_status("burn")

	func _render() -> void:
		var fade := clampf((life - t) / 0.8, 0.0, 1.0)
		Iso.ground(cv)
		cv.draw_circle(Vector2.ZERO, r, Color(0.25, 0.06, 0.02, 0.45 * fade))
		cv.draw_circle(Vector2.ZERO, r * 0.7, Color(0.6, 0.18, 0.04, 0.35 * fade))
		cv.draw_set_transform(Vector2.ZERO)
		for i in 10:
			var a := float(i) * 2.4
			var rr := r * (0.25 + 0.7 * fmod(float(i) * 0.37, 1.0))
			var p := Iso.to_screen(Vector2.from_angle(a) * rr)
			var ph := t * 10.0 + i
			var h := (8.0 + 6.0 * absf(sin(ph))) * fade
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(sin(ph) * 2.0, -h)]), Color(1.0, 0.5 + 0.2 * sin(ph), 0.1, 0.85 * fade))


## Danger Close: a targeting marker for 2 s, then shells rain over the area.
class OrbitalStrike extends Node2D:
	const MARK := 2.0
	const SHELLS := 9
	var r := 170.0
	var dmg := 45.0
	var src: Node
	var t := 0.0
	var fired := 0
	var cv: IsoView

	func setup(pos: Vector2, p_r: float, p_dmg: float, p_src: Node) -> void:
		position = pos
		r = p_r
		dmg = p_dmg
		src = p_src

	func _ready() -> void:
		add_to_group("player_ordnance")
		cv = IsoView.attach(self)
		cv.z_index = -1
		Audio.play("boss_alarm", global_position, 1.3, -6.0)

	func _physics_process(delta: float) -> void:
		t += delta
		if t < MARK:
			return
		var due := mini(SHELLS, int((t - MARK) / 0.14) + 1)
		while fired < due:
			fired += 1
			var p := global_position + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r
			Ordnance.explode(get_parent(), p, 70.0 * GameState.explosive_radius_mult(), dmg, 300.0, 0.0, src, true, Color(0.7, 0.85, 1.0))
		if fired >= SHELLS:
			queue_free()

	func _render() -> void:
		if t >= MARK:
			return
		var k := t / MARK
		Iso.ground(cv)
		cv.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.5, 0.8, 1.0, 0.4 + 0.4 * sin(t * 12.0)), 2.0)
		cv.draw_arc(Vector2.ZERO, r * (1.0 - k), 0, TAU, 32, Color(0.6, 0.9, 1.0, 0.8), 2.0)
		cv.draw_line(Vector2(-r, 0), Vector2(r, 0), Color(0.5, 0.8, 1.0, 0.35), 1.0)
		cv.draw_line(Vector2(0, -r), Vector2(0, r), Color(0.5, 0.8, 1.0, 0.35), 1.0)
		cv.draw_set_transform(Vector2.ZERO)
