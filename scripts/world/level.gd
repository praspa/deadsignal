class_name Level
extends Node2D
## Builds the current location (GameState.location) from its ASCII map in
## data/maps/ (see data/locations.json): floor + wall
## rendering, merged wall collision, an AStarGrid2D for enemy pathing, and all
## entities (enemies, doors, terminals, containers, props, lights, triggers).
## Simulation runs on the square grid; rendering is isometric (see Iso).

const T := 32
const WALL_H := 58.0
const CUTAWAY_ALPHA := 0.22
const MAP_DIR := "res://data/maps/"   # outpost_<n>.txt + .json, see tools/gen_maps.py

const SOLID_PROPS := "opgtinqx&^$?+([]}"
const ENEMY_CHARS := {"d": "drone", "r": "researcher", "h": "heavy", "B": "boss",
	"w": "swarmling", "y": "spitter", "G": "broodguard", "m": "miner", "u": "burrower", "e": "egg", "K": "queen",
	"a": "militia", "s": "crawler", "A": "lieutenant"}
const BROOD := ["swarmling", "spitter", "broodguard", "miner", "burrower", "egg", "militia", "crawler", "lieutenant",
	"stalker", "gibberer", "thornback", "elder_thornback"]   # (Kessar VII's primates use the same behaviours)
const COCOON_CHAR := "O"      # a captive governor, cocooned in resin (Last Water)
const HIVE_HOLE_CHAR := "H"   # Kessar sinkhole between the surface and the hive
const TELEPORT_CHAR := "W"    # ship's teleport pad (returns to the recall beacon)
const KESSAR_LOG_CHAR := "J"  # mining camp log terminal (id "kessar_log")
const DOOR_REQ := {"D": "", "E": "power", "R": "research", "S": "cause", "V": "boss"}
const CREW_CHARS := "QTMFP"   # crew members on the ship, see data/crew.json
const NAV_CHAR := "N"         # ship's nav console (a terminal with id "nav")
const STASH_CHAR := "L"       # ship's cargo locker (stash)
const CRADLE_CHAR := "Z"      # Lazarus Cradle: where the operative revives after dying

var grid: Array = []
var w := 0
var h := 0
var astar := AStarGrid2D.new()
var world: Node2D
var floor_layer: Node2D
var walls: Dictionary = {}      # Vector2i -> WallTile
var _faded: Dictionary = {}     # Vector2i -> true (walls currently fading / faded)
var player_start := Vector2.ZERO
var revive_point := Vector2.ZERO   # in front of the Lazarus Cradle (ship only)
var hive_hole: HiveHole = null
var enemy_chars: Dictionary = {}    # map char -> enemy kind (ENEMY_CHARS + the location's "enemy_chars")
var exits: Dictionary = {}          # map char -> ZoneExit (zone transitions from data/locations.json)
var exit_points: Dictionary = {}    # map char -> world position (arrivals)
var teleport_pad: TeleportPad = null
var rooms: Dictionary = {}           # room name -> Rect2i (tiles), from the layout metadata
var exit_rect := Rect2()
var arena_rect := Rect2()
var lamps: Array = []
var canvas_mod: CanvasModulate
var powered := false
var lamp_color := Color(0.95, 0.82, 0.62)
var steady_lights := false     # aboard the ship: lamps don't fail (one still flickers)
var tinted := false            # location palette remap active (props share it)
var _flicker_t := 0.0
var chunks: Array = []
var baker: Baker
var normal_material: ShaderMaterial
var wall_cache: Dictionary = {}      # signature -> baked Texture2D
var _wall_waiting: Dictionary = {}   # signature -> [WallTile]

const LIGHT_FLOOR := 2   # light layer for the floor: lit by lamps and the player's shadowed lights


func build(p_world: Node2D) -> void:
	world = p_world
	add_to_group("level")
	var ldef := GameState.location_def()
	powered = bool(ldef.get("powered", false)) or GameState.has_flag(String(ldef.get("powered_flag", "-")))
	baker = Baker.new()
	baker.name = "Baker"
	add_child(baker)
	normal_material = ShaderMaterial.new()
	normal_material.shader = preload("res://shaders/luma_normal.gdshader")
	var pal: Dictionary = ldef.get("palette", {})
	if not pal.is_empty():
		tinted = true
		normal_material.set_shader_parameter("remap", float(pal.get("amount", 1.0)))
		normal_material.set_shader_parameter("remap_dark", _vec3(pal.get("dark", [0, 0, 0])))
		normal_material.set_shader_parameter("remap_light", _vec3(pal.get("light", [1, 1, 1])))
		normal_material.set_shader_parameter("remap_gain", float(pal.get("gain", 3.0)))
	if ldef.has("lamp_color"):
		var lc: Array = ldef["lamp_color"]
		lamp_color = Color(float(lc[0]), float(lc[1]), float(lc[2]))
	steady_lights = bool(ldef.get("steady_lights", false))
	WallTile.ship_style = String(ldef.get("wall_style", "")) == "ship"
	WallTile.natural = String(ldef.get("wall_style", "")) if String(ldef.get("wall_style", "")) in ["rock", "hive", "city", "jungle"] else ""
	_load_map()
	floor_layer = Node2D.new()
	floor_layer.name = "Floor"
	floor_layer.z_index = -10
	add_child(floor_layer)
	move_child(floor_layer, 0)
	# small chunks: projected chunks are diamonds, so their bounding boxes
	# overlap the screen a lot; 8x8 keeps off-screen floor culled
	for cy in range(0, h, 8):
		for cx in range(0, w, 8):
			var chunk := FloorChunk.new()
			chunk.setup(self, cx, cy, 8)
			if chunk.has_content():
				chunk.light_mask = LIGHT_FLOOR
				floor_layer.add_child(chunk)
				chunks.append(chunk)
			else:
				chunk.free()
	enemy_chars = ENEMY_CHARS.duplicate()
	enemy_chars.merge(GameState.location_def().get("enemy_chars", {}), true)
	_build_walls()
	_build_water()
	_build_occluders()
	_build_astar()
	_spawn_entities()
	_bake_floor()
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	canvas_mod.color = _ambient()
	Events.flag_set.connect(_on_flag)


func _load_map() -> void:
	var base := MAP_DIR + GameState.map_base()
	var f := FileAccess.open(base + ".txt", FileAccess.READ)
	var lines := f.get_as_text().split("\n")
	grid = []
	w = 0
	for l in lines:
		w = maxi(w, l.length())
	for l in lines:
		grid.append(l.rpad(w))
	h = grid.size()
	var meta = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	GameState.map_info = meta if meta is Dictionary else {}
	rooms = {}
	var rm: Dictionary = GameState.map_info.get("rooms", {})
	for k in rm:
		var r: Array = rm[k]
		rooms[k] = Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)


static func _vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## World-space centre of a named room (layout metadata), or the player start.
func room_center(name: String) -> Vector2:
	if not rooms.has(name):
		return player_start
	var r: Rect2i = rooms[name]
	return Vector2((r.position.x + r.size.x * 0.5) * T, (r.position.y + r.size.y * 0.5) * T)


func ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or y >= h or x >= w:
		return " "
	return (grid[y] as String)[x]


func is_wall(x: int, y: int) -> bool:
	return ch(x, y) == "#"


func is_floor(x: int, y: int) -> bool:
	var c := ch(x, y)
	return c != "#" and c != " "


## Floor style for any walkable tile: ',' exterior, '_' corridor, '.' room.
func floor_style(x: int, y: int) -> String:
	var c := ch(x, y)
	if c == "," or c == "_" or c == ".":
		return c
	var counts := {",": 0, "_": 0, ".": 0}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var n := ch(x + d.x, y + d.y)
		if counts.has(n):
			counts[n] += 1
	var best := "."
	var bc := 0
	for k in counts:
		if int(counts[k]) > bc:
			bc = counts[k]
			best = k
	return best


static func hash2(x: int, y: int) -> int:
	var n := x * 73856093 ^ y * 19349663
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


func tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * T + T * 0.5, y * T + T * 0.5)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / T), 0, w - 1), clampi(int(p.y / T), 0, h - 1))


## Swaps each vector floor chunk for a baked, normal-mapped Sprite2D once the
## Baker has rendered it (no-op headless; vector chunks stay).
func _bake_floor() -> void:
	for chunk in chunks:
		var r: Rect2 = (chunk as FloorChunk).screen_rect()
		baker.request(Vector2i(r.size), -r.position, (chunk as FloorChunk).paint, _on_floor_baked.bind(chunk, r.position))


func _on_floor_baked(tex: Texture2D, chunk: FloorChunk, pos: Vector2) -> void:
	if not is_instance_valid(chunk):
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = pos
	spr.material = normal_material
	spr.light_mask = LIGHT_FLOOR
	floor_layer.add_child(spr)
	chunk.queue_free()


## Baked wall-block textures are shared by every tile with the same look.
func wall_texture(sig: String, tile: WallTile) -> Texture2D:
	if wall_cache.has(sig):
		return wall_cache[sig]
	if baker.enabled:
		if not _wall_waiting.has(sig):
			_wall_waiting[sig] = []
			baker.request(WallTile.BAKE_SIZE, -WallTile.BAKE_ORIGIN, tile.paint, _on_wall_baked.bind(sig))
		(_wall_waiting[sig] as Array).append(tile)
	return null


func _on_wall_baked(tex: Texture2D, sig: String) -> void:
	wall_cache[sig] = tex
	for t in _wall_waiting.get(sig, []):
		if is_instance_valid(t):
			(t as Node2D).queue_redraw()
	_wall_waiting.erase(sig)


## Light occluders in screen space: each horizontal run of wall (and each
## solid prop) projects to a parallelogram on the floor. Only the shadow-casting
## lights (the player's) use them, and their shadows land on the floor only.
func _build_occluders() -> void:
	var occ_root := Node2D.new()
	occ_root.name = "Occluders"
	add_child(occ_root)
	for y in h:
		var x := 0
		while x < w:
			if is_wall(x, y):
				var x0 := x
				while x < w and is_wall(x, y):
					x += 1
				_add_occluder(occ_root, Rect2(x0 * T, y * T, (x - x0) * T, T))
			else:
				x += 1
	for y in h:
		for x in w:
			var c := ch(x, y)
			if "ogtinqx&$?+[]}".contains(c) or c == "C":
				_add_occluder(occ_root, Rect2(x * T + 3, y * T + 3, T - 6, T - 6))


func _add_occluder(parent: Node, r: Rect2) -> void:
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Iso.to_screen(r.position), Iso.to_screen(Vector2(r.end.x, r.position.y)), Iso.to_screen(r.end), Iso.to_screen(Vector2(r.position.x, r.end.y))])
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	var o := LightOccluder2D.new()
	o.occluder = poly
	parent.add_child(o)


# ---------------------------------------------------------------- walls

## Water ('~'): its own collision layer, so it stops the operative and enemies
## but bullets and sight pass over it.
func _build_water() -> void:
	var body := StaticBody2D.new()
	body.name = "WaterCollision"
	body.collision_layer = Combat.LAYER_WATER
	body.collision_mask = 0
	add_child(body)
	for y in h:
		var x := 0
		while x < w:
			if ch(x, y) == "~":
				var x0 := x
				while x < w and ch(x, y) == "~":
					x += 1
				var cs := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2((x - x0) * T, T)
				cs.shape = r
				cs.position = Vector2(x0 * T + (x - x0) * T * 0.5, y * T + T * 0.5)
				body.add_child(cs)
			else:
				x += 1


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "WallCollision"
	body.collision_layer = Combat.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for y in h:
		var row_has := false
		var x := 0
		while x < w:
			if is_wall(x, y):
				row_has = true
				var x0 := x
				while x < w and is_wall(x, y):
					x += 1
				var cs := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2((x - x0) * T, T)
				cs.shape = r
				cs.position = Vector2(x0 * T + (x - x0) * T * 0.5, y * T + T * 0.5)
				body.add_child(cs)
			else:
				x += 1
		if row_has:
			for wx in w:
				if is_wall(wx, y):
					var wt := WallTile.new()
					wt.setup(self, wx, y)
					Iso.view_root.add_child(wt)
					walls[Vector2i(wx, y)] = wt


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T * 0.5, T * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in h:
		for x in w:
			var c := ch(x, y)
			if c == "#" or c == " " or c == "~" or SOLID_PROPS.contains(c) or (c.is_valid_int() and not enemy_chars.has(c)) or c == "c" or c == "C" or c == NAV_CHAR or c == STASH_CHAR or c == CRADLE_CHAR or c == KESSAR_LOG_CHAR or c == COCOON_CHAR or CREW_CHARS.contains(c):
				astar.set_point_solid(Vector2i(x, y), true)
			elif DOOR_REQ.has(c):
				astar.set_point_solid(Vector2i(x, y), not GameState.has_flag(door_flag(x, y)))


## The Brood King smashes a stone pillar ('+'): it becomes rubble you can walk over.
func break_pillar(cell: Vector2i) -> void:
	for n in world.get_children():
		if n is Prop and (n as Prop).cell == cell and (n as Prop).kind == "+":
			(n as Prop).shatter()
			astar.set_point_solid(cell, false)
			return


func set_cell_solid(cell: Vector2i, solid: bool) -> void:
	astar.set_point_solid(cell, solid)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if astar.is_point_solid(a):
		return PackedVector2Array()
	return astar.get_point_path(a, b, true)


static func door_flag(x: int, y: int) -> String:
	return GameState.area_flag("door:%d,%d" % [x, y])


# ---------------------------------------------------------------- entities

func _spawn_entities() -> void:
	var n_cocoons := 0
	var exit_min := Vector2(INF, INF)
	var exit_max := Vector2(-INF, -INF)
	for y in h:
		for x in w:
			var c := ch(x, y)
			var pos := tile_center(x, y)
			var sid := "%d,%d" % [x, y]
			if c == "@":
				player_start = pos
			elif enemy_chars.has(c):
				if not GameState.has_flag(GameState.area_flag("k:" + sid)):
					var e := spawn_enemy(enemy_chars[c], pos, sid)
					if c == "K":
						(e as BroodQueen).arena_rect = Rect2(rooms["queen"].position * T, rooms["queen"].size * T).grow(-T) if rooms.has("queen") else Rect2()
					if c == "B":
						arena_rect = _room_rect(x, y).grow(-T * 3)
						(e as Boss).arena_rect = arena_rect
				elif c == "B":
					var wreck := Boss.new()
					wreck.setup("boss", self, sid)
					wreck.position = pos
					wreck.dead = true
					wreck.dead_t = 99.0
					world.add_child(wreck)
					wreck.remove_from_group("enemies")
					wreck.remove_from_group("boss")
					wreck._shape.disabled = true
			elif DOOR_REQ.has(c):
				var d := Door.new()
				d.setup(self, Vector2i(x, y), DOOR_REQ[c])
				world.add_child(d)
			elif c.is_valid_int() or c == NAV_CHAR or c == KESSAR_LOG_CHAR:
				var t := Terminal.new()
				var log_id := String(GameState.location_def().get("log_id", "kessar_log"))
				t.setup(self, "nav" if c == NAV_CHAR else (log_id if c == KESSAR_LOG_CHAR else c), Vector2i(x, y))
				world.add_child(t)
			elif GameState.location_def().get("exits", {}).has(c):
				var ex := ZoneExit.new()
				ex.setup(c, GameState.location_def()["exits"][c])
				ex.position = pos
				world.add_child(ex)
				exits[c] = ex
				exit_points[c] = pos
			elif c == COCOON_CHAR:
				var co := GovernorCocoon.new()
				co.index = n_cocoons
				n_cocoons += 1
				co.position = pos
				world.add_child(co)
			elif c == HIVE_HOLE_CHAR:
				hive_hole = HiveHole.new()
				hive_hole.position = pos
				hive_hole.dest = "kessar_hive" if GameState.location == "kessar_surface" else "kessar_surface"
				world.add_child(hive_hole)
			elif c == TELEPORT_CHAR:
				teleport_pad = TeleportPad.new()
				teleport_pad.position = pos
				world.add_child(teleport_pad)
			elif c == CRADLE_CHAR:
				var cradle := LazarusCradle.new()
				cradle.position = pos
				world.add_child(cradle)
				revive_point = pos + Vector2(T, 0)
			elif c == STASH_CHAR:
				var locker := StashLocker.new()
				locker.position = pos
				world.add_child(locker)
			elif CREW_CHARS.contains(c) and c != "":
				var npc := CrewNpc.new()
				npc.setup(c, pos)
				world.add_child(npc)
			elif c == "c" or c == "C":
				var box := LootContainer.new()
				box.setup(self, Vector2i(x, y), c == "C")
				world.add_child(box)
			elif SOLID_PROPS.contains(c) or c in ["l", "v", "z", "j", "f", "%", "*", '"', "!", ")", "{"]:
				var p := Prop.new()
				p.setup(self, Vector2i(x, y), c)
				world.add_child(p)
				if tinted and c != "l" and p.cv != null:
					p.cv.material = normal_material
				if c == "l":
					lamps.append(p)
			elif c == "X":
				exit_min = exit_min.min(Vector2(x * T, y * T))
				exit_max = exit_max.max(Vector2(x * T + T, y * T + T))
	if exit_min.x < INF:
		exit_rect = Rect2(exit_min, exit_max - exit_min)
	for gi in GameState.ground_items.duplicate():
		var drop := LootDrop.new()
		drop.entry = gi
		drop.position = Vector2(float(gi["x"]), float(gi["y"]))
		world.add_child(drop)


func spawn_enemy(kind: String, pos: Vector2, sid: String) -> Enemy:
	var e: Enemy
	if kind == "boss":
		e = Boss.new()
	elif kind == "queen":
		e = BroodQueen.new()
	elif kind == "brood_king":
		e = BroodKing.new()
	elif kind in BROOD:
		e = BroodEnemy.new()
	else:
		e = Enemy.new()
	e.setup(kind, self, sid)
	e.position = pos
	world.add_child(e)
	return e


func _room_rect(sx: int, sy: int) -> Rect2:
	# flood fill walkable tiles (stopping at doors) to find the room bounds
	var seen := {Vector2i(sx, sy): true}
	var stack := [Vector2i(sx, sy)]
	var mn := Vector2i(sx, sy)
	var mx := Vector2i(sx, sy)
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
		mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if seen.has(n) or not is_floor(n.x, n.y) or DOOR_REQ.has(ch(n.x, n.y)) or ch(n.x, n.y) == "_":
				continue
			seen[n] = true
			stack.append(n)
	return Rect2(mn.x * T, mn.y * T, (mx.x - mn.x + 1) * T, (mx.y - mn.y + 1) * T)


# ---------------------------------------------------------------- loot

func drop_item(pos: Vector2, entry: Dictionary) -> void:
	entry["x"] = pos.x
	entry["y"] = pos.y
	GameState.ground_items.append(entry)
	var drop := LootDrop.new()
	drop.entry = entry
	drop.position = pos
	drop.pop = true
	world.add_child(drop)


func scatter(pos: Vector2) -> Vector2:
	for i in 8:
		var p := pos + Vector2.from_angle(randf() * TAU) * randf_range(14.0, 40.0)
		if not astar.is_point_solid(world_to_cell(p)):
			return p
	return pos


func roll_consumable(pos: Vector2, stim_chance: float) -> void:
	if randf() < stim_chance:
		drop_item(scatter(pos), {"kind": "stim", "amount": 1})
	else:
		if randf() < 0.6:
			drop_item(scatter(pos), {"kind": "ammo", "ammo": "rifle", "amount": randi_range(25, 45)})
		else:
			drop_item(scatter(pos), {"kind": "ammo", "ammo": "shell", "amount": randi_range(6, 12)})


## A pile of creds, scaled by character level. `mult` scales for tougher sources.
func drop_credits(pos: Vector2, mult: float) -> void:
	var amount := roundi(randf_range(4.0, 10.0) * (1.0 + float(GameState.area_level() - 1) * 0.35) * mult)
	if amount > 0:
		drop_item(scatter(pos), {"kind": "credits", "amount": amount})


func enemy_loot(pos: Vector2, def: Dictionary) -> void:
	var q := int(def.get("quality", 0))
	if randf() < float(def.get("credit_chance", 0.5)):
		drop_credits(pos, 1.0 + q)
	if randf() < float(def.get("drop_chance", 0.3)):
		drop_item(scatter(pos), {"kind": "item", "item": ItemDB.random_drop(GameState.area_level(), q)})
	if randf() < float(def.get("ammo_chance", 0.3)):
		roll_consumable(pos, 0.15)


func boss_loot(pos: Vector2) -> void:
	drop_item(scatter(pos), {"kind": "item", "item": ItemDB.generate(ItemDB.random_base_id(), ItemDB.RARITY_EXPERIMENTAL, GameState.area_level() + 1)})
	drop_item(scatter(pos), {"kind": "item", "item": ItemDB.random_drop(GameState.area_level() + 1, 3)})
	drop_item(scatter(pos), {"kind": "item", "item": ItemDB.random_drop(GameState.area_level() + 1, 3)})
	drop_item(scatter(pos), {"kind": "stim", "amount": 2})
	drop_credits(pos, 25.0)


func container_loot(pos: Vector2, strong: bool) -> void:
	drop_credits(pos, 4.0 if strong else 1.5)
	if strong:
		drop_item(scatter(pos), {"kind": "item", "item": ItemDB.random_drop(GameState.area_level(), 2)})
		drop_item(scatter(pos), {"kind": "item", "item": ItemDB.random_drop(GameState.area_level(), 1)})
		drop_item(scatter(pos), {"kind": "stim", "amount": 1})
		roll_consumable(pos, 0.0)
	else:
		if randf() < 0.6:
			drop_item(scatter(pos), {"kind": "item", "item": ItemDB.random_drop(GameState.area_level(), 0)})
		roll_consumable(pos, 0.3)


# ---------------------------------------------------------------- atmosphere

func _ambient() -> Color:
	var ldef := GameState.location_def()
	var a: Array = ldef.get("ambient_powered", ldef.get("ambient", [0.38, 0.37, 0.36])) if powered else ldef.get("ambient", [0.24, 0.23, 0.25])
	return Color(float(a[0]), float(a[1]), float(a[2]))


func _on_flag(f: String) -> void:
	if f == String(GameState.location_def().get("powered_flag", "-")) and not powered:
		powered = true
		var tw := create_tween()
		tw.tween_property(canvas_mod, "color", _ambient(), 2.5)
		for l in lamps:
			l.call("set_powered", true)
		for wt in walls.values():
			(wt as Node2D).queue_redraw()


func _process(delta: float) -> void:
	_flicker_t += delta
	_update_cutaway(delta)


## Fades wall blocks that stand between the camera and the player.
func _update_cutaway(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var pc := world_to_cell(p.global_position)
	var want: Dictionary = {}
	for y in range(pc.y - 1, pc.y + 7):
		for x in range(pc.x - 1, pc.x + 7):
			var cell := Vector2i(x, y)
			if not walls.has(cell):
				continue
			var depth := (x + y) - (pc.x + pc.y)     # in front of the player
			var lateral := absi((x - y) - (pc.x - pc.y))
			if depth >= 1 and depth <= 6 and lateral <= 3:
				want[cell] = true
	for cell in want:
		_faded[cell] = true
	for cell in _faded.keys():
		var target := CUTAWAY_ALPHA if want.has(cell) else 1.0
		var still := (walls[cell] as WallTile).set_fade(target, delta)
		if not still and target == 1.0:
			_faded.erase(cell)
