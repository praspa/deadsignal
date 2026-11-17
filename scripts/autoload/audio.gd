extends Node
## Music and sound effects. All audio is synthesised offline by tools/gen_audio.py
## into res://audio/ (sfx/<name>_<n>.wav variants, music/<track>.wav loops).
##
##   Audio.play("rifle", world_pos)        positional (world / ground-plane coords)
##   Audio.play_screen("boss_shot", sp)    positional, already in screen space
##   Audio.play_ui("terminal")             non-positional
##   Audio.music("level") / Audio.music("")  cross-fades loops (""=fade out)

## name: [variants, volume dB, max simultaneous voices, min seconds between starts]
const SFX := {
	"rifle": [2, -4.0, 6, 0.03],
	"shotgun": [1, -2.0, 3, 0.05],
	"heavy_shot": [1, -6.0, 6, 0.04],
	"laser": [2, -6.0, 4, 0.03],
	"enemy_bolt": [1, -8.0, 4, 0.05],
	"grenade_launch": [1, -4.0, 2, 0.1],
	"explosion": [2, -1.0, 4, 0.06],
	"swing": [2, -5.0, 2, 0.05],
	"swing_heavy": [1, -3.0, 2, 0.05],
	"chainblade": [1, -9.0, 2, 0.05],
	"melee_hit": [1, -3.0, 3, 0.04],
	"impact_flesh": [2, -8.0, 4, 0.04],
	"impact_metal": [2, -12.0, 4, 0.05],
	"zombie_groan": [3, -5.0, 3, 0.4],
	"zombie_snarl": [2, -4.0, 3, 0.15],
	"zombie_hurt": [2, -6.0, 3, 0.12],
	"zombie_death": [1, -4.0, 3, 0.1],
	"player_hurt": [2, -5.0, 1, 0.3],
	"player_death": [1, -2.0, 1, 0.5],
	"robot_chatter": [4, -16.0, 3, 0.3],
	"robot_alert": [1, -15.0, 2, 0.15],
	"robot_hurt": [1, -15.0, 3, 0.1],
	"robot_death": [1, -8.0, 3, 0.1],
	"boss_alarm": [1, -12.0, 1, 1.0],
	"boss_charge": [1, -7.0, 1, 0.5],
	"boss_laser": [1, -8.0, 1, 0.5],
	"boss_shot": [1, -16.0, 3, 0.06],
	"pulse": [1, -3.0, 1, 0.2],
	"overcharge": [1, -6.0, 1, 0.5],
	"stim": [1, -6.0, 1, 0.2],
	"dodge": [1, -6.0, 1, 0.1],
	"reload": [1, -6.0, 1, 0.2],
	"pickup": [1, -8.0, 2, 0.08],
	"door": [1, -4.0, 2, 0.2],
	"crate": [1, -4.0, 2, 0.2],
	"terminal": [1, -16.0, 1, 0.2],
	"levelup": [1, -6.0, 1, 0.5],
}
const MUSIC_DB := -11.0
const POOL := 32
const HEAR_DIST := 1300.0   # screen px

var _streams := {}        # name -> Array[AudioStream]
var _last := {}           # name -> msec of last start
var _pool: Array[AudioStreamPlayer2D] = []
var _ui: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _tracks := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for sname in SFX:
		var arr: Array = []
		for k in int(SFX[sname][0]):
			var s := load("res://audio/sfx/%s_%d.wav" % [sname, k + 1]) as AudioStream
			if s != null:
				arr.append(s)
		_streams[sname] = arr
	for t in ["level", "boss"]:
		var w := load("res://audio/music/%s.wav" % t) as AudioStreamWAV
		if w != null:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
			_tracks[t] = w
	for i in POOL:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = HEAR_DIST
		p.attenuation = 1.4
		p.panning_strength = 0.6
		add_child(p)
		_pool.append(p)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = "SFX"
		add_child(u)
		_ui.append(u)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)


## True if every sound and track loaded (used by the smoke test).
func all_loaded() -> bool:
	for sname in SFX:
		if (_streams.get(sname, []) as Array).size() != int(SFX[sname][0]):
			return false
	return _tracks.size() == 2


func _allowed(sname: String) -> bool:
	if not _streams.has(sname) or (_streams[sname] as Array).is_empty():
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sname, -100000)) < int(float(SFX[sname][3]) * 1000.0):
		return false
	var playing := 0
	for p in _pool:
		if p.playing and p.get_meta("sfx", "") == sname:
			playing += 1
	if playing >= int(SFX[sname][2]):
		return false
	_last[sname] = now
	return true


func _pick(sname: String) -> AudioStream:
	var arr: Array = _streams[sname]
	return arr[randi() % arr.size()]


## Positional sound at a world (ground-plane) position.
func play(sname: String, world_pos: Vector2, pitch := 1.0, vol := 0.0) -> void:
	play_screen(sname, Iso.sp(world_pos, 20), pitch, vol)


## Positional sound at a screen-space position (Fx / camera space).
func play_screen(sname: String, screen_pos: Vector2, pitch := 1.0, vol := 0.0) -> void:
	if not _allowed(sname):
		return
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.get_screen_center_position().distance_to(screen_pos) > HEAR_DIST:
		return
	var best: AudioStreamPlayer2D = null
	for p in _pool:
		if not p.playing:
			best = p
			break
	if best == null:
		return
	best.set_meta("sfx", sname)
	best.stream = _pick(sname)
	best.global_position = screen_pos
	best.volume_db = float(SFX[sname][1]) + vol
	best.pitch_scale = pitch * randf_range(0.94, 1.06)
	best.play()


## Non-positional sound (UI, the player's own voice).
func play_ui(sname: String, pitch := 1.0, vol := 0.0) -> void:
	if not _allowed(sname):
		return
	for u in _ui:
		if not u.playing:
			u.stream = _pick(sname)
			u.volume_db = float(SFX[sname][1]) + vol
			u.pitch_scale = pitch * randf_range(0.96, 1.04)
			u.play()
			return


## Cross-fades to a music loop; "" fades out.
func music(track: String, fade := 1.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	var old: AudioStreamPlayer = _music_a if _music_a.playing else (_music_b if _music_b.playing else null)
	var nxt := _music_b if old == _music_a else _music_a
	if old != null:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -80.0, fade)
		tw.tween_callback(old.stop)
	if track != "" and _tracks.has(track):
		nxt.stream = _tracks[track]
		nxt.volume_db = -40.0
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", MUSIC_DB, fade * 0.7)


## Stops every positional sound (leaving a level).
func stop_all() -> void:
	for p in _pool:
		p.stop()
