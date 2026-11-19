extends Node
## Persistent character + world state. Everything here is plain data so the
## save system can dump it straight to JSON.

var save_path := "user://deadsignal_save.json"
const SLOTS := ["primary", "secondary", "head", "body", "gloves", "boots", "utility"]
const ATTRS := ["str", "dex", "int", "wil"]
const POINTS_PER_LEVEL := 3
const MAX_INVENTORY := 30
const MAX_STASH := 50
const START_ATTRIBUTES := {"str": 7, "dex": 6, "int": 4, "wil": 4}
const BUYBACK_SIZE := 10
const RESPEC_PRICE_PER_LEVEL := 100
const XP_CURVE_BASE := 100.0   # XP to next level = base * level ^ exponent
const XP_CURVE_EXP := 1.5
const XP_FULL_GAP := 2         # full monster XP up to this many levels above the area level
const XP_FALLOFF := 0.15       # then this much less per extra level
const XP_MIN_MULT := 0.05
const DEATH_UC_LOSS := 0.10    # share of carried creds lost on death
const DEATH_XP_LOSS := 0.05    # share of the current level's XP requirement lost on death
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
var credits := 0                   # Universal Credits (UC, "creds")
var flags: Dictionary = {}
var location := "ship"             # key into data/locations.json
var reviving := false             # died: wake in the Lazarus Cradle on the next ship load
var last_death_loss := [0, 0]      # [UC, XP] lost on the last death (for the wake-up message)
var stash: Array = []              # items in the ship's cargo locker
var vendor_stock: Array = []       # the Quartermaster's gear for sale
var buyback: Array = []            # items sold this session, newest first
var respecs := 0                   # attribute respecs bought from the Medic (first is free)
var max_area_reached := 1          # highest area level visited (caps vendor / fence item level)
var variants: Dictionary = {}      # location -> layout number, for locations with several layouts
var beacon: Dictionary = {}        # recall beacon: {location, x, y, node} or empty
var recall_cd := 0.0               # seconds until Recall is ready again
var arrive_at: Variant = null      # Vector2: next arrival spot (teleport pad); String "hive_hole": beside the sinkhole
var ship_node := ""                # where the ship is on the star map (data/starmap.json node id)
var areas: Dictionary = {}         # location -> {"ground_items": [...]} for places not currently loaded
var ground_items: Array = []       # loot on the floor of the current location
var player_pos: Variant = null
var map_variant := 1               # which outpost layout (data/maps/outpost_<n>.txt)
var map_info: Dictionary = {}      # that layout's metadata (name, rooms, compass directions)
var explored := PackedByteArray()   # minimap fog of war: 1 per seen tile (row-major, map width)

const MAP_VARIANTS := 6
const SAVE_VERSION := 3   # 2: race / name / class, 3: locations + creds
const _MAP_FLAG_PREFIXES := ["k:", "box:", "door:", "read:"]
var play_time := 0.0
var _uid := 1
var loaded_from_save := false
var session_started := false   # set by start_session; Game announces it once


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
	credits = 0
	flags = {}
	location = "ship"
	ship_node = String(ItemDB.starmap.get("ship_start", ""))
	stash = []
	buyback = []
	respecs = 0
	max_area_reached = 1
	reviving = false
	beacon = {}
	recall_cd = 0.0
	arrive_at = null
	variants = {}
	for id in ItemDB.locations:
		var nv := int(ItemDB.locations[id].get("variants", 0))
		if nv > 0:
			variants[id] = randi_range(1, nv)
	areas = {}
	ground_items = []
	player_pos = null
	map_variant = _pick_variant()
	explored = PackedByteArray()
	play_time = 0.0
	_uid = 1
	loaded_from_save = false
	if ItemDB.bases.is_empty():
		return
	refresh_vendor()
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


# ---------------------------------------------------------------- locations

func location_def(id: String = "") -> Dictionary:
	return ItemDB.locations.get(location if id == "" else id, {})


func is_hub() -> bool:
	return bool(location_def().get("hub", false))


func location_name(id: String = "") -> String:
	return String(location_def(id).get("name", id if id != "" else location))


## Map file base name (no extension) under data/maps/ for the current location.
func map_base() -> String:
	return String(location_def().get("map", location)).format({"variant": int(variants.get(location, map_variant))})


## Moves the character to another location. Floor loot of the place being left
## is kept so it is still there on the way back.
func travel(dest: String) -> void:
	if not is_hub() and bool(ItemDB.locations.get(dest, {}).get("hub", false)):
		refresh_vendor()   # back from a mission: the Quartermaster has new stock
	var here := pack_explored(explored)
	here["ground_items"] = ground_items
	areas[location] = here
	location = dest
	var there: Dictionary = areas.get(dest, {})
	ground_items = there.get("ground_items", [])
	explored = unpack_explored(there)
	areas.erase(dest)
	player_pos = null
	loaded_from_save = false
	max_area_reached = maxi(max_area_reached, int(location_def().get("area_level", 1)))


## Minimap fog of war as JSON-safe data (deflated, base64).
static func pack_explored(arr: PackedByteArray) -> Dictionary:
	if arr.is_empty():   # not visited yet (e.g. saving right after travel)
		return {"explored": "", "explored_size": 0}
	return {"explored": Marshalls.raw_to_base64(arr.compress(FileAccess.COMPRESSION_DEFLATE)), "explored_size": arr.size()}


static func unpack_explored(d: Dictionary) -> PackedByteArray:
	var n := int(d.get("explored_size", 0))
	if n <= 0:
		return PackedByteArray()
	return Marshalls.base64_to_raw(String(d.get("explored", ""))).decompress(n, FileAccess.COMPRESSION_DEFLATE)


## Flags for things placed in a map (killed enemies, opened crates, doors, read
## terminals) are per location, since map coordinates repeat between maps.
func area_flag(f: String) -> String:
	return location + "/" + f


# ---------------------------------------------------------------- death

## Applies the death penalty and restores the body for revival aboard the ship:
## 10% of carried UC, and 5% of this level's XP requirement taken only from
## progress toward the next level (never loses a level).
func apply_death() -> void:
	var uc := int(floor(credits * DEATH_UC_LOSS))
	var xp_loss := mini(xp, int(floor(xp_to_next() * DEATH_XP_LOSS)))
	credits -= uc
	xp -= xp_loss
	last_death_loss = [uc, xp_loss]
	hp = max_hp()
	energy = max_energy()
	reviving = true
	set_flag("revived_once")
	Events.stats_changed.emit()


# ---------------------------------------------------------------- crew services

## Item level for vendor and fence goods: keeps pace with the character but
## never outruns where they've actually been.
func shop_ilvl() -> int:
	return clampi(level, 1, max_area_reached + 2)


## New Quartermaster stock: 12-16 items, mostly Common / Uncommon, 1-2 Rare.
func refresh_vendor() -> void:
	if ItemDB.bases.is_empty():
		return
	vendor_stock = []
	var il := shop_ilvl()
	var n := randi_range(12, 16)
	var rares := randi_range(1, 2)
	for i in n:
		var r := ItemDB.RARITY_RARE if i < rares else (ItemDB.RARITY_UNCOMMON if randf() < 0.4 else ItemDB.RARITY_COMMON)
		vendor_stock.append(ItemDB.generate(ItemDB.random_base_id(), r, il))
	vendor_stock.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["slot"]) < String(b["slot"]))


func _pay(price: int) -> bool:
	if credits < price:
		Events.msg("Not enough creds (%s needed)." % fmt_uc(price), Color(0.9, 0.4, 0.3))
		return false
	credits -= price
	Events.stats_changed.emit()
	return true


func buy_item(item: Dictionary, from_buyback := false) -> bool:
	var src: Array = buyback if from_buyback else vendor_stock
	if not src.has(item):
		return false
	if inventory.size() >= MAX_INVENTORY:
		Events.msg("Pack is full.", Color(0.9, 0.4, 0.3))
		return false
	var price := ItemDB.sell_price(item) if from_buyback else ItemDB.buy_price(item)
	if not _pay(price):
		return false
	src.erase(item)
	add_item(item)
	return true


func sell_item(item: Dictionary) -> bool:
	if not inventory.has(item):
		return false
	remove_item(item)
	add_credits(ItemDB.sell_price(item))
	buyback.push_front(item)
	if buyback.size() > BUYBACK_SIZE:
		buyback.resize(BUYBACK_SIZE)
	return true


func buy_supply(id: String) -> bool:
	var s: Dictionary = ItemDB.SUPPLIES.get(id, {})
	if s.is_empty() or not _pay(int(s["price"])):
		return false
	if s.has("ammo"):
		ammo[String(s["ammo"])] = int(ammo.get(String(s["ammo"]), 0)) + int(s["amount"])
	else:
		stims += 1
	Events.inventory_changed.emit()
	return true


func respec_price() -> int:
	return 0 if respecs == 0 else RESPEC_PRICE_PER_LEVEL * level


## Refunds every spent attribute point (Medic). False if unaffordable / nothing to refund.
func respec() -> bool:
	var spent := 0
	for a in ATTRS:
		spent += int(attributes[a]) - int(START_ATTRIBUTES[a])
	if spent <= 0:
		Events.msg("No attribute points to refund.", UiTheme.TEXT_DIM)
		return false
	if not _pay(respec_price()):
		return false
	var hp_ratio := hp / max_hp()
	attributes = START_ATTRIBUTES.duplicate()
	attr_points += spent
	respecs += 1
	hp = max_hp() * hp_ratio
	_clamp_vitals()
	Events.stats_changed.emit()
	return true


## Fence: buys and opens a sealed crate; returns the item ({} if it failed).
func buy_crate(cat: String) -> Dictionary:
	if inventory.size() >= MAX_INVENTORY:
		Events.msg("Pack is full.", Color(0.9, 0.4, 0.3))
		return {}
	var il := shop_ilvl()
	if not _pay(ItemDB.fence_price(cat, il)):
		return {}
	var slots: Array = ItemDB.FENCE_CATEGORIES[cat]["slots"]
	var item := ItemDB.generate(ItemDB.random_base_in(slots), ItemDB.roll_weighted(ItemDB.FENCE_ODDS), il)
	add_item(item)
	return item


# ---------------------------------------------------------------- stash

## Moves an item between the pack and the ship's cargo locker. False if full.
func stash_item(item: Dictionary) -> bool:
	if stash.size() >= MAX_STASH or not inventory.has(item):
		return false
	inventory.erase(item)
	stash.append(item)
	Events.inventory_changed.emit()
	return true


func unstash_item(item: Dictionary) -> bool:
	if inventory.size() >= MAX_INVENTORY or not stash.has(item):
		return false
	stash.erase(item)
	inventory.append(item)
	Events.inventory_changed.emit()
	return true


# ---------------------------------------------------------------- credits

func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	Events.stats_changed.emit()


static func fmt_uc(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out + " UC"


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


## The mission the current location belongs to ("" aboard the ship).
func mission_id() -> String:
	return String(location_def().get("mission", ""))


func objective_index(mid: String = "") -> int:
	if mid == "":
		mid = mission_id()
	var objs: Array = ItemDB.missions.get(mid, {}).get("objectives", [])
	for i in objs.size():
		if not has_flag(String(objs[i]["flag"])):
			return i
	return objs.size()


func current_objective_text() -> String:
	if location == "ship":
		if not has_flag("kessar:queen"):
			return "Deploy to Kessar IV (star map, cockpit)"
		return "Await new orders from OVERWATCH"
	var objs: Array = ItemDB.missions.get(mission_id(), {}).get("objectives", [])
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
	return roundi(XP_CURVE_BASE * pow(float(level), XP_CURVE_EXP))


## The current location's area level (drives monster XP and loot); the
## character's level where a place has none (the ship).
func area_level() -> int:
	return int(location_def().get("area_level", level))


## Monster XP after the outlevelled-area falloff: full until the character is
## XP_FULL_GAP levels above the area, then -15% per level, never below 5%.
func xp_mult() -> float:
	var over := level - area_level() - XP_FULL_GAP
	if over <= 0:
		return 1.0
	return maxf(XP_MIN_MULT, 1.0 - XP_FALLOFF * over)


func monster_xp(base: int) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(base * xp_mult()))


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


## `pos` null = respawn at the location's start point on load.
func save_game(pos: Variant) -> bool:
	player_pos = pos
	var pp: Array = [] if pos == null else [(pos as Vector2).x, (pos as Vector2).y]
	var d := {
		"version": SAVE_VERSION,
		"player_name": player_name, "class_id": class_id, "race_id": race_id,
		"level": level, "xp": xp, "attr_points": attr_points,
		"attributes": attributes, "hp": hp, "energy": energy,
		"inventory": inventory, "equipment": equipment,
		"ammo": ammo, "stims": stims, "credits": credits, "flags": flags,
		"location": location, "areas": areas, "ship_node": ship_node, "stash": stash, "vendor_stock": vendor_stock, "buyback": buyback, "respecs": respecs, "max_area_reached": max_area_reached, "reviving": reviving, "variants": variants, "beacon": beacon, "recall_cd": recall_cd,
		"ground_items": ground_items,
		"player_pos": pp,
		"map_variant": map_variant,
		"explored": pack_explored(explored)["explored"],
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
	credits = int(d.get("credits", 0))
	flags = d.get("flags", {})
	location = String(d.get("location", "kharon"))   # pre-v3 saves were all at Kharon
	if not ItemDB.locations.has(location):
		location = "ship"
	areas = d.get("areas", {})
	ship_node = String(d.get("ship_node", ""))
	stash = d.get("stash", [])
	vendor_stock = d.get("vendor_stock", [])
	buyback = d.get("buyback", [])
	respecs = int(d.get("respecs", 0))
	max_area_reached = int(d.get("max_area_reached", 1))
	reviving = bool(d.get("reviving", false))
	beacon = d.get("beacon", {})
	recall_cd = float(d.get("recall_cd", 0.0))
	variants = {}
	var sv: Dictionary = d.get("variants", {})
	for id in ItemDB.locations:
		var nv := int(ItemDB.locations[id].get("variants", 0))
		if nv > 0:
			variants[id] = clampi(int(sv.get(id, randi_range(1, nv))), 1, nv)
	if not ItemDB.starmap.get("nodes", {}).has(ship_node):
		# older saves: in orbit over the mission site they were on, else the start
		ship_node = StarMapUI.node_for_location(location)
		if ship_node == "":
			ship_node = String(ItemDB.starmap.get("ship_start", ""))
	ground_items = d.get("ground_items", [])
	if int(d.get("version", 1)) < 3:
		_migrate_pre_location_flags()
	var pp: Array = d.get("player_pos", [])
	player_pos = Vector2(float(pp[0]), float(pp[1])) if pp.size() == 2 else null
	play_time = float(d.get("play_time", 0.0))
	map_variant = clampi(int(d.get("map_variant", 1)), 1, MAP_VARIANTS)   # older saves: original layout
	explored = unpack_explored(d)   # older saves: no minimap yet, start blank
	_uid = int(d.get("uid", 1000))
	hp = clampf(float(d.get("hp", 100)), 1.0, max_hp())
	energy = clampf(float(d.get("energy", 50)), 0.0, max_energy())
	loaded_from_save = true
	start_session()
	return true


## A new play session (loading a save): like starting a new game in Diablo II,
## every mission area is repopulated and re-rolled. The character, story
## progress, star map and ship persist; the session begins aboard the ship.
func start_session() -> void:
	var keep := {}
	for f in flags:
		var key := String(f)
		var slash := key.find("/")
		if slash > 0:
			var loc := key.substr(0, slash)
			var what := key.substr(slash + 1)
			# map state of mission areas resets; terminals stay read (XP is one-time)
			if not bool(ItemDB.locations.get(loc, {}).get("hub", false)) and not what.begins_with("read:"):
				continue
		keep[key] = flags[f]
	flags = keep
	var hub_ground: Array = ground_items if is_hub() else areas.get("ship", {}).get("ground_items", [])
	var ship_area: Dictionary = areas.get("ship", {}) if not is_hub() else pack_explored(explored)
	ship_area["ground_items"] = hub_ground
	if not is_hub():
		explored = unpack_explored(ship_area)
	areas = {}
	ground_items = hub_ground
	for id in ItemDB.locations:
		var nv := int(ItemDB.locations[id].get("variants", 0))
		if nv > 0:
			var prev := int(variants.get(id, 0))
			var v := randi_range(1, nv)
			while nv > 1 and v == prev:
				v = randi_range(1, nv)
			variants[id] = v
	map_variant = _pick_variant()
	beacon = {}
	location = "ship"
	player_pos = null
	buyback = []
	refresh_vendor()
	session_started = true


## Saves before v3 predate locations: their map flags all belong to Kharon.
func _migrate_pre_location_flags() -> void:
	var out := {}
	for f in flags:
		var key := String(f)
		for pre in _MAP_FLAG_PREFIXES:
			if key.begins_with(pre):
				key = "kharon/" + key
				break
		out[key] = flags[f]
	flags = out
