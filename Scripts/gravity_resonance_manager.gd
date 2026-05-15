extends Node
class_name GravityResonanceManager

# Gravity resonance turns overlapping wells into readable tactical pressure.
# It samples nearby gravity sources on a capped cadence, creates a small number
# of resonance zones, and exposes signals for VFX/audio without owning either.
# Known limitation: zones are pair-based rather than a full vector-field solve;
# this keeps the system predictable and affordable during late-run chaos.

signal resonance_zone_created(zone_data: Dictionary)
signal resonance_zone_intensified(zone_data: Dictionary)
signal resonance_zone_decayed(zone_id: int)
signal debris_ring_requested(ring_data: Dictionary)
signal chain_implosion_triggered(implosion_data: Dictionary)
signal fracture_applied(position: Vector2, intensity: float)

@export var enabled: bool = true

@export_group("Detection")
@export var source_refresh_interval: float = 0.35
@export var detection_interval: float = 0.18
@export var resonance_detection_radius: float = 400.0
@export var minimum_resonance_strength: float = 0.5
@export var maximum_resonance_zones: int = 3
@export var max_gravity_sources: int = 12
@export var resonance_decay_rate: float = 2.0
@export var resonance_buildup_rate: float = 3.0

@export_group("Projectile Warping")
@export var enable_projectile_acceleration: bool = true
@export var projectile_acceleration_multiplier: float = 1.5
@export var max_projectiles_per_zone: int = 32
@export var projectile_groups: Array[StringName] = [&"Projectiles", &"player_projectiles", &"enemy_projectiles", &"bullets"]

@export_group("Debris And Fractures")
@export var enable_debris_compression: bool = true
@export var debris_ring_formation_chance: float = 0.3
@export var enable_fracture_effects: bool = true
@export var fracture_threshold: float = 0.8

@export_group("Chain Implosions")
@export var enable_chain_implosions: bool = true
@export var implosion_chain_chance: float = 0.25
@export var max_pending_implosions: int = 6

var _active_resonance_zones: Array[Dictionary] = []
# Untyped Array to avoid implicit cast crashes when stored nodes are freed
var _gravity_sources: Array = [] 
var _implosion_queue: Array[Dictionary] = []
var _source_refresh_elapsed: float = 999.0
var _detection_elapsed: float = 999.0

func _ready() -> void:
	add_to_group("gravity_resonance_manager")
	set_process(true)
	_refresh_gravity_sources()

func _process(delta: float) -> void:
	if not enabled:
		return

	_source_refresh_elapsed += delta
	_detection_elapsed += delta

	if _source_refresh_elapsed >= maxf(source_refresh_interval, 0.05):
		_source_refresh_elapsed = 0.0
		_refresh_gravity_sources()

	if _detection_elapsed >= maxf(detection_interval, 0.05):
		var detection_delta := _detection_elapsed
		_detection_elapsed = 0.0
		_detect_resonance_zones(detection_delta)

	_update_resonance_zones(delta)
	_process_implosion_queue(delta)

func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	var seen := {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			# Validate BEFORE casting to prevent freed object crashes
			if not is_instance_valid(source) or source.is_queued_for_deletion():
				continue

			var source_2d := source as Node2D
			if source_2d == null:
				continue

			var id := source_2d.get_instance_id()
			if seen.has(id):
				continue

			seen[id] = true
			_gravity_sources.append(source_2d)

	var player_node = get_tree().get_first_node_in_group("Player")
	var player: Node2D = null
	if is_instance_valid(player_node) and not player_node.is_queued_for_deletion():
		player = player_node as Node2D

	if player != null:
		_gravity_sources.sort_custom(func(a: Variant, b: Variant) -> bool:
			if not is_instance_valid(a) or not is_instance_valid(b):
				return false
			return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
		)

	if max_gravity_sources > 0 and _gravity_sources.size() > max_gravity_sources:
		_gravity_sources.resize(max_gravity_sources)

func _detect_resonance_zones(delta: float) -> void:
	var potential_zones: Array[Dictionary] = []
	var detection_diameter_squared := resonance_detection_radius * resonance_detection_radius * 4.0

	for i in range(_gravity_sources.size()):
		var raw_a = _gravity_sources[i]
		if not is_instance_valid(raw_a) or raw_a.is_queued_for_deletion():
			continue
		var source_a: Node2D = raw_a

		for j in range(i + 1, _gravity_sources.size()):
			var raw_b = _gravity_sources[j]
			if not is_instance_valid(raw_b) or raw_b.is_queued_for_deletion():
				continue
			var source_b: Node2D = raw_b

			var distance_squared := source_a.global_position.distance_squared_to(source_b.global_position)
			if distance_squared > detection_diameter_squared:
				continue

			var distance := sqrt(distance_squared)
			var midpoint := (source_a.global_position + source_b.global_position) * 0.5
			var combined_strength := _calculate_combined_strength(source_a, source_b, midpoint)
			if combined_strength < minimum_resonance_strength:
				continue

			potential_zones.append({
				"source_a": source_a,
				"source_b": source_b,
				"midpoint": midpoint,
				"distance": distance,
				"combined_strength": combined_strength,
				"intensity": 0.0,
				"id": _zone_id(source_a, source_b),
			})

	if potential_zones.size() > maximum_resonance_zones:
		potential_zones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["combined_strength"]) > float(b["combined_strength"])
		)
		potential_zones.resize(maximum_resonance_zones)

	_merge_resonance_zones(potential_zones, delta)

func _calculate_combined_strength(source_a: Node2D, source_b: Node2D, position: Vector2) -> float:
	var strength_a := _get_source_strength_at(source_a, position)
	var strength_b := _get_source_strength_at(source_b, position)
	var ratio := strength_a / maxf(strength_b, 0.001)
	var resonance_factor := 1.0 / (absf(ratio - 1.0) + 1.0)
	return (strength_a + strength_b) * resonance_factor * 0.5

func _get_source_strength_at(source: Node2D, position: Vector2) -> float:
	if not is_instance_valid(source):
		return 0.0
	var distance := maxf(source.global_position.distance_to(position), 20.0)
	var mass := _source_mass(source)
	return 500.0 * mass / (distance * distance)

func _merge_resonance_zones(potential_zones: Array[Dictionary], delta: float) -> void:
	var new_ids := {}

	for potential in potential_zones:
		var zone_id := int(potential["id"])
		new_ids[zone_id] = true

		var existing_idx := -1
		for idx in range(_active_resonance_zones.size()):
			if int(_active_resonance_zones[idx]["id"]) == zone_id:
				existing_idx = idx
				break

		if existing_idx >= 0:
			var existing := _active_resonance_zones[existing_idx]
			existing["source_a"] = potential["source_a"]
			existing["source_b"] = potential["source_b"]
			existing["combined_strength"] = potential["combined_strength"]
			existing["distance"] = potential["distance"]
			existing["midpoint"] = potential["midpoint"]

			var previous_intensity := float(existing["intensity"])
			existing["intensity"] = minf(previous_intensity + resonance_buildup_rate * delta, 1.0)
			_active_resonance_zones[existing_idx] = existing

			if previous_intensity <= 0.7 and float(existing["intensity"]) > 0.7:
				resonance_zone_intensified.emit(existing)
		else:
			potential["intensity"] = 0.3
			_active_resonance_zones.append(potential)
			resonance_zone_created.emit(potential)

	for idx in range(_active_resonance_zones.size() - 1, -1, -1):
		var zone := _active_resonance_zones[idx]
		var zone_id := int(zone["id"])
		if new_ids.has(zone_id):
			continue

		zone["intensity"] = float(zone["intensity"]) - resonance_decay_rate * delta
		if float(zone["intensity"]) <= 0.0:
			resonance_zone_decayed.emit(zone_id)
			_active_resonance_zones.remove_at(idx)
		else:
			_active_resonance_zones[idx] = zone

func _update_resonance_zones(delta: float) -> void:
	for zone in _active_resonance_zones:
		var intensity := float(zone.get("intensity", 0.0))

		if enable_projectile_acceleration and intensity > 0.3:
			_apply_projectile_acceleration(zone, delta)

		if enable_debris_compression and intensity > 0.5:
			_try_form_debris_ring(zone, delta)

		if enable_fracture_effects and intensity > fracture_threshold:
			fracture_applied.emit(zone["midpoint"], intensity)

		if enable_chain_implosions and intensity > 0.6:
			_try_trigger_chain_implosion(zone, delta)

func _apply_projectile_acceleration(zone: Dictionary, delta: float) -> void:
	var center: Vector2 = zone["midpoint"]
	var influence_radius := resonance_detection_radius * 0.5
	var influence_radius_squared := influence_radius * influence_radius
	var acceleration_strength := float(zone["intensity"]) * projectile_acceleration_multiplier * 50.0
	var affected := 0
	var seen := {}

	for group_name in projectile_groups:
		for projectile in get_tree().get_nodes_in_group(group_name):
			if affected >= max_projectiles_per_zone:
				return
				
			if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
				continue

			var projectile_2d := _projectile_motion_body(projectile)
			if projectile_2d == null:
				continue

			var id := projectile_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var offset := projectile_2d.global_position - center
			var distance_squared := offset.length_squared()
			if distance_squared > influence_radius_squared or distance_squared <= 0.001:
				continue

			var direction := _resonance_projectile_direction(zone, projectile_2d, offset)
			CombatStatus.add_velocity(projectile_2d, direction * acceleration_strength * delta)
			affected += 1

func _projectile_motion_body(node: Node) -> Node2D:
	var current := node
	# Validate nodes traversing up the tree
	while is_instance_valid(current) and not current.is_queued_for_deletion():
		var current_2d := current as Node2D
		if current_2d != null and _accepts_velocity(current_2d):
			return current_2d
		current = current.get_parent()

	return null

func _accepts_velocity(node: Node) -> bool:
	var velocity: Variant = node.get("velocity")
	if velocity is Vector2:
		return true

	var linear_velocity: Variant = node.get("linear_velocity")
	return linear_velocity is Vector2

func _resonance_projectile_direction(zone: Dictionary, projectile: Node2D, offset_from_center: Vector2) -> Vector2:
	var field := Vector2.ZERO
	
	# Safely extract and check dictionary objects before casting
	var raw_a = zone.get("source_a")
	if is_instance_valid(raw_a) and not raw_a.is_queued_for_deletion():
		var source_a := raw_a as Node2D
		if source_a:
			field += (source_a.global_position - projectile.global_position).normalized()

	var raw_b = zone.get("source_b")
	if is_instance_valid(raw_b) and not raw_b.is_queued_for_deletion():
		var source_b := raw_b as Node2D
		if source_b:
			field += (source_b.global_position - projectile.global_position).normalized()

	var tangent := offset_from_center.normalized().orthogonal()
	if field == Vector2.ZERO:
		return tangent

	return (field.normalized() * 0.62 + tangent * 0.38).normalized()

func _try_form_debris_ring(zone: Dictionary, delta: float) -> void:
	if randf() > debris_ring_formation_chance * delta:
		return

	var ring_data := {
		"center": zone["midpoint"],
		"radius": float(zone["distance"]) * 0.5,
		"intensity": zone["intensity"],
	}
	debris_ring_requested.emit(ring_data)

func _try_trigger_chain_implosion(zone: Dictionary, delta: float) -> void:
	if _implosion_queue.size() >= max_pending_implosions:
		return
	if randf() > implosion_chain_chance * delta:
		return

	_implosion_queue.append({
		"position": zone["midpoint"],
		"radius": float(zone["distance"]) * 0.3,
		"strength": float(zone["intensity"]) * 2.0,
		"delay": 0.2,
	})

func _process_implosion_queue(delta: float) -> void:
	for i in range(_implosion_queue.size() - 1, -1, -1):
		var implosion := _implosion_queue[i]
		implosion["delay"] = float(implosion["delay"]) - delta

		if float(implosion["delay"]) <= 0.0:
			chain_implosion_triggered.emit(implosion)
			_implosion_queue.remove_at(i)
		else:
			_implosion_queue[i] = implosion

func _zone_id(source_a: Node2D, source_b: Node2D) -> int:
	var a := source_a.get_instance_id() if is_instance_valid(source_a) else 0
	var b := source_b.get_instance_id() if is_instance_valid(source_b) else 0
	return int(hash("%d_%d" % [mini(a, b), maxi(a, b)]))

func _source_mass(source: Node2D) -> float:
	var mass: float = 100.0
	if not is_instance_valid(source):
		return mass
		
	var value: Variant = source.get("mass")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		mass = absf(float(value))
	return maxf(mass, 1.0)

func get_active_resonance_zones() -> Array[Dictionary]:
	return _active_resonance_zones.duplicate()

func get_resonance_at_position(position: Vector2) -> float:
	var total_intensity := 0.0
	var influence_radius := resonance_detection_radius * 0.5

	for zone in _active_resonance_zones:
		var midpoint: Vector2 = zone["midpoint"]
		var distance := position.distance_to(midpoint)
		if distance < influence_radius:
			total_intensity += float(zone["intensity"]) * (1.0 - distance / influence_radius)

	return total_intensity

func is_position_in_resonance(position: Vector2, threshold: float = 0.3) -> bool:
	return get_resonance_at_position(position) > threshold

func clear_all_zones() -> void:
	_active_resonance_zones.clear()
	_implosion_queue.clear()
