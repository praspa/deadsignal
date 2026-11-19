class_name InventoryUI
extends Screen
## Inventory + equipment screen with loot inspection and comparison.
## Navigate with mouse, keyboard arrows or the d-pad / stick.
##   Accept / click  : equip (from bag) or unequip (from equipment slot)
##   Reload key       : drop the selected bag item

var level: Level
var player: Player
var equip_box: VBoxContainer
var grid: GridContainer
var inspect: RichTextLabel
var compare: RichTextLabel
var equip_btn: Button
var equip2_btn: Button
var drop_btn: Button
var info: Label
var selected: Dictionary = {}
var selected_slot := ""   # non-empty when an equipment slot is selected
var _rebuilding := false

const SLOT_NAMES := {"primary": "Primary", "secondary": "Secondary", "head": "Head", "body": "Body", "gloves": "Gloves", "boots": "Boots", "utility": "Utility"}


func _ready() -> void:
	make_panel(Vector2(1160, 660))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var title := UiTheme.title_label("INVENTORY & EQUIPMENT", 24)
	root.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# equipment column
	var eq_col := VBoxContainer.new()
	eq_col.custom_minimum_size = Vector2(300, 0)
	eq_col.add_child(UiTheme.title_label("Equipped", 16, UiTheme.TEXT_DIM))
	equip_box = VBoxContainer.new()
	equip_box.add_theme_constant_override("separation", 4)
	eq_col.add_child(equip_box)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	eq_col.add_child(info)
	cols.add_child(eq_col)

	# bag grid
	var bag_col := VBoxContainer.new()
	bag_col.custom_minimum_size = Vector2(430, 0)
	bag_col.add_child(UiTheme.title_label("Pack (%d slots)" % GameState.MAX_INVENTORY, 16, UiTheme.TEXT_DIM))
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	bag_col.add_child(grid)
	cols.add_child(bag_col)

	# inspection
	var ins_col := VBoxContainer.new()
	ins_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ins_col.add_child(UiTheme.title_label("Inspection", 16, UiTheme.TEXT_DIM))
	inspect = RichTextLabel.new()
	inspect.bbcode_enabled = true
	inspect.fit_content = true
	inspect.custom_minimum_size = Vector2(340, 230)
	inspect.add_theme_font_size_override("normal_font_size", 14)
	inspect.add_theme_font_size_override("bold_font_size", 16)
	ins_col.add_child(inspect)
	ins_col.add_child(HSeparator.new())
	ins_col.add_child(UiTheme.title_label("Compared to equipped", 13, UiTheme.TEXT_DIM))
	compare = RichTextLabel.new()
	compare.bbcode_enabled = true
	compare.fit_content = true
	compare.custom_minimum_size = Vector2(340, 120)
	compare.add_theme_font_size_override("normal_font_size", 14)
	ins_col.add_child(compare)
	var btns := HBoxContainer.new()
	equip_btn = UiTheme.button("Equip", _on_equip_pressed)
	equip2_btn = UiTheme.button("Equip as Secondary", _on_equip_secondary)
	drop_btn = UiTheme.button("Drop", _on_drop)
	for b in [equip_btn, equip2_btn, drop_btn]:
		b.focus_mode = Control.FOCUS_CLICK
		btns.add_child(b)
	ins_col.add_child(btns)
	cols.add_child(ins_col)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	hint.text = "Click / Enter / A (PS Cross): equip or unequip    R / X (Square): drop    Right-click: equip as secondary    I / Esc / B (Circle): close"
	root.add_child(hint)
	Events.inventory_changed.connect(_on_inv_changed)


func _on_inv_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_rebuilding = true
	var had_focus := get_viewport().gui_get_focus_owner()
	var focus_idx := -1
	var focus_in_equip := false
	if had_focus != null:
		if had_focus.get_parent() == grid:
			focus_idx = had_focus.get_index()
		elif had_focus.get_parent() == equip_box:
			focus_idx = had_focus.get_index()
			focus_in_equip = true
	for c in equip_box.get_children():
		equip_box.remove_child(c)
		c.queue_free()
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for s in GameState.SLOTS:
		var it: Dictionary = GameState.equipment.get(s, {})
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(300, 40)
		b.clip_text = true
		b.text = "%s:  %s" % [SLOT_NAMES[s], "—" if it.is_empty() else String(it["name"])]
		if not it.is_empty():
			b.add_theme_color_override("font_color", ItemDB.rarity_color(int(it["rarity"])))
		b.focus_entered.connect(_select_slot.bind(s))
		b.mouse_entered.connect(_select_slot.bind(s))
		b.pressed.connect(_on_slot_pressed.bind(s))
		equip_box.add_child(b)
	for i in GameState.MAX_INVENTORY:
		var b := Button.new()
		b.custom_minimum_size = Vector2(82, 52)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		if i < GameState.inventory.size():
			var it: Dictionary = GameState.inventory[i]
			b.text = _short(it)
			b.tooltip_text = String(it["name"])
			b.add_theme_color_override("font_color", ItemDB.rarity_color(int(it["rarity"])))
			b.focus_entered.connect(_select_item.bind(i))
			b.mouse_entered.connect(_select_item.bind(i))
			b.pressed.connect(_on_item_pressed.bind(i))
			b.gui_input.connect(_on_item_gui_input.bind(i))
		else:
			b.text = ""
			b.focus_entered.connect(_select_none)
		grid.add_child(b)
	info.text = "Armor %d   Crit %d%%   Evasion %d%%\nAmmo: %d rifle  /  %d shells   Stims: %d\nCreds: %s" % [
		roundi(GameState.armor()), roundi(GameState.crit_chance() * 100.0), roundi(GameState.evasion() * 100.0),
		int(GameState.ammo.get("rifle", 0)), int(GameState.ammo.get("shell", 0)), GameState.stims,
		GameState.fmt_uc(GameState.credits)]
	_rebuilding = false
	if focus_idx >= 0:
		var parent: Container = equip_box if focus_in_equip else grid
		var idx := mini(focus_idx, parent.get_child_count() - 1)
		if idx >= 0:
			(parent.get_child(idx) as Control).grab_focus()
	else:
		_update_inspect()


func _short(it: Dictionary) -> String:
	var lbl := ItemDB.slot_label(it)
	var words := lbl.split(" ")
	var s := words[words.size() - 1]
	return "%s\n%s" % [s, ["Common", "Uncomm.", "Rare", "Exper."][clampi(int(it["rarity"]), 0, 3)]]


func _select_item(i: int) -> void:
	if _rebuilding or i >= GameState.inventory.size():
		return
	selected = GameState.inventory[i]
	selected_slot = ""
	_update_inspect()


func _select_slot(s: String) -> void:
	if _rebuilding:
		return
	selected = GameState.equipment.get(s, {})
	selected_slot = s
	_update_inspect()


func _select_none() -> void:
	if _rebuilding:
		return
	selected = {}
	selected_slot = ""
	_update_inspect()


func _update_inspect() -> void:
	if selected.is_empty():
		inspect.text = "[color=#777]Select an item to inspect it.[/color]" if selected_slot == "" else "[color=#777]Nothing equipped in this slot.[/color]"
		compare.text = ""
		equip_btn.disabled = true
		equip2_btn.visible = false
		drop_btn.disabled = true
		return
	inspect.text = ItemDB.describe(selected)
	if selected_slot != "":
		compare.text = "[color=#999]Currently equipped.[/color]"
		equip_btn.text = "Unequip"
		equip_btn.disabled = false
		equip2_btn.visible = false
		drop_btn.disabled = true
	else:
		var slot := GameState.best_slot_for(selected)
		compare.text = ItemDB.compare(selected, GameState.equipment.get(slot, {}))
		equip_btn.text = "Equip (%s)" % SLOT_NAMES.get(slot, slot)
		equip_btn.disabled = false
		equip2_btn.visible = "secondary" in selected.get("slots", []) and slot != "secondary"
		drop_btn.disabled = false


func _on_item_pressed(i: int) -> void:
	if i < GameState.inventory.size():
		GameState.equip(GameState.inventory[i])


func _on_item_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if i < GameState.inventory.size():
			var it: Dictionary = GameState.inventory[i]
			if "secondary" in it.get("slots", []):
				GameState.equip(it, "secondary")


func _on_slot_pressed(s: String) -> void:
	GameState.unequip(s)


func _on_equip_pressed() -> void:
	if selected.is_empty():
		return
	if selected_slot != "":
		GameState.unequip(selected_slot)
	else:
		GameState.equip(selected)
	selected = {}
	refresh()


func _on_equip_secondary() -> void:
	if not selected.is_empty() and selected_slot == "":
		GameState.equip(selected, "secondary")
		selected = {}
		refresh()


func _on_drop() -> void:
	if selected.is_empty() or selected_slot != "":
		return
	var it := selected
	GameState.remove_item(it)
	if level != null and player != null:
		level.drop_item(level.scatter(player.global_position), {"kind": "item", "item": it})
	Events.msg("Dropped " + String(it["name"]), UiTheme.TEXT_DIM)
	selected = {}
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("reload"):
		var f := get_viewport().gui_get_focus_owner()
		if f != null and f.get_parent() == grid:
			_on_drop()
		get_viewport().set_input_as_handled()
