class_name DoctrineUI
extends Screen
## The Combat Specialist's Doctrines (skill trees, requirements 15.14): three
## columns (Gunline, Vanguard, Siegebreaker) of skills by tier, the info panel,
## and the combat ability slots along the bottom. Learning asks for a second
## press (it's permanent until a respec). Slots can only be changed aboard the
## ship. Controller: d-pad / stick, A, B to close.

var header: Label
var cols: HBoxContainer
var info_title: Label
var info: RichTextLabel
var slot_box: HBoxContainer
var slot_hint: Label
var pending := ""        # skill id waiting for the confirming second press
var selected := ""
var _rebuilding := false


class SkillButton extends Button:
	var skill_id := ""
	var state := "locked"   # learned / open / locked / soon

	func _draw() -> void:
		var col := AbilityIcon.color_of(skill_id)
		match state:
			"locked", "soon":
				col = col.darkened(0.65)
			"open":
				col = col.lightened(0.1)
		AbilityIcon.draw(self, skill_id, Vector2(24, size.y * 0.5), col)
		if state == "learned":
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.95, 0.75, 0.35, 0.8), false, 2.0)
		elif state == "open":
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.5, 1.0, 0.55, 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.006)), false, 2.0)


func _ready() -> void:
	make_panel(Vector2(1200, 690))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(UiTheme.title_label("DOCTRINES — COMBAT SPECIALIST", 24))
	header = Label.new()
	header.add_theme_font_size_override("font_size", 15)
	root.add_child(header)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)
	cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	mid.add_child(cols)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	info_title = UiTheme.title_label("", 18)
	right.add_child(info_title)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size = Vector2(300, 300)
	info.add_theme_font_size_override("normal_font_size", 14)
	right.add_child(info)
	mid.add_child(right)
	root.add_child(HSeparator.new())
	root.add_child(UiTheme.title_label("Ability slots", 15, UiTheme.TEXT_DIM))
	slot_box = HBoxContainer.new()
	slot_box.add_theme_constant_override("separation", 8)
	root.add_child(slot_box)
	slot_hint = Label.new()
	slot_hint.add_theme_font_size_override("font_size", 13)
	slot_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	root.add_child(slot_hint)
	Events.stats_changed.connect(_on_changed)


func _on_changed() -> void:
	if visible and not _rebuilding:
		refresh()


func refresh() -> void:
	_rebuilding = true
	var had := get_viewport().gui_get_focus_owner()
	var had_id: String = had.skill_id if had is SkillButton else ""
	var had_slot := had.get_index() if had != null and had.get_parent() == slot_box else -1
	var nx := GameState.next_doctrine_level()
	header.text = "Doctrine points: %d free   (%d earned%s)     Level %d" % [GameState.doctrine_points_free(), GameState.doctrine_points_earned(),
		", next at level %d" % nx if nx > 0 else "", GameState.level]
	for c in cols.get_children():
		cols.remove_child(c)
		c.queue_free()
	var refocus: Control = null
	var tier_names := ["Tier 1", "Tier 2", "Tier 3", "Capstone"]
	var tier_pts: Array = ItemDB.doctrines.get("tier_points", [0, 2, 4, 6])
	for tree in ItemDB.doctrines.get("trees", []):
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(285, 0)
		col.add_theme_constant_override("separation", 4)
		col.add_child(UiTheme.title_label(String(tree["name"]), 18, AbilityIcon.color_of({"gunline": "gl_", "vanguard": "vg_", "siegebreaker": "sb_"}.get(String(tree["id"]), ""))))
		var bl := Label.new()
		bl.text = "%s\nPoints in this Doctrine: %d" % [String(tree["blurb"]), GameState.tree_points(String(tree["id"]))]
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(285, 52)
		bl.add_theme_font_size_override("font_size", 12)
		bl.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		col.add_child(bl)
		for tier in range(1, 5):
			var tl := Label.new()
			tl.text = "%s%s" % [tier_names[tier - 1], "" if tier == 1 else "  (%d in Doctrine)" % int(tier_pts[tier - 1])]
			tl.add_theme_font_size_override("font_size", 12)
			tl.add_theme_color_override("font_color", UiTheme.BRASS_DIM)
			col.add_child(tl)
			for sk in tree["skills"]:
				if int(sk["tier"]) != tier:
					continue
				var b := SkillButton.new()
				b.skill_id = String(sk["id"])
				b.state = _state(b.skill_id)
				b.custom_minimum_size = Vector2(285, 46)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.add_theme_constant_override("h_separation", 0)
				var bs := StyleBoxFlat.new()
				bs.bg_color = Color(0.08, 0.075, 0.075)
				bs.content_margin_left = 50
				for st in ["normal", "hover", "focus", "pressed"]:
					var sb := bs.duplicate() as StyleBoxFlat
					sb.border_color = UiTheme.BRASS if st in ["focus", "pressed"] else (UiTheme.BRASS_DIM if st == "hover" else Color(0.2, 0.18, 0.16))
					sb.set_border_width_all(2 if st != "normal" else 1)
					b.add_theme_stylebox_override(st, sb)
				b.text = "%s\n%s" % [String(sk["name"]), String(sk["kind"]).to_upper() + ("" if b.state != "soon" else "  (coming soon)")]
				b.add_theme_font_size_override("font_size", 13)
				var fc := UiTheme.TEXT if b.state in ["learned", "open"] else UiTheme.TEXT_DIM
				for fs in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
					b.add_theme_color_override(fs, fc)
				b.pressed.connect(_on_skill.bind(b.skill_id))
				b.focus_entered.connect(_show.bind(b.skill_id))
				b.mouse_entered.connect(_show.bind(b.skill_id))
				col.add_child(b)
				if b.skill_id == had_id:
					refocus = b
		cols.add_child(col)
	_build_slots()
	_rebuilding = false
	if had_slot >= 0 and had_slot < slot_box.get_child_count():
		refocus = slot_box.get_child(had_slot)
	if refocus != null:
		refocus.grab_focus()
	elif selected != "":
		_show(selected)


func _state(id: String) -> String:
	if GameState.has_skill(id):
		return "learned"
	if not bool(GameState.skill_def(id).get("ready", false)):
		return "soon"
	return "open" if GameState.learn_block(id) == "" else "locked"


func _show(id: String) -> void:
	if _rebuilding:
		return
	selected = id
	var d := GameState.skill_def(id)
	info_title.text = String(d.get("name", id))
	var lines := "[color=#a08850]%s%s[/color]\n\n%s\n" % [String(d.get("kind", "")).to_upper(),
		"" if String(d.get("tree", "")) == "" else "  ·  " + _tree_name(String(d["tree"])), String(d.get("desc", ""))]
	if String(d.get("kind", "")) == "active":
		lines += "\nCooldown %d s   ·   Energy %d" % [int(d.get("cd", 0)), int(d.get("cost", 0))]
	var st := _state(id)
	match st:
		"learned":
			lines += "\n\n[color=#e8c060]Learned.[/color]"
		"open":
			lines += "\n\n[color=#80ff90]%s[/color]" % ("Press again to learn it. Permanent until a respec at the Medic." if pending == id else "Press to learn (costs 1 Doctrine point).")
		_:
			lines += "\n\n[color=#ff8a6a]%s[/color]" % GameState.learn_block(id)
	info.text = lines


func _tree_name(tid: String) -> String:
	for t in ItemDB.doctrines.get("trees", []):
		if String(t["id"]) == tid:
			return String(t["name"])
	return ""


func _on_skill(id: String) -> void:
	if _state(id) != "open":
		_show(id)
		return
	if pending != id:
		pending = id
		_show(id)
		return
	pending = ""
	if GameState.learn_skill(id):
		Audio.play_ui("levelup")
		Events.msg("Doctrine learned: " + String(GameState.skill_def(id)["name"]), Color(0.95, 0.8, 0.4))
	refresh()
	_show(id)


func _build_slots() -> void:
	for c in slot_box.get_children():
		slot_box.remove_child(c)
		c.queue_free()
	var keys := ["ability_1", "ability_2", "ability_3"]
	for i in 3:
		var b := SkillButton.new()
		var open := i < GameState.slot_count()
		b.skill_id = String(GameState.slots[i]) if open else ""
		b.state = "learned" if b.skill_id != "" else "locked"
		b.custom_minimum_size = Vector2(250, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.08, 0.075, 0.075)
		bs.content_margin_left = 50
		bs.border_color = Color(0.2, 0.18, 0.16)
		bs.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", bs)
		var fsb := bs.duplicate() as StyleBoxFlat
		fsb.border_color = UiTheme.BRASS
		fsb.set_border_width_all(2)
		b.add_theme_stylebox_override("focus", fsb)
		b.add_theme_stylebox_override("hover", fsb)
		b.add_theme_font_size_override("font_size", 13)
		var key := InputSetup.key_hint(keys[i])
		if not open:
			b.text = "[%s]  Opens at level %d" % [key, int(ItemDB.doctrines.get("third_slot_level", 20))]
		else:
			b.text = "[%s]  %s" % [key, String(Player.ability_info(b.skill_id)["name"]) if b.skill_id != "" else "— empty —"]
		b.pressed.connect(_cycle_slot.bind(i))
		slot_box.add_child(b)
	slot_hint.text = "Select a slot to cycle through your active abilities." if GameState.is_hub() \
		else "Ability slots can only be changed aboard the ship. Passives are always on."


## Cycles a slot through basic training + learned actives (aboard the ship only).
func _cycle_slot(i: int) -> void:
	if i >= GameState.slot_count():
		return
	if not GameState.is_hub():
		Events.msg("Ability slots can only be changed aboard the ship.", Color(1.0, 0.55, 0.35))
		return
	var opts: Array = GameState.slottable()
	opts.append("")
	var cur := opts.find(String(GameState.slots[i]))
	GameState.set_slot(i, String(opts[(cur + 1) % opts.size()]))
	Audio.play_ui("pickup", 1.3, -8.0)
	refresh()
