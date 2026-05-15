# time_dilation_manager.gd
extends Node
class_name TimeDilationManager

## Time Dilation System for ORBITRON: VECTORFALL

@export var base_time_scale: float = 1.0
@export var min_time_scale: float = 0.1
@export var max_time_scale: float = 2.0
@export var dilation_rate: float = 3.0
@export var recovery_rate: float = 1.5
@export var initial_dilation_capacity: float = 100.0
@export var dilation_cost_per_second: float = 40.0
@export var near_miss_charge_amount: float = 15.0
@export var near_miss_detection_radius: float = 60.0
@export var use_global_time_scale: bool = false
@export var dilation_enemy_multiplier: float = 0.52
@export var dilation_projectile_multiplier: float = 0.68
@export var dilation_local_effect_duration: float = 0.18
@export var dilation_field_interval: float = 0.08
@export var max_dilation_targets_per_tick: int = 64
@export var enable_afterimages: bool = true
@export var afterimage_interval: float = 0.08
@export var afterimage_lifetime: float = 0.4
@export var afterimage_color: Color = Color(0.0, 0.9, 1.0, 0.3)

var current_dilation_capacity: float = 100.0
var current_time_scale: float = 1.0
var is_dilating: bool = false
var _dilation_input_active: bool = false
var _afterimage_timer: float = 0.0
var _afterimage_positions: Array[Dictionary] = []
var _local_slow_effects: Dictionary = {}
var _momentum_preservation_active: bool = true
var _dilation_field_elapsed := 0.0

signal time_scale_changed(new_scale: float, capacity: float)
signal dilation_started()
signal dilation_ended()
signal capacity_depleted()
signal afterimage_spawned(position: Vector2, velocity: Vector2)
signal near_miss_detected(amount: float)
signal local_time_pocket_entered(target: Node, multiplier: float, duration: float)
signal local_time_pocket_expired(target_id: int)
signal time_tear_intensity_changed(intensity: float)

var _last_time_tear_intensity: float = 0.0

func _ready() -> void:
	current_dilation_capacity = initial_dilation_capacity
	set_process(true)
	set_physics_process(true)

func _exit_tree() -> void:
	if is_equal_approx(Engine.time_scale, current_time_scale):
		Engine.time_scale = base_time_scale

func _process(delta: float) -> void:
	_handle_input()
	_update_capacity(delta)
	_update_afterimages(delta)
	_update_local_time_effects(delta)
	_update_dilation_field(delta)

	time_scale_changed.emit(current_time_scale, current_dilation_capacity)

func _physics_process(_delta: float) -> void:
	_update_global_time_scale()
	_emit_time_tear_intensity()

func _handle_input() -> void:
	var dilation_pressed = Input.is_action_pressed("time_dilation")

	if dilation_pressed and not _dilation_input_active:
		_start_dilation()
	elif not dilation_pressed and _dilation_input_active:
		_end_dilation()

	_dilation_input_active = dilation_pressed

func _start_dilation() -> void:
	if is_dilating or current_dilation_capacity <= 0.0:
		return

	is_dilating = true
	dilation_started.emit()

func _end_dilation() -> void:
	if not is_dilating:
		return

	is_dilating = false
	dilation_ended.emit()

func _update_capacity(delta: float) -> void:
	if is_dilating:
		var drain = dilation_cost_per_second * delta
		current_dilation_capacity -= drain

		if current_dilation_capacity <= 0.0:
			current_dilation_capacity = 0.0
			_end_dilation()
			capacity_depleted.emit()
	else:
		var recover = recovery_rate * delta * 20.0
		current_dilation_capacity += recover
		current_dilation_capacity = minf(current_dilation_capacity, initial_dilation_capacity)

func _update_global_time_scale() -> void:
	if is_dilating and current_dilation_capacity > 0.0:
		var target_scale := lerpf(
			min_time_scale,
			base_time_scale,
			current_dilation_capacity / maxf(initial_dilation_capacity, 0.001)
		)

		current_time_scale = lerpf(
			current_time_scale,
			target_scale,
			dilation_rate * get_physics_process_delta_time()
		)
	else:
		current_time_scale = lerpf(
			current_time_scale,
			base_time_scale,
			recovery_rate * get_physics_process_delta_time()
		)

	Engine.time_scale = current_time_scale if use_global_time_scale else base_time_scale

func _emit_time_tear_intensity() -> void:
	var denominator := maxf(base_time_scale - min_time_scale, 0.001)
	var intensity := clampf(
		(base_time_scale - current_time_scale) / denominator,
		0.0,
		1.0
	)

	if absf(intensity - _last_time_tear_intensity) < 0.025:
		return

	_last_time_tear_intensity = intensity
	time_tear_intensity_changed.emit(intensity)

func _update_afterimages(delta: float) -> void:
	if not enable_afterimages or not is_dilating:
		return

	_afterimage_timer += delta

	if _afterimage_timer >= afterimage_interval:
		_afterimage_timer = 0.0
		_spawn_afterimage()

	for i in range(_afterimage_positions.size() - 1, -1, -1):
		var afterimage = _afterimage_positions[i]
		afterimage["lifetime"] -= delta

		if afterimage["lifetime"] <= 0.0:
			_afterimage_positions.remove_at(i)

func _spawn_afterimage() -> void:
	var player = get_tree().get_first_node_in_group("Player")

	if not is_instance_valid(player):
		return

	var player_2d := player as Node2D

	if player_2d == null:
		return

	var velocity_value: Variant = player.get("velocity")
	var player_velocity: Vector2 = velocity_value if velocity_value is Vector2 else Vector2.ZERO

	var afterimage_data = {
		"position": player_2d.global_position,
		"rotation": player_2d.rotation,
		"velocity": player_velocity,
		"lifetime": afterimage_lifetime,
		"scale": player_2d.scale
	}

	_afterimage_positions.append(afterimage_data)
	afterimage_spawned.emit(afterimage_data["position"], afterimage_data["velocity"])

func add_near_miss_charge(amount: float = near_miss_charge_amount) -> void:
	if amount <= 0.0:
		return

	current_dilation_capacity = minf(
		current_dilation_capacity + amount,
		initial_dilation_capacity * 1.2
	)

	near_miss_detected.emit(amount)

func detect_near_misses(player: Node2D, enemies: Array) -> void:
	if player == null:
		return

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_2d = enemy as Node2D

		if enemy_2d == null:
			continue

		var distance = player.global_position.distance_to(enemy_2d.global_position)

		if distance < near_miss_detection_radius:
			add_near_miss_charge()
			break

func apply_local_slow_to_target(target: Node, multiplier: float, duration: float) -> void:
	if target == null or duration <= 0.0:
		return

	if not is_instance_valid(target):
		return

	var now = Time.get_ticks_msec() / 1000.0
	var previous_until := float(target.get_meta("local_time_scale_until", 0.0))
	var previous_multiplier := clampf(
		float(target.get_meta("local_time_scale", 1.0)),
		0.05,
		1.0
	)

	var already_slowed: bool = previous_until > now
	var clamped_multiplier := clampf(multiplier, 0.05, 1.0)
	var until: float = maxf(previous_until, now + duration)
	var target_id := target.get_instance_id()

	target.set_meta(
		"local_time_scale",
		minf(previous_multiplier, clamped_multiplier)
			if already_slowed
			else clamped_multiplier
	)

	target.set_meta("local_time_scale_until", until)

	var existing_value = _local_slow_effects.get(target_id, {})
	var existing_remaining := 0.0

	if typeof(existing_value) == TYPE_DICTIONARY:
		var existing_effect: Dictionary = existing_value
		existing_remaining = float(existing_effect.get("remaining", 0.0))

	_local_slow_effects[target_id] = {
		"target": target,
		"remaining": maxf(duration, existing_remaining),
		"multiplier": clamped_multiplier,
	}

	if not already_slowed or clamped_multiplier < previous_multiplier:
		var velocity: Variant = target.get("velocity")

		if velocity is Vector2:
			target.set("velocity", velocity * maxf(clamped_multiplier, 0.25))

	if is_instance_valid(target) and target.has_method("on_local_slow_applied"):
		target.call("on_local_slow_applied", clamped_multiplier, duration)

	local_time_pocket_entered.emit(target, clamped_multiplier, duration)
	time_tear_intensity_changed.emit(1.0 - clamped_multiplier)

func get_time_scale_for_target(target: Node) -> float:
	if target == null:
		return current_time_scale

	if not is_instance_valid(target):
		return current_time_scale

	var now = Time.get_ticks_msec() / 1000.0
	var until = float(target.get_meta("local_time_scale_until", 0.0))

	if now >= until:
		if target.has_meta("local_time_scale"):
			target.remove_meta("local_time_scale")

		return current_time_scale

	var local_scale = clampf(
		float(target.get_meta("local_time_scale", 1.0)),
		0.05,
		1.0
	)

	return local_scale * current_time_scale

func _update_local_time_effects(delta: float) -> void:
	var expired: Array = []

	for obj_id in _local_slow_effects.keys():
		var effect_value = _local_slow_effects[obj_id]

		if typeof(effect_value) != TYPE_DICTIONARY:
			expired.append(obj_id)
			continue

		var effect: Dictionary = effect_value
		effect["remaining"] -= delta

		var target = effect.get("target")

		if not is_instance_valid(target):
			expired.append(obj_id)
			continue

		target = target as Node

		if float(effect["remaining"]) <= 0.0:
			expired.append(obj_id)
		else:
			_local_slow_effects[obj_id] = effect

	for obj_id in expired:
		var effect_value = _local_slow_effects.get(obj_id, {})

		if typeof(effect_value) == TYPE_DICTIONARY:
			var expired_effect: Dictionary = effect_value

			var target = expired_effect.get("target")

			if is_instance_valid(target):
				target = target as Node

				if target.has_meta("local_time_scale"):
					target.remove_meta("local_time_scale")

				if target.has_meta("local_time_scale_until"):
					target.remove_meta("local_time_scale_until")

		_local_slow_effects.erase(obj_id)
		local_time_pocket_expired.emit(int(obj_id))

func _update_dilation_field(delta: float) -> void:
	_dilation_field_elapsed += delta

	if _dilation_field_elapsed < maxf(dilation_field_interval, 0.02):
		return

	var tick_delta := _dilation_field_elapsed
	_dilation_field_elapsed = 0.0

	if not is_dilating or current_dilation_capacity <= 0.0:
		return

	var affected := 0

	affected += _apply_dilation_to_group(
		&"enemies",
		dilation_enemy_multiplier,
		dilation_local_effect_duration + tick_delta
	)

	if affected < max_dilation_targets_per_tick:
		affected += _apply_dilation_to_group(
			&"wave_enemy",
			dilation_enemy_multiplier,
			dilation_local_effect_duration + tick_delta,
			affected
		)

	if affected < max_dilation_targets_per_tick:
		affected += _apply_dilation_to_group(
			&"bosses",
			maxf(dilation_enemy_multiplier, 0.72),
			dilation_local_effect_duration + tick_delta,
			affected
		)

	if affected < max_dilation_targets_per_tick:
		affected += _apply_dilation_to_group(
			&"enemy_projectiles",
			dilation_projectile_multiplier,
			dilation_local_effect_duration + tick_delta,
			affected
		)

	if affected < max_dilation_targets_per_tick:
		_apply_dilation_to_group(
			&"Projectiles",
			maxf(dilation_projectile_multiplier, 0.74),
			dilation_local_effect_duration + tick_delta,
			affected
		)

func _apply_dilation_to_group(
	group_name: StringName,
	multiplier: float,
	duration: float,
	already_affected: int = 0
) -> int:

	var affected := 0

	for node in get_tree().get_nodes_in_group(group_name):
		if already_affected + affected >= max_dilation_targets_per_tick:
			return affected

		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue

		if node.is_in_group("Player"):
			continue

		apply_local_slow_to_target(node, multiplier, duration)
		affected += 1

	return affected

func get_momentum_preserved_velocity(base_velocity: Vector2) -> Vector2:
	if _momentum_preservation_active and is_dilating:
		return base_velocity

	return base_velocity * current_time_scale

func create_temporal_burst(direction: Vector2, delay: float, magnitude: float) -> Dictionary:
	return {
		"direction": direction,
		"delay": delay,
		"magnitude": magnitude,
		"elapsed": 0.0,
		"triggered": false
	}

func update_temporal_bursts(bursts: Array, delta: float) -> Array:
	for i in range(bursts.size()):
		var burst = bursts[i]

		if burst["triggered"]:
			continue

		burst["elapsed"] += delta

		if burst["elapsed"] >= burst["delay"]:
			burst["triggered"] = true

	return bursts

func get_active_afterimages() -> Array[Dictionary]:
	return _afterimage_positions.duplicate()

func clear_afterimages() -> void:
	_afterimage_positions.clear()

func get_dilation_fraction() -> float:
	return current_dilation_capacity / maxf(initial_dilation_capacity, 0.001)

func is_at_minimum_time_scale() -> bool:
	return current_time_scale <= min_time_scale + 0.01

func force_end_dilation() -> void:
	var was_dilating := is_dilating

	is_dilating = false
	current_time_scale = base_time_scale
	Engine.time_scale = base_time_scale

	if was_dilating:
		dilation_ended.emit()

	_emit_time_tear_intensity()
