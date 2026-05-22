extends Node
## Music-sync finale: beat timeline drives gravity pulses and hazard bursts.

signal finale_complete

const FINALE_TRACK := "res://Assets/Songs/Resonance.mp3"
const GRAVITY_TIDE_SCENE := preload("res://Nodes/gravity_tide_pocket.tscn")

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


func _ready() -> void:
	_level_root = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D

	_music = AudioStreamPlayer.new()
	_music.name = "FinaleMusic"
	add_child(_music)

	var stream := load(FINALE_TRACK) as AudioStream
	if stream != null:
		_music.stream = stream
		_music.play()
	else:
		push_warning("MusicFinaleDirector: missing Resonance.mp3")
		call_deferred("_finish")
		return

	_music.finished.connect(_finish)


func _process(delta: float) -> void:
	_elapsed += delta
	_advance_beats()

	if _music != null and not _music.playing and _elapsed > 1.0:
		_finish()


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
			_spawn_tide_near_player(1.15)
		&"burst":
			_spawn_tide_near_player(1.55)
			_pulse_arena()
		&"finale":
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


func _finish() -> void:
	set_process(false)
	finale_complete.emit()
