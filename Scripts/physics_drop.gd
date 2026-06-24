extends Area2D
class_name PhysicsDrop

signal physics_drop_collected(drop_type: int, data: Dictionary)
signal physics_drop_expired(drop_type: int, data: Dictionary)

enum DropType {
	FRAGMENT,
	MOMENTUM_ORB,
	GRAVITY_RESIDUE,
	TEMPORAL_CHARGE,
	INSTABILITY_SHARD,
	ANOMALY_SEED,
	CELESTIAL_CORE,
}

const TYPE_NAMES := {
	DropType.FRAGMENT: &"fragment",
	DropType.MOMENTUM_ORB: &"momentum_orb",
	DropType.GRAVITY_RESIDUE: &"gravity_residue",
	DropType.TEMPORAL_CHARGE: &"temporal_charge",
	DropType.INSTABILITY_SHARD: &"instability_shard",
	DropType.ANOMALY_SEED: &"anomaly_seed",
	DropType.CELESTIAL_CORE: &"celestial_core",
}

@export var drop_type: int = DropType.FRAGMENT
@export var rarity: int = 0
@export var value: float = 1.0
@export var pickup_radius: float = 38.0
@export var attract_radius: float = 280.0
@export var max_speed: float = 560.0
@export var gravity_sample_interval: float = 0.28
@export var lifetime: float = 11.0
@export var mass: float = 0.0
@export var gravity_constant: float = 145.0
@export var max_gravity_sources: int = 4
@export var visual_radius: float = 34.0
@export var planet_clearance: float = 84.0
@export var planet_pushout_attempts: int = 3

var powerup_definition: PowerupDefinition = null

var _player: Node2D = null
var _velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _gravity_elapsed: float = 999.0
var _gravity_sources: Array[Node2D] = []
var _core: Polygon2D = null
var _ring: Line2D = null
var _glyph: Line2D = null
var _label: Label = null


func _ready() -> void:
	add_to_group("physics_drop")
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_cache_player()
	_push_out_of_planets()
	_build_collision()
	_build_visuals()
	_apply_gravity_group_state()
	call_deferred("_push_out_of_planets")


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_expire()
		return
	_update_motion(delta)
	_update_visuals(delta)


func configure(new_type: int, new_rarity: int, launch_impulse: Vector2, new_value: float = 1.0, definition: PowerupDefinition = null) -> void:
	drop_type = clampi(new_type, DropType.FRAGMENT, DropType.CELESTIAL_CORE)
	rarity = maxi(new_rarity, 0)
	value = maxf(new_value, 0.0)
	powerup_definition = definition
	_velocity = launch_impulse.limit_length(max_speed)
	_configure_type_defaults()
	_apply_gravity_group_state()


func _configure_type_defaults() -> void:
	match drop_type:
		DropType.MOMENTUM_ORB:
			lifetime = maxf(lifetime, 8.0)
			visual_radius = 38.0
		DropType.GRAVITY_RESIDUE:
			mass = lerpf(95000.0, 190000.0, clampf(float(rarity) / 4.0, 0.0, 1.0))
			lifetime = maxf(lifetime, 10.0)
			visual_radius = 46.0
		DropType.TEMPORAL_CHARGE:
			lifetime = maxf(lifetime, 9.0)
			visual_radius = 40.0
		DropType.INSTABILITY_SHARD:
			lifetime = maxf(lifetime, 12.0)
			visual_radius = 42.0
		DropType.ANOMALY_SEED:
			lifetime = maxf(lifetime, 13.0)
			visual_radius = 48.0
		DropType.CELESTIAL_CORE:
			lifetime = maxf(lifetime, 18.0)
			visual_radius = 58.0
		_:
			visual_radius = 32.0


func _apply_gravity_group_state() -> void:
	if drop_type == DropType.GRAVITY_RESIDUE:
		add_to_group("Objects_With_Gravity")
		add_to_group("planets")
		if RuntimeRegistry != null and is_inside_tree():
			RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
			RuntimeRegistry.register_node(self, &"planets")
	else:
		remove_from_group("Objects_With_Gravity")
		remove_from_group("planets")
		if RuntimeRegistry != null:
			RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
			RuntimeRegistry.unregister_node(self, &"planets")


func _update_motion(delta: float) -> void:
	_cache_player()
	_gravity_elapsed += delta
	if _gravity_elapsed >= maxf(gravity_sample_interval, 0.05):
		_gravity_elapsed = 0.0
		_refresh_gravity_sources()

	var acceleration := _gravity_acceleration()
	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		var distance_sq := to_player.length_squared()
		var attract_sq := attract_radius * attract_radius
		if distance_sq <= attract_sq and distance_sq > 1.0:
			var factor := 1.0 - clampf(sqrt(distance_sq) / maxf(attract_radius, 1.0), 0.0, 1.0)
			acceleration += to_player.normalized() * lerpf(340.0, 1750.0, factor)

	_velocity = (_velocity + acceleration * delta).limit_length(max_speed)
	_velocity = _velocity.move_toward(Vector2.ZERO, 42.0 * delta)
	global_position += _velocity * delta
	_push_out_of_planets()


func _gravity_acceleration() -> Vector2:
	var total := Vector2.ZERO
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source == self:
			continue
		var offset := source.global_position - global_position
		var dist_sq := maxf(offset.length_squared(), 2500.0)
		if dist_sq > 2400.0 * 2400.0:
			continue
		var source_mass := 100.0
		var mass_value: Variant = source.get("mass")
		if mass_value is float or mass_value is int:
			source_mass = float(mass_value)
		total += offset.normalized() * gravity_constant * source_mass / dist_sq
	return total


func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body) or not body.is_in_group("Player"):
		return
	_apply_pickup(body)
	queue_free()


func _apply_pickup(player_body: Node) -> void:
	var data := _drop_data()
	match drop_type:
		DropType.FRAGMENT:
			_add_player_fragments(player_body, maxi(1, int(round(value))))
		DropType.MOMENTUM_ORB:
			_apply_momentum_orb(player_body)
		DropType.GRAVITY_RESIDUE:
			_spawn_gravity_residue_field()
		DropType.TEMPORAL_CHARGE:
			_apply_temporal_charge()
		DropType.INSTABILITY_SHARD:
			_apply_instability_shard()
		DropType.ANOMALY_SEED:
			_activate_anomaly_seed()
		DropType.CELESTIAL_CORE:
			_apply_celestial_core(player_body)
	physics_drop_collected.emit(drop_type, data)


func _add_player_fragments(player_body: Node, count: int) -> void:
	var current := int(player_body.get_meta(&"vector_fragments", 0))
	player_body.set_meta(&"vector_fragments", current + count)
	var energy := player_body.get_node_or_null("EnergyComponent")
	if energy != null and energy.has_method("add_currency"):
		energy.call("add_currency", count)
	if RunProgress != null:
		RunProgress.arena_flags["vector_fragments"] = int(RunProgress.arena_flags.get("vector_fragments", 0)) + count
		RunProgress.arena_flags["energy_currency_fragments"] = int(RunProgress.arena_flags.get("energy_currency_fragments", 0)) + count


func _apply_momentum_orb(player_body: Node) -> void:
	var player_2d := player_body as Node2D
	if player_2d == null:
		return
	var velocity := _body_velocity(player_body)
	var direction := velocity.normalized() if velocity.length_squared() > 1.0 else -player_2d.transform.x.normalized()
	CombatStatus.add_velocity(player_body, direction * lerpf(260.0, 620.0, clampf(value / 4.0, 0.0, 1.0)))
	player_body.set_meta(&"momentum_orb_charge", _now_seconds())


func _spawn_gravity_residue_field() -> void:
	var resonance := _find_scene_node("GravityResonanceManager")
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		resonance.call(
			"create_manual_resonance_zone",
			global_position,
			220.0 + float(rarity) * 42.0,
			GravityResonanceManager.ZoneType.COMPRESSION,
			0.42 + float(rarity) * 0.08,
			2.8 + float(rarity) * 0.6
		)


func _apply_temporal_charge() -> void:
	var time_manager := _find_scene_node("TimeDilationManager")
	if time_manager != null and time_manager.has_method("add_near_miss_charge"):
		time_manager.call("add_near_miss_charge", 18.0 + value * 8.0)


func _apply_instability_shard() -> void:
	var arena := _find_scene_node("ArenaDestabilizationManager")
	if arena != null and arena.get("instability") != null:
		arena.set("instability", clampf(float(arena.get("instability")) + 0.035 + float(rarity) * 0.012, 0.0, 1.0))
	var reality := _find_scene_node("RealityCollapseDirector")
	if rarity >= 3 and reality != null and reality.has_method("force_reality_breach"):
		reality.call("force_reality_breach", &"corrupted_spacetime")
	if RunProgress != null:
		RunProgress.arena_flags["instability_shards"] = int(RunProgress.arena_flags.get("instability_shards", 0)) + 1


func _activate_anomaly_seed() -> void:
	var route := absi(hash("%s:%d:%d" % [global_position, rarity, int(value * 100.0)])) % 5
	if route == 0 and _force_instability_event():
		return
	if route == 1 and _force_celestial_event():
		return
	if route == 2 and _force_reality_breach():
		return
	var arena := _find_scene_node("ArenaDestabilizationManager")
	if arena != null and arena.has_method("force_arena_event"):
		var events: Array[StringName] = [&"tide_slipstream", &"wormhole_shear", &"resonance_storm", &"temporal_pocket"]
		arena.call("force_arena_event", events[absi(hash("%s:%d" % [global_position, rarity])) % events.size()])
		return
	var resonance := _find_scene_node("GravityResonanceManager")
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		resonance.call("create_manual_resonance_zone", global_position, 260.0, GravityResonanceManager.ZoneType.SLIPSTREAM, 0.62, 3.2)


func _force_instability_event() -> bool:
	var instability := _find_scene_node("ArenaInstabilityDirector")
	if instability == null or not instability.has_method("force_instability_event"):
		return false
	var events: Array[StringName] = [
		&"gravity_tide",
		&"resonance_storm",
		&"slipstream_surge",
		&"collapsing_orbit_lane",
		&"spacetime_fracture",
	]
	instability.call("force_instability_event", events[_seeded_index(events.size(), 11)])
	return true


func _force_celestial_event() -> bool:
	var celestial := _find_scene_node("CelestialBodyDirector")
	if celestial == null or not celestial.has_method("force_celestial_event"):
		return false
	var events: Array[StringName] = [&"rogue_planet", &"binary_system", &"wandering_singularity", &"orbital_structure"]
	celestial.call("force_celestial_event", events[_seeded_index(events.size(), 23)])
	return true


func _force_reality_breach() -> bool:
	var reality := _find_scene_node("RealityCollapseDirector")
	if reality == null or not reality.has_method("force_reality_breach"):
		return false
	var breaches: Array[StringName] = [&"screen_edge_breach", &"corrupted_spacetime", &"overlapping_timeline"]
	reality.call("force_reality_breach", breaches[_seeded_index(breaches.size(), 37)])
	return true


func _apply_celestial_core(player_body: Node) -> void:
	var inventory := player_body.get_node_or_null("PowerupInventory") as PowerupInventory
	if inventory == null:
		inventory = PowerupInventory.new()
		inventory.name = "PowerupInventory"
		player_body.add_child(inventory)
	var definition := powerup_definition
	if definition == null:
		definition = PowerupLibrary.get_random_definition()
	if definition != null:
		inventory.apply_powerup(definition)
	player_body.set_meta(&"celestial_core_rule", String(TYPE_NAMES.get(drop_type, &"celestial_core")))
	_force_celestial_event()


func _expire() -> void:
	physics_drop_expired.emit(drop_type, _drop_data())
	queue_free()


func _drop_data() -> Dictionary:
	return {
		"type": TYPE_NAMES.get(drop_type, &"fragment"),
		"rarity": rarity,
		"value": value,
		"position": global_position,
		"source_enemy": String(get_meta(&"source_enemy", "")),
		"source_wave": int(get_meta(&"source_wave", 0)),
		"drop_sequence": int(get_meta(&"drop_sequence", 0)),
	}


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "PhysicsDropCollision"
	var shape := CircleShape2D.new()
	shape.radius = pickup_radius
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	_core = Polygon2D.new()
	_core.name = "PhysicsDropCore"
	_core.color = _drop_color(0.86)
	_core.polygon = _circle_points(6, visual_radius * 0.42)
	add_child(_core)

	_ring = Line2D.new()
	_ring.name = "PhysicsDropRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.2 + float(rarity) * 0.4
	_ring.default_color = _drop_color(0.64)
	_ring.points = _circle_points(28, visual_radius)
	add_child(_ring)

	_glyph = Line2D.new()
	_glyph.name = "PhysicsDropGlyph"
	_glyph.antialiased = true
	_glyph.width = 2.0
	_glyph.default_color = _drop_color(0.76)
	_glyph.points = _glyph_points()
	add_child(_glyph)

	_label = Label.new()
	_label.name = "PhysicsDropLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.text = String(TYPE_NAMES.get(drop_type, &"fragment")).replace("_", " ").to_upper()
	_label.position = Vector2(-76.0, -visual_radius - 28.0)
	_label.size = Vector2(152.0, 22.0)
	_label.modulate = _drop_color(0.62)
	add_child(_label)


func _update_visuals(delta: float) -> void:
	var remaining := clampf(1.0 - _age / maxf(lifetime, 0.001), 0.0, 1.0)
	var pulse := 1.0 + sin(_age * (5.0 + float(rarity))) * 0.08
	if _core != null:
		_core.scale = Vector2.ONE * pulse
		_core.color = _drop_color(0.78 * remaining)
	if _ring != null:
		_ring.rotation += delta * (0.85 + float(rarity) * 0.18)
		_ring.default_color = _drop_color(0.52 * remaining)
	if _glyph != null:
		_glyph.rotation -= delta * 1.4
		_glyph.default_color = _drop_color(0.66 * remaining)
	if _label != null:
		_label.modulate = _drop_color(0.46 * remaining)


func _drop_color(alpha: float) -> Color:
	var color := Color(0.3, 0.95, 1.0, alpha)
	match drop_type:
		DropType.MOMENTUM_ORB:
			color = Color(0.35, 1.0, 0.58, alpha)
		DropType.GRAVITY_RESIDUE:
			color = Color(0.32, 0.72, 1.0, alpha)
		DropType.TEMPORAL_CHARGE:
			color = Color(0.72, 0.38, 1.0, alpha)
		DropType.INSTABILITY_SHARD:
			color = Color(1.0, 0.32, 0.18, alpha)
		DropType.ANOMALY_SEED:
			color = Color(0.9, 0.46, 1.0, alpha)
		DropType.CELESTIAL_CORE:
			color = Color(1.0, 0.84, 0.22, alpha)
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _glyph_points() -> PackedVector2Array:
	match drop_type:
		DropType.MOMENTUM_ORB:
			return PackedVector2Array([Vector2(-visual_radius * 0.55, 0.0), Vector2(visual_radius * 0.55, 0.0)])
		DropType.GRAVITY_RESIDUE:
			return _circle_points(12, visual_radius * 0.48)
		DropType.TEMPORAL_CHARGE:
			return PackedVector2Array([Vector2(0.0, -visual_radius * 0.52), Vector2(0.0, visual_radius * 0.52)])
		DropType.INSTABILITY_SHARD:
			return PackedVector2Array([Vector2(-visual_radius * 0.42, -visual_radius * 0.42), Vector2(visual_radius * 0.42, visual_radius * 0.42)])
		DropType.ANOMALY_SEED:
			return PackedVector2Array([Vector2(-visual_radius * 0.5, 0.0), Vector2(0.0, -visual_radius * 0.36), Vector2(visual_radius * 0.5, 0.0)])
		DropType.CELESTIAL_CORE:
			return _circle_points(5, visual_radius * 0.48)
	return PackedVector2Array([Vector2.ZERO, Vector2(visual_radius * 0.5, 0.0)])


func _circle_points(count: int, radius_value: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius_value)
	return points


func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(global_position, _gravity_sources, max_gravity_sources, 2200.0, self)
		return
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			var source_2d := source as Node2D
			if source_2d != null and source_2d != self:
				_gravity_sources.append(source_2d)
				if _gravity_sources.size() >= max_gravity_sources:
					return


func _cache_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("Player") as Node2D


func _body_velocity(body: Node) -> Vector2:
	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		return velocity
	var linear_velocity: Variant = body.get("linear_velocity")
	if linear_velocity is Vector2:
		return linear_velocity
	return Vector2.ZERO


func _find_scene_node(node_name: String) -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child(node_name, true, false)


func _seeded_index(size: int, salt: int) -> int:
	if size <= 0:
		return 0
	var seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return absi(hash("%d:%d:%d:%d:%d" % [seed, salt, rarity, int(global_position.x), int(global_position.y)])) % size


func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001


func _push_out_of_planets() -> void:
	if not is_inside_tree():
		return
	for _attempt in range(maxi(planet_pushout_attempts, 1)):
		var moved := false
		for node in get_tree().get_nodes_in_group(&"planets"):
			var planet := node as Node2D
			if planet == null or planet == self or not is_instance_valid(planet) or planet.is_queued_for_deletion():
				continue
			var min_distance := _planet_radius(planet) + pickup_radius + planet_clearance
			var offset := global_position - planet.global_position
			var distance := offset.length()
			if distance >= min_distance:
				continue
			if distance <= 0.001:
				offset = _fallback_push_direction(planet)
			var target_position := planet.global_position + offset.normalized() * min_distance
			global_position = target_position
			_velocity = _velocity.slide(offset.normalized())
			moved = true
		if not moved:
			return


func _planet_radius(planet: Node2D) -> float:
	var radius_value: Variant = planet.get("radius")
	if radius_value is float or radius_value is int:
		return float(radius_value) * maxf(planet.scale.x, planet.scale.y)
	var collision := planet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return (collision.shape as CircleShape2D).radius * maxf(planet.scale.x, planet.scale.y)
	return 96.0 * maxf(planet.scale.x, planet.scale.y)


func _fallback_push_direction(planet: Node2D) -> Vector2:
	_cache_player()
	if _player != null and is_instance_valid(_player):
		var from_player := global_position - _player.global_position
		if from_player.length_squared() > 0.001:
			return from_player.normalized()
	var seed := float(planet.get_instance_id() % 997) * 0.017
	return Vector2.RIGHT.rotated(seed)
