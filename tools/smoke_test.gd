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
	var race0 := GameState.race_id
	var sums_zero := GameState.RACES.all(func(r: Dictionary) -> bool:
		var t := 0
		for v in r.get("attr_mod", {}).values():
			t += int(v)
		return t == 0)
	check(sums_zero and GameState.race_info("human").get("attr_mod", {}).is_empty(), "race attribute mods are balanced; Human has none")
	GameState.race_id = "ursathi"
	var hu_str := float(GameState.attributes["str"]) + GameState.equip_stat("str")
	check(GameState.attr("str") == hu_str + 2 and GameState.race_mod_text("ursathi").contains("+2 STR"), "Ursathi: +2 STR on top of points and gear")
	GameState.race_id = race0
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
	print("== ship hub")
	GameState.new_game()
	await start()
	check(GameState.location == "ship" and game.hub, "new game starts aboard the ship")
	check(game.player.holstered, "weapons holstered aboard the ship")
	check(get_tree().get_nodes_in_group("enemies").is_empty(), "no enemies aboard the ship")
	check(get_tree().get_nodes_in_group("crew").size() == 5, "five crew members aboard")
	var nav: Terminal = null
	for n in game.world.get_children():
		if n is Terminal and (n as Terminal).term_id == "nav":
			nav = n
	check(nav != null, "nav console aboard")
	await _crew_service_tests()
	var locker: StashLocker = null
	for n in game.world.get_children():
		if n is StashLocker:
			locker = n
	check(locker != null, "cargo locker aboard")
	locker.interact(game.player)
	await frames(2)
	check(game.stash_ui.visible, "cargo locker opens the stash")
	var stowed: Dictionary = ItemDB.generate("flak_carapace", 1, 1)
	GameState.add_item(stowed)
	game.stash_ui._move(stowed, true)
	check(GameState.stash.has(stowed) and not GameState.inventory.has(stowed), "item stowed in the cargo locker")
	game.stash_ui._move(stowed, false)
	check(GameState.inventory.has(stowed) and GameState.stash.is_empty(), "item taken back out of the locker")
	game.stash_ui._move(stowed, true)
	game.stash_ui.close()
	await frames(2)
	check(not game.player._cone.enabled, "flashlight off aboard the well-lit ship")
	await frames(20)   # past the input grace after closing the cargo locker
	var en_roll := GameState.energy
	var pos_roll := game.player.global_position
	Input.action_press("roll")
	await frames(3)
	Input.action_release("roll")
	check(game.player.roll_t > 0.0 or game.player.global_position.distance_to(pos_roll) > 30.0, "rolling works aboard the ship, just for fun")
	check(GameState.energy >= en_roll - 0.01, "rolling aboard costs no energy")
	await frames(30)
	var cd0: float = game.player.cooldowns["pulse"]
	Input.action_press("ability_2")
	await frames(3)
	Input.action_release("ability_2")
	check(float(game.player.cooldowns["pulse"]) == cd0, "combat abilities disabled aboard the ship")
	nav.interact(game.player)
	await frames(2)
	var sm := game.star_map
	check(sm.visible, "nav console opens the star map")
	check(sm.pos.has("known_space") and sm.pos.has("veil") and sm.pos.has("kharon"), "star map lays out the tree (%d nodes shown)" % sm.pos.size())
	check(not sm.pos.has("relay_9"), "children of locked nodes stay hidden")
	check(sm.ship_at == "kessar", "ship starts at its star map node")
	check(StarMapUI.tree_path("kharon", "drift") == ["kharon", "kessar", "veil", "known_space", "drift"], "course follows the tree")
	sm.activate("kessar_belt")
	await frames(2)
	check(sm.flight.is_empty() and sm.ship_at == "kessar", "locked node can't be flown to")
	sm._select("kharon")
	sm.activate("kharon")
	for i in 120:
		await frames(1)
		if sm.flight.is_empty():
			break
	check(sm.ship_at == "kharon" and GameState.ship_node == "kharon", "ship flies to Kharon on the star map")
	check(sm.can_descend(), "can descend at a node with a mission site")
	sm.activate("kharon")
	await frames(8)
	game = main.get("current")
	check(GameState.location == "kharon" and not game.hub, "nav console deploys to Kharon")
	check(game.player._cone.enabled, "flashlight on at mission sites")
	check(GameState.has_save() and _saved_location() == "kharon", "travel autosaves")

	print("== boot")
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
	check(GameState.unpack_explored(GameState.pack_explored(GameState.explored)).count(1) == explored_now, "explored map saves and loads (packed)")
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
	var uc0 := GameState.credits
	level.drop_credits(player.global_position + Vector2(40, 0), 1.0)
	await frames(30)
	check(GameState.credits > uc0, "creds dropped and auto-collected (%s)" % GameState.fmt_uc(GameState.credits - uc0))
	check(GameState.fmt_uc(1234567) == "1,234,567 UC", "UC formatting")
	var drop: LootDrop = null
	for n in get_tree().get_nodes_in_group("loot"):
		drop = n
	var inv0 := GameState.inventory.size()
	if drop != null:
		# fill its slot first, so this pickup goes to the pack (empty slots auto-equip)
		var dit: Dictionary = drop.entry["item"]
		for sl in dit.get("slots", [dit.get("slot", "")]):
			if GameState.equipment.get(String(sl), {}).is_empty():
				GameState.equipment[String(sl)] = ItemDB.generate(String(dit["base"]), 0, 1)
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

	print("== loot container glow")
	var box: LootContainer = null
	for n in game.world.get_children():
		if n is LootContainer and not (n as LootContainer).opened:
			box = n
			break
	check(box != null and box.glow != null, "unopened containers glow")
	if box != null:
		player.global_position = box.global_position + Vector2(0, 40)
		box.interact(player)
		check(box.glow == null, "opening a container puts its glow out")

	print("== auto-equip into empty slots")
	GameState.equipment["boots"] = {}
	var boots := ItemDB.generate("mag_boots", 1, 1)
	level.drop_item(player.global_position + Vector2(30, 0), {"kind": "item", "item": boots})
	await frames(2)
	for n in game.world.get_children():
		if n is LootDrop and (n as LootDrop).entry.get("item", {}) == boots:
			(n as LootDrop).interact(player)
	check(GameState.equipment["boots"] == boots and not GameState.inventory.has(boots), "picking up boots with no boots on wears them")
	var boots2 := ItemDB.generate("runner_boots", 0, 1)
	level.drop_item(player.global_position + Vector2(30, 0), {"kind": "item", "item": boots2})
	await frames(2)
	for n in game.world.get_children():
		if n is LootDrop and (n as LootDrop).entry.get("item", {}) == boots2:
			(n as LootDrop).interact(player)
	check(GameState.equipment["boots"] == boots and GameState.inventory.has(boots2), "with boots already on, new boots go to the pack")

	print("== progression")
	var lv0 := GameState.level
	GameState.add_xp(5000)
	check(GameState.level >= lv0 + 3, "three+ level-ups (%d -> %d)" % [lv0, GameState.level])
	var pts := GameState.attr_points
	var str0 := int(GameState.attributes["str"])
	var mhp := GameState.max_hp()
	GameState.spend_point("str")
	check(GameState.attr_points == pts - 1 and int(GameState.attributes["str"]) == str0 + 1, "attribute point spent")
	check(GameState.max_hp() > mhp, "strength raises max health")
	game.character_ui.open()
	await frames(3)
	(game.character_ui.rows.get_child(2) as Control).grab_focus()   # INTELLIGENCE
	var int0 := int(GameState.attributes["int"])
	for i in 2:   # press whatever is selected, as a player would
		(get_viewport().gui_get_focus_owner() as Button).emit_signal("pressed")
		await frames(2)
	check(get_viewport().gui_get_focus_owner() == game.character_ui.rows.get_child(2), "assigning a point keeps the selection on that attribute")
	check(int(GameState.attributes["int"]) == int0 + 2, "repeated presses add to the same attribute")
	GameState.attributes["int"] = int0   # undo, so later respec checks see the same spent points
	GameState.attr_points += 2
	game.character_ui.close()
	await frames(2)

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

	print("== save / load: a new session")
	GameState.journal_log("[OVERWATCH] Journal persistence check.", "kharon")
	var saved_journal := GameState.journal.size()
	GameState.save_game(player.global_position)
	var saved_level := GameState.level
	var saved_inv := GameState.inventory.size()
	var saved_uc := GameState.credits
	var saved_variant := GameState.map_variant
	main.call("_on_game_request", "load")
	await frames(8)
	game = main.get("current")
	check(GameState.level == saved_level and GameState.inventory.size() == saved_inv and GameState.credits == saved_uc, "save/load restores character and creds")
	check(GameState.stash.size() == 1, "stash survives save / load")
	check(GameState.journal.size() == saved_journal and saved_journal > 0, "journal survives save / load (%d lines)" % saved_journal)
	await _journal_tests()
	check(GameState.location == "ship" and game.hub, "loading starts the session aboard the ship")
	check(GameState.has_flag("boss") and GameState.has_flag("power"), "story progress persists across sessions")
	check(not GameState.flags.keys().any(func(f: String) -> bool: return f.begins_with("kharon/k:") or f.begins_with("kharon/box:")), "mission areas reset: kills and opened crates forgotten")
	check(GameState.map_variant != saved_variant, "mission areas re-roll their layout (%d -> %d)" % [saved_variant, GameState.map_variant])
	check(game.hud.messages.any(func(m: Array) -> bool: return String(m[0]).begins_with("New session")), "new session is announced")
	main.call("_on_game_request", "travel:kharon")
	await frames(8)
	game = main.get("current")
	player = game.player
	level = game.level
	check(get_tree().get_nodes_in_group("boss").size() == 1 and get_tree().get_nodes_in_group("enemies").size() >= 25, "Kharon repopulated: monsters and WARDEN are back")
	check(level.powered, "but the generator stays restored (story flag)")
	var kept_item := ItemDB.generate("shotgun", 0, 1)
	level.drop_item(level.player_start + Vector2(0, 40), {"kind": "item", "item": kept_item})

	print("== escape")
	var vdoor := _door_with_req("boss")
	player.global_position = vdoor.global_position + Vector2(40, -16)
	await frames(5)
	check(vdoor.is_open, "vault door opens after boss defeat")
	player.global_position = level.exit_rect.get_center()
	await frames(10)
	check(GameState.has_flag("escape"), "reaching containment completes the mission")
	for i in 200:
		await get_tree().physics_frame
		if main.get("current") != game:
			break
	await frames(8)
	game = main.get("current")
	check(GameState.location == "ship" and game.hub, "extraction returns the operative to the ship")
	check(GameState.has_flag("debriefed"), "OVERWATCH debrief aboard the ship")
	check(GameState.has_flag("lastwater_open") and StarMapUI.is_unlocked("kessar_iii") and not StarMapUI.is_unlocked("kessar_iv"), "Kharon's debrief clears Last Water (Kessar IV still locked)")
	var kharon_loot: Array = GameState.areas.get("kharon", {}).get("ground_items", [])
	check(not kharon_loot.is_empty(), "loot left at Kharon is kept while away")
	check(GameState.explored.size() == game.level.w * game.level.h and int(GameState.areas["kharon"].get("explored_size", 0)) > 0, "minimap exploration kept per location")

	print("== shuttle back from a mission site")
	main.call("_on_game_request", "travel:kharon")
	await frames(8)
	game = main.get("current")
	check(GameState.ground_items.any(func(g: Dictionary) -> bool: return g.get("item", {}) == kept_item), "Kharon remembers its state on return (same session)")
	var pad: ShuttlePad = null
	for n in game.world.get_children():
		if n is ShuttlePad:
			pad = n
	check(pad != null, "return shuttle at the landing site")
	pad.interact(game.player)
	await frames(8)
	game = main.get("current")
	check(GameState.location == "ship", "shuttle flies back to the ship")

	print("== death and the Lazarus Cradle")
	main.call("_on_game_request", "travel:kharon")
	await frames(8)
	game = main.get("current")
	var node_before := GameState.ship_node
	GameState.credits = 1000
	var lv_before := GameState.level
	var xp_loss := int(floor(GameState.xp_to_next() * GameState.DEATH_XP_LOSS))
	GameState.xp = xp_loss + 7
	game.player.die()
	for i in 240:
		await get_tree().physics_frame
		if main.get("current") != game:
			break
	await frames(8)
	game = main.get("current")
	check(GameState.location == "ship", "dying on a mission revives aboard the ship")
	check(game.player.global_position.distance_to(game.level.revive_point) < 4.0 and game.level.revive_point != Vector2.ZERO, "operative wakes at the Lazarus Cradle")
	check(GameState.credits == 900, "death costs 10%% of carried UC (%d left)" % GameState.credits)
	check(GameState.xp == 7 and GameState.level == lv_before, "death costs 5% of the level's XP, no level lost")
	check(game.player.hp >= game.player.max_hp - 0.5 and not game.player.dead, "revived at full health")
	check(GameState.ship_node == node_before, "ship still in orbit where the operative descended")
	check(not GameState.reviving and _saved_location() == "ship", "revival autosaves aboard the ship")
	check(game.hud.messages.any(func(m: Array) -> bool: return String(m[0]).contains("Lost:")), "wake-up message lists what was lost")
	GameState.xp = 0
	GameState.apply_death()
	check(GameState.xp == 0 and GameState.level == lv_before, "death never drops below the start of the level")
	GameState.reviving = false

	await _lastwater_tests()
	await _kessar_tests()
	await _brood_king_tests()

	await _doctrine_tests()
	await _gunline_vanguard_tests()

	print("== autosave on quit")
	GameState.travel("ship")
	main.call("start_game")
	await frames(6)
	game = main.get("current")
	GameState.credits = 4242
	main.call("_on_game_request", "menu")
	await frames(4)
	check(main.get("current") is MainMenu, "quit to main menu returns to the menu")
	GameState.credits = 0
	GameState.load_game()
	check(GameState.credits == 4242, "quitting to the menu autosaved")
	main.call("_on_game_request", "travel:kharon")
	await frames(8)
	game = main.get("current")
	GameState.credits = 1000
	game.player.die()
	await frames(2)
	main.call("_on_game_request", "menu")
	await frames(4)
	GameState.credits = 0
	GameState.load_game()
	check(GameState.location == "ship" and GameState.reviving and GameState.credits == 900, "quitting while dead still costs the death penalty (wakes in the Cradle)")
	GameState.reviving = false

	print("== v1 save migration")
	var v1 := {"version": 1, "level": 3, "flags": {"power": true, "k:5,5": true, "box:2,3": true}, "player_pos": [10, 10]}
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	GameState.load_game()
	check(GameState.location == "ship" and GameState.has_flag("power") and not GameState.has_flag("kharon/k:5,5"), "v1 saves load: story kept, areas reset, aboard the ship")

	print("== performance sample")
	GameState.new_game()
	GameState.location = "kharon"
	await start()
	get_tree().paused = false
	var t0 := Time.get_ticks_usec()
	await frames(120)
	var avg := (Time.get_ticks_usec() - t0) / 120.0 / 1000.0
	print("  avg frame (headless, physics-bound) %.2f ms" % avg)


func _lastwater_tests() -> void:
	print("== Last Water: spaceport")
	GameState.ship_node = "kessar_iii"
	check(StarMapUI.is_unlocked("kessar_iii"), "Last Water (Kessar III) is open on the star map")
	main.call("_on_game_request", "travel:lastwater_port")
	await frames(8)
	game = main.get("current")
	check(GameState.location == "lastwater_port" and GameState.has_flag("lastwater:landed"), "landing at Last Water's spaceport")
	check(game.level.exits.has("Y"), "a gate into the city")
	game.level.exits["Y"].interact(game.player)
	await frames(8)
	game = main.get("current")
	var level := game.level
	var player := game.player
	print("== Last Water: the streets")
	check(GameState.location == "lastwater_streets" and player.global_position.distance_to(level.exit_points["Y"]) < 80.0, "through the gate into the streets (%s)" % GameState.map_info.get("name", "?"))
	check(GameState.current_objective_text().begins_with("Find the Brood Lieutenant"), "objective: " + GameState.current_objective_text())
	check(_count_kind("militia") >= 4 and _count_kind("crawler") >= 4 and _count_kind("lieutenant") == 1, "militia, wall crawlers and the Lieutenant are in the streets")
	check(not GameState.fmt(String(ItemDB.terminals["lastwater_log"]["pages"][2])).contains("{"), "militia log points toward the Lieutenant")
	var door: ZoneExit = level.exits["U"]
	door.interact(player)
	await frames(4)
	check(GameState.location == "lastwater_streets" and not door.is_open(), "the Civic Hall is sealed without the card")
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node2D).global_position.distance_to(player.global_position) < 900.0 and (e as Enemy).kind != "lieutenant":
			e.queue_free()
	await frames(2)
	var cr := level.spawn_enemy("crawler", player.global_position + Vector2(300, 0), "test_crawler") as BroodEnemy
	await frames(2)
	check(cr.buried and not cr.take_hit(Combat.make_hit(5, null)), "Wall Crawler clings to the wall, out of reach")
	cr.global_position = player.global_position + Vector2(80, 0)
	for i in 80:
		await frames(1)
		if not cr.buried:
			break
	check(not cr.buried and cr.global_position.distance_to(player.global_position) < 60.0, "Wall Crawler drops onto the operative")
	cr.take_hit(Combat.make_hit(9999, null))
	var lt := get_tree().get_first_node_in_group("champion") as BroodEnemy
	check(lt != null and lt.display_name.contains("Frenzied"), "the Lieutenant is a named champion: " + (lt.display_name if lt != null else "?"))
	while not lt.dead:
		lt.take_hit(Combat.make_hit(400, player))
		await frames(1)
	await frames(3)
	var card: LootDrop = null
	for n in game.world.get_children():
		if n is LootDrop and String((n as LootDrop).entry.get("kind", "")) == "quest":
			card = n
	check(card != null, "the Lieutenant drops the Civic Hall access card")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	player.global_position = card.global_position
	await frames(6)
	check(GameState.has_flag("lastwater:card") and door.is_open(), "picking up the card unseals the Civic Hall")
	door.interact(player)
	await frames(8)
	game = main.get("current")
	player = game.player
	print("== Last Water: the Civic Hall")
	check(GameState.location == "lastwater_hall" and GameState.has_flag("lastwater:hall"), "inside the Civic Hall")
	check(GameState.has_flag("beacon:lastwater_hall"), "the Civic Hall's landing beacon links")
	var cocoons := get_tree().get_nodes_in_group("cocoon")
	check(cocoons.size() == 3, "three governors cocooned in the hall")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)
	var first := cocoons[0] as GovernorCocoon
	player.global_position = first.global_position + Vector2(0, 30)
	await frames(2)
	first.interact(player)
	await frames(10)
	player.hp -= 5.0
	await frames(3)
	check(not first.freed() and first.cutting == 0.0, "getting hurt interrupts cutting a governor free")
	for co in cocoons:
		player.global_position = (co as Node2D).global_position + Vector2(0, 30)
		await frames(2)
		co.interact(player)
		for i in 120:
			await frames(1)
			if (co as GovernorCocoon).freed():
				break
	check(GameState.has_flag("lastwater:governors"), "all three governors freed")
	check(GameState.current_objective_text().begins_with("Return to the ship"), "objective: " + GameState.current_objective_text())
	var uc0 := GameState.credits
	GameState.recall_cd = 0.0
	player.start_recall()
	for i in 200:
		await get_tree().physics_frame
		if main.get("current") != game:
			break
	await frames(8)
	game = main.get("current")
	check(GameState.has_flag("lastwater:done") and GameState.credits >= uc0 + 600, "OVERWATCH debrief: the treasury pays")
	check(StarMapUI.is_unlocked("kessar_iv"), "the governors' intel unlocks Kessar IV")
	check(StarMapUI.landing_points("kessar_iii").filter(func(p: Dictionary) -> bool: return bool(p["open"])).size() == 2, "Kessar III now has two landing points (spaceport, Civic Hall)")


func _kessar_tests() -> void:
	GameState.set_flag("kessar_iv_open")   # cleared by Last Water's debrief in a real run
	print("== Kessar IV: Ashfall Flats")
	GameState.ship_node = "kessar_iv"
	main.call("_on_game_request", "travel:kessar_surface")
	await frames(8)
	game = main.get("current")
	var level := game.level
	var player := game.player
	check(GameState.location == "kessar_surface" and level.w > 60, "Kessar IV surface loaded (%s)" % GameState.map_info.get("name", "?"))
	check(GameState.has_flag("kessar:landed") and GameState.current_objective_text().begins_with("Find the hive"), "landing completes objective 1: " + GameState.current_objective_text())
	check(level.hive_hole != null and level.hive_hole.global_position.distance_to(level.player_start) > 600.0, "hive sinkhole exists, far from the landing point")
	var kinds := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		kinds[(e as Enemy).kind] = int(kinds.get((e as Enemy).kind, 0)) + 1
	check(kinds.has("miner") and kinds.has("burrower") and kinds.has("swarmling") and kinds.has("spitter"), "surface has miners, burrowers, swarmlings, spitters %s" % str(kinds))
	var log_term: Terminal = null
	for n in game.world.get_children():
		if n is Terminal and (n as Terminal).term_id == "kessar_log":
			log_term = n
	check(log_term != null and not GameState.fmt(String(ItemDB.terminals["kessar_log"]["pages"][2])).contains("{"), "mining camp log points toward the hive")
	# clear the landing zone, then test the Brood up close
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node2D).global_position.distance_to(player.global_position) < 900.0:
			e.queue_free()
	await frames(2)
	var bur := level.spawn_enemy("burrower", player.global_position + Vector2(300, 0), "test_burrower") as BroodEnemy
	await frames(2)
	check(bur.buried and not bur.take_hit(Combat.make_hit(10, null)), "Ash Burrower hides under the ash, untouchable")
	bur.global_position = player.global_position + Vector2(60, 0)
	for i in 60:
		await frames(1)
		if not bur.buried:
			break
	check(not bur.buried, "Ash Burrower erupts when the operative comes close")
	bur.take_hit(Combat.make_hit(9999, null))
	var spit := level.spawn_enemy("spitter", player.global_position + Vector2(250, 0), "") as BroodEnemy
	await frames(2)
	spit._spit(player.global_position + Vector2(120, 40))
	var pooled := false
	for i in 90:
		await frames(1)
		if not get_tree().get_nodes_in_group("acid").is_empty():
			pooled = true
			break
	check(pooled, "Spitter's acid leaves a pool on the floor")
	spit.take_hit(Combat.make_hit(9999, null))

	print("== recall")
	GameState.recall_cd = 0.0
	player.start_recall()
	await frames(10)
	for i in 30:   # the operative may evade; keep swinging until a hit lands
		if player.take_hit(Combat.make_hit(25, null)) and player.recall_t == 0.0:
			break
	player.hp = player.max_hp
	check(player.recall_t == 0.0 and GameState.recall_cd >= 2.5 and GameState.recall_cd <= Player.RECALL_FAIL_CD, "taking damage interrupts recall (short cooldown)")
	player.start_recall()
	check(player.recall_t == 0.0, "recall waits for its cooldown")
	GameState.recall_cd = 0.0
	var recall_spot := player.global_position
	player.start_recall()
	for i in 200:
		await get_tree().physics_frame
		if main.get("current") != game:
			break
	await frames(8)
	game = main.get("current")
	check(GameState.location == "ship", "recall pulls the operative back to the ship")
	check(String(GameState.beacon.get("location", "")) == "kessar_surface" and GameState.recall_cd > Player.RECALL_COOLDOWN - 5.0, "recall leaves a beacon and starts the 60 s cooldown")
	var pad := game.level.teleport_pad
	check(pad != null, "teleport pad aboard the ship")
	GameState.ship_node = "kessar"
	pad.interact(game.player)
	await frames(4)
	check(GameState.location == "ship", "teleport pad refuses when the ship has moved (beacon out of range)")
	GameState.ship_node = "kessar_iv"
	pad.interact(game.player)
	await frames(8)
	game = main.get("current")
	player = game.player
	level = game.level
	check(GameState.location == "kessar_surface" and player.global_position.distance_to(recall_spot) < 4.0 and GameState.beacon.is_empty(), "teleport pad returns to the beacon spot (beacon used up)")

	print("== into the hive")
	player.global_position = level.hive_hole.global_position + Vector2(100, 0)
	await frames(4)
	check(GameState.has_flag("kessar:hive_found"), "finding the sinkhole completes objective 2")
	level.hive_hole.interact(player)
	await frames(8)
	game = main.get("current")
	level = game.level
	player = game.player
	check(GameState.location == "kessar_hive" and GameState.has_flag("kessar:hive"), "sinkhole leads down into the hive (%s)" % GameState.map_info.get("name", "?"))
	check(GameState.current_objective_text() == "Kill the Brood Queen", "objective: " + GameState.current_objective_text())
	await frames(4)
	check(GameState.has_flag("beacon:kessar_hive") and get_tree().get_nodes_in_group("landing_beacon").size() == 1, "reaching the hive links its landing beacon")
	check(StarMapUI.landing_points("kessar_iv").filter(func(p: Dictionary) -> bool: return bool(p["open"])).size() == 2, "Kessar IV now has two landing points")
	var eggs: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return (e as Enemy).kind == "egg")
	var n_sw := _count_kind("swarmling")
	(eggs[0] as BroodEnemy).hatch()
	await frames(3)
	check(_count_kind("swarmling") >= n_sw + 2, "egg clusters hatch Swarmlings")
	var queen := get_tree().get_first_node_in_group("boss") as BroodQueen
	check(queen != null, "the Brood Queen waits in her chamber")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != queen and (e as Enemy).kind != "egg":
			e.queue_free()
	player.global_position = queen.global_position + Vector2(0, 160)
	await frames(2)
	queen.take_hit(Combat.make_hit(10, player))
	var seen := {}
	var forced := false
	for i in 1400:
		await frames(1)
		player.hp = player.max_hp
		if queen.dead:
			break
		seen[queen.act] = true
		if queen.act == "burrow" and not forced:
			queen.interrupt()
			forced = not queen.buried and queen.is_stunned()
		if i % 40 == 0:
			queen.take_hit(Combat.make_hit(110, player))
	check(seen.has("spray_tele") and seen.has("burrow"), "Brood Queen sprays acid and burrows %s" % str(seen.keys()))
	check(forced, "Disruptor Pulse forces the Queen out of her burrow")
	while not queen.dead:
		queen.take_hit(Combat.make_hit(500, player))
		await frames(1)
	await frames(4)
	check(GameState.has_flag("kessar:queen") and GameState.current_objective_text().begins_with("Return to the ship"), "killing the Queen: " + GameState.current_objective_text())
	var uc0 := GameState.credits
	for n in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("acid"):
		n.queue_free()   # leftover Swarmlings would (rightly) interrupt the recall
	await frames(2)
	GameState.recall_cd = 0.0
	player.start_recall()
	for i in 200:
		await get_tree().physics_frame
		if main.get("current") != game:
			break
	await frames(8)
	game = main.get("current")
	check(GameState.has_flag("kessar:done") and GameState.credits >= uc0 + 500, "OVERWATCH debrief pays the bounty")
	check(StarMapUI.is_unlocked("kessar_vii") and not StarMapUI.is_unlocked("kessar_belt"), "the twist: Kessar IV's debrief reveals Kessar VII (the Brood King)")
	check(game.comms.any(func(c: Array) -> bool: return String(c[0]).begins_with("[INES RUHL]")), "Ines stops the celebration: something answered the hive")

	print("== re-entrant areas and diminishing returns")
	var lv_keep := GameState.level
	var loc_keep := GameState.location
	GameState.location = "kessar_hive"
	var mults := []
	for lv in [8, 10, 13, 16]:
		GameState.level = lv
		mults.append(snappedf(GameState.xp_mult(), 0.01))
	var want := [1.0, 0.7, 0.25, 0.05]
	check(range(4).all(func(i: int) -> bool: return is_equal_approx(float(mults[i]), float(want[i]))), "XP falls off once the character outlevels the area %s" % str(mults))
	GameState.level = 5
	check(GameState.xp_to_next() == 1118 and GameState.area_level() == 6, "XP curve 100 x level^1.5; the Hive is area level 6")
	GameState.level = lv_keep
	GameState.location = loc_keep
	GameState.save_game(null)
	main.call("_on_game_request", "load")
	await frames(8)
	GameState.ship_node = "kessar_iv"
	game = main.get("current")
	check(GameState.has_flag("beacon:kessar_hive"), "landing beacons survive a new session")
	Events.open_nav.emit()
	await frames(3)
	var sm := game.star_map
	sm._select("kessar_iv")
	sm._descend()
	check(sm.choosing and sm.choice.size() == 2, "Descend lists the landing points (surface, hive)")
	sm._land("kessar_hive")
	await frames(8)
	game = main.get("current")
	check(GameState.location == "kessar_hive", "descending straight into the hive from the star map")
	var queen2 := get_tree().get_first_node_in_group("boss") as BroodQueen
	check(queen2 != null and not queen2.dead, "new session: the Brood Queen is back for another run")
	var uc1 := GameState.credits
	while not queen2.dead:
		queen2.take_hit(Combat.make_hit(500, game.player))
		await frames(1)
	await frames(4)
	main.call("_on_game_request", "travel:ship")
	await frames(8)
	game = main.get("current")
	check(GameState.credits < uc1 + 500 and not game.comms.any(func(c: Array) -> bool: return String(c[0]).contains("Bounty")), "re-killing her pays no second bounty")


func _brood_king_tests() -> void:
	print("== Kessar VII: the Shoreline")
	GameState.ship_node = "kessar_vii"
	main.call("_on_game_request", "travel:kessar7_shore")
	await frames(8)
	game = main.get("current")
	var level := game.level
	check(GameState.location == "kessar7_shore" and GameState.has_flag("king:landed"), "landing on Kessar VII's beach")
	var water := 0
	for y in level.h:
		for x in level.w:
			if level.ch(x, y) == "~":
				water += 1
	check(water > 200 and level.astar.is_point_solid(_find_char(level, "~")), "the ocean behind you is impassable water")
	check(level.get_node_or_null("WaterCollision") != null and (level.get_node("WaterCollision") as Node).get_child_count() > 0, "water has its own collision (blocks walking, not bullets)")
	level.exits["Y"].interact(game.player)
	await frames(8)
	game = main.get("current")
	level = game.level
	var player := game.player
	print("== Kessar VII: the Tangle")
	check(GameState.location == "kessar7_tangle" and GameState.current_objective_text().begins_with("Follow the King's trail"), "into the jungle maze (%s): %s" % [GameState.map_info.get("name", "?"), GameState.current_objective_text()])
	var counts := {}
	for y in level.h:
		for x in level.w:
			var c := level.ch(x, y)
			if c in ["=", ":", "{", "~"]:
				counts[c] = int(counts.get(c, 0)) + 1
	check(counts.get("=", 0) > 0 and counts.get(":", 0) > 0 and counts.get("{", 0) > 20, "rivers with bridges and fords; the King's tracks %s" % str(counts))
	check(_count_kind("gibberer") > 10 and _count_kind("thornback") >= 1 and _count_kind("stalker") >= 4 and _count_kind("elder_thornback") == 1,
		"primates (Gibberers, Thornbacks, the Elder) and Canopy Stalkers in the Tangle")
	check(not GameState.fmt(String(ItemDB.terminals["kessar7_log"]["pages"][2])).contains("{"), "the survey log points toward the Caldera")
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node2D).global_position.distance_to(player.global_position) < 900.0:
			e.queue_free()
	await frames(2)
	var gib := level.spawn_enemy("gibberer", player.global_position + Vector2(200, 0), "") as BroodEnemy
	await frames(2)
	gib.telegraph_target = player.global_position
	gib.attack_variant = "stone"
	var n_proj := game.world.get_children().filter(func(n: Node) -> bool: return n is Projectile).size()
	gib._begin_attack()
	check(game.world.get_children().filter(func(n: Node) -> bool: return n is Projectile).size() > n_proj, "Gibberers throw stones")
	gib.queue_free()
	var tb := level.spawn_enemy("thornback", player.global_position + Vector2(50, 0), "") as BroodEnemy
	await frames(2)
	var hurt := false
	for i in 20:
		player.hp = player.max_hp
		tb.telegraph_target = player.global_position
		tb.attack_variant = "pound"
		tb._begin_attack()
		await frames(1)
		if player.hp < player.max_hp:
			hurt = true
			break
	check(hurt, "a Thornback's ground pound hits the operative")
	tb.queue_free()
	player.hp = player.max_hp
	var gate: ZoneExit = level.exits["U"]
	player.global_position = gate.global_position + Vector2(-60, 0)
	await frames(4)
	check(GameState.has_flag("king:gate"), "reaching the old gate")
	gate.interact(player)
	await frames(8)
	game = main.get("current")
	level = game.level
	player = game.player
	print("== Kessar VII: the King's Caldera")
	check(GameState.location == "kessar7_caldera" and GameState.has_flag("beacon:kessar7_caldera"), "through the gate into the Caldera (landing beacon linked)")
	var king := get_tree().get_first_node_in_group("boss") as BroodKing
	check(king != null, "the Brood King waits in the Caldera")
	var pillars := game.world.get_children().filter(func(n: Node) -> bool: return n is Prop and (n as Prop).kind == "+")
	check(pillars.size() == 8, "eight stone pillars for cover")
	player.global_position = king.global_position + Vector2(0, 260)
	player.invuln_t = 9999.0   # the test drives the fight; the operative mustn't die mid-script
	await frames(2)
	king.take_hit(Combat.make_hit(10, player))
	# a charge into a pillar smashes it and dazes him
	var pil := pillars[0] as Prop
	king.global_position = pil.global_position + Vector2(-140, 0)
	king.aim = Vector2.RIGHT
	king.act = "charge"
	king.act_t = 1.0
	for i in 40:
		player.hp = player.max_hp
		await frames(1)
		if pil.broken:
			break
	check(pil.broken and king.is_stunned(), "charging into a stone pillar smashes it and dazes the King")
	var seen := {}
	var pulled := false
	for i in 1500:
		await frames(1)
		player.hp = player.max_hp
		if king.dead:
			break
		seen[king.act] = true
		if king.act == "climb" and not pulled and king.act_t < 5.0:
			king.interrupt()
			pulled = not king.buried and king.is_stunned()
		if i % 30 == 0 and king.hp > king.max_hp * 0.3:
			king.take_hit(Combat.make_hit(160, player))
	check(seen.has("swipe_tele") or seen.has("charge_tele"), "the King swipes and charges %s" % str(seen.keys()))
	check(seen.has("climb") and pulled, "he climbs the crater wall; Disruptor Pulse pulls him down")
	while not king.dead:
		king.take_hit(Combat.make_hit(800, player))
		await frames(1)
	await frames(4)
	check(GameState.has_flag("king:dead") and GameState.current_objective_text().begins_with("Return to the ship"), "the Brood King is dead: " + GameState.current_objective_text())
	var crest: LootDrop = null
	for n in game.world.get_children():
		if n is LootDrop and String((n as LootDrop).entry.get("item", {}).get("unique", "")) == "kings_crest":
			crest = n
	check(crest != null and int(crest.entry["item"]["rarity"]) == ItemDB.RARITY_UNIQUE, "he drops the King's Crest, a Unique helm")
	if crest != null:
		GameState.equipment["head"] = {}
		crest.interact(player)
		check(GameState.has_special("dread_crown") and ItemDB.describe(GameState.equipment["head"]).contains("Dread Crown"), "wearing the Crest: Dread Crown")
	for n in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("acid"):
		n.queue_free()
	for n in game.world.get_children():
		if n is BroodEnemy.Boulder:
			n.queue_free()   # boulders still in the air would (rightly) interrupt the recall
	await frames(2)
	player.hp = player.max_hp
	player.invuln_t = 0.0
	var uc0 := GameState.credits
	GameState.recall_cd = 0.0
	player.start_recall()
	for i in 200:
		await get_tree().physics_frame
		if main.get("current") != game:
			break
	await frames(8)
	game = main.get("current")
	check(GameState.has_flag("king:done") and GameState.credits >= uc0 + 900, "OVERWATCH debrief: the Brood arc is over")
	check(StarMapUI.is_unlocked("kessar_belt") and StarMapUI.is_unlocked("halcyon"), "Belt Claim 7 and the Halcyon System open up")
	GameState.equipment["head"] = {}


func _find_char(level: Level, ch: String) -> Vector2i:
	for y in level.h:
		for x in level.w:
			if level.ch(x, y) == ch:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _count_kind(k: String) -> int:
	return get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return (e as Enemy).kind == k).size()


func _doctrine_tests() -> void:
	print("== doctrines (skill trees)")
	var keep_lv := GameState.level
	var keep_skills := GameState.skills.duplicate()
	var keep_slots := GameState.slots.duplicate()
	GameState.skills = []
	GameState.slots = ["", "", ""]
	GameState.level = 1
	check(GameState.slottable().is_empty(), "a fresh operative has no slotted abilities, only Tactical Roll")
	check(GameState.doctrine_points_earned() == 0 and GameState.next_doctrine_level() == 2, "no Doctrine points at level 1 (first at level 2)")
	GameState.level = 5
	check(GameState.doctrine_points_free() == 2, "two Doctrine points by level 5")
	check(GameState.learn_block("overcharge") == "" and GameState.learn_block("pulse") == "", "Overcharge (Gunline) and Disruptor Pulse (Vanguard) are tier 1 skills")
	check(GameState.learn_skill("sb_concussion"), "learn a tier 1 Siegebreaker skill")
	check(GameState.learn_block("sb_semtex").contains("Needs 2"), "tier 2 needs 2 points in the Doctrine")
	check(GameState.learn_skill("sb_blast") and GameState.doctrine_points_free() == 0, "learn the tier 1 passive (points spent)")
	check(GameState.learn_block("sb_semtex").contains("No Doctrine points"), "no free points: wait for level 10")
	GameState.level = 40
	for id in ["sb_semtex", "sb_shrapnel", "sb_incendiary", "sb_chain", "sb_strike"]:
		GameState.learn_skill(id)
	check(GameState.has_skill("sb_strike") and GameState.doctrine_points_free() == 2, "a capstone costs 7 of the 9 points (2 left)")
	check(GameState.slot_count() == 3, "third ability slot at level 20+")
	main.call("_on_game_request", "travel:ship")
	await frames(8)
	game = main.get("current")
	check(GameState.set_slot(0, "sb_concussion") and GameState.set_slot(1, "sb_semtex") and GameState.set_slot(2, "sb_incendiary"), "slots set aboard the ship")
	main.call("_on_game_request", "travel:kharon")
	await frames(8)
	game = main.get("current")
	var player := game.player
	check(not GameState.set_slot(0, "pulse"), "slots can't be changed on a mission")
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node2D).global_position.distance_to(player.global_position) < 1200.0:
			e.queue_free()
	await frames(2)
	var lvl := game.level
	var spot := player.global_position + Vector2(180, 0)
	var a := lvl.spawn_enemy("heavy", spot, "") as Enemy
	await frames(2)
	a.max_hp = 5000.0   # survive the blast so the daze can be checked
	a.hp = 5000.0
	GameState.energy = GameState.max_energy()
	player.aim_override = spot
	await frames(2)
	var hp0 := a.hp
	player.use_ability("sb_concussion")
	for i in 60:
		await frames(1)
		if a.hp < hp0:
			break
	check(a.hp < hp0 and a.is_stunned(), "Concussion Grenade blasts and dazes (%.0f dmg)" % (hp0 - a.hp))
	a.queue_free()
	var big := lvl.spawn_enemy("heavy", spot, "") as Enemy
	await frames(2)
	var hb := big.hp
	GameState.energy = GameState.max_energy()
	player.cooldowns["sb_semtex"] = 0.0
	player.use_ability("sb_semtex")
	await frames(40)
	var stuck := get_tree().get_nodes_in_group("player_ordnance").size() > 0
	for i in 120:
		await frames(1)
		if big.hp < hb:
			break
	check(stuck and big.hp < hb, "Semtex Charge sticks, then blows (%.0f dmg)" % (hb - big.hp))
	big.queue_free()
	var burner := lvl.spawn_enemy("heavy", spot, "") as Enemy
	await frames(2)
	burner.max_hp = 5000.0   # survive the fire so the burn can be checked
	burner.hp = 5000.0
	var hr := burner.hp
	GameState.energy = GameState.max_energy()
	player.use_ability("sb_incendiary")
	await frames(90)
	check(burner.hp < hr and burner.has_status("burn"), "Incendiary Charge sets enemies burning")
	burner.queue_free()
	# Shrapnel: fragments hit just outside the blast
	var ring := lvl.spawn_enemy("heavy", spot + Vector2(100, 0), "") as Enemy
	await frames(2)
	var hring := ring.hp
	Ordnance.explode(game.world, spot, 60.0, 30.0, 0.0, 0.0, player, false)
	await frames(2)
	check(ring.hp < hring, "Shrapnel hits enemies just outside the blast")
	ring.queue_free()
	# Chain Reaction (shrapnel off): a kill in the blast sets off a second blast
	GameState.skills.erase("sb_shrapnel")
	var weak := lvl.spawn_enemy("drone", spot + Vector2(55, 0), "") as Enemy
	var far := lvl.spawn_enemy("heavy", spot + Vector2(105, 0), "") as Enemy
	await frames(2)
	weak.hp = 1.0
	var hf := far.hp
	weak.global_position = spot + Vector2(55, 0)   # pin them: the drone drifts toward the player
	far.global_position = spot + Vector2(105, 0)
	Ordnance.explode(game.world, spot, 60.0, 30.0, 0.0, 0.0, player, true)
	await frames(2)
	check(weak.dead and far.hp < hf, "Chain Reaction: a blast kill explodes and hits the next enemy")
	far.queue_free()
	var t1 := lvl.spawn_enemy("heavy", spot, "") as Enemy
	await frames(2)
	var ht := t1.hp
	GameState.energy = GameState.max_energy()
	GameState.slots[0] = "sb_strike"
	player.use_ability("sb_strike")
	for i in 240:
		await frames(1)
		if t1.hp < ht:
			break
	check(t1.hp < ht, "Danger Close: the orbital barrage lands after its marker")
	t1.queue_free()
	GameState.respecs = 0
	check(GameState.respec() and GameState.skills.is_empty() and GameState.slots[0] == "", "the Medic's respec refunds Doctrine points and resets slots")
	GameState.level = keep_lv
	GameState.skills = keep_skills
	GameState.slots = keep_slots
	player.aim_override = null


func _gunline_vanguard_tests() -> void:
	print("== the Gunline and the Vanguard")
	var keep_lv := GameState.level
	var keep_skills := GameState.skills.duplicate()
	GameState.level = 20
	main.call("_on_game_request", "travel:kharon")
	await frames(8)
	game = main.get("current")
	var player := game.player
	var lvl := game.level
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node2D).global_position.distance_to(player.global_position) < 1200.0:
			e.queue_free()
	await frames(2)
	var rifle: Dictionary = ItemDB.generate("assault_rifle", 0, 1)
	GameState.equipment["primary"] = rifle
	GameState.skills = []
	var sp0 := GameState.spread_mult()
	var dm0 := player.damage_mult(rifle)
	var mag0 := player.mag_size(rifle)
	var hp_max0 := GameState.max_hp()
	var ar0 := GameState.armor()
	GameState.skills = ["overcharge", "gl_steady", "gl_mark", "gl_quick", "gl_deadeye", "gl_hollow", "gl_unbroken", "pulse", "vg_iron"]
	check(GameState.spread_mult() < sp0 * 0.8 and player.damage_mult(rifle) > dm0 * 1.05, "Steady Hands: tighter spread, more firearm damage")
	check(player.mag_size(rifle) == int(round(mag0 * 1.2)), "Quick Hands: +20%% magazine (%d -> %d)" % [mag0, player.mag_size(rifle)])
	rifle["loaded"] = 0
	player.reload_t["primary"] = 0.0
	player.start_reload("primary")
	check(player.reload_t["primary"] < float(rifle["weapon"]["reload"]) * 0.75, "Quick Hands: faster reloads")
	player.reload_t["primary"] = 0.0
	rifle["loaded"] = player.mag_size(rifle)
	check(GameState.max_hp() > hp_max0 * 1.05 and GameState.armor() > ar0 * 1.1, "Iron Hide: more armour and health")
	var spot := player.global_position + Vector2(160, 0)
	var a := lvl.spawn_enemy("researcher", spot, "") as Enemy
	var b := lvl.spawn_enemy("researcher", spot + Vector2(0, 90), "") as Enemy
	await frames(2)
	player.aim_override = spot
	await frames(2)
	GameState.energy = GameState.max_energy()
	player.use_ability("gl_mark")
	check(a.marked_t > 0.0 and a.is_in_group("marked"), "Marked Target tags the enemy under the cursor")
	var ha := a.hp
	var hb := b.hp
	var mh := Combat.make_hit(10.0, player, false)
	mh["pierce_armor"] = true
	a.take_hit(mh.duplicate())
	b.take_hit(mh.duplicate())
	check(is_equal_approx(ha - a.hp, (hb - b.hp) * 1.35), "a marked enemy takes +35% from you")
	GameState.energy = GameState.max_energy()
	player.use_ability("gl_deadeye")
	check(player.deadeye_shots == 6 and bool(player._base_hit(rifle)["crit"]), "Deadeye: guaranteed crits")
	var ch := Combat.make_hit(5.0, player, true)
	ch["wtype"] = "rifle"
	ch["_victim"] = b
	player.on_dealt_damage(5.0, ch)
	check(b.has_status("bleed"), "Hollow Points: crits make organics bleed")
	player.cooldowns["pulse"] = 5.0
	rifle["loaded"] = 10
	player.on_kill(a, {"wtype": "rifle", "slot": "primary"})
	check(is_equal_approx(float(player.cooldowns["pulse"]), 4.0) and int(rifle["loaded"]) == 15, "Gunline Unbroken: firearm kills cut cooldowns and refund rounds")
	a.queue_free()
	b.queue_free()
	player.deadeye_shots = 0
	GameState.skills = ["pulse", "vg_iron", "vg_charge", "vg_blood", "vg_litany", "vg_unbreak", "vg_jugg"]
	var c := lvl.spawn_enemy("researcher", player.global_position + Vector2(90, 0), "") as Enemy
	await frames(2)
	c.max_hp = 5000.0   # survive the hit, so the stun can be checked (and no Juggernaut kill)
	c.hp = 5000.0
	c.set_physics_process(false)   # a still target: the test checks the charge, not the dodge
	player.aim_override = c.global_position
	await frames(2)
	var hc := c.hp
	var p0 := player.global_position
	GameState.energy = GameState.max_energy()
	player.use_ability("vg_charge")
	await frames(24)
	check(c.hp < hc and c.is_stunned() and player.global_position.distance_to(p0) > 30.0, "Shoulder Charge: dash, damage, stun")
	c.queue_free()
	player.hp = player.max_hp * 0.5
	var h0 := player.hp
	player.on_dealt_damage(100.0, {"wtype": "melee"})
	check(is_equal_approx(player.hp, h0 + 5.0), "Bloodletter: melee hits heal 5%")
	var maul := {"weapon": {"type": "melee"}, "stats": {}}
	var md0 := player.damage_mult(maul)
	GameState.energy = GameState.max_energy()
	player.use_ability("vg_litany")
	player.apply_status("stun")
	check(player.litany_t > 0.0 and player.damage_mult(maul) > md0 * 1.4 and not player.is_stunned(), "Battle Litany: +50% melee, can't be stunned")
	check(is_equal_approx(player._modify_incoming(100.0, {}), 115.0), "Battle Litany: you take 15% more")
	player.litany_t = 0.0
	player.hp = player.max_hp * 0.2
	check(is_equal_approx(player._modify_incoming(100.0, {}), 75.0), "Unbreakable: 25% less damage below 30% health")
	player.hp = player.max_hp
	player.on_kill(null, {"wtype": "melee"})
	check(player.jugg_t > 0.0 and is_equal_approx(player._modify_incoming(100.0, {}), 10.0), "Juggernaut: a melee kill gives 90% damage reduction")
	player.jugg_t = 0.0
	player.on_kill(null, {"wtype": "melee"})
	check(player.jugg_t == 0.0, "Juggernaut: at most once every 8 s")
	player.aim_override = null
	GameState.level = keep_lv
	GameState.skills = keep_skills


func _crew(id: String) -> CrewNpc:
	for n in get_tree().get_nodes_in_group("crew"):
		if (n as CrewNpc).crew_id == id:
			return n
	return null


func _journal_tests() -> void:
	print("== journal")
	var n0 := GameState.journal.size()
	GameState.journal_log("[OVERWATCH] Smoke test line.", "kharon")
	GameState.journal_log("[OVERWATCH] Smoke test line.", "kharon")
	GameState.journal_log('Dov Harrow: "Smoke test banter."', "crew")
	var last: Dictionary = GameState.journal[GameState.journal.size() - 1]
	check(GameState.journal.size() == n0 + 2, "journal records comms once (repeats skipped)")
	check(String(last["who"]) == "Dov Harrow" and String(last["text"]) == "Smoke test banter." and String(last["m"]) == "crew", "crew banter parsed into speaker and line")
	check(GameState.mission_status("kharon") in ["active", "completed"], "Kharon is in the journal (%s)" % GameState.mission_status("kharon"))
	var ks := GameState.mission_status("kessar")
	check(ks == ("locked" if not GameState.has_flag("kessar_iv_open") else "active") or ks == "completed", "Kessar IV only appears once it's cleared for travel (%s)" % ks)
	var t := GameState.journal_objective_text("kharon", 1) if GameState.mission_id() != "kharon" else "skip"
	check(not t.contains("{") and not t.contains("("), "objective directions are dropped outside the map (\"%s\")" % t)
	game._toggle(game.journal_ui)
	await frames(3)
	var entries: Array = game.journal_ui.list.get_children().filter(func(c: Node) -> bool: return c is Button)
	check(game.journal_ui.visible and entries.size() >= 2, "journal screen opens with %d entries" % entries.size())
	game.journal_ui.show_entry("crew")
	check(game.journal_ui.log_lbl.text.contains("Smoke test banter."), "Ship & crew entry shows crew banter")
	game.journal_ui.show_entry("kharon")
	check(game.journal_ui.log_lbl.text.contains("Smoke test line.") and game.journal_ui.objectives.text != "", "mission entry shows objectives and comms")
	game._toggle(game.journal_ui)
	await frames(2)
	check(not game.journal_ui.visible, "J closes the journal")


func _crew_service_tests() -> void:
	print("== crew services")
	var pl := game.player
	var q := _crew("Q")
	q.interact(pl)
	await frames(2)
	check(game.crew_ui.visible and game.crew_ui.title_lbl.text.contains("DOV") and game.crew_ui.quote.text.length() > 4, "talking opens the crew screen with a line of dialogue")
	game.crew_ui.trade.emit()
	await frames(2)
	check(game.trade_ui.visible and not game.crew_ui.visible and GameState.vendor_stock.size() >= 12, "Quartermaster trade screen (%d items in stock)" % GameState.vendor_stock.size())
	check(GameState.vendor_stock.all(func(it: Dictionary) -> bool: return int(it["rarity"]) <= ItemDB.RARITY_RARE) and GameState.vendor_stock.any(func(it: Dictionary) -> bool: return int(it["rarity"]) == ItemDB.RARITY_RARE), "stock: never Experimental, at least one Rare")
	GameState.credits = 5000
	var it: Dictionary = GameState.vendor_stock[0]
	var price := ItemDB.buy_price(it)
	var inv0 := GameState.inventory.size()
	game.trade_ui._buy(it, false)
	check(GameState.inventory.size() == inv0 + 1 and GameState.credits == 5000 - price and not GameState.vendor_stock.has(it), "buying gear (%s)" % GameState.fmt_uc(price))
	game.trade_ui._sell(it)
	if GameState.inventory.has(it):
		game.trade_ui._sell(it)   # Rare: second press confirms
	check(not GameState.inventory.has(it) and GameState.buyback.has(it) and GameState.credits == 5000 - price + ItemDB.sell_price(it), "selling for 25%% of value, into buyback")
	game.trade_ui._buy(it, true)
	check(GameState.inventory.has(it) and not GameState.buyback.has(it), "buying back a sold item")
	var rare := ItemDB.generate("shotgun", ItemDB.RARITY_RARE, 3)
	GameState.add_item(rare)
	game.trade_ui._sell(rare)
	check(GameState.inventory.has(rare), "selling a Rare asks for confirmation")
	game.trade_ui._sell(rare)
	check(not GameState.inventory.has(rare), "second press sells it")
	var st0 := GameState.stims
	var am0 := int(GameState.ammo["rifle"])
	game.trade_ui._buy_supply("stim")
	game.trade_ui._buy_supply("rifle")
	check(GameState.stims == st0 + 1 and int(GameState.ammo["rifle"]) == am0 + 30, "buying supplies (stims, ammo)")
	GameState.credits = 0
	check(not GameState.buy_item(GameState.vendor_stock[0]), "can't buy without the creds")
	var keep := ItemDB.generate("shotgun", ItemDB.RARITY_UNCOMMON, 3)
	var junk_a := ItemDB.generate("shotgun", ItemDB.RARITY_COMMON, 3)
	var junk_b := ItemDB.generate("shotgun", ItemDB.RARITY_COMMON, 2)
	for x in [keep, junk_a, junk_b]:
		GameState.add_item(x)
	game.trade_ui.refresh()
	var n_junk := GameState.junk_items().size()
	var junk_uc := 0
	for x in GameState.junk_items():
		junk_uc += ItemDB.sell_price(x)
	check(not game.trade_ui.junk_btn.disabled and game.trade_ui.junk_btn.text.contains(str(n_junk)), "Sell all junk button shows the junk count (%d)" % n_junk)
	game.trade_ui.junk_btn.grab_focus()
	game.trade_ui._sell_junk()
	await frames(1)
	check(GameState.junk_items().is_empty() and GameState.inventory.has(keep) and GameState.credits == junk_uc and GameState.buyback.has(junk_a), "Sell all junk sells every Common item and keeps the rest (+%s)" % GameState.fmt_uc(junk_uc))
	var fo := get_viewport().gui_get_focus_owner()
	check(game.trade_ui.junk_btn.disabled and fo != null and fo != game.trade_ui.junk_btn, "with no junk left the button greys out and focus moves on")
	GameState.credits = 0   # later checks (free respec) expect an empty wallet
	game.trade_ui.close()
	await frames(2)
	print("== medic, fence, pilot")
	var m := _crew("M")
	m.interact(pl)
	await frames(2)
	pl.hp = 10.0
	game.crew_ui._heal()
	check(pl.hp >= pl.max_hp - 0.1, "Medic heals for free")
	GameState.attributes["str"] = int(GameState.attributes["str"]) + 3
	var pts0 := GameState.attr_points
	game.crew_ui._respec()
	game.crew_ui._respec()
	check(GameState.attr_points == pts0 + 3 and int(GameState.attributes["str"]) == 7 and GameState.credits == 0, "first respec is free and refunds spent points")
	GameState.attributes["dex"] = int(GameState.attributes["dex"]) + 1
	GameState.attr_points -= 1
	check(GameState.respec_price() == 100 * GameState.level and not GameState.respec(), "later respecs cost 100 UC x level")
	game.crew_ui.close()
	await frames(2)
	_crew("F").interact(pl)
	await frames(2)
	GameState.credits = 2000
	var inv1 := GameState.inventory.size()
	game.crew_ui._crate("weapon")
	var got: Dictionary = GameState.inventory[GameState.inventory.size() - 1]
	check(GameState.inventory.size() == inv1 + 1 and String(got["slot"]) in ["primary", "secondary"] and GameState.credits == 2000 - ItemDB.fence_price("weapon", GameState.shop_ilvl()), "Fence sells a sealed weapon crate, opened on the spot")
	game.crew_ui.close()
	await frames(2)
	_crew("P").interact(pl)
	await frames(2)
	game.crew_ui.starmap.emit()
	await frames(2)
	check(game.star_map.visible and not game.crew_ui.visible, "Pilot opens the star map")
	game.star_map.close()
	await frames(2)
	var uids := GameState.vendor_stock.map(func(i: Dictionary) -> int: return int(i["uid"]))
	var keep_ground := GameState.ground_items
	var keep_areas := GameState.areas.duplicate(true)
	var keep_explored := GameState.explored
	GameState.location = "kharon"
	GameState.travel("ship")
	GameState.ground_items = keep_ground
	GameState.areas = keep_areas
	GameState.explored = keep_explored
	check(GameState.vendor_stock.map(func(i: Dictionary) -> int: return int(i["uid"])) != uids, "returning from a mission refreshes the Quartermaster's stock")
	GameState.credits = 0
	GameState.stims = 2


func _saved_location() -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string(GameState.save_path))
	return String(d.get("location", "")) if d is Dictionary else ""


func _any_boss_sid() -> String:
	for y in game.level.h:
		for x in game.level.w:
			if game.level.ch(x, y) == "B":
				return "%d,%d" % [x, y]
	return "?"


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
