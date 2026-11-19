extends Node
## Root scene: switches between the main menu and the game.

var current: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--smoke" in OS.get_cmdline_user_args():
		var t: Node = load("res://tools/smoke_test.gd").new()
		add_child(t)
		return
	if "--shots" in OS.get_cmdline_user_args():
		show_menu()
		var s: Node = load("res://tools/screenshots.gd").new()
		add_child(s)
		return
	if "--steam-art" in OS.get_cmdline_user_args():
		add_child(load("res://tools/steam_art.gd").new())
		return
	show_menu()


func _clear() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
		remove_child(current)
	current = null
	get_tree().paused = false
	Audio.stop_all()


func show_menu() -> void:
	_clear()
	Audio.music("menu")
	var menu := MainMenu.new()
	menu.action.connect(_on_menu_action)
	add_child(menu)
	current = menu


func show_character_creation() -> void:
	_clear()
	var cc := CharacterCreation.new()
	cc.begin.connect(_on_creation_begin)
	cc.back.connect(func() -> void: show_menu.call_deferred())
	add_child(cc)
	current = cc


func _on_creation_begin(player_name: String, class_id: String, race_id: String) -> void:
	GameState.new_game(player_name, class_id, race_id)
	start_game.call_deferred()


func start_game() -> void:
	_clear()
	var game := Game.new()
	game.request.connect(_on_game_request)
	add_child(game)
	current = game


func _on_menu_action(id: String) -> void:
	match id:
		"new":
			show_character_creation.call_deferred()
		"continue":
			if GameState.load_game():
				start_game.call_deferred()
		"quit":
			get_tree().quit()


func _on_game_request(id: String) -> void:
	if id.begins_with("travel:"):
		GameState.travel(id.trim_prefix("travel:"))
		GameState.save_game(null)   # arrive at the destination's start point
		start_game.call_deferred()
		return
	match id:
		"menu":
			show_menu.call_deferred()
		"load":
			if GameState.load_game():
				start_game.call_deferred()
		"quit":
			get_tree().quit()
