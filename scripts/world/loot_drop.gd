class_name LootDrop
extends Node2D
## An item lying on the floor. Equipment is picked up with Interact; ammo and
## stims are collected automatically by walking over them. The `entry`
## dictionary is shared with GameState.ground_items so it persists in saves.

var entry: Dictionary = {}
var interact_radius := 44.0
var t := 0.0
var pop := false
var pop_t := 0.0
var cv: IsoView
var lift_px := 0.0   # current pop height (read by LootLabels)

static var _font: Font


func _ready() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	t = randf() * 5.0
	cv = IsoView.attach(self)
	cv.z_index = -1   # lies on the floor, under actors
	if String(entry.get("kind", "")) == "item":
		add_to_group("interactable")
		add_to_group("loot")
		var r := int(entry["item"]["rarity"])
		if r >= ItemDB.RARITY_RARE:
			var l := PointLight2D.new()
			l.range_item_cull_mask = 3   # also lights the floor layer
			l.height = 150.0
			l.texture = LightUtil.radial(128)
			l.color = ItemDB.rarity_color(r)
			l.energy = 0.7
			l.texture_scale = 0.9
			l.scale = Vector2(1.0, 0.6)
			cv.add_child(l)


func interact_text() -> String:
	return "Pick up " + String(entry["item"]["name"])


func label_text() -> String:
	match String(entry.get("kind", "")):
		"item":
			return String(entry["item"]["name"])
		"ammo":
			return "%d %s" % [int(entry["amount"]), ItemDB.ammo_label(String(entry["ammo"]))]
		"stim":
			return "Stim-pack"
	return "?"


func color() -> Color:
	match String(entry.get("kind", "")):
		"item":
			return ItemDB.rarity_color(int(entry["item"]["rarity"]))
		"ammo":
			return Color(0.85, 0.75, 0.45)
		"stim":
			return Color(0.5, 1.0, 0.55)
	return Color.WHITE


func interact(_player: Node) -> void:
	if String(entry.get("kind", "")) != "item":
		return
	if GameState.add_item(entry["item"]):
		Events.msg("Picked up: " + String(entry["item"]["name"]), color())
		Audio.play_ui("pickup")
		for it in GameState.auto_equip():
			Events.msg("Equipped: %s (%s)" % [it["name"], ItemDB.slot_label(it)], ItemDB.rarity_color(int(it["rarity"])))
		_consume()


func _consume() -> void:
	GameState.ground_items.erase(entry)
	queue_free()


func _process(delta: float) -> void:
	t += delta
	if pop and pop_t < 0.35:
		pop_t += delta
	queue_redraw()
	var kind := String(entry.get("kind", ""))
	if kind == "item":
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or bool(p.get("dead")):
		return
	var d := p.global_position.distance_to(global_position)
	if d < 90.0 and d > 26.0:
		global_position = global_position.move_toward(p.global_position, delta * 160.0)
	if d <= 26.0:
		Audio.play_ui("pickup", 1.2, -3.0)
		if kind == "ammo":
			var a := String(entry["ammo"])
			GameState.ammo[a] = int(GameState.ammo.get(a, 0)) + int(entry["amount"])
			Events.msg("+%d %s" % [int(entry["amount"]), ItemDB.ammo_label(a)], color())
		elif kind == "stim":
			GameState.stims += int(entry.get("amount", 1))
			Events.msg("+%d stim-pack" % int(entry.get("amount", 1)), color())
		_consume()


func _render() -> void:
	var c := color()
	var lift := 0.0
	if pop and pop_t < 0.35:
		var f := pop_t / 0.35
		lift = -sin(f * PI) * 22.0
	var bob := sin(t * 3.0) * 1.5
	var base := Vector2(0, lift)
	lift_px = lift
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45))
	cv.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.4))
	cv.draw_set_transform(Vector2.ZERO)
	var kind := String(entry.get("kind", ""))
	if kind == "item":
		var r := int(entry["item"]["rarity"])
		if r >= ItemDB.RARITY_UNCOMMON:
			var beam_h := 30.0 + 25.0 * r
			cv.draw_rect(Rect2(-2, -beam_h, 4, beam_h), Color(c.r, c.g, c.b, 0.12 + 0.05 * sin(t * 4.0)))
		# rarity glow on the floor, then the item's silhouette lying on it
		Iso.ground(cv, base)
		cv.draw_circle(Vector2.ZERO, 11.0, Color(c.r, c.g, c.b, 0.12 + 0.04 * r))
		cv.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 20, Color(c.r, c.g, c.b, 0.35), 1.0)
		cv.draw_set_transform(Vector2.ZERO)
		ItemIcon.draw(cv, entry["item"], base + Vector2(0, -6 + bob), 0.85, c)
	elif kind == "ammo":
		var p2 := base + Vector2(0, -5 + bob)
		cv.draw_rect(Rect2(p2.x - 7, p2.y - 5, 14, 10), Color(0.25, 0.22, 0.12))
		cv.draw_rect(Rect2(p2.x - 7, p2.y - 5, 14, 10), c, false, 1.0)
	else:
		var p3 := base + Vector2(0, -5 + bob)
		cv.draw_rect(Rect2(p3.x - 6, p3.y - 6, 12, 12), Color(0.85, 0.85, 0.8))
		cv.draw_line(p3 + Vector2(-4, 0), p3 + Vector2(4, 0), Color(0.8, 0.1, 0.1), 2.5)
		cv.draw_line(p3 + Vector2(0, -4), p3 + Vector2(0, 4), Color(0.8, 0.1, 0.1), 2.5)

