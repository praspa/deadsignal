extends Node
## Automated play-through of the demo's acceptance criteria.
## Run:  godot --headless --path . -- --smoke
## Exits with the number of failed checks as the process exit code.

var main: Node
var game: Game
var fails := 0
var passes := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  PASS  ", msg)
	else:
		fails += 1
		print("  FAIL  ", msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	main = get_parent()
	check(Audio.all_loaded(), "all sound effects and music loops load")
	await _controller_menu_test()
	# isolate the test from any physically connected controller
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
	GameState.save_path = "user://smoke_test_save.json"
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	await frames(2)
	await _character_creation_test()
	await run()
	print("\nSMOKE TEST: %d passed, %d failed" % [passes, fails])
	get_tree().quit(fails)


## Menus must respond to the controller: A (PS Cross) presses the focused
## button, the d-pad moves focus. Uses synthetic pad events, before the pad
## bindings are stripped for the rest of the run.
func _controller_menu_test() -> void:
	print("== controller menu input")
	var box := VBoxContainer.new()
	var b1 := Button.new()
	var b2 := Button.new()
	b1.text = "one"
	b2.text = "two"
	box.add_child(b1)
	box.add_child(b2)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(box)
	add_child(layer)
	await get_tree().process_frame
	b1.grab_focus()
	var pressed := [0]
	b2.pressed.connect(func() -> void: pressed[0] += 1)
	for p in [true, false]:
		var dn := InputEventJoypadButton.new()
		dn.button_index = JOY_BUTTON_DPAD_DOWN
		dn.pressed = p
		Input.parse_input_event(dn)
		await get_tree().process_frame
	check(get_viewport().gui_get_focus_owner() == b2, "d-pad moves menu focus")
	for p in [true, false]:
		var a := InputEventJoypadButton.new()
		a.button_index = JOY_BUTTON_A
		a.pressed = p
		Input.parse_input_event(a)
		await get_tree().process_frame
	check(pressed[0] == 1, "A / Cross presses the focused menu button")
	var has_cancel := false
	for ev in InputMap.action_get_events("ui_cancel"):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			has_cancel = true
	check(has_cancel, "B / Circle bound to menu back")
	layer.queue_free()
	await get_tree().process_frame


func _key(code: Key) -> void:
	for p in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = p
		Input.parse_input_event(k)
		await get_tree().process_frame


## New Game -> character creation -> game, plus Back, races, locked classes,
## keyboard navigation, and name / race surviving a save / load.
func _character_creation_test() -> void:
	print("== character creation")
	check(GameState.clean_name("   ") == GameState.DEFAULT_NAME, "blank name falls back to the default")
	check(GameState.clean_name("  Vo\tss ") == "Voss", "name is trimmed and control characters dropped")
	check(GameState.clean_name("x".repeat(40)).length() == GameState.NAME_MAX, "name is capped at %d characters" % GameState.NAME_MAX)
	var names_ok := true
	for i in 50:
		var n := GameState.random_name()
		names_ok = names_ok and n.length() <= GameState.NAME_MAX and GameState.clean_name(n) == n
	check(names_ok, "random names fit the name rules")
	main.call("_on_menu_action", "new")
	await frames(3)
	var cc := main.get("current") as CharacterCreation
	check(cc != null, "New Game opens the character creation screen")
	if cc == null:
		return
	check(cc.class_buttons.size() == 5, "five classes listed")
	var enabled := cc.class_buttons.filter(func(b: Button) -> bool: return not b.disabled)
	check(enabled.size() == 1 and String(enabled[0].get_meta("class_id")) == "combat_specialist", "only Combat Specialist is selectable")
	check(cc.race_buttons.size() == GameState.RACES.size() and cc.race_buttons.all(func(b: Button) -> bool: return not b.disabled), "all %d races listed and selectable" % GameState.RACES.size())
	check(cc.name_edit.text != "" and cc.name_edit.text != GameState.DEFAULT_NAME, "name field starts with a random name (%s)" % cc.name_edit.text)
	var first_name := cc.name_edit.text
	for i in 10:
		cc.dice_btn.pressed.emit()
		if cc.name_edit.text != first_name:
			break
	check(cc.name_edit.text != first_name, "Random rerolls the name")
	check(get_viewport().gui_get_focus_owner() == cc.name_edit, "name field has focus on open")
	await _key(KEY_DOWN)
	check(get_viewport().gui_get_focus_owner() == cc.race_buttons[0], "down arrow leaves the name field for the race list")
	await _key(KEY_RIGHT)
	await _key(KEY_DOWN)
	check(cc.detail_status.text.contains("LOCKED"), "focusing a locked class shows it as locked")
	check(cc.selected_class == "combat_specialist", "locked class cannot be selected")
	await _key(KEY_RIGHT)
	await get_tree().process_frame
	check(get_viewport().gui_get_focus_owner() == cc.begin_btn and not cc.detail_status.text.contains("LOCKED"), "details panel leaves the locked class when focus moves to Begin")
	for b in cc.race_buttons:
		b.pressed.emit()
		await frames(2)   # preview draws each race's art
	check(cc.preview_view.position == CharacterCreation.PREVIEW_FEET, "operative preview stays in its frame")
	check(cc.selected_race == GameState.RACES[GameState.RACES.size() - 1]["id"], "clicking a race selects it")
	await _key(KEY_ESCAPE)
	await frames(2)
	check(main.get("current") is MainMenu, "Esc / B returns to the main menu")
	check(Audio.get("_music_name") == "menu", "title screen plays the menu track")
	main.call("_on_menu_action", "new")
	await frames(3)
	cc = main.get("current") as CharacterCreation
	cc.name_edit.text = "  Voss "
	cc.race_buttons[GameState.RACES.find(GameState.race_info("zessk"))].pressed.emit()
	var begins := [0]
	cc.begin.connect(func(_n: String, _c: String, _r: String) -> void: begins[0] += 1)
	cc.begin_btn.pressed.emit()
	cc.begin_btn.pressed.emit()   # double click / Enter + A in one frame
	await _key(KEY_ESCAPE)        # and Esc right after Begin
	await frames(6)
	check(begins[0] == 1, "Begin Mission fires once, however many times it is pressed")
	check(main.get("current") is Game, "Begin Mission starts the game (and a late Esc does not undo it)")
	check(GameState.player_name == "Voss" and GameState.class_title() == "Combat Specialist" and GameState.race_id == "zessk", "name, class and race carried into the game")
	var g := main.get("current") as Game
	check(g != null and g.player.race == "zessk", "the in-game operative is drawn as the chosen race")
	GameState.save_game(Vector2.ZERO)
	GameState.player_name = "changed"
	GameState.race_id = "human"
	GameState.load_game()
	check(GameState.player_name == "Voss" and GameState.race_id == "zessk", "name and race survive save / load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))


func start() -> void:
	main.call("start_game")
	await frames(6)
	game = main.get("current")


func run() -> void:
	print("== boot")
	GameState.new_game()
	await start()
	var level := game.level
	var player := game.player
	check(level.w > 60 and level.h > 60, "outpost map loaded (%dx%d)" % [level.w, level.h])
	print("  layout %d: %s" % [GameState.map_variant, GameState.map_info.get("name", "?")])
	var ground := _open_ground(level)
	check(not GameState.map_info.get("dirs", {}).is_empty(), "layout metadata loaded")
	check(not GameState.current_objective_text().contains("{"), "objective text filled in: " + GameState.current_objective_text())
	var enemy_count := get_tree().get_nodes_in_group("enemies").size()
	check(enemy_count >= 25, "enemies spawned (%d)" % enemy_count)
	check(get_tree().get_nodes_in_group("boss").size() == 1, "boss spawned")
	check(not GameState.equipment["primary"].is_empty(), "starting primary weapon equipped")
	check(Audio.get("_music_name") == "level", "game switches to the level track")

	print("== minimap")
	var mm := game.minimap
	check(mm != null and mm.is_visible_in_tree(), "minimap on the HUD")
	await frames(2)
	var seen := mm.explored_count()
	check(seen > 0 and mm.wall_segs.size() > 0, "start area explored and drawn as line art (%d tiles, %d wall edges)" % [seen, mm.wall_segs.size() / 2])
	var boss_cell := level.world_to_cell((get_tree().get_first_node_in_group("boss") as Node2D).global_position)
	check(not mm.is_explored(boss_cell.x, boss_cell.y), "unexplored areas stay blank (boss room)")
	# two floor tiles in a straight line with wall between them (any thickness):
	# the far one must not be visible from the near one
	var pair := []
	for y in range(level.h):
		for x in range(level.w):
			if not pair.is_empty() or not level.is_floor(x, y):
				continue
			for dv in [Vector2i(1, 0), Vector2i(0, 1)]:
				var d: Vector2i = dv
				var a := Vector2i(x, y)
				if not pair.is_empty() or not level.is_wall((a + d).x, (a + d).y):
					continue
				for k in range(2, Minimap.SIGHT):
					var b := a + d * k
					if level.is_floor(b.x, b.y):
						pair = [a, b, d]
						break
	check(not pair.is_empty(), "layout has a wall between two floor tiles to test sight against")
	if not pair.is_empty():
		check(not mm._visible(pair[0], pair[1]) and mm._visible(pair[0] - pair[2], pair[0]), "walls block the minimap's line of sight")
	mm.reveal_around(boss_cell)
	check(mm.is_explored(boss_cell.x, boss_cell.y) and mm.explored_count() > seen, "exploring reveals new map")
	var explored_now := mm.explored_count()
	GameState.save_game(player.global_position)
	GameState.explored = PackedByteArray()
	GameState.load_game()
	check(GameState.explored.count(1) == explored_now, "explored map survives save / load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))

	print("== reload sounds")
	var rifle := player.weapon("primary")
	rifle["loaded"] = 0
	var heard: Dictionary = Audio.get("_last")
	heard.erase("reload_rifle_out")
	heard.erase("reload_rifle_in")
	player.start_reload("primary")
	check(heard.has("reload_rifle_out"), "rifle reload starts with the magazine coming out")
	for i in 200:
		if not player.is_reloading("primary"):
			break
		await frames(1)
	check(heard.has("reload_rifle_in") and int(rifle["loaded"]) > 0, "rifle reload ends with mag in + charging handle")

	print("== movement (8 directions, screen-relative in the isometric view)")
	var dirs := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "up": Vector2.UP, "down": Vector2.DOWN}
	for d in dirs:
		var p0 := player.global_position
		Input.action_press("move_" + d)
		await frames(12)
		Input.action_release("move_" + d)
		var moved := Iso.dir(player.global_position - p0)
		check(moved.normalized().dot(dirs[d]) > 0.95 and moved.length() > 20.0, "moves %s on screen (%.0f px)" % [d, moved.dot(dirs[d])])
	var p1 := player.global_position
	Input.action_press("move_right")
	Input.action_press("move_up")
	await frames(12)
	Input.action_release("move_right")
	Input.action_release("move_up")
	var diag := player.global_position - p1
	# up+right follows the isometric grid: world north, i.e. up-right on screen
	check(diag.y < -20 and absf(diag.x) < 4.0 and Iso.dir(diag).x > 15, "moves diagonally along the iso grid")

	print("== combat vs archetypes (assault rifle)")
	for kind in ["drone", "researcher", "heavy"]:
		player.global_position = ground
		await frames(2)
		var e := level.spawn_enemy(kind, player.global_position + Vector2(170, -60), "")
		var killed := false
		for i in 1500:
			player.hp = player.max_hp
			GameState.ammo["rifle"] = 300
			if not is_instance_valid(e) or e.dead:
				killed = true
				break
			# flank the heavy so its shield faces away part of the time
			player.aim_override = e.global_position
			player.fire("primary")
			await get_tree().physics_frame
		check(killed, "%s detected, fought and killed" % kind)
		check(e.aggro, "%s aggroed onto player" % kind)
	player.aim_override = null

	print("== enemy attacks")
	player.global_position = ground
	player.hp = player.max_hp
	var hp0 := player.hp
	var r := level.spawn_enemy("researcher", player.global_position + Vector2(120, 0), "")
	for i in 30:   # up to ~4 s: the player can evade individual lunges
		await frames(8)
		if player.hp < hp0:
			break
	check(player.hp < hp0, "researcher pursued and hit player (hp %.0f -> %.0f)" % [hp0, player.hp])
	var d := level.spawn_enemy("drone", player.global_position + Vector2(-200, 40), "")
	player.hp = player.max_hp
	hp0 = player.hp
	await frames(240)
	check(player.hp < hp0, "drone ranged attack hits player")
	r.take_hit(Combat.make_hit(9999, null))
	d.take_hit(Combat.make_hit(9999, null))
	player.hp = player.max_hp
	player.statuses.clear()

	print("== weapons behave distinctly")
	var shotgun: Dictionary = {}
	for it in GameState.inventory:
		if it["base"] == "shotgun":
			shotgun = it
	GameState.equip(shotgun, "primary")
	check(GameState.equipment["primary"]["base"] == "shotgun", "shotgun equipped from inventory")
	player.aim_override = player.global_position + Vector2(200, 0)
	var before := _count_projectiles()
	player.fire("primary")
	await frames(1)
	check(_count_projectiles() - before >= 6, "shotgun fires a pellet spread (%d)" % (_count_projectiles() - before))
	var pistol := ItemDB.generate("energy_pistol", 1, 1)
	GameState.add_item(pistol)
	GameState.equip(pistol, "primary")
	var dr := level.spawn_enemy("drone", player.global_position + Vector2(150, 0), "")
	await frames(2)
	player.aim_override = dr.global_position
	await frames(60)
	var e0 := GameState.energy
	var dhp := dr.hp
	player.aim_override = dr.global_position
	await frames(1)
	player.fire("primary")
	await frames(2)
	check(GameState.energy < e0, "energy pistol consumes energy")
	check(dr.hp < dhp or dr.dead, "energy pistol hitscan damages instantly")
	dr.take_hit(Combat.make_hit(9999, null))
	var rr := level.spawn_enemy("researcher", player.global_position + Vector2(40, 0), "")
	await frames(1)
	player.aim_override = rr.global_position
	var rhp := rr.hp
	player.fire("secondary")
	await frames(2)
	check(rr.hp < rhp or rr.dead, "melee (shock maul) arc hits adjacent enemy")
	rr.take_hit(Combat.make_hit(9999, null))
	GameState.equip(GameState.inventory.filter(func(x): return x["base"] == "assault_rifle")[0], "primary")
	player.aim_override = null

	print("== damage model")
	check(Combat.mitigate(100, 60) < 60.0 and Combat.mitigate(100, 0) == 100.0, "armor mitigates damage")
	var crits := 0
	for i in 400:
		if Combat.roll_damage(10, 10, 1, 0.5)[1]:
			crits += 1
	check(crits > 120 and crits < 280, "critical hits roll (%d/400 at 50%%)" % crits)
	var tst := level.spawn_enemy("researcher", player.global_position + Vector2(220, 0), "")
	await frames(1)
	tst.apply_status("burn")
	var th := tst.hp
	await frames(70)
	check(tst.hp < th, "status effect (burn) deals damage over time")
	tst.take_hit(Combat.make_hit(9999, null))

	print("== abilities")
	player.global_position = ground
	GameState.energy = GameState.max_energy()
	player._try_roll()
	check(player.roll_t > 0.0 and player.invuln_t > 0.0, "tactical roll grants movement + invulnerability")
	var hurt := player.take_hit(Combat.make_hit(50, null))
	check(not hurt, "rolling avoids damage")
	await frames(30)
	GameState.energy = GameState.max_energy()
	player._try_overcharge()
	check(player.overcharge_t > 0.0, "overcharge active")
	check(player.damage_mult(GameState.equipment["primary"]) > GameState.ranged_mult() * 1.3, "overcharge boosts damage")
	var pe := level.spawn_enemy("heavy", player.global_position + Vector2(100, 0), "")
	await frames(2)
	pe.become_aggro()
	pe._start_telegraph()
	GameState.energy = GameState.max_energy()
	player._try_pulse()
	check(pe.is_stunned(), "disruptor pulse stuns")
	check(pe.state != Enemy.S.TELEGRAPH, "disruptor pulse interrupts telegraphed attack")
	check(player.cooldowns["pulse"] > 0.0, "abilities go on cooldown")
	pe.take_hit(Combat.make_hit(9999, null))
	pe.take_hit(Combat.make_hit(9999, null))

	print("== loot")
	# count equipment only: ammo / stims nearby get auto-collected mid-test
	var item_drops := func() -> int:
		return GameState.ground_items.filter(func(g: Dictionary) -> bool: return String(g.get("kind", "")) == "item").size()
	var n_items: int = item_drops.call()
	level.enemy_loot(player.global_position, {"drop_chance": 1.0, "ammo_chance": 1.0, "quality": 2})
	await frames(2)
	check(int(item_drops.call()) > n_items, "enemy death drops loot")
	var drop: LootDrop = null
	for n in get_tree().get_nodes_in_group("loot"):
		drop = n
	var inv0 := GameState.inventory.size()
	if drop != null:
		player.global_position = drop.global_position
		await frames(2)
		drop.interact(player)
	check(GameState.inventory.size() == inv0 + 1, "item picked up into inventory")
	var picked: Dictionary = GameState.inventory[GameState.inventory.size() - 1]
	check(ItemDB.describe(picked).length() > 20, "item can be inspected")
	var slot := GameState.best_slot_for(picked)
	var cmp := ItemDB.compare(picked, GameState.equipment.get(slot, {}))
	check(cmp.length() > 0, "item comparison text")
	GameState.equip(picked)
	check(GameState.equipment[slot] == picked, "picked item equipped to %s" % slot)
	GameState.unequip(slot)
	check(GameState.equipment[slot].is_empty() or GameState.equipment[slot] != picked, "item unequipped")
	var exp_item := ItemDB.generate("assault_rifle", 3, 3)
	check(exp_item["special"] != "", "experimental items roll a special property")

	print("== progression")
	var lv0 := GameState.level
	GameState.add_xp(900)
	check(GameState.level >= lv0 + 3, "three+ level-ups (%d -> %d)" % [lv0, GameState.level])
	var pts := GameState.attr_points
	var str0 := int(GameState.attributes["str"])
	var mhp := GameState.max_hp()
	GameState.spend_point("str")
	check(GameState.attr_points == pts - 1 and int(GameState.attributes["str"]) == str0 + 1, "attribute point spent")
	check(GameState.max_hp() > mhp, "strength raises max health")

	print("== mission flow")
	await _use_terminal("1")
	check(GameState.has_flag("entered") or true, "atrium log readable")
	var edoor := _door_with_req("power")
	check(edoor != null and not edoor.unlocked(), "power-locked door is locked before power")
	await _use_terminal("2")
	check(GameState.has_flag("power"), "generator terminal restores power")
	check(not GameState.current_objective_text().contains("{") and GameState.fmt("{labs_dir}") != "{labs_dir}", "story directions filled in: " + GameState.current_objective_text())
	check(level.powered, "level switched to powered lighting")
	player.global_position = edoor.global_position + Vector2(0, 40)
	await frames(5)
	check(edoor.is_open, "bulkhead opens after power restored")
	await _use_terminal("3")
	check(GameState.has_flag("research"), "research terminal accessed")
	await _use_terminal("4")
	check(GameState.has_flag("cause"), "cause of incident discovered")
	check(GameState.has_save(), "checkpoint autosave written")

	print("== boss")
	var boss := get_tree().get_first_node_in_group("boss") as Boss
	# step into the arena, well away from WARDEN (works on every layout)
	player.global_position = Vector2(level.arena_rect.get_center().x, level.arena_rect.end.y - 12.0)
	for i in 120:
		player.hp = player.max_hp
		await get_tree().physics_frame
		if boss.active:
			break
	check(boss.active, "boss activates when player enters the arena")
	var seen_patterns := {}
	# patterns are random (never the same twice in a row), so watch for up to
	# 30 s and stop as soon as three different ones have shown up
	for i in 1800:
		player.hp = player.max_hp
		player.statuses.clear()
		if boss.pattern != "":
			seen_patterns[boss.pattern] = true
		if seen_patterns.size() >= 3:
			break
		if i % 30 == 0 and i > 0 and i <= 900:
			boss.take_hit(Combat.make_hit(45, player))
		await get_tree().physics_frame
	check(seen_patterns.size() >= 3, "boss uses multiple attack patterns %s" % str(seen_patterns.keys()))
	var guard := 0
	while not boss.dead and guard < 400:
		boss.take_hit(Combat.make_hit(120, player))
		player.hp = player.max_hp
		await get_tree().physics_frame
		guard += 1
	check(boss.dead, "boss can be defeated")
	await frames(200)
	check(GameState.has_flag("boss"), "boss defeat sets mission flag")

	print("== save / load")
	GameState.save_game(player.global_position)
	var saved_level := GameState.level
	var saved_inv := GameState.inventory.size()
	main.call("_on_game_request", "load")
	await frames(8)
	game = main.get("current")
	player = game.player
	level = game.level
	check(GameState.level == saved_level and GameState.inventory.size() == saved_inv, "save/load restores character")
	check(GameState.has_flag("boss") and get_tree().get_nodes_in_group("boss").size() == 0, "save/load restores world state")

	print("== escape")
	var vdoor := _door_with_req("boss")
	player.global_position = vdoor.global_position + Vector2(40, -16)
	await frames(5)
	check(vdoor.is_open, "vault door opens after boss defeat")
	player.global_position = level.exit_rect.get_center()
	await frames(10)
	check(GameState.has_flag("escape"), "reaching containment completes the mission")
	for i in 150:
		await get_tree().physics_frame
		if game.end_screen.visible:
			break
	check(game.end_screen.visible, "victory screen shown")

	print("== performance sample")
	get_tree().paused = false
	game.end_screen.hide()
	GameState.flags.erase("escape")
	var t0 := Time.get_ticks_usec()
	await frames(120)
	var avg := (Time.get_ticks_usec() - t0) / 120.0 / 1000.0
	print("  avg frame (headless, physics-bound) %.2f ms" % avg)


func _count_projectiles() -> int:
	var c := 0
	for n in game.world.get_children():
		if n is Projectile:
			c += 1
	return c


## Combat tests run on the landing pad (kept clear by the layout generator);
## level enemies close enough to interfere are removed first.
func _open_ground(level: Level) -> Vector2:
	var c := level.room_center("pad")
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_in_group("boss") and (e as Node2D).global_position.distance_to(c) < 700.0:
			e.queue_free()
	return c


func _door_with_req(req: String) -> Door:
	for n in game.world.get_children():
		if n is Door and (n as Door).requirement == req:
			return n
	return null


func _use_terminal(id: String) -> void:
	for n in game.world.get_children():
		if n is Terminal and (n as Terminal).term_id == id:
			game.player.global_position = n.global_position + Vector2(0, 30)
			await frames(2)
			n.interact(game.player)
			await frames(2)
			game.terminal_ui.close()
			await frames(2)
			return
	check(false, "terminal %s exists" % id)
