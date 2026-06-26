extends Node
class_name StyleContractTracker

signal contract_started(contract_id: StringName)
signal contract_failed(contract_id: StringName, reason: StringName)
signal contract_progressed(contract_id: StringName, progress: Dictionary)

const CONTRACT_TYPE_NONE := 0
const CONTRACT_TYPE_NO_DASH := 1
const CONTRACT_TYPE_PERFECT_ORBIT := 2
const CONTRACT_TYPE_PACIFIST := 3
const CONTRACT_TYPE_GLASS := 4
const CONTRACT_TYPE_SPEED := 5
const CONTRACT_TYPE_NO_THRUST := 6
const CONTRACT_TYPE_CLEAN_VECTOR := 7

@export var enabled: bool = true
@export var player_group_name: StringName = &"Player"
@export var director_group_name: StringName = &"optional_challenge_director"
@export var no_thrust_allowed_seconds: float = 0.08
@export var clean_vector_turn_threshold_degrees: float = 118.0
@export var clean_vector_violation_grace: int = 2
@export var perfect_orbit_scan_radius: float = 1350.0
@export var perfect_orbit_min_tangent_speed: float = 360.0
@export var perfect_orbit_radial_tolerance: float = 0.34
@export var progress_emit_interval: float = 0.25
@export var glass_player_damage_meta: StringName = &"last_damage_time"
@export var pacifist_projectile_meta: StringName = &"recent_weapon_fire_time"

var current_contract = null
var current_rift = null
var active: bool = false
var failed: bool = false
var elapsed: float = 0.0
var dash_count: int = 0
var thrust_seconds: float = 0.0
var orbit_seconds: float = 0.0
var clean_vector_violations: int = 0
var max_speed_seen: float = 0.0

var _player: CharacterBody2D = null
var _last_velocity: Vector2 = Vector2.ZERO
var _progress_elapsed: float = 999.0
var _connected_player_id: int = 0


func begin_tracking(contract, rift = null) -> void:
	_disconnect_player_signals()
	current_contract = contract
	current_rift = rift
	active = enabled and current_contract != null and int(current_contract.get("contract_type")) != CONTRACT_TYPE_NONE
	failed = false
	elapsed = 0.0
	dash_count = 0
	thrust_seconds = 0.0
	orbit_seconds = 0.0
	clean_vector_violations = 0
	max_speed_seen = 0.0
	_progress_elapsed = 999.0
	_resolve_player()
	_connect_player_signals()
	if _player != null:
		_last_velocity = _player.velocity
	if active:
		contract_started.emit(StringName(str(current_contract.get("contract_id"))))


func update_contract_time(time_seconds: float) -> void:
	elapsed = maxf(time_seconds, elapsed)


func is_contract_successful() -> bool:
	if current_contract == null or int(current_contract.get("contract_type")) == CONTRACT_TYPE_NONE:
		return true
	if failed:
		return false
	match int(current_contract.get("contract_type")):
		CONTRACT_TYPE_NO_DASH:
			return dash_count <= 0
		CONTRACT_TYPE_NO_THRUST:
			return thrust_seconds <= no_thrust_allowed_seconds
		CONTRACT_TYPE_PERFECT_ORBIT:
			return orbit_seconds >= maxf(float(current_contract.get("required_orbit_chain")), 1.0)
		CONTRACT_TYPE_SPEED:
			return elapsed <= maxf(float(current_contract.get("time_limit_seconds")), 0.01)
		CONTRACT_TYPE_CLEAN_VECTOR:
			return clean_vector_violations <= clean_vector_violation_grace
	return not failed


func get_progress() -> Dictionary:
	return {
		"active": active,
		"failed": failed,
		"contract_id": str(current_contract.get("contract_id")) if current_contract != null else "",
		"elapsed": elapsed,
		"dash_count": dash_count,
		"thrust_seconds": thrust_seconds,
		"orbit_seconds": orbit_seconds,
		"clean_vector_violations": clean_vector_violations,
		"max_speed_seen": max_speed_seen,
	}


func _process(delta: float) -> void:
	if not active or current_contract == null:
		return
	elapsed += delta
	_progress_elapsed += delta
	_resolve_player()
	_update_motion_samples(delta)
	_check_contract_conditions()
	if _progress_elapsed >= progress_emit_interval:
		_progress_elapsed = 0.0
		contract_progressed.emit(StringName(str(current_contract.get("contract_id"))), get_progress())


func _update_motion_samples(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var speed := _player.velocity.length()
	max_speed_seen = maxf(max_speed_seen, speed)
	if int(current_contract.get("contract_type")) == CONTRACT_TYPE_PERFECT_ORBIT:
		orbit_seconds += _orbit_quality_delta(delta)
	if int(current_contract.get("contract_type")) == CONTRACT_TYPE_CLEAN_VECTOR:
		_sample_clean_vector()
	_last_velocity = _player.velocity


func _check_contract_conditions() -> void:
	if failed:
		return
	match int(current_contract.get("contract_type")):
		CONTRACT_TYPE_NO_DASH:
			if dash_count > 0:
				_fail(&"dash_used")
		CONTRACT_TYPE_NO_THRUST:
			if thrust_seconds > no_thrust_allowed_seconds:
				_fail(&"thrust_used")
		CONTRACT_TYPE_PACIFIST:
			if _recent_meta_time(pacifist_projectile_meta):
				_fail(&"weapon_fired")
		CONTRACT_TYPE_GLASS:
			if _recent_meta_time(glass_player_damage_meta):
				_fail(&"player_damaged")
		CONTRACT_TYPE_SPEED:
			if elapsed > maxf(float(current_contract.get("time_limit_seconds")), 0.01):
				_fail(&"time_limit")
		CONTRACT_TYPE_CLEAN_VECTOR:
			if clean_vector_violations > clean_vector_violation_grace:
				_fail(&"dirty_vector")


func _on_player_dash_used(_kind: StringName) -> void:
	dash_count += 1
	_check_contract_conditions()


func _on_player_thrust_used(delta: float, _energy_cost: float) -> void:
	thrust_seconds += maxf(delta, 0.0)
	_check_contract_conditions()


func _orbit_quality_delta(delta: float) -> float:
	var source := _nearest_gravity_source()
	if source == null:
		return 0.0
	var offset := _player.global_position - source.global_position
	if offset.length_squared() <= 0.001:
		return 0.0
	var velocity := _player.velocity
	var speed := velocity.length()
	if speed < perfect_orbit_min_tangent_speed:
		return 0.0
	var radial_alignment := absf(velocity.normalized().dot(offset.normalized()))
	if radial_alignment > clampf(perfect_orbit_radial_tolerance, 0.01, 0.98):
		return 0.0
	return delta


func _sample_clean_vector() -> void:
	if _last_velocity.length_squared() <= 16.0 or _player.velocity.length_squared() <= 16.0:
		return
	var angle_delta := absf(rad_to_deg(_last_velocity.angle_to(_player.velocity)))
	if angle_delta > clean_vector_turn_threshold_degrees:
		clean_vector_violations += 1


func _nearest_gravity_source() -> Node2D:
	if _player == null:
		return null
	var sources: Array[Node2D] = []
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(_player.global_position, sources, 1, perfect_orbit_scan_radius, _player)
		return sources[0] if not sources.is_empty() else null
	var best: Node2D = null
	var best_distance := perfect_orbit_scan_radius * perfect_orbit_scan_radius
	for value in get_tree().get_nodes_in_group("Objects_With_Gravity"):
		var candidate := value as Node2D
		if candidate == null or candidate == _player or not is_instance_valid(candidate):
			continue
		var distance := _player.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _recent_meta_time(meta_name: StringName) -> bool:
	if _player == null or not _player.has_meta(meta_name):
		return false
	var value: Variant = _player.get_meta(meta_name)
	if value is float or value is int:
		return Time.get_ticks_msec() * 0.001 - float(value) <= 0.2
	return bool(value)


func _fail(reason: StringName) -> void:
	if failed or current_contract == null:
		return
	failed = true
	contract_failed.emit(StringName(str(current_contract.get("contract_id"))), reason)
	if bool(current_contract.get("failure_fails_rift")):
		var director := get_tree().get_first_node_in_group(director_group_name)
		if director != null and director.has_method("fail_rift"):
			director.call("fail_rift", reason)


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = MultiplayerTargeting.local_player(get_tree()) as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group(player_group_name) as CharacterBody2D
	_connect_player_signals()


func _connect_player_signals() -> void:
	if _player == null or _connected_player_id == _player.get_instance_id():
		return
	_disconnect_player_signals()
	_connected_player_id = _player.get_instance_id()
	if _player.has_signal(&"dash_used"):
		var dash_callable := Callable(self, "_on_player_dash_used")
		if not _player.is_connected(&"dash_used", dash_callable):
			_player.connect(&"dash_used", dash_callable)
	if _player.has_signal(&"thrust_used"):
		var thrust_callable := Callable(self, "_on_player_thrust_used")
		if not _player.is_connected(&"thrust_used", thrust_callable):
			_player.connect(&"thrust_used", thrust_callable)


func _disconnect_player_signals() -> void:
	if _player == null or not is_instance_valid(_player):
		_connected_player_id = 0
		return
	var dash_callable := Callable(self, "_on_player_dash_used")
	if _player.has_signal(&"dash_used") and _player.is_connected(&"dash_used", dash_callable):
		_player.disconnect(&"dash_used", dash_callable)
	var thrust_callable := Callable(self, "_on_player_thrust_used")
	if _player.has_signal(&"thrust_used") and _player.is_connected(&"thrust_used", thrust_callable):
		_player.disconnect(&"thrust_used", thrust_callable)
	_connected_player_id = 0
