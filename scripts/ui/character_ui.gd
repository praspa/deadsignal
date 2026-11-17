class_name CharacterUI
extends Screen
## Character sheet: spend attribute points and review derived combat stats.

var rows: VBoxContainer
var stats: RichTextLabel
var header: Label

const ATTR_INFO := {
	"str": ["STRENGTH", "Melee damage, max health, physical might."],
	"dex": ["DEXTERITY", "Ranged damage, accuracy, evasion, critical chance."],
	"int": ["INTELLIGENCE", "Ability power, energy weapons, max energy."],
	"wil": ["WILLPOWER", "Status resistance, energy regen, cooldowns."],
}


func _ready() -> void:
	make_panel(Vector2(840, 640))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	root.add_child(UiTheme.title_label("OPERATIVE DOSSIER", 24))
	header = Label.new()
	root.add_child(header)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	root.add_child(cols)
	rows = VBoxContainer.new()
	rows.custom_minimum_size = Vector2(400, 0)
	rows.add_theme_constant_override("separation", 8)
	cols.add_child(rows)
	stats = RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.custom_minimum_size = Vector2(360, 470)
	stats.scroll_active = false
	stats.add_theme_font_size_override("normal_font_size", 14)
	cols.add_child(stats)
	var hint := Label.new()
	hint.text = "Select an attribute and press Enter / A (PS Cross) / click to assign a point.    C / Esc / B (Circle): close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	root.add_child(hint)
	Events.stats_changed.connect(_on_stats_changed)


func _on_stats_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var fidx := focus.get_index() if focus != null and focus.get_parent() == rows else 0
	header.text = "Level %d %s     Attribute points: %d" % [GameState.level, GameState.CLASS_NAME, GameState.attr_points]
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	for a in GameState.ATTRS:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(400, 70)
		var base := int(GameState.attributes[a])
		var bonus := int(GameState.equip_stat(a))
		var bonus_s := " (+%d gear)" % bonus if bonus != 0 else ""
		b.text = "%s   %d%s   %s\n%s" % [ATTR_INFO[a][0], base, bonus_s, "[ + ]" if GameState.attr_points > 0 else "", ATTR_INFO[a][1]]
		b.pressed.connect(_spend.bind(a))
		rows.add_child(b)
	var close_b := UiTheme.button("Close", close)
	rows.add_child(close_b)
	if fidx >= 0 and fidx < rows.get_child_count():
		(rows.get_child(fidx) as Control).call_deferred("grab_focus")
	var s := ""
	s += "[color=#c9a54a]VITALS[/color]\n"
	s += "Max Health: %d\nMax Energy: %d\n" % [roundi(GameState.max_hp()), roundi(GameState.max_energy())]
	s += "Health Regen: %.1f/s\nEnergy Regen: %.1f/s\n\n" % [GameState.hp_regen(), GameState.energy_regen()]
	s += "[color=#c9a54a]OFFENCE[/color]\n"
	s += "Ranged Damage: x%.2f\nMelee Damage: x%.2f\nTech / Ability Power: x%.2f\n" % [GameState.ranged_mult(), GameState.melee_mult(), GameState.tech_mult()]
	s += "Critical Chance: %d%%\nAccuracy (spread): x%.2f\n\n" % [roundi(GameState.crit_chance() * 100), GameState.spread_mult()]
	s += "[color=#c9a54a]DEFENCE[/color]\n"
	var a_val := GameState.armor()
	s += "Armor: %d  (-%d%% damage)\n" % [roundi(a_val), roundi(minf(a_val / (a_val + 60.0), 0.75) * 100)]
	s += "Evasion: %d%%\nStatus Resistance: %d%%\nCooldown modifier: x%.2f\n\n" % [roundi(GameState.evasion() * 100), roundi(GameState.status_resist() * 100), GameState.cooldown_mult()]
	s += "[color=#888]Combat Specialist: +10% firearm damage, +3 armor.[/color]"
	stats.text = s


func _spend(a: String) -> void:
	if GameState.spend_point(a):
		refresh()
