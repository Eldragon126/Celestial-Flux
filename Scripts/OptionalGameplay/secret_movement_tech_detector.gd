extends Node
class_name SecretMovementTechDetector

signal tech_discovered(tech_id: StringName, data: Dictionary)

@export var enabled: bool = true
@export var player_group_name: StringName = &"Player"
@export var scan_interval: float = 0.12
@export var high_speed_threshold: float = 1450.0
@export var close_orbit_radius: float = 220.0
@export var orbit_tangent_alignment: float = 0.84
@export var no_thrust_window_seconds: float = 1.2
@export var reverse_slingshot_speed_gain: float = 340.0

var _player: CharacterBody2D = null
var _scan_elapsed: float = 0.0
var _last_speed: float = 0.0
var _last_thrust_time: float = -999.0
var _unlocked: Dictionary = {}


func _ready() -> void:
	add_to_group("secret_movement_tech_detector")
	_resolve_player()
	_connect_player_signals()


func _process(delta: float) -> void:
	if not enabled:
		return
	_scan_elapsed += delta
	if _scan_elapsed < scan_interval:
		return
	_scan_elapsed = 0.0
	_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	var speed := _player.velocity.length()
	if speed >= high_speed_threshold:
		_discover(&"velocity_scream", {"speed": speed})
	_check_close_orbit(speed)
	if speed - _last_speed >= reverse_slingshot_speed_gain and Time.get_ticks_msec() * 0.001 - _last_thrust_time >= no_thrust_window_seconds:
		_discover(&"silent_slingshot", {"speed_gain": speed - _last_speed, "speed": speed})
	_last_speed = speed


func _check_close_orbit(speed: float) -> void:
	var source := _nearest_gravity_source()
	if source == null:
		return
	var offset := _player.global_position - source.global_position
	if offset.length() > close_orbit_radius or offset.length_squared() <= 0.001:
		return
	if speed <= 1.0:
		return
	var tangent_alignment := absf(_player.velocity.normalized().dot(offset.normalized().orthogonal()))
	if tangent_alignment >= orbit_tangent_alignment:
		_discover(&"needle_orbit", {"speed": speed, "radius": offset.length()})


func _discover(tech_id: StringName, data: Dictionary) -> void:
	if _unlocked.has(String(tech_id)):
		return
	_unlocked[String(tech_id)] = true
	var record := data.duplicate(true)
	record["timestamp_msec"] = Time.get_ticks_msec()
	if RunProgress != null:
		RunProgress.arena_flags["secret_movement_tech_%s" % String(tech_id)] = record
	tech_discovered.emit(tech_id, record)


func _on_player_thrust_used(_delta: float, _energy_cost: float) -> void:
	_last_thrust_time = Time.get_ticks_msec() * 0.001


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = MultiplayerTargeting.local_player(get_tree()) as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group(player_group_name) as CharacterBody2D
	_connect_player_signals()


func _connect_player_signals() -> void:
	if _player != null and _player.has_signal(&"thrust_used"):
		var callable := Callable(self, "_on_player_thrust_used")
		if not _player.is_connected(&"thrust_used", callable):
			_player.connect(&"thrust_used", callable)


func _nearest_gravity_source() -> Node2D:
	if _player == null:
		return null
	var sources: Array[Node2D] = []
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(_player.global_position, sources, 1, close_orbit_radius * 1.8, _player)
		return sources[0] if not sources.is_empty() else null
	var best: Node2D = null
	var best_distance := close_orbit_radius * close_orbit_radius * 3.24
	for value in get_tree().get_nodes_in_group("Objects_With_Gravity"):
		var candidate := value as Node2D
		if candidate == null or candidate == _player or not is_instance_valid(candidate):
			continue
		var distance := candidate.global_position.distance_squared_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
