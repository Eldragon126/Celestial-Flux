extends Node
class_name GravityResonanceManager

# Gravity resonance turns overlapping wells into readable tactical pressure.
# It samples nearby gravity sources on a capped cadence, creates a small number
# of resonance zones, and exposes signals for VFX/audio without owning either.
# Known limitation: zones are pair-based rather than a full vector-field solve;
# this keeps the system predictable and affordable during late-run chaos.

signal resonance_zone_created(zone_data: Dictionary)
signal resonance_zone_intensified(zone_data: Dictionary)
signal resonance_zone_updated(zone_data: Dictionary)
signal resonance_zone_type_changed(zone_data: Dictionary)
signal resonance_zone_decayed(zone_id: int)
signal resonance_zone_decayed_detailed(zone_data: Dictionary)
signal debris_ring_requested(ring_data: Dictionary)
signal chain_implosion_triggered(implosion_data: Dictionary)
signal fracture_applied(position: Vector2, intensity: float)
signal resonance_field_pulsed(zone_data: Dictionary)

enum ZoneType { COMPRESSION, SLIPSTREAM, INVERSION, TEMPORAL_SCAR, HARMONIC_ORBIT }
enum VisualQuality { OFF, LOW, HIGH }

const ZONE_TYPE_NAMES = {
	ZoneType.COMPRESSION: &"compression",
	ZoneType.SLIPSTREAM: &"slipstream",
	ZoneType.INVERSION: &"inversion",
	ZoneType.TEMPORAL_SCAR: &"temporal_scar",
	ZoneType.HARMONIC_ORBIT: &"harmonic_orbit",
}

const ZONE_DISPLAY_NAMES = {
	ZoneType.COMPRESSION: "Compression",
	ZoneType.SLIPSTREAM: "Slipstream",
	ZoneType.INVERSION: "Inversion",
	ZoneType.TEMPORAL_SCAR: "Temporal Scar",
	ZoneType.HARMONIC_ORBIT: "Harmonic Orbit",
}

const ZONE_COLORS = {
	ZoneType.COMPRESSION: Color(0.22, 0.72, 1.0, 1.0),
	ZoneType.SLIPSTREAM: Color(0.0, 1.0, 0.78, 1.0),
	ZoneType.INVERSION: Color(1.0, 0.38, 0.16, 1.0),
	ZoneType.TEMPORAL_SCAR: Color(0.84, 0.42, 1.0, 1.0),
	ZoneType.HARMONIC_ORBIT: Color(1.0, 0.88, 0.25, 1.0),
}

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

@export_group("Zone Gameplay")
@export var enable_zone_body_effects: bool = true
@export var zone_body_acceleration: float = 260.0
@export var max_bodies_per_zone: int = 36
@export var player_zone_effect_multiplier: float = 0.42
@export var enemy_zone_effect_multiplier: float = 0.8
@export var boss_zone_effect_multiplier: float = 0.48
@export var temporal_scar_slow_multiplier: float = 0.58
@export var temporal_scar_slow_duration: float = 0.28
@export var zone_body_groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses"]

@export_group("Visuals")
@export var enable_zone_visuals: bool = true
@export_enum("Off", "Low", "High") var resonance_visual_quality: int = VisualQuality.HIGH
@export var max_visual_particles_per_zone: int = 42
@export var visual_ring_segments: int = 72

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
var _visual_root: Node2D = null
var _zone_visuals: Dictionary = {}
var _time_dilation_manager: Node = null
var _manual_zone_counter := 900000

func _ready() -> void:
	add_to_group("gravity_resonance_manager")
	set_process(true)
	_refresh_gravity_sources()
	_ensure_visual_root()

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

	_update_manual_zones(delta)
	_update_resonance_zones(delta)
	_process_implosion_queue(delta)
	_sync_zone_visuals(delta)

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

			var zone_id := _zone_id(source_a, source_b)
			var zone_type := _classify_zone(source_a, source_b, midpoint, distance, combined_strength)

			potential_zones.append({
				"source_a": source_a,
				"source_b": source_b,
				"midpoint": midpoint,
				"distance": distance,
				"combined_strength": combined_strength,
				"intensity": 0.0,
				"id": zone_id,
				"zone_type": zone_type,
				"zone_type_name": _zone_type_name(zone_type),
				"zone_display_name": _zone_display_name(zone_type),
				"zone_color": _zone_type_color(zone_type),
				"radius": _zone_radius_for_distance(distance, zone_type, combined_strength),
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

func _classify_zone(source_a: Node2D, source_b: Node2D, _position: Vector2, distance: float, combined_strength: float) -> int:
	var mass_a := _source_signed_mass(source_a)
	var mass_b := _source_signed_mass(source_b)
	if mass_a < 0.0 or mass_b < 0.0:
		return ZoneType.INVERSION

	var mass_delta := absf(absf(mass_a) - absf(mass_b)) / maxf(maxf(absf(mass_a), absf(mass_b)), 1.0)
	var temporal_threshold := maxf(minimum_resonance_strength * 2.65, fracture_threshold * 0.95)

	if combined_strength >= temporal_threshold:
		return ZoneType.TEMPORAL_SCAR
	if mass_delta <= 0.18 and distance <= resonance_detection_radius * 1.35:
		return ZoneType.HARMONIC_ORBIT
	if distance <= resonance_detection_radius * 0.85:
		return ZoneType.COMPRESSION
	return ZoneType.SLIPSTREAM

func _zone_radius_for_distance(distance: float, zone_type: int, combined_strength: float) -> float:
	var base_radius := clampf(distance * 0.42, resonance_detection_radius * 0.22, resonance_detection_radius * 0.74)
	var strength_swell := clampf((combined_strength - minimum_resonance_strength) * 0.08, 0.0, 0.22)
	base_radius *= 1.0 + strength_swell

	match zone_type:
		ZoneType.COMPRESSION:
			base_radius *= 0.88
		ZoneType.SLIPSTREAM:
			base_radius *= 1.16
		ZoneType.TEMPORAL_SCAR:
			base_radius *= 1.08
		ZoneType.HARMONIC_ORBIT:
			base_radius *= 0.96

	return maxf(base_radius, 56.0)

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
			var previous_type := _zone_type(existing)
			existing["source_a"] = potential["source_a"]
			existing["source_b"] = potential["source_b"]
			existing["combined_strength"] = potential["combined_strength"]
			existing["distance"] = potential["distance"]
			existing["midpoint"] = potential["midpoint"]
			existing["zone_type"] = potential["zone_type"]
			existing["zone_type_name"] = potential["zone_type_name"]
			existing["zone_display_name"] = potential["zone_display_name"]
			existing["zone_color"] = potential["zone_color"]
			existing["radius"] = potential["radius"]

			var previous_intensity := float(existing["intensity"])
			existing["intensity"] = minf(previous_intensity + resonance_buildup_rate * delta, 1.0)
			_active_resonance_zones[existing_idx] = existing

			if previous_type != _zone_type(existing):
				resonance_zone_type_changed.emit(existing)
			if previous_intensity <= 0.45 and float(existing["intensity"]) > 0.45:
				resonance_field_pulsed.emit(existing)
			if previous_intensity <= 0.7 and float(existing["intensity"]) > 0.7:
				resonance_zone_intensified.emit(existing)
			resonance_zone_updated.emit(existing)
		else:
			potential["intensity"] = 0.3
			_active_resonance_zones.append(potential)
			resonance_zone_created.emit(potential)
			resonance_field_pulsed.emit(potential)

	for idx in range(_active_resonance_zones.size() - 1, -1, -1):
		var zone := _active_resonance_zones[idx]
		var zone_id := int(zone["id"])
		if new_ids.has(zone_id):
			continue
		if bool(zone.get("manual", false)):
			continue

		zone["intensity"] = float(zone["intensity"]) - resonance_decay_rate * delta
		if float(zone["intensity"]) <= 0.0:
			resonance_zone_decayed.emit(zone_id)
			resonance_zone_decayed_detailed.emit(zone)
			_remove_zone_visual(zone_id)
			_active_resonance_zones.remove_at(idx)
		else:
			_active_resonance_zones[idx] = zone

func _update_resonance_zones(delta: float) -> void:
	for zone in _active_resonance_zones:
		var intensity := float(zone.get("intensity", 0.0))

		if enable_projectile_acceleration and intensity > 0.3:
			_apply_projectile_acceleration(zone, delta)

		if enable_zone_body_effects and intensity > 0.18:
			_apply_zone_body_effects(zone, delta)

		if enable_debris_compression and intensity > 0.5:
			_try_form_debris_ring(zone, delta)

		if enable_fracture_effects and intensity > fracture_threshold:
			fracture_applied.emit(zone["midpoint"], intensity)

		if enable_chain_implosions and intensity > 0.6:
			_try_trigger_chain_implosion(zone, delta)

func _update_manual_zones(delta: float) -> void:
	for idx in range(_active_resonance_zones.size() - 1, -1, -1):
		var zone := _active_resonance_zones[idx]
		if not bool(zone.get("manual", false)):
			continue

		zone["remaining"] = float(zone.get("remaining", 0.0)) - delta
		var remaining := float(zone["remaining"])
		var duration := maxf(float(zone.get("duration", 1.0)), 0.001)
		zone["intensity"] = clampf(float(zone.get("base_intensity", 0.6)) * minf(1.0, remaining / duration * 2.0), 0.0, 1.0)

		if remaining <= 0.0:
			var zone_id := int(zone.get("id", 0))
			resonance_zone_decayed.emit(zone_id)
			resonance_zone_decayed_detailed.emit(zone)
			_remove_zone_visual(zone_id)
			_active_resonance_zones.remove_at(idx)
		else:
			_active_resonance_zones[idx] = zone
			resonance_zone_updated.emit(zone)

func _apply_projectile_acceleration(zone: Dictionary, delta: float) -> void:
	var center: Vector2 = zone["midpoint"]
	var influence_radius := _zone_radius(zone)
	var influence_radius_squared := influence_radius * influence_radius
	var acceleration_strength := float(zone["intensity"]) * projectile_acceleration_multiplier * 65.0 * _zone_projectile_multiplier(_zone_type(zone))
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
			if _zone_type(zone) == ZoneType.TEMPORAL_SCAR:
				_apply_temporal_slow(projectile_2d, temporal_scar_slow_multiplier, temporal_scar_slow_duration)
			CombatStatus.add_velocity(projectile_2d, direction * acceleration_strength * delta)
			affected += 1

func _apply_zone_body_effects(zone: Dictionary, delta: float) -> void:
	var center: Vector2 = zone["midpoint"]
	var influence_radius := _zone_radius(zone)
	var influence_radius_squared := influence_radius * influence_radius
	var intensity := float(zone.get("intensity", 0.0))
	var affected := 0
	var seen := {}

	for group_name in zone_body_groups:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if affected >= max_bodies_per_zone:
				return
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
				continue

			var body_2d := _motion_body(candidate)
			if body_2d == null or not is_instance_valid(body_2d) or body_2d.is_queued_for_deletion():
				continue

			var id := body_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var offset := body_2d.global_position - center
			var distance_squared := offset.length_squared()
			if distance_squared > influence_radius_squared or distance_squared <= 0.001:
				continue

			var distance := sqrt(distance_squared)
			var falloff := 1.0 - clampf(distance / influence_radius, 0.0, 1.0)
			var multiplier := _zone_body_multiplier(body_2d)
			if multiplier <= 0.0:
				continue

			var zone_type := _zone_type(zone)
			if zone_type == ZoneType.TEMPORAL_SCAR and not body_2d.is_in_group("Player"):
				var slow := lerpf(1.0, temporal_scar_slow_multiplier, clampf(intensity * falloff, 0.0, 1.0))
				_apply_temporal_slow(body_2d, slow, temporal_scar_slow_duration)

			var direction := _zone_effect_direction(zone, body_2d, offset)
			if direction == Vector2.ZERO:
				continue

			var impulse := direction * zone_body_acceleration * intensity * falloff * multiplier * delta
			CombatStatus.add_velocity(body_2d, impulse)
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

func _motion_body(node: Node) -> Node2D:
	var current := node
	while is_instance_valid(current) and not current.is_queued_for_deletion():
		var current_2d := current as Node2D
		if current_2d != null:
			if _accepts_velocity(current_2d) or current_2d.is_in_group("Player") or current_2d.is_in_group("enemies") or current_2d.is_in_group("wave_enemy") or current_2d.is_in_group("bosses"):
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
	var velocity := _body_velocity(projectile)
	if velocity != Vector2.ZERO and tangent.dot(velocity) < 0.0:
		tangent = -tangent

	match _zone_type(zone):
		ZoneType.COMPRESSION:
			return (-offset_from_center).normalized()
		ZoneType.INVERSION:
			return offset_from_center.normalized()
		ZoneType.SLIPSTREAM:
			return tangent
		ZoneType.TEMPORAL_SCAR:
			return -velocity.normalized() if velocity != Vector2.ZERO else -offset_from_center.normalized()
		ZoneType.HARMONIC_ORBIT:
			return (tangent * 0.74 - offset_from_center.normalized() * 0.26).normalized()

	if field == Vector2.ZERO:
		return tangent

	return (field.normalized() * 0.62 + tangent * 0.38).normalized()

func _zone_effect_direction(zone: Dictionary, body: Node2D, offset_from_center: Vector2) -> Vector2:
	if offset_from_center.length_squared() <= 0.001:
		return Vector2.ZERO

	var radial := offset_from_center.normalized()
	var tangent := radial.orthogonal()
	var velocity := _body_velocity(body)
	if velocity != Vector2.ZERO and tangent.dot(velocity) < 0.0:
		tangent = -tangent

	match _zone_type(zone):
		ZoneType.COMPRESSION:
			return -radial
		ZoneType.INVERSION:
			return radial
		ZoneType.SLIPSTREAM:
			return tangent
		ZoneType.TEMPORAL_SCAR:
			return -velocity.normalized() if velocity != Vector2.ZERO else -radial * 0.25
		ZoneType.HARMONIC_ORBIT:
			return (tangent * 0.72 - radial * 0.28).normalized()

	return Vector2.ZERO

func _zone_body_multiplier(body: Node) -> float:
	if body.is_in_group("Player"):
		return player_zone_effect_multiplier
	if body.is_in_group("bosses"):
		return boss_zone_effect_multiplier
	if body.is_in_group("enemies") or body.is_in_group("wave_enemy"):
		return enemy_zone_effect_multiplier
	return 0.0

func _zone_projectile_multiplier(zone_type: int) -> float:
	match zone_type:
		ZoneType.COMPRESSION:
			return 1.08
		ZoneType.INVERSION:
			return 1.16
		ZoneType.SLIPSTREAM:
			return 1.25
		ZoneType.TEMPORAL_SCAR:
			return 0.42
		ZoneType.HARMONIC_ORBIT:
			return 0.9
	return 1.0

func _body_velocity(body: Node) -> Vector2:
	if not is_instance_valid(body):
		return Vector2.ZERO

	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		return velocity

	var linear_velocity: Variant = body.get("linear_velocity")
	if linear_velocity is Vector2:
		return linear_velocity

	return Vector2.ZERO

func _apply_temporal_slow(target: Node, multiplier: float, duration: float) -> void:
	var time_manager := _get_time_dilation_manager()
	if time_manager != null and time_manager.has_method("apply_local_slow_to_target"):
		time_manager.call("apply_local_slow_to_target", target, multiplier, duration)
	else:
		CombatStatus.apply_local_slow(target, multiplier, duration)

func _get_time_dilation_manager() -> Node:
	if _time_dilation_manager != null and is_instance_valid(_time_dilation_manager) and not _time_dilation_manager.is_queued_for_deletion():
		return _time_dilation_manager

	var root := get_tree().current_scene
	if root == null:
		return null

	_time_dilation_manager = root.find_child("TimeDilationManager", true, false)
	return _time_dilation_manager

func _try_form_debris_ring(zone: Dictionary, delta: float) -> void:
	if randf() > debris_ring_formation_chance * delta:
		return

	var ring_data := {
		"center": zone["midpoint"],
		"radius": float(zone["distance"]) * 0.5,
		"intensity": zone["intensity"],
		"zone_type": _zone_type(zone),
		"zone_type_name": _zone_type_name(_zone_type(zone)),
		"zone_color": _zone_type_color(_zone_type(zone)),
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
		"zone_type": _zone_type(zone),
		"zone_type_name": _zone_type_name(_zone_type(zone)),
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

func _sync_zone_visuals(delta: float) -> void:
	if not enable_zone_visuals or resonance_visual_quality == VisualQuality.OFF:
		_clear_zone_visuals()
		return

	_ensure_visual_root()
	var active_ids := {}
	for zone in _active_resonance_zones:
		var zone_id := int(zone.get("id", 0))
		active_ids[zone_id] = true
		_update_zone_visual(zone, delta)

	for visual_id in _zone_visuals.keys():
		if not active_ids.has(visual_id):
			_remove_zone_visual(int(visual_id))

func _ensure_visual_root() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	if not enable_zone_visuals or resonance_visual_quality == VisualQuality.OFF:
		return

	_visual_root = Node2D.new()
	_visual_root.name = "ResonanceZoneVisuals"
	_visual_root.top_level = true
	_visual_root.z_index = -8
	add_child(_visual_root)

func _update_zone_visual(zone: Dictionary, delta: float) -> void:
	var zone_id := int(zone.get("id", 0))
	if zone_id == 0:
		return

	var visual_value = _zone_visuals.get(zone_id, {})
	var visual: Dictionary = visual_value if typeof(visual_value) == TYPE_DICTIONARY else {}
	if visual.is_empty():
		visual = _make_zone_visual(zone_id, _zone_type(zone))
		_zone_visuals[zone_id] = visual

	var root := visual.get("root") as Node2D
	var core := visual.get("core") as Polygon2D
	var ring := visual.get("ring") as Line2D
	var accent := visual.get("accent") as Line2D
	var particles := visual.get("particles") as GPUParticles2D
	var material := visual.get("particle_material") as ParticleProcessMaterial
	if root == null or not is_instance_valid(root):
		_zone_visuals.erase(zone_id)
		return

	var center: Vector2 = zone.get("midpoint", Vector2.ZERO)
	var radius := _zone_radius(zone)
	var intensity := clampf(float(zone.get("intensity", 0.0)), 0.0, 1.0)
	var base_color := _zone_type_color(_zone_type(zone))
	var life_alpha := lerpf(0.1, 0.72, intensity)

	root.global_position = center
	root.rotation += delta * _visual_spin_for_zone(_zone_type(zone))
	root.scale = Vector2.ONE * lerpf(0.96, 1.04, sin(Time.get_ticks_msec() / 180.0) * 0.5 + 0.5)

	if core != null:
		core.polygon = _soft_circle_points(48, radius * 0.74)
		core.color = Color(base_color.r, base_color.g, base_color.b, life_alpha * 0.2)
	if ring != null:
		ring.points = _circle_points(maxi(24, visual_ring_segments), radius)
		ring.width = lerpf(1.8, 4.8, intensity)
		ring.default_color = Color(base_color.r, base_color.g, base_color.b, life_alpha)
	if accent != null:
		accent.points = _circle_points(maxi(18, int(visual_ring_segments / 2)), radius * 0.58)
		accent.width = lerpf(1.0, 2.6, intensity)
		accent.default_color = Color(1.0, 1.0, 1.0, life_alpha * 0.36)
	if particles != null:
		particles.amount = maxi(0, max_visual_particles_per_zone)
		particles.emitting = intensity > 0.24 and resonance_visual_quality == VisualQuality.HIGH
		if material != null:
			material.emission_sphere_radius = radius * 0.86

func _make_zone_visual(zone_id: int, zone_type: int) -> Dictionary:
	_ensure_visual_root()
	if _visual_root == null:
		return {}

	var root := Node2D.new()
	root.name = "ResonanceZone_%d" % zone_id
	root.z_index = -8
	_visual_root.add_child(root)

	var core := Polygon2D.new()
	core.name = "Core"
	core.z_index = -10
	root.add_child(core)

	var ring := Line2D.new()
	ring.name = "OuterRing"
	ring.closed = true
	ring.antialiased = true
	ring.z_index = -7
	root.add_child(ring)

	var accent := Line2D.new()
	accent.name = "InnerAccent"
	accent.closed = true
	accent.antialiased = true
	accent.z_index = -6
	root.add_child(accent)

	var particles: GPUParticles2D = null
	var material: ParticleProcessMaterial = null
	if resonance_visual_quality == VisualQuality.HIGH and max_visual_particles_per_zone > 0:
		particles = GPUParticles2D.new()
		particles.name = "ZoneParticles"
		particles.z_index = -9
		particles.amount = max_visual_particles_per_zone
		particles.lifetime = 1.8
		particles.randomness = 0.62
		material = _make_zone_particle_material(zone_type)
		particles.process_material = material
		root.add_child(particles)

	return {
		"root": root,
		"core": core,
		"ring": ring,
		"accent": accent,
		"particles": particles,
		"particle_material": material,
	}

func _make_zone_particle_material(zone_type: int) -> ParticleProcessMaterial:
	var base := _zone_type_color(zone_type)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(base.r, base.g, base.b, 0.78))
	gradient.set_color(1, Color(base.r, base.g, base.b, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.spread = 180.0
	material.initial_velocity_min = 12.0
	material.initial_velocity_max = 76.0
	material.orbit_velocity_min = -0.45
	material.orbit_velocity_max = 0.92
	material.radial_accel_min = -28.0 if zone_type == ZoneType.COMPRESSION else -8.0
	material.radial_accel_max = 42.0 if zone_type == ZoneType.INVERSION else 18.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.2
	material.scale_max = 4.4
	material.color_ramp = texture
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.55
	return material

func _remove_zone_visual(zone_id: int) -> void:
	var visual_value = _zone_visuals.get(zone_id, {})
	var visual: Dictionary = visual_value if typeof(visual_value) == TYPE_DICTIONARY else {}
	if not visual.is_empty():
		var root := visual.get("root") as Node
		if root != null and is_instance_valid(root):
			root.queue_free()
	_zone_visuals.erase(zone_id)

func _clear_zone_visuals() -> void:
	for zone_id in _zone_visuals.keys():
		_remove_zone_visual(int(zone_id))
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	_visual_root = null

func _visual_spin_for_zone(zone_type: int) -> float:
	match zone_type:
		ZoneType.SLIPSTREAM:
			return 1.7
		ZoneType.INVERSION:
			return -1.25
		ZoneType.TEMPORAL_SCAR:
			return 0.38
		ZoneType.HARMONIC_ORBIT:
			return 1.05
	return 0.62

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _soft_circle_points(count: int, base_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var wave := sin(angle * 3.0) * 0.05 + cos(angle * 5.0) * 0.035
		points.append(Vector2(cos(angle), sin(angle)) * base_radius * (1.0 + wave))
	return points

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

func _source_signed_mass(source: Node2D) -> float:
	if not is_instance_valid(source):
		return 100.0

	var value: Variant = source.get("mass")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var mass := float(value)
		if absf(mass) >= 1.0:
			return mass

	return 100.0

func _zone_type(zone: Dictionary) -> int:
	return int(zone.get("zone_type", ZoneType.COMPRESSION))

func _zone_type_name(zone_type: int) -> StringName:
	return ZONE_TYPE_NAMES.get(zone_type, &"compression")

func _zone_display_name(zone_type: int) -> String:
	return String(ZONE_DISPLAY_NAMES.get(zone_type, "Compression"))

func _zone_type_color(zone_type: int) -> Color:
	return ZONE_COLORS.get(zone_type, Color(0.22, 0.72, 1.0, 1.0))

func _zone_radius(zone: Dictionary) -> float:
	return maxf(float(zone.get("radius", resonance_detection_radius * 0.5)), 40.0)

func get_active_resonance_zones() -> Array[Dictionary]:
	return _active_resonance_zones.duplicate()

func get_resonance_at_position(position: Vector2) -> float:
	var total_intensity := 0.0

	for zone in _active_resonance_zones:
		var midpoint: Vector2 = zone["midpoint"]
		var influence_radius := _zone_radius(zone)
		var distance := position.distance_to(midpoint)
		if distance < influence_radius:
			total_intensity += float(zone["intensity"]) * (1.0 - distance / influence_radius)

	return total_intensity

func get_resonance_zone_at_position(position: Vector2) -> Dictionary:
	var best_zone := {}
	var best_intensity := 0.0

	for zone in _active_resonance_zones:
		var midpoint: Vector2 = zone["midpoint"]
		var influence_radius := _zone_radius(zone)
		var distance := position.distance_to(midpoint)
		if distance >= influence_radius:
			continue

		var local_intensity := float(zone["intensity"]) * (1.0 - distance / influence_radius)
		if local_intensity > best_intensity:
			best_intensity = local_intensity
			best_zone = zone.duplicate()
			best_zone["local_intensity"] = local_intensity

	return best_zone

func get_resonance_debug_state() -> Dictionary:
	var strongest := {}
	var max_intensity := 0.0

	for zone in _active_resonance_zones:
		var intensity := float(zone.get("intensity", 0.0))
		if intensity > max_intensity:
			max_intensity = intensity
			strongest = zone

	return {
		"active": _active_resonance_zones.size(),
		"max_intensity": max_intensity,
		"strongest_type": String(strongest.get("zone_type_name", &"none")) if not strongest.is_empty() else "none",
	}

func is_position_in_resonance(position: Vector2, threshold: float = 0.3) -> bool:
	return get_resonance_at_position(position) > threshold

func clear_all_zones() -> void:
	_active_resonance_zones.clear()
	_implosion_queue.clear()
	_clear_zone_visuals()

func create_manual_resonance_zone(position: Vector2, radius: float, zone_type: int = ZoneType.HARMONIC_ORBIT, intensity: float = 0.65, duration: float = 2.0) -> int:
	_manual_zone_counter += 1
	var zone_id := _manual_zone_counter
	var clamped_type := clampi(zone_type, ZoneType.COMPRESSION, ZoneType.HARMONIC_ORBIT)
	var zone := {
		"id": zone_id,
		"midpoint": position,
		"distance": radius * 2.0,
		"radius": maxf(radius, 40.0),
		"combined_strength": maxf(intensity, minimum_resonance_strength),
		"intensity": clampf(intensity, 0.05, 1.0),
		"base_intensity": clampf(intensity, 0.05, 1.0),
		"duration": maxf(duration, 0.1),
		"remaining": maxf(duration, 0.1),
		"zone_type": clamped_type,
		"zone_type_name": _zone_type_name(clamped_type),
		"zone_display_name": _zone_display_name(clamped_type),
		"zone_color": _zone_type_color(clamped_type),
		"manual": true,
	}
	_active_resonance_zones.append(zone)
	resonance_zone_created.emit(zone)
	resonance_field_pulsed.emit(zone)
	return zone_id
