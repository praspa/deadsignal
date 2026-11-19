class_name TeleportPad
extends StaticBody2D
## The ship's teleport pad (cargo hold, by the boarding ramp): sends the
## operative back to their recall beacon, while the ship is still in orbit
## over the beacon's star map node.

signal teleport

var interact_radius := 60.0
var t := 0.0
var cv: IsoView


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("teleport_pad")
	collision_layer = 0
	collision_mask = 0
	cv = IsoView.attach(self)
	cv.z_index = -1


func interact_text() -> String:
	var b := GameState.beacon
	if b.is_empty():
		return "Teleport pad (no recall beacon set)"
	return "Return to beacon — " + GameState.location_name(String(b["location"]))


func interact(_player: Node) -> void:
	var b := GameState.beacon
	if b.is_empty():
		Events.msg("No recall beacon set. Use Recall [%s] on a mission to leave one." % InputSetup.key_hint("recall"), UiTheme.TEXT_DIM)
		return
	if String(b.get("node", "")) != GameState.ship_node:
		var n: Dictionary = StarMapUI.node(String(b.get("node", "")))
		Events.msg("Beacon out of range. Return the ship to %s." % String(n.get("name", "its orbit")), Color(1.0, 0.55, 0.35))
		return
	teleport.emit()


func _process(delta: float) -> void:
	t += delta


func _render() -> void:
	var armed := not GameState.beacon.is_empty() and String(GameState.beacon.get("node", "")) == GameState.ship_node
	var glow := Color(0.4, 0.75, 1.0) if armed else Color(0.35, 0.4, 0.45)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	Iso.ground(cv)
	cv.draw_circle(Vector2.ZERO, 26.0, Color(0.22, 0.25, 0.3))
	cv.draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.14, 0.17))
	for i in 3:
		cv.draw_arc(Vector2.ZERO, 8.0 + i * 6.0, 0, TAU, 24, Color(glow.r, glow.g, glow.b, (0.25 + 0.5 * pulse) if armed else 0.25), 1.5)
	for i in 6:
		cv.draw_circle(Vector2.from_angle(i * TAU / 6.0) * 24.0, 2.0, glow)
	cv.draw_set_transform(Vector2.ZERO)
