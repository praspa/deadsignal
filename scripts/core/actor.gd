class_name Actor
extends CharacterBody2D
## Base for anything with health, armor and status effects (player + enemies).

signal died(actor: Actor)

var hp := 100.0
var max_hp := 100.0
var armor := 0.0
var dead := false
var statuses: Dictionary = {}   # name -> {"t": remaining, "tick": accum}
var flash := 0.0                # hit-flash timer for drawing
var marked_t := 0.0             # Gunline "Marked Target": takes +35% damage from the operative
var knock := Vector2.ZERO
var cv: IsoView                 # screen-space view (see Iso / IsoView)


func status_resist() -> float:
	return 0.0


func apply_status(sname: String, power: float = 1.0) -> void:
	if dead or not Combat.STATUS.has(sname):
		return
	if randf() < status_resist():
		return
	var def: Dictionary = Combat.STATUS[sname]
	var dur := float(def["duration"]) * (1.0 - status_resist() * 0.5)
	var cur: Dictionary = statuses.get(sname, {"t": 0.0, "tick": 0.0, "power": power})
	cur["t"] = maxf(float(cur["t"]), dur)
	cur["power"] = maxf(float(cur.get("power", 1.0)), power)
	statuses[sname] = cur
	_on_status_applied(sname)


func _on_status_applied(_sname: String) -> void:
	pass


func has_status(sname: String) -> bool:
	return statuses.has(sname)


func is_stunned() -> bool:
	return statuses.has("stun")


func slow_factor() -> float:
	var f := 1.0
	for s in statuses:
		f *= 1.0 - float(Combat.STATUS[s].get("slow", 0.0))
	return f


func status_color() -> Color:
	for s in statuses:
		return Combat.STATUS[s]["color"]
	return Color(0, 0, 0, 0)


func process_statuses(delta: float) -> void:
	if marked_t > 0.0:
		marked_t = maxf(0.0, marked_t - delta)
		if marked_t <= 0.0:
			remove_from_group("marked")
	if statuses.is_empty():
		return
	var ended: Array = []
	for s in statuses:
		var st: Dictionary = statuses[s]
		st["t"] = float(st["t"]) - delta
		var dps := float(Combat.STATUS[s]["dps"]) * float(st.get("power", 1.0))
		if dps > 0.0:
			st["tick"] = float(st["tick"]) + delta
			if float(st["tick"]) >= 0.5:
				st["tick"] = float(st["tick"]) - 0.5
				var h := Combat.make_hit(dps * 0.5, null)
				h["pierce_armor"] = true
				h["dot"] = true
				h["color"] = Combat.STATUS[s]["color"]
				take_hit(h)
		if float(st["t"]) <= 0.0:
			ended.append(s)
	for s in ended:
		statuses.erase(s)


## Returns true when the hit landed (false = evaded / invulnerable).
func take_hit(hit: Dictionary) -> bool:
	if dead:
		return false
	var amount := float(hit["amount"])
	if not hit.get("pierce_armor", false):
		amount = Combat.mitigate(amount, armor)
	amount = _modify_incoming(amount, hit)
	if marked_t > 0.0 and hit.get("source") is Player:
		amount *= 1.35
	if amount <= 0.0:
		return true
	hp -= amount
	flash = 0.12
	var kb := float(hit.get("knockback", 0.0))
	if kb > 0.0:
		knock += (hit["dir"] as Vector2) * kb
	var col: Color = hit.get("color", Color(1, 1, 1))
	if hit.get("crit", false):
		col = Color(1.0, 0.85, 0.2)
	_show_damage(amount, hit.get("crit", false), col)
	var st: String = hit.get("status", "")
	if st != "" and randf() < float(hit.get("status_chance", 0.0)):
		apply_status(st)
	_on_damaged(hit, amount)
	var src = hit.get("source")
	hit["_victim"] = self
	if src != null and is_instance_valid(src) and src != self and src.has_method("on_dealt_damage"):
		src.on_dealt_damage(amount, hit)
	if hp <= 0.0:
		hp = 0.0
		die()
		if src != null and is_instance_valid(src) and src != self and src.has_method("on_kill"):
			src.on_kill(self, hit)
	return true


func _modify_incoming(amount: float, _hit: Dictionary) -> float:
	return amount


func _on_damaged(_hit: Dictionary, _amount: float) -> void:
	pass


func _show_damage(amount: float, crit: bool, col: Color) -> void:
	Fx.text(get_parent(), Iso.sp(global_position, 40) + Vector2(randf_range(-10, 10), 0), str(roundi(amount)) + ("!" if crit else ""), col, 1.3 if crit else 1.0)


func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)


func apply_knockback(delta: float) -> Vector2:
	var k := knock
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	return k
