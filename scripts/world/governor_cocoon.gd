class_name GovernorCocoon
extends StaticBody2D
## One of Last Water's governors, cocooned in brood resin in the Civic Hall.
## Interact to cut them free: a 1.5 s channel, interrupted if the operative is
## hurt or walks off (like Recall). Freed governors stay put, saved as flags.

const CUT_TIME := 1.5
const GOVERNORS := [
	{"name": "Governor Ada Calloway", "coat": Color(0.45, 0.2, 0.18), "thanks": "You came. I'd stopped believing anyone would."},
	{"name": "Marshal Eli Brandt", "coat": Color(0.38, 0.3, 0.2), "thanks": "Took you long enough, friend. Give me a rifle and point me at 'em."},
	{"name": "Treasurer Ruth Okafor", "coat": Color(0.22, 0.28, 0.36), "thanks": "Thank you. The treasury will remember this. I'll see to it personally."},
]

var index := 0
var interact_radius := 60.0
var cutting := 0.0
var t := 0.0
var _hp_at_start := 0.0
var cv: IsoView


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
	if cutting <= 0.0:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
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
	var g := gov()
	if not freed():
		# a resin pod with a person-shaped bulge, pulsing faintly
		var pulse := 1.0 + 0.04 * sin(t * 2.0)
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		cv.draw_circle(Vector2.ZERO, 16.0, Color(0.25, 0.22, 0.16, 0.6))
		cv.draw_set_transform(Vector2.ZERO)
		Shade.ball(cv, Vector2(0, -22), 13.0 * pulse, Color(0.46, 0.42, 0.32))
		Shade.ball(cv, Vector2(0, -36), 9.0 * pulse, Color(0.5, 0.46, 0.35))
		Shade.ball(cv, Vector2(1, -44), 5.5, Color(0.55, 0.5, 0.38))
		cv.draw_circle(Vector2(2, -45), 1.2, Color(0.15, 0.1, 0.08))                        # a face pressed to the resin
		for i in 4:
			cv.draw_line(Vector2(-12 + i * 8, -6), Vector2(-14 + i * 9, -48 + i * 4), Color(0.6, 0.62, 0.45, 0.35), 1.5)
		if cutting > 0.0:
			var k := 1.0 - cutting / CUT_TIME
			cv.draw_rect(Rect2(-16, -58, 32, 4), Color(0, 0, 0, 0.7))
			cv.draw_rect(Rect2(-16, -58, 32 * k, 4), Color(1.0, 0.8, 0.4))
		return
	# freed: torn pod behind, the governor sitting against the wall, exhausted
	Shade.ball(cv, Vector2(-6, -16), 10.0, Color(0.36, 0.33, 0.26))
	cv.draw_arc(Vector2(-6, -20), 12.0, PI * 0.9, PI * 2.1, 10, Color(0.5, 0.46, 0.35), 3.0)
	var coat: Color = g["coat"]
	Shade.limb(cv, Vector2(2, -10), Vector2(12, -2), 4.0, Color(0.2, 0.18, 0.16))
	Shade.poly(cv, PackedVector2Array([Vector2(-3, -28), Vector2(7, -28), Vector2(8, -8), Vector2(-4, -8)]), coat)
	Shade.ball(cv, Vector2(2, -33), 5.0, Color(0.62, 0.48, 0.4))
	if index == 1:
		cv.draw_line(Vector2(-5, -37), Vector2(9, -37), Color(0.3, 0.22, 0.14), 3.0)        # the Marshal's hat brim
		cv.draw_rect(Rect2(-1, -42, 6, 5), Color(0.3, 0.22, 0.14))
