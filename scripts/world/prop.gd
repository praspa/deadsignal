class_name Prop
extends StaticBody2D
## Static environment pieces drawn procedurally:
##  o obstacle (crates/barrels/cogitator bank)   p gothic pillar
##  g generator machinery   t specimen tank   l lamp post (light)
##  v steam vent   z sparking conduit
##  i boulder (Kessar)   j resin growth (decor)   f glowing fungus (light)

var level: Level
var cell := Vector2i.ZERO
var kind := "o"
var variant := 0
var light: PointLight2D
var powered := false
var t := 0.0
var flicker := 1.0
var cv: IsoView

const T := 32


func setup(p_level: Level, p_cell: Vector2i, p_kind: String) -> void:
	level = p_level
	cell = p_cell
	kind = p_kind
	variant = Level.hash2(cell.x, cell.y) % 3
	position = Vector2(cell.x * T + T * 0.5, cell.y * T + T * 0.5)
	powered = level.powered


func _ready() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0
	t = randf() * 10.0
	cv = IsoView.attach(self, false)
	if kind == "v" or kind == "j":
		cv.z_index = -1   # floor grate / resin crust
	if Level.SOLID_PROPS.contains(kind):
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(T, T) if kind != "p" else Vector2(24, 24)
		cs.shape = r
		add_child(cs)
	match kind:
		"l":
			light = PointLight2D.new()
			light.range_item_cull_mask = 3   # also lights the floor layer
			light.height = 150.0
			light.texture = LightUtil.radial(256)
			light.texture_scale = 1.15
			light.position = Vector2(0, -36)
			light.scale = Vector2(1.0, 0.6)
			cv.add_child(light)
			set_powered(powered)
		"g":
			if Level.hash2(cell.x, cell.y) % 4 == 0:
				light = PointLight2D.new()
				light.range_item_cull_mask = 3   # also lights the floor layer
				light.height = 150.0
				light.texture = LightUtil.radial(128)
				light.texture_scale = 1.5
				light.position = Vector2(0, -30)
				light.color = Color(1.0, 0.5, 0.15)
				light.energy = 0.4
				light.scale = Vector2(1.0, 0.6)
				cv.add_child(light)
		"t":
			light = PointLight2D.new()
			light.range_item_cull_mask = 3   # also lights the floor layer
			light.height = 150.0
			light.texture = LightUtil.radial(128)
			light.texture_scale = 1.3
			light.position = Vector2(0, -30)
			light.color = Color(0.3, 1.0, 0.4)
			light.energy = 0.6
			light.scale = Vector2(1.0, 0.6)
			cv.add_child(light)
		"v":
			var p := CPUParticles2D.new()
			p.amount = 14
			p.lifetime = 2.2
			p.position = Vector2(0, -4)
			p.direction = Vector2(0, -1)
			p.spread = 18.0
			p.gravity = Vector2(6, -12)
			p.initial_velocity_min = 18.0
			p.initial_velocity_max = 34.0
			p.texture = LightUtil.radial(32)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.1
			p.color = Color(0.6, 0.6, 0.62, 0.18)
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			p.color_ramp = g
			p.z_index = 10
			cv.add_child(p)
		"f":
			light = PointLight2D.new()
			light.range_item_cull_mask = 3   # also lights the floor layer
			light.height = 150.0
			light.texture = LightUtil.radial(128)
			light.texture_scale = 1.9
			light.position = Vector2(0, -10)
			light.color = Color(0.35, 0.95, 0.75) if variant != 1 else Color(0.6, 0.4, 1.0)
			light.energy = 1.1
			light.scale = Vector2(1.0, 0.6)
			cv.add_child(light)
		"z":
			var s := CPUParticles2D.new()
			s.amount = 10
			s.lifetime = 0.5
			s.explosiveness = 0.9
			s.position = Vector2(0, -22)
			s.direction = Vector2(0, 1)
			s.spread = 60.0
			s.gravity = Vector2(0, 400)
			s.initial_velocity_min = 40.0
			s.initial_velocity_max = 120.0
			s.scale_amount_min = 1.5
			s.scale_amount_max = 2.5
			s.color = Color(1.0, 0.75, 0.3)
			s.z_index = 10
			cv.add_child(s)
			light = PointLight2D.new()
			light.range_item_cull_mask = 3   # also lights the floor layer
			light.height = 150.0
			light.texture = LightUtil.radial(128)
			light.color = Color(1.0, 0.7, 0.3)
			light.energy = 0.0
			light.position = Vector2(0, -22)
			light.scale = Vector2(1.0, 0.6)
			cv.add_child(light)


func set_powered(on: bool) -> void:
	powered = on
	if kind == "l" and light != null:
		light.color = (level.lamp_color if level != null else Color(0.95, 0.82, 0.62)) if on else Color(0.95, 0.2, 0.1)
		light.energy = 1.3 if on else 1.0
		if cv != null: cv.queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if (kind == "t" or kind == "g" or kind == "l" or kind == "f") and cv != null:
		cv.redraw_if_visible()
	if light == null:
		return
	match kind:
		"l":
			var hsh := Level.hash2(cell.x, cell.y)
			var lamp_on := 1.3 if powered else 0.7 + 0.45 * sin(t * 2.4)   # emergency beacons pulse
			if level != null and level.steady_lights and hsh % 7 != 0:
				light.energy = lamp_on
			elif hsh % 7 == 0:
				# dying: mostly dark, an occasional sputtering flash
				light.energy = 0.08 if fmod(t + float(hsh % 9), 6.3) > 0.35 else randf_range(0.4, lamp_on)
			elif hsh % 3 == 0:
				# failing: buzzing dropouts
				var phase := fmod(t + float(hsh % 11), 3.9)
				light.energy = randf_range(0.05, lamp_on * 0.6) if phase < 0.45 else lamp_on
			else:
				light.energy = lamp_on
		"z":
			light.energy = maxf(0.0, light.energy - delta * 4.0)
			if randf() < delta * 1.2:
				light.energy = 1.2


func _render() -> void:
	match kind:
		"o":
			_draw_obstacle()
		"p":
			_draw_pillar()
		"g":
			_draw_machine()
		"t":
			_draw_tank()
		"l":
			_draw_lamp()
		"i":
			_draw_boulder()
		"j":
			_draw_resin()
		"f":
			_draw_fungus()
		"z":
			cv.draw_rect(Rect2(-12, -30, 24, 10), Color(0.12, 0.11, 0.1))
			cv.draw_line(Vector2(-10, -25), Vector2(10, -25), Color(0.4, 0.3, 0.15), 2.0)
			cv.draw_line(Vector2(4, -20), Vector2(7, -8), Color(0.08, 0.08, 0.08), 2.0)


func _draw_boulder() -> void:
	var c := Color(0.2, 0.18, 0.16).lerp(Color(0.26, 0.23, 0.2), float(variant) / 2.0)
	var h := 14.0 + variant * 5.0
	Iso.box(cv, Vector2(0, 1), Vector2(12, 10), h, c.lightened(0.12), c, c.darkened(0.35))
	Iso.box(cv, Vector2(-3, -2), Vector2(7, 6), 7.0, c.lightened(0.18), c.lightened(0.04), c.darkened(0.25), Color(0, 0, 0, 0), h)
	cv.draw_line(Vector2(-6, -h + 4), Vector2(2, -h * 0.4), c.darkened(0.4), 1.0)


func _draw_resin() -> void:
	# glistening brood resin creeping over the ground
	var c := Color(0.32, 0.27, 0.22)
	Iso.ground(cv)
	var hsh := Level.hash2(cell.x, cell.y)
	for i in 4:
		var hh := (hsh >> (i * 4)) & 15
		var o := Vector2(float(hh % 5) * 5.0 - 10.0, float(hh / 5) * 5.0 - 7.0)
		cv.draw_circle(o, 5.0 + float(hh % 3) * 2.0, c.lightened(float(i) * 0.04))
	cv.draw_circle(Vector2(-2, -2), 3.0, Color(0.6, 0.65, 0.45, 0.4))
	if variant == 0:
		cv.draw_circle(Vector2(5, 3), 2.0, Color(0.6, 1.0, 0.35, 0.5))
	cv.draw_set_transform(Vector2.ZERO)


func _draw_fungus() -> void:
	var col := Color(0.35, 0.95, 0.75) if variant != 1 else Color(0.6, 0.4, 1.0)
	var pulse := 0.75 + 0.25 * sin(t * 1.5 + float(variant))
	for i in 3:
		var base := Vector2((i - 1) * 7.0, (i % 2) * 3.0)
		var hgt := 9.0 + i * 4.0
		cv.draw_line(base, base + Vector2(0, -hgt), Color(0.3, 0.32, 0.28), 2.0)
		cv.draw_set_transform(base + Vector2(0, -hgt), 0.0, Vector2(1.0, 0.55))
		cv.draw_circle(Vector2.ZERO, 5.0 - i * 0.6, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5))
		cv.draw_circle(Vector2(0, -1), 3.5 - i * 0.5, Color(col.r, col.g, col.b, pulse))
		cv.draw_set_transform(Vector2.ZERO)


func _draw_obstacle() -> void:
	match variant:
		0:  # stacked munitions crates
			Iso.box(cv, Vector2(0, 2), Vector2(14, 12), 16.0, Color(0.27, 0.25, 0.17), Color(0.2, 0.19, 0.13), Color(0.14, 0.13, 0.09), Color(0.1, 0.09, 0.06))
			Iso.face(cv, Vector2(-14, 14), Vector2.RIGHT)
			cv.draw_line(Vector2(0, -8), Vector2(28, -8), Color(0.45, 0.38, 0.12), 2.0)
			cv.draw_set_transform(Vector2.ZERO)
			Iso.box(cv, Vector2(-2, 0), Vector2(9, 8), 12.0, Color(0.25, 0.23, 0.16), Color(0.18, 0.17, 0.12), Color(0.13, 0.12, 0.08), Color(0.1, 0.09, 0.06), 16.0)
		1:  # promethium barrels
			for off in [Vector2(-6, -6), Vector2(7, 2), Vector2(-4, 9)]:
				var bp := Iso.to_screen(off)
				cv.draw_rect(Rect2(bp.x - 6, bp.y - 22, 12, 22), Color(0.3, 0.12, 0.08))
				cv.draw_rect(Rect2(bp.x + 2, bp.y - 22, 4, 22), Color(0.22, 0.09, 0.06))
				cv.draw_set_transform(bp + Vector2(0, -22), 0.0, Vector2(1, 0.5))
				cv.draw_circle(Vector2.ZERO, 6.0, Color(0.38, 0.17, 0.1))
				cv.draw_circle(Vector2.ZERO, 2.0, Color(0.1, 0.05, 0.03))
				cv.draw_set_transform(Vector2.ZERO)
				cv.draw_line(bp + Vector2(-6, -12), bp + Vector2(6, -12), Color(0.55, 0.45, 0.1), 2.0)
		_:  # cogitator bank
			Iso.box(cv, Vector2.ZERO, Vector2(14, 11), 22.0, Color(0.16, 0.16, 0.17), Color(0.1, 0.1, 0.11), Color(0.07, 0.07, 0.08), Color(0.32, 0.25, 0.12))
			Iso.face(cv, Vector2(-14, 11), Vector2.RIGHT)
			for i in 3:
				cv.draw_rect(Rect2(4 + i * 8, -17, 5, 3), Color(0.2, 0.6, 0.3) if (i + variant) % 2 == 0 else Color(0.6, 0.2, 0.1))
			cv.draw_set_transform(Vector2.ZERO)


func _draw_pillar() -> void:
	cv.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1, 0.45))
	cv.draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.4))
	cv.draw_set_transform(Vector2.ZERO)
	cv.draw_rect(Rect2(-15, -14, 30, 14), Color(0.13, 0.12, 0.12))      # plinth
	cv.draw_rect(Rect2(-15, -14, 30, 3), Color(0.27, 0.23, 0.15))
	cv.draw_rect(Rect2(-10, -82, 20, 68), Color(0.12, 0.115, 0.12))     # shaft
	for i in 4:
		cv.draw_line(Vector2(-7 + i * 4.7, -80), Vector2(-7 + i * 4.7, -16), Color(0.17, 0.16, 0.16), 2.0)
	cv.draw_rect(Rect2(-12, -56, 24, 5), Color(0.3, 0.25, 0.16))        # tarnished brass band
	cv.draw_rect(Rect2(-14, -92, 28, 12), Color(0.15, 0.14, 0.14))      # capital
	cv.draw_rect(Rect2(-14, -92, 28, 3), Color(0.2, 0.19, 0.18))         # lit lip of the capital
	cv.draw_rect(Rect2(2, -82, 8, 66), Color(0, 0, 0, 0.35))              # shaft in shadow (light from the left)
	cv.draw_rect(Rect2(-10, -82, 3, 66), Color(0.17, 0.16, 0.16, 0.6))   # lit edge
	cv.draw_circle(Vector2(0, -68), 5.0, Color(0.45, 0.42, 0.36))       # skull boss
	cv.draw_circle(Vector2(-1.8, -69), 1.3, Color(0.05, 0.05, 0.05))
	cv.draw_circle(Vector2(1.8, -69), 1.3, Color(0.05, 0.05, 0.05))


func _draw_machine() -> void:
	var on := level.powered
	Iso.box(cv, Vector2.ZERO, Vector2(16, 16), 28.0, Color(0.17, 0.16, 0.15), Color(0.11, 0.1, 0.1), Color(0.075, 0.07, 0.07), Color(0.05, 0.05, 0.05))
	var h := Level.hash2(cell.x, cell.y)
	Iso.face(cv, Vector2(-16, 16), Vector2.RIGHT)
	if h % 2 == 0:
		cv.draw_line(Vector2(0, -14), Vector2(32, -14), Color(0.3, 0.22, 0.12), 5.0)
	cv.draw_rect(Rect2(5, -24, 6, 6), Color(0.3, 0.6, 0.3) if on else Color(0.5, 0.1, 0.05))
	cv.draw_set_transform(Vector2.ZERO)
	var coil := Color(1.0, 0.55, 0.15) if on else Color(0.3, 0.12, 0.06)
	cv.draw_rect(Rect2(-3, -46, 6, 12), Color(0.1, 0.1, 0.1))
	cv.draw_circle(Vector2(0, -48), 7.0, Color(0.08, 0.08, 0.08))
	cv.draw_circle(Vector2(0, -48), 4.0, coil)
	if on:
		cv.draw_circle(Vector2(0, -48), 9.0, Color(1.0, 0.5, 0.1, 0.2 + 0.1 * sin(t * 5.0)))


func _draw_tank() -> void:
	cv.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1, 0.45))
	cv.draw_circle(Vector2.ZERO, 16.0, Color(0.1, 0.1, 0.1))
	cv.draw_set_transform(Vector2.ZERO)
	cv.draw_rect(Rect2(-14, -10, 28, 10), Color(0.15, 0.14, 0.13))
	var broken := Level.hash2(cell.x, cell.y) % 3 == 0
	cv.draw_rect(Rect2(-11, -54, 22, 44), Color(0.15, 0.45, 0.2, 0.35) if not broken else Color(0.05, 0.08, 0.06, 0.5))
	if not broken:
		# floating specimen silhouette
		var b := sin(t * 1.2) * 2.0
		cv.draw_circle(Vector2(0, -40 + b), 4.0, Color(0.08, 0.12, 0.08, 0.9))
		cv.draw_line(Vector2(0, -36 + b), Vector2(0, -22 + b), Color(0.08, 0.12, 0.08, 0.9), 4.0)
		cv.draw_line(Vector2(0, -32 + b), Vector2(-6, -26 + b), Color(0.08, 0.12, 0.08, 0.9), 2.0)
		cv.draw_line(Vector2(0, -32 + b), Vector2(7, -24 + b), Color(0.08, 0.12, 0.08, 0.9), 2.0)
		for i in 3:
			var by := -14.0 - fmod(t * 14.0 + i * 13.0, 38.0)
			cv.draw_circle(Vector2(-5 + i * 5, by), 1.2, Color(0.6, 1.0, 0.6, 0.5))
	else:
		cv.draw_line(Vector2(-11, -30), Vector2(-3, -44), Color(0.7, 0.8, 0.7, 0.6), 1.0)
		cv.draw_line(Vector2(-3, -44), Vector2(6, -36), Color(0.7, 0.8, 0.7, 0.6), 1.0)
	cv.draw_rect(Rect2(-11, -54, 3, 44), Color(0.6, 0.7, 0.6, 0.18))     # glass catching the light
	cv.draw_line(Vector2(-7, -50), Vector2(-7, -16), Color(1, 1, 1, 0.15), 2.0)
	cv.draw_rect(Rect2(-14, -62, 28, 8), Color(0.15, 0.14, 0.13))
	cv.draw_rect(Rect2(-14, -55, 28, 1), Color(0, 0, 0, 0.5))


func _draw_lamp() -> void:
	cv.draw_rect(Rect2(-2, -34, 4, 34), Color(0.1, 0.09, 0.09))
	cv.draw_rect(Rect2(-6, -4, 12, 4), Color(0.14, 0.13, 0.12))
	var e := clampf(light.energy / 1.3, 0.05, 1.0) if light != null else 1.0
	var c := (Color(0.95, 0.82, 0.58) if powered else Color(0.95, 0.2, 0.08)) * Color(e, e, e, 1.0)
	cv.draw_rect(Rect2(-5, -42, 10, 9), Color(0.16, 0.14, 0.12))
	cv.draw_circle(Vector2(0, -37), 3.5, c)
	cv.draw_circle(Vector2(0, -37), 7.0, Color(c.r, c.g, c.b, 0.25 * e))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(-7, -42), Vector2(7, -42), Vector2(0, -50)]), Color(0.2, 0.17, 0.12))
