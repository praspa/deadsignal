class_name GovernorCocoon
extends StaticBody2D
## One of Last Water's governors, cocooned in brood resin in the Civic Hall.
## Interact to cut them free: a 1.5 s channel, interrupted if the operative is
## hurt or walks off (like Recall). Freed governors stay put, saved as flags.

const CUT_TIME := 1.5
const GOVERNORS := [
	{"name": "Governor Ada Calloway", "coat": Color(0.5, 0.16, 0.14), "skin": Color(0.78, 0.62, 0.52), "hair": Color(0.72, 0.72, 0.7),
		"thanks": "You came. I'd stopped believing anyone would."},
	{"name": "Marshal Eli Brandt", "coat": Color(0.45, 0.33, 0.2), "skin": Color(0.66, 0.48, 0.36), "hair": Color(0.35, 0.3, 0.26),
		"thanks": "Took you long enough, friend. Give me a rifle and point me at 'em."},
	{"name": "Treasurer Ruth Okafor", "coat": Color(0.2, 0.28, 0.42), "skin": Color(0.36, 0.24, 0.18), "hair": Color(0.1, 0.08, 0.07),
		"thanks": "Thank you. The treasury will remember this. I'll see to it personally."},
]
const S := 1.5   # governors are drawn larger than life so they read at a glance

var index := 0
var interact_radius := 60.0
var cutting := 0.0
var t := 0.0
var _hp_at_start := 0.0
var cv: IsoView
var light: PointLight2D
var near := false
static var _font: Font


func _ready() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	cs.shape = c
	add_child(cs)
	add_to_group("cocoon")
	cv = IsoView.attach(self)
	if _font == null:
		_font = ThemeDB.fallback_font
	light = PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.texture_scale = 1.4
	light.position = Vector2(0, -30)
	light.scale = Vector2(1.0, 0.6)
	cv.add_child(light)
	if not freed():
		add_to_group("interactable")


func flag() -> String:
	return "lastwater:gov_%d" % (index + 1)


func freed() -> bool:
	return GameState.has_flag(flag())


func gov() -> Dictionary:
	return GOVERNORS[clampi(index, 0, GOVERNORS.size() - 1)]


func interact_text() -> String:
	return "Cut %s free" % String(gov()["name"])


func interact(p: Node) -> void:
	if freed() or cutting > 0.0:
		return
	cutting = CUT_TIME
	_hp_at_start = float(p.get("hp"))
	Audio.play("chainblade", global_position, 0.8, -6.0)


func _process(delta: float) -> void:
	t += delta
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	near = pl != null and pl.global_position.distance_to(global_position) < 160.0
	if light != null:
		light.color = Color(0.75, 0.95, 0.6) if not freed() else Color(1.0, 0.85, 0.6)
		light.energy = (0.6 + 0.2 * sin(t * 2.0)) if not freed() else 0.7
	if cutting <= 0.0:
		return
	var p := pl
	if p == null or bool(p.get("dead")) or p.global_position.distance_to(global_position) > interact_radius + 20.0 \
			or float(p.get("hp")) < _hp_at_start - 0.5:
		cutting = 0.0
		Events.msg("Cutting interrupted.", Color(1.0, 0.55, 0.35))
		return
	cutting -= delta
	if cutting <= 0.0:
		free_governor()


func free_governor() -> void:
	cutting = 0.0
	GameState.set_flag(flag())
	remove_from_group("interactable")
	Fx.burst(get_parent(), Iso.sp(global_position, 20), Color(0.6, 0.55, 0.4), 18, 160.0)
	Audio.play("impact_flesh", global_position, 0.8)
	Events.msg("%s: \"%s\"" % [String(gov()["name"]), String(gov()["thanks"])], Color(0.95, 0.85, 0.6))
	var all_free := true
	for i in GOVERNORS.size():
		if not GameState.has_flag("lastwater:gov_%d" % (i + 1)):
			all_free = false
	if all_free:
		GameState.set_flag("lastwater:governors")


func _render() -> void:
	if not freed():
		_draw_cocoon()
	else:
		_draw_governor()
	if near:
		var nm := String(gov()["name"]) + ("" if freed() else "  (cocooned)")
		cv.draw_string(_font, Vector2(-100, -95), nm, HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color(0, 0, 0, 0.8))
		cv.draw_string(_font, Vector2(-100, -96), nm, HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color(0.95, 0.85, 0.6))


## A resin pod in the shape of a person, standing against the wall; the face
## shows through the resin, eyes moving. Cutting shows a progress bar.
func _draw_cocoon() -> void:
	var g := gov()
	var pulse := 1.0 + 0.03 * sin(t * 2.0)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	cv.draw_circle(Vector2.ZERO, 26.0, Color(0.22, 0.2, 0.14, 0.7))
	cv.draw_set_transform(Vector2.ZERO)
	var resin := Color(0.5, 0.46, 0.34)
	Shade.ball(cv, Vector2(0, -16) * S, 15.0 * S * pulse, resin.darkened(0.1))
	Shade.ball(cv, Vector2(0, -36) * S, 13.0 * S * pulse, resin)
	Shade.ball(cv, Vector2(1, -55) * S, 9.0 * S, resin.lightened(0.05))
	# the face pressed against the resin from inside
	var face := Vector2(2, -57) * S
	cv.draw_circle(face, 5.5 * S, Color(g["skin"]).darkened(0.25))
	var look := sin(t * 0.9) * 1.2
	cv.draw_circle(face + Vector2(-2.2 + look, -1) * S, 1.1 * S, Color(0.95, 0.95, 0.9))
	cv.draw_circle(face + Vector2(2.2 + look, -1) * S, 1.1 * S, Color(0.95, 0.95, 0.9))
	cv.draw_circle(face + Vector2(-2.2 + look, -1) * S, 0.6 * S, Color(0.1, 0.08, 0.06))
	cv.draw_circle(face + Vector2(2.2 + look, -1) * S, 0.6 * S, Color(0.1, 0.08, 0.06))
	cv.draw_arc(face + Vector2(0, 2.5) * S, 1.6 * S, 0, PI, 6, Color(0.25, 0.1, 0.08), 1.2)
	# a hand pressing out, resin strands, wet sheen
	Shade.ball(cv, Vector2(-9, -38) * S, 2.6 * S, Color(g["skin"]).darkened(0.3))
	for i in 5:
		cv.draw_line(Vector2(-14 + i * 7, -4) * S, Vector2(-16 + i * 8, -62 + i * 5) * S, Color(0.65, 0.66, 0.48, 0.35), 1.5)
	cv.draw_arc(Vector2(-4, -40) * S, 8.0 * S, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.18), 2.0)
	if cutting > 0.0:
		var k := 1.0 - cutting / CUT_TIME
		cv.draw_rect(Rect2(Vector2(-22, -80) * S, Vector2(44, 5) * S), Color(0, 0, 0, 0.75))
		cv.draw_rect(Rect2(Vector2(-22, -80) * S, Vector2(44 * k, 5) * S), Color(1.0, 0.8, 0.4))


## Freed: sitting against the wall beside the torn pod, exhausted but alive.
func _draw_governor() -> void:
	var g := gov()
	var coat: Color = g["coat"]
	var skin: Color = g["skin"]
	var hair: Color = g["hair"]
	var breathe := sin(t * 1.4) * 0.6
	# the torn pod behind them
	Shade.ball(cv, Vector2(-14, -20) * S, 11.0 * S, Color(0.34, 0.31, 0.24))
	cv.draw_arc(Vector2(-14, -26) * S, 13.0 * S, PI * 0.85, PI * 2.15, 12, Color(0.52, 0.48, 0.36), 3.0)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	cv.draw_circle(Vector2(4, 0) * S, 16.0 * S, Color(0, 0, 0, 0.4))
	cv.draw_set_transform(Vector2.ZERO)
	# legs stretched out in front, boots / shoes
	var hip := Vector2(0, -10) * S
	for side in [-1.0, 1.0]:
		var knee := hip + Vector2(9 + side * 2, 2 + side * 2) * S
		var foot := knee + Vector2(9, 5 + side) * S
		Shade.limb(cv, hip + Vector2(side * 2.5, 0) * S, knee, 3.4 * S, coat.darkened(0.35))
		Shade.limb(cv, knee, foot, 3.0 * S, coat.darkened(0.4))
		Shade.ball(cv, foot + Vector2(1.5, 0) * S, 2.4 * S, Color(0.12, 0.1, 0.08))
	# torso, leaning back against the wall
	var sh := hip + Vector2(-3, -17 + breathe) * S
	var body := PackedVector2Array([sh + Vector2(-7, 0) * S, sh + Vector2(7, 0) * S, hip + Vector2(6, 2) * S, hip + Vector2(-6, 2) * S])
	Shade.poly(cv, body, coat)
	cv.draw_line(sh + Vector2(0, 1) * S, hip + Vector2(0, 1) * S, coat.darkened(0.3), 1.0)            # coat opening
	match index:
		0:  # Governor: white collar, gold chain of office
			cv.draw_colored_polygon(PackedVector2Array([sh + Vector2(-4, 0) * S, sh + Vector2(4, 0) * S, sh + Vector2(0, 5) * S]), Color(0.9, 0.88, 0.82))
			cv.draw_polyline(PackedVector2Array([sh + Vector2(-6, 1) * S, sh + Vector2(0, 8) * S, sh + Vector2(6, 1) * S]), Color(0.9, 0.72, 0.3), 1.5)
			cv.draw_circle(sh + Vector2(0, 8.5) * S, 1.8 * S, Color(0.95, 0.78, 0.35))
		1:  # Marshal: star badge, gun belt
			var st := sh + Vector2(-3.5, 5) * S
			for k in 5:
				cv.draw_line(st, st + Vector2.from_angle(-PI * 0.5 + k * TAU / 5.0) * 2.6 * S, Color(0.9, 0.8, 0.45), 1.5)
			cv.draw_rect(Rect2(hip + Vector2(-6, -2) * S, Vector2(12, 2) * S), Color(0.25, 0.17, 0.1))
			cv.draw_rect(Rect2(hip + Vector2(3, -2) * S, Vector2(3, 5) * S), Color(0.2, 0.14, 0.09))
		2:  # Treasurer: clutching the ledger
			cv.draw_rect(Rect2(sh + Vector2(-5, 5) * S, Vector2(9, 7) * S), Color(0.35, 0.18, 0.12))
			cv.draw_line(sh + Vector2(-5, 8.5) * S, sh + Vector2(4, 8.5) * S, Color(0.9, 0.82, 0.6), 1.0)
	# arms resting in the lap / on the ledger
	for side in [-1.0, 1.0]:
		var s0 := sh + Vector2(side * 6.5, 1) * S
		var hand := hip + Vector2(3 + side * 4, -3) * S
		Shade.limb(cv, s0, s0.lerp(hand, 0.5) + Vector2(side * 2, 0) * S, 2.6 * S, coat.darkened(0.1))
		Shade.limb(cv, s0.lerp(hand, 0.5) + Vector2(side * 2, 0) * S, hand, 2.4 * S, coat.darkened(0.1))
		Shade.ball(cv, hand, 1.8 * S, skin)
	# head: neck, face, hair, features
	var head := sh + Vector2(0.5, -7.5) * S
	Shade.limb(cv, sh + Vector2(0, 1) * S, head + Vector2(0, 3) * S, 2.2 * S, skin.darkened(0.15))
	Shade.ball(cv, head, 5.2 * S, skin)
	match index:
		0:  # grey hair in a bun
			cv.draw_arc(head + Vector2(0, -1) * S, 5.2 * S, PI * 1.05, TAU * 0.97, 12, hair, 2.6 * S)
			Shade.ball(cv, head + Vector2(-3.5, -4.5) * S, 2.4 * S, hair)
		1:  # wide-brimmed hat, moustache
			cv.draw_line(head + Vector2(-9, -3.5) * S, head + Vector2(9, -3.5) * S, Color(0.32, 0.23, 0.14), 2.2 * S)
			cv.draw_rect(Rect2(head + Vector2(-5, -9.5) * S, Vector2(10, 6) * S), Color(0.34, 0.25, 0.15))
			cv.draw_line(head + Vector2(-2.5, 2) * S, head + Vector2(2.5, 2) * S, hair, 1.6 * S)
		2:  # close-cropped hair, round glasses
			cv.draw_arc(head + Vector2(0, -0.5) * S, 5.2 * S, PI * 1.1, TAU * 0.95, 12, hair, 1.8 * S)
			for gx in [-2.0, 2.0]:
				cv.draw_arc(head + Vector2(gx, 0) * S, 1.6 * S, 0, TAU, 10, Color(0.75, 0.75, 0.72), 1.0)
	# eyes (tired, half closed) and mouth
	for ex in [-2.0, 2.0]:
		cv.draw_line(head + Vector2(ex - 0.8, 0) * S, head + Vector2(ex + 0.8, 0) * S, Color(0.12, 0.08, 0.06), 1.2)
	cv.draw_line(head + Vector2(-1.2, 2.8) * S, head + Vector2(1.2, 2.8) * S, skin.darkened(0.45), 1.0)
	# dirt / resin smears: they've been through it
	cv.draw_circle(sh + Vector2(4, 4) * S, 2.0 * S, Color(0.4, 0.38, 0.28, 0.5))

