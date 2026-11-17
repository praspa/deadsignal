class_name IsoView
extends Node2D
## Screen-space stand-in for a world-space entity. Lives under Iso.view_root
## (y-sorted), follows the target's projected position, and runs the target's
## `_render()` during its own draw so the target can draw via `cv.draw_*()`.
## Lights and particles that belong to an entity are parented to its view.

var target: Node2D
var dynamic := true   # follow + redraw every frame; static views redraw on demand


static func attach(t: Node2D, p_dynamic: bool = true) -> IsoView:
	var v := IsoView.new()
	v.target = t
	v.dynamic = p_dynamic
	v.position = Iso.to_screen(t.global_position)
	if Iso.view_root != null:
		Iso.view_root.add_child(v)
	t.tree_exiting.connect(v.queue_free)
	t.visibility_changed.connect(v._on_target_visibility)
	v.set_process(p_dynamic)
	return v


func _on_target_visibility() -> void:
	if is_instance_valid(target):
		visible = target.is_visible_in_tree()


func _process(_delta: float) -> void:
	position = Iso.to_screen(target.global_position)
	if Iso.cull_rect.size == Vector2.ZERO or Iso.cull_rect.has_point(position):
		queue_redraw()


## Redraws only when near the camera (for animated static entities).
func redraw_if_visible() -> void:
	if Iso.cull_rect.size == Vector2.ZERO or Iso.cull_rect.has_point(position):
		queue_redraw()


## For static views whose entity moved (e.g. teleported in tests).
func sync() -> void:
	position = Iso.to_screen(target.global_position)
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(target):
		target.call("_render")
