class_name Baker
extends Node
## Renders procedural drawings into textures once ("baking"), so static art
## costs one quad at runtime and can carry a normal map (see luma_normal shader).
## Jobs are processed a few per frame with pooled SubViewports.
## Headless runs render nothing, so `enabled` is false there and callers keep
## their vector drawing.

const PER_FRAME := 8

var enabled := false
var _queue: Array = []        # [size: Vector2i, offset: Vector2, draw: Callable, done: Callable]
var _vps: Array = []
var _busy := false


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	for i in PER_FRAME:
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		_vps.append(vp)


## Queues a bake. `draw` is called as draw.call(canvas_item) inside a draw
## notification with the origin shifted by `offset`; `done` receives the texture.
func request(size: Vector2i, offset: Vector2, draw: Callable, done: Callable) -> void:
	if not enabled:
		return
	_queue.append([size, offset, draw, done])
	if not _busy:
		_run()


func pending() -> int:
	return _queue.size()


func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var jobs: Array = []
		for vp in _vps:
			if _queue.is_empty():
				break
			var job: Array = _queue.pop_front()
			var canvas := BakeCanvas.new()
			canvas.draw_fn = job[2]
			canvas.position = job[1]
			(vp as SubViewport).size = job[0]
			(vp as SubViewport).add_child(canvas)
			(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
			jobs.append([vp, canvas, job[3]])
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return
		for j in jobs:
			var img := (j[0] as SubViewport).get_texture().get_image()
			(j[1] as Node).queue_free()
			if img != null and not img.is_empty():
				(j[2] as Callable).call(ImageTexture.create_from_image(img))
	_busy = false


class BakeCanvas extends Node2D:
	var draw_fn: Callable

	func _draw() -> void:
		draw_fn.call(self)
