extends Node
## Item database: loads base items / affixes / rarities from data/items.json and
## generates item instances (plain Dictionaries so they serialise straight to JSON).

const RARITY_COMMON := 0
const RARITY_UNCOMMON := 1
const RARITY_RARE := 2
const RARITY_EXPERIMENTAL := 3

var data: Dictionary = {}
var bases: Dictionary = {}
var rarities: Array = []
var affixes: Array = []
var stat_names: Dictionary = {}
var specials: Dictionary = {}
var enemies: Dictionary = {}
var terminals: Dictionary = {}
var mission: Dictionary = {}
var locations: Dictionary = {}
var crew: Dictionary = {}
var starmap: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	data = load_json("res://data/items.json")
	bases = data.get("bases", {})
	rarities = data.get("rarities", [])
	affixes = data.get("affixes", [])
	stat_names = data.get("stat_names", {})
	specials = data.get("specials", {})
	enemies = load_json("res://data/enemies.json")
	terminals = load_json("res://data/terminals.json")
	mission = load_json("res://data/mission.json")
	locations = load_json("res://data/locations.json")
	crew = load_json("res://data/crew.json")
	starmap = load_json("res://data/starmap.json")


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Invalid JSON in " + path)
	return {}


func rarity_color(r: int) -> Color:
	if r < 0 or r >= rarities.size():
		return Color.WHITE
	return Color.html(String(rarities[r]["color"]))


func rarity_name(r: int) -> String:
	return String(rarities[clampi(r, 0, rarities.size() - 1)]["name"])


func roll_rarity(quality: int = 0) -> int:
	# quality shifts weight toward better rarities
	var weights: Array = []
	var total := 0.0
	for i in rarities.size():
		var w := float(rarities[i]["weight"])
		if i > 0:
			w *= 1.0 + quality * 0.9 * i
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return i
	return 0


func random_base_id() -> String:
	var total := 0.0
	for id in bases:
		total += float(bases[id].get("weight", 1))
	var roll := rng.randf() * total
	for id in bases:
		roll -= float(bases[id].get("weight", 1))
		if roll <= 0.0:
			return id
	return bases.keys()[0]


func random_drop(ilvl: int, quality: int = 0) -> Dictionary:
	return generate(random_base_id(), roll_rarity(quality), ilvl)


func generate(base_id: String, rarity: int, ilvl: int) -> Dictionary:
	var base: Dictionary = bases[base_id]
	var rdef: Dictionary = rarities[rarity]
	var scale := float(rdef["scale"]) * (1.0 + 0.06 * float(ilvl - 1))
	var item := {
		"uid": GameState.next_uid(),
		"base": base_id,
		"slot": base["slot"],
		"slots": base["slots"].duplicate(),
		"kind": base["kind"],
		"rarity": rarity,
		"ilvl": ilvl,
		"armor": 0,
		"stats": {},
		"special": "",
	}
	if base.has("weapon"):
		var w: Dictionary = base["weapon"].duplicate(true)
		var d: Array = w["dmg"]
		w["dmg"] = [roundi(float(d[0]) * scale), roundi(float(d[1]) * scale)]
		item["weapon"] = w
		if w.has("mag"):
			item["loaded"] = int(w["mag"])
	if base.has("armor"):
		item["armor"] = roundi(float(base["armor"]) * scale)
	if base.has("stats"):
		item["stats"] = base["stats"].duplicate(true)
	# affixes
	var n := rng.randi_range(int(rdef["affixes"][0]), int(rdef["affixes"][1]))
	var pool: Array = []
	for a in affixes:
		if a.get("weapon_only", false) and item["kind"] != "weapon":
			continue
		pool.append(a)
	pool.shuffle()
	var prefix := ""
	var suffix := ""
	for i in mini(n, pool.size()):
		var a: Dictionary = pool[i]
		var lo := float(a["range"][0])
		var hi := float(a["range"][1])
		var v := lerpf(lo, hi, rng.randf()) * (1.0 + 0.05 * float(ilvl - 1))
		if hi <= 3.0 and lo >= 0.5 and a["stat"] in ["hp_regen", "energy_regen"]:
			v = snappedf(v, 0.1)
		else:
			v = float(roundi(v))
		var stat: String = a["stat"]
		item["stats"][stat] = float(item["stats"].get(stat, 0.0)) + v
		if prefix == "":
			prefix = a["prefix"]
		elif suffix == "":
			suffix = a["suffix"]
	if rarity == RARITY_EXPERIMENTAL:
		var plist: Array = specials["weapon"] if item["kind"] == "weapon" else specials["armor"]
		var sp: Dictionary = plist[rng.randi() % plist.size()]
		item["special"] = sp["id"]
		item["special_text"] = sp["text"]
		prefix = "Signal-Touched"
	var nm: String = base["name"]
	if prefix != "":
		nm = prefix + " " + nm
	if suffix != "" and rarity >= RARITY_RARE:
		nm = nm + " " + suffix
	item["name"] = nm
	return item


func stat_label(stat: String) -> String:
	return String(stat_names.get(stat, stat))


func fmt_num(v: float) -> String:
	if absf(v - roundf(v)) < 0.01:
		return str(roundi(v))
	return "%.1f" % v


## Full BBCode description used by the loot-inspection panel.
func describe(item: Dictionary) -> String:
	if item.is_empty():
		return "[color=#777]Empty slot[/color]"
	var c := rarity_color(int(item["rarity"])).to_html(false)
	var s := "[color=#%s][b]%s[/b][/color]\n" % [c, item["name"]]
	s += "[color=#%s]%s %s[/color]   [color=#888]ilvl %d[/color]\n" % [c, rarity_name(int(item["rarity"])), slot_label(item), int(item["ilvl"])]
	if item.has("weapon"):
		var w: Dictionary = item["weapon"]
		var pellets := int(w.get("pellets", 1))
		var dmg := "%d-%d" % [int(w["dmg"][0]), int(w["dmg"][1])]
		if pellets > 1:
			dmg += " x%d" % pellets
		s += "Damage: [b]%s[/b]\n" % dmg
		s += "Attacks/sec: %.1f\n" % float(w["rate"])
		if w.has("mag"):
			s += "Magazine: %d  (%s)\n" % [int(w["mag"]), ammo_label(String(w["ammo"]))]
		if w.has("energy_cost"):
			s += "Energy per shot: %d\n" % int(w["energy_cost"])
		var mode: String = w["mode"]
		s += "[color=#999]%s[/color]\n" % {"projectile": "Projectile", "hitscan": "Hitscan beam", "melee": "Melee arc"}.get(mode, mode)
		if w.has("status"):
			s += "[color=#9ad]%d%% chance: %s[/color]\n" % [roundi(float(w["status_chance"]) * 100.0), String(w["status"]).capitalize()]
	if int(item.get("armor", 0)) > 0:
		s += "Armor: [b]%d[/b]\n" % int(item["armor"])
	var stats: Dictionary = item.get("stats", {})
	for k in stats:
		var v := float(stats[k])
		var col := "8fd18a" if v >= 0 else "e07070"
		s += "[color=#%s]%s%s %s[/color]\n" % [col, "+" if v >= 0 else "", fmt_num(v), stat_label(k)]
	if String(item.get("special", "")) != "":
		s += "[color=#c25cff]%s[/color]\n" % item.get("special_text", "")
	return s


## Compares `item` to `other` (the currently equipped item) and lists differences.
func compare(item: Dictionary, other: Dictionary) -> String:
	if other.is_empty():
		return "[color=#8fd18a]Slot is empty — straight upgrade.[/color]"
	var lines := ""
	if item.has("weapon") and other.has("weapon"):
		var d1 := dps(item)
		var d2 := dps(other)
		lines += _diff_line("Damage / sec", d1 - d2)
	var a := float(item.get("armor", 0)) - float(other.get("armor", 0))
	lines += _diff_line("Armor", a)
	var keys: Dictionary = {}
	for k in item.get("stats", {}): keys[k] = true
	for k in other.get("stats", {}): keys[k] = true
	for k in keys:
		var dv := float(item.get("stats", {}).get(k, 0.0)) - float(other.get("stats", {}).get(k, 0.0))
		lines += _diff_line(stat_label(k), dv)
	if lines == "":
		lines = "[color=#888]No stat difference.[/color]"
	return lines


func _diff_line(label: String, dv: float) -> String:
	if absf(dv) < 0.05:
		return ""
	var col := "8fd18a" if dv > 0 else "e07070"
	return "[color=#%s]%s%s %s[/color]\n" % [col, "+" if dv > 0 else "", fmt_num(dv), label]


func dps(item: Dictionary) -> float:
	if not item.has("weapon"):
		return 0.0
	var w: Dictionary = item["weapon"]
	var avg := (float(w["dmg"][0]) + float(w["dmg"][1])) * 0.5 * float(w.get("pellets", 1))
	var mult := 1.0 + float(item.get("stats", {}).get("damage_pct", 0.0)) / 100.0
	var rate := float(w["rate"]) * (1.0 + float(item.get("stats", {}).get("rate_pct", 0.0)) / 100.0)
	return avg * mult * rate


func slot_label(item: Dictionary) -> String:
	if item.has("weapon"):
		return {"rifle": "Assault Rifle", "shotgun": "Shotgun", "energy": "Energy Pistol", "melee": "Melee Weapon"}.get(String(item["weapon"]["type"]), "Weapon")
	return {"head": "Helm", "body": "Body Armor", "gloves": "Gloves", "boots": "Boots", "utility": "Utility Device"}.get(String(item["slot"]), "Item")


func ammo_label(ammo: String) -> String:
	return {"rifle": "rifle rounds", "shell": "shells"}.get(ammo, ammo)
