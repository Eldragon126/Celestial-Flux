# time_dilation_manager.gd
extends Node
class_name TimeDilationManager

## ORBITRON: VECTORFALL
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
@export var dilation_projectile_multiplier: float = 0.68

@export var local_effect_duration: float = 0.16
@export var field_tick_interval: float = 0.03

@export var max_targets_per_tick: int = 64

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

var is_dilating: bool = false

var _dilation_input_active := false
var _field_elapsed := 0.0
var _afterimage_elapsed := 0.0

var _afterimages: Array[Dictionary] = []
var _local_slow_effects: Dictionary = {}

var _player: CharacterBody2D = null

# ============================================================
# SIGNALS
# ============================================================

signal dilation_started()
signal dilation_ended()

signal time_scale_changed(scale: float, capacity: float)

signal local_time_pocket_entered(
	target: Node,
	multiplier: float,
	duration: float
)

signal local_time_pocket_expired(target_id: int)

signal afterimage_spawned(position: Vector2, velocity: Vector2)

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Ensure the manager processes independently of the game's time state
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	current_dilation_capacity = initial_dilation_capacity
	current_time_scale = base_time_scale

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
	var unscaled_delta = delta if Engine.time_scale == 0 else (delta / Engine.time_scale)
	
	_handle_input()
	_update_capacity(unscaled_delta)
	_update_afterimages(unscaled_delta) 
	_update_local_effects(unscaled_delta)

	time_scale_changed.emit(
		current_time_scale,
		current_dilation_capacity
	)

# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	var unscaled_delta = delta if Engine.time_scale == 0 else (delta / Engine.time_scale)
	
	_update_time_scale(unscaled_delta)
	_update_field(unscaled_delta)
	_manage_player_isolation()

# ============================================================
# PLAYER LOOKUP
# ============================================================

func _find_player() -> void:
	var node := get_tree().get_first_node_in_group("Player")

	if node is CharacterBody2D:
		_player = node

# ============================================================
# INPUT
# ============================================================

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("time_dilation")

	if pressed and not _dilation_input_active:
		_start_dilation()

	elif not pressed and _dilation_input_active:
		_end_dilation()

	_dilation_input_active = pressed

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

func _end_dilation() -> void:
	if not is_dilating:
		return

	is_dilating = false

	dilation_ended.emit()

# ============================================================
# CAPACITY
# ============================================================

func _update_capacity(unscaled_delta: float) -> void:
	if is_dilating:
		current_dilation_capacity -= dilation_cost_per_second * unscaled_delta

		if current_dilation_capacity <= 0.0:
			current_dilation_capacity = 0.0
			_end_dilation()

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
	var target_scale := base_time_scale

	if is_dilating:
		var fraction := current_dilation_capacity / maxf(
			initial_dilation_capacity,
			0.001
		)

		target_scale = lerpf(
			min_time_scale,
			base_time_scale,
			fraction
		)

		current_time_scale = lerpf(
			current_time_scale,
			target_scale,
			dilation_rate * unscaled_delta
		)

	else:
		current_time_scale = lerpf(
			current_time_scale,
			base_time_scale,
			recovery_rate * unscaled_delta
		)

	current_time_scale = clampf(
		current_time_scale,
		min_time_scale,
		max_time_scale
	)

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

	if not is_dilating:
		return

	var affected := 0

	affected += _apply_group_slow(
		&"enemies",
		dilation_enemy_multiplier,
		local_effect_duration
	)

	if affected < max_targets_per_tick:
		affected += _apply_group_slow(
			&"bosses",
			0.72,
			local_effect_duration
		)

	if affected < max_targets_per_tick:
		affected += _apply_group_slow(
			&"enemy_projectiles",
			dilation_projectile_multiplier,
			local_effect_duration
		)

# ============================================================
# APPLY GROUP SLOW
# ============================================================

func _apply_group_slow(
	group_name: StringName,
	multiplier: float,
	duration: float
) -> int:

	var affected := 0

	for node in get_tree().get_nodes_in_group(group_name):

		if affected >= max_targets_per_tick:
			break

		if not is_instance_valid(node):
			continue

		if node == _player:
			continue

		apply_local_slow_to_target(
			node,
			multiplier,
			duration
		)

		affected += 1

	return affected

# ============================================================
# APPLY LOCAL SLOW
# ============================================================

func apply_local_slow_to_target(
	target: Node,
	multiplier: float,
	duration: float
) -> void:

	if not is_instance_valid(target) or target == _player:
		return

	var id := target.get_instance_id()
	var clamped_multiplier := clampf(multiplier, 0.05, 1.0)
	var existing: Dictionary = _local_slow_effects.get(id, {})
	var was_new := existing.is_empty()
	var previous_multiplier := float(existing.get("multiplier", 1.0))

	_local_slow_effects[id] = {
		"target": target,
		"remaining": maxf(duration, float(existing.get("remaining", 0.0))),
		"multiplier": minf(clamped_multiplier, previous_multiplier)
	}

	target.set_meta("local_time_scale", minf(clamped_multiplier, previous_multiplier))
	
	if was_new or clamped_multiplier < previous_multiplier - 0.01:
		_dampen_velocity_for_local_slow(target, clamped_multiplier)
		local_time_pocket_entered.emit(target, clamped_multiplier, duration)

# ============================================================
# UPDATE LOCAL EFFECTS
# ============================================================

func _update_local_effects(unscaled_delta: float) -> void:
	var expired: Array[int] = []

	for id in _local_slow_effects.keys():

		var entry = _local_slow_effects[id]

		if typeof(entry) != TYPE_DICTIONARY:
			expired.append(id)
			continue

		var target = entry.get("target")

		if not is_instance_valid(target):
			expired.append(id)
			continue

		entry["remaining"] -= unscaled_delta

		if float(entry["remaining"]) <= 0.0:
			expired.append(id)
		else:
			_local_slow_effects[id] = entry

	for id in expired:
		_remove_local_slow(id)

# ============================================================
# REMOVE LOCAL SLOW
# ============================================================

func _remove_local_slow(id: int) -> void:
	var entry = _local_slow_effects.get(id)

	if typeof(entry) == TYPE_DICTIONARY:
		var target = entry.get("target")

		if is_instance_valid(target):

			if target.has_meta("local_time_scale"):
				target.remove_meta("local_time_scale")

			# Restore original velocity
			if target.has_meta("original_velocity"):
				var orig_vel = target.get_meta("original_velocity")
				if target.get("velocity") is Vector2:
					target.set("velocity", orig_vel)
				elif target.get("linear_velocity") is Vector2:
					target.set("linear_velocity", orig_vel)
				target.remove_meta("original_velocity")

	_local_slow_effects.erase(id)

	local_time_pocket_expired.emit(id)

# ============================================================
# CLEAR ALL
# ============================================================

func _clear_all_local_slows() -> void:
	for id in _local_slow_effects.keys():
		_remove_local_slow(id)

	_local_slow_effects.clear()

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
		return current_time_scale

	if target == _player:
		return 1.0

	if target.has_meta("local_time_scale"):
		return float(target.get_meta("local_time_scale"))

	return current_time_scale

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

	_restore_global_time()

func _restore_global_time() -> void:
	Engine.time_scale = base_time_scale

	if sync_audio_pitch:
		AudioServer.playback_speed_scale = base_time_scale

func _dampen_velocity_for_local_slow(target: Node, multiplier: float) -> void:
	if target.is_in_group("player_projectiles") or target.is_in_group("Player"):
		return

	var damping := maxf(multiplier, 0.35)
	
	# Save original velocity if we haven't already
	if not target.has_meta("original_velocity"):
		if target.get("velocity") is Vector2:
			target.set_meta("original_velocity", target.get("velocity"))
		elif target.get("linear_velocity") is Vector2:
			target.set_meta("original_velocity", target.get("linear_velocity"))

	# Apply dampening
	if target.get("velocity") is Vector2:
		target.set("velocity", target.get("velocity") * damping)
	if target.get("linear_velocity") is Vector2:
		target.set("linear_velocity", target.get("linear_velocity") * damping)
