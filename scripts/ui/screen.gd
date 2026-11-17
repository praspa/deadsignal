class_name Screen
extends Control
## Base for modal menu screens: dims the game, runs while the tree is paused,
## and gives the first focusable control focus so keyboard / controller
## navigation works immediately.

signal closed

var panel: PanelContainer
var dim: ColorRect


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func make_panel(size_px: Vector2) -> PanelContainer:
	panel = PanelContainer.new()
	panel.custom_minimum_size = size_px
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -size_px * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	return panel


func _center_panel() -> void:
	if panel != null:
		panel.position = (size - panel.size) * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_panel()


func open() -> void:
	show()
	refresh()
	await get_tree().process_frame
	_center_panel()
	focus_first()


func refresh() -> void:
	pass


func focus_first() -> void:
	var c := _find_focusable(self)
	if c != null:
		c.grab_focus()


func _find_focusable(n: Node) -> Control:
	for child in n.get_children():
		if child is Control:
			var ctl := child as Control
			if ctl.focus_mode == Control.FOCUS_ALL and ctl.is_visible_in_tree() and not (ctl is Button and (ctl as Button).disabled):
				return ctl
			var f := _find_focusable(child)
			if f != null:
				return f
	return null


func close() -> void:
	hide()
	closed.emit()
