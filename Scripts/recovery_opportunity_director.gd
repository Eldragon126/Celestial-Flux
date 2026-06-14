extends Node2D
class_name RecoveryOpportunityDirector

signal recovery_opportunity_started(opportunity_id: StringName, data: Dictionary)
signal recovery_opportunity_resolved(opportunity_id: StringName, data: Dictionary)
signal near_miss_recorded(data: Dictionary)

const WORMHOLE_PAIR_SCENE = preload("res://Nodes/wormhole_pair.tscn")

@export var enabled: bool = true
@export var sample_interval: float = 0.16
@export var cooldown: float = 18.0
@export var critical_health_threshold: float = 0.28
@export var critical_shield_threshold: float = 0.18
@export var threat_radius: float = 520.0
@export var lethal_collision_speed: float = 780.0
@export var max_targets_per_window: int = 24
@export var opportunity_duration: float = 4.2
@export var min_wave: int = 2
@export_group("Success Rewards")
@export var success_energy_restore: float = 62.0
@export var success_shield_restore: float = 22.0
@export var success_cooldown_refund: float = 4.0
@export var success_drop_count: int = 2
@export var success_drop_spread_radius: float = 72.0

var _player: Node2D = null
var _health_component: Node = null
var _momentum_component: Node = null
var _time_manager: Node = null
var _resonance_manager: Node = null
var _arena_manager: Node = null
var _wave_director: Node = null
var _sample_elapsed: float = 999.0
var _cooldown_remaining: float = 0.0
var _last_health_ratio: float = 1.0
var _last_near_miss_time: float = -999.0
var _sequence: int = 0
var _active_windows: Array[Dictionary] = []
var _targets: Array[Node2D] = []
var _notice_canvas: CanvasLayer = null
var _notice_label: Label = null


func _ready() -> void:
	add_to_group("recovery_opportunity_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_notice()
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_sample_elapsed += delta
	_update_active_windows(delta)
	_update_notice(delta)
	if _sample_elapsed < maxf(sample_interval, 0.05):
		return
	_sample_elapsed = 0.0
	_resolve_sources()
	_try_start_recovery_window()


func _bootstrap() -> void:
	_resolve_sources()
	_connect_player_signals()


func _try_start_recovery_window() -> void:
	if _player == null or _cooldown_remaining > 0.0 or _current_wave() < min_wave:
		return
	var danger := _danger_score()
	if danger < 0.74:
		return
	var opportunity_id := _choose_opportunity(danger)
	_start_opportunity(opportunity_id, danger)


func _start_opportunity(opportunity_id: StringName, danger: float) -> void:
	_sequence += 1
	_cooldown_remaining = cooldown
	var data := {
		"id": opportunity_id,
		"danger": danger,
		"position": _player.global_position,
		"velocity": _player_velocity(),
		"duration": opportunity_duration,
		"sequence": _sequence,
	}
	_active_windows.append({"id": opportunity_id, "age": 0.0, "duration": opportunity_duration, "data": data})
	_set_notice(_opportunity_display(opportunity_id), _opportunity_color(opportunity_id))
	match opportunity_id:
		&"slingshot_escape":
			_create_slingshot_escape(data)
		&"wormhole_exit":
			_create_wormhole_exit(data)
		&"resonance_rebound":
			_create_resonance_rebound(data)
		&"momentum_chain":
			_create_momentum_chain(data)
		&"time_dilation_window":
			_create_time_window(data)
	recovery_opportunity_started.emit(opportunity_id, data.duplicate(true))


func _update_active_windows(delta: float) -> void:
	for i in range(_active_windows.size() - 1, -1, -1):
		var entry := _active_windows[i]
		var age := float(entry.get("age", 0.0)) + delta
		var duration := float(entry.get("duration", opportunity_duration))
		entry["age"] = age
		_active_windows[i] = entry
		if age >= duration:
			var resolved_data: Dictionary = entry.get("data", {}).duplicate(true)
			resolved_data["danger_after"] = _danger_score()
			var success := _recovery_window_succeeded(entry)
			resolved_data["success"] = success
			resolved_data["resolved_position"] = _player.global_position if _player != null else global_position
			if success:
				_apply_success_reward(resolved_data)
			recovery_opportunity_resolved.emit(StringName(entry.get("id", &"unknown")), resolved_data)
			_active_windows.remove_at(i)


func _create_slingshot_escape(data: Dictionary) -> void:
	var tangent := _player_velocity().orthogonal().normalized()
	var center: Vector2 = data.get("position", global_position) + _player_velocity().normalized() * 180.0 + tangent * 160.0
	_create_zone(center, 300.0, GravityResonanceManager.ZoneType.SLIPSTREAM, 0.72, opportunity_duration)
	_create_zone(center + tangent * 220.0, 220.0, GravityResonanceManager.ZoneType.HARMONIC_ORBIT, 0.58, opportunity_duration)


func _create_wormhole_exit(data: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var wormhole := WORMHOLE_PAIR_SCENE.instantiate()
	root.add_child(wormhole)
	var direction := _player_velocity().normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var start: Vector2 = data.get("position", global_position) + direction * 210.0
	var exit := start + direction * 820.0 + direction.orthogonal() * 260.0
	if wormhole.has_method("set_endpoint_positions"):
		wormhole.call("set_endpoint_positions", start, exit)
	if wormhole is Node:
		var wormhole_node := wormhole as Node
		wormhole_node.tree_exited.connect(Callable(self, "_on_window_helper_exited"))
		get_tree().create_timer(opportunity_duration + 1.0).timeout.connect(Callable(self, "_queue_free_if_valid").bind(wormhole_node))


func _create_resonance_rebound(data: Dictionary) -> void:
	var direction := _player_velocity().normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var center: Vector2 = data.get("position", global_position) - direction * 180.0
	_create_zone(center, 340.0, GravityResonanceManager.ZoneType.INVERSION, 0.7, opportunity_duration)
	_apply_slow_to_nearby_threats(center, 420.0, 0.62, 0.62)


func _create_momentum_chain(data: Dictionary) -> void:
	if _player == null:
		return
	var velocity := _player_velocity()
	var direction := velocity.normalized() if velocity.length_squared() > 1.0 else -_player.transform.x.normalized()
	CombatStatus.add_velocity(_player, direction * 360.0)
	_player.set_meta(&"recovery_momentum_chain_until", _now_seconds() + opportunity_duration)
	_create_zone(_player.global_position + direction * 260.0, 260.0, GravityResonanceManager.ZoneType.HARMONIC_ORBIT, 0.54, opportunity_duration)


func _create_time_window(data: Dictionary) -> void:
	if _time_manager != null and _time_manager.has_method("add_near_miss_charge"):
		_time_manager.call("add_near_miss_charge", 36.0)
	_apply_slow_to_nearby_threats(data.get("position", global_position), threat_radius, 0.46, 0.82)


func _create_zone(position: Vector2, radius: float, zone_type: int, intensity: float, duration: float) -> void:
	if _resonance_manager != null and _resonance_manager.has_method("create_manual_resonance_zone"):
		_resonance_manager.call("create_manual_resonance_zone", position, radius, zone_type, intensity, duration)


func _apply_slow_to_nearby_threats(center: Vector2, radius: float, multiplier: float, duration: float) -> void:
	_targets.clear()
	var groups: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"]
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, max_targets_per_window, false, _targets)
	else:
		var radius_sq := radius * radius
		for group_name in groups:
			for node in get_tree().get_nodes_in_group(group_name):
				var node_2d := node as Node2D
				if node_2d == null or node_2d.global_position.distance_squared_to(center) > radius_sq:
					continue
				_targets.append(node_2d)
				if _targets.size() >= max_targets_per_window:
					break
	for target in _targets:
		if _time_manager != null and _time_manager.has_method("apply_local_slow_to_target"):
			_time_manager.call("apply_local_slow_to_target", target, multiplier, duration)
		else:
			CombatStatus.apply_local_slow(target, multiplier, duration)


func _danger_score() -> float:
	var health_pressure := 1.0 - _health_ratio()
	var shield_pressure := 1.0 - _shield_ratio()
	var speed_pressure := clampf(_player_velocity().length() / maxf(lethal_collision_speed, 1.0), 0.0, 1.2)
	var threat_pressure := clampf(float(_nearby_threat_count()) / 5.0, 0.0, 1.0)
	var near_miss_pressure := 1.0 if _now_seconds() - _last_near_miss_time < 1.2 else 0.0
	if health_pressure < 1.0 - critical_health_threshold and shield_pressure < 1.0 - critical_shield_threshold:
		return 0.0
	return clampf(health_pressure * 0.38 + shield_pressure * 0.18 + speed_pressure * 0.18 + threat_pressure * 0.18 + near_miss_pressure * 0.08, 0.0, 1.2)


func _nearby_threat_count() -> int:
	if _player == null:
		return 0
	_targets.clear()
	var groups: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"]
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, _player.global_position, threat_radius, max_targets_per_window, false, _targets)
		return _targets.size()
	var radius_sq := threat_radius * threat_radius
	var count := 0
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d := node as Node2D
			if node_2d != null and node_2d.global_position.distance_squared_to(_player.global_position) <= radius_sq:
				count += 1
				if count >= max_targets_per_window:
					return count
	return count


func _choose_opportunity(danger: float) -> StringName:
	var choices: Array[StringName] = [&"slingshot_escape", &"resonance_rebound", &"time_dilation_window", &"momentum_chain"]
	if danger >= 0.86:
		choices.append(&"wormhole_exit")
	var seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return choices[absi(hash("%d:%d:%d:%d" % [seed, _current_wave(), _sequence, int(danger * 1000.0)])) % choices.size()]


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	if ratio <= critical_health_threshold and _last_health_ratio > ratio:
		_record_near_miss({
			"type": &"critical_health_survival",
			"health_ratio": ratio,
			"position": _player.global_position if _player != null else global_position,
			"wave": _current_wave(),
		})
	_last_health_ratio = ratio


func _on_near_miss_velocity_gained(target: Node, amount: float) -> void:
	_last_near_miss_time = _now_seconds()
	_record_near_miss({
		"type": &"gravity_near_miss",
		"target_key": String(target.name) if target != null else "",
		"amount": amount,
		"position": _player.global_position if _player != null else global_position,
		"wave": _current_wave(),
	})


func _record_near_miss(data: Dictionary) -> void:
	if RunProgress != null:
		RunProgress.arena_flags["near_miss_events"] = int(RunProgress.arena_flags.get("near_miss_events", 0)) + 1
		var recent_value: Variant = RunProgress.arena_flags.get("near_miss_recent", [])
		var recent: Array = recent_value if recent_value is Array else []
		recent.append(data.duplicate(true))
		while recent.size() > 12:
			recent.pop_front()
		RunProgress.arena_flags["near_miss_recent"] = recent
	near_miss_recorded.emit(data)


func _recovery_window_succeeded(entry: Dictionary) -> bool:
	if _player == null or not is_instance_valid(_player) or not _player_alive():
		return false
	var data: Dictionary = entry.get("data", {})
	var start_position: Vector2 = data.get("position", _player.global_position)
	var escape_distance := _player.global_position.distance_to(start_position)
	var danger_after := _danger_score()
	return danger_after < 0.58 or escape_distance > threat_radius * 0.72 or _player_velocity().length() < lethal_collision_speed * 0.58


func _apply_success_reward(data: Dictionary) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - success_cooldown_refund, 0.0)
	var restored_energy := _restore_player_energy(success_energy_restore)
	var restored_shield := _restore_player_shield(success_shield_restore)
	if success_drop_count > 0 and _player != null and is_instance_valid(_player):
		PowerupLibrary.try_spawn_energy_droplets(
			_player.get_parent(),
			_player.global_position,
			success_drop_count,
			1.0,
			success_drop_spread_radius,
			maxf(success_energy_restore / float(maxi(success_drop_count, 1)), 1.0)
		)
	if RunProgress != null:
		RunProgress.arena_flags["recovery_windows_resolved"] = int(RunProgress.arena_flags.get("recovery_windows_resolved", 0)) + 1
		RunProgress.arena_flags["last_recovery_reward"] = {
			"id": String(data.get("id", "")),
			"energy": restored_energy,
			"shield": restored_shield,
			"wave": _current_wave(),
			"time": _now_seconds(),
		}


func _restore_player_energy(amount: float) -> float:
	if amount <= 0.0 or _player == null or not is_instance_valid(_player):
		return 0.0
	var energy := _player.get_node_or_null("EnergyComponent")
	if energy != null and energy.has_method("restore"):
		var restored: Variant = energy.call("restore", amount)
		if restored is float or restored is int:
			return float(restored)
	return 0.0


func _restore_player_shield(amount: float) -> float:
	if amount <= 0.0 or _player == null or not is_instance_valid(_player):
		return 0.0
	var shield := _player.get_node_or_null("Shield")
	if shield != null and shield.has_method("restore_shield"):
		var restored: Variant = shield.call("restore_shield", amount)
		if restored is float or restored is int:
			return float(restored)
	return 0.0


func _player_alive() -> bool:
	if _health_component == null or not is_instance_valid(_health_component):
		return true
	if _health_component.has_method("is_dead"):
		return not bool(_health_component.call("is_dead"))
	var current: Variant = _health_component.get("current_health")
	return not (current is float or current is int) or float(current) > 0.0


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _player != null:
		_health_component = _player.get_node_or_null("HealthComponent")
		_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
	if root != null:
		_time_manager = root.find_child("TimeDilationManager", true, false)
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)
		_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
		_wave_director = root.find_child("WaveDirector", true, false)
	_connect_player_signals()


func _connect_player_signals() -> void:
	if _health_component != null and _health_component.has_signal("health_changed"):
		var health_cb := Callable(self, "_on_health_changed")
		if not _health_component.is_connected("health_changed", health_cb):
			_health_component.connect("health_changed", health_cb)
	if _momentum_component != null and _momentum_component.has_signal("near_miss_velocity_gained"):
		var near_cb := Callable(self, "_on_near_miss_velocity_gained")
		if not _momentum_component.is_connected("near_miss_velocity_gained", near_cb):
			_momentum_component.connect("near_miss_velocity_gained", near_cb)


func _health_ratio() -> float:
	if _health_component == null:
		return 1.0
	var current: Variant = _health_component.get("current_health")
	var maximum: Variant = _health_component.get("max_health")
	if (current is float or current is int) and (maximum is float or maximum is int):
		return clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)
	return 1.0


func _shield_ratio() -> float:
	if _player == null:
		return 1.0
	var shield := _player.get_node_or_null("Shield")
	if shield == null:
		return 1.0
	var current: Variant = shield.get("current_energy")
	var maximum: Variant = shield.get("max_capacity")
	if (current is float or current is int) and (maximum is float or maximum is int):
		return clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)
	return 1.0


func _player_velocity() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var velocity: Variant = _player.get("velocity")
	if velocity is Vector2:
		return velocity
	var linear_velocity: Variant = _player.get("linear_velocity")
	if linear_velocity is Vector2:
		return linear_velocity
	return Vector2.ZERO


func _current_wave() -> int:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return int(RunProgress.wave_index if RunProgress != null else 0)


func _build_notice() -> void:
	_notice_canvas = CanvasLayer.new()
	_notice_canvas.name = "RecoveryOpportunityHUD"
	_notice_canvas.layer = 68
	add_child(_notice_canvas)
	_notice_label = Label.new()
	_notice_label.name = "RecoveryOpportunityNotice"
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.offset_left = -240.0
	_notice_label.offset_right = 240.0
	_notice_label.offset_top = 174.0
	_notice_label.offset_bottom = 202.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.text = ""
	_notice_label.modulate.a = 0.0
	_notice_canvas.add_child(_notice_label)


func _set_notice(text: String, color: Color) -> void:
	if _notice_label == null:
		return
	_notice_label.text = text
	_notice_label.modulate = Color(color.r, color.g, color.b, 1.0)


func _update_notice(delta: float) -> void:
	if _notice_label == null or _notice_label.text.is_empty():
		return
	_notice_label.modulate.a = move_toward(_notice_label.modulate.a, 0.0, delta * 0.32)
	if _notice_label.modulate.a <= 0.02:
		_notice_label.text = ""


func _opportunity_display(opportunity_id: StringName) -> String:
	return "RECOVERY: %s" % String(opportunity_id).replace("_", " ").to_upper()


func _opportunity_color(opportunity_id: StringName) -> Color:
	match opportunity_id:
		&"wormhole_exit":
			return Color(0.78, 0.38, 1.0, 1.0)
		&"time_dilation_window":
			return Color(0.48, 0.92, 1.0, 1.0)
		&"momentum_chain":
			return Color(0.42, 1.0, 0.58, 1.0)
	return Color(0.34, 1.0, 0.86, 1.0)


func _on_window_helper_exited() -> void:
	pass


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001
