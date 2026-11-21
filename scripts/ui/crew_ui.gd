class_name CrewUI
extends Screen
## Talking to a crew member: name plate, a line of dialogue, and their services
## (requirements 15.2). Quartermaster -> trade screen, Medic -> heal / respec,
## Fence -> sealed crates, Pilot -> star map. Controller: d-pad, A, B to leave.

signal trade
signal starmap

var crew_id := ""
var player: Player
var title_lbl: Label
var role_lbl: Label
var quote: Label
var buttons: VBoxContainer
var result: RichTextLabel
var creds: Label
var respec_armed := false


func _ready() -> void:
	make_panel(Vector2(620, 460))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	title_lbl = UiTheme.title_label("", 24)
	root.add_child(title_lbl)
	role_lbl = UiTheme.title_label("", 14, UiTheme.TEXT_DIM)
	root.add_child(role_lbl)
	root.add_child(HSeparator.new())
	quote = Label.new()
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(580, 50)
	quote.add_theme_font_size_override("font_size", 15)
	quote.add_theme_color_override("font_color", Color(0.9, 0.84, 0.66))
	root.add_child(quote)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	root.add_child(buttons)
	result = RichTextLabel.new()
	result.bbcode_enabled = true
	result.fit_content = true
	result.custom_minimum_size = Vector2(580, 60)
	result.add_theme_font_size_override("normal_font_size", 14)
	result.add_theme_font_size_override("bold_font_size", 16)
	root.add_child(result)
	creds = Label.new()
	creds.add_theme_font_size_override("font_size", 14)
	creds.add_theme_color_override("font_color", LootDrop.CREDIT_COLOR)
	root.add_child(creds)


func show_crew(id: String, p: Player) -> void:
	crew_id = id
	player = p
	result.text = ""
	respec_armed = false
	var npc := _npc()
	quote.text = "\"%s\"" % (npc.line() if npc != null else "...")


func _npc() -> CrewNpc:
	for n in get_tree().get_nodes_in_group("crew"):
		if (n as CrewNpc).crew_id == crew_id:
			return n
	return null


func refresh() -> void:
	var d: Dictionary = ItemDB.crew.get(crew_id, {})
	title_lbl.text = String(d.get("name", "Crew")).to_upper()
	role_lbl.text = String(d.get("title", ""))
	creds.text = "Your creds: " + GameState.fmt_uc(GameState.credits)
	for c in buttons.get_children():
		buttons.remove_child(c)
		c.queue_free()
	for svc in d.get("services", []):
		match String(svc):
			"trade":
				_button("Trade (buy and sell gear, supplies)", func() -> void: trade.emit())
			"heal":
				_button("Patch me up (free)", _heal)
			"respec":
				var price := GameState.respec_price()
				var txt := ("Confirm respec — " if respec_armed else "Respec attributes & Doctrines — ") + ("free (first time)" if price == 0 else GameState.fmt_uc(price))
				_button(txt, _respec)
			"fence":
				var il := GameState.shop_ilvl()
				for cat in ItemDB.FENCE_CATEGORIES:
					var cd: Dictionary = ItemDB.FENCE_CATEGORIES[cat]
					_button("Buy a sealed %s — %s" % [String(cd["name"]).to_lower(), GameState.fmt_uc(ItemDB.fence_price(cat, il))], _crate.bind(cat))
			"starmap":
				_button("Open the star map", func() -> void: starmap.emit())
	_button("Leave", close)


func _button(text: String, cb: Callable) -> void:
	var b := UiTheme.button(text, cb)
	b.custom_minimum_size = Vector2(0, 38)
	buttons.add_child(b)


func _say(text: String, col := Color(0.85, 0.82, 0.75)) -> void:
	result.text = "[color=#%s]%s[/color]" % [col.to_html(false), text]


func _heal() -> void:
	if player != null:
		player.hp = player.max_hp
		player.statuses.clear()
	GameState.hp = GameState.max_hp()
	GameState.energy = GameState.max_energy()
	Audio.play_ui("stim")
	_say("Oskar dabs something cold on your wounds. \"There. Try not to undo my work immediately.\"", Color(0.5, 1.0, 0.6))
	Events.stats_changed.emit()


func _respec() -> void:
	if not respec_armed:
		respec_armed = true
		_say("All spent attribute and Doctrine points will be refunded, and your ability slots reset. Press again to confirm.")
		_refresh_keep_focus()
		return
	respec_armed = false
	if GameState.respec():
		if player != null:
			player.sync_from_state()
		_say("Done. %d attribute points to spend again (Character screen)." % GameState.attr_points, Color(0.5, 1.0, 0.6))
		Audio.play_ui("levelup")
	_refresh_keep_focus()


func _crate(cat: String) -> void:
	var item := GameState.buy_crate(cat)
	if item.is_empty():
		_refresh_keep_focus()
		return
	Audio.play_ui("crate")
	var r := int(item["rarity"])
	var lines := ["Junk. Probably.", "Not bad, friend!", "Oho! Told you. A fortune.", "...I should have charged more for that one."]
	_say("Kesh cracks the seal: \"%s\"\n%s" % [lines[clampi(r, 0, 3)], ItemDB.describe(item)], ItemDB.rarity_color(r))
	_refresh_keep_focus()


func _refresh_keep_focus() -> void:
	var idx := -1
	var f := get_viewport().gui_get_focus_owner()
	if f != null and f.get_parent() == buttons:
		idx = f.get_index()
	refresh()
	if idx >= 0:
		await get_tree().process_frame
		var n := buttons.get_child_count()
		if n > 0:
			(buttons.get_child(mini(idx, n - 1)) as Control).grab_focus()
