class_name TerminalUI
extends Screen
## Green-phosphor cogitator readout with a typewriter effect. Pages advance
## with Accept / click. Emits `finished` (via closed) so the game can apply
## the terminal's effects (flags, XP, saving).

var title: Label
var body: RichTextLabel
var next_btn: Button
var page_lbl: Label
var term_id := ""
var terminal: Node = null
var pages: Array = []
var page := 0
var reveal := 0.0
var finished_reading := false

const SCREEN_GREEN := Color(0.45, 1.0, 0.5)


func _ready() -> void:
	var st := UiTheme.panel_style(Color(0.02, 0.05, 0.03, 0.97), Color(0.25, 0.55, 0.3), 2)
	make_panel(Vector2(760, 470))
	panel.add_theme_stylebox_override("panel", st)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	title = UiTheme.title_label("", 20, SCREEN_GREEN)
	root.add_child(title)
	root.add_child(HSeparator.new())
	body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.custom_minimum_size = Vector2(720, 320)
	body.add_theme_color_override("default_color", SCREEN_GREEN)
	body.add_theme_font_size_override("normal_font_size", 17)
	body.scroll_active = false
	root.add_child(body)
	var bottom := HBoxContainer.new()
	page_lbl = Label.new()
	page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_lbl.add_theme_color_override("font_color", Color(0.3, 0.6, 0.35))
	bottom.add_child(page_lbl)
	next_btn = UiTheme.button("Continue", _on_next)
	bottom.add_child(next_btn)
	root.add_child(bottom)


func show_terminal(id: String, term: Node) -> void:
	term_id = id
	terminal = term
	var data: Dictionary = ItemDB.terminals.get(id, {})
	title.text = "> " + String(data.get("title", "TERMINAL"))
	pages = data.get("pages", ["NO DATA"])
	page = 0
	finished_reading = false
	_show_page()
	open()


func _show_page() -> void:
	body.text = GameState.fmt(String(pages[page]))
	body.visible_characters = 0
	reveal = 0.0
	page_lbl.text = "PAGE %d / %d" % [page + 1, pages.size()]
	next_btn.text = "Continue" if page < pages.size() - 1 else "Log off"


func _process(delta: float) -> void:
	if not visible:
		return
	var total := body.get_total_character_count()
	if body.visible_characters >= 0 and body.visible_characters < total:
		reveal += delta * 90.0
		body.visible_characters = int(reveal)
		if body.visible_characters >= total:
			body.visible_characters = -1


func _on_next() -> void:
	if body.visible_characters != -1:
		body.visible_characters = -1
		return
	if page < pages.size() - 1:
		page += 1
		_show_page()
	else:
		finished_reading = true
		close()
