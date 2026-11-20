class_name JournalUI
extends Screen
## Mission journal (J, or Journal in the pause menu). Left: active missions,
## then completed ones, then the ship's crew. Right: the selected entry's
## objectives (done, current; later ones stay hidden) and every comms line
## heard for it, oldest first. Lines are recorded by GameState.journal_log as
## they play, so the journal only holds what the operative has actually heard.

const C_DONE := Color(0.55, 0.62, 0.5)
const C_CURRENT := Color(0.95, 0.78, 0.4)
const C_OVERWATCH := Color(0.55, 0.85, 1.0)
const C_CREW := Color(0.85, 0.78, 0.6)

var list: VBoxContainer
var title_lbl: Label
var status_lbl: Label
var objectives: RichTextLabel
var log_lbl: RichTextLabel
var shown := ""          # mission id, or "crew"


func _ready() -> void:
	make_panel(Vector2(1060, 640))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	root.add_child(UiTheme.title_label("MISSION JOURNAL", 24))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(300, 0)
	list.add_theme_constant_override("separation", 6)
	cols.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	title_lbl = UiTheme.title_label("", 22)
	right.add_child(title_lbl)
	status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 13)
	right.add_child(status_lbl)
	objectives = RichTextLabel.new()
	objectives.bbcode_enabled = true
	objectives.fit_content = true
	objectives.scroll_active = false
	objectives.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(objectives)
	right.add_child(UiTheme.title_label("COMMS LOG", 15, UiTheme.TEXT_DIM))
	log_lbl = RichTextLabel.new()
	log_lbl.bbcode_enabled = true
	log_lbl.scroll_active = true
	log_lbl.scroll_following = true
	log_lbl.focus_mode = Control.FOCUS_ALL   # d-pad right into the log, then up / down scrolls it
	log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_lbl.add_theme_font_size_override("normal_font_size", 14)
	log_lbl.add_theme_constant_override("paragraph_separation", 6)
	right.add_child(log_lbl)
	var hint := Label.new()
	hint.text = "Select an entry to read it.  Right: into the log, Up / Down to scroll.    J / Esc / B (Circle): close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	root.add_child(hint)


func refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var first := ""
	for status in ["active", "completed"]:
		var ids: Array = ItemDB.missions.keys().filter(func(m: String) -> bool: return GameState.mission_status(m) == status)
		if ids.is_empty():
			continue
		list.add_child(UiTheme.title_label(status.to_upper(), 14, UiTheme.TEXT_DIM))
		for mid in ids:
			_entry(String(ItemDB.missions[mid].get("title", mid)), mid)
			if first == "":
				first = mid
	list.add_child(UiTheme.title_label("SABLE MULE", 14, UiTheme.TEXT_DIM))
	_entry("Ship & crew", "crew")
	if shown == "" or (shown != "crew" and GameState.mission_status(shown) == "locked"):
		shown = first if first != "" else "crew"
	show_entry(shown)


func _entry(text: String, id: String) -> void:
	var b := UiTheme.button(text, show_entry.bind(id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 40)
	b.set_meta("entry", id)
	b.focus_entered.connect(show_entry.bind(id))
	b.mouse_entered.connect(show_entry.bind(id))
	list.add_child(b)
	b.focus_neighbor_right = b.get_path_to(log_lbl)


## Focuses the list entry for `id` (the screen opens on the shown entry).
func focus_first() -> void:
	for c in list.get_children():
		if c is Button and String(c.get_meta("entry", "")) == shown:
			(c as Button).grab_focus()
			return
	super.focus_first()


func show_entry(id: String) -> void:
	shown = id
	for c in list.get_children():
		if c is Button:
			var on := String(c.get_meta("entry", "")) == id
			(c as Button).add_theme_color_override("font_color", UiTheme.BRASS if on else UiTheme.TEXT)
	if id == "crew":
		title_lbl.text = "SHIP & CREW"
		status_lbl.text = "Talk aboard the Sable Mule"
		status_lbl.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		objectives.text = ""
	else:
		_show_mission(id)
	_show_log(id)


func _show_mission(mid: String) -> void:
	var m: Dictionary = ItemDB.missions.get(mid, {})
	var objs: Array = m.get("objectives", [])
	var status := GameState.mission_status(mid)
	var idx := GameState.objective_index(mid)
	title_lbl.text = String(m.get("title", mid)).to_upper()
	var bounty := int(m.get("bounty", 0))
	if status == "completed":
		status_lbl.text = "COMPLETED" + ("   ·   Bounty paid: %s" % GameState.fmt_uc(bounty) if bounty > 0 else "")
		status_lbl.add_theme_color_override("font_color", C_DONE)
	else:
		status_lbl.text = "ACTIVE" + ("   ·   Bounty: %s" % GameState.fmt_uc(bounty) if bounty > 0 else "")
		status_lbl.add_theme_color_override("font_color", C_CURRENT)
	var s := ""
	for i in objs.size():
		var t := GameState.journal_objective_text(mid, i)
		if i < idx:
			s += "[color=#%s]✓  %s[/color]\n" % [C_DONE.to_html(false), t]
		elif i == idx:
			s += "[color=#%s]▸  %s[/color]\n" % [C_CURRENT.to_html(false), t]
	if idx < objs.size() - 1:
		s += "[color=#%s]   ...[/color]\n" % UiTheme.TEXT_DIM.to_html(false)
	objectives.text = s.strip_edges()


func _show_log(id: String) -> void:
	var entries := GameState.journal_entries(id)
	if entries.is_empty():
		log_lbl.text = "[color=#%s]Nothing on record yet.[/color]" % UiTheme.TEXT_DIM.to_html(false)
		return
	var s := PackedStringArray()
	for e in entries:
		var who := String(e.get("who", ""))
		var col := C_OVERWATCH if who.to_upper() == "OVERWATCH" else C_CREW
		var text := String(e.get("text", "")).replace("[", "[lb]")
		s.append("[color=#%s]%s[/color]  %s" % [col.to_html(false), who.to_upper() if who != "" else "—", text])
	log_lbl.text = "\n".join(s)
