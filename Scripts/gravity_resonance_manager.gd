extends Node
class_name GravityResonanceManager

## Gravity Resonance System for ORBITRON: VECTORFALL
## When gravity wells overlap, resonance zones form
## Bullets accelerate, debris compresses into rings, temporary fractures appear,
## chain implosions occur - all capped for performance and readability

@export var resonance_detection_radius: float = 400.0
@export var minimum_resonance_strength: float = 0.5
@export var maximum_resonance_zones: int = 3
@export var resonance_decay_rate: float = 2.0
@export var resonance_buildup_rate: float = 3.0
@export var enable_bullet_acceleration: bool = true
@export var bullet_acceleration_multiplier: float = 1.5
@export var enable_debris_compression: bool = true
@export var debris_ring_formation_chance: float = 0.3
@export var enable_fracture_effects: bool = true
@export var fracture_threshold: float = 0.8
@export var enable_chain_implosions: bool = true
@export var implosion_chain_chance: float = 0.25

var _active_resonance_zones: Array[Dictionary] = []
var _gravity_sources: Array[Node2D] = []
var _resonance_field_data: Dictionary = {}
var _last_source_positions: Dictionary = {}
var _implosion_queue: Array[Dictionary] = []

signal resonance_zone_created(zone_data: Dictionary)
signal resonance_zone_intensified(zone_data: Dictionary)
signal resonance_zone_decayed(zone_id: int)
signal chain_implosion_triggered(implosion_data: Dictionary)
signal fracture_applied(position: Vector2, intensity: float)

func _ready() -> void:
	set_process(true)
	_refresh_gravity_sources()

func _process(delta: float) -> void:
	_refresh_gravity_sources()
	_detect_resonance_zones()
	_update_resonance_zones(delta)
	_process_implosion_queue(delta)

func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d = source as Node2D
			if source_2d != null:
				_gravity_sources.append(source_2d)

func _detect_resonance_zones() -> void:
	# Find pairs of gravity sources that are close enough to create resonance
	var potential_zones: Array[Dictionary] = []
	
	for i in range(_gravity_sources.size()):
		for j in range(i + 1, _gravity_sources.size()):
			var source_a = _gravity_sources[i]
			var source_b = _gravity_sources[j]
			
			if not is_instance_valid(source_a) or not is_instance_valid(source_b):
				continue
			
			var distance = source_a.global_position.distance_to(source_b.global_position)
			
			if distance < resonance_detection_radius * 2.0:
				var midpoint = (source_a.global_position + source_b.global_position) * 0.5
				var combined_strength = _calculate_combined_strength(source_a, source_b, midpoint)
				
				if combined_strength >= minimum_resonance_strength:
					potential_zones.append({
						"source_a": source_a,
						"source_b": source_b,
						"midpoint": midpoint,
						"distance": distance,
						"combined_strength": combined_strength,
						"intensity": 0.0,
						"id": hash(str(source_a.get_instance_id(), "_", source_b.get_instance_id()))
					})
	
	# Limit active zones for performance
	if potential_zones.size() > maximum_resonance_zones:
		potential_zones.sort_custom(func(a, b): 
			return a["combined_strength"] > b["combined_strength"]
		)
		potential_zones.resize(maximum_resonance_zones)
	
	# Merge with existing zones
	_merge_resonance_zones(potential_zones)

func _calculate_combined_strength(source_a: Node2D, source_b: Node2D, position: Vector2) -> float:
	var strength_a = _get_source_strength_at(source_a, position)
	var strength_b = _get_source_strength_at(source_b, position)
	
	# Resonance occurs when strengths are similar (constructive interference)
	var ratio = strength_a / (strength_b + 0.001)
	var resonance_factor = 1.0 / (abs(ratio - 1.0) + 1.0)
	
	return (strength_a + strength_b) * resonance_factor * 0.5

func _get_source_strength_at(source: Node2D, position: Vector2) -> float:
	var distance = source.global_position.distance_to(position)
	
	if distance < 20.0:
		distance = 20.0
	
	var mass: float = 100.0
	if source.has_method("get"):
		var m = source.get("mass")
		if typeof(m) in [TYPE_FLOAT, TYPE_INT]:
			mass = float(m)
	
	return 500.0 * mass / (distance * distance)

func _merge_resonance_zones(potential_zones: Array[Dictionary]) -> void:
	var new_ids = []
	
	for potential in potential_zones:
		new_ids.append(potential["id"])
		
		# Check if zone already exists
		var existing_idx = -1
		for idx in range(_active_resonance_zones.size()):
			if _active_resonance_zones[idx]["id"] == potential["id"]:
				existing_idx = idx
				break
		
		if existing_idx >= 0:
			# Update existing zone
			var existing = _active_resonance_zones[existing_idx]
			existing["combined_strength"] = potential["combined_strength"]
			existing["distance"] = potential["distance"]
			existing["midpoint"] = potential["midpoint"]
			
			# Build up intensity
			existing["intensity"] = minf(existing["intensity"] + resonance_buildup_rate * get_process_delta_time(), 1.0)
			
			if existing["intensity"] > 0.7 and existing["intensity"] - get_process_delta_time() * resonance_buildup_rate <= 0.7:
				resonance_zone_intensified.emit(existing)
		else:
			# Create new zone
			potential["intensity"] = 0.3
			_active_resonance_zones.append(potential)
			resonance_zone_created.emit(potential)
	
	# Mark zones for decay if they no longer exist
	for idx in range(_active_resonance_zones.size() - 1, -1, -1):
		var zone = _active_resonance_zones[idx]
		if not new_ids.has(zone["id"]):
			zone["intensity"] -= resonance_decay_rate * get_process_delta_time()
			
			if zone["intensity"] <= 0.0:
				resonance_zone_decayed.emit(zone["id"])
				_active_resonance_zones.remove_at(idx)

func _update_resonance_zones(delta: float) -> void:
	for zone in _active_resonance_zones:
		# Apply effects based on intensity
		if enable_bullet_acceleration and zone["intensity"] > 0.3:
			_apply_bullet_acceleration(zone)
		
		if enable_debris_compression and zone["intensity"] > 0.5:
			_try_form_debris_ring(zone)
		
		if enable_fracture_effects and zone["intensity"] > fracture_threshold:
			fracture_applied.emit(zone["midpoint"], zone["intensity"])
		
		if enable_chain_implosions and zone["intensity"] > 0.6:
			_try_trigger_chain_implosion(zone)

func _apply_bullet_acceleration(zone: Dictionary) -> void:
	var acceleration_strength = zone["intensity"] * bullet_acceleration_multiplier
	
	# Find bullets in resonance zone
	for bullet in get_tree().get_nodes_in_group("bullets"):
		if not is_instance_valid(bullet):
			continue
		
		var bullet_2d = bullet as Node2D
		if bullet_2d == null:
			continue
		
		var distance = bullet_2d.global_position.distance_to(zone["midpoint"])
		
		if distance < resonance_detection_radius * 0.5:
			var direction = (bullet_2d.global_position - zone["midpoint"]).normalized()
			
			# Accelerate outward from resonance center
			if "velocity" in bullet:
				bullet.velocity += direction * acceleration_strength * 50.0 * get_process_delta_time()

func _try_form_debris_ring(zone: Dictionary) -> void:
	if randf() > debris_ring_formation_chance * get_process_delta_time():
		return
	
	# This would integrate with a debris system
	# For now, emit signal for external systems to handle
	var ring_data = {
		"center": zone["midpoint"],
		"radius": zone["distance"] * 0.5,
		"intensity": zone["intensity"]
	}
	
	# External systems can listen to create visual debris rings

func _try_trigger_chain_implosion(zone: Dictionary) -> void:
	if randf() > implosion_chain_chance * get_process_delta_time():
		return
	
	var implosion_data = {
		"position": zone["midpoint"],
		"radius": zone["distance"] * 0.3,
		"strength": zone["intensity"] * 2.0,
		"delay": 0.2
	}
	
	_implosion_queue.append(implosion_data)

func _process_implosion_queue(delta: float) -> void:
	for i in range(_implosion_queue.size() - 1, -1, -1):
		var implosion = _implosion_queue[i]
		implosion["delay"] -= delta
		
		if implosion["delay"] <= 0.0:
			chain_implosion_triggered.emit(implosion)
			_implosion_queue.remove_at(i)

func get_active_resonance_zones() -> Array[Dictionary]:
	return _active_resonance_zones.duplicate()

func get_resonance_at_position(position: Vector2) -> float:
	var total_intensity = 0.0
	
	for zone in _active_resonance_zones:
		var distance = position.distance_to(zone["midpoint"])
		if distance < resonance_detection_radius * 0.5:
			total_intensity += zone["intensity"] * (1.0 - distance / (resonance_detection_radius * 0.5))
	
	return total_intensity

func is_position_in_resonance(position: Vector2, threshold: float = 0.3) -> bool:
	return get_resonance_at_position(position) > threshold

func clear_all_zones() -> void:
	_active_resonance_zones.clear()
	_implosion_queue.clear()
