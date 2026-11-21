extends Node
## Registers all input actions in code so keyboard/mouse and controller
## bindings live in one place. Also tracks which device was used last so
## aiming can switch between mouse and right stick seamlessly.

signal device_changed(using_pad: bool)

var using_pad := false

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"roll": [KEY_SPACE],
	"ability_1": [KEY_Q],
	"ability_2": [KEY_F],
	"ability_3": [KEY_G],
	"doctrine": [KEY_K],
	"reload": [KEY_R],
	"interact": [KEY_E],
	"use_stim": [KEY_H],
	"inventory": [KEY_I, KEY_TAB],
	"character": [KEY_C],
	"journal": [KEY_J],
	"pause": [KEY_ESCAPE],
	"quicksave": [KEY_F5],
	"quickload": [KEY_F9],
	"swap_weapons": [KEY_X],
	"show_loot": [KEY_ALT],
	"recall": [KEY_T],
}

const MOUSE := {
	"fire_primary": MOUSE_BUTTON_LEFT,
	"fire_secondary": MOUSE_BUTTON_RIGHT,
}

const PAD_BUTTONS := {
	"roll": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_Y],
	"reload": [JOY_BUTTON_X],
	"ability_1": [JOY_BUTTON_LEFT_SHOULDER],
	"ability_2": [JOY_BUTTON_RIGHT_SHOULDER],
	"ability_3": [JOY_BUTTON_B],
	"use_stim": [JOY_BUTTON_DPAD_UP],
	"swap_weapons": [JOY_BUTTON_DPAD_DOWN],
	"character": [JOY_BUTTON_DPAD_LEFT],
	"inventory": [JOY_BUTTON_BACK, JOY_BUTTON_DPAD_RIGHT],
	"pause": [JOY_BUTTON_START],
	"show_loot": [JOY_BUTTON_LEFT_STICK],
	"recall": [JOY_BUTTON_RIGHT_STICK],
}

# Godot's built-in UI actions are keyboard-only, so pad buttons are added to them
# here; otherwise "accept" (A / PS Cross) and "back" (B / PS Circle) and the
# d-pad do nothing in menus.
const PAD_UI_BUTTONS := {
	"ui_accept": [JOY_BUTTON_A],
	"ui_cancel": [JOY_BUTTON_B],
	"ui_up": [JOY_BUTTON_DPAD_UP],
	"ui_down": [JOY_BUTTON_DPAD_DOWN],
	"ui_left": [JOY_BUTTON_DPAD_LEFT],
	"ui_right": [JOY_BUTTON_DPAD_RIGHT],
}
const PAD_UI_AXES := {
	"ui_up": [JOY_AXIS_LEFT_Y, -1.0],
	"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
	"ui_left": [JOY_AXIS_LEFT_X, -1.0],
	"ui_right": [JOY_AXIS_LEFT_X, 1.0],
}

# action -> [axis, direction]
const PAD_AXES := {
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"aim_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"aim_left": [JOY_AXIS_RIGHT_X, -1.0],
	"aim_right": [JOY_AXIS_RIGHT_X, 1.0],
	"fire_primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"fire_secondary": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var all_actions: Array = []
	for a in KEYS.keys(): all_actions.append(a)
	for a in MOUSE.keys(): all_actions.append(a)
	for a in PAD_AXES.keys(): all_actions.append(a)
	for a in PAD_BUTTONS.keys(): all_actions.append(a)
	for action in all_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
	for action in KEYS:
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)
	for action in PAD_BUTTONS:
		for b in PAD_BUTTONS[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
	for action in PAD_AXES:
		var jm := InputEventJoypadMotion.new()
		jm.axis = PAD_AXES[action][0]
		jm.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, jm)
	for action in PAD_UI_BUTTONS:
		for b in PAD_UI_BUTTONS[action]:
			var ub := InputEventJoypadButton.new()
			ub.button_index = b
			InputMap.action_add_event(action, ub)
	for action in PAD_UI_AXES:
		var um := InputEventJoypadMotion.new()
		um.axis = PAD_UI_AXES[action][0]
		um.axis_value = PAD_UI_AXES[action][1]
		InputMap.action_add_event(action, um)
	InputMap.action_set_deadzone("ui_up", 0.5)
	InputMap.action_set_deadzone("ui_down", 0.5)
	InputMap.action_set_deadzone("ui_left", 0.5)
	InputMap.action_set_deadzone("ui_right", 0.5)


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		pad = true
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		pad = false
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(using_pad)


func aim_vector() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.3)


func key_hint(action: String) -> String:
	if using_pad:
		var names := {"roll": "A", "interact": "Y", "reload": "X", "ability_1": "LB", "ability_2": "RB", "ability_3": "B",
			"use_stim": "D-Up", "fire_primary": "RT", "fire_secondary": "LT", "inventory": "Back",
			"character": "D-Left", "pause": "Start", "swap_weapons": "D-Down", "recall": "R3"}
		return names.get(action, "?")
	var knames := {"fire_primary": "LMB", "fire_secondary": "RMB", "roll": "SPC", "pause": "Esc", "inventory": "I"}
	if knames.has(action):
		return knames[action]
	if KEYS.has(action):
		return OS.get_keycode_string(KEYS[action][0])
	return "?"
