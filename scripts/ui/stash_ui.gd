class_name StashUI
extends Screen
## Ship's cargo locker: two grids, the operative's pack and the ship's stash.
## Accept / click on an item moves it to the other side.

var pack_grid: GridContainer
var stash_grid: GridContainer
var pack_title: Label
var stash_title: Label
var inspect: RichTextLabel
var _rebuilding := false


func _ready() -> void:
	make_panel(Vector2(1160, 640))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(UiTheme.title_label("CARGO LOCKER — %s" % GameState.location_name("ship").to_upper(), 24))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var pack_col := VBoxContainer.new()
	pack_title = UiTheme.title_label("", 16, UiTheme.TEXT_DIM)
	pack_col.add_child(pack_title)
	pack_grid = _grid(5)
	pack_col.add_child(pack_grid)
	cols.add_child(pack_col)
	var stash_col := VBoxContainer.new()
	stash_title = UiTheme.title_label("", 16, UiTheme.TEXT_DIM)
	stash_col.add_child(stash_title)
	stash_grid = _grid(5)
	stash_col.add_child(stash_grid)
	cols.add_child(stash_col)
	var ins_col := VBoxContainer.new()
	ins_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ins_col.add_child(UiTheme.title_label("Inspection", 16, UiTheme.TEXT_DIM))
	inspect = RichTextLabel.new()
	inspect.bbcode_enabled = true
	inspect.fit_content = true
	inspect.custom_minimum_size = Vector2(240, 300)
	inspect.add_theme_font_size_override("normal_font_size", 14)
	inspect.add_theme_font_size_override("bold_font_size", 16)
	ins_col.add_child(inspect)
	cols.add_child(ins_col)
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	hint.text = "Click / Enter / A (PS Cross): move item between pack and locker    Esc / B (Circle): close"
	root.add_child(hint)
	Events.inventory_changed.connect(_on_inv_changed)


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	return g


func _on_inv_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_rebuilding = true
	var had := get_viewport().gui_get_focus_owner()
	var focus_grid: Control = had.get_parent() if had != null and had.get_parent() in [pack_grid, stash_grid] else null
	var focus_idx := had.get_index() if focus_grid != null else -1
	pack_title.text = "Pack (%d / %d)" % [GameState.inventory.size(), GameState.MAX_INVENTORY]
	stash_title.text = "Cargo locker (%d / %d)" % [GameState.stash.size(), GameState.MAX_STASH]
	_fill(pack_grid, GameState.inventory, GameState.MAX_INVENTORY, true)
	_fill(stash_grid, GameState.stash, GameState.MAX_STASH, false)
	_rebuilding = false
	if focus_grid != null:
		var idx := mini(focus_idx, focus_grid.get_child_count() - 1)
		if idx >= 0:
			(focus_grid.get_child(idx) as Control).grab_focus()


func _fill(g: GridContainer, items: Array, cap: int, from_pack: bool) -> void:
	for c in g.get_children():
		g.remove_child(c)
		c.queue_free()
	for i in cap:
		var b := Button.new()
		b.custom_minimum_size = Vector2(78, 46)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		if i < items.size():
			var it: Dictionary = items[i]
			b.text = _short(it)
			b.tooltip_text = String(it["name"])
			b.add_theme_color_override("font_color", ItemDB.rarity_color(int(it["rarity"])))
			b.focus_entered.connect(_inspect.bind(it))
			b.mouse_entered.connect(_inspect.bind(it))
			b.pressed.connect(_move.bind(it, from_pack))
		else:
			b.focus_entered.connect(_inspect.bind({}))
		g.add_child(b)


static func _short(it: Dictionary) -> String:
	var words := ItemDB.slot_label(it).split(" ")
	return "%s\n%s" % [words[words.size() - 1], ["Common", "Uncomm.", "Rare", "Exper."][clampi(int(it["rarity"]), 0, 3)]]


func _inspect(it: Dictionary) -> void:
	if _rebuilding:
		return
	inspect.text = "" if it.is_empty() else ItemDB.describe(it)


func _move(it: Dictionary, from_pack: bool) -> void:
	var ok := GameState.stash_item(it) if from_pack else GameState.unstash_item(it)
	if not ok:
		Events.msg("Cargo locker is full." if from_pack else "Pack is full.", Color(0.9, 0.4, 0.3))
		return
	Audio.play_ui("pickup", 0.9, -6.0)
