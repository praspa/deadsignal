class_name ItemSlot
extends Button
## An inventory-style slot that shows the item itself: its procedural icon
## (ItemIcon, the same silhouettes as loot on the floor) in its rarity colour.
## The rarity colour stays put in every state: hover and selection brighten
## and thicken the rarity-coloured frame and add a brass corner marker instead
## of recolouring the text.
##   Grid mode (default): icon centred, small caption underneath (e.g. a price).
##   Wide mode: icon on the left, text to its right (equipment slots).
## An empty slot can show a dim placeholder silhouette (`ghost`) of what goes there.

var item: Dictionary = {}
var ghost: Dictionary = {}     # placeholder item for an empty slot (drawn dim)
var caption := ""
var wide := false
var dim := false               # e.g. unaffordable in a shop
var icon_scale := 1.15


static func make(p_item: Dictionary, p_caption := "", p_wide := false, size_px := Vector2(82, 56)) -> ItemSlot:
	var s := ItemSlot.new()
	s.item = p_item
	s.caption = p_caption
	s.wide = p_wide
	s.custom_minimum_size = size_px
	s.focus_mode = Control.FOCUS_ALL
	s.clip_text = true
	return s


func _ready() -> void:
	var rc := rarity()
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, rc if not item.is_empty() else UiTheme.TEXT_DIM)
	add_theme_font_size_override("font_size", 11 if not wide else 14)
	var tint := rc if not item.is_empty() else UiTheme.BRASS_DIM
	add_theme_stylebox_override("normal", _box(Color(0.08, 0.075, 0.075), tint.darkened(0.45), 1))
	add_theme_stylebox_override("hover", _box(Color(0.13, 0.11, 0.1), tint, 2))
	add_theme_stylebox_override("focus", _box(Color(0.15, 0.12, 0.1), tint.lightened(0.25), 3))
	add_theme_stylebox_override("pressed", _box(Color(0.2, 0.1, 0.08), tint.lightened(0.25), 3))
	add_theme_stylebox_override("hover_pressed", _box(Color(0.2, 0.1, 0.08), tint.lightened(0.25), 3))
	if wide:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		text = caption
	else:
		text = ""
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func rarity() -> Color:
	return ItemDB.rarity_color(int(item["rarity"])) if not item.is_empty() else UiTheme.TEXT_DIM


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(w)
	b.set_content_margin_all(4)
	if wide:
		b.content_margin_left = 62   # room for the icon
	return b


func _draw() -> void:
	var sz := size
	var rc := rarity()
	var shown := item if not item.is_empty() else ghost
	if not shown.is_empty():
		var col := rc if not item.is_empty() else Color(0.4, 0.38, 0.34, 0.6)
		if dim:
			col = col.darkened(0.55)
		var at := Vector2(30, sz.y * 0.5 + 2) if wide else Vector2(sz.x * 0.5, sz.y * (0.42 if caption != "" else 0.55))
		if not item.is_empty() and int(item["rarity"]) >= ItemDB.RARITY_UNCOMMON:
			# soft rarity glow behind the icon
			draw_circle(at, 16.0, Color(rc.r, rc.g, rc.b, 0.08 + 0.04 * int(item["rarity"])))
		ItemIcon.draw(self, shown, at, icon_scale if not wide else 1.0, col)
		draw_set_transform(Vector2.ZERO)
	if not wide and caption != "":
		var font := get_theme_default_font()
		var cc := rc if not dim else rc.darkened(0.55)
		draw_string(font, Vector2(2, sz.y - 6), caption, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 4, 11, cc)
	if has_focus() or is_hovered():
		# brass corner marker: "this one", without losing the rarity colour
		var m := UiTheme.BRASS if has_focus() else UiTheme.BRASS_DIM
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(0, 10)]), m)
		draw_colored_polygon(PackedVector2Array([Vector2(sz.x, sz.y), Vector2(sz.x - 10, sz.y), Vector2(sz.x, sz.y - 10)]), m)
