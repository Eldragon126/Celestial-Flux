extends Node
class_name TimeDilationManager

## Time Dilation System for ORBITRON: VECTORFALL
## Time dilation is NOT a panic button - it's precision rhythm combat
## Preserves momentum during slowdown, enables delayed release bursts,
## harmful afterimages, threading impossible trajectories

@export var base_time_scale: float = 1.0
@export var min_time_scale: float = 0.1
@export var max_time_scale: float = 2.0
@export var dilation_rate: float = 3.0
@export var recovery_rate: float = 1.5
@export var initial_dilation_capacity: float = 100.0
@export var dilation_cost_per_second: float = 40.0
@export var near_miss_charge_amount: float = 15.0
@export var near_miss_detection_radius: float = 60.0
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
var _global_slow_factor: float = 1.0
var _momentum_preservation_active: bool = true

signal time_scale_changed(new_scale: float, capacity: float)
signal dilation_started()
signal dilation_ended()
signal capacity_depleted()
signal afterimage_spawned(position: Vector2, velocity: Vector2)
signal near_miss_detected(amount: float)

func _ready() -> void:
	current_dilation_capacity = initial_dilation_capacity
	set_process(true)
	set_physics_process(true)

func _process(delta: float) -> void:
	_handle_input()
	_update_capacity(delta)
	_update_afterimages(delta)
	_update_local_time_effects(delta)
	
	# Emit signal for audio/visual systems
	time_scale_changed.emit(current_time_scale, current_dilation_capacity)

func _physics_process(_delta: float) -> void:
	_update_global_time_scale()

func _handle_input() -> void:
	var dilation_pressed = Input.is_action_pressed("time_dilation")
	
	if dilation_pressed and not _dilation_input_active:
		_start_dilation()
	elif not dilation_pressed and _dilation_input_active:
		_end_dilation()
	
	_dilation_input_active = dilation_pressed

func _start_dilation() -> void:
	if current_dilation_capacity <= 0.0:
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
		# Drain capacity while dilating
		var drain = dilation_cost_per_second * delta
		current_dilation_capacity -= drain
		
		if current_dilation_capacity <= 0.0:
			current_dilation_capacity = 0.0
			is_dilating = false
			capacity_depleted.emit()
	else:
		# Recover capacity when not dilating
		var recover = recovery_rate * delta * 20.0
		current_dilation_capacity += recover
		current_dilation_capacity = minf(current_dilation_capacity, initial_dilation_capacity)

func _update_global_time_scale() -> void:
	if is_dilating and current_dilation_capacity > 0.0:
		# Calculate time scale based on remaining capacity
		var target_scale = lerp(min_time_scale, base_time_scale, 
			current_dilation_capacity / initial_dilation_capacity)
		current_time_scale = lerp(current_time_scale, target_scale, dilation_rate * get_physics_process_delta_time())
	else:
		current_time_scale = lerp(current_time_scale, base_time_scale, recovery_rate * get_physics_process_delta_time())
	
	# Apply to engine (this affects global physics)
	Engine.time_scale = current_time_scale

func _update_afterimages(delta: float) -> void:
	if not enable_afterimages or not is_dilating:
		return
	
	_afterimage_timer += delta
	
	if _afterimage_timer >= afterimage_interval:
		_afterimage_timer = 0.0
		_spawn_afterimage()

func _spawn_afterimage() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	
	var afterimage_data = {
		"position": player.global_position,
		"rotation": player.rotation,
		"velocity": player.velocity if "velocity" in player else Vector2.ZERO,
		"lifetime": afterimage_lifetime,
		"scale": player.scale
	}
	
	_afterimage_positions.append(afterimage_data)
	afterimage_spawned.emit(afterimage_data["position"], afterimage_data["velocity"])

func _update_afterimages(delta: float) -> void:
	for i in range(_afterimage_positions.size() - 1, -1, -1):
		var afterimage = _afterimage_positions[i]
		afterimage["lifetime"] -= delta
		
		if afterimage["lifetime"] <= 0.0:
			_afterimage_positions.remove_at(i)

func add_near_miss_charge(amount: float = near_miss_charge_amount) -> void:
	current_dilation_capacity = minf(current_dilation_capacity + amount, initial_dilation_capacity * 1.2)
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
	
	var now = Time.get_ticks_msec() / 1000.0
	var until = maxf(float(target.get_meta("local_time_scale_until", 0.0)), now + duration)
	
	target.set_meta("local_time_scale", clampf(multiplier, 0.05, 1.0))
	target.set_meta("local_time_scale_until", until)
	
	# Affect velocity for visual feedback
	var velocity: Variant = target.get("velocity")
	if velocity is Vector2:
		target.set("velocity", velocity * maxf(multiplier, 0.25))
	
	if target.has_method("on_local_slow_applied"):
		target.call("on_local_slow_applied", multiplier, duration)

func get_time_scale_for_target(target: Node) -> float:
	if target == null:
		return current_time_scale
	
	var now = Time.get_ticks_msec() / 1000.0
	var until = float(target.get_meta("local_time_scale_until", 0.0))
	
	if now >= until:
		if target.has_meta("local_time_scale"):
			target.remove_meta("local_time_scale")
		return current_time_scale
	
	var local_scale = clampf(float(target.get_meta("local_time_scale", 1.0)), 0.05, 1.0)
	return local_scale * current_time_scale

func _update_local_time_effects(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	
	for obj_id in _local_slow_effects.keys():
		var effect = _local_slow_effects[obj_id]
		effect["remaining"] -= delta
		
		if effect["remaining"] <= 0.0:
			expired.append(obj_id)
	
	for obj_id in expired:
		_local_slow_effects.erase(obj_id)

func get_momentum_preserved_velocity(base_velocity: Vector2) -> Vector2:
	if _momentum_preservation_active and is_dilating:
		# Preserve full momentum during time dilation
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
	return current_dilation_capacity / initial_dilation_capacity

func is_at_minimum_time_scale() -> bool:
	return current_time_scale <= min_time_scale + 0.01

func force_end_dilation() -> void:
	is_dilating = false
	current_time_scale = base_time_scale
	Engine.time_scale = base_time_scale
