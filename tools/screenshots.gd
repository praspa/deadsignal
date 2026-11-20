extends Node
## Captures one gameplay screenshot per run for visual review (needs a display).
##   godot --path . -- --shots <output_dir> <scene>
## scenes: menu creation races ship revive nav starmap_fly ship_overview landing atrium generator powered labs xenolab boss inventory character terminal cutaway loot [aim: down|up|left|right] overview
## add --variant N to pick a layout

var main: Node
var out_dir := "user://shots"
var scene := "landing"


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	main = get_parent()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
	if i >= 0 and i + 2 < args.size():
		scene = args[i + 2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
	GameState.save_path = "user://shots_save.json"
	await frames(3)
	if scene == "menu":
		await frames(30)
		await _shot()
		get_tree().quit()
		return
	if scene == "races":
		await _races_lineup()
		get_tree().quit()
		return
	if scene == "creation":
		main.call("show_character_creation")
		await frames(30)
		await _shot()
		get_tree().quit()
		return
	GameState.new_game()
	if scene == "revive":
		GameState.credits = 420
		GameState.apply_death()
	if scene in ["kessar", "camp", "recall", "kessar_overview"]:
		GameState.location = "kessar_surface"
	elif scene in ["hive", "queen", "hive_overview"]:
		GameState.location = "kessar_hive"
	elif not scene in ["ship", "nav", "starmap_fly", "ship_overview", "revive", "crew_q", "crew_t", "crew_m", "crew_f", "crew_p", "crew_screen", "trade", "landing"]:
		GameState.location = "kharon"
	main.call("start_game")
	await frames(3)
	var game: Game = main.get("current")
	var p := game.player
	var lvl := game.level
	match scene:
		"revive":
			await frames(150)
		"landing":
			GameState.set_flag("beacon:kessar_hive")
			GameState.ship_node = "kessar_iv"
			Events.open_nav.emit()
			await frames(10)
			game.star_map._select("kessar_iv")
			game.star_map._descend()
			await frames(20)
		"crew_q", "crew_t", "crew_m", "crew_f", "crew_p":
			var cid := scene.substr(5, 1).to_upper()
			for n in get_tree().get_nodes_in_group("crew"):
				if (n as CrewNpc).crew_id == cid:
					p.global_position = (n as Node2D).global_position + Vector2(70, -70)
					game.camera.set_process(false)
					game.set_process(false)
					game.camera.position_smoothing_enabled = false
					game.camera.global_position = Iso.sp((n as Node2D).global_position, 24)
					game.hud.visible = false
			game.camera.zoom = Vector2(3.2, 3.2)
			await frames(80)
		"crew_screen":
			Events.open_crew.emit("M")
			await frames(30)
		"trade":
			GameState.credits = 640
			Events.open_crew.emit("Q")
			await frames(10)
			for b in ["shotgun", "flak_carapace", "auspex"]:
				GameState.add_item(ItemDB.generate(b, ItemDB.RARITY_COMMON, 2))
			GameState.add_item(ItemDB.generate("energy_pistol", ItemDB.RARITY_UNCOMMON, 2))
			game.crew_ui.trade.emit()
			await frames(10)
			game.trade_ui.junk_btn.grab_focus()
			await frames(20)
		"kessar":
			await frames(60)
		"camp":
			p.global_position = lvl.room_center("camp") + Vector2(0, 60)
			await frames(60)
		"recall":
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
			await frames(20)
			p.start_recall()
			await frames(70)
		"hive":
			await frames(60)
		"queen":
			var q := get_tree().get_first_node_in_group("boss") as BroodQueen
			p.global_position = q.global_position + Vector2(40, 190)
			q.take_hit(Combat.make_hit(10, p))
			for k in 150:
				p.hp = p.max_hp
				await frames(1)
				if q.act == "spray_tele" and q.act_t < 0.4:
					break
		"ship":
			p.global_position = lvl.room_center("common") + Vector2(40, 0)
			await frames(60)
		"nav":
			p.global_position = lvl.room_center("cockpit") + Vector2(-40, 30)
			await frames(30)
			Events.open_nav.emit()
			await frames(20)
		"starmap_fly":
			p.global_position = lvl.room_center("cockpit") + Vector2(-40, 30)
			await frames(30)
			Events.open_nav.emit()
			await frames(10)
			game.star_map._select("kharon")
			game.star_map.activate("kharon")
			await frames(90)
		"landing":
			await frames(40)
		"atrium":
			p.global_position = lvl.room_center("atrium") + Vector2(0, 80)
			await frames(45)
			p.aim_override = lvl.room_center("atrium") + Vector2(0, -150)
			for k in 12:
				p.hp = p.max_hp
				p.fire("primary")
				await frames(1)
		"generator", "powered":
			if scene == "powered":
				GameState.set_flag("power")
			p.global_position = lvl.room_center("generator")
			for k in 50:
				p.hp = p.max_hp
				await frames(1)
			p.aim_override = lvl.room_center("generator") + Vector2(0, -180)
			for k in 8:
				p.fire("primary")
				await frames(1)
		"labs":
			GameState.set_flag("power")
			p.global_position = lvl.room_center("labs")
			for k in 70:
				p.hp = p.max_hp
				await frames(1)
		"xenolab":
			GameState.set_flag("power")
			p.global_position = lvl.room_center("xenolab")
			for k in 60:
				p.hp = p.max_hp
				await frames(1)
		"boss":
			GameState.set_flag("power")
			var boss := get_tree().get_first_node_in_group("boss") as Boss
			p.global_position = boss.global_position + Vector2(0, 230)
			for k in 170:
				p.hp = p.max_hp
				await frames(1)
				if boss.pattern != "" and boss.pat_t > 1.3:
					break
		"inventory", "character":
			GameState.add_item(ItemDB.generate("energy_pistol", 3, 3))
			GameState.add_item(ItemDB.generate("plate_cuirass", 2, 2))
			GameState.add_item(ItemDB.generate("auspex", 1, 1))
			GameState.add_xp(300)
			await frames(5)
			game._toggle(game.inventory_ui if scene == "inventory" else game.character_ui)
			await frames(8)
			if scene == "inventory":
				(game.inventory_ui.grid.get_child(1) as Control).grab_focus()
				await frames(3)
		"perf":
			# uncapped render timing in the busiest room (prints, no screenshot)
			Engine.max_fps = 60 if "--cap" in OS.get_cmdline_user_args() else 0
			GameState.set_flag("power")
			p.global_position = lvl.room_center("labs")
			var a := OS.get_cmdline_user_args()
			if "--nowalls" in a:
				for wt in lvl.walls.values():
					wt.visible = false
			if "--nofloor" in a:
				lvl.floor_layer.visible = false
			if "--nolights" in a:
				for l in get_tree().root.find_children("*", "PointLight2D", true, false):
					l.enabled = false
			if "--noactors" in a:
				for e in get_tree().get_nodes_in_group("enemies"):
					e.process_mode = Node.PROCESS_MODE_DISABLED
					e.visible = false
			if "--noshadow" in a:
				for l in get_tree().root.find_children("*", "PointLight2D", true, false):
					l.shadow_enabled = false
			if "--nopost" in a:
				var pg := get_tree().root.find_child("PostGrade", true, false) as CanvasItem
				if pg != null:
					pg.visible = false
			await frames(30)
			while lvl.baker.pending() > 0:   # measure after floor / wall baking
				await frames(5)
			await frames(10)
			var t0 := Time.get_ticks_usec()
			var worst := 0
			var slow := 0
			var last := t0
			for k in 300:
				p.hp = p.max_hp
				await frames(1)
				var now := Time.get_ticks_usec()
				worst = maxi(worst, now - last)
				if now - last > (20000 if Engine.max_fps > 0 else 16667):
					slow += 1
					print("  slow frame %.1f ms: process %.1f physics %.1f fx %d views %d" % [(now - last) / 1000.0,
						Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
						Iso.fx_root.get_child_count(), Iso.view_root.get_child_count()])
				last = now
			var avg := float(Time.get_ticks_usec() - t0) / 300.0 / 1000.0
			print("PERF avg %.2f ms (%.0f fps), worst %.2f ms, %d/300 frames over %.1f ms, views %d" % [avg, 1000.0 / avg, worst / 1000.0, slow, 20.0 if Engine.max_fps > 0 else 16.7, Iso.view_root.get_child_count()])
			get_tree().quit()
			return
		"loot":
			# every item type on the floor around the player (zoomed in)
			GameState.set_flag("power")
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
			p.global_position = lvl.room_center("labs")
			var bases := ItemDB.bases.keys()
			for k in bases.size():
				var ang := TAU * float(k) / float(bases.size())
				var it := ItemDB.generate(bases[k], k % 4, 1)
				lvl.drop_item(p.global_position + Vector2.from_angle(ang) * (85.0 + 45.0 * (k % 2)), {"kind": "item", "item": it})
			var aim := {"down": Vector2(1, 1), "up": Vector2(-1, -1), "left": Vector2(-1, 1), "right": Vector2(1, -1)}
			var which := args[i + 3] if args.size() > i + 3 else "down"
			p.aim_override = p.global_position + (aim.get(which, Vector2(1, 1)) as Vector2) * 60.0
			game.camera.zoom = Vector2(2.2, 2.2)
			if args.has("--closeup"):
				for d in get_tree().get_nodes_in_group("loot"):
					d.queue_free()
				game.camera.zoom = Vector2(6, 6)
				game.hud.visible = false
				which += "_closeup"
			scene = "loot_" + which
			await frames(40)
			if args.has("--closeup"):
				game.camera.global_position = Iso.sp(p.global_position, 28)
				game.camera.reset_smoothing()
				game.set_process(false)
				await frames(3)
		"overview", "ship_overview", "kessar_overview", "hive_overview":
			# whole layout, fully lit and zoomed out (compare the variants)
			for e in get_tree().get_nodes_in_group("enemies"):
				e.visible = false
			p.visible = false
			lvl.canvas_mod.color = Color(1.4, 1.35, 1.3)
			var pg := get_tree().root.find_child("PostGrade", true, false) as CanvasItem
			if pg != null:
				pg.visible = false
			game.hud.visible = false
			var corners := [Iso.to_screen(Vector2.ZERO), Iso.to_screen(Vector2(lvl.w * Level.T, 0)),
				Iso.to_screen(Vector2(0, lvl.h * Level.T)), Iso.to_screen(Vector2(lvl.w * Level.T, lvl.h * Level.T))]
			var bb := Rect2(corners[0], Vector2.ZERO)
			for c in corners:
				bb = bb.expand(c)
			game.set_process(false)
			game.camera.position_smoothing_enabled = false
			game.camera.global_position = bb.get_center()
			var z := minf(1280.0 / bb.size.x, 800.0 / bb.size.y) * 0.98
			game.camera.zoom = Vector2(z, z)
			Iso.cull_rect = Rect2()
			await frames(10)
			while lvl.baker.pending() > 0:
				await frames(5)
			await frames(10)
			if scene == "overview":
				scene = "overview_%d" % GameState.map_variant
		"cutaway":
			# stand right behind (north of) a front wall to show the cutaway fade
			GameState.set_flag("power")
			var c := lvl.world_to_cell(lvl.room_center("atrium"))
			var y := c.y
			while not lvl.is_wall(c.x, y + 1):
				y += 1
			p.global_position = lvl.tile_center(c.x, y)
			p.aim_override = lvl.tile_center(c.x + 5, y + 3)
			await frames(60)
		"terminal":
			Events.open_terminal.emit("4", null)
			await frames(150)
	await _shot()
	get_tree().quit()


func _shot() -> void:
	await frames(1)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(scene + ".png"))
	print("saved ", scene)


## Every race in the operative's armour, facing the camera, side-on and from
## behind, using the real Player art.
func _races_lineup() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.085, 0.09)
	bg.size = Vector2(1280, 800)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(bg)
	add_child(layer)
	var puppets: Array = []
	var dirs := [Vector2(0.4, 1.0), Vector2(1.0, -0.15), Vector2(-0.3, -1.0)]
	for i in GameState.RACES.size():
		var label := Label.new()
		label.text = String(GameState.RACES[i]["name"])
		label.position = Vector2(30 + i * 208, 20)
		label.add_theme_font_size_override("font_size", 20)
		bg.add_child(label)
		for k in dirs.size():
			var p := Player.new()
			p.race = String(GameState.RACES[i]["id"])
			p.aim_dir = (dirs[k] as Vector2).normalized()
			var v := IsoView.new()
			v.target = p
			v.position = Vector2(100 + i * 208, 250 + k * 250)
			v.scale = Vector2(2.6, 2.6)
			p.cv = v
			bg.add_child(v)
			v.set_process(false)   # after add_child, or entering the tree re-enables it
			puppets.append(p)
	await frames(10)
	await _shot()
	layer.queue_free()
	await frames(1)
	for p in puppets:
		(p as Node).free()
