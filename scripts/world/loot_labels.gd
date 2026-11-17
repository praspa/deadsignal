class_name LootLabels
extends Node2D
## Draws the names of equipment lying on the floor, Diablo II style: above the
## whole world, in rarity colour, stacked so they never overlap. Names show for
## items near the player, or for every item on screen while show_loot
## (Alt / L3) is held. The item the player would pick up is highlighted.

const RANGE := 230.0
const FS := 11

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 55


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var show_all := Input.is_action_pressed("show_loot")
	var drops: Array = []
	for n in get_tree().get_nodes_in_group("loot"):
		var d := n as LootDrop
		if d == null or d.cv == null:
			continue
		if Iso.cull_rect.size != Vector2.ZERO and not Iso.cull_rect.has_point(d.cv.position):
			continue
		var targeted: bool = p.interact_target == d
		if targeted or show_all or p.global_position.distance_to(d.global_position) < RANGE:
			drops.append(d)
	# targeted first, then front-to-back, so the most relevant names keep their spot
	drops.sort_custom(func(a: LootDrop, b: LootDrop) -> bool:
		var ta: bool = p.interact_target == a
		var tb: bool = p.interact_target == b
		if ta != tb:
			return ta
		return a.cv.position.y > b.cv.position.y)
	var taken: Array = []
	for d in drops:
		var c: Color = d.color()
		var targeted: bool = p.interact_target == d
		var label: String = d.label_text()
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var anchor: Vector2 = d.cv.position + Vector2(0, d.lift_px - 14)
		var r := Rect2(anchor.x - tw * 0.5 - 3, anchor.y - 21, tw + 6, 15)
		for i in 10:
			var hit := false
			for o in taken:
				if (o as Rect2).grow(1.0).intersects(r):
					hit = true
					break
			if not hit:
				break
			r.position.y -= 16.0
		taken.append(r)
		if r.end.y < anchor.y - 8:
			draw_line(Vector2(anchor.x, r.end.y), anchor, Color(c.r, c.g, c.b, 0.35), 1.0)
		draw_rect(r, Color(0, 0, 0, 0.82 if targeted else 0.65))
		if targeted:
			draw_rect(r, c, false, 1.0)
		draw_string(_font, Vector2(r.position.x + 3, r.end.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, c.lightened(0.3) if targeted else c)
