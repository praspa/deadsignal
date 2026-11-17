extends Node
## Persistent character + world state. Everything here is plain data so the
## save system can dump it straight to JSON.

var save_path := "user://deadsignal_save.json"
const SLOTS := ["primary", "secondary", "head", "body", "gloves", "boots", "utility"]
const ATTRS := ["str", "dex", "int", "wil"]
const POINTS_PER_LEVEL := 3
const MAX_INVENTORY := 30
const DEFAULT_NAME := "Operative"
const NAME_MAX := 16
## Playable classes, in the order the character creation screen lists them.
## Only "available" classes can be picked; the rest show as locked.
const CLASSES := [
	{"id": "combat_specialist", "name": "Combat Specialist", "available": true,
		"skills": ["Firearms", "Heavy Weapons", "Armor", "Melee", "Brute Force"],
		"description": "A burly, battle-hardened space marine. Trained to hold a corridor against anything that comes through it, and to walk out carrying the wounded.\n\nStarts with an assault rifle, a power maul, flak carapace armour and a shotgun in reserve."},
	{"id": "field_technician", "name": "Field Technician", "available": false},
	{"id": "psionic_adept", "name": "Psionic Adept", "available": false},
	{"id": "infiltrator", "name": "Infiltrator", "available": false},
	{"id": "combat_medic", "name": "Combat Medic", "available": false},
]
const DEFAULT_RACE := "human"
## Playable races. Purely visual for now: each one changes how the operative
## looks (see Player.RACE_LOOK), not their stats.
const RACES := [
	{"id": "human", "name": "Human",
		"description": "The baseline species: adaptable, stubborn and everywhere. Human colonies and corporate holdings stretch across most of settled space, and so do their wars."},
	{"id": "ossari", "name": "Ossari",
		"description": "Slender, pale and large-eyed. The Ossari are a contemplative people who avoid violence where they can, and nearly all of them are born with some measure of psionic talent."},
	{"id": "halvex", "name": "Halvex",
		"description": "A humanoid people who graft symbiotic cybernetics into their children from infancy. A grown Halvex can feel a data network the way others feel a breeze, and talk to machines directly."},
	{"id": "nyxari", "name": "Nyxari",
		"description": "Nocturnal hunters with leathery wings and a ring of eight small eyes around the head. They come from a low-tech world, glide with ease, and find bright light painful, so their visors run dark."},
	{"id": "zessk", "name": "Zessk",
		"description": "Small, quick reptilians with sleek, finely scaled bodies. Endlessly curious, never still and always talking, the Zessk take apart any machine they can reach, and usually put it back together better."},
	{"id": "ursathi", "name": "Ursathi",
		"description": "Towering, heavily muscled and covered in fur, with claws and a thick mane. Over two metres tall and from a tribal warrior culture, the Ursathi hold to a strict code of honour."},
]
const NAME_FIRST := ["Kade", "Vex", "Juno", "Rhys", "Talon", "Mira", "Orin", "Sable", "Dax", "Nyra", "Corvin", "Ilsa", "Brann", "Tamsin", "Zeke", "Rook", "Anya", "Cassius", "Lio", "Wren", "Thorne", "Yara", "Soren", "Ember"]
const NAME_LAST := ["Voss", "Kael", "Draven", "Morrow", "Strand", "Halloran", "Rask", "Teague", "Vantor", "Okoro", "Sato", "Kessler", "Varga", "Lindqvist", "Ashgrove", "Calder", "Reyes", "Mbeki", "Dreyfus", "Quill", "Harrow", "Crane"]

var player_name := DEFAULT_NAME
var class_id := "combat_specialist"
var race_id := DEFAULT_RACE
var level := 1
var xp := 0
var attr_points := 0
var attributes := {"str": 7, "dex": 6, "int": 4, "wil": 4}
var hp := 100.0
var energy := 50.0
var inventory: Array = []
var equipment: Dictionary = {}
var ammo := {"rifle": 150, "shell": 24}
var stims := 2
var flags: Dictionary = {}
var ground_items: Array = []
var player_pos: Variant = null
var map_variant := 1               # which outpost layout (data/maps/outpost_<n>.txt)
var map_info: Dictionary = {}      # that layout's metadata (name, rooms, compass directions)
var explored := PackedByteArray()   # minimap fog of war: 1 per seen tile (row-major, map width)

const MAP_VARIANTS := 6
var play_time := 0.0
var _uid := 1
var loaded_from_save := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	new_game()


func next_uid() -> int:
	_uid += 1
	return _uid


func new_game(p_name: String = DEFAULT_NAME, p_class: String = "combat_specialist", p_race: String = DEFAULT_RACE) -> void:
	player_name = clean_name(p_name)
	class_id = p_class if is_class_available(p_class) else "combat_specialist"
	race_id = p_race if not race_info(p_race).is_empty() else DEFAULT_RACE
	level = 1
	xp = 0
	attr_points = 0
	attributes = {"str": 7, "dex": 6, "int": 4, "wil": 4}
	inventory = []
	equipment = {}
	for s in SLOTS:
		equipment[s] = {}
	ammo = {"rifle": 150, "shell": 24}
	stims = 2
	flags = {}
	ground_items = []
	player_pos = null
	map_variant = _pick_variant()
	explored = PackedByteArray()
	play_time = 0.0
	_uid = 1
	loaded_from_save = false
	if ItemDB.bases.is_empty():
		return
	equipment["primary"] = ItemDB.generate("assault_rifle", 0, 1)
	equipment["secondary"] = ItemDB.generate("power_maul", 0, 1)
	equipment["body"] = ItemDB.generate("flak_carapace", 0, 1)
	inventory.append(ItemDB.generate("shotgun", 0, 1))
	hp = max_hp()
	energy = max_energy()


# ---------------------------------------------------------------- identity

## Trims the name, drops control characters and caps the length; blank means DEFAULT_NAME.
func clean_name(n: String) -> String:
	var out := ""
	for ch in n.strip_edges():
		if ch.unicode_at(0) >= 32:
			out += ch
	out = out.strip_edges().left(NAME_MAX)
	return out if out != "" else DEFAULT_NAME


func class_info(id: String) -> Dictionary:
	for c in CLASSES:
		if c["id"] == id:
			return c
	return {}


func race_info(id: String) -> Dictionary:
	for r in RACES:
		if r["id"] == id:
			return r
	return {}


func race_title() -> String:
	return String(race_info(race_id).get("name", "Human"))


## A random sci-fi "First Last" name that fits in NAME_MAX.
func random_name() -> String:
	for i in 20:
		var n := "%s %s" % [NAME_FIRST.pick_random(), NAME_LAST.pick_random()]
		if n.length() <= NAME_MAX:
			return n
	return String(NAME_FIRST.pick_random())


func is_class_available(id: String) -> bool:
	return bool(class_info(id).get("available", false))


func class_title() -> String:
	return String(class_info(class_id).get("name", "Combat Specialist"))


# ---------------------------------------------------------------- flags

func has_flag(f: String) -> bool:
	return flags.has(f)


func set_flag(f: String) -> void:
	if flags.has(f):
		return
	flags[f] = true
	Events.flag_set.emit(f)


## A random layout for a new game, avoiding the one in the current save.
## `--variant N` on the command line forces one (tests, screenshots).
func _pick_variant() -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--variant")
	if i >= 0 and i + 1 < args.size():
		return clampi(int(args[i + 1]), 1, MAP_VARIANTS)
	var previous := -1
	if has_save():
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				previous = int(d.get("map_variant", 1))
	var v := randi_range(1, MAP_VARIANTS)
	while v == previous:
		v = randi_range(1, MAP_VARIANTS)
	return v


## Fills layout-specific placeholders ({gen_dir}, {labs_dir}, ...) in story text.
func fmt(text: String) -> String:
	return text.format(map_info.get("dirs", {}))


func objective_index() -> int:
	var objs: Array = ItemDB.mission.get("objectives", [])
	for i in objs.size():
		if not has_flag(String(objs[i]["flag"])):
			return i
	return objs.size()


func current_objective_text() -> String:
	var objs: Array = ItemDB.mission.get("objectives", [])
	var i := objective_index()
	if i >= objs.size():
		return "Mission complete"
	return fmt(String(objs[i]["text"]))


# ---------------------------------------------------------------- stats

func attr(a: String) -> float:
	return float(attributes.get(a, 0)) + equip_stat(a)


func equip_stat(stat: String) -> float:
	var t := 0.0
	for s in SLOTS:
		var it: Dictionary = equipment.get(s, {})
		if it.is_empty():
			continue
		t += float(it.get("stats", {}).get(stat, 0.0))
	return t


func has_special(id: String, slot_filter: String = "") -> bool:
	for s in SLOTS:
		if slot_filter != "" and s != slot_filter:
			continue
		var it: Dictionary = equipment.get(s, {})
		if not it.is_empty() and String(it.get("special", "")) == id:
			return true
	return false


func max_hp() -> float:
	return 70.0 + attr("str") * 5.0 + float(level - 1) * 12.0 + equip_stat("max_hp")


func max_energy() -> float:
	return 40.0 + attr("int") * 4.0 + attr("wil") * 2.0 + equip_stat("max_energy")


func armor() -> float:
	var a := 3.0  # Combat Specialist training
	for s in SLOTS:
		var it: Dictionary = equipment.get(s, {})
		if not it.is_empty():
			a += float(it.get("armor", 0))
	return a + equip_stat("armor")


func crit_chance() -> float:
	return clampf(5.0 + attr("dex") * 0.5 + equip_stat("crit"), 0.0, 75.0) / 100.0


func evasion() -> float:
	return clampf(attr("dex") * 0.6, 0.0, 30.0) / 100.0


func melee_mult() -> float:
	return 1.0 + attr("str") * 0.045


func ranged_mult() -> float:
	return 1.1 + attr("dex") * 0.03  # +10% Combat Specialist firearms training


func tech_mult() -> float:
	return 1.0 + attr("int") * 0.06


func status_resist() -> float:
	return clampf(attr("wil") * 3.0 + equip_stat("resist"), 0.0, 75.0) / 100.0


func hp_regen() -> float:
	return 0.4 + equip_stat("hp_regen")


func energy_regen() -> float:
	return 5.0 + attr("wil") * 0.4 + attr("int") * 0.2 + equip_stat("energy_regen")


func move_mult() -> float:
	return 1.0 + equip_stat("move_pct") / 100.0


func spread_mult() -> float:
	return maxf(0.35, 1.0 - attr("dex") * 0.03)


func cooldown_mult() -> float:
	var m := 1.0 - clampf(attr("wil") * 0.01, 0.0, 0.25)
	if has_special("reactive"):
		m *= 0.8
	return m


func xp_to_next() -> int:
	return 100 + (level - 1) * 60


# ---------------------------------------------------------------- progression

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	Events.xp_gained.emit(amount)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		attr_points += POINTS_PER_LEVEL
		hp = max_hp()
		energy = max_energy()
		Events.leveled_up.emit(level)
	Events.stats_changed.emit()


func spend_point(a: String) -> bool:
	if attr_points <= 0 or not attributes.has(a):
		return false
	var hp_ratio := hp / max_hp()
	attributes[a] = int(attributes[a]) + 1
	attr_points -= 1
	hp = max_hp() * hp_ratio
	Events.stats_changed.emit()
	return true


# ---------------------------------------------------------------- inventory

func add_item(item: Dictionary) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		Events.msg("Inventory full.", Color(0.9, 0.4, 0.3))
		return false
	inventory.append(item)
	Events.inventory_changed.emit()
	return true


func can_equip(item: Dictionary, slot: String) -> bool:
	return slot in item.get("slots", [item.get("slot", "")])


func best_slot_for(item: Dictionary) -> String:
	var slots: Array = item.get("slots", [item.get("slot", "")])
	for s in slots:
		if equipment.get(s, {}).is_empty():
			return s
	return String(slots[0])


func equip(item: Dictionary, slot: String = "") -> void:
	if slot == "":
		slot = best_slot_for(item)
	if not can_equip(item, slot):
		return
	var idx := inventory.find(item)
	if idx >= 0:
		inventory.remove_at(idx)
	var old: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	if not old.is_empty():
		inventory.insert(maxi(idx, 0), old)
	_clamp_vitals()
	Events.inventory_changed.emit()
	Events.stats_changed.emit()


func unequip(slot: String) -> void:
	var it: Dictionary = equipment.get(slot, {})
	if it.is_empty():
		return
	if inventory.size() >= MAX_INVENTORY:
		Events.msg("Inventory full.", Color(0.9, 0.4, 0.3))
		return
	equipment[slot] = {}
	inventory.append(it)
	_clamp_vitals()
	Events.inventory_changed.emit()
	Events.stats_changed.emit()


func remove_item(item: Dictionary) -> void:
	var idx := inventory.find(item)
	if idx >= 0:
		inventory.remove_at(idx)
		Events.inventory_changed.emit()


func swap_weapons() -> void:
	var p: Dictionary = equipment.get("primary", {})
	var s: Dictionary = equipment.get("secondary", {})
	if s.is_empty() or not can_equip(s, "primary"):
		Events.msg("Secondary weapon cannot be used as primary.", Color(0.7, 0.7, 0.7))
		return
	if not p.is_empty() and not can_equip(p, "secondary"):
		Events.msg("Primary weapon cannot be used as secondary.", Color(0.7, 0.7, 0.7))
		return
	equipment["primary"] = s
	equipment["secondary"] = p
	Events.inventory_changed.emit()
	Events.stats_changed.emit()


func _clamp_vitals() -> void:
	hp = minf(hp, max_hp())
	energy = minf(energy, max_energy())


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game(pos: Vector2) -> bool:
	player_pos = pos
	var d := {
		"version": 2,
		"player_name": player_name, "class_id": class_id, "race_id": race_id,
		"level": level, "xp": xp, "attr_points": attr_points,
		"attributes": attributes, "hp": hp, "energy": energy,
		"inventory": inventory, "equipment": equipment,
		"ammo": ammo, "stims": stims, "flags": flags,
		"ground_items": ground_items,
		"player_pos": [pos.x, pos.y],
		"map_variant": map_variant,
		"explored": Marshalls.raw_to_base64(explored.compress(FileAccess.COMPRESSION_DEFLATE)),
		"explored_size": explored.size(),
		"play_time": play_time, "uid": _uid,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save file")
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return false
	player_name = clean_name(String(d.get("player_name", DEFAULT_NAME)))   # older saves: no name
	class_id = String(d.get("class_id", "combat_specialist"))
	if not is_class_available(class_id):
		class_id = "combat_specialist"
	race_id = String(d.get("race_id", DEFAULT_RACE))   # version 1 saves: no race
	if race_info(race_id).is_empty():
		race_id = DEFAULT_RACE
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	attr_points = int(d.get("attr_points", 0))
	attributes = {}
	var attrs: Dictionary = d.get("attributes", {})
	for a in ATTRS:
		attributes[a] = int(attrs.get(a, 5))
	inventory = d.get("inventory", [])
	equipment = {}
	var eq: Dictionary = d.get("equipment", {})
	for s in SLOTS:
		equipment[s] = eq.get(s, {})
	ammo = {}
	var am: Dictionary = d.get("ammo", {})
	for k in am:
		ammo[k] = int(am[k])
	stims = int(d.get("stims", 0))
	flags = d.get("flags", {})
	ground_items = d.get("ground_items", [])
	var pp: Array = d.get("player_pos", [])
	player_pos = Vector2(float(pp[0]), float(pp[1])) if pp.size() == 2 else null
	play_time = float(d.get("play_time", 0.0))
	map_variant = clampi(int(d.get("map_variant", 1)), 1, MAP_VARIANTS)   # older saves: original layout
	explored = PackedByteArray()   # older saves: no minimap yet, start blank
	var ex_size := int(d.get("explored_size", 0))
	if ex_size > 0:
		explored = Marshalls.base64_to_raw(String(d.get("explored", ""))).decompress(ex_size, FileAccess.COMPRESSION_DEFLATE)
	_uid = int(d.get("uid", 1000))
	hp = clampf(float(d.get("hp", 100)), 1.0, max_hp())
	energy = clampf(float(d.get("energy", 50)), 0.0, max_energy())
	loaded_from_save = true
	return true
