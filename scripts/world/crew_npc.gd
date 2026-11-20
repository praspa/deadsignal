class_name CrewNpc
extends StaticBody2D
## A member of the ship's crew: drawn with their own look, prop and idle
## animation (requirements 15.2.6). Interacting opens the crew screen with their
## services; walking past them the first time in a visit gets a one-line bark.
## Data (names, lines, services) in data/crew.json.

const NAME_RANGE := 90.0
const BARK_RANGE := 120.0

var crew_id := "Q"
var data: Dictionary = {}
var interact_radius := 60.0
var t := 0.0
var talk_t := 0.0          # > 0: turned toward the operative after being spoken to
var face := -1.0           # -1 faces screen-left, 1 screen-right
var barked := false
var near := false
var cv: IsoView
var light: PointLight2D

static var _font: Font


func setup(p_id: String, pos: Vector2) -> void:
	crew_id = p_id
	data = ItemDB.crew.get(p_id, {})
	position = pos


func _ready() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	add_to_group("interactable")
	add_to_group("crew")
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	cs.shape = c
	add_child(cs)
	cv = IsoView.attach(self)
	t = randf() * 10.0
	face = {"Q": -1.0, "T": 1.0, "M": -1.0, "F": -1.0, "P": 1.0}.get(crew_id, -1.0)
	light = PointLight2D.new()
	light.range_item_cull_mask = 3
	light.height = 150.0
	light.texture = LightUtil.radial(128)
	light.energy = 0.45
	light.texture_scale = 0.8
	light.scale = Vector2(1.0, 0.6)
	light.position = Vector2(0, -30)
	light.color = {"Q": Color(1.0, 0.75, 0.4), "T": Color(0.3, 1.0, 0.85), "M": Color(0.9, 0.95, 1.0),
		"F": Color(0.85, 0.5, 1.0), "P": Color(1.0, 0.7, 0.25)}.get(crew_id, Color.WHITE)
	cv.add_child(light)


func display_name() -> String:
	return String(data.get("name", "Crew"))


func title() -> String:
	return String(data.get("title", ""))


func interact_text() -> String:
	return "Talk to %s (%s)" % [display_name(), title()]


func interact(p: Node) -> void:
	talk_t = 6.0
	_face_toward((p as Node2D).global_position)
	Events.open_crew.emit(crew_id)


## A line for the crew screen: general lines plus any unlocked by progress.
## The line goes in the journal: under the mission whose progress unlocked it
## (a "kessar:queen" line -> The Brood of Kessar), otherwise under the crew.
func line() -> String:
	var pool: Array = []   # [line, journal tag]
	for l in data.get("lines", []):
		pool.append([String(l), "crew"])
	var after: Dictionary = data.get("lines_after", {})
	for f in after:
		if GameState.has_flag(String(f)):
			var mid := String(f).get_slice(":", 0)
			var tag := mid if ItemDB.missions.has(mid) else "crew"
			# progress lines are fresher: weight them up
			for i in 3:
				for l in after[f]:
					pool.append([String(l), tag])
	if pool.is_empty():
		return "..."
	var pick: Array = pool.pick_random()
	GameState.journal_log("%s: \"%s\"" % [display_name(), pick[0]], pick[1])
	return String(pick[0])


func _face_toward(p: Vector2) -> void:
	var sx := Iso.to_screen(p - global_position).x
	if absf(sx) > 2.0:
		face = signf(sx)


func _process(delta: float) -> void:
	t += delta
	talk_t = maxf(0.0, talk_t - delta)
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl != null:
		var d := pl.global_position.distance_to(global_position)
		near = d < NAME_RANGE
		if talk_t > 0.0:
			_face_toward(pl.global_position)
		if not barked and d < BARK_RANGE:
			barked = true   # once per visit: a new Game builds new crew
			var b := String(data.get("bark", ""))
			if b != "":
				Events.msg("%s: \"%s\"" % [display_name(), b], Color(0.85, 0.78, 0.6))
				GameState.journal_log("%s: \"%s\"" % [display_name(), b], "crew")
	if light != null:
		light.energy = 0.45 + (0.15 * sin(t * 3.0) if crew_id == "T" else 0.0)


# ---------------------------------------------------------------- drawing

func _render() -> void:
	match crew_id:
		"Q":
			_draw_dov()
		"T":
			_draw_ines()
		"M":
			_draw_oskar()
		"F":
			_draw_kesh()
		"P":
			_draw_mara()
	if near:
		var nm := display_name()
		var top := -78.0 if crew_id == "M" else (-70.0 if crew_id == "F" else -62.0)
		cv.draw_string(_font, Vector2(-80, top + 1), nm, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0, 0, 0, 0.8))
		cv.draw_string(_font, Vector2(-80, top), nm, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.95, 0.85, 0.6))


func _shadow(r: float) -> void:
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45))
	cv.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.45))
	cv.draw_set_transform(Vector2.ZERO)


## Shared figure: legs, torso, shoulders, head. Returns {head, sh_l, sh_r, chest}.
## `h` = head height above the feet, `w` = half shoulder width.
func _figure(base: Vector2, h: float, w: float, legs: Color, torso: Color, skin: Color, breathe: float) -> Dictionary:
	var hip := base + Vector2(0, -h * 0.42)
	Shade.limb(cv, hip + Vector2(-w * 0.35, 0), base + Vector2(-w * 0.4, 0), w * 0.42, legs)
	Shade.limb(cv, hip + Vector2(w * 0.35, 0), base + Vector2(w * 0.4, 0), w * 0.42, legs)
	var sh := base + Vector2(0, -h * 0.78 + breathe)
	var body := PackedVector2Array([sh + Vector2(-w, 0), sh + Vector2(w, 0), hip + Vector2(w * 0.8, 2), hip + Vector2(-w * 0.8, 2)])
	Shade.poly(cv, body, torso)
	var head := base + Vector2(face * 1.5, -h + breathe)
	Shade.ball(cv, head, w * 0.62, skin)
	return {"head": head, "sh_l": sh + Vector2(-w, 2), "sh_r": sh + Vector2(w, 2), "hip": hip, "chest": sh.lerp(hip, 0.35)}


func _arm(s0: Vector2, hand: Vector2, thick: float, c: Color, glove: Color) -> void:
	var elbow := s0.lerp(hand, 0.5) + Vector2(face * 2.0, 3.0)
	Shade.limb(cv, s0, elbow, thick, c)
	Shade.limb(cv, elbow, hand, thick * 0.9, c)
	Shade.ball(cv, hand, thick * 0.5, glove)


## Dov Harrow: short, barrel-wide, mutton chops, oily apron, hydraulic brass arm,
## unlit cigar; counts stock and knocks on his crate counter for luck.
func _draw_dov() -> void:
	var leather := Color(0.36, 0.25, 0.15)
	var shirt := Color(0.3, 0.28, 0.24)
	var brass := Color(0.62, 0.48, 0.24)
	var skin := Color(0.62, 0.47, 0.38)
	_shadow(14.0)
	var breathe := sin(t * 1.4) * 0.8
	var f := _figure(Vector2.ZERO, 34.0, 11.0, Color(0.2, 0.19, 0.17), shirt, skin, breathe)
	# apron with tool loops
	var ap := PackedVector2Array([f["chest"] + Vector2(-8, -2), f["chest"] + Vector2(8, -2), f["hip"] + Vector2(9, 8), f["hip"] + Vector2(-9, 8)])
	Shade.poly(cv, ap, leather)
	cv.draw_line(f["hip"] + Vector2(-6, 2), f["hip"] + Vector2(6, 2), Color(0.25, 0.25, 0.27), 2.0)
	cv.draw_line(f["hip"] + Vector2(4, 2), f["hip"] + Vector2(5, 7), Color(0.55, 0.55, 0.58), 1.5)   # spanner
	cv.draw_rect(Rect2(f["hip"] + Vector2(-9 * face, 0), Vector2(3, 5)), Color(0.6, 0.15, 0.1))     # red rag
	# flesh arm holds the dataslate; brass arm knocks on the crate every few seconds
	var knock := fmod(t, 5.0)
	var kd := -absf(sin(knock * 18.0)) * 4.0 if knock < 0.35 else 0.0
	var slate: Vector2 = f["chest"] + Vector2(6 * face, 4)
	_arm(f["sh_r"] if face > 0 else f["sh_l"], slate, 4.5, shirt, skin)
	cv.draw_rect(Rect2(slate + Vector2(-4, -6), Vector2(8, 6)), Color(0.12, 0.14, 0.13))
	cv.draw_rect(Rect2(slate + Vector2(-3, -5), Vector2(6, 3)), Color(0.4, 0.9, 0.6, 0.6))
	var mech_sh: Vector2 = f["sh_l"] if face > 0 else f["sh_r"]
	var fist := Vector2(-10 * face, -16 + kd)
	cv.draw_line(mech_sh, mech_sh.lerp(fist, 0.5), brass.darkened(0.2), 5.0)
	cv.draw_line(mech_sh.lerp(fist, 0.5), fist, brass, 4.0)
	cv.draw_circle(mech_sh.lerp(fist, 0.5), 2.5, Color(0.25, 0.22, 0.18))   # piston joint
	Shade.ball(cv, fist, 3.5, brass.lightened(0.1))
	if fmod(t, 3.3) < 0.5:
		cv.draw_circle(mech_sh.lerp(fist, 0.5) + Vector2(0, -5 - fmod(t, 3.3) * 14.0), 2.5 + fmod(t, 3.3) * 4.0, Color(0.85, 0.85, 0.85, 0.25))   # steam
	# head: bald scarred scalp, grey mutton chops, cigar
	var hd: Vector2 = f["head"]
	cv.draw_line(hd + Vector2(-3, -5), hd + Vector2(2, -3), skin.darkened(0.3), 1.0)
	for sx in [-1.0, 1.0]:
		Shade.ball(cv, hd + Vector2(sx * 5.5, 2.5), 3.0, Color(0.62, 0.6, 0.56))
	cv.draw_line(hd + Vector2(4 * face, 3), hd + Vector2(10 * face, 4), Color(0.35, 0.22, 0.12), 2.5)
	cv.draw_circle(hd + Vector2(2 * face, -1), 1.0, Color(0.1, 0.08, 0.07))
	# his crate counter, in front of him; votive candle and tally marks on top
	Iso.box(cv, Vector2(12, 12), Vector2(13, 5), 17.0, Color(0.34, 0.31, 0.24), Color(0.27, 0.24, 0.18), Color(0.19, 0.17, 0.13), Color(0.45, 0.4, 0.28))
	var top := Iso.to_screen(Vector2(12, 12)) + Vector2(0, -17)
	cv.draw_circle(top + Vector2(-9, -2), 1.8, Color(1.0, 0.8, 0.4, 0.6 + 0.4 * sin(t * 9.0)))
	cv.draw_rect(Rect2(top + Vector2(-10, -1), Vector2(2, 3)), Color(0.8, 0.75, 0.6))
	for i in 4:
		cv.draw_line(top + Vector2(2 + i * 2.0, 2), top + Vector2(2 + i * 2.0, 8), Color(0.75, 0.7, 0.6, 0.7), 1.0)


## Ines Ruhl: thin and sleepless, huge headphones wired into her skull,
## backpack decoder rig of blinking boards, teal hair, drumming fingers.
func _draw_ines() -> void:
	var hoodie := Color(0.33, 0.33, 0.35)
	var vest := Color(0.22, 0.27, 0.27)
	var teal := Color(0.2, 0.75, 0.72)
	var skin := Color(0.72, 0.64, 0.6)
	# decoder bank she's hunched over
	Iso.box(cv, Vector2(12 * face, 2), Vector2(7, 10), 22.0, Color(0.2, 0.22, 0.24), Color(0.15, 0.16, 0.18), Color(0.1, 0.11, 0.12))
	for i in 3:
		var ly := -10.0 - i * 5.0
		var ln := 4.0 + fmod(t * 6.0 + i * 2.0, 6.0)
		cv.draw_line(Vector2(14 * face - 3, ly), Vector2(14 * face - 3 + ln * face, ly + sin(t * 8.0 + i) * 1.5), Color(0.3, 1.0, 0.7, 0.85), 1.0)
	# stool
	cv.draw_line(Vector2(-4, 0), Vector2(-2, -12), Color(0.3, 0.3, 0.32), 2.0)
	cv.draw_line(Vector2(4, 0), Vector2(2, -12), Color(0.3, 0.3, 0.32), 2.0)
	_shadow(11.0)
	var flinch := 2.0 if fmod(t, 7.0) < 0.15 else 0.0
	var f := _figure(Vector2(0, -8), 32.0, 7.5, Color(0.18, 0.18, 0.2), hoodie, skin, sin(t * 2.2) * 0.6 - flinch)
	var vp := PackedVector2Array([f["chest"] + Vector2(-6, -4), f["chest"] + Vector2(6, -4), f["hip"] + Vector2(6, 0), f["hip"] + Vector2(-6, 0)])
	Shade.poly(cv, vp, vest)
	# backpack rig with blinking LEDs, cables to the headphones
	var pack: Vector2 = f["chest"] + Vector2(-8 * face, -2)
	Iso.box(cv, pack, Vector2(4, 4), 12.0, Color(0.25, 0.27, 0.3), Color(0.18, 0.2, 0.22), Color(0.12, 0.13, 0.15), Color(0, 0, 0, 0), 0.0)
	for i in 3:
		var on := int(t * 4.0 + i) % 3 != 0
		cv.draw_circle(pack + Vector2(-2 + i * 2.0, -8), 1.0, Color(0.3, 1.0, 0.6) if on else Color(0.1, 0.3, 0.2))
	# arms reaching to the dials, fingers drumming
	var dial: Vector2 = Vector2(9 * face, -22) + Vector2(0, sin(t * 14.0) * 1.0)
	_arm(f["sh_r"] if face > 0 else f["sh_l"], dial, 3.5, hoodie, skin)
	_arm(f["sh_l"] if face > 0 else f["sh_r"], dial + Vector2(-4 * face, 3 + sin(t * 11.0) * 1.0), 3.5, hoodie, skin)
	# head: messy teal hair, goggles up, big headphones + skull-port cable
	var hd: Vector2 = f["head"]
	for i in 5:
		cv.draw_circle(hd + Vector2(-4 + i * 2.0, -4 - (i % 2)), 2.5, teal)
	cv.draw_rect(Rect2(hd + Vector2(-5, -6), Vector2(10, 2.5)), Color(0.15, 0.15, 0.16))
	cv.draw_circle(hd + Vector2(-3, -5), 1.5, Color(0.5, 0.7, 0.8))
	cv.draw_circle(hd + Vector2(3, -5), 1.5, Color(0.5, 0.7, 0.8))
	cv.draw_arc(hd + Vector2(0, -1), 6.5, PI, TAU, 10, Color(0.12, 0.12, 0.13), 2.0)
	for sx in [-1.0, 1.0]:
		Shade.ball(cv, hd + Vector2(sx * 6.0, 0), 3.2, Color(0.18, 0.18, 0.2))
	cv.draw_polyline(PackedVector2Array([hd + Vector2(-6 * face, 2), pack + Vector2(0, -12), pack + Vector2(-1, -10)]), Color(0.1, 0.1, 0.1), 1.0)
	cv.draw_circle(hd + Vector2(2.5 * face, 1), 0.9, Color(0.1, 0.1, 0.12))


## Oskar Venn: very tall, gaunt and stooped, half-moon spectacles, stained
## surgical coat, faded red-cross armband; polishes a bone saw, sips "antiseptic".
func _draw_oskar() -> void:
	var coat := Color(0.52, 0.51, 0.47)
	var skin := Color(0.6, 0.5, 0.45)
	# instrument tray on a stand
	cv.draw_line(Vector2(12 * face, 0), Vector2(12 * face, -22), Color(0.4, 0.42, 0.45), 1.5)
	cv.draw_rect(Rect2(Vector2(12 * face - 6, -24), Vector2(12, 3)), Color(0.55, 0.58, 0.62))
	for i in 3:
		cv.draw_line(Vector2(12 * face - 4 + i * 3, -25), Vector2(12 * face - 3 + i * 3, -28), Color(0.8, 0.82, 0.85), 1.0)
	_shadow(11.0)
	var f := _figure(Vector2.ZERO, 50.0, 8.0, Color(0.2, 0.2, 0.22), coat, skin, sin(t * 1.1) * 0.6)
	# long coat skirt with old stains, armband
	var skirt := PackedVector2Array([f["hip"] + Vector2(-8, -2), f["hip"] + Vector2(8, -2), Vector2(9, -8), Vector2(-9, -8)])
	Shade.poly(cv, skirt, coat.darkened(0.05))
	cv.draw_circle(f["chest"] + Vector2(3, 6), 1.8, Color(0.36, 0.22, 0.14, 0.5))
	cv.draw_circle(f["hip"] + Vector2(-4, 7), 1.5, Color(0.36, 0.22, 0.14, 0.45))
	var band: Vector2 = (f["sh_l"] as Vector2).lerp(f["hip"], 0.3) + Vector2(-2, 0)
	cv.draw_rect(Rect2(band - Vector2(2, 2), Vector2(4, 4)), Color(0.55, 0.18, 0.15))
	# polishing a bone saw; every so often a nip from the flask
	var sip := fmod(t, 9.0) < 1.2
	var hand_a: Vector2 = f["chest"] + Vector2(7 * face, 6 + sin(t * 5.0) * 1.5)
	var hand_b: Vector2 = (f["head"] as Vector2) + Vector2(3 * face, 6) if sip else hand_a + Vector2(-5 * face, 2)
	_arm(f["sh_r"] if face > 0 else f["sh_l"], hand_a, 3.5, coat, Color(0.85, 0.82, 0.7))
	_arm(f["sh_l"] if face > 0 else f["sh_r"], hand_b, 3.5, coat, Color(0.85, 0.82, 0.7))
	cv.draw_line(hand_a, hand_a + Vector2(9 * face, -3), Color(0.8, 0.82, 0.86), 2.0)   # saw blade
	for i in 3:
		cv.draw_line(hand_a + Vector2((3 + i * 2) * face, -1 - i * 0.6), hand_a + Vector2((3 + i * 2) * face, 1 - i * 0.6), Color(0.6, 0.62, 0.66), 1.0)
	if sip:
		cv.draw_rect(Rect2(hand_b + Vector2(-2, -4), Vector2(4, 6)), Color(0.55, 0.58, 0.6))   # flask
	# head: long grey hair, half-moon spectacles low on the nose
	var hd: Vector2 = f["head"]
	cv.draw_line(hd + Vector2(-3 * face, -2), hd + Vector2(-6 * face, 8), Color(0.6, 0.6, 0.6), 2.5)
	cv.draw_arc(hd + Vector2(0, -2), 5.0, PI, TAU, 10, Color(0.62, 0.62, 0.6), 2.0)
	cv.draw_arc(hd + Vector2(2.5 * face, 1.5), 2.0, 0, PI, 6, Color(0.85, 0.85, 0.75), 1.0)
	cv.draw_arc(hd + Vector2(-0.5 * face, 1.5), 2.0, 0, PI, 6, Color(0.85, 0.85, 0.75), 1.0)


## Kesh: a small T'sa in a swamp of purple coats with too many pockets, gold
## rings, a clicking monocle scanner; perched on sealed crates, never still.
func _draw_kesh() -> void:
	var coat := Color(0.36, 0.16, 0.4)
	var scales := Color(0.42, 0.5, 0.32)
	var gold := Color(0.85, 0.68, 0.25)
	# stack of sealed crates he perches on
	Iso.box(cv, Vector2(0, 2), Vector2(12, 10), 14.0, Color(0.32, 0.3, 0.26), Color(0.25, 0.23, 0.2), Color(0.17, 0.16, 0.13), Color(0.5, 0.42, 0.25))
	Iso.box(cv, Vector2(1, 1), Vector2(9, 8), 10.0, Color(0.36, 0.33, 0.28), Color(0.28, 0.26, 0.21), Color(0.2, 0.18, 0.15), Color(0.5, 0.42, 0.25), 14.0)
	cv.draw_line(Vector2(-6, -18), Vector2(6, -18), Color(0.7, 0.2, 0.15), 1.5)   # SEALED tape
	_shadow(14.0)
	var fidget := sin(t * 7.0) * 1.2
	var base := Vector2(fidget * 0.3, -24)
	var f := _figure(base, 22.0, 7.0, scales.darkened(0.2), coat, scales, sin(t * 3.0) * 0.6)
	# layered coat tails and pockets
	var tail := PackedVector2Array([f["hip"] + Vector2(-7, -2), f["hip"] + Vector2(7, -2), base + Vector2(8, 6), base + Vector2(-8, 6)])
	Shade.poly(cv, tail, coat.darkened(0.1))
	for i in 3:
		cv.draw_rect(Rect2((f["chest"] as Vector2) + Vector2(-5 + i * 3.5, 3 + (i % 2) * 3), Vector2(2.5, 2)), coat.lightened(0.2))
	# reptile tail flicking out from under the coat
	var tl := base + Vector2(-6 * face, 3)
	cv.draw_polyline(PackedVector2Array([tl, tl + Vector2(-6 * face, 4), tl + Vector2(-11 * face, 3 + sin(t * 6.0) * 3.0)]), scales, 2.5)
	# hands: one twisting a ring
	var h1: Vector2 = f["chest"] + Vector2(5 * face, 4)
	var h2: Vector2 = h1 + Vector2(-3 * face, 1 + fidget)
	_arm(f["sh_r"] if face > 0 else f["sh_l"], h1, 2.8, coat, scales)
	_arm(f["sh_l"] if face > 0 else f["sh_r"], h2, 2.8, coat, scales)
	cv.draw_circle(h1, 1.5, gold)
	cv.draw_circle(h2 + Vector2(1, 0), 1.3, gold)
	# head: snout, big glossy eyes, monocle scanner that zooms
	var hd: Vector2 = f["head"]
	Shade.ball(cv, hd + Vector2(4 * face, 1.5), 3.0, scales.lightened(0.05))
	cv.draw_circle(hd + Vector2(1 * face, -1), 2.0, Color(0.1, 0.08, 0.06))
	cv.draw_circle(hd + Vector2(1.5 * face, -1.5), 0.7, Color(1, 1, 1, 0.8))
	var zoom := 2.0 + 0.8 * sin(t * 2.5)
	cv.draw_arc(hd + Vector2(-2 * face, -1), zoom, 0, TAU, 10, gold, 1.2)
	cv.draw_circle(hd + Vector2(-2 * face, -1), zoom * 0.5, Color(0.8, 0.3, 1.0, 0.6))


## Mara Quill: slouched in the pilot's chair, boots up on the console, patched
## flight jacket, glowing amber cybernetic eye; flips a coin without looking.
func _draw_mara() -> void:
	var jacket := Color(0.33, 0.35, 0.22)
	var skin := Color(0.6, 0.45, 0.36)
	# pilot's chair
	Iso.box(cv, Vector2(0, 2), Vector2(9, 8), 12.0, Color(0.3, 0.28, 0.26), Color(0.22, 0.2, 0.18), Color(0.15, 0.14, 0.13))
	cv.draw_rect(Rect2(Vector2(-9 * face - 3, -34), Vector2(6, 22)), Color(0.25, 0.23, 0.21))   # backrest
	_shadow(12.0)
	var breathe := sin(t * 1.3) * 0.6
	# seated: torso leaning back, legs stretched toward the console
	var hip := Vector2(-2 * face, -14)
	var sh := hip + Vector2(-5 * face, -15 + breathe)
	var foot := Vector2(16 * face, -18)
	Shade.limb(cv, hip, hip.lerp(foot, 0.55) + Vector2(0, -3), 4.5, Color(0.2, 0.2, 0.18))
	Shade.limb(cv, hip.lerp(foot, 0.55) + Vector2(0, -3), foot, 4.0, Color(0.2, 0.2, 0.18))
	Shade.ball(cv, foot + Vector2(2 * face, 0), 3.5, Color(0.15, 0.12, 0.1))   # boots
	var body := PackedVector2Array([sh + Vector2(-7, 0), sh + Vector2(7, 0), hip + Vector2(6, 2), hip + Vector2(-6, 2)])
	Shade.poly(cv, body, jacket)
	for i in 4:
		var pc: Color = [Color(0.6, 0.15, 0.1), Color(0.2, 0.3, 0.6), Color(0.75, 0.6, 0.2), Color(0.5, 0.5, 0.5)][i]
		cv.draw_rect(Rect2(sh.lerp(hip, 0.25 + i * 0.15) + Vector2(-5 + (i % 2) * 6, 0), Vector2(3, 3)), pc)   # mismatched patches
	# coin flip: up, spin, caught
	var ft := fmod(t, 4.0)
	var hand := sh + Vector2(8 * face, 6)
	var coin_y := -sin(clampf(ft / 0.8, 0.0, 1.0) * PI) * 16.0 if ft < 0.8 else 0.0
	_arm(sh + Vector2(6 * face, 1), hand, 3.5, jacket, skin)
	cv.draw_set_transform(hand + Vector2(0, -3 + coin_y), 0.0, Vector2(absf(cos(t * 20.0)) * 0.8 + 0.2, 1.0))
	cv.draw_circle(Vector2.ZERO, 2.0, Color(0.85, 0.7, 0.3))
	cv.draw_set_transform(Vector2.ZERO)
	_arm(sh + Vector2(-6 * face, 1), hip + Vector2(-2 * face, -2), 3.5, jacket, skin)
	# head: cropped dark hair with a shaved stripe, glowing amber cyber-eye, chewing
	var hd := sh + Vector2(1 * face, -8)
	Shade.ball(cv, hd, 5.0, skin)
	cv.draw_arc(hd + Vector2(0, -1), 5.0, PI * 1.05, TAU * 0.98, 10, Color(0.12, 0.1, 0.09), 2.5)
	cv.draw_line(hd + Vector2(-1, -5), hd + Vector2(1, -5), skin.lightened(0.1), 1.0)
	var eye := hd + Vector2(2.5 * face, -0.5)
	cv.draw_circle(eye, 1.8, Color(1.0, 0.65, 0.15))
	cv.draw_circle(eye, 3.0 + 0.4 * sin(t * 4.0), Color(1.0, 0.6, 0.1, 0.25))
	cv.draw_line(hd + Vector2(1 * face, 3 + sin(t * 6.0) * 0.4), hd + Vector2(3 * face, 3), Color(0.3, 0.15, 0.12), 1.0)
