class_name Game
extends Node2D
## One play session: builds the level, spawns the player, owns the camera,
## HUD and menu screens, and runs mission logic (objectives, comms, saving).

signal request(id: String)

var level: Level
var world: Node2D
var player: Player
var camera: Camera2D
var hud: Hud
var minimap: Minimap
var ui_layer: CanvasLayer
var inventory_ui: InventoryUI
var character_ui: CharacterUI
var terminal_ui: TerminalUI
var pause_menu: PauseMenu
var end_screen: EndScreen
var open_screen: Screen = null
var dust: CPUParticles2D
var views: Node2D

var shake := 0.0
var death_timer := -1.0
var victory_timer := -1.0
var last_obj := -1
var comms: Array = []   # [text, delay]
var comms_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.music("level")
	level = Level.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	# simulation nodes live in `world` (square grid, never drawn directly);
	# their IsoViews live in the y-sorted view root (isometric screen space)
	world = Node2D.new()
	world.name = "World"
	level.add_child(world)
	views = Node2D.new()
	views.name = "Views"
	views.y_sort_enabled = true
	level.add_child(views)
	var fx := Node2D.new()
	fx.name = "Fx"
	fx.z_index = 50
	level.add_child(fx)
	# loot names: own canvas layer that follows the camera, so the level's
	# darkness / lighting never dims them (they stay readable, like Diablo II)
	var label_layer := CanvasLayer.new()
	label_layer.layer = 3
	label_layer.follow_viewport_enabled = true
	label_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.add_child(label_layer)
	var labels := LootLabels.new()
	labels.name = "LootLabels"
	label_layer.add_child(labels)
	Iso.view_root = views
	Iso.fx_root = fx
	level.build(world)

	player = Player.new()
	if GameState.loaded_from_save and GameState.player_pos != null:
		player.position = GameState.player_pos
	else:
		player.position = level.player_start
	world.add_child(player)

	camera = Camera2D.new()
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.zoom = Vector2(1.35, 1.35)
	camera.position = Iso.sp(player.position, 20)
	add_child(camera)
	camera.make_current()
	camera.reset_smoothing()

	dust = CPUParticles2D.new()
	dust.process_mode = Node.PROCESS_MODE_PAUSABLE
	dust.amount = 70
	dust.lifetime = 7.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(520, 340)
	dust.direction = Vector2(1, -0.3)
	dust.spread = 40.0
	dust.gravity = Vector2(0, 2)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.texture = LightUtil.radial(32)
	dust.scale_amount_min = 0.06
	dust.scale_amount_max = 0.14
	dust.color = Color(0.75, 0.68, 0.6, 0.18)
	dust.z_index = 40
	add_child(dust)

	# full-screen grade: grain, colour grade, edge aberration (under labels / HUD)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 2
	add_child(post_layer)
	var post := ColorRect.new()
	post.name = "PostGrade"
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post_mat := ShaderMaterial.new()
	post_mat.shader = preload("res://shaders/post_grade.gdshader")
	post.material = post_mat
	post_layer.add_child(post)

	hud = Hud.new()
	hud.player = player
	add_child(hud)
	minimap = Minimap.new()
	minimap.setup(level, player)
	hud.add_child(minimap)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	inventory_ui = InventoryUI.new()
	inventory_ui.level = level
	inventory_ui.player = player
	character_ui = CharacterUI.new()
	terminal_ui = TerminalUI.new()
	pause_menu = PauseMenu.new()
	end_screen = EndScreen.new()
	for s in [inventory_ui, character_ui, terminal_ui, pause_menu, end_screen]:
		ui_layer.add_child(s)
		s.hide()
	inventory_ui.closed.connect(_on_screen_closed)
	character_ui.closed.connect(_on_screen_closed)
	terminal_ui.closed.connect(_on_terminal_closed)
	pause_menu.closed.connect(_on_screen_closed)
	pause_menu.action.connect(_on_pause_action)
	end_screen.action.connect(_on_end_action)

	Events.open_terminal.connect(_on_open_terminal)
	Events.player_died.connect(_on_player_died)
	Events.flag_set.connect(_on_flag_set)
	Events.screen_shake.connect(_on_shake)

	last_obj = GameState.objective_index()
	Events.msg("Kharon Outpost — %s" % String(GameState.map_info.get("name", "")), Color(0.75, 0.68, 0.5))
	if GameState.loaded_from_save:
		Events.msg("Save loaded.", UiTheme.TEXT_DIM)
	else:
		_queue_comms(last_obj)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	if Iso.view_root == views:
		Iso.view_root = null
		Iso.fx_root = null
		Iso.cull_rect = Rect2()
	# autoload signals outlive this node; disconnect to avoid stale callbacks
	for pair in [[Events.open_terminal, _on_open_terminal], [Events.player_died, _on_player_died],
			[Events.flag_set, _on_flag_set], [Events.screen_shake, _on_shake]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if not get_tree().paused:
		_update_camera(delta)
		_mission_triggers()
		_run_comms(delta)
	if death_timer > 0.0:
		death_timer -= delta
		if death_timer <= 0.0:
			_open(end_screen)
			end_screen.show_death()
	if victory_timer > 0.0:
		victory_timer -= delta
		if victory_timer <= 0.0:
			_open(end_screen)
			end_screen.show_victory()


func _update_camera(delta: float) -> void:
	var look := Iso.dir(player.aim_point - player.global_position)
	look = look.limit_length(300.0) * 0.2
	if player.dead:
		look = Vector2.ZERO
	camera.global_position = Iso.sp(player.global_position, 20) + look
	var half := get_viewport_rect().size / camera.zoom * 0.5
	Iso.cull_rect = Rect2(camera.global_position - half, half * 2.0).grow(160.0)
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	dust.global_position = camera.get_screen_center_position()


func _on_shake(amount: float) -> void:
	shake = minf(14.0, maxf(shake, amount))


func _mission_triggers() -> void:
	if player.dead:
		return
	var p := player.global_position
	# inside once off the exterior ground (past the airlock) on any layout
	if not GameState.has_flag("entered") and level.floor_style(level.world_to_cell(p).x, level.world_to_cell(p).y) != ",":
		GameState.set_flag("entered")
	if GameState.has_flag("boss") and not GameState.has_flag("escape") and level.exit_rect.has_point(p):
		GameState.set_flag("escape")
		Events.msg("[OVERWATCH] Extraction lock confirmed. Bringing you home, Operative.", Color(0.55, 0.85, 1.0))
		Events.mission_complete.emit()
		victory_timer = 1.5


func _on_flag_set(f: String) -> void:
	var idx := GameState.objective_index()
	if idx != last_obj:
		last_obj = idx
		Events.objective_changed.emit(GameState.current_objective_text())
		_queue_comms(idx)
	if f in ["power", "research", "cause", "boss"]:
		_save.call_deferred(true)
	if f == "power":
		Events.msg("Primary reactor online. Bulkheads unlocked.", Color(0.5, 1.0, 0.6))


func _queue_comms(idx: int) -> void:
	var objs: Array = ItemDB.mission.get("objectives", [])
	if idx < 0 or idx >= objs.size():
		return
	var delay := 1.2
	for line in objs[idx].get("comms", []):
		comms.append([GameState.fmt(String(line)), delay])
		delay = 3.5


func _run_comms(delta: float) -> void:
	if comms.is_empty():
		return
	comms[0][1] = float(comms[0][1]) - delta
	if float(comms[0][1]) <= 0.0:
		Events.msg(String(comms[0][0]), Color(0.55, 0.85, 1.0))
		comms.pop_front()


# ---------------------------------------------------------------- screens

func _open(s: Screen) -> void:
	if open_screen != null and open_screen != s:
		open_screen.hide()
	open_screen = s
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if s != terminal_ui and s != end_screen:
		s.open()


func _close_current() -> void:
	if open_screen != null:
		open_screen.close()


func _on_screen_closed() -> void:
	if open_screen != null and open_screen.visible:
		return
	open_screen = null
	player.input_grace = 0.2   # the button that closed the menu must not also roll / fire
	if death_timer <= 0.0 and not player.dead and victory_timer <= 0.0:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if open_screen == end_screen and end_screen.visible:
		return
	# while a menu is open the d-pad navigates it; don't treat it as gameplay
	# shortcuts (D-Left = character sheet, D-Right = inventory, ...)
	if open_screen != null and event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index in [
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		return
	if event.is_action_pressed("pause"):
		if open_screen != null:
			_close_current()
		elif not player.dead:
			_open(pause_menu)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and open_screen != null:
		_close_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not player.dead:
		_toggle(inventory_ui)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character") and not player.dead:
		_toggle(character_ui)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quicksave") and open_screen == null and not player.dead:
		_save(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quickload"):
		if GameState.has_save():
			request.emit("load")
		get_viewport().set_input_as_handled()


func _toggle(s: Screen) -> void:
	if open_screen == s:
		_close_current()
	elif open_screen == null or open_screen == inventory_ui or open_screen == character_ui or open_screen == pause_menu:
		if open_screen != null:
			open_screen.hide()
			open_screen = null
		_open(s)


func _on_open_terminal(id: String, term: Node) -> void:
	if open_screen != null:
		return
	_open(terminal_ui)
	terminal_ui.show_terminal(id, term)


func _on_terminal_closed() -> void:
	var data: Dictionary = ItemDB.terminals.get(terminal_ui.term_id, {})
	var term := terminal_ui.terminal
	_on_screen_closed()
	if term != null and is_instance_valid(term):
		var rf: String = term.call("read_flag")
		if not GameState.has_flag(rf):
			GameState.set_flag(rf)
			GameState.add_xp(int(data.get("xp", 0)))
			var tv = term.get("cv")
			if tv != null:
				(tv as CanvasItem).queue_redraw()
	var sf := String(data.get("sets_flag", ""))
	if sf != "":
		GameState.set_flag(sf)
	if String(data.get("type", "")) == "save":
		_save(false)


func _on_pause_action(id: String) -> void:
	match id:
		"resume":
			_close_current()
		"inventory":
			_toggle(inventory_ui)
		"character":
			_toggle(character_ui)
		"save":
			_save(false)
		"load":
			request.emit("load")
		"menu":
			request.emit("menu")
		"quit":
			request.emit("quit")


func _on_end_action(id: String) -> void:
	request.emit(id)


func _on_player_died() -> void:
	death_timer = 2.0
	Audio.music("", 2.5)
	_close_current()


func _save(checkpoint: bool) -> void:
	if player.dead:
		return
	if GameState.save_game(player.global_position):
		Events.msg("Checkpoint reached — progress saved." if checkpoint else "Progress saved.", Color(0.5, 0.75, 1.0))
