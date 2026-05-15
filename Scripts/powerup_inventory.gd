extends Node
class_name PowerupInventory

signal powerup_applied(definition: PowerupDefinition, stacks: int)
signal powerup_expired(powerup_id: StringName)
signal orbital_satellite_captured(projectile: Node, stacks: int)
signal gravity_debris_spawned(debris: Node, source_enemy: Node)
signal time_fracture_released(impulse: Vector2)
signal law_fusion_triggered(fusion_id: StringName, fusion_data: Dictionary)

@export_node_path("Node2D") var player_path: NodePath = ^".."
@export var action_pulse_cooldown: float = 0.65
@export_group("Orbital Law")
@export var satellite_capture_radius: float = 270.0
@export var satellite_orbit_radius: float = 118.0
@export var satellite_duration: float = 2.4
@export var max_satellites_per_stack: int = 2
@export_group("Singularity Law")
@export var singularity_debris_lifetime: float = 3.2
@export var singularity_debris_radius: float = 94.0
@export var singularity_debris_mass: float = 92000.0
@export var singularity_debris_particle_cap: int = 38
@export_group("Time Fracture Law")
@export var time_fracture_store_rate: float = 0.36
@export var time_fracture_release_cap: float = 680.0
@export_group("Law Fusion")
@export var enable_law_fusions: bool = true
@export var fusion_debris_bend_force: float = 340.0
@export var fusion_debris_bend_radius_multiplier: float = 1.45
@export var fusion_debris_bend_max_targets: int = 7
@export var fusion_satellite_arc_speed: float = 980.0
@export var fusion_debris_satellite_capture_radius: float = 260.0
@export var fusion_debris_satellite_capture_duration: float = 0.72
@export var fusion_visuals_enabled: bool = true

var _player: Node2D = null
var _stacks: Dictionary = {}
var _timed_effects: Dictionary = {}
var _time_pulse_ready = 0.0
var _captured_projectiles: Dictionary = {}
var _enemy_death_hooks: Dictionary = {}
var _stored_time_fracture_velocity := Vector2.ZERO
var _was_time_dilating := false
var _time_dilation_manager: Node = null
var _momentum_component: Node = null
var _last_fusion_id: StringName = &"none"
var _last_fusion_time := -999.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	set_process(true)

func _process(delta: float) -> void:
	_update_law_rules(delta)

	var expired: Array[StringName] = []

	for id in _timed_effects.keys():
		var entry: Dictionary = _timed_effects[id]
		entry["remaining"] = float(entry["remaining"]) - delta
		_timed_effects[id] = entry
		if float(entry["remaining"]) <= 0.0:
			expired.append(id)

	for id in expired:
		_timed_effects.erase(id)
		_stacks.erase(id)
		powerup_expired.emit(id)

func apply_powerup(definition: PowerupDefinition) -> void:
	if definition == null or _player == null or not is_instance_valid(_player):
		return

	var id = definition.powerup_id
	var previous_stack = int(_stacks.get(id, 0))
	var current_stack = previous_stack

	if definition.stack_policy == PowerupDefinition.StackPolicy.MUTUALLY_EXCLUSIVE:
		current_stack = 1
	elif definition.stack_policy == PowerupDefinition.StackPolicy.REFRESH_DURATION:
		current_stack = max(1, current_stack)
	else:
		current_stack = mini(current_stack + 1, max(1, definition.max_stacks))

	_stacks[id] = current_stack

	if definition.duration > 0.0:
		_timed_effects[id] = {
			"definition": definition,
			"remaining": definition.duration,
		}

	if definition.stack_policy == PowerupDefinition.StackPolicy.STACKABLE and current_stack == previous_stack:
		powerup_applied.emit(definition, current_stack)
		return

	_apply_effect(definition, current_stack)
	powerup_applied.emit(definition, current_stack)

func trigger_player_action() -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_queued_for_deletion() or not _player.is_inside_tree():
		return

	var tree = get_tree()
	if tree == null:
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now < _time_pulse_ready:
		return

	var time_stack = _get_stack_for_effect(&"time_fracture_pulse")
	if time_stack <= 0:
		return

	_time_pulse_ready = now + action_pulse_cooldown
	var pulse_radius = 320.0 + 70.0 * float(time_stack - 1)
	var slow_multiplier = maxf(0.34, 0.52 - 0.06 * float(time_stack - 1))
	var duration = 0.75 + 0.16 * float(time_stack - 1)

	for enemy in tree.get_nodes_in_group("enemies"):
		var enemy_2d = enemy as Node2D
		if enemy_2d == null or not is_instance_valid(enemy_2d) or enemy_2d.is_queued_for_deletion() or not enemy_2d.is_inside_tree():
			continue
		
		if enemy_2d.global_position.distance_squared_to(_player.global_position) > pulse_radius * pulse_radius:
			continue

		CombatStatus.apply_local_slow(enemy_2d, slow_multiplier, duration)

func get_stack_count(powerup_id: StringName) -> int:
	return int(_stacks.get(powerup_id, 0))

func _apply_effect(definition: PowerupDefinition, stacks: int) -> void:
	match definition.effect_type:
		&"singularity_amplifier":
			if _player.get("gravity_constant") != null:
				_player.set("gravity_constant", float(_player.get("gravity_constant")) + definition.amount)
			if _player.get("gravity_pull_radius") != null:
				_player.set("gravity_pull_radius", float(_player.get("gravity_pull_radius")) + definition.radius)
			if _player.get("recoil_instability") != null:
				_player.set("recoil_instability", float(_player.get("recoil_instability")) + definition.secondary_amount)
		&"time_fracture_pulse":
			trigger_player_action()
		&"shield_overcharge":
			var shield = _player.get_node_or_null("Shield")
			if shield != null and is_instance_valid(shield) and not shield.is_queued_for_deletion():
				if shield.has_method("restore_shield"):
					shield.call("restore_shield", definition.amount)
				if shield.has_method("add_temporary_max_bonus"):
					shield.call("add_temporary_max_bonus", definition.secondary_amount, definition.duration, &"shield_overcharge")
		&"orbital_tether_upgrade":
			if _player.get("max_gravity_anchors") != null:
				_player.set("max_gravity_anchors", int(_player.get("max_gravity_anchors")) + int(definition.amount))
			if _player.get("orbit_control_bonus") != null:
				_player.set("orbit_control_bonus", float(_player.get("orbit_control_bonus")) + definition.secondary_amount)

func _get_stack_for_effect(effect_type: StringName) -> int:
	var best = 0
	for id in _stacks.keys():
		var entry = _timed_effects.get(id, {})
		var definition = entry.get("definition", null) as PowerupDefinition
		if definition == null and ClassDB.class_exists("PowerupLibrary"):
			# Assuming PowerupLibrary is an Autoload
			definition = PowerupLibrary.get_definition(id) 
		if definition != null and definition.effect_type == effect_type:
			best = max(best, int(_stacks[id]))
	return best

func _update_law_rules(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_queued_for_deletion() or not _player.is_inside_tree():
		return

	_connect_momentum_component()
	_update_orbital_satellites(delta)
	_update_singularity_death_hooks()
	_update_time_fracture_storage(delta)

func _update_orbital_satellites(delta: float) -> void:
	var stacks := get_stack_count(&"orbital_tether_upgrade")
	if stacks <= 0:
		_release_all_invalid_satellites()
		return

	_capture_nearby_projectiles(stacks)
	_update_captured_projectiles(delta)

func _capture_nearby_projectiles(stacks: int) -> void:
	var tree = get_tree()
	if tree == null:
		return
		
	var max_satellites: int = max(1, stacks * max_satellites_per_stack)
	if _count_valid_satellites() >= max_satellites:
		return

	var radius_squared := satellite_capture_radius * satellite_capture_radius
	for projectile in tree.get_nodes_in_group("enemy_projectiles"):
		if _count_valid_satellites() >= max_satellites:
			return
			
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion() or not projectile.is_inside_tree():
			continue

		var projectile_2d := projectile as Node2D
		if projectile_2d == null:
			continue
			
		if projectile_2d.global_position.distance_squared_to(_player.global_position) > radius_squared:
			continue
			
		if projectile_2d.has_meta(&"orbital_satellite_owner"):
			continue

		var angle := (projectile_2d.global_position - _player.global_position).angle()
		projectile_2d.set_meta(&"orbital_satellite_owner", _player.get_instance_id())
		projectile_2d.set_meta(&"converted_to_player_projectile", true)
		projectile_2d.remove_from_group("enemy_projectiles")
		projectile_2d.add_to_group("player_projectiles")

		_captured_projectiles[projectile_2d.get_instance_id()] = {
			"projectile": projectile_2d,
			"age": 0.0,
			"angle": angle,
			"radius": satellite_orbit_radius + float(_count_valid_satellites()) * 18.0,
			"debris_anchor_until": 0.0,
			"next_debris_anchor": 0.0,
		}
		orbital_satellite_captured.emit(projectile_2d, stacks)

func _update_captured_projectiles(delta: float) -> void:
	var expired: Array[int] = []
	var orbit_speed := 3.7
	var singularity_stacks := get_stack_count(&"singularity_amplifier")

	for id in _captured_projectiles.keys():
		var entry_value = _captured_projectiles[id]
		if typeof(entry_value) != TYPE_DICTIONARY:
			expired.append(id)
			continue

		var entry: Dictionary = entry_value
		var projectile := entry.get("projectile") as Node2D
		
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion() or not projectile.is_inside_tree():
			expired.append(id)
			continue

		entry["age"] = float(entry.get("age", 0.0)) + delta
		entry["angle"] = float(entry.get("angle", 0.0)) + orbit_speed * delta
		if enable_law_fusions and singularity_stacks > 0:
			_try_anchor_satellite_to_debris(entry, projectile, singularity_stacks)

		var angle := float(entry["angle"])
		var anchor := _valid_debris_anchor(entry)
		var orbit_center := _player.global_position
		var radius := float(entry.get("radius", satellite_orbit_radius))
		if anchor != null:
			orbit_center = anchor.global_position
			var anchor_radius_value: Variant = anchor.get("radius")
			var anchor_radius := maxf(float(anchor_radius_value) * 0.74, 58.0) if typeof(anchor_radius_value) == TYPE_FLOAT or typeof(anchor_radius_value) == TYPE_INT else 78.0
			radius = minf(radius, anchor_radius)

		var offset := Vector2.RIGHT.rotated(angle) * radius
		var tangent := offset.normalized().orthogonal()
		
		projectile.global_position = orbit_center + offset
		CombatStatus.add_velocity(projectile, tangent * 32.0)
		
		if projectile.get("linear_velocity") is Vector2:
			var inherited := _body_velocity(_player) * 0.2 if anchor == null else Vector2.ZERO
			projectile.set("linear_velocity", tangent * 720.0 + inherited)

		if float(entry["age"]) >= satellite_duration:
			_release_satellite(projectile, tangent)
			expired.append(id)
		else:
			_captured_projectiles[id] = entry

	for id in expired:
		_captured_projectiles.erase(id)

func _release_satellite(projectile: Node2D, tangent: Vector2, release_speed: float = 920.0) -> void:
	if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
		return
		
	projectile.remove_meta(&"orbital_satellite_owner")
	projectile.remove_meta(&"singularity_debris_anchor")
	if projectile.get("linear_velocity") is Vector2:
		projectile.set("linear_velocity", tangent.normalized() * release_speed + _body_velocity(_player) * 0.25)

func _release_all_invalid_satellites() -> void:
	var expired: Array[int] = []
	for id in _captured_projectiles.keys():
		var entry_value = _captured_projectiles[id]
		if typeof(entry_value) != TYPE_DICTIONARY:
			expired.append(id)
			continue
		var entry: Dictionary = entry_value
		var projectile := entry.get("projectile") as Node2D
		
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			expired.append(id)
			
	for id in expired:
		_captured_projectiles.erase(id)

func _count_valid_satellites() -> int:
	var count := 0
	for entry_value in _captured_projectiles.values():
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var projectile := entry.get("projectile") as Node2D
		if projectile != null and is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			count += 1
	return count

func _update_singularity_death_hooks() -> void:
	var stacks := get_stack_count(&"singularity_amplifier")
	if stacks <= 0:
		return

	var tree = get_tree()
	if tree == null:
		return
		
	# Clean up stale memory leak hooks
	var stale_hooks: Array[int] = []
	for id in _enemy_death_hooks.keys():
		if not is_instance_id_valid(id):
			stale_hooks.append(id)
	for id in stale_hooks:
		_enemy_death_hooks.erase(id)

	for enemy in tree.get_nodes_in_group("enemies"):
		if enemy == _player or not is_instance_valid(enemy):
			continue
			
		var enemy_node := enemy as Node
		if enemy_node == null or enemy_node.is_queued_for_deletion():
			continue

		var id := enemy_node.get_instance_id()
		if _enemy_death_hooks.has(id):
			continue

		var health := enemy_node.get_node_or_null("HealthComponent")
		if health != null and health.has_signal("died"):
			var callable := Callable(self, "_on_tracked_enemy_died").bind(enemy_node)
			if not health.is_connected("died", callable):
				health.connect("died", callable)
			_enemy_death_hooks[id] = true

func _on_tracked_enemy_died(enemy: Node) -> void:
	# Erase hook to avoid memory leaks
	var id = enemy.get_instance_id()
	if _enemy_death_hooks.has(id):
		_enemy_death_hooks.erase(id)
		
	if _player == null or enemy == _player or not is_instance_valid(enemy):
		return
		
	if get_stack_count(&"singularity_amplifier") <= 0:
		return

	var enemy_2d := enemy as Node2D
	if enemy_2d == null:
		return
		
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return # Prevents call_deferred crash on a null scene during transitions

	var stacks := get_stack_count(&"singularity_amplifier")
	var debris := GravityDebris.new()
	debris.name = "SingularityDebris"
	debris.configure(
		singularity_debris_mass * (1.0 + 0.2 * float(stacks - 1)),
		singularity_debris_radius + 18.0 * float(stacks - 1),
		singularity_debris_lifetime,
		Color(0.78, 0.32, 1.0, 1.0)
	)
	debris.particle_cap = singularity_debris_particle_cap
	
	# Fallback safe position check just in case the enemy died by falling out of tree bounds
	var spawn_pos := enemy_2d.position
	if enemy_2d.is_inside_tree():
		spawn_pos = enemy_2d.global_position
		
	debris.position = spawn_pos
	tree.current_scene.call_deferred("add_child", debris)
	
	gravity_debris_spawned.emit(debris, enemy)

func _update_time_fracture_storage(delta: float) -> void:
	var stacks := get_stack_count(&"time_fracture_pulse")
	var time_manager := _get_time_dilation_manager()
	var is_dilating := false
	
	if time_manager != null and is_instance_valid(time_manager) and not time_manager.is_queued_for_deletion():
		is_dilating = bool(time_manager.get("is_dilating")) if typeof(time_manager.get("is_dilating")) == TYPE_BOOL else false

	if stacks > 0 and is_dilating:
		var velocity := _body_velocity(_player)
		if velocity.length_squared() > 1.0:
			_stored_time_fracture_velocity += velocity.normalized() * velocity.length() * time_fracture_store_rate * delta
			_stored_time_fracture_velocity = _stored_time_fracture_velocity.limit_length(time_fracture_release_cap)

	if _was_time_dilating and not is_dilating and _stored_time_fracture_velocity.length_squared() > 1.0:
		var impulse := _stored_time_fracture_velocity
		_stored_time_fracture_velocity = Vector2.ZERO
		CombatStatus.add_velocity(_player, impulse)
		time_fracture_released.emit(impulse)
		if enable_law_fusions and get_stack_count(&"orbital_tether_upgrade") > 0:
			_fling_satellites_with_time_fracture(impulse, stacks)

	_was_time_dilating = is_dilating

func _connect_momentum_component() -> void:
	if _momentum_component != null and is_instance_valid(_momentum_component) and not _momentum_component.is_queued_for_deletion():
		return
	if _player == null or not is_instance_valid(_player):
		return

	_momentum_component = _player.get_node_or_null("MomentumCombatComponent")
	if _momentum_component == null or not _momentum_component.has_signal("kinetic_shockwave_created"):
		return

	var callable := Callable(self, "_on_kinetic_shockwave_created")
	if not _momentum_component.is_connected("kinetic_shockwave_created", callable):
		_momentum_component.connect("kinetic_shockwave_created", callable)

func _on_kinetic_shockwave_created(shockwave_data: Dictionary) -> void:
	if not enable_law_fusions or get_stack_count(&"singularity_amplifier") <= 0:
		return

	var center: Vector2 = shockwave_data.get("position", Vector2.ZERO)
	var base_radius := float(shockwave_data.get("radius", 180.0))
	var speed := float(shockwave_data.get("speed", 0.0))
	var radius := maxf(base_radius * fusion_debris_bend_radius_multiplier, base_radius + 24.0)
	var radius_squared := radius * radius
	var affected := 0

	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):
		if affected >= fusion_debris_bend_max_targets:
			break
		var debris_2d := debris as Node2D
		if debris_2d == null or not is_instance_valid(debris_2d) or debris_2d.is_queued_for_deletion():
			continue

		var offset := debris_2d.global_position - center
		var dist_squared := offset.length_squared()
		if dist_squared <= 0.001 or dist_squared > radius_squared:
			continue

		var falloff := 1.0 - sqrt(dist_squared) / radius
		var impulse := offset.normalized() * fusion_debris_bend_force * falloff * (1.0 + speed / 2400.0)
		if debris_2d.has_method("apply_fusion_impulse"):
			debris_2d.call("apply_fusion_impulse", impulse, Color(0.36, 0.9, 1.0, 1.0))
		affected += 1

	if affected <= 0:
		return

	_emit_law_fusion(&"momentum_singularity", {
		"position": center,
		"radius": radius,
		"affected": affected,
		"speed": speed,
	})
	_spawn_fusion_ring(center, radius, Color(0.36, 0.9, 1.0, 0.72))

func _try_anchor_satellite_to_debris(entry: Dictionary, projectile: Node2D, singularity_stacks: int) -> void:
	var now := _now_seconds()
	if float(entry.get("debris_anchor_until", 0.0)) > now:
		return
	if float(entry.get("next_debris_anchor", 0.0)) > now:
		return

	var anchor := _nearest_debris(projectile.global_position, fusion_debris_satellite_capture_radius + 28.0 * float(singularity_stacks - 1))
	if anchor == null:
		entry["next_debris_anchor"] = now + 0.22
		return

	entry["debris_anchor"] = anchor
	entry["debris_anchor_until"] = now + fusion_debris_satellite_capture_duration
	entry["next_debris_anchor"] = now + fusion_debris_satellite_capture_duration + 0.35
	projectile.set_meta(&"singularity_debris_anchor", anchor.get_instance_id())

	_emit_law_fusion(&"singularity_orbital", {
		"position": anchor.global_position,
		"projectile": projectile,
		"anchor": anchor,
	})

func _valid_debris_anchor(entry: Dictionary) -> Node2D:
	var anchor = entry.get("debris_anchor")
	if anchor == null or not is_instance_valid(anchor):
		return null
	var anchor_2d := anchor as Node2D
	if anchor_2d == null or anchor_2d.is_queued_for_deletion():
		return null
	if float(entry.get("debris_anchor_until", 0.0)) <= _now_seconds():
		return null
	return anchor_2d

func _nearest_debris(position: Vector2, search_radius: float) -> Node2D:
	var best: Node2D = null
	var best_distance := search_radius * search_radius
	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):
		var debris_2d := debris as Node2D
		if debris_2d == null or not is_instance_valid(debris_2d) or debris_2d.is_queued_for_deletion():
			continue
		var distance := debris_2d.global_position.distance_squared_to(position)
		if distance < best_distance:
			best = debris_2d
			best_distance = distance
	return best

func _fling_satellites_with_time_fracture(impulse: Vector2, time_stacks: int) -> void:
	if impulse.length_squared() <= 1.0 or _captured_projectiles.is_empty():
		return

	var release_ids: Array[int] = []
	var impulse_dir := impulse.normalized()
	var count := _captured_projectiles.size()
	var released := 0

	for id in _captured_projectiles.keys():
		var entry_value = _captured_projectiles[id]
		if typeof(entry_value) != TYPE_DICTIONARY:
			release_ids.append(id)
			continue
		var entry: Dictionary = entry_value
		var projectile := entry.get("projectile") as Node2D
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			release_ids.append(id)
			continue

		var spread := 0.0 if count <= 1 else lerpf(-0.42, 0.42, float(released) / float(count - 1))
		var radial := (projectile.global_position - _player.global_position).normalized()
		if radial == Vector2.ZERO:
			radial = Vector2.RIGHT.rotated(float(entry.get("angle", 0.0)))
		var arc_dir := (impulse_dir.rotated(spread) * 0.72 + radial.orthogonal() * 0.28).normalized()
		_release_satellite(projectile, arc_dir, fusion_satellite_arc_speed + impulse.length() * (0.36 + 0.08 * float(time_stacks - 1)))
		release_ids.append(id)
		released += 1

	for id in release_ids:
		_captured_projectiles.erase(id)

	if released <= 0:
		return

	_emit_law_fusion(&"orbital_time_fracture", {
		"position": _player.global_position,
		"impulse": impulse,
		"released": released,
	})
	_spawn_fusion_ring(_player.global_position, 180.0 + 28.0 * float(released), Color(0.35, 0.86, 1.0, 0.76))

func _emit_law_fusion(fusion_id: StringName, fusion_data: Dictionary) -> void:
	_last_fusion_id = fusion_id
	_last_fusion_time = _now_seconds()
	law_fusion_triggered.emit(fusion_id, fusion_data)

func _spawn_fusion_ring(center: Vector2, radius: float, ring_color: Color) -> void:
	if not fusion_visuals_enabled:
		return
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := Line2D.new()
	ring.name = "LawFusionRing"
	ring.closed = true
	ring.antialiased = true
	ring.width = 4.0
	ring.default_color = ring_color
	ring.points = _circle_points(54, 1.0)
	ring.global_position = center
	ring.scale = Vector2.ONE * 18.0
	ring.z_index = 26
	root.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.26)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.26)
	tween.tween_callback(ring.queue_free)

func get_law_fusion_debug_state() -> Dictionary:
	var active: Array[String] = []
	if get_stack_count(&"singularity_amplifier") > 0:
		active.append("Momentum+Singularity")
	if get_stack_count(&"singularity_amplifier") > 0 and get_stack_count(&"orbital_tether_upgrade") > 0:
		active.append("Singularity+Orbital")
	if get_stack_count(&"orbital_tether_upgrade") > 0 and get_stack_count(&"time_fracture_pulse") > 0:
		active.append("Orbital+Time")

	return {
		"active": active,
		"satellites": _count_valid_satellites(),
		"last": String(_last_fusion_id),
		"last_age": _now_seconds() - _last_fusion_time,
	}

func _get_time_dilation_manager() -> Node:
	if _time_dilation_manager != null and is_instance_valid(_time_dilation_manager) and not _time_dilation_manager.is_queued_for_deletion():
		return _time_dilation_manager

	var tree = get_tree()
	if tree == null:
		return null
		
	var root = tree.current_scene
	if root == null:
		return null

	_time_dilation_manager = root.find_child("TimeDilationManager", true, false)
	return _time_dilation_manager

func _body_velocity(body: Node) -> Vector2:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return Vector2.ZERO

	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		return velocity

	var linear_velocity: Variant = body.get("linear_velocity")
	if linear_velocity is Vector2:
		return linear_velocity

	return Vector2.ZERO

func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
