class_name Fx
extends Node2D
## Lightweight, self-drawing one-shot effects (no textures, no particle nodes).
## Spawn through the static helpers: Fx.text(), Fx.burst(), Fx.beam(), Fx.ring().
## Positions are SCREEN space (use Iso.sp(world_pos, height)); directions and
## angles are WORLD space and get projected. Rings and slashes lie on the floor.

enum Kind { TEXT, BURST, BEAM, RING, SLASH }

var kind: int = Kind.TEXT
var life := 0.5
var age := 0.0
var color := Color.WHITE
var label := ""
var size := 1.0
var points: Array = []      # BURST: [pos, vel, size]
var to := Vector2.ZERO      # BEAM end (local)
var radius := 0.0           # RING target radius
var angle := 0.0            # SLASH direction
var arc := 1.5              # SLASH arc width
var width := 3.0
var gravity := 0.0

static var _font: Font


static func _spawn(parent: Node, k: int, pos: Vector2) -> Fx:
	var f := Fx.new()
	f.kind = k
	f.position = pos
	if Iso.fx_root != null and is_instance_valid(Iso.fx_root):
		Iso.fx_root.add_child(f)
	elif parent != null and is_instance_valid(parent):
		parent.add_child(f)
	return f


static func text(parent: Node, pos: Vector2, t: String, col: Color, scale_mult: float = 1.0) -> void:
	var f := _spawn(parent, Kind.TEXT, pos)
	f.label = t
	f.color = col
	f.size = scale_mult
	f.life = 0.8
	f.z_index = 60


static func burst(parent: Node, pos: Vector2, col: Color, count: int = 8, speed: float = 160.0, dir: Vector2 = Vector2.ZERO, spread: float = PI, psize: float = 2.0, life_s: float = 0.35) -> void:
	var f := _spawn(parent, Kind.BURST, pos)
	f.color = col
	f.life = life_s
	f.z_index = 20
	var base_ang := Iso.dir(dir).angle() if dir != Vector2.ZERO else 0.0
	var spr := spread if dir != Vector2.ZERO else PI
	for i in count:
		var a := base_ang + randf_range(-spr, spr)
		var v := Vector2.from_angle(a) * speed * randf_range(0.35, 1.0)
		f.points.append([Vector2.ZERO, v, psize * randf_range(0.6, 1.3)])


static func blood(parent: Node, pos: Vector2, dir: Vector2, col: Color = Color(0.45, 0.02, 0.02)) -> void:
	burst(parent, pos, col, 10, 140.0, dir, 0.7, 2.6, 0.45)


static func beam(parent: Node, from: Vector2, end: Vector2, col: Color, w: float = 3.0, life_s: float = 0.12) -> void:
	var f := _spawn(parent, Kind.BEAM, from)
	f.to = end - from
	f.color = col
	f.width = w
	f.life = life_s
	f.z_index = 25


static func ring(parent: Node, pos: Vector2, r: float, col: Color, life_s: float = 0.4, w: float = 6.0) -> void:
	var f := _spawn(parent, Kind.RING, pos)
	f.radius = r
	f.color = col
	f.life = life_s
	f.width = w
	f.z_index = 15


static func slash(parent: Node, pos: Vector2, ang: float, r: float, arc_w: float, col: Color) -> void:
	var f := _spawn(parent, Kind.SLASH, pos)
	f.angle = ang
	f.radius = r
	f.arc = arc_w
	f.color = col
	f.life = 0.16
	f.z_index = 25


func _ready() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	if kind == Kind.TEXT:
		position.y -= 38.0 * delta
	elif kind == Kind.BURST:
		for p in points:
			p[0] += p[1] * delta
			p[1] *= 0.9
	queue_redraw()


func _draw() -> void:
	var t := age / life
	var c := color
	match kind:
		Kind.TEXT:
			c.a = 1.0 - t * t
			var fs := int(15 * size)
			draw_string_outline(_font, Vector2(-20, 0), label, HORIZONTAL_ALIGNMENT_CENTER, 40, fs, 3, Color(0, 0, 0, c.a))
			draw_string(_font, Vector2(-20, 0), label, HORIZONTAL_ALIGNMENT_CENTER, 40, fs, c)
		Kind.BURST:
			c.a = 1.0 - t
			for p in points:
				var pos: Vector2 = p[0]
				var v: Vector2 = p[1]
				draw_line(pos, pos - v * 0.03, c, float(p[2]))
		Kind.BEAM:
			c.a = 1.0 - t
			var glow := c
			glow.a *= 0.35
			draw_line(Vector2.ZERO, to, glow, width * 3.0)
			draw_line(Vector2.ZERO, to, c, width)
			draw_line(Vector2.ZERO, to, Color(1, 1, 1, c.a), maxf(1.0, width * 0.3))
		Kind.RING:
			c.a = (1.0 - t) * 0.9
			var r := radius * (0.2 + 0.8 * sqrt(t))
			Iso.ground(self)
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, width * (1.0 - t * 0.6))
			var inner := c
			inner.a *= 0.15
			draw_circle(Vector2.ZERO, r, inner)
		Kind.SLASH:
			c.a = 1.0 - t
			var sweep := lerpf(-arc * 0.5, arc * 0.5, minf(1.0, t * 2.2))
			Iso.ground(self)
			draw_arc(Vector2.ZERO, radius, angle - arc * 0.5, angle + sweep, 16, c, 7.0 * (1.0 - t))
			var c2 := c
			c2.a *= 0.35
			draw_arc(Vector2.ZERO, radius * 0.75, angle - arc * 0.5, angle + sweep, 16, c2, 12.0 * (1.0 - t))
