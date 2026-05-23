extends Node
## Music-sync finale: beat timeline drives gravity pulses and hazard bursts.

signal finale_complete

const FINALE_TRACK := "res://Assets/Songs/Resonance.mp3"
const GRAVITY_TIDE_SCENE := preload("res://Nodes/gravity_tide_pocket.tscn")
const MUSIC_RESONANCE_BOSS_SCENE := preload("res://Nodes/music_resonance_boss.tscn")

const BEAT_TIMELINE: Array = [
	{"t": 2.0, "id": &"pulse"},
	{"t": 5.5, "id": &"pulse"},
	{"t": 9.0, "id": &"burst"},
	{"t": 12.5, "id": &"pulse"},
	{"t": 16.0, "id": &"burst"},
	{"t": 20.0, "id": &"pulse"},
	{"t": 24.0, "id": &"finale"},
]

var _music: AudioStreamPlayer = null
var _elapsed: float = 0.0
var _beat_index: int = 0
var _player: Node2D = null
var _level_root: Node = null
var _boss: Node = null
var _fallback_attack_elapsed: float = 0.0
var _finale_finished: bool = false


func _ready() -> void:
	_level_root = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D

	_music = AudioStreamPlayer.new()
	_music.name = "FinaleMusic"
	add_child(_music)
	_spawn_finale_boss()

	var stream := load(FINALE_TRACK) as AudioStream
	if stream != null:
		_music.stream = stream
		_music.play()
	else:
		push_warning("MusicFinaleDirector: missing Resonance.mp3")
		_fire_beat(&"pulse")

	_music.finished.connect(_on_music_finished)


func _process(delta: float) -> void:
	_elapsed += delta
	_advance_beats()

	if _music != null and not _music.playing and _elapsed > 1.0 and _boss_alive():
		_fallback_attack_elapsed += delta
		if _fallback_attack_elapsed >= 3.2:
			_fallback_attack_elapsed = 0.0
			_fire_beat(&"burst")


func _advance_beats() -> void:
	while _beat_index < BEAT_TIMELINE.size():
		var entry: Dictionary = BEAT_TIMELINE[_beat_index]
		if _elapsed < float(entry.get("t", 0.0)):
			break
		_fire_beat(StringName(entry.get("id", &"")))
		_beat_index += 1


func _fire_beat(event_id: StringName) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	match event_id:
		&"pulse":
			_call_boss_beat(&"on_music_pulse", 1.0)
			_spawn_tide_near_player(1.15)
		&"burst":
			_call_boss_beat(&"on_music_burst", 1.0)
			_spawn_tide_near_player(1.55)
			_pulse_arena()
		&"finale":
			_call_boss_beat(&"on_music_finale", 1.0)
			_spawn_tide_near_player(2.0)
			_pulse_arena()


func _spawn_tide_near_player(scale: float) -> void:
	if _level_root == null:
		return
	var tide := GRAVITY_TIDE_SCENE.instantiate()
	tide.name = "FinaleTide_%d" % Time.get_ticks_msec()
	_level_root.add_child(tide)
	if tide is Node2D:
		var offset := Vector2.from_angle(randf() * TAU) * 420.0
		tide.global_position = _player.global_position + offset
	if tide.get("field_acceleration") != null:
		tide.set("field_acceleration", float(tide.get("field_acceleration")) * scale)


func _pulse_arena() -> void:
	if _level_root == null:
		return
	var arena := _level_root.find_child("ArenaDestabilizationManager", true, false)
	if arena != null and arena.has_method("force_arena_event"):
		arena.call("force_arena_event", &"finale_storm")


func _spawn_finale_boss() -> void:
	if _level_root == null or _boss_alive():
		return

	_boss = MUSIC_RESONANCE_BOSS_SCENE.instantiate()
	_boss.name = "TheResonanceSingularity"
	_level_root.add_child(_boss)
	if _boss is Node2D:
		var spawn_position := Vector2.ZERO
		if _player != null and is_instance_valid(_player):
			spawn_position = _player.global_position + Vector2(0.0, -720.0)
		(_boss as Node2D).global_position = spawn_position
	if _boss.has_signal("boss_defeated"):
		_boss.connect("boss_defeated", Callable(self, "_on_boss_defeated"))


func _call_boss_beat(method_name: StringName, intensity: float) -> void:
	if _boss_alive() and _boss.has_method(method_name):
		_boss.call(method_name, intensity)


func _boss_alive() -> bool:
	return _boss != null and is_instance_valid(_boss) and not _boss.is_queued_for_deletion()


func _on_music_finished() -> void:
	if not _boss_alive():
		_finish()


func _on_boss_defeated() -> void:
	_finish()


func _finish() -> void:
	if _finale_finished:
		return
	_finale_finished = true
	set_process(false)
	if _music != null:
		_music.stop()
	finale_complete.emit()
