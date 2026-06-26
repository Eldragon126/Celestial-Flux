extends Node2D
class_name AnomalyGhostEcho

signal echo_saved(rift_id: StringName, clear_time: float, sample_count: int)
signal time_scar_touched(sample_index: int)

@export var enabled: bool = true
@export var player_group_name: StringName = &"Player"
@export var director_group_name: StringName = &"optional_challenge_director"
@export var sample_interval: float = 0.08
@export var max_samples: int = 720
@export var echo_delay_seconds: float = 1.2
@export var time_scar_danger_radius: float = 34.0
@export var time_scar_arm_delay: float = 0.85
@export var ghost_line_width: float = 2.0
@export var ghost_line_color: Color = Color(0.42, 1.0, 0.86, 0.28)
@export var scar_line_color: Color = Color(1.0, 0.34, 0.18, 0.38)
@export var fail_rift_on_time_scar_touch: bool = false

var current_rift_id: StringName = &""
var recording_enabled: bool = false
var time_scar_enabled: bool = false
var ghost_echo_required: bool = false

var _player: CharacterBody2D = null
var _samples: Array[Dictionary] = []
var _sample_elapsed: float = 0.0
var _recording_elapsed: float = 0.0
var _line: Line2D = null
var _ghost_marker: Polygon2D = null


func _ready() -> void:
	_build_visuals()
	set_process(true)


func configure_from_rift(config) -> void:
	if config == null:
		set_recording_enabled(false)
		return
	current_rift_id = config.rift_id
	time_scar_enabled = config.time_scar_trail_enabled
	ghost_echo_required = config.ghost_echo_required
	recording_enabled = enabled
	restart_recording()


func set_recording_enabled(value: bool) -> void:
	recording_enabled = value and enabled
	if _line != null:
		_line.visible = recording_enabled
	if _ghost_marker != null:
		_ghost_marker.visible = recording_enabled and ghost_echo_required


func restart_recording() -> void:
	_samples.clear()
	_sample_elapsed = sample_interval
	_recording_elapsed = 0.0
	set_recording_enabled(true)
	_update_line()


func save_best_run(rift_id: StringName, clear_time: float) -> void:
	var serial_samples: Array[Dictionary] = []
	for sample in _samples:
		var pos: Vector2 = sample.get("position", Vector2.ZERO)
		serial_samples.append({
			"x": pos.x,
			"y": pos.y,
			"rotation": float(sample.get("rotation", 0.0)),
			"t": float(sample.get("t", 0.0)),
		})
	if RunProgress != null:
		RunProgress.arena_flags["blackbox_ghost_%s" % String(rift_id)] = {
			"clear_time": clear_time,
			"samples": serial_samples,
		}
	echo_saved.emit(rift_id, clear_time, serial_samples.size())


func _process(delta: float) -> void:
	if not recording_enabled:
		return
	_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	_recording_elapsed += delta
	_sample_elapsed += delta
	if _sample_elapsed >= sample_interval:
		_sample_elapsed = 0.0
		_record_sample()
	_update_line()
	_update_ghost_marker()
	if time_scar_enabled and _recording_elapsed >= time_scar_arm_delay:
		_check_time_scar_contact()


func _record_sample() -> void:
	_samples.append({
		"position": _player.global_position,
		"rotation": _player.global_rotation,
		"t": _recording_elapsed,
	})
	while _samples.size() > max_samples:
		_samples.remove_at(0)


func _check_time_scar_contact() -> void:
	var latest_safe_time := _recording_elapsed - time_scar_arm_delay
	for index in range(_samples.size()):
		var sample := _samples[index]
		if float(sample.get("t", 0.0)) > latest_safe_time:
			continue
		var pos: Vector2 = sample.get("position", Vector2.ZERO)
		if _player.global_position.distance_to(pos) <= time_scar_danger_radius:
			_player.set_meta(&"time_scar_touched", Time.get_ticks_msec() * 0.001)
			time_scar_touched.emit(index)
			if fail_rift_on_time_scar_touch:
				var director := get_tree().get_first_node_in_group(director_group_name)
				if director != null and director.has_method("fail_rift"):
					director.call("fail_rift", &"time_scar")
			return


func _update_line() -> void:
	if _line == null:
		return
	var points := PackedVector2Array()
	for sample in _samples:
		points.append(to_local(sample.get("position", Vector2.ZERO)))
	_line.points = points
	_line.default_color = scar_line_color if time_scar_enabled else ghost_line_color


func _update_ghost_marker() -> void:
	if _ghost_marker == null:
		return
	_ghost_marker.visible = ghost_echo_required and recording_enabled and _samples.size() > 1
	if not _ghost_marker.visible:
		return
	var target_time := _recording_elapsed - echo_delay_seconds
	var best := _samples[0]
	for sample in _samples:
		if float(sample.get("t", 0.0)) > target_time:
			break
		best = sample
	_ghost_marker.global_position = best.get("position", global_position)
	_ghost_marker.global_rotation = float(best.get("rotation", 0.0))


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = MultiplayerTargeting.local_player(get_tree()) as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group(player_group_name) as CharacterBody2D


func _build_visuals() -> void:
	if _line == null:
		_line = Line2D.new()
		_line.name = "AnomalyGhostTrail"
		_line.antialiased = true
		_line.width = ghost_line_width
		_line.z_index = 12
		add_child(_line)
	if _ghost_marker == null:
		_ghost_marker = Polygon2D.new()
		_ghost_marker.name = "AnomalyGhostMarker"
		_ghost_marker.polygon = PackedVector2Array([
			Vector2(28.0, 0.0),
			Vector2(-14.0, 13.0),
			Vector2(-8.0, 0.0),
			Vector2(-14.0, -13.0),
		])
		_ghost_marker.color = Color(0.42, 1.0, 0.86, 0.34)
		_ghost_marker.z_index = 14
		add_child(_ghost_marker)
