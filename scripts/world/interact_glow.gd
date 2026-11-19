class_name InteractGlow
## Soft glow marking something the player can open or loot (crates, strongboxes,
## and any future container). Two parts:
##   - a small pulsing light, so the object reads in the dark outpost
##   - a faint halo on the floor and a rim along the object's top, drawn by the
##     object's own _render via draw_halo()
## Remove the light (light.queue_free()) once the object has been looted.

const COLOR := Color(1.0, 0.78, 0.42)
const ENERGY := 0.55
const PULSE := 1.6   # seconds per breath


## Adds the pulsing light under `view` (the object's IsoView), `height` px up.
static func attach(view: Node2D, height: float = 14.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = LightUtil.radial(64)
	l.texture_scale = 1.3
	l.scale = Vector2(1.0, 0.6)
	l.position = Vector2(0, -height)
	l.color = COLOR
	l.energy = ENERGY
	l.height = 40.0
	l.range_item_cull_mask = 3   # the object, nearby actors and the floor
	l.shadow_enabled = false
	view.add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", ENERGY * 0.45, PULSE * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "energy", ENERGY, PULSE * 0.5).set_trans(Tween.TRANS_SINE)
	return l


## Floor halo around a box footprint `half` (world units) and a glowing rim
## along its lid at `top` px above the floor.
static func draw_halo(ci: CanvasItem, half: Vector2, top: float) -> void:
	Iso.ground(ci)
	var r := maxf(half.x, half.y) + 7.0
	ci.draw_circle(Vector2.ZERO, r, Color(COLOR.r, COLOR.g, COLOR.b, 0.07))
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(COLOR.r, COLOR.g, COLOR.b, 0.28), 1.2)
	ci.draw_set_transform(Vector2.ZERO)
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var rim := PackedVector2Array()
	for c in corners:
		rim.append(Iso.to_screen(c) - Vector2(0, top))
	rim.append(rim[0])
	ci.draw_polyline(rim, Color(COLOR.r, COLOR.g, COLOR.b, 0.55), 1.2)
