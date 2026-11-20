class_name StarMapUI
extends Screen
## The ship's star map (nav console). Draws data/starmap.json as a tree of the
## known universe, left to right: universe -> galaxies -> systems -> planets /
## stations. The ship marker flies along the tree's lines to the selected node;
## at a node with a mission site the operative can descend to it.
##   d-pad / stick / arrows : move the selection    mouse : hover selects
##   A / Enter / click      : plot course, or descend when the ship is there
##   B / Esc                : close (handled by Game)

signal travel(dest: String)

const COL_W := 230.0            # horizontal distance between tree depths
const SHIP_SPEED := 520.0       # px / s along the tree lines
const NAV_REPEAT := 0.18        # s between stick-driven selection moves
const INFO_W := 340.0

var view: Control
var descend_btn: Button
var pos: Dictionary = {}        # node id -> Vector2 (screen), visible nodes only
var depth: Dictionary = {}      # node id -> int
var selected := ""
var ship_at := ""
var ship_pos := Vector2.ZERO
var flight: Array = []          # remaining Vector2 waypoints
var flight_path: Array = []     # node ids being flown through (drawn highlighted)
var flight_target := ""
var status_flash := ""
var status_t := 0.0
var t := 0.0
var _nav_cd := 0.0
var _stars: Array = []          # [Vector2 (0..1), size, phase]
var choosing := false           # Descend pressed at a node with several landing points
var choice: Array = []          # landing points shown: {loc, name, open}
var choice_i := 0
var choice_rects: Array = []    # Rect2 per row (mouse)


func _ready() -> void:
	dim.color = Color(0, 0, 0, 1)
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_map)
	add_child(view)
	descend_btn = UiTheme.button("DESCEND", _descend)
	descend_btn.focus_mode = Control.FOCUS_NONE
	descend_btn.custom_minimum_size = Vector2(INFO_W - 40, 40)
	add_child(descend_btn)
	var close_btn := UiTheme.button("Close", close)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(120, 34)
	close_btn.name = "CloseBtn"
	add_child(close_btn)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	for i in 260:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.5, 1.8), rng.randf() * TAU])


# ---------------------------------------------------------------- data

static func nodes() -> Dictionary:
	return ItemDB.starmap.get("nodes", {})


static func node(id: String) -> Dictionary:
	return nodes().get(id, {})


static func children(id: String) -> Array:
	var out: Array = []
	for k in nodes():
		if String(nodes()[k].get("parent", "")) == id:
			out.append(k)
	return out


static func is_unlocked(id: String) -> bool:
	var n := node(id)
	if n.is_empty():
		return false
	for f in n.get("requires", []):
		if not GameState.has_flag(String(f)):
			return false
	var p := String(n.get("parent", ""))
	return p == "" or is_unlocked(p)


## Node ids from `a` to `b` along the tree (up to the shared ancestor, then down).
static func tree_path(a: String, b: String) -> Array:
	var up_a := _ancestors(a)
	var up_b := _ancestors(b)
	var common := ""
	for x in up_a:
		if x in up_b:
			common = x
			break
	var out: Array = []
	for x in up_a:
		out.append(x)
		if x == common:
			break
	var down: Array = []
	for x in up_b:
		if x == common:
			break
		down.push_front(x)
	out.append_array(down)
	return out


static func _ancestors(id: String) -> Array:
	var out: Array = []
	var cur := id
	while cur != "":
		out.append(cur)
		cur = String(node(cur).get("parent", ""))
	return out


## The node whose landing zone or beacon zones include `location`, if any.
static func node_for_location(location: String) -> String:
	for k in nodes():
		if landing_of(k) == location or location in node(k).get("beacons", []):
			return k
	return ""


## The zone a node lands in by default ("" if nothing to land on).
static func landing_of(id: String) -> String:
	var n := node(id)
	return String(n.get("landing", n.get("location", "")))


## Every landing point of a node: the landing zone (always open) and its
## beacon zones (open once their landing beacon has been activated).
static func landing_points(id: String) -> Array:
	var out: Array = []
	var land := landing_of(id)
	if land == "":
		return out
	var prefix := String(node(id).get("name", "")) + " — "
	out.append({"loc": land, "name": GameState.location_name(land).trim_prefix(prefix), "open": true, "kind": "landing zone"})
	for b in node(id).get("beacons", []):
		var open := GameState.has_flag("beacon:" + String(b))
		out.append({"loc": String(b), "name": GameState.location_name(String(b)).trim_prefix(prefix) if open else "???", "open": open, "kind": "beacon" if open else "undiscovered"})
	return out


# ---------------------------------------------------------------- layout

func refresh() -> void:
	_layout()
	ship_at = GameState.ship_node if pos.has(GameState.ship_node) else String(ItemDB.starmap.get("root", ""))
	ship_pos = pos.get(ship_at, Vector2.ZERO)
	selected = ship_at
	flight.clear()
	flight_path.clear()
	status_flash = ""
	_update_buttons()


## Visible nodes: every unlocked node, plus locked nodes whose parent is
## unlocked (drawn as "Uncharted"; their own children stay hidden). Leaves get
## evenly spaced rows; a parent sits at the middle of its children.
func _layout() -> void:
	pos.clear()
	depth.clear()
	var root := String(ItemDB.starmap.get("root", ""))
	if root == "":
		return
	var rows: Array = []   # [id, depth] for leaves, in order
	_collect(root, 0, rows)
	var top := 120.0
	var bottom := size.y - 110.0
	var gap := minf(96.0, (bottom - top) / maxf(1.0, float(rows.size())))
	var y0 := (top + bottom) * 0.5 - gap * float(rows.size() - 1) * 0.5
	for i in rows.size():
		pos[rows[i][0]] = Vector2(0, y0 + gap * i)
	_place(root, 0)
	var max_depth := 0
	for k in depth:
		max_depth = maxi(max_depth, int(depth[k]))
	var map_w := size.x - INFO_W - 60.0
	var col := minf(COL_W, (map_w - 140.0) / maxf(1.0, float(max_depth)))
	for k in pos:
		pos[k] = Vector2(110.0 + col * int(depth[k]), (pos[k] as Vector2).y)


func _collect(id: String, d: int, rows: Array) -> void:
	depth[id] = d
	var kids: Array = children(id) if is_unlocked(id) else []
	if kids.is_empty():
		rows.append([id, d])
		return
	for c in kids:
		_collect(c, d + 1, rows)


func _place(id: String, d: int) -> float:
	var kids: Array = children(id) if is_unlocked(id) else []
	if kids.is_empty():
		return (pos[id] as Vector2).y
	var sum := 0.0
	for c in kids:
		sum += _place(c, d + 1)
	var y := sum / kids.size()
	pos[id] = Vector2(0, y)
	return y


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_layout()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event is InputEventMouseMotion:
		var h := _node_at((event as InputEventMouseMotion).position)
		if h != "" and h != selected:
			_select(h)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if choosing:
			for i in choice_rects.size():
				if (choice_rects[i] as Rect2).has_point((event as InputEventMouseButton).position) and bool(choice[i]["open"]):
					_land(String(choice[i]["loc"]))
					get_viewport().set_input_as_handled()
					return
		var c := _node_at((event as InputEventMouseButton).position)
		if c != "":
			_select(c)
			activate(c)
			get_viewport().set_input_as_handled()
		return
	if choosing:
		_choice_input(event)
		return
	if event.is_action_pressed("ui_accept"):
		activate(selected)
		get_viewport().set_input_as_handled()
		return
	for pair in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if event.is_action_pressed(pair[0]):
			if event is InputEventJoypadMotion and _nav_cd > 0.0:
				return
			_nav_cd = NAV_REPEAT
			_move_selection(pair[1])
			get_viewport().set_input_as_handled()
			return


func _node_at(p: Vector2) -> String:
	var best := ""
	var bd := 30.0
	for k in pos:
		var d := p.distance_to(pos[k])
		if d < bd:
			bd = d
			best = k
	return best


## Nearest visible node in direction `dir`, favouring ones straight ahead.
func _move_selection(dir: Vector2) -> void:
	var from: Vector2 = pos.get(selected, Vector2.ZERO)
	var best := ""
	var bs := INF
	for k in pos:
		if k == selected:
			continue
		var v: Vector2 = (pos[k] as Vector2) - from
		var along := v.dot(dir)
		if along <= 4.0:
			continue
		var score := v.length() + absf(v.cross(dir)) * 2.0
		if score < bs:
			bs = score
			best = k
	if best != "":
		_select(best)


func _choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if bool(choice[choice_i]["open"]):
			_land(String(choice[choice_i]["loc"]))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		choosing = false
		_update_buttons()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if event is InputEventJoypadMotion and _nav_cd > 0.0:
			return
		_nav_cd = NAV_REPEAT
		var step := -1 if event.is_action_pressed("ui_up") else 1
		var i := choice_i
		for k in choice.size():
			i = wrapi(i + step, 0, choice.size())
			if bool(choice[i]["open"]):
				break
		choice_i = i
		get_viewport().set_input_as_handled()


func _select(id: String) -> void:
	choosing = false
	selected = id
	status_flash = ""
	_update_buttons()


## Accept on a node: fly there, or descend if the ship is already there.
func activate(id: String) -> void:
	if not flight.is_empty() or id == "":
		return
	if not is_unlocked(id):
		_flash("Locked: %s." % String(node(id).get("locked_reason", "OVERWATCH hasn't cleared this route")))
		return
	if id == ship_at:
		if can_descend():
			_descend()
		else:
			_flash("Nothing down there for you. Pick a planet or station.")
		return
	flight_path = tree_path(ship_at, id)
	flight.clear()
	# follow the chart's elbowed lines: across to the midpoint, along, across
	for i in range(1, flight_path.size()):
		var a: Vector2 = pos[flight_path[i - 1]]
		var b: Vector2 = pos[flight_path[i]]
		var mx := (a.x + b.x) * 0.5
		flight.append(Vector2(mx, a.y))
		flight.append(Vector2(mx, b.y))
		flight.append(b)
	flight_target = id
	Audio.play_ui("terminal", 0.8, -6.0)


func can_descend() -> bool:
	return flight.is_empty() and selected == ship_at and landing_of(ship_at) != "" and is_unlocked(ship_at)


## Descend: lands directly when there's one landing point, else lists them.
func _descend() -> void:
	if not can_descend():
		return
	var pts := landing_points(ship_at)
	var open := pts.filter(func(p: Dictionary) -> bool: return bool(p["open"]))
	if open.size() <= 1:
		_land(String(open[0]["loc"]))
		return
	choosing = true
	choice = pts
	choice_i = 0
	_update_buttons()


func _land(loc: String) -> void:
	choosing = false
	hide()
	travel.emit(loc)


func _flash(msg: String) -> void:
	status_flash = msg
	status_t = 2.5


func _update_buttons() -> void:
	if descend_btn == null:
		return
	descend_btn.visible = can_descend() and not choosing
	descend_btn.position = Vector2(size.x - INFO_W - 20 + 20, 420)
	var cb := get_node_or_null("CloseBtn") as Control
	if cb != null:
		cb.position = Vector2(size.x - 140, size.y - 52)


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_nav_cd = maxf(0.0, _nav_cd - delta)
	status_t = maxf(0.0, status_t - delta)
	if not flight.is_empty():
		var step := SHIP_SPEED * delta
		while step > 0.0 and not flight.is_empty():
			var target: Vector2 = flight[0]
			var d := ship_pos.distance_to(target)
			if d <= step:
				ship_pos = target
				step -= d
				flight.pop_front()
			else:
				ship_pos = ship_pos.move_toward(target, step)
				step = 0.0
		if flight.is_empty():
			ship_at = flight_target
			GameState.ship_node = ship_at
			flight_path.clear()
			Audio.play_ui("pickup", 0.7, -8.0)
			_update_buttons()
	view.queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_map() -> void:
	var d := view
	var font := get_theme_default_font()
	var sz := size
	d.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.012, 0.012, 0.02))
	# nebula haze + starfield
	for i in 12:
		var f := 1.0 - i / 12.0
		d.draw_circle(sz * Vector2(0.3, 0.4), 340.0 * f, Color(0.2, 0.06, 0.05, 0.012))
		d.draw_circle(sz * Vector2(0.58, 0.72), 260.0 * f, Color(0.06, 0.1, 0.16, 0.014))
	for s in _stars:
		var a := 0.35 + 0.35 * sin(t * 1.3 + float(s[2]))
		d.draw_circle((s[0] as Vector2) * sz, float(s[1]) * 0.6, Color(0.85, 0.82, 0.75, a))
	# chart grid
	for x in range(0, int(sz.x), 80):
		d.draw_line(Vector2(x, 0), Vector2(x, sz.y), Color(0.62, 0.48, 0.22, 0.04), 1.0)
	for y in range(0, int(sz.y), 80):
		d.draw_line(Vector2(0, y), Vector2(sz.x, y), Color(0.62, 0.48, 0.22, 0.04), 1.0)
	# header
	d.draw_string(font, Vector2(36, 52), "STAR MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.BRASS)
	d.draw_string(font, Vector2(36, 76), "Nav console — %s" % GameState.location_name("ship"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.TEXT_DIM)
	# edges
	for k in pos:
		var p := String(node(k).get("parent", ""))
		if p == "" or not pos.has(p):
			continue
		var a: Vector2 = pos[p]
		var b: Vector2 = pos[k]
		var mid := Vector2((a.x + b.x) * 0.5, a.y)
		var mid2 := Vector2((a.x + b.x) * 0.5, b.y)
		var on_route: bool = k in flight_path and p in flight_path
		var col := Color(0.95, 0.75, 0.35, 0.9) if on_route else (Color(0.62, 0.48, 0.22, 0.55) if is_unlocked(k) else Color(0.4, 0.38, 0.35, 0.3))
		var w := 2.0 if on_route else 1.4
		if is_unlocked(k):
			d.draw_polyline(PackedVector2Array([a, mid, mid2, b]), col, w)
		else:
			d.draw_dashed_line(a, mid, col, 1.0, 5.0)
			d.draw_dashed_line(mid, mid2, col, 1.0, 5.0)
			d.draw_dashed_line(mid2, b, col, 1.0, 5.0)
	# nodes
	for k in pos:
		_draw_node(d, font, k, pos[k])
	# ship marker
	if not pos.is_empty():
		var bob := sin(t * 3.0) * 2.0
		var sp := ship_pos + Vector2(0, -30 + bob)
		var dirx := 1.0
		if not flight.is_empty():
			dirx = signf((flight[0] as Vector2).x - ship_pos.x) if absf((flight[0] as Vector2).x - ship_pos.x) > 1.0 else 1.0
		d.draw_colored_polygon(PackedVector2Array([sp + Vector2(10 * dirx, 0), sp + Vector2(-7 * dirx, -6), sp + Vector2(-4 * dirx, 0), sp + Vector2(-7 * dirx, 6)]), Color(0.9, 0.85, 0.7))
		d.draw_circle(sp + Vector2(-6 * dirx, 0), 2.0 + 0.8 * sin(t * 12.0), Color(0.4, 0.8, 1.0, 0.8))
	_draw_info(d, font)
	# hint bar
	var hint := "D-pad / stick: select    A: plot course / descend    B: close" if InputSetup.using_pad \
		else "Arrows / mouse: select    Enter / click: plot course / descend    Esc: close"
	d.draw_string(font, Vector2(36, sz.y - 28), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.TEXT_DIM)


func _draw_node(d: Control, font: Font, id: String, p: Vector2) -> void:
	var n := node(id)
	var kind := String(n.get("type", "planet"))
	var open := is_unlocked(id)
	var grey := Color(0.38, 0.37, 0.35, 0.6)
	var hsh := absi(hash(id))
	if id == selected:
		var r := 22.0 + 2.0 * sin(t * 4.0)
		d.draw_arc(p, r, 0, TAU, 32, Color(0.95, 0.75, 0.35, 0.9), 2.0)
	match kind:
		"universe":
			for i in 3:
				d.draw_arc(p, 6.0 + i * 5.0, 0, TAU, 28, Color(0.62, 0.48, 0.22, 0.7 - i * 0.18), 1.2)
			d.draw_circle(p, 3.0, UiTheme.TEXT)
		"galaxy":
			var col := Color(0.75, 0.6, 0.85) if open else grey
			d.draw_circle(p, 13.0, Color(col.r, col.g, col.b, 0.12))
			for arm in 2:
				var pts := PackedVector2Array()
				for i in 14:
					var ang := t * 0.4 + arm * PI + i * 0.32
					pts.append(p + Vector2.from_angle(ang) * (1.5 + i * 1.0) * Vector2(1.0, 0.6))
				d.draw_polyline(pts, Color(col.r, col.g, col.b, 0.85), 1.5)
			d.draw_circle(p, 3.0, col.lightened(0.3))
		"system":
			var col := Color(1.0, 0.62, 0.25) if open else grey
			if open:
				for i in 4:
					d.draw_circle(p, 16.0 - i * 3.0, Color(col.r, col.g, col.b, 0.06 + i * 0.05))
			d.draw_circle(p, 6.0, col)
			d.draw_circle(p, 3.0, col.lightened(0.5))
		"station":
			var col := Color(0.6, 0.66, 0.7) if open else grey
			var hexp := PackedVector2Array()
			for i in 6:
				hexp.append(p + Vector2.from_angle(TAU * i / 6.0 + t * 0.2) * 9.0)
			d.draw_colored_polygon(hexp, col.darkened(0.45))
			hexp.append(hexp[0])
			d.draw_polyline(hexp, col, 1.5)
			d.draw_line(p + Vector2(-14, 0), p + Vector2(14, 0), col, 1.0)
			if open:
				d.draw_circle(p, 2.0, Color(1.0, 0.3, 0.15, 0.5 + 0.5 * sin(t * 5.0)))
		_:
			var base := Color.from_hsv(float(hsh % 360) / 360.0, 0.35, 0.55) if open else grey
			d.draw_circle(p, 10.0, base.darkened(0.55))
			d.draw_circle(p + Vector2(-2, -2), 7.5, base)
			d.draw_circle(p + Vector2(-4, -4), 3.0, base.lightened(0.25))
			if hsh % 2 == 0:
				d.draw_arc(p, 15.0, 0, TAU, 28, Color(base.r, base.g, base.b, 0.5), 1.0)
	if not open:
		# padlock
		var lp := p + Vector2(12, -12)
		d.draw_arc(lp + Vector2(0, -3), 3.0, PI, TAU, 8, grey.lightened(0.3), 1.2)
		d.draw_rect(Rect2(lp + Vector2(-4, -3), Vector2(8, 6)), grey.lightened(0.3))
	var label := String(n.get("name", id)) if open else "Uncharted"
	var lc := UiTheme.TEXT if open else UiTheme.TEXT_DIM
	if id == selected:
		lc = Color(1.0, 0.85, 0.5)
	d.draw_string(font, p + Vector2(-80, 32), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, lc)


func _draw_info(d: Control, font: Font) -> void:
	var r := Rect2(size.x - INFO_W - 20, 110, INFO_W, 290)
	d.draw_rect(r, Color(0.05, 0.045, 0.05, 0.94))
	d.draw_rect(r, UiTheme.BRASS_DIM, false, 2.0)
	d.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), UiTheme.BLOOD)
	if selected == "":
		return
	var n := node(selected)
	var open := is_unlocked(selected)
	var x := r.position.x + 20
	var w := r.size.x - 40
	var kinds := {"universe": "KNOWN SPACE", "galaxy": "GALAXY", "system": "STAR SYSTEM", "planet": "PLANET", "station": "STATION / INSTALLATION"}
	d.draw_string(font, Vector2(x, r.position.y + 32), String(kinds.get(String(n.get("type", "")), "")), HORIZONTAL_ALIGNMENT_LEFT, w, 12, UiTheme.BRASS)
	d.draw_string(font, Vector2(x, r.position.y + 60), String(n.get("name", selected)) if open else "Uncharted", HORIZONTAL_ALIGNMENT_LEFT, w, 22, UiTheme.TEXT)
	var desc := String(n.get("description", "")) if open else "No survey data. " + String(n.get("locked_reason", "OVERWATCH has not cleared this route")) + "."
	choice_rects.clear()
	if choosing:
		var accept0 := "A" if InputSetup.using_pad else "Enter"
		d.draw_string(font, Vector2(x, r.position.y + 90), "Choose landing point", HORIZONTAL_ALIGNMENT_LEFT, w, 13, UiTheme.BRASS)
		for i in choice.size():
			var row := Rect2(x - 6, r.position.y + 100 + i * 30, w + 12, 26)
			choice_rects.append(row)
			var c: Dictionary = choice[i]
			if i == choice_i:
				d.draw_rect(row, Color(0.62, 0.48, 0.22, 0.25))
				d.draw_rect(row, UiTheme.BRASS, false, 1.0)
			var txt := ("> " if i == choice_i else "  ") + String(c["name"]) + "  (" + String(c["kind"]) + ")"
			d.draw_string(font, row.position + Vector2(8, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, w, 14, UiTheme.TEXT if bool(c["open"]) else UiTheme.TEXT_DIM)
		d.draw_string(font, Vector2(x, r.end.y - 22), "[%s] Land    [%s] Back" % [accept0, "B" if InputSetup.using_pad else "Esc"], HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color(0.5, 1.0, 0.6))
		return
	d.draw_multiline_string(font, Vector2(x, r.position.y + 92), desc, HORIZONTAL_ALIGNMENT_LEFT, w, 14, 7, UiTheme.TEXT_DIM)
	var status := ""
	var sc := UiTheme.TEXT
	var accept := "A" if InputSetup.using_pad else "Enter"
	if status_t > 0.0 and status_flash != "":
		status = status_flash
		sc = Color(1.0, 0.55, 0.35)
	elif not open:
		status = "LOCKED — " + String(n.get("locked_reason", "not cleared"))
		sc = Color(0.75, 0.35, 0.3)
	elif not flight.is_empty():
		status = "In transit..."
		sc = Color(0.4, 0.8, 1.0)
	elif selected == ship_at:
		if landing_of(selected) != "":
			var n_open := landing_points(selected).filter(func(p: Dictionary) -> bool: return bool(p["open"])).size()
			status = "Ship in orbit.  [%s] Descend" % accept + ("  (%d landing points)" % n_open if n_open > 1 else "")
			sc = Color(0.5, 1.0, 0.6)
		else:
			status = "The %s is here." % GameState.location_name("ship")
	else:
		status = "[%s] Plot course" % accept
		sc = Color(1.0, 0.85, 0.5)
	d.draw_multiline_string(font, Vector2(x, r.end.y - 40), status, HORIZONTAL_ALIGNMENT_LEFT, w, 15, 2, sc)
