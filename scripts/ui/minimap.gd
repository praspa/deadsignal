class_name Minimap
extends Control
## Top-right automap, Diablo style: the level as thin architectural line art
## (walls, doorways, obstacles), drawn in the same isometric angle as the game
## and centred on the operative. Only tiles the operative has seen are drawn;
## the rest stays blank. Explored tiles live in GameState.explored, so they
## persist through saves.

const SIZE := Vector2(270, 180)
const MARGIN := 10.0
const ZOOM := 0.15                 # screen px per iso px (a 64x32 tile diamond -> ~10x5)
const SIGHT := 13                  # reveal radius, tiles (about what the camera shows)
const C_WALL := Color(0.8, 0.76, 0.64, 0.9)
const C_OBSTACLE := Color(0.6, 0.57, 0.5, 0.6)
const C_DOOR := Color(0.95, 0.72, 0.3)
const C_DOOR_OPEN := Color(0.55, 0.5, 0.4, 0.55)
const C_PLAYER := Color(1.0, 0.35, 0.2)
const OBSTACLE_CHARS := "opgtcC0123456789"

var level: Level
var player: Player
var wall_segs := PackedVector2Array()       # world-space line pairs, for draw_multiline
var obstacle_segs := PackedVector2Array()
var doors: Array[Vector2i] = []             # explored door cells (drawn live: open / closed)
var _last_cell := Vector2i(-999, -999)


func setup(p_level: Level, p_player: Player) -> void:
	level = p_level
	player = p_player
	var n := level.w * level.h
	if GameState.explored.size() != n:
		GameState.explored = PackedByteArray()
		GameState.explored.resize(n)
	# rebuild line art for everything already explored (a loaded save)
	for y in level.h:
		for x in level.w:
			if GameState.explored[y * level.w + x] != 0:
				_add_cell_art(x, y)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	clip_contents = true
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(get_viewport_rect().size.x - SIZE.x - MARGIN, MARGIN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		if is_inside_tree():
			position = Vector2(get_viewport_rect().size.x - SIZE.x - MARGIN, MARGIN)


func _process(_delta: float) -> void:
	if level == null or not is_instance_valid(player):
		return
	var cell := level.world_to_cell(player.global_position)
	if cell != _last_cell:
		_last_cell = cell
		reveal_around(cell)
	queue_redraw()


func is_explored(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= level.w or y >= level.h:
		return false
	return GameState.explored[y * level.w + x] != 0


func explored_count() -> int:
	return GameState.explored.count(1)


## Marks every tile within SIGHT that has a clear line of sight from `from`.
## Walls and closed doors block sight (but are themselves seen).
func reveal_around(from: Vector2i) -> void:
	for dy in range(-SIGHT, SIGHT + 1):
		for dx in range(-SIGHT, SIGHT + 1):
			if dx * dx + dy * dy > SIGHT * SIGHT:
				continue
			var x := from.x + dx
			var y := from.y + dy
			if x < 0 or y < 0 or x >= level.w or y >= level.h or is_explored(x, y):
				continue
			if _visible(from, Vector2i(x, y)):
				GameState.explored[y * level.w + x] = 1
				_add_cell_art(x, y)


## Bresenham walk from `a` to `b`; blocked if an opaque tile lies strictly between.
func _visible(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while not (x == b.x and y == b.y):
		if not (x == a.x and y == a.y) and _opaque(x, y):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


func _opaque(x: int, y: int) -> bool:
	if not level.is_floor(x, y):
		return true
	return Level.DOOR_REQ.has(level.ch(x, y)) and not GameState.has_flag(Level.door_flag(x, y))


## Line art one explored tile contributes: a wall edge on every side that faces
## rock, an outline for solid props, and doors (drawn live in _draw).
func _add_cell_art(x: int, y: int) -> void:
	if not level.is_floor(x, y):
		return
	var t := float(Level.T)
	var p := Vector2(x, y) * t
	var corners := [p, p + Vector2(t, 0), p + Vector2(t, t), p + Vector2(0, t)]
	var sides := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in 4:
		var n: Vector2i = sides[i]
		if not level.is_floor(x + n.x, y + n.y):
			wall_segs.append(corners[i])
			wall_segs.append(corners[(i + 1) % 4])
	var c := level.ch(x, y)
	if Level.DOOR_REQ.has(c):
		doors.append(Vector2i(x, y))
	elif OBSTACLE_CHARS.contains(c):
		var q := [p + Vector2(8, 8), p + Vector2(t - 8, 8), p + Vector2(t - 8, t - 8), p + Vector2(8, t - 8)]
		for i in 4:
			obstacle_segs.append(q[i])
			obstacle_segs.append(q[(i + 1) % 4])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.02, 0.025, 0.55))
	if level == null or not is_instance_valid(player):
		return
	var center := SIZE * 0.5
	var origin := center - Iso.to_screen(player.global_position) * ZOOM
	draw_set_transform_matrix(Transform2D(Iso.M.x * ZOOM, Iso.M.y * ZOOM, origin))
	if obstacle_segs.size() > 0:
		draw_multiline(obstacle_segs, C_OBSTACLE, -1.0)
	if wall_segs.size() > 0:
		draw_multiline(wall_segs, C_WALL, -1.0)
	var t := float(Level.T)
	for d in doors:
		var open := GameState.has_flag(Level.door_flag(d.x, d.y))
		var p := Vector2(d) * t
		# a bar across the passage: walls left and right -> the corridor runs north-south
		var across_x := level.is_wall(d.x - 1, d.y) or level.is_wall(d.x + 1, d.y)
		var a := p + (Vector2(0, t * 0.5) if across_x else Vector2(t * 0.5, 0))
		var b := a + (Vector2(t, 0) if across_x else Vector2(0, t))
		draw_line(a, b, C_DOOR_OPEN if open else C_DOOR, -1.0)
	# zone exits (city gates, doors to the next zone): bright pulsing markers once seen
	for ex in level.exits.values():
		var ec := level.world_to_cell((ex as Node2D).global_position)
		if is_explored(ec.x, ec.y):
			var col := Color(1.0, 0.75, 0.3) if (ex as ZoneExit).is_open() else Color(1.0, 0.35, 0.25)
			draw_circle((ex as Node2D).global_position, t * (0.7 + 0.15 * sin(Time.get_ticks_msec() * 0.006)), col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# the operative: an arrow pointing where they aim, in screen space
	var dir := Iso.dir(player.aim_dir).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([center + dir * 6.0, center - dir * 4.0 + side * 3.5, center - dir * 2.0, center - dir * 4.0 - side * 3.5]), C_PLAYER)
	draw_rect(Rect2(Vector2.ZERO, SIZE), UiTheme.BRASS_DIM, false, 1.0)
