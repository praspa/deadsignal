extends Node
## Global signal bus. Systems talk through these signals instead of holding
## direct references to each other.

signal message(text: String, color: Color)
signal flag_set(flag: String)
signal objective_changed(text: String)
signal stats_changed
signal inventory_changed
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
signal boss_bar(name: String, hp: float, max_hp: float, visible: bool)
signal open_terminal(terminal_id: String, terminal: Node)
signal open_nav
signal open_stash
signal player_died
signal mission_complete
signal screen_shake(amount: float)
signal player_hurt(amount: float)
signal save_requested
signal ui_toggle(which: String)


func msg(text: String, color: Color = Color(0.85, 0.82, 0.75)) -> void:
	message.emit(text, color)
