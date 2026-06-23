extends Node
class_name MultiplayerSyncFoundation
## Passive deterministic sync/readability scaffold for future co-op.

signal sync_snapshot_ready(snapshot: Dictionary)
signal desync_risk_changed(risk: float, reason: StringName)
signal peer_readability_state_changed(peer_count: int, budget: Dictionary)
signal coop_combo_window_started(data: Dictionary)

@export var enabled: bool = true
@export var snapshot_interval: float = 0.25
@export var quantization_px: float = 2.0
@export var max_tracked_enemies: int = 48
@export var max_tracked_projectiles: int = 96
@export var max_tracked_gravity_sources: int = 24
@export var local_player_count: int = 1
@export var remote_peer_count: int = 0
@export var coop_combo_window_sec: float = 1.4

var _snapshot_timer: float = 0.0
var _last_snapshot: Dictionary = {}
var _last_desync_risk: float = -1.0
var _last_peer_count: int = -1
var _last_combo_event: Dictionary = {}
var _hash_nodes: Array[Node2D] = []


func _ready() -> void:
	add_to_group("multiplayer_sync_foundation")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(enabled)
	call_deferred("_emit_readability_budget")


func _process(delta: float) -> void:
	if not enabled:
		return
	_snapshot_timer += delta
	if _snapshot_timer < snapshot_interval:
		return
	_snapshot_timer = 0.0
	_last_snapshot = _build_snapshot()
	sync_snapshot_ready.emit(_last_snapshot.duplicate(true))
	_emit_desync_risk(_estimate_desync_risk())
	_emit_readability_budget()


func set_remote_peer_count(count: int) -> void:
	remote_peer_count = maxi(count, 0)
	_emit_readability_budget()


func register_coop_vector_event(player_id: StringName, event_data: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _last_combo_event.is_empty():
		var last_time := float(_last_combo_event.get("time", -999.0))
		var last_player := StringName(_last_combo_event.get("player_id", &""))
		if player_id != last_player and now - last_time <= coop_combo_window_sec:
			var combo := {
				"first_player": last_player,
				"second_player": player_id,
				"window": coop_combo_window_sec,
				"first_event": _last_combo_event.get("event", {}),
				"second_event": event_data,
			}
			coop_combo_window_started.emit(combo)
	_last_combo_event = {
		"player_id": player_id,
		"time": now,
		"event": event_data.duplicate(true),
	}


func get_sync_snapshot() -> Dictionary:
	if _last_snapshot.is_empty():
		_last_snapshot = _build_snapshot()
	return _last_snapshot.duplicate(true)


func get_readability_budget() -> Dictionary:
	var peer_count := maxi(local_player_count + remote_peer_count, 1)
	return {
		"peer_count": peer_count,
		"enemy_arrow_limit": maxi(10 - peer_count * 2, 4),
		"boss_arrow_limit": 2,
		"projectile_warning_limit": maxi(24 - peer_count * 3, 10),
		"solo_atmosphere_factor": clampf(1.0 - float(peer_count - 1) * 0.18, 0.46, 1.0),
	}


func _build_snapshot() -> Dictionary:
	var wave := 0
	var root := get_tree().current_scene
	var wave_director := root.find_child("WaveDirector", true, false) if root != null else null
	if wave_director != null and wave_director.has_method("get_current_wave"):
		wave = int(wave_director.call("get_current_wave"))

	return {
		"version": 1,
		"seed": int(RunProgress.run_seed if RunProgress != null else 0),
		"phase": int(RunProgress.phase if RunProgress != null else 0),
		"wave": wave,
		"gravity_hash": _hash_group(&"Objects_With_Gravity", max_tracked_gravity_sources),
		"enemy_hash": _hash_group(&"wave_enemy", max_tracked_enemies),
		"boss_hash": _hash_group(&"bosses", 8),
		"projectile_hash": _hash_group(&"enemy_projectiles", max_tracked_projectiles),
	}


func _hash_group(group_name: StringName, limit: int) -> int:
	_fill_hash_nodes(group_name, limit)
	_hash_nodes.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return String(a.name) < String(b.name)
	)

	var acc := 17
	var count := mini(_hash_nodes.size(), maxi(limit, 0))
	for i in range(count):
		var node := _hash_nodes[i]
		if not is_instance_valid(node):
			continue
		acc = _mix_hash(acc, _node_sync_token(node))
	return acc


func _fill_hash_nodes(group_name: StringName, limit: int) -> void:
	_hash_nodes.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(group_name, _hash_nodes, limit)
		return
	for value in get_tree().get_nodes_in_group(group_name):
		var node_2d := value as Node2D
		if node_2d != null and is_instance_valid(node_2d) and not node_2d.is_queued_for_deletion():
			_hash_nodes.append(node_2d)


func _node_sync_token(node: Node) -> String:
	var token := "%s:%s" % [String(node.scene_file_path), String(node.name)]
	var node_2d := node as Node2D
	if node_2d != null:
		var position := _quantize_vector(node_2d.global_position)
		token += ":p%d,%d" % [position.x, position.y]
	var velocity := _read_velocity(node)
	var q_velocity := _quantize_vector(velocity)
	token += ":v%d,%d" % [q_velocity.x, q_velocity.y]
	return token


func _read_velocity(node: Node) -> Vector2:
	var linear_value: Variant = node.get("linear_velocity")
	if linear_value is Vector2:
		return linear_value
	var velocity_value: Variant = node.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	return Vector2.ZERO


func _quantize_vector(value: Vector2) -> Vector2i:
	var step := maxf(quantization_px, 0.25)
	return Vector2i(roundi(value.x / step), roundi(value.y / step))


func _mix_hash(acc: int, token: String) -> int:
	return int(hash("%d|%s" % [acc, token]))


func _estimate_desync_risk() -> Dictionary:
	var projectile_count := _group_count(&"enemy_projectiles")
	var gravity_count := _group_count(&"Objects_With_Gravity")
	var risk := 0.0
	var reason := &"stable"
	if projectile_count > max_tracked_projectiles:
		risk += 0.35
		reason = &"projectile_budget"
	if gravity_count > max_tracked_gravity_sources:
		risk += 0.3
		reason = &"gravity_budget"
	return {"risk": clampf(risk, 0.0, 1.0), "reason": reason}


func _group_count(group_name: StringName) -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(group_name)
	return get_tree().get_nodes_in_group(group_name).size()


func _emit_desync_risk(data: Dictionary) -> void:
	var risk := float(data.get("risk", 0.0))
	if absf(risk - _last_desync_risk) < 0.08:
		return
	_last_desync_risk = risk
	desync_risk_changed.emit(risk, StringName(data.get("reason", &"stable")))


func _emit_readability_budget() -> void:
	var peer_count := maxi(local_player_count + remote_peer_count, 1)
	if peer_count == _last_peer_count:
		return
	_last_peer_count = peer_count
	peer_readability_state_changed.emit(peer_count, get_readability_budget())
