class_name UiTheme
## Grimdark UI theme built in code: blackened iron panels with brass trim.

const BRASS := Color(0.62, 0.48, 0.22)
const BRASS_DIM := Color(0.36, 0.28, 0.14)
const IRON := Color(0.07, 0.065, 0.07, 0.96)
const IRON_LIGHT := Color(0.13, 0.12, 0.12)
const BLOOD := Color(0.55, 0.07, 0.05)
const TEXT := Color(0.86, 0.82, 0.72)
const TEXT_DIM := Color(0.55, 0.52, 0.47)

static var _theme: Theme


static func panel_style(bg: Color = IRON, border: Color = BRASS_DIM, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var btn := panel_style(Color(0.1, 0.09, 0.09), BRASS_DIM, 1)
	btn.set_content_margin_all(6)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	var btn_hover := panel_style(Color(0.17, 0.13, 0.1), BRASS, 1)
	btn_hover.set_content_margin_all(6)
	btn_hover.content_margin_left = 14
	btn_hover.content_margin_right = 14
	var btn_focus := panel_style(Color(0.2, 0.09, 0.07), Color(0.95, 0.75, 0.35), 2)
	btn_focus.set_content_margin_all(6)
	btn_focus.content_margin_left = 14
	btn_focus.content_margin_right = 14
	btn_focus.draw_center = true
	var btn_pressed := panel_style(BLOOD, BRASS, 2)
	btn_pressed.set_content_margin_all(6)
	var btn_disabled := panel_style(Color(0.06, 0.06, 0.06), Color(0.2, 0.2, 0.2), 1)
	btn_disabled.set_content_margin_all(6)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("hover_pressed", "Button", btn_pressed)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.92, 0.75))
	t.set_color("font_focus_color", "Button", Color(1, 0.92, 0.75))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.35, 0.35))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	var sep := StyleBoxLine.new()
	sep.color = BRASS_DIM
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


static func title_label(text: String, size: int = 28, col: Color = BRASS) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b
