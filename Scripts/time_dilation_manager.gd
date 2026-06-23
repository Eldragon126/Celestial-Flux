# time_dilation_manager.gd
extends Node
class_name TimeDilationManager

## Vector Anomaly
## Stable Time Dilation System
##
## Key fixes:
## - Manager runs independently of Engine.time_scale
## - No recursive velocity scaling (Black hole fix)
## - Local slow system uses internal time syncing
## - Safe metadata cleanup
## - Stable Engine.time_scale transitions
## - Compatible with MomentumCombatComponent

# ============================================================
# CORE SETTINGS
# ============================================================

@export_group("Core Settings")

@export var base_time_scale: float = 1.0
@export var min_time_scale: float = 0.18
@export var safe_global_min_time_scale: float = 0.34
@export var max_time_scale: float = 1.0

@export var dilation_rate: float = 7.0
@export var recovery_rate: float = 3.0

@export var use_global_time_scale: bool = false
@export var sync_audio_pitch: bool = true

# ============================================================
# PLAYER PROTECTION
# ============================================================

@export_group("Player Protection")

@export var isolate_player_from_slowmo: bool = true
@export var preserve_player_velocity: bool = true

# ============================================================
# ENERGY / CAPACITY
# ============================================================

@export_group("Capacity")

@export var initial_dilation_capacity: float = 100.0
@export var dilation_cost_per_second: float = 36.0
@export var recovery_per_second: float = 18.0
@export var near_miss_charge_amount: float = 16.0

# ============================================================
# LOCAL FIELD
# ============================================================

@export_group("Local Time Field")

@export var dilation_enemy_multiplier: float = 0.52
@export var dilation_boss_multiplier: float = 0.72
@export var dilation_projectile_multiplier: float = 0.68
@export var field_radius: float = 1100.0
@export_range(0.0, 1.0, 0.01) var field_edge_strength: float = 0.18
@export var field_falloff_power: float = 1.6

@export var local_effect_duration: float = 0.16
@export var field_tick_interval: float = 0.03

@export var max_targets_per_tick: int = 64
@export var max_local_slow_effects: int = 64
@export var minimum_local_slow_multiplier: float = 0.32

# ============================================================
# AFTERIMAGES
# ============================================================

@export_group("Afterimages")

@export var enable_afterimages: bool = true
@export var afterimage_interval: float = 0.08
@export var afterimage_lifetime: float = 0.45

# ============================================================
# STATE
# ============================================================

var current_dilation_capacity: float = 100.0
var current_time_scale: float = 1.0
var dilation_blend: float = 0.0
var active_field_target_count: int = 0

var is_dilating: bool = false

var _dilation_input_active := false
var _field_elapsed := 0.0
var _afterimage_elapsed := 0.0

var _afterimages: Array[Dictionary] = []
var _local_slow_effects: Dictionary = {}
var _player_field_effects: Dictionary = {}
var _group_slow_targets: Array[Node2D] = []
var _group_slow_query: Array[StringName] = []
var _field_seen_ids: Dictionary = {}

var _player: CharacterBody2D = null
var _pause_menu: Node = null
var _last_tear_intensity: float = 0.0

# ============================================================
# SIGNALS
# ============================================================

signal dilation_started()
signal dilation_ended()
signal dilation_break_triggered(data: Dictionary)

signal time_scale_changed(scale: float, capacity: float)

signal local_time_pocket_entered(
	target: Node,
	multiplier: float,
	duration: float
)

signal local_time_pocket_expired(target_id: int)
signal pocket_entered(target: Node, multiplier: float, duration: float)
signal pocket_exited(target_id: int)

signal afterimage_spawned(position: Vector2, velocity: Vector2)

signal time_tear_intensity_changed(intensity: float)
signal instability_changed(intensity: float)

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Ensure the manager processes independently of the game's time state
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	current_dilation_capacity = initial_dilation_capacity
	current_time_scale = base_time_scale
	dilation_blend = 0.0

	_find_player()

	set_process(true)
	set_physics_process(true)

# ============================================================
# EXIT
# ============================================================

func _exit_tree() -> void:
	_restore_global_time()
	_clear_all_local_slows()
	_reset_player_isolation()

# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	var unscaled_delta := _get_unscaled_delta(delta)
	if _is_gameplay_blocked():
		_handle_blocked_gameplay()
		time_scale_changed.emit(current_time_scale, current_dilation_capacity)
		return
	
	_handle_input()
	_update_capacity(unscaled_delta)
	_update_afterimages(unscaled_delta) 
	_update_local_effects(unscaled_delta)

	time_scale_changed.emit(
		current_time_scale,
		current_dilation_capacity
	)
	_emit_tear_intensity_if_changed()

# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	var unscaled_delta := _get_unscaled_delta(delta)
	if _is_gameplay_blocked():
		active_field_target_count = 0
		_reset_player_isolation()
		return
	
	_update_time_scale(unscaled_delta)
	_update_field(unscaled_delta)
	_manage_player_isolation()

# ============================================================
# PLAYER LOOKUP
# ============================================================

func _find_player() -> void:
	var node := MultiplayerTargeting.local_player(get_tree())

	if node is CharacterBody2D:
		_player = node

func _get_pause_menu() -> Node:
	if _pause_menu != null and is_instance_valid(_pause_menu) and not _pause_menu.is_queued_for_deletion():
		return _pause_menu

	_pause_menu = get_tree().get_first_node_in_group("PauseMenu")
	if _pause_menu != null and is_instance_valid(_pause_menu):
		return _pause_menu

	var scene := get_tree().current_scene
	if scene == null:
		return null

	_pause_menu = scene.find_child("PauseMenu", true, false)
	return _pause_menu

# ============================================================
# INPUT
# ============================================================

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("time_dilation")
	if not is_instance_valid(_player):
		_find_player()

	if pressed and not _dilation_input_active:
		_start_dilation()

	elif not pressed and _dilation_input_active:
		_end_dilation()

	_dilation_input_active = pressed

func _handle_blocked_gameplay() -> void:
	if is_dilating:
		_end_dilation()

	_dilation_input_active = false
	_afterimage_elapsed = 0.0
	dilation_blend = 0.0
	active_field_target_count = 0
	current_time_scale = base_time_scale
	_restore_global_time()

func _is_gameplay_blocked() -> bool:
	var pause_menu := _get_pause_menu()
	if pause_menu != null and pause_menu.has_method("is_gameplay_blocked"):
		return bool(pause_menu.call("is_gameplay_blocked"))

	return get_tree().paused

func _get_unscaled_delta(delta: float) -> float:
	if Engine.time_scale <= 0.001:
		return delta

	return delta / Engine.time_scale

# ============================================================
# START / END
# ============================================================

func _start_dilation() -> void:
	if is_dilating:
		return

	if current_dilation_capacity <= 0.0:
		return

	is_dilating = true

	dilation_started.emit()

func _end_dilation(drain_break: bool = false) -> void:
	if not is_dilating:
		return

	is_dilating = false

	dilation_ended.emit()
	if drain_break:
		var break_position := Vector2.ZERO
		var break_velocity := Vector2.ZERO
		if is_instance_valid(_player):
			break_position = _player.global_position
			break_velocity = _player.velocity
		dilation_break_triggered.emit({
			"position": break_position,
			"velocity": break_velocity,
			"intensity": clampf(1.0 - current_dilation_capacity / maxf(initial_dilation_capacity, 0.001), 0.0, 1.0),
			"scale": current_time_scale,
		})

# ============================================================
# CAPACITY
# ============================================================

func _update_capacity(unscaled_delta: float) -> void:
	if is_dilating:
		current_dilation_capacity -= dilation_cost_per_second * unscaled_delta

		if current_dilation_capacity <= 0.0:
			current_dilation_capacity = 0.0
			_end_dilation(true)

	else:
		current_dilation_capacity += recovery_per_second * unscaled_delta

		current_dilation_capacity = minf(
			current_dilation_capacity,
			initial_dilation_capacity
		)

# ============================================================
# GLOBAL TIME SCALE
# ============================================================

func _update_time_scale(unscaled_delta: float) -> void:
	if _is_gameplay_blocked():
		return

	var blend_rate := dilation_rate if is_dilating else recovery_rate
	dilation_blend = move_toward(
		dilation_blend,
		1.0 if is_dilating else 0.0,
		maxf(blend_rate, 0.01) * unscaled_delta
	)
	var effective_min_scale := maxf(min_time_scale, safe_global_min_time_scale)
	current_time_scale = lerpf(base_time_scale, effective_min_scale, dilation_blend)
	current_time_scale = clampf(current_time_scale, effective_min_scale, max_time_scale)

	var applied := current_time_scale

	if not use_global_time_scale:
		applied = base_time_scale

	Engine.time_scale = applied

	if sync_audio_pitch:
		AudioServer.playback_speed_scale = applied

# ============================================================
# PLAYER ISOLATION
# ============================================================

func _manage_player_isolation() -> void:
	if not isolate_player_from_slowmo:
		return

	if not use_global_time_scale:
		return

	if not is_instance_valid(_player):
		_find_player()
		return

	if is_dilating:
		if _player.process_mode != Node.PROCESS_MODE_ALWAYS:
			_player.process_mode = Node.PROCESS_MODE_ALWAYS

		if preserve_player_velocity:
			_player.set_meta(
				"time_dilation_velocity_protected",
				true
			)

	else:
		_reset_player_isolation()

func _reset_player_isolation() -> void:
	if not is_instance_valid(_player):
		return

	if _player.process_mode == Node.PROCESS_MODE_ALWAYS:
		_player.process_mode = Node.PROCESS_MODE_INHERIT

	if _player.has_meta("time_dilation_velocity_protected"):
		_player.remove_meta("time_dilation_velocity_protected")

# ============================================================
# LOCAL FIELD
# ============================================================

func _update_field(unscaled_delta: float) -> void:
	_field_elapsed += unscaled_delta

	if _field_elapsed < field_tick_interval:
		return

	_field_elapsed = 0.0

	if dilation_blend <= 0.01:
		active_field_target_count = 0
		return
	if not is_instance_valid(_player):
		_find_player()
	if not is_instance_valid(_player):
		active_field_target_count = 0
		return

	var remaining := maxi(max_targets_per_tick, 0)
	if remaining <= 0:
		active_field_target_count = 0
		return
	active_field_target_count = 0
	_field_seen_ids.clear()
	var enemy_limit := mini(remaining, maxi(int(round(float(max_targets_per_tick) * 0.5)), 1))
	var enemy_count := _apply_group_slow(
		&"enemies",
		dilation_enemy_multiplier,
		local_effect_duration,
		enemy_limit
	)
	active_field_target_count += enemy_count
	remaining -= enemy_count

	if remaining > 0:
		var boss_limit := mini(remaining, maxi(int(round(float(max_targets_per_tick) * 0.18)), 1))
		var boss_count := _apply_group_slow(
			&"bosses",
			dilation_boss_multiplier,
			local_effect_duration,
			boss_limit
		)
		active_field_target_count += boss_count
		remaining -= boss_count

	if remaining > 0:
		active_field_target_count += _apply_group_slow(
			&"enemy_projectiles",
			dilation_projectile_multiplier,
			local_effect_duration,
			remaining
		)

# ============================================================
# APPLY GROUP SLOW
# ============================================================

func _apply_group_slow(
	group_name: StringName,
	multiplier: float,
	duration: float,
	limit: int
) -> int:

	var affected := 0
	if limit <= 0:
		return affected
	if RuntimeRegistry != null:
		_group_slow_query.clear()
		_group_slow_query.append(group_name)
		RuntimeRegistry.fill_targets_in_radius(
			_group_slow_query,
			_player.global_position,
			maxf(field_radius, 1.0),
			limit,
			false,
			_group_slow_targets
		)
		for target in _group_slow_targets:
			if affected >= limit:
				break
			if not is_instance_valid(target) or target == _player:
				continue
			var target_id := target.get_instance_id()
			if _field_seen_ids.has(target_id):
				continue
			if not _apply_player_field_slow(target, _field_multiplier_for_target(target, multiplier), duration):
				continue
			_field_seen_ids[target_id] = true
			affected += 1
		return affected

	for node in get_tree().get_nodes_in_group(group_name):

		if affected >= limit:
			break

		if not is_instance_valid(node):
			continue

		if node == _player:
			continue
		var target_2d := node as Node2D
		var effective_radius := maxf(field_radius, 1.0)
		if target_2d == null or target_2d.global_position.distance_squared_to(_player.global_position) > effective_radius * effective_radius:
			continue
		var target_id := target_2d.get_instance_id()
		if _field_seen_ids.has(target_id):
			continue

		if not _apply_player_field_slow(
			node,
			_field_multiplier_for_target(target_2d, multiplier),
			duration
		):
			continue
		_field_seen_ids[target_id] = true

		affected += 1

	return affected


func _field_multiplier_for_target(target: Node2D, core_multiplier: float) -> float:
	if target == null or not is_instance_valid(_player):
		return 1.0
	var normalized_distance := clampf(
		target.global_position.distance_to(_player.global_position) / maxf(field_radius, 1.0),
		0.0,
		1.0
	)
	var radial_strength := pow(1.0 - normalized_distance, maxf(field_falloff_power, 0.01))
	var field_strength := lerpf(clampf(field_edge_strength, 0.0, 1.0), 1.0, radial_strength)
	return lerpf(1.0, core_multiplier, clampf(dilation_blend * field_strength, 0.0, 1.0))


func _apply_player_field_slow(target: Node, multiplier: float, duration: float) -> bool:
	if not is_instance_valid(target) or target == _player:
		return false
	var id := target.get_instance_id()
	var existing: Dictionary = _player_field_effects.get(id, {})
	if existing.is_empty() and max_local_slow_effects > 0 and _player_field_effects.size() >= max_local_slow_effects:
		return false
	var now_msec := Time.get_ticks_msec()
	var expires_at_msec := now_msec + int(ceil(maxf(duration, 0.01) * 1000.0))
	var effective_multiplier := clampf(multiplier, minimum_local_slow_multiplier, 1.0)
	_player_field_effects[id] = {
		"target": target,
		"expires_at_msec": expires_at_msec,
		"multiplier": effective_multiplier,
	}
	target.set_meta(&"player_time_field_scale", effective_multiplier)
	target.set_meta(&"player_time_field_until_msec", expires_at_msec)
	return true

# ============================================================
# APPLY LOCAL SLOW
# ============================================================

func apply_local_slow_to_target(
	target: Node,
	multiplier: float,
	duration: float
) -> bool:

	if not is_instance_valid(target) or target == _player:
		return false

	var id: int = target.get_instance_id()
	var existing: Dictionary = _local_slow_effects.get(id, {})
	if existing.is_empty() and max_local_slow_effects > 0 and _local_slow_effects.size() >= max_local_slow_effects:
		return false
	var clamped_multiplier := clampf(multiplier, minimum_local_slow_multiplier, 1.0)
	var previous_multiplier := float(existing.get("multiplier", 1.0))
	var effective_multiplier := minf(clamped_multiplier, previous_multiplier)
	var now_msec := Time.get_ticks_msec()
	var expires_at_msec := maxi(
		int(existing.get("expires_at_msec", 0)),
		now_msec + int(ceil(maxf(duration, 0.01) * 1000.0))
	)

	_local_slow_effects[id] = {
		"target": target,
		"expires_at_msec": expires_at_msec,
		"multiplier": effective_multiplier,
	}

	target.set_meta(&"time_dilation_field_scale", effective_multiplier)
	target.set_meta(&"time_dilation_field_until_msec", expires_at_msec)
	if existing.is_empty():
		local_time_pocket_entered.emit(target, effective_multiplier, duration)
		pocket_entered.emit(target, effective_multiplier, duration)
	return true

# ============================================================
# UPDATE LOCAL EFFECTS
# ============================================================

func _update_local_effects(_unscaled_delta: float) -> void:
	var expired: Array[int] = []
	var now_msec := Time.get_ticks_msec()

	for id in _local_slow_effects.keys():

		var entry = _local_slow_effects[id]

		if typeof(entry) != TYPE_DICTIONARY:
			expired.append(id)
			continue

		var target = entry.get("target")

		if not is_instance_valid(target):
			expired.append(id)
			continue

		if now_msec >= int(entry.get("expires_at_msec", 0)):
			expired.append(id)

	for id in expired:
		_remove_local_slow(id)

	expired.clear()
	for id in _player_field_effects.keys():
		var entry: Variant = _player_field_effects[id]
		if not (entry is Dictionary):
			expired.append(id)
			continue
		var target: Variant = (entry as Dictionary).get("target")
		if not is_instance_valid(target) or now_msec >= int((entry as Dictionary).get("expires_at_msec", 0)):
			expired.append(id)
	for id in expired:
		_remove_player_field_slow(id)

# ============================================================
# REMOVE LOCAL SLOW
# ============================================================

func _remove_local_slow(id: int) -> void:
	var entry = _local_slow_effects.get(id)

	if typeof(entry) == TYPE_DICTIONARY:
		var target = entry.get("target")

		if is_instance_valid(target):
			if target.has_meta(&"time_dilation_field_scale"):
				target.remove_meta(&"time_dilation_field_scale")
			if target.has_meta(&"time_dilation_field_until_msec"):
				target.remove_meta(&"time_dilation_field_until_msec")

	_local_slow_effects.erase(id)

	local_time_pocket_expired.emit(id)
	pocket_exited.emit(id)


func _remove_player_field_slow(id: int) -> void:
	var entry: Variant = _player_field_effects.get(id)
	if entry is Dictionary:
		var target: Variant = (entry as Dictionary).get("target")
		if is_instance_valid(target):
			if target.has_meta(&"player_time_field_scale"):
				target.remove_meta(&"player_time_field_scale")
			if target.has_meta(&"player_time_field_until_msec"):
				target.remove_meta(&"player_time_field_until_msec")
	_player_field_effects.erase(id)

# ============================================================
# CLEAR ALL
# ============================================================

func _clear_all_local_slows() -> void:
	for id in _local_slow_effects.keys():
		_remove_local_slow(id)

	_local_slow_effects.clear()
	for id in _player_field_effects.keys():
		_remove_player_field_slow(id)
	_player_field_effects.clear()
	active_field_target_count = 0

# ============================================================
# AFTERIMAGES
# ============================================================

func _update_afterimages(unscaled_delta: float) -> void:
	if not enable_afterimages or not is_dilating or not is_instance_valid(_player):
		return

	_afterimage_elapsed += unscaled_delta

	if _afterimage_elapsed >= afterimage_interval:
		_afterimage_elapsed = 0.0
		_spawn_afterimage()

	for i in range(_afterimages.size() - 1, -1, -1):
		var entry = _afterimages[i]

		entry["lifetime"] -= unscaled_delta

		if entry["lifetime"] <= 0.0:
			_afterimages.remove_at(i)
		else:
			_afterimages[i] = entry

func _spawn_afterimage() -> void:
	if not is_instance_valid(_player):
		return

	var velocity := Vector2.ZERO

	if _player.velocity is Vector2:
		velocity = _player.velocity

	var data := {
		"position": _player.global_position,
		"rotation": _player.rotation,
		"velocity": velocity,
		"lifetime": afterimage_lifetime
	}

	_afterimages.append(data)

	afterimage_spawned.emit(
		data["position"],
		data["velocity"]
	)

# ============================================================
# HELPERS
# ============================================================

func get_time_scale_for_target(target: Node) -> float:
	if not is_instance_valid(target):
		return current_time_scale if use_global_time_scale else 1.0

	if target == _player:
		return 1.0

	var target_scale := CombatStatus.get_time_scale(target)
	if target_scale < 1.0:
		return target_scale

	return current_time_scale if use_global_time_scale else 1.0

func get_active_afterimages() -> Array[Dictionary]:
	return _afterimages.duplicate(true)

func clear_afterimages() -> void:
	_afterimages.clear()

func get_dilation_fraction() -> float:
	return current_dilation_capacity / maxf(
		initial_dilation_capacity,
		0.001
	)

func add_near_miss_charge(amount: float = -1.0) -> void:
	var charge := near_miss_charge_amount if amount < 0.0 else amount
	current_dilation_capacity = minf(
		current_dilation_capacity + maxf(charge, 0.0),
		initial_dilation_capacity
	)

func force_end_dilation() -> void:
	_end_dilation()

	current_time_scale = base_time_scale
	dilation_blend = 0.0
	active_field_target_count = 0

	_restore_global_time()

func _restore_global_time() -> void:
	Engine.time_scale = base_time_scale

	if sync_audio_pitch:
		AudioServer.playback_speed_scale = base_time_scale

func _emit_tear_intensity_if_changed() -> void:
	var local_pressure := clampf(float(_local_slow_effects.size() + _player_field_effects.size()) / 12.0, 0.0, 1.0)
	var intensity := clampf(dilation_blend * 0.82 + local_pressure * 0.18, 0.0, 1.0)
	var must_clear := intensity <= 0.001 and _last_tear_intensity > 0.001
	if not must_clear and absf(intensity - _last_tear_intensity) < 0.03:
		return
	_last_tear_intensity = intensity
	time_tear_intensity_changed.emit(intensity)
	instability_changed.emit(intensity)
