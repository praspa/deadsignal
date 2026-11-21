class_name Combat
## Shared combat constants and helpers.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_WATER := 8     # rivers / ocean: block walking, not bullets or sight

const STATUS := {
	"burn":  {"dps": 7.0, "duration": 3.0, "color": Color(1.0, 0.5, 0.1)},
	"bleed": {"dps": 5.0, "duration": 4.0, "color": Color(0.8, 0.05, 0.05)},
	"toxin": {"dps": 4.0, "duration": 5.0, "color": Color(0.45, 0.95, 0.25), "slow": 0.15},
	"shock": {"dps": 0.0, "duration": 2.0, "color": Color(0.45, 0.75, 1.0), "slow": 0.45},
	"stun":  {"dps": 0.0, "duration": 1.2, "color": Color(1.0, 1.0, 0.6), "stun": true},
}


## Armor mitigation: diminishing returns, capped at 75%.
static func mitigate(amount: float, armor: float) -> float:
	var reduction := minf(armor / (armor + 60.0), 0.75)
	return amount * (1.0 - reduction)


static func make_hit(amount: float, source: Node, crit: bool = false) -> Dictionary:
	return {"amount": amount, "crit": crit, "source": source, "status": "", "status_chance": 0.0,
		"knockback": 0.0, "dir": Vector2.ZERO, "pierce_armor": false}


static func roll_damage(lo: float, hi: float, mult: float, crit_chance: float) -> Array:
	var dmg := randf_range(lo, hi) * mult
	var crit := randf() < crit_chance
	if crit:
		dmg *= 1.75
	return [dmg, crit]
