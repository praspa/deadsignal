class_name Player
extends Actor
## The operative. Reads input, fires weapons, runs abilities and draws itself.
## Character data (stats, gear, ammo) lives in GameState; this node is the body.

const BASE_SPEED := 205.0
const ROLL_SPEED := 560.0
const ROLL_TIME := 0.3
const INTERACT_RANGE := 58.0

const ABIL := {
	"roll":       {"cd": 2.0,  "cost": 10.0, "name": "Tactical Roll"},
	"overcharge": {"cd": 18.0, "cost": 25.0, "name": "Overcharge"},
	"pulse":      {"cd": 9.0,  "cost": 30.0, "name": "Disruptor Pulse"},
}

var aim_dir := Vector2.RIGHT
var aim_point := Vector2.ZERO
var facing := 0.0
var walk_t := 0.0
var moving := false
var fire_cd := {"primary": 0.0, "secondary": 0.0}
var reload_t := {"primary": 0.0, "secondary": 0.0}
var reload_uid := {"primary": -1, "secondary": -1}
var muzzle_t := 0.0
var swing_t := 0.0
var swing_dir := 0.0
var roll_t := 0.0
var roll_dir := Vector2.ZERO
var invuln_t := 0.0
var cooldowns := {"roll": 0.0, "overcharge": 0.0, "pulse": 0.0}
var overcharge_t := 0.0
var trail: Array = []
var interact_target: Node = null
var hovered_enemy: Node = null
var controls_enabled := true
var death_t := 0.0
var _light: PointLight2D       # lights the floor, casts wall shadows
var _cone: PointLight2D        # flashlight on the floor, casts wall shadows
var _body_light: PointLight2D  # same lights for walls / actors (no shadows)
var _body_cone: PointLight2D
var _last_hint_t := 0.0
var aim_override: Variant = null
var race := GameState.DEFAULT_RACE   # which RACE_LOOK to draw
var input_grace := 0.0             # ignore actions briefly after a menu closes   # Vector2 to force aim (automated tests)


func _ready() -> void:
	add_to_group("player")
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	shape.shape = c
	add_child(shape)
	cv = IsoView.attach(self)
	# Shadows: the floor (light layer 2) is lit by shadow-casting copies of the
	# player's lights, so walls and big props throw hard shadows across it.
	# Walls and actors (layer 1) get unshadowed copies, so their own faces
	# never fall into their shadows.
	_light = _make_light(LightUtil.radial(256), 1.45, 1.15, Color(1.0, 0.84, 0.66), Level.LIGHT_FLOOR, true)
	_light.scale = Vector2(1.0, 0.6)
	_body_light = _make_light(LightUtil.radial(256), 1.45, 0.9, Color(1.0, 0.84, 0.66), 1, false)
	_body_light.scale = Vector2(1.0, 0.6)
	_body_light.position = Vector2(0, -14)
	_cone = _make_light(LightUtil.cone(), 1.0, 1.4, Color(1.0, 0.95, 0.82), Level.LIGHT_FLOOR, true)
	_body_cone = _make_light(LightUtil.cone(), 1.0, 1.0, Color(1.0, 0.95, 0.82), 1, false)
	for l in [_cone, _body_cone]:
		(l as PointLight2D).offset = Vector2(256, 0)
	sync_from_state()
	Events.leveled_up.connect(_on_leveled_up)


func _make_light(tex: Texture2D, tex_scale: float, energy: float, col: Color, item_mask: int, shadows: bool) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = tex_scale
	l.energy = energy
	l.color = col
	l.height = 150.0
	l.range_item_cull_mask = item_mask
	if shadows:
		l.shadow_enabled = true
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 2.5
		l.shadow_color = Color(0, 0, 0, 1)
	cv.add_child(l)
	return l


func _on_leveled_up(_lv: int) -> void:
	max_hp = GameState.max_hp()
	hp = max_hp
	GameState.hp = hp
	Fx.ring(get_parent(), Iso.sp(global_position, 14), 60.0, Color(1.0, 0.85, 0.3), 0.6, 6.0)
	Audio.play_ui("levelup")


func sync_from_state() -> void:
	race = GameState.race_id
	max_hp = GameState.max_hp()
	hp = clampf(GameState.hp, 1.0, max_hp)
	armor = GameState.armor()


func status_resist() -> float:
	return GameState.status_resist()


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if dead:
		death_t += delta
		queue_redraw()
		return
	GameState.play_time += delta
	max_hp = GameState.max_hp()
	armor = GameState.armor()
	_tick_timers(delta)
	process_statuses(delta)
	if dead:
		return
	_update_aim()
	_handle_movement(delta)
	if controls_enabled:
		_handle_actions()
	_update_interact()
	_update_hover()
	# regen
	hp = minf(max_hp, hp + GameState.hp_regen() * delta)
	var regen := GameState.energy_regen()
	if has_status("toxin"):
		regen *= 0.5
	GameState.energy = minf(GameState.max_energy(), GameState.energy + regen * delta)
	GameState.hp = hp
	# flashlight cone lies on the floor: rotate in world space, then project
	var cone_xf := Transform2D(Iso.M.x, Iso.M.y, Vector2(0, -2)) * Transform2D(facing, Vector2.ZERO)
	_cone.transform = cone_xf
	_body_cone.transform = cone_xf
	queue_redraw()


func _tick_timers(delta: float) -> void:
	for k in cooldowns:
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	for s in fire_cd:
		fire_cd[s] = maxf(0.0, float(fire_cd[s]) - delta)
	for s in reload_t:
		if float(reload_t[s]) > 0.0:
			reload_t[s] = float(reload_t[s]) - delta
			if float(reload_t[s]) <= 0.0:
				_finish_reload(s)
	muzzle_t = maxf(0.0, muzzle_t - delta)
	swing_t = maxf(0.0, swing_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	flash = maxf(0.0, flash - delta)
	if overcharge_t > 0.0:
		overcharge_t -= delta
		if overcharge_t <= 0.0:
			Events.msg("Overcharge depleted.", Color(0.6, 0.6, 0.6))


func _update_aim() -> void:
	if aim_override != null:
		aim_point = aim_override
		aim_dir = (aim_point - global_position).normalized()
		facing = aim_dir.angle()
		return
	var stick := InputSetup.aim_vector()
	if InputSetup.using_pad:
		if stick.length() > 0.3:
			aim_dir = Iso.to_world(stick).normalized()   # stick points on screen
		else:
			var mv := Iso.input_to_world(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
			if mv.length() > 0.3:
				aim_dir = mv.normalized()
		# light aim assist toward the closest enemy in a narrow cone
		var best: Node2D = null
		var best_score := 0.94
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Node2D
			var to := en.global_position - global_position
			var dist := to.length()
			if dist > 520.0 or dist < 1.0:
				continue
			var dot := aim_dir.dot(to / dist)
			if dot > best_score:
				best_score = dot
				best = en
		if best != null:
			aim_dir = aim_dir.lerp((best.global_position - global_position).normalized(), 0.5).normalized()
		aim_point = global_position + aim_dir * 240.0
	else:
		# the cursor points at bodies (drawn ~16px above their feet); aim on the ground plane
		aim_point = Iso.to_world(get_global_mouse_position() + Vector2(0, 16))
		var d := aim_point - global_position
		if d.length() > 4.0:
			aim_dir = d.normalized()
	facing = aim_dir.angle()


func _handle_movement(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Iso.input_to_world(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if roll_t > 0.0:
		roll_t -= delta
		velocity = roll_dir * ROLL_SPEED
		trail.append(global_position)
		if trail.size() > 6:
			trail.pop_front()
		if roll_t <= 0.0:
			collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	else:
		if not trail.is_empty():
			trail.pop_front()
		var spd := BASE_SPEED * GameState.move_mult() * slow_factor()
		if is_stunned():
			spd = 0.0
		velocity = input.limit_length(1.0) * spd
	velocity += apply_knockback(delta)
	moving = velocity.length() > 10.0
	if moving:
		walk_t += delta * (velocity.length() / BASE_SPEED)
	move_and_slide()


func _handle_actions() -> void:
	if input_grace > 0.0:
		input_grace -= get_physics_process_delta_time()
		return
	if is_stunned():
		return
	if Input.is_action_just_pressed("roll"):
		_try_roll()
	if Input.is_action_just_pressed("overcharge"):
		_try_overcharge()
	if Input.is_action_just_pressed("pulse"):
		_try_pulse()
	if Input.is_action_just_pressed("reload"):
		start_reload("primary")
	if Input.is_action_just_pressed("use_stim"):
		_use_stim()
	if Input.is_action_just_pressed("swap_weapons"):
		GameState.swap_weapons()
	if Input.is_action_just_pressed("interact") and interact_target != null and is_instance_valid(interact_target):
		interact_target.call("interact", self)
	if roll_t > 0.0:
		return
	if Input.is_action_pressed("fire_primary"):
		fire("primary")
	if Input.is_action_pressed("fire_secondary"):
		fire("secondary")


# ---------------------------------------------------------------- weapons

func weapon(slot: String) -> Dictionary:
	return GameState.equipment.get(slot, {})


func damage_mult(item: Dictionary) -> float:
	var w: Dictionary = item["weapon"]
	var m := 1.0
	match String(w["type"]):
		"melee":
			m = GameState.melee_mult()
		"energy":
			m = (GameState.ranged_mult() + GameState.tech_mult()) * 0.5
		_:
			m = GameState.ranged_mult()
	m *= 1.0 + float(item.get("stats", {}).get("damage_pct", 0.0)) / 100.0
	if overcharge_t > 0.0:
		m *= 1.4 + GameState.attr("int") * 0.01
	return m


func fire_rate(item: Dictionary) -> float:
	var r := float(item["weapon"]["rate"]) * (1.0 + float(item.get("stats", {}).get("rate_pct", 0.0)) / 100.0)
	if overcharge_t > 0.0:
		r *= 1.35
	return r


## Ground-plane muzzle position (projectiles are simulated on the ground plane).
func muzzle_pos() -> Vector2:
	return global_position + aim_dir * 24.0 + aim_dir.orthogonal() * 4.0


const SHOT_HEIGHT := Vector2(0, -16)


func _base_hit(item: Dictionary) -> Dictionary:
	var w: Dictionary = item["weapon"]
	var roll := Combat.roll_damage(float(w["dmg"][0]), float(w["dmg"][1]), damage_mult(item), GameState.crit_chance())
	var h := Combat.make_hit(float(roll[0]), self, bool(roll[1]))
	h["knockback"] = float(w.get("knockback", 0.0)) / float(w.get("pellets", 1))
	if w.has("status"):
		h["status"] = w["status"]
		h["status_chance"] = float(w["status_chance"])
	match String(item.get("special", "")):
		"incendiary":
			h["status"] = "burn"
			h["status_chance"] = 0.3
		"arc":
			h["status"] = "shock"
			h["status_chance"] = 0.3
		"vampiric":
			h["lifesteal"] = 0.05
	return h


func fire(slot: String) -> void:
	var item := weapon(slot)
	if item.is_empty():
		return
	if float(reload_t[slot]) > 0.0 and int(reload_uid[slot]) != int(item.get("uid", -2)):
		reload_t[slot] = 0.0   # weapon was swapped mid-reload
	if float(fire_cd[slot]) > 0.0 or float(reload_t[slot]) > 0.0:
		return
	var w: Dictionary = item["weapon"]
	var mode: String = w["mode"]
	if mode == "projectile" and int(item.get("loaded", 0)) <= 0:
		start_reload(slot)
		return
	if mode == "hitscan":
		var cost := float(w.get("energy_cost", 0))
		if GameState.energy < cost:
			_hint("Not enough energy.")
			return
		GameState.energy -= cost
	fire_cd[slot] = 1.0 / fire_rate(item)
	match mode:
		"projectile":
			_fire_projectile(item)
		"hitscan":
			_fire_hitscan(item)
		"melee":
			_melee(item)


func _fire_projectile(item: Dictionary) -> void:
	var w: Dictionary = item["weapon"]
	item["loaded"] = int(item["loaded"]) - 1
	var pellets := int(w.get("pellets", 1))
	var spread := deg_to_rad(float(w.get("spread", 0.0))) * GameState.spread_mult()
	var from := muzzle_pos()
	var col := Color(1.0, 0.75, 0.3) if overcharge_t <= 0.0 else Color(1.0, 0.45, 0.2)
	for i in pellets:
		var a := aim_dir.angle()
		if pellets > 1:
			a += lerpf(-spread * 0.5, spread * 0.5, (float(i) + randf()) / float(pellets))
		else:
			a += randf_range(-spread * 0.5, spread * 0.5)
		var dir := Vector2.from_angle(a)
		var p := Projectile.fire(get_parent(), from, dir * float(w["speed"]) * randf_range(0.92, 1.08), _base_hit(item),
			Combat.LAYER_WORLD | Combat.LAYER_ENEMY, float(w["range"]) * randf_range(0.9, 1.05), col)
		p.start_from = global_position
		p.exclude = [get_rid()]
		if String(w["type"]) == "shotgun":
			p.length = 8.0
	muzzle_t = 0.06
	Audio.play("shotgun" if String(w["type"]) == "shotgun" else "rifle", global_position)
	Events.screen_shake.emit(1.6 if pellets == 1 else 4.5)
	knock -= aim_dir * (12.0 if pellets == 1 else 60.0)
	if int(item["loaded"]) <= 0:
		start_reload(_slot_of(item))


func _fire_hitscan(item: Dictionary) -> void:
	var w: Dictionary = item["weapon"]
	var from := muzzle_pos()
	var spread := deg_to_rad(float(w.get("spread", 0.0))) * GameState.spread_mult()
	var dir := aim_dir.rotated(randf_range(-spread, spread) * 0.5)
	var to := from + dir * float(w["range"])
	var q := PhysicsRayQueryParameters2D.create(global_position, to, Combat.LAYER_WORLD | Combat.LAYER_ENEMY, [get_rid()])
	var res := get_world_2d().direct_space_state.intersect_ray(q)
	var end := to
	var beam_col := Color(0.4, 0.75, 1.0) if overcharge_t <= 0.0 else Color(0.9, 0.5, 1.0)
	if not res.is_empty():
		end = res["position"]
		var col: Object = res["collider"]
		if col != null and col.has_method("take_hit"):
			var h := _base_hit(item)
			h["dir"] = dir
			h["color"] = Color(0.6, 0.85, 1.0)
			col.call("take_hit", h)
		Fx.burst(get_parent(), Iso.sp(end) + SHOT_HEIGHT, beam_col, 7, 150.0, -dir, 1.0)
	Fx.beam(get_parent(), Iso.sp(from) + SHOT_HEIGHT, Iso.sp(end) + SHOT_HEIGHT, beam_col, 2.5, 0.1)
	muzzle_t = 0.05
	Audio.play("laser", global_position, 1.25 if overcharge_t > 0.0 else 1.0)
	Events.screen_shake.emit(1.2)


func _melee(item: Dictionary) -> void:
	var w: Dictionary = item["weapon"]
	var reach := float(w["range"])
	var arc := deg_to_rad(float(w.get("arc", 100.0)))
	swing_t = 0.18
	swing_dir = facing
	var col := Color(0.6, 0.85, 1.0) if String(w.get("status", "")) == "stun" else Color(1.0, 0.35, 0.2)
	Fx.slash(get_parent(), Iso.sp(global_position, 10), facing, reach * 0.8, arc, col)
	match String(item.get("base", "")):
		"chainblade":
			Audio.play("chainblade", global_position)
		"power_maul":
			Audio.play("swing_heavy", global_position)
		_:
			Audio.play("swing", global_position)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Actor
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		var r := reach + float(en.get("radius"))
		if to.length() > r:
			continue
		if absf(angle_difference(facing, to.angle())) > arc * 0.5 and to.length() > 26.0:
			continue
		var h := _base_hit(item)
		h["dir"] = to.normalized()
		en.take_hit(h)
		Fx.blood(get_parent(), Iso.sp(en.global_position, 14), to.normalized())
		hit_any = true
	if hit_any:
		Audio.play("melee_hit", global_position)
		Events.screen_shake.emit(5.0)
	knock += aim_dir * 70.0


func _slot_of(item: Dictionary) -> String:
	for s in ["primary", "secondary"]:
		if GameState.equipment.get(s, {}) == item:
			return s
	return "primary"


func start_reload(slot: String) -> void:
	var item := weapon(slot)
	if item.is_empty() or not item["weapon"].has("mag"):
		# try the other slot if primary has nothing to reload
		if slot == "primary":
			var other := weapon("secondary")
			if not other.is_empty() and other["weapon"].has("mag"):
				start_reload("secondary")
		return
	var w: Dictionary = item["weapon"]
	if int(item.get("loaded", 0)) >= int(w["mag"]) or float(reload_t[slot]) > 0.0:
		return
	var ammo_type: String = w["ammo"]
	if int(GameState.ammo.get(ammo_type, 0)) <= 0:
		_hint("Out of %s!" % ItemDB.ammo_label(ammo_type))
		return
	reload_t[slot] = float(w["reload"]) * (0.75 if overcharge_t > 0.0 else 1.0)
	reload_uid[slot] = int(item.get("uid", -1))
	_reload_sound(String(w["type"]), "start")


func _finish_reload(slot: String) -> void:
	reload_t[slot] = 0.0
	var item := weapon(slot)
	if item.is_empty() or not item["weapon"].has("mag") or int(item.get("uid", -2)) != int(reload_uid[slot]):
		return
	var w: Dictionary = item["weapon"]
	_reload_sound(String(w["type"]), "finish")
	var ammo_type: String = w["ammo"]
	var need := int(w["mag"]) - int(item.get("loaded", 0))
	var have := int(GameState.ammo.get(ammo_type, 0))
	var take := mini(need, have)
	item["loaded"] = int(item.get("loaded", 0)) + take
	GameState.ammo[ammo_type] = have - take


## Reload sounds come in two halves so they line up with any reload time:
## rifle mag out -> mag in + charging handle; shotgun shells in -> pump.
## Other weapon types fall back to the generic click at the start.
const RELOAD_SFX := {
	"rifle": {"start": "reload_rifle_out", "finish": "reload_rifle_in"},
	"shotgun": {"start": "reload_shotgun_load", "finish": "reload_shotgun_pump"},
}


func _reload_sound(weapon_type: String, phase: String) -> void:
	if RELOAD_SFX.has(weapon_type):
		Audio.play(RELOAD_SFX[weapon_type][phase], global_position)
	elif phase == "start":
		Audio.play("reload", global_position)


func is_reloading(slot: String) -> bool:
	return float(reload_t[slot]) > 0.0 and int(reload_uid[slot]) == int(weapon(slot).get("uid", -2))


# ---------------------------------------------------------------- abilities

func ability_cd(id: String) -> float:
	return float(ABIL[id]["cd"]) * GameState.cooldown_mult()


func _spend(id: String) -> bool:
	if float(cooldowns[id]) > 0.0:
		return false
	var cost := float(ABIL[id]["cost"])
	if GameState.energy < cost:
		_hint("Not enough energy for %s." % ABIL[id]["name"])
		return false
	GameState.energy -= cost
	cooldowns[id] = ability_cd(id)
	return true


func _try_roll() -> void:
	if roll_t > 0.0 or not _spend("roll"):
		return
	var mv := Iso.input_to_world(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	roll_dir = mv.normalized() if mv.length() > 0.2 else aim_dir
	roll_t = ROLL_TIME
	invuln_t = ROLL_TIME + 0.08
	collision_mask = Combat.LAYER_WORLD
	trail.clear()
	Fx.burst(get_parent(), Iso.sp(global_position), Color(0.5, 0.5, 0.5, 0.6), 8, 90.0, -roll_dir, 0.8, 3.0, 0.4)
	Audio.play("dodge", global_position)


func _try_overcharge() -> void:
	if not _spend("overcharge"):
		return
	overcharge_t = 8.0 + GameState.attr("int") * 0.25
	Fx.ring(get_parent(), Iso.sp(global_position, 12), 70.0, Color(1.0, 0.55, 0.15), 0.5, 8.0)
	Events.msg("OVERCHARGE ENGAGED", Color(1.0, 0.6, 0.2))
	Audio.play("overcharge", global_position)


func _try_pulse() -> void:
	if not _spend("pulse"):
		return
	var radius := 170.0 + GameState.attr("int") * 4.0
	var dmg := (22.0 + float(GameState.level) * 4.0) * GameState.tech_mult()
	Fx.ring(get_parent(), Iso.sp(global_position, 10), radius, Color(0.45, 0.8, 1.0), 0.45, 12.0)
	Fx.burst(get_parent(), Iso.sp(global_position, 10), Color(0.6, 0.9, 1.0), 24, 380.0)
	Events.screen_shake.emit(7.0)
	Audio.play("pulse", global_position)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Actor
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		if to.length() > radius + float(en.get("radius")):
			continue
		var h := Combat.make_hit(dmg, self, randf() < GameState.crit_chance())
		if h["crit"]:
			h["amount"] = dmg * 1.75
		h["dir"] = to.normalized()
		h["knockback"] = 260.0
		h["color"] = Color(0.6, 0.85, 1.0)
		en.take_hit(h)
		if en.has_method("interrupt"):
			en.call("interrupt")
		en.apply_status("stun", 1.0)
	# Pulse also destroys hostile projectiles nearby
	for n in get_parent().get_children():
		if n is Projectile and (n as Projectile).mask & Combat.LAYER_PLAYER and n.global_position.distance_to(global_position) < radius:
			n.queue_free()


func _use_stim() -> void:
	if GameState.stims <= 0:
		_hint("No stim-packs left.")
		return
	if hp >= max_hp:
		_hint("Health is full.")
		return
	GameState.stims -= 1
	hp = minf(max_hp, hp + max_hp * 0.45)
	statuses.erase("toxin")
	statuses.erase("bleed")
	statuses.erase("burn")
	Fx.ring(get_parent(), Iso.sp(global_position, 12), 46.0, Color(0.4, 1.0, 0.5), 0.4, 5.0)
	Fx.text(get_parent(), Iso.sp(global_position, 50), "+STIM", Color(0.5, 1.0, 0.5))
	Audio.play("stim", global_position)


func _hint(t: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hint_t > 0.8:
		_last_hint_t = now
		Events.msg(t, Color(0.75, 0.75, 0.7))


# ---------------------------------------------------------------- interaction / hover

func _update_interact() -> void:
	var best: Node = null
	var best_ratio := 1.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var n2 := n as Node2D
		var rv = n2.get("interact_radius")
		var r: float = float(rv) if rv != null else INTERACT_RANGE
		var ratio := n2.global_position.distance_to(global_position) / r
		if ratio < best_ratio:
			best_ratio = ratio
			best = n
	interact_target = best


func _update_hover() -> void:
	hovered_enemy = null
	var best := 40.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		var d := en.global_position.distance_to(aim_point)
		if d < best:
			best = d
			hovered_enemy = en


# ---------------------------------------------------------------- damage

func take_hit(hit: Dictionary) -> bool:
	if dead or invuln_t > 0.0:
		return false
	if not hit.get("dot", false):
		if randf() < GameState.evasion():
			Fx.text(get_parent(), Iso.sp(global_position, 44), "EVADED", Color(0.7, 0.9, 1.0), 0.9)
			return false
		if GameState.has_special("barrier") and randf() < 0.12:
			Fx.text(get_parent(), Iso.sp(global_position, 44), "BARRIER", Color(0.8, 0.5, 1.0), 0.9)
			Fx.ring(get_parent(), Iso.sp(global_position, 14), 26.0, Color(0.8, 0.5, 1.0), 0.25, 4.0)
			return true
	return super.take_hit(hit)


func _show_damage(amount: float, _crit: bool, _col: Color) -> void:
	Fx.text(get_parent(), Iso.sp(global_position, 44) + Vector2(randf_range(-8, 8), 0), str(roundi(amount)), Color(1.0, 0.3, 0.25), 0.9)


func _on_damaged(hit: Dictionary, amount: float) -> void:
	GameState.hp = hp
	Events.player_hurt.emit(amount)
	if not hit.get("dot", false):
		Audio.play_ui("player_hurt")
		Events.screen_shake.emit(minf(10.0, 2.0 + amount * 0.25))
		Fx.blood(get_parent(), Iso.sp(global_position, 16), hit.get("dir", Vector2.ZERO))


func on_dealt_damage(amount: float, hit: Dictionary) -> void:
	var ls := float(hit.get("lifesteal", 0.0))
	if ls > 0.0:
		hp = minf(max_hp, hp + amount * ls)


func die() -> void:
	if dead:
		return
	super.die()
	GameState.hp = 0.0
	velocity = Vector2.ZERO
	Fx.blood(get_parent(), Iso.sp(global_position, 10), Vector2.UP)
	Audio.play_ui("player_death")
	Events.player_died.emit()


# ---------------------------------------------------------------- drawing

const C_ARMOR := Color(0.21, 0.22, 0.23)
const C_ARMOR_HI := Color(0.34, 0.34, 0.33)
const C_ARMOR_SH := Color(0.13, 0.135, 0.14)
const C_TRIM := Color(0.44, 0.36, 0.2)      # tarnished brass
const C_RED := Color(0.37, 0.075, 0.06)     # dull crimson
const C_RED_SH := Color(0.22, 0.045, 0.035)
const C_CLOTH := Color(0.12, 0.1, 0.09)
const C_METAL := Color(0.09, 0.09, 0.1)
const C_SKIN := Color(0.6, 0.47, 0.39)
const C_SKIN_SH := Color(0.42, 0.31, 0.26)
const C_HAIR := Color(0.13, 0.11, 0.1)
const C_GLOW := Color(0.35, 0.9, 1.0)        # cybernetic / suit status light

## How each race looks inside the suit. `scale` is applied to the whole body
## (x, y) from the feet; `head_r` is the head radius under the glass helmet;
## `hair` is hair, crest, mane or implant metal depending on the race;
## `visor` tints the helmet glass.
const RACE_LOOK := {
	"human":   {"scale": Vector2(1.0, 1.0),   "head_r": 5.5, "skin": Color(0.6, 0.47, 0.39),  "skin_sh": Color(0.42, 0.31, 0.26), "hair": Color(0.13, 0.11, 0.1),  "visor": Color(0.55, 0.8, 0.95, 0.14)},
	"ossari":  {"scale": Vector2(0.86, 1.03), "head_r": 6.2, "skin": Color(0.74, 0.76, 0.8),  "skin_sh": Color(0.52, 0.55, 0.6),  "hair": Color(0.52, 0.55, 0.6),  "visor": Color(0.6, 0.75, 1.0, 0.14)},
	"halvex":  {"scale": Vector2(1.0, 1.0),   "head_r": 5.5, "skin": Color(0.55, 0.58, 0.66), "skin_sh": Color(0.38, 0.4, 0.48),  "hair": Color(0.3, 0.32, 0.35),  "visor": Color(0.4, 0.9, 1.0, 0.16)},
	"nyxari":  {"scale": Vector2(0.95, 1.0),  "head_r": 5.3, "skin": Color(0.32, 0.26, 0.35), "skin_sh": Color(0.2, 0.16, 0.23),  "hair": Color(0.14, 0.11, 0.16), "visor": Color(0.18, 0.08, 0.22, 0.55)},
	"zessk":   {"scale": Vector2(0.8, 0.8),   "head_r": 5.0, "skin": Color(0.38, 0.56, 0.3),  "skin_sh": Color(0.24, 0.38, 0.2),  "hair": Color(0.62, 0.52, 0.2),  "visor": Color(0.6, 0.9, 0.7, 0.14)},
	"ursathi": {"scale": Vector2(1.18, 1.18), "head_r": 5.8, "skin": Color(0.52, 0.37, 0.22), "skin_sh": Color(0.34, 0.23, 0.13), "hair": Color(0.22, 0.14, 0.08), "visor": Color(0.85, 0.75, 0.6, 0.12)},
}


func _look() -> Dictionary:
	return RACE_LOOK.get(race, RACE_LOOK["human"])


func _tint(c: Color) -> Color:
	if flash > 0.0:
		return c.lerp(Color(1, 1, 1), 0.7)
	if invuln_t > 0.0 and roll_t <= 0.0:
		return c.lerp(Color(0.6, 0.8, 1.0), 0.3)
	return c


## Called by the IsoView. Body art is drawn in screen space, so world-space
## facing / aim are temporarily swapped for their projected equivalents.
func _render() -> void:
	var wf := facing
	var wa := aim_dir
	facing = Iso.angle(wf)
	aim_dir = Iso.dir(wa).normalized()
	_render_body()
	facing = wf
	aim_dir = wa


func _render_body() -> void:
	# roll after-images
	for i in trail.size():
		var p: Vector2 = Iso.rel(trail[i], global_position)
		cv.draw_circle(p + Vector2(0, -20), 11.0, Color(0.4, 0.55, 0.7, 0.08 * float(i + 1)))
	# shadow
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	cv.draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.5))
	cv.draw_set_transform(Vector2.ZERO)
	if dead:
		_draw_corpse()
		return
	if overcharge_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		Iso.ground(cv)
		cv.draw_arc(Vector2.ZERO, 17.0 + pulse * 2.0, 0, TAU, 32, Color(1.0, 0.5, 0.1, 0.6), 2.5)
		cv.draw_set_transform(Vector2.ZERO)
	var sc := status_color()
	if sc.a > 0.0:
		Iso.ground(cv)
		cv.draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, Color(sc.r, sc.g, sc.b, 0.7), 2.0)
		cv.draw_set_transform(Vector2.ZERO)
	if roll_t > 0.0:
		# tucked into a combat roll
		var f := 1.0 - roll_t / ROLL_TIME
		cv.draw_set_transform(Vector2(0, -12), f * TAU * (1.0 if aim_dir.x >= 0.0 else -1.0), Vector2(0.75, 0.75))
		cv.draw_circle(Vector2.ZERO, 12.0, _tint(C_ARMOR))
		cv.draw_arc(Vector2.ZERO, 12.0, 0.0, PI, 10, _tint(C_RED), 5.0)
		cv.draw_circle(Vector2(0, -6), 5.0, _tint(_look()["skin"]))
		cv.draw_circle(Vector2(0, -6), 6.5, Color(0.55, 0.8, 0.95, 0.18))   # helmet glass
		cv.draw_set_transform(Vector2.ZERO)
	else:
		cv.draw_set_transform(Vector2.ZERO, 0.0, _look()["scale"])
		_draw_marine()
		cv.draw_set_transform(Vector2.ZERO)
	# reload indicator
	for s in ["primary", "secondary"]:
		if is_reloading(s):
			var item := weapon(s)
			var total := float(item["weapon"]["reload"])
			var rp := 1.0 - float(reload_t[s]) / total
			cv.draw_rect(Rect2(-16, -64, 32, 4), Color(0, 0, 0, 0.7))
			cv.draw_rect(Rect2(-16, -64, 32 * rp, 4), Color(0.9, 0.75, 0.3))


## A marine in heavy power armour with a glass helmet, drawn upright for the
## isometric camera. The race (RACE_LOOK) sets body proportions, what shows
## through the helmet glass, and extras such as wings, a tail or claws. `aim_dir` is in screen space here (see _render):
## the body turns to face it (left/right, toward or away from the camera).
func _draw_marine() -> void:
	var d := aim_dir
	var fx := 1.0 if d.x >= 0.0 else -1.0
	var away := d.y < -0.35          # back turned to the camera
	var stride := sin(walk_t * 10.0) if moving else 0.0
	var bob := absf(stride) * 1.2
	var breathe := sin(Time.get_ticks_msec() * 0.003) * 0.6 if not moving else 0.0
	var up := Vector2(0, -bob + breathe)

	if race == "zessk" and not away:
		_draw_tail(fx, up)
	if race == "nyxari" and not away:
		_draw_wings(up, false)

	# legs: armoured greaves, knee guards, heavy boots
	for side in [-1.0, 1.0]:
		var sw: float = stride * 5.0 * side
		var hip := Vector2(side * 5.5, -20) + up
		var foot := Vector2(side * 6.0 + sw * fx * 0.7, -1.0 - maxf(0.0, sw) * 0.5)
		var knee := hip.lerp(foot, 0.5) + Vector2(fx * 1.5, 0)
		var shade := C_ARMOR if side * fx < 0.0 else C_ARMOR_SH
		Shade.limb(cv, hip, knee, 8.0, _tint(shade))
		Shade.limb(cv, knee, foot + Vector2(0, -3), 7.0, _tint(shade))
		cv.draw_rect(Rect2(knee + Vector2(-3.5, -2.5), Vector2(7, 5)), _tint(C_ARMOR_HI.darkened(0.25)))
		Shade.poly(cv, PackedVector2Array([foot + Vector2(-4.5, -5), foot + Vector2(4.5, -5), foot + Vector2(4.5 + fx * 3.0, 1), foot + Vector2(-4.5, 1)]), _tint(C_METAL.lightened(0.08)))

	if race == "zessk" and away:
		_draw_tail(fx, up)
	if away:
		_draw_arms_and_weapon(d, fx, up)

	# hip armour, belt and tabard
	Shade.poly(cv, _shift(up) * PackedVector2Array([Vector2(-10, -26), Vector2(10, -26), Vector2(11, -18), Vector2(-11, -18)]), _tint(C_ARMOR_SH.lightened(0.1)))
	cv.draw_rect(Rect2(Vector2(-10, -26) + up, Vector2(20, 4)), _tint(C_METAL))
	cv.draw_rect(Rect2(Vector2(-2.5, -26) + up, Vector2(5, 4)), _tint(C_TRIM))
	if not away:
		Shade.poly(cv, _shift(up) * PackedVector2Array([Vector2(-4, -22), Vector2(4, -22), Vector2(3, -9), Vector2(0, -7), Vector2(-3, -9)]), _tint(C_RED))

	# power pack: peeks over the shoulders from the front, dominates from behind
	if not away:
		cv.draw_rect(Rect2(Vector2(-12, -53) + up, Vector2(24, 9)), _tint(C_METAL))
		for ex in [-8.0, 5.0]:
			cv.draw_rect(Rect2(Vector2(ex, -58) + up, Vector2(3, 6)), _tint(C_ARMOR_HI))

	# torso: broad, barrel-chested power armour
	var chest := _shift(up) * PackedVector2Array([Vector2(-9, -26), Vector2(9, -26), Vector2(13, -38), Vector2(12, -45), Vector2(-12, -45), Vector2(-13, -38)])
	Shade.poly(cv, chest, _tint(C_ARMOR))
	if away:
		var pack := Rect2(Vector2(-10, -50) + up, Vector2(20, 22))
		Shade.rect(cv, pack, _tint(C_METAL.lightened(0.06)))
		for i in 3:
			cv.draw_line(Vector2(-7, -45 + i * 5) + up, Vector2(7, -45 + i * 5) + up, _tint(C_ARMOR_SH), 2.0)
		for ex in [-8.0, 5.0]:
			cv.draw_rect(Rect2(Vector2(ex, -56) + up, Vector2(3, 7)), _tint(C_ARMOR_HI))
			cv.draw_circle(Vector2(ex + 1.5, -57) + up, 1.5, Color(0.9, 0.35, 0.1, 0.8))
		if race == "nyxari":
			_draw_wings(up, true)
	else:
		# moulded pectoral plates, brass trim and a life-support panel
		cv.draw_line(Vector2(-9, -36) + up, Vector2(-1, -33) + up, _tint(C_ARMOR_HI), 1.5)
		cv.draw_line(Vector2(9, -36) + up, Vector2(1, -33) + up, _tint(C_ARMOR_HI), 1.5)
		cv.draw_line(Vector2(-10, -42) + up, Vector2(10, -42) + up, _tint(C_TRIM), 1.5)
		cv.draw_rect(Rect2(Vector2(-4, -40) + up, Vector2(8, 5)), _tint(C_METAL))
		var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
		cv.draw_circle(Vector2(-1.8, -37.5) + up, 0.9, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, blink))
		cv.draw_circle(Vector2(1.8, -37.5) + up, 0.9, Color(0.4, 1.0, 0.45, 0.85))
		# hose from the pack to the helmet collar
		cv.draw_line(Vector2(-6 * fx, -44) + up, Vector2(-7 * fx, -30) + up, _tint(C_METAL.lightened(0.1)), 2.0)

	_draw_head(fx, up, away)

	# massive pauldrons in chapter crimson with brass rims
	for side in [-1.0, 1.0]:
		var near: bool = side * fx > 0.0
		var pc := Vector2(side * 14.0, -43) + up
		var col := C_RED if near or not away else C_RED_SH
		var pts := PackedVector2Array()
		for i in 11:
			var a := PI + PI * float(i) / 10.0
			pts.append(pc + Vector2(cos(a) * 9.0, sin(a) * 7.0))
		pts.append(pc + Vector2(8, 5))
		pts.append(pc + Vector2(-8, 5))
		Shade.poly(cv, pts, _tint(col))
		cv.draw_polyline(pts.slice(0, 11), _tint(C_TRIM.darkened(0.15)), 1.0)   # worn brass rim
		if not away and near:
			# unit chevron stencilled on the near pauldron
			cv.draw_polyline(PackedVector2Array([pc + Vector2(-3, -3), pc + Vector2(0, 0), pc + Vector2(3, -3)]), _tint(Color(0.75, 0.72, 0.62)), 1.2)

	if not away:
		_draw_arms_and_weapon(d, fx, up)


static func _shift(o: Vector2) -> Transform2D:
	return Transform2D(0.0, o)


## Both arms hold the current primary weapon at chest height, pointed along
## the screen-space aim; the off-hand melee weapon hangs at the hip until swung.
func _draw_arms_and_weapon(d: Vector2, fx: float, up: Vector2) -> void:
	var prim := weapon("primary")
	var t := "rifle"
	if not prim.is_empty():
		t = String(prim["weapon"]["type"])
	var grip := Vector2(fx * 3.0, -33) + up + d * 4.0
	var length := {"rifle": 30.0, "shotgun": 28.0, "energy": 18.0}.get(t, 28.0) as float
	var muzzle := grip + d * length
	var stock := grip - d * 8.0
	var down := Vector2(0, 1)
	# weapon
	match t:
		"shotgun":
			cv.draw_line(stock, grip, _tint(Color(0.32, 0.2, 0.11)), 6.0)
			cv.draw_line(grip, muzzle, _tint(C_METAL), 5.0)
			cv.draw_line(grip + d * 9.0 + down * 3.0, grip + d * 18.0 + down * 3.0, _tint(Color(0.32, 0.2, 0.11)), 4.0)
		"energy":
			cv.draw_line(grip - d * 2.0, muzzle, _tint(C_ARMOR_HI), 5.0)
			cv.draw_line(grip + d * 3.0, grip + d * 11.0, Color(0.3, 0.7, 1.0, 0.95), 2.5)
			cv.draw_circle(muzzle, 2.5, Color(0.5, 0.85, 1.0))
		_:
			cv.draw_line(stock, grip, _tint(C_METAL), 5.0)
			cv.draw_line(grip, muzzle, _tint(C_METAL), 4.5)
			cv.draw_line(grip + d * 4.0, grip + d * 13.0, _tint(C_ARMOR_HI), 6.0)        # receiver
			cv.draw_line(grip + d * 8.0, grip + d * 8.0 + down * 6.0, _tint(C_METAL), 3.5)  # magazine
	# arms: rear arm to the trigger grip, lead arm to the foregrip
	var sh_rear := Vector2(-fx * 11.0, -41) + up
	var sh_lead := Vector2(fx * 11.0, -41) + up
	var fore := grip + d * length * 0.55
	for pair in [[sh_rear, grip], [sh_lead, fore]]:
		var s0: Vector2 = pair[0]
		var h: Vector2 = pair[1]
		var elbow := s0.lerp(h, 0.5) + Vector2(0, 5)
		Shade.limb(cv, s0, elbow, 6.5, _tint(C_ARMOR))
		Shade.limb(cv, elbow, h, 6.0, _tint(C_ARMOR))
		Shade.ball(cv, h, 3.4, _tint(C_ARMOR_HI))   # gauntlet
		if race == "ursathi":
			for k in [-0.5, 0.0, 0.5]:
				var cd := d.rotated(k)
				cv.draw_line(h + cd * 2.5, h + cd * 6.0, Color(0.85, 0.8, 0.68), 1.2)   # claws through the glove tips
	if muzzle_t > 0.0:
		var mc := Color(1.0, 0.85, 0.4) if t != "energy" else Color(0.6, 0.9, 1.0)
		var n := Vector2(-d.y, d.x)
		cv.draw_colored_polygon(PackedVector2Array([muzzle + n * 5.0, muzzle + d * 14.0, muzzle - n * 5.0, muzzle + d * 4.0]), mc)
		cv.draw_circle(muzzle, 4.0, Color(1, 1, 0.9))
	# off-hand melee weapon
	var sec := weapon("secondary")
	if not sec.is_empty() and String(sec["weapon"]["type"]) == "melee":
		var is_maul := String(sec["weapon"].get("status", "")) == "stun"
		var hilt: Vector2
		var tip: Vector2
		if swing_t > 0.0:
			var k := 1.0 - swing_t / 0.18
			var ang := d.angle() + lerpf(-1.5, 1.5, k) * fx
			hilt = sh_lead + Vector2.from_angle(ang) * 10.0
			tip = hilt + Vector2.from_angle(ang) * 24.0
			cv.draw_line(sh_lead, hilt, _tint(C_ARMOR), 6.0)
		else:
			hilt = Vector2(-fx * 11.0, -24) + up
			tip = hilt + Vector2(-fx * 4.0, 16.0)
		cv.draw_line(hilt, tip, _tint(C_METAL), 3.5)
		if is_maul:
			cv.draw_circle(tip, 5.0, _tint(C_ARMOR_HI))
			cv.draw_circle(tip, 2.5, Color(0.5, 0.8, 1.0, 0.9))
		else:
			cv.draw_line(hilt.lerp(tip, 0.3), tip, Color(0.75, 0.72, 0.65), 4.0)
			cv.draw_line(hilt.lerp(tip, 0.3), tip, C_RED, 1.0)


func _draw_corpse() -> void:
	var t := minf(death_t / 0.5, 1.0)
	cv.draw_set_transform(Vector2(0, -4), PI * 0.5 * t * (1.0 if cos(facing) >= 0.0 else -1.0), Vector2(1, 1))
	cv.draw_rect(Rect2(-6, -22, 13, 20), C_ARMOR)                 # torso
	cv.draw_rect(Rect2(-5, -2, 5, 14), C_ARMOR_SH)               # legs
	cv.draw_rect(Rect2(1, -2, 5, 14), C_ARMOR_SH)
	cv.draw_circle(Vector2(-9, -20), 6.0, C_RED)                  # pauldrons
	cv.draw_circle(Vector2(10, -20), 6.0, C_RED)
	cv.draw_circle(Vector2(0, -27), 5.0, _look()["skin_sh"])     # head
	cv.draw_circle(Vector2(0, -27), 7.0, Color(0.55, 0.8, 0.95, 0.15))   # cracked helmet glass
	cv.draw_line(Vector2(-3, -31), Vector2(2, -25), Color(0.85, 0.95, 1.0, 0.5), 1.0)
	cv.draw_set_transform(Vector2.ZERO)
	Iso.ground(cv)
	cv.draw_circle(Vector2(4, 4), 16.0 * t, Color(0.35, 0.0, 0.0, 0.5))
	cv.draw_set_transform(Vector2.ZERO)


## Ellipse outline as a polygon (no draw transforms: the body scale is one).
static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Head under a glass helmet: collar, the inside of the dome, the race's head,
## then the glass on top (tint, rim, glint).
func _draw_head(fx: float, up: Vector2, away: bool) -> void:
	var lk := _look()
	var r: float = lk["head_r"]
	var skin: Color = _tint(lk["skin"])
	var sk_sh: Color = _tint(lk["skin_sh"])
	var hair: Color = _tint(lk["hair"])
	cv.draw_rect(Rect2(Vector2(-7, -49) + up, Vector2(14, 5)), _tint(C_ARMOR_HI))   # helmet collar ring
	var head := Vector2(fx * 1.0, -48.5 - r * 0.9) + up
	var dome_r := r + 3.0 + (1.8 if race == "ursathi" else 0.0)
	var dome := head + Vector2(0, -0.5)
	cv.draw_circle(dome, dome_r, Color(0.04, 0.06, 0.08, 0.6))   # inside of the dome
	var eye_col := Color(1.0, 0.25, 0.1) if overcharge_t > 0.0 else Color(0.08, 0.06, 0.05)
	match race:
		"ossari":
			var cran := head + Vector2(0, -1.2)
			if away:
				Shade.poly(cv, _ellipse(cran, r * 0.9, r * 1.1), sk_sh)
			else:
				cv.draw_colored_polygon(PackedVector2Array([head + Vector2(-3.2, 1.5), head + Vector2(3.2, 1.5), head + Vector2(fx * 0.8, 6.0)]), sk_sh)   # narrow chin
				Shade.poly(cv, _ellipse(cran, r * 0.9, r * 1.1), skin)
				var big := Color(0.02, 0.02, 0.04) if overcharge_t <= 0.0 else eye_col
				for e in [[head + Vector2(fx * 2.4, 0.6), 2.2], [head + Vector2(-fx * 1.9, 0.6), 1.5]]:
					var c: Vector2 = e[0]
					var w: float = e[1]
					cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * fx, 0.6), c + Vector2(-w * 0.2 * fx, -1.3), c + Vector2(w * fx, -1.0), c + Vector2(w * 0.3 * fx, 1.3)]), big)
					cv.draw_circle(c + Vector2(-0.4, -0.5), 0.45, Color(1, 1, 1, 0.6))
		"halvex":
			if away:
				Shade.ball(cv, head, r, sk_sh)
				cv.draw_colored_polygon(_ellipse(head + Vector2(0, -0.5), r * 0.85, r * 0.7, 10), hair)   # cortical plate
				cv.draw_line(head + Vector2(-3, -0.5), head + Vector2(3, -0.5), C_GLOW, 1.0)
			else:
				cv.draw_rect(Rect2(head + Vector2(-4.0, 0), Vector2(8, 4.5)), sk_sh)
				Shade.ball(cv, head, r, skin)
				# implant plate over the far side of the skull, with a glowing seam
				cv.draw_colored_polygon(PackedVector2Array([head + Vector2(-fx * 5.6, -1.0), head + Vector2(-fx * 3.5, -5.2), head + Vector2(fx * 1.0, -5.8), head + Vector2(-fx * 0.5, -2.0), head + Vector2(-fx * 2.5, 1.5)]), hair)
				cv.draw_polyline(PackedVector2Array([head + Vector2(fx * 0.5, -5.0), head + Vector2(-fx * 1.0, -2.2), head + Vector2(-fx * 3.0, 1.0)]), C_GLOW, 0.9)
				cv.draw_circle(head + Vector2(fx * 2.3, -0.4), 1.3, C_GLOW if overcharge_t <= 0.0 else eye_col)   # optic implant
				cv.draw_rect(Rect2(head + Vector2(-1.6 * fx - 1.0, -0.9), Vector2(2.0, 1.3)), eye_col)
		"nyxari":
			var eyes := Color(1.0, 0.62, 0.15) if overcharge_t <= 0.0 else eye_col
			if away:
				Shade.ball(cv, head, r, sk_sh)
				for i in 3:
					cv.draw_circle(head + Vector2(-2.5 + i * 2.5, -1.0 + absf(i - 1) * 0.7), 0.75, eyes)
			else:
				cv.draw_colored_polygon(PackedVector2Array([head + Vector2(-3.5, 2), head + Vector2(3.5, 2), head + Vector2(fx * 1.5, 5.5)]), sk_sh)   # pointed jaw
				Shade.ball(cv, head, r, skin)
				# a ring of eight small eyes: five face the camera
				for i in 5:
					cv.draw_circle(head + Vector2(fx * 0.6 - 4.2 + i * 2.1, -0.8 + absf(i - 2) * 0.6), 0.85, eyes)
		"zessk":
			if away:
				Shade.ball(cv, head, r, sk_sh)
			else:
				Shade.poly(cv, PackedVector2Array([head + Vector2(fx * 1.0, -2.0), head + Vector2(fx * 7.0, 0.5), head + Vector2(fx * 6.5, 2.6), head + Vector2(fx * 0.5, 3.5)]), sk_sh)   # snout
				Shade.ball(cv, head, r, skin)
				var ey := head + Vector2(fx * 2.4, -0.8)
				cv.draw_circle(ey, 1.4, Color(0.95, 0.8, 0.2) if overcharge_t <= 0.0 else eye_col)
				cv.draw_line(ey + Vector2(0, -1.1), ey + Vector2(0, 1.1), Color(0.05, 0.05, 0.02), 0.7)   # slit pupil
			for i in 3:   # crest spines and a few dark scales
				var b := head + Vector2(-2.5 + i * 2.5, -r + 0.6)
				cv.draw_colored_polygon(PackedVector2Array([b + Vector2(-1.0, 0.5), b + Vector2(1.0, 0.5), b + Vector2(-fx * 0.8, -2.4)]), hair)
				cv.draw_circle(head + Vector2(-2.0 + i * 1.8, 1.5 + (i % 2)), 0.5, sk_sh.darkened(0.3))
		"ursathi":
			Shade.ball(cv, head, r + 2.0, hair)   # mane
			for i in 9:
				var a := PI * 0.9 + PI * 1.2 * float(i) / 8.0
				cv.draw_colored_polygon(PackedVector2Array([head + Vector2.from_angle(a - 0.25) * (r + 1.5), head + Vector2.from_angle(a + 0.25) * (r + 1.5), head + Vector2.from_angle(a) * (r + 3.6)]), hair)
			for side in [-1.0, 1.0]:   # ears
				var e: Vector2 = head + Vector2(side * 3.8, -r + 0.5)
				cv.draw_colored_polygon(PackedVector2Array([e + Vector2(-1.4, 0.8), e + Vector2(1.4, 0.8), e + Vector2(side * 0.6, -2.2)]), sk_sh)
			if not away:
				Shade.ball(cv, head, r * 0.85, skin)
				cv.draw_colored_polygon(_ellipse(head + Vector2(fx * 2.2, 2.0), 2.8, 2.0, 10), skin.lightened(0.25))   # muzzle
				cv.draw_circle(head + Vector2(fx * 3.8, 1.2), 0.9, Color(0.08, 0.05, 0.04))   # nose
				var amber := Color(0.95, 0.65, 0.15) if overcharge_t <= 0.0 else eye_col
				cv.draw_circle(head + Vector2(fx * 1.8, -1.4), 0.8, amber)
				cv.draw_circle(head + Vector2(-fx * 1.6, -1.4), 0.7, amber)
		_:   # human: cropped hair, scarred, heavy jaw
			if away:
				cv.draw_circle(head, r, sk_sh)
				cv.draw_circle(head + Vector2(0, -1), r - 0.2, hair)
			else:
				cv.draw_rect(Rect2(head + Vector2(-4.5, 0), Vector2(9, 5)), sk_sh)  # jaw
				Shade.ball(cv, head, r, skin)
				cv.draw_colored_polygon(PackedVector2Array([head + Vector2(-5.6, -0.5), head + Vector2(-4.5, -4.5), head + Vector2(0, -6.2), head + Vector2(4.5, -4.5), head + Vector2(5.6, -0.5), head + Vector2(0, -3.0)]), hair)
				var eye := head + Vector2(fx * 2.3, -0.5)
				cv.draw_rect(Rect2(eye + Vector2(-1.2, -0.6), Vector2(2.4, 1.4)), eye_col)
				cv.draw_rect(Rect2(eye + Vector2(-3.8 * fx - 1.0, -0.6), Vector2(2.0, 1.4)), eye_col)
				cv.draw_line(head + Vector2(-1.5 * fx, -3.5), head + Vector2(2.5 * fx, 2.5), Color(0.55, 0.25, 0.22), 1.0)   # scar
				cv.draw_line(head + Vector2(-1.5 * fx, 4.2), head + Vector2(3.5 * fx, 4.2), C_SKIN_SH.darkened(0.3), 1.0)    # set mouth
	# the glass: tint, metal rim, and a glint toward the key light
	cv.draw_circle(dome, dome_r, lk["visor"])
	cv.draw_arc(dome, dome_r, 0.0, TAU, 28, _tint(C_ARMOR_HI.lightened(0.1)), 1.2)
	if not away:
		cv.draw_arc(dome, dome_r - 1.8, PI * 1.08, PI * 1.42, 8, Color(1, 1, 1, 0.5), 1.3)
		cv.draw_circle(dome + Vector2(dome_r * 0.35, -dome_r * 0.55), 0.8, Color(1, 1, 1, 0.55))


## Nyxari wings, folded and rising behind the shoulders. `front` = drawn over
## the back (camera behind the operative).
func _draw_wings(up: Vector2, front: bool) -> void:
	var mem := _tint(_look()["skin_sh"])
	var bone := _tint(_look()["skin"])
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 6.0, -44) + up
		var tip := Vector2(side * 15.0, -68) + up
		var pts := PackedVector2Array([base, tip, Vector2(side * 21.0, -52) + up, Vector2(side * 12.0, -36) + up])
		Shade.poly(cv, pts, mem if front else mem.darkened(0.15))
		cv.draw_line(base, tip, bone, 1.6)
		cv.draw_line(tip, Vector2(side * 21.0, -52) + up, bone, 1.0)
		cv.draw_circle(tip, 1.3, bone)


## Zessk tail, curving to the ground behind the operative.
func _draw_tail(fx: float, up: Vector2) -> void:
	var col := _tint(_look()["skin"])
	var a := Vector2(-fx * 5.0, -22) + up
	var b := Vector2(-fx * 15.0, -15)
	var c := Vector2(-fx * 24.0, -6)
	var e := Vector2(-fx * 31.0, -4)
	Shade.limb(cv, a, b, 9.0, col)
	Shade.limb(cv, b, c, 7.0, col)
	Shade.limb(cv, c, e, 4.5, col)
	cv.draw_circle(e, 2.2, col)
	for k in 3:   # dark bands along the tail
		var m := b.lerp(c, 0.25 + 0.3 * k)
		cv.draw_line(m + Vector2(0, -3), m + Vector2(0, 3), _look()["skin_sh"], 1.5)
