class_name TradeUI
extends Screen
## The Quartermaster's counter: vendor stock (tabs Gear / Supplies / Buyback)
## on the left, the operative's pack on the right, inspection + comparison
## with what's equipped. Accept / click buys from the left or sells from the
## right; selling Rare or better asks for a second press.

var tab := "gear"
var vendor_grid: GridContainer
var pack_grid: GridContainer
var tabs: HBoxContainer
var inspect: RichTextLabel
var compare: RichTextLabel
var creds: Label
var hint: Label
var pending_sale: Dictionary = {}
var _rebuilding := false


func _ready() -> void:
	make_panel(Vector2(1180, 660))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(UiTheme.title_label("QUARTERMASTER — DOV HARROW", 24))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	tabs = HBoxContainer.new()
	for pair in [["Gear", "gear"], ["Supplies", "supplies"], ["Buyback", "buyback"]]:
		var b := UiTheme.button(pair[0], _set_tab.bind(pair[1]))
		b.custom_minimum_size = Vector2(110, 32)
		tabs.add_child(b)
	left.add_child(tabs)
	vendor_grid = GridContainer.new()
	vendor_grid.columns = 4
	vendor_grid.add_theme_constant_override("h_separation", 4)
	vendor_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(vendor_grid)
	cols.add_child(left)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(500, 0)
	mid.add_child(UiTheme.title_label("Your pack (select to sell)", 16, UiTheme.TEXT_DIM))
	pack_grid = GridContainer.new()
	pack_grid.columns = 5
	pack_grid.add_theme_constant_override("h_separation", 4)
	pack_grid.add_theme_constant_override("v_separation", 4)
	mid.add_child(pack_grid)
	cols.add_child(mid)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UiTheme.title_label("Inspection", 16, UiTheme.TEXT_DIM))
	inspect = RichTextLabel.new()
	inspect.bbcode_enabled = true
	inspect.fit_content = true
	inspect.custom_minimum_size = Vector2(250, 230)
	inspect.add_theme_font_size_override("normal_font_size", 14)
	inspect.add_theme_font_size_override("bold_font_size", 16)
	right.add_child(inspect)
	right.add_child(UiTheme.title_label("Compared to equipped", 13, UiTheme.TEXT_DIM))
	compare = RichTextLabel.new()
	compare.bbcode_enabled = true
	compare.fit_content = true
	compare.custom_minimum_size = Vector2(250, 110)
	compare.add_theme_font_size_override("normal_font_size", 13)
	right.add_child(compare)
	cols.add_child(right)
	creds = Label.new()
	creds.add_theme_font_size_override("font_size", 16)
	creds.add_theme_color_override("font_color", LootDrop.CREDIT_COLOR)
	root.add_child(creds)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	hint.text = "Click / Enter / A: buy (left) or sell (right)    Esc / B: close"
	root.add_child(hint)
	Events.inventory_changed.connect(_on_changed)
	Events.stats_changed.connect(_on_changed)


func _on_changed() -> void:
	if visible and not _rebuilding:
		refresh()


func _set_tab(t: String) -> void:
	tab = t
	refresh()


func refresh() -> void:
	_rebuilding = true
	var had := get_viewport().gui_get_focus_owner()
	var fg: Control = had.get_parent() if had != null and had.get_parent() in [vendor_grid, pack_grid] else null
	var fi := had.get_index() if fg != null else -1
	creds.text = "Your creds: " + GameState.fmt_uc(GameState.credits)
	for i in tabs.get_child_count():
		var b := tabs.get_child(i) as Button
		b.add_theme_color_override("font_color", UiTheme.BRASS if ["gear", "supplies", "buyback"][i] == tab else UiTheme.TEXT_DIM)
	_clear(vendor_grid)
	_clear(pack_grid)
	match tab:
		"gear":
			for it in GameState.vendor_stock:
				_item_button(vendor_grid, it, ItemDB.buy_price(it), _buy.bind(it, false))
		"buyback":
			for it in GameState.buyback:
				_item_button(vendor_grid, it, ItemDB.sell_price(it), _buy.bind(it, true))
			if GameState.buyback.is_empty():
				var l := Label.new()
				l.text = "Nothing sold yet this session."
				l.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
				vendor_grid.add_child(l)
		"supplies":
			for id in ItemDB.SUPPLIES:
				var s: Dictionary = ItemDB.SUPPLIES[id]
				var b := Button.new()
				b.custom_minimum_size = Vector2(96, 56)
				b.add_theme_font_size_override("font_size", 11)
				b.text = "%s\n%s" % [String(s["name"]), GameState.fmt_uc(int(s["price"]))]
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.disabled = GameState.credits < int(s["price"])
				b.pressed.connect(_buy_supply.bind(id))
				b.focus_entered.connect(_show_supplies)
				vendor_grid.add_child(b)
	for it in GameState.inventory:
		_item_button(pack_grid, it, ItemDB.sell_price(it), _sell.bind(it))
	_rebuilding = false
	if inspect.text == "" and tab == "gear" and not GameState.vendor_stock.is_empty():
		_inspect(GameState.vendor_stock[0], false)
	if fg != null and fg.get_child_count() > 0:
		(fg.get_child(mini(fi, fg.get_child_count() - 1)) as Control).grab_focus()


func _clear(g: Container) -> void:
	for c in g.get_children():
		g.remove_child(c)
		c.queue_free()


func _item_button(g: GridContainer, it: Dictionary, price: int, cb: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 56)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 11)
	var words := ItemDB.slot_label(it).split(" ")
	b.text = "%s\n%s" % [words[words.size() - 1], GameState.fmt_uc(price)]
	b.tooltip_text = String(it["name"])
	b.add_theme_color_override("font_color", ItemDB.rarity_color(int(it["rarity"])))
	if g == vendor_grid and GameState.credits < price:
		b.add_theme_color_override("font_color", ItemDB.rarity_color(int(it["rarity"])).darkened(0.55))
	b.pressed.connect(cb)
	b.focus_entered.connect(_inspect.bind(it, g == pack_grid))
	b.mouse_entered.connect(_inspect.bind(it, g == pack_grid))
	g.add_child(b)


func _inspect(it: Dictionary, selling: bool) -> void:
	if _rebuilding:
		return
	var price := ItemDB.sell_price(it) if selling else (ItemDB.sell_price(it) if GameState.buyback.has(it) else ItemDB.buy_price(it))
	inspect.text = ItemDB.describe(it) + "\n[color=#%s]%s: %s[/color]" % [LootDrop.CREDIT_COLOR.to_html(false), "Sells for" if selling else "Costs", GameState.fmt_uc(price)]
	compare.text = ItemDB.compare(it, GameState.equipment.get(GameState.best_slot_for(it), {}))


func _show_supplies() -> void:
	inspect.text = "Ammo: %d rifle / %d shells\nStim-packs: %d" % [int(GameState.ammo.get("rifle", 0)), int(GameState.ammo.get("shell", 0)), GameState.stims]
	compare.text = ""


func _buy(it: Dictionary, from_buyback: bool) -> void:
	if GameState.buy_item(it, from_buyback):
		Audio.play_ui("pickup")
		Events.msg("Bought: " + String(it["name"]), ItemDB.rarity_color(int(it["rarity"])))
	refresh()


func _sell(it: Dictionary) -> void:
	if int(it["rarity"]) >= ItemDB.RARITY_RARE and pending_sale != it:
		pending_sale = it
		inspect.text = ItemDB.describe(it) + "\n[color=#ff9a6a]Press again to sell this %s item for %s.[/color]" % [
			String(ItemDB.rarities[int(it["rarity"])]["name"]), GameState.fmt_uc(ItemDB.sell_price(it))]
		return
	pending_sale = {}
	if GameState.sell_item(it):
		Audio.play_ui("pickup", 0.8)
		Events.msg("Sold: %s (+%s)" % [String(it["name"]), GameState.fmt_uc(ItemDB.sell_price(it))], LootDrop.CREDIT_COLOR)
	refresh()


func _buy_supply(id: String) -> void:
	if GameState.buy_supply(id):
		Audio.play_ui("pickup", 1.1)
	refresh()
	_show_supplies()
