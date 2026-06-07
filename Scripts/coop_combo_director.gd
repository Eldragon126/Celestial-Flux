extends Node
class_name CoopComboDirector
## Future co-op payoff layer. Network code can feed vector events here; the
## reward stays deterministic because it uses existing resonance/time systems.

signal coop_combo_triggered(combo_id: StringName, data: Dictionary)

@export var enabled: bool = true
@export var minimum_mastery_score: float = 0.78
@export var combo_resonance_radius: float = 340.0
@export var combo_resonance_duration: float = 2.8
@export var combo_slow_radius: float = 520.0
@export var combo_slow_duration: float = 0.55
@export var max_slow_targets: int = 24

var _sync_foundation: Node = null
var _resonance_manager: Node = null
var _time_manager: Node = null
var _player: Node2D = null


func _ready() -> void:
	add_to_group("coop_combo_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func register_remote_vector_event(player_id: StringName, event_data: Dictionary) -> void:
	if _sync_foundation != null and _sync_foundation.has_method("register_coop_vector_event"):
		_sync_foundation.call("register_coop_vector_event", player_id, event_data)


func _bootstrap() -> void:
	if not enabled:
		return
	_resolve_sources()
	_connect_sources()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = _get_local_player()
	if root == null:
		return
	_sync_foundation = root.find_child("MultiplayerSyncFoundation", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_time_manager = root.find_child("TimeDilationManager", true, false)


func _connect_sources() -> void:
	_connect_once(_player, &"slingshot_mastery_scored", Callable(self, "_on_local_mastery_scored"))
	_connect_once(_sync_foundation, &"coop_combo_window_started", Callable(self, "_on_combo_window_started"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _get_local_player() -> Node2D:
	return MultiplayerTargeting.local_player(get_tree())


func _on_local_mastery_scored(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < minimum_mastery_score:
		return
	if _sync_foundation != null and _sync_foundation.has_method("register_coop_vector_event"):
		_sync_foundation.call("register_coop_vector_event", &"local_player", data.duplicate(true))


func _on_combo_window_started(combo_data: Dictionary) -> void:
	var position := _combo_position(combo_data)
	var combo_id := _combo_id(combo_data)
	var data := {
		"combo_id": combo_id,
		"position": position,
		"radius": combo_resonance_radius,
		"source": combo_data.duplicate(true),
	}
	_spawn_combo_resonance(combo_id, position)
	_apply_combo_slow(position)
	coop_combo_triggered.emit(combo_id, data)


func _combo_id(combo_data: Dictionary) -> StringName:
	var second_value: Variant = combo_data.get("second_event", {})
	var second_event: Dictionary = {}
	if second_value is Dictionary:
		second_event = second_value
	var grade := StringName(second_event.get("grade", &"vector"))
	if grade == &"apex":
		return &"apex_dual_vector"
	if grade == &"perfect":
		return &"perfect_vector_cross"
	return &"shared_slingshot"


func _combo_position(combo_data: Dictionary) -> Vector2:
	var second_value: Variant = combo_data.get("second_event", {})
	var second_event: Dictionary = {}
	if second_value is Dictionary:
		second_event = second_value
	var position: Variant = second_event.get("position", null)
	if position is Vector2:
		return position
	if _player != null:
		return _player.global_position
	return Vector2.ZERO


func _spawn_combo_resonance(combo_id: StringName, position: Vector2) -> void:
	if _resonance_manager == null or not _resonance_manager.has_method("create_manual_resonance_zone"):
		return
	var zone_type := GravityResonanceManager.ZoneType.SLIPSTREAM
	if combo_id == &"apex_dual_vector":
		zone_type = GravityResonanceManager.ZoneType.HARMONIC_ORBIT
	elif combo_id == &"perfect_vector_cross":
		zone_type = GravityResonanceManager.ZoneType.INVERSION
	_resonance_manager.call(
		"create_manual_resonance_zone",
		position,
		combo_resonance_radius,
		zone_type,
		0.82,
		combo_resonance_duration
	)


func _apply_combo_slow(position: Vector2) -> void:
	if _time_manager == null or not _time_manager.has_method("apply_local_slow_to_target"):
		return
	var affected := 0
	for target in _nearby_threats(position):
		_time_manager.call("apply_local_slow_to_target", target, 0.5, combo_slow_duration)
		affected += 1
		if affected >= max_slow_targets:
			return


func _nearby_threats(position: Vector2) -> Array[Node]:
	var threats: Array[Node] = []
	var seen := {}
	for group_name in [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d := node as Node2D
			if node_2d == null or seen.has(node.get_instance_id()):
				continue
			if node_2d.global_position.distance_squared_to(position) > combo_slow_radius * combo_slow_radius:
				continue
			seen[node.get_instance_id()] = true
			threats.append(node)
			if threats.size() >= max_slow_targets:
				return threats
	return threats
