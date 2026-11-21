class_name Hud
extends CanvasLayer
## In-game HUD, drawn procedurally: health/energy orbs, XP bar, ability
## cooldowns, weapon + ammo, objective, boss / target health, messages,
## interaction prompt and crosshair. Also hosts the vignette post effect.

var player: Player
var draw_node: Control
var vignette: ColorRect
var messages: Array = []        # [text, color, age]
var boss_name := ""
var boss_hp := 0.0
var boss_max := 1.0
var boss_visible := false
var objective := ""
var objective_flash := 0.0
var levelup_t := 0.0
var hurt := 0.0
var font: Font

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float hurt = 0.0;
uniform float low_hp = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.25, 1.0));
	float v = smoothstep(0.32, 0.85, d);
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
	vec3 col = mix(vec3(0.0), vec3(0.45, 0.0, 0.0), clamp(hurt + low_hp * pulse * 0.7, 0.0, 1.0));
	COLOR = vec4(col, v * (0.72 + hurt * 0.25) + (hurt * 0.12));
}
"""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	mat.shader = sh
	vignette.material = mat
	add_child(vignette)
	draw_node = Control.new()
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_draw_hud)
	add_child(draw_node)
	Events.message.connect(_on_message)
	Events.boss_bar.connect(_on_boss_bar)
	Events.objective_changed.connect(_on_objective)
	Events.leveled_up.connect(_on_level_up)
	Events.player_hurt.connect(_on_hurt)
	objective = GameState.current_objective_text()


func _on_objective(t: String) -> void:
	objective = t
	objective_flash = 2.5


func _on_level_up(lv: int) -> void:
	levelup_t = 4.0
	_on_message("LEVEL UP! You are now level %d. Press [%s] to assign attribute points." % [lv, InputSetup.key_hint("character")], Color(1.0, 0.85, 0.3))


func _on_hurt(a: float) -> void:
	hurt = minf(1.0, hurt + a / 40.0)


func _on_message(t: String, c: Color) -> void:
	# word-wrap long lines so comms never run off-screen
	var line := ""
	for word in t.split(" "):
		var test := word if line == "" else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > 590.0 and line != "":
			messages.append([line, c, 0.0])
			line = "    " + word
		else:
			line = test
	if line != "":
		messages.append([line, c, 0.0])
	while messages.size() > 9:
		messages.pop_front()


func _on_boss_bar(n: String, hp: float, mx: float, vis: bool) -> void:
	boss_name = n
	boss_hp = hp
	boss_max = mx
	boss_visible = vis


func _process(delta: float) -> void:
	for m in messages:
		m[2] = float(m[2]) + delta
	while not messages.is_empty() and float(messages[0][2]) > 7.0:
		messages.pop_front()
	objective_flash = maxf(0.0, objective_flash - delta)
	levelup_t = maxf(0.0, levelup_t - delta)
	hurt = maxf(0.0, hurt - delta * 1.5)
	var low := 0.0
	if player != null and is_instance_valid(player) and not player.dead:
		low = clampf(1.0 - (player.hp / player.max_hp) / 0.3, 0.0, 1.0)
	(vignette.material as ShaderMaterial).set_shader_parameter("hurt", hurt)
	(vignette.material as ShaderMaterial).set_shader_parameter("low_hp", low)
	draw_node.queue_redraw()


# ---------------------------------------------------------------- drawing helpers

func _text(pos: Vector2, t: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_node.draw_string_outline(font, pos, t, align, width, size, 4, Color(0, 0, 0, col.a * 0.9))
	draw_node.draw_string(font, pos, t, align, width, size, col)


func _orb(c: Vector2, r: float, frac: float, col: Color, label: String) -> void:
	var d := draw_node
	d.draw_circle(c, r + 6.0, Color(0.05, 0.045, 0.045))
	d.draw_circle(c, r, Color(0.02, 0.02, 0.02))
	frac = clampf(frac, 0.0, 1.0)
	if frac > 0.0:
		var level_y := c.y + r - 2.0 * r * frac
		var pts := PackedVector2Array()
		for i in 48:
			var p := c + Vector2.from_angle(TAU * i / 48.0) * (r - 2.0)
			p.y = maxf(p.y, level_y)
			pts.append(p)
		d.draw_colored_polygon(pts, col)
		var wave := sin(Time.get_ticks_msec() * 0.004) * 2.0
		var half_w := sqrt(maxf(0.0, r * r - pow(level_y - c.y, 2.0))) - 3.0
		if frac < 0.98:
			d.draw_line(Vector2(c.x - half_w, level_y + wave * 0.3), Vector2(c.x + half_w, level_y - wave * 0.3), col.lightened(0.35), 2.0)
	d.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.22, Color(1, 1, 1, 0.08))
	d.draw_arc(c, r + 3.0, 0, TAU, 48, UiTheme.BRASS, 3.0)
	d.draw_arc(c, r + 7.0, 0, TAU, 48, UiTheme.BRASS_DIM, 1.5)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		d.draw_line(c + Vector2.from_angle(a) * (r + 2), c + Vector2.from_angle(a) * (r + 11), UiTheme.BRASS, 3.0)
	_text(c + Vector2(-r, 6), label, 15, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _draw_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	var d := draw_node
	var vs := d.size
	# --- bottom frame
	var by := vs.y - 74.0
	d.draw_rect(Rect2(0, by, vs.x, 74), Color(0.045, 0.04, 0.045, 0.94))
	d.draw_line(Vector2(0, by), Vector2(vs.x, by), UiTheme.BRASS_DIM, 2.0)
	d.draw_line(Vector2(0, by + 4), Vector2(vs.x, by + 4), Color(0.2, 0.15, 0.08), 1.0)
	# --- orbs
	_orb(Vector2(78, vs.y - 70), 60.0, player.hp / player.max_hp, Color(0.55, 0.04, 0.03), "%d/%d" % [roundi(player.hp), roundi(player.max_hp)])
	_orb(Vector2(vs.x - 78, vs.y - 70), 60.0, GameState.energy / GameState.max_energy(), Color(0.1, 0.28, 0.6), "%d/%d" % [roundi(GameState.energy), roundi(GameState.max_energy())])
	# --- XP bar
	var xr := Rect2(160, vs.y - 12, vs.x - 320, 7)
	d.draw_rect(xr, Color(0.02, 0.02, 0.02))
	d.draw_rect(Rect2(xr.position, Vector2(xr.size.x * float(GameState.xp) / float(GameState.xp_to_next()), xr.size.y)), Color(0.55, 0.42, 0.9))
	d.draw_rect(xr, UiTheme.BRASS_DIM, false, 1.0)
	for i in range(1, 10):
		var x := xr.position.x + xr.size.x * i / 10.0
		d.draw_line(Vector2(x, xr.position.y), Vector2(x, xr.end.y), Color(0, 0, 0, 0.6), 1.0)
	# --- weapons
	_draw_weapon_panel(Rect2(158, by + 8, 300, 26), "primary", "fire_primary")
	_draw_weapon_panel(Rect2(158, by + 36, 300, 26), "secondary", "fire_secondary")
	# --- abilities
	# Tactical Roll, then the combat ability slots (2, or 3 from level 20), stim, recall
	# boxes sit between the weapon panels (end at x 458) and the level text, above the XP bar
	var ax := 472.0
	var abil := [["roll", "roll"]]
	for i in GameState.slot_count():
		abil.append([String(GameState.slots[i]), "ability_%d" % (i + 1)])
	var step := 56.0
	var bs := Vector2(48, 48)
	for i in abil.size():
		_draw_ability(Rect2(Vector2(ax + i * step, by + 6), bs), String(abil[i][0]), String(abil[i][1]))
	_draw_stim(Rect2(Vector2(ax + abil.size() * step, by + 6), bs))
	_draw_recall(Rect2(Vector2(ax + (abil.size() + 1) * step, by + 6), bs))
	# --- level / points
	var lx := vs.x - 450.0
	_text(Vector2(lx, by + 26), "LEVEL %d  %s" % [GameState.level, GameState.class_title().to_upper()], 15, UiTheme.BRASS)
	_text(Vector2(lx, by + 46), "XP %d / %d" % [GameState.xp, GameState.xp_to_next()], 13, UiTheme.TEXT_DIM)
	_text(Vector2(lx + 150, by + 46), GameState.fmt_uc(GameState.credits), 13, LootDrop.CREDIT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, 150)
	if GameState.attr_points > 0:
		var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		_text(Vector2(lx, by + 64), "+%d attribute points [%s]" % [GameState.attr_points, InputSetup.key_hint("character")], 13, Color(1.0, 0.85, 0.3, a))
	# --- objective
	var obj_col := UiTheme.TEXT if objective_flash <= 0.0 else Color(1.0, 0.85, 0.3)
	d.draw_rect(Rect2(10, 10, 430, 50), Color(0, 0, 0, 0.55))
	d.draw_rect(Rect2(10, 10, 4, 50), UiTheme.BLOOD)
	_text(Vector2(22, 30), "OBJECTIVE", 12, UiTheme.BRASS)
	_text(Vector2(22, 50), objective, 15, obj_col)
	# --- boss bar / hovered target
	if boss_visible:
		var bw := 560.0
		var bx := (vs.x - bw) * 0.5
		d.draw_rect(Rect2(bx - 3, 18, bw + 6, 22), Color(0, 0, 0, 0.8))
		d.draw_rect(Rect2(bx, 21, bw * clampf(boss_hp / boss_max, 0, 1), 16), Color(0.6, 0.05, 0.04))
		d.draw_rect(Rect2(bx - 3, 18, bw + 6, 22), UiTheme.BRASS, false, 2.0)
		_text(Vector2(bx, 60), boss_name, 16, Color(1.0, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, bw)
	elif player.hovered_enemy != null and is_instance_valid(player.hovered_enemy):
		var e := player.hovered_enemy as Enemy
		if e != null and not e.dead:
			var bw2 := 300.0
			var bx2 := (vs.x - bw2) * 0.5
			d.draw_rect(Rect2(bx2 - 2, 16, bw2 + 4, 20), Color(0, 0, 0, 0.75))
			d.draw_rect(Rect2(bx2, 18, bw2 * e.hp / e.max_hp, 16), Color(0.55, 0.06, 0.05))
			_text(Vector2(bx2, 31), e.display_name, 14, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, bw2)
			if float(e.def.get("front_shield", 0.0)) > 0.0:
				_text(Vector2(bx2, 52), "Frontal shield — flank or disrupt", 12, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, bw2)
	# --- messages (left, under the objective; clear of the boss bar)
	var my := 84.0
	for m in messages:
		var age := float(m[2])
		var c: Color = m[1]
		c.a = clampf(7.0 - age, 0.0, 1.0)
		_text(Vector2(14, my), String(m[0]), 14, c)
		my += 19.0
	# --- interaction prompt
	var it := player.interact_target
	if it != null and is_instance_valid(it):
		var label := "[%s] %s" % [InputSetup.key_hint("interact"), String(it.call("interact_text"))]
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var px := (vs.x - tw) * 0.5
		d.draw_rect(Rect2(px - 10, by - 44, tw + 20, 28), Color(0, 0, 0, 0.7))
		d.draw_rect(Rect2(px - 10, by - 44, tw + 20, 28), UiTheme.BRASS_DIM, false, 1.0)
		_text(Vector2(px, by - 24), label, 16, Color(1.0, 0.9, 0.65))
	if levelup_t > 0.0:
		var a2 := clampf(levelup_t, 0.0, 1.0)
		_text(Vector2(0, vs.y * 0.3), "LEVEL UP", 40, Color(1.0, 0.8, 0.3, a2), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	# --- crosshair
	if not player.dead and not get_tree().paused:
		var cp: Vector2
		if InputSetup.using_pad:
			cp = player.get_viewport().get_canvas_transform() * (Iso.sp(player.aim_point, 16))
		else:
			cp = d.get_local_mouse_position()
		var cc := Color(1.0, 0.3, 0.2, 0.9) if player.hovered_enemy != null else Color(0.9, 0.85, 0.7, 0.85)
		d.draw_arc(cp, 9.0, 0, TAU, 20, cc, 1.5)
		for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			d.draw_line(cp + v * 5.0, cp + v * 14.0, cc, 2.0)
		d.draw_circle(cp, 1.5, cc)


func _draw_weapon_panel(r: Rect2, slot: String, action: String) -> void:
	var d := draw_node
	var item: Dictionary = GameState.equipment.get(slot, {})
	d.draw_rect(r, Color(0.08, 0.075, 0.075))
	d.draw_rect(r, UiTheme.BRASS_DIM, false, 1.0)
	_text(r.position + Vector2(6, 18), InputSetup.key_hint(action), 12, UiTheme.BRASS)
	if item.is_empty():
		_text(r.position + Vector2(44, 18), "— empty —", 13, UiTheme.TEXT_DIM)
		return
	var col := ItemDB.rarity_color(int(item["rarity"]))
	var nm := String(item["name"])
	if nm.length() > 24:
		nm = nm.substr(0, 23) + "…"
	_text(r.position + Vector2(44, 18), nm, 13, col)
	var w: Dictionary = item["weapon"]
	var ammo_s := ""
	if w.has("mag"):
		if player.is_reloading(slot):
			ammo_s = "RELOADING"
		else:
			ammo_s = "%d | %d" % [int(item.get("loaded", 0)), int(GameState.ammo.get(String(w["ammo"]), 0))]
	elif w.has("energy_cost"):
		ammo_s = "%d EN" % int(w["energy_cost"])
	else:
		ammo_s = "MELEE"
	var low := w.has("mag") and int(item.get("loaded", 0)) <= int(w["mag"]) / 4
	_text(r.position + Vector2(r.size.x - 104, 18), ammo_s, 13, Color(1.0, 0.4, 0.3) if low else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 98)


func _draw_ability(r: Rect2, id: String, action: String) -> void:
	var d := draw_node
	if id == "":
		d.draw_rect(r, Color(0.04, 0.04, 0.045))
		d.draw_rect(r, UiTheme.BRASS_DIM.darkened(0.4), false, 1.0)
		_text(r.position + Vector2(3, 13), InputSetup.key_hint(action), 11, UiTheme.BRASS_DIM)
		_text(Vector2(r.position.x, r.get_center().y + 5), "empty", 10, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	var cd := float(player.cooldowns.get(id, 0.0))
	var total := player.ability_cd(id)
	var cost := float(Player.ability_info(id)["cost"])
	var is_ready := cd <= 0.0 and GameState.energy >= cost
	var active := (id == "overcharge" and player.overcharge_t > 0.0) or (id == "roll" and player.roll_t > 0.0)
	d.draw_rect(r, Color(0.06, 0.055, 0.06))
	var icol := AbilityIcon.color_of(id)
	if not is_ready:
		icol = icol.darkened(0.6)
	var c := r.get_center() + Vector2(0, -3)
	d.draw_set_transform(c, 0.0, Vector2(0.8, 0.8))
	AbilityIcon.draw(d, id, Vector2.ZERO, icol)
	d.draw_set_transform(Vector2.ZERO)
	if cd > 0.0:
		var f := cd / total
		d.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - f), r.size.x, r.size.y * f), Color(0, 0, 0, 0.65))
		_text(Vector2(r.position.x, r.get_center().y + 6), "%.1f" % cd, 15, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var border := UiTheme.BRASS if is_ready else UiTheme.BRASS_DIM
	if active:
		border = icol.lightened(0.4)
	d.draw_rect(r, border, false, 2.0 if not active else 3.0)
	_text(r.position + Vector2(3, 13), InputSetup.key_hint(action), 11, UiTheme.BRASS)
	_text(Vector2(r.position.x, r.end.y - 3), "%d" % roundi(cost), 10, Color(0.5, 0.7, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3)


## Recall: beam-up icon, cooldown sweep, progress while channeling.
func _draw_recall(r: Rect2) -> void:
	var d := draw_node
	var cd := GameState.recall_cd
	var aboard := GameState.is_hub()
	var is_ready := cd <= 0.0 and not aboard
	d.draw_rect(r, Color(0.06, 0.055, 0.06))
	var icol := Color(0.5, 0.8, 1.0) if is_ready else Color(0.25, 0.35, 0.45)
	var c := r.get_center() + Vector2(0, -3)
	d.draw_rect(Rect2(c + Vector2(-3, -14), Vector2(6, 22)), Color(icol.r, icol.g, icol.b, 0.5))
	d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -18), c + Vector2(-8, -8), c + Vector2(8, -8)]), icol)
	d.draw_arc(c + Vector2(0, 10), 10.0, PI * 0.1, PI * 0.9, 10, icol, 2.0)
	if player.recall_t > 0.0:
		var f := 1.0 - player.recall_t / Player.RECALL_CHANNEL
		d.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * f, r.size.x, r.size.y * f), Color(0.4, 0.75, 1.0, 0.35))
	elif cd > 0.0:
		var f2 := clampf(cd / Player.RECALL_COOLDOWN, 0.0, 1.0)
		d.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - f2), r.size.x, r.size.y * f2), Color(0, 0, 0, 0.65))
		_text(Vector2(r.position.x, r.get_center().y + 6), "%d" % ceili(cd), 15, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	d.draw_rect(r, UiTheme.BRASS if is_ready else UiTheme.BRASS_DIM, false, 2.0)
	_text(r.position + Vector2(3, 13), InputSetup.key_hint("recall"), 11, UiTheme.BRASS)


func _draw_stim(r: Rect2) -> void:
	var d := draw_node
	d.draw_rect(r, Color(0.06, 0.055, 0.06))
	var c := r.get_center() + Vector2(0, -3)
	var col := Color(0.5, 1.0, 0.55) if GameState.stims > 0 else Color(0.25, 0.3, 0.25)
	d.draw_rect(Rect2(c - Vector2(9, 12), Vector2(18, 24)), col.darkened(0.5))
	d.draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color(0.9, 0.15, 0.1), 3.0)
	d.draw_line(c + Vector2(0, -6), c + Vector2(0, 6), Color(0.9, 0.15, 0.1), 3.0)
	d.draw_rect(r, UiTheme.BRASS_DIM, false, 2.0)
	_text(r.position + Vector2(3, 13), InputSetup.key_hint("use_stim"), 11, UiTheme.BRASS)
	_text(Vector2(r.position.x, r.end.y - 3), "x%d" % GameState.stims, 12, col, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3)
