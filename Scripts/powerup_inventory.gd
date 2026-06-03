extends Node
class_name PowerupInventory

signal powerup_applied(definition: PowerupDefinition, stacks: int)
signal powerup_expired(powerup_id: StringName)
signal orbital_satellite_captured(projectile: Node, stacks: int)
signal gravity_debris_spawned(debris: Node, source_enemy: Node)
signal time_fracture_released(impulse: Vector2)
signal law_fusion_triggered(fusion_id: StringName, fusion_data: Dictionary)
signal apex_vector_released(data: Dictionary)
signal barycentric_tether_applied(data: Dictionary)
signal frame_dragging_anchor_applied(data: Dictionary)

@export_node_path("Node2D") var player_path: NodePath = ^".."
@export var action_pulse_cooldown: float = 0.65

@export_group("Orbital Law")
@export var satellite_capture_radius: float = 340.0
@export var satellite_orbit_radius: float = 118.0
@export var satellite_duration: float = 3.3
@export var max_satellites_per_stack: int = 3

@export_group("Singularity Law")
@export var singularity_debris_lifetime: float = 4.2
@export var singularity_debris_radius: float = 118.0
@export var singularity_debris_mass: float = 92000.0
@export var singularity_debris_particle_cap: int = 52

@export_group("Time Fracture Law")
@export var time_fracture_store_rate: float = 0.36
@export var time_fracture_release_cap: float = 860.0

@export_group("Pickup Readability")
@export var powerup_visuals_enabled: bool = true
@export var powerup_burst_radius: float = 180.0

@export_group("Law Fusion")
@export var enable_law_fusions: bool = true
@export var enemy_hook_scan_interval: float = 0.25
@export var fusion_debris_bend_force: float = 340.0
@export var fusion_debris_bend_radius_multiplier: float = 1.45
@export var fusion_debris_bend_max_targets: int = 7
@export var fusion_satellite_arc_speed: float = 980.0
@export var fusion_debris_satellite_capture_radius: float = 260.0
@export var fusion_debris_satellite_capture_duration: float = 0.72
@export var fusion_visuals_enabled: bool = true
@export var slingshot_convergence_radius: float = 430.0
@export var slingshot_convergence_cooldown: float = 0.32
@export var slingshot_time_lens_multiplier: float = 0.46

@export_group("Apex Vector Core")
@export var apex_vector_score_threshold: float = 0.82
@export var apex_vector_charge_required: int = 2
@export var apex_vector_release_force: float = 520.0
@export var apex_vector_damage: float = 12.0
@export var apex_vector_max_targets: int = 24

@export_group("Barycentric Tether")
@export var barycentric_tick_interval: float = 0.08
@export var barycentric_max_pairs: int = 6
@export var barycentric_min_pair_distance: float = 72.0
@export var barycentric_max_pair_distance: float = 620.0
@export var barycentric_enemy_damage_per_second: float = 5.5

@export_group("Frame-Dragging Anchor")
@export var frame_dragging_tick_interval: float = 0.07
@export var frame_dragging_max_targets: int = 18
@export var frame_dragging_projectile_force_multiplier: float = 1.35
@export var frame_dragging_slingshot_boost: float = 0.24

var _player: Node2D = null
var _stacks: Dictionary = {}
var _timed_effects: Dictionary = {}
var _time_pulse_ready := 0.0
var _next_slingshot_convergence_time := 0.0
var _apex_vector_charge := 0

# instance_id -> data
var _captured_projectiles: Dictionary = {}

# enemy_instance_id -> Callable
var _enemy_death_hooks: Dictionary = {}

var _stored_time_fracture_velocity := Vector2.ZERO
var _was_time_dilating := false

var _time_dilation_manager: Node = null
var _momentum_component: Node = null

var _last_fusion_id: StringName = &"none"
var _last_fusion_time := -999.0
var _enemy_hook_scan_elapsed := 999.0
var _barycentric_elapsed := 999.0
var _frame_dragging_elapsed := 999.0
var _projectile_query: Array[Node2D] = []
var _enemy_query: Array[Node2D] = []
var _debris_query: Array[Node2D] = []
var _target_query: Array[Node2D] = []
var _fusion_ring_pool: Array[Line2D] = []
var _powerup_ring_pool: Array[Line2D] = []
var _powerup_echo_pool: Array[Line2D] = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_connect_player_slingshot_mastery()
	set_process(true)


func _process(delta: float) -> void:
	if not _is_node_valid(_player):
		return

	_update_law_rules(delta)

	var expired: Array[StringName] = []

	for id in _timed_effects.keys():
		var entry: Dictionary = _timed_effects[id]

		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		_timed_effects[id] = entry

		if float(entry["remaining"]) <= 0.0:
			expired.append(id)

	for id in expired:
		_timed_effects.erase(id)
		_stacks.erase(id)
		powerup_expired.emit(id)


func apply_powerup(definition: PowerupDefinition) -> void:
	if definition == null:
		return

	if not _is_node_valid(_player):
		return

	var id := definition.powerup_id
	var previous_stack := int(_stacks.get(id, 0))
	var current_stack := previous_stack

	match definition.stack_policy:
		PowerupDefinition.StackPolicy.MUTUALLY_EXCLUSIVE:
			current_stack = 1

		PowerupDefinition.StackPolicy.REFRESH_DURATION:
			current_stack = max(1, current_stack)

		_:
			current_stack = mini(current_stack + 1, max(1, definition.max_stacks))

	_stacks[id] = current_stack

	if definition.duration > 0.0:
		_timed_effects[id] = {
			"definition": definition,
			"remaining": definition.duration,
		}

	if (
		definition.stack_policy == PowerupDefinition.StackPolicy.STACKABLE
		and current_stack == previous_stack
	):
		powerup_applied.emit(definition, current_stack)
		return

	_apply_effect(definition, current_stack)
	_spawn_powerup_burst(definition, current_stack)
	powerup_applied.emit(definition, current_stack)


func trigger_player_action() -> void:
	if not _is_node_valid(_player):
		return

	var tree := get_tree()
	if tree == null:
		return

	var now := _now_seconds()

	if now < _time_pulse_ready:
		return

	var time_stack := _get_stack_for_effect(&"time_fracture_pulse")

	if time_stack <= 0:
		return

	_time_pulse_ready = now + action_pulse_cooldown

	var pulse_radius := 320.0 + 70.0 * float(time_stack - 1)
	var slow_multiplier := maxf(0.34, 0.52 - 0.06 * float(time_stack - 1))
	var duration := 0.75 + 0.16 * float(time_stack - 1)

	_fill_targets_in_radius(
		[&"enemies", &"wave_enemy", &"bosses"],
		_player.global_position,
		pulse_radius,
		false,
		_target_query,
		42
	)
	for enemy_2d in _target_query:
		CombatStatus.apply_local_slow(enemy_2d, slow_multiplier, duration)


func get_stack_count(powerup_id: StringName) -> int:
	return int(_stacks.get(powerup_id, 0))


func _apply_effect(definition: PowerupDefinition, stacks: int) -> void:
	match definition.effect_type:

		&"singularity_amplifier":
			if _player.get("gravity_constant") != null:
				_player.set(
					"gravity_constant",
					float(_player.get("gravity_constant")) + definition.amount
				)

			if _player.get("gravity_pull_radius") != null:
				_player.set(
					"gravity_pull_radius",
					float(_player.get("gravity_pull_radius")) + definition.radius
				)

			if _player.get("recoil_instability") != null:
				_player.set(
					"recoil_instability",
					float(_player.get("recoil_instability")) + definition.secondary_amount
				)

		&"time_fracture_pulse":
			trigger_player_action()

		&"shield_overcharge":
			var shield := _player.get_node_or_null("Shield")

			if _is_node_valid(shield):

				if shield.has_method("restore_shield"):
					shield.call("restore_shield", definition.amount)

				if shield.has_method("add_temporary_max_bonus"):
					shield.call(
						"add_temporary_max_bonus",
						definition.secondary_amount,
						definition.duration,
						&"shield_overcharge"
					)

		&"orbital_tether_upgrade":
			if _player.get("max_gravity_anchors") != null:
				_player.set(
					"max_gravity_anchors",
					int(_player.get("max_gravity_anchors")) + int(definition.amount)
				)

			if _player.get("orbit_control_bonus") != null:
				_player.set(
					"orbit_control_bonus",
					float(_player.get("orbit_control_bonus")) + definition.secondary_amount
				)

		&"momentum_shockwave_law":
			_apply_momentum_shockwave_law(stacks)

		&"apex_vector_core":
			_apply_apex_vector_core(definition, stacks)

		&"barycentric_tether":
			_barycentric_elapsed = maxf(barycentric_tick_interval, 0.03)

		&"frame_dragging_anchor":
			_frame_dragging_elapsed = maxf(frame_dragging_tick_interval, 0.03)

		&"micro_lensing_emitter", &"vacuum_collapse_injector", &"relativistic_rail", &"orbital_debris_seeder", &"chronal_refraction_beam":
			_activate_vector_anomaly_upgrade(definition, stacks)


func _get_stack_for_effect(effect_type: StringName) -> int:
	var best := 0

	for id in _stacks.keys():
		var entry: Dictionary = _timed_effects.get(id, {})
		var definition := entry.get("definition", null) as PowerupDefinition

		if definition == null and ClassDB.class_exists("PowerupLibrary"):
			definition = PowerupLibrary.get_definition(id)

		if definition != null and definition.effect_type == effect_type:
			best = max(best, int(_stacks[id]))

	return best


func _update_law_rules(delta: float) -> void:
	if not _is_node_valid(_player):
		return

	_connect_momentum_component()
	_connect_player_slingshot_mastery()
	_update_momentum_shockwave_law()
	_update_orbital_satellites(delta)
	_update_singularity_death_hooks(delta)
	_update_time_fracture_storage(delta)
	_update_barycentric_tether(delta)
	_update_frame_dragging_anchor(delta)


func _update_orbital_satellites(delta: float) -> void:
	var stacks := get_stack_count(&"orbital_tether_upgrade")

	if stacks <= 0:
		_release_all_satellites()
		return

	_capture_nearby_projectiles(stacks)
	_update_captured_projectiles(delta)


func _capture_nearby_projectiles(stacks: int, override_radius: float = -1.0) -> void:
	var max_satellites = max(1, stacks * max_satellites_per_stack)

	if _count_valid_satellites() >= max_satellites:
		return

	var capture_radius := satellite_capture_radius if override_radius <= 0.0 else override_radius
	var radius_squared := capture_radius * capture_radius

	_fill_group_nodes(&"enemy_projectiles", _projectile_query)
	for projectile_2d in _projectile_query:
		if _count_valid_satellites() >= max_satellites:
			return

		if not _is_node_valid(projectile_2d):
			continue

		if projectile_2d.global_position.distance_squared_to(_player.global_position) > radius_squared:
			continue

		if projectile_2d.has_meta(&"orbital_satellite_owner"):
			continue

		var angle := (_player.global_position.direction_to(projectile_2d.global_position)).angle()

		projectile_2d.set_meta(&"orbital_satellite_owner", _player.get_instance_id())
		projectile_2d.set_meta(&"converted_to_player_projectile", true)

		projectile_2d.remove_from_group("enemy_projectiles")
		projectile_2d.add_to_group("player_projectiles")
		if RuntimeRegistry != null:
			RuntimeRegistry.unregister_node(projectile_2d, &"enemy_projectiles")
			RuntimeRegistry.register_node(projectile_2d, &"player_projectiles")

		_captured_projectiles[projectile_2d.get_instance_id()] = {
			"projectile_id": projectile_2d.get_instance_id(),
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

		var entry := _captured_projectiles[id] as Dictionary

		if entry.is_empty():
			expired.append(id)
			continue

		var projectile := _node2d_from_instance_id(int(entry.get("projectile_id", -1)))

		if not _is_node_valid(projectile):
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

		if _is_node_valid(anchor):
			orbit_center = anchor.global_position

			var anchor_radius := 78.0

			if anchor.get("radius") != null:
				anchor_radius = maxf(float(anchor.get("radius")) * 0.74, 58.0)

			radius = minf(radius, anchor_radius)

		var offset := Vector2.RIGHT.rotated(angle) * radius
		var tangent := offset.normalized().orthogonal()

		projectile.global_position = orbit_center + offset

		CombatStatus.add_velocity(projectile, tangent * 32.0)

		if projectile.get("linear_velocity") is Vector2:
			var inherited := Vector2.ZERO

			if anchor == null:
				inherited = _body_velocity(_player) * 0.2

			projectile.set(
				"linear_velocity",
				tangent * 720.0 + inherited
			)

		if float(entry["age"]) >= satellite_duration:
			_release_satellite(projectile, tangent)
			expired.append(id)
		else:
			_captured_projectiles[id] = entry

	for id in expired:
		_captured_projectiles.erase(id)


func _release_satellite(
	projectile: Node2D,
	tangent: Vector2,
	release_speed: float = 920.0
) -> void:

	if not _is_node_valid(projectile):
		return

	projectile.remove_meta(&"orbital_satellite_owner")
	projectile.remove_meta(&"singularity_debris_anchor")

	if projectile.get("linear_velocity") is Vector2:
		projectile.set(
			"linear_velocity",
			tangent.normalized() * release_speed + _body_velocity(_player) * 0.25
		)


func _release_all_satellites() -> void:
	var erase_ids: Array[int] = []

	for id in _captured_projectiles.keys():
		var entry := _captured_projectiles[id] as Dictionary

		var projectile := _node2d_from_instance_id(int(entry.get("projectile_id", -1)))

		if _is_node_valid(projectile):
			_release_satellite(projectile, Vector2.RIGHT)

		erase_ids.append(id)

	for id in erase_ids:
		_captured_projectiles.erase(id)


func _count_valid_satellites() -> int:
	var count := 0

	for entry_value in _captured_projectiles.values():
		var entry := entry_value as Dictionary

		var projectile := _node2d_from_instance_id(int(entry.get("projectile_id", -1)))

		if _is_node_valid(projectile):
			count += 1

	return count


func _update_singularity_death_hooks(delta: float) -> void:
	var stacks := get_stack_count(&"singularity_amplifier")

	if stacks <= 0:
		return

	_enemy_hook_scan_elapsed += delta
	if _enemy_hook_scan_elapsed < maxf(enemy_hook_scan_interval, 0.05):
		return
	_enemy_hook_scan_elapsed = 0.0

	var stale: Array[int] = []

	for id in _enemy_death_hooks.keys():
		if not is_instance_id_valid(id):
			stale.append(id)

	for id in stale:
		_enemy_death_hooks.erase(id)

	_fill_group_nodes(&"enemies", _enemy_query)
	for enemy_node in _enemy_query:
		if enemy_node == _player:
			continue

		if not _is_node_valid(enemy_node):
			continue

		var id := enemy_node.get_instance_id()

		if _enemy_death_hooks.has(id):
			continue

		var health := enemy_node.get_node_or_null("HealthComponent")

		if health != null and health.has_signal("died"):
			var callable := Callable(self, "_on_tracked_enemy_died").bind(enemy_node)

			if not health.is_connected("died", callable):
				health.connect("died", callable)

			_enemy_death_hooks[id] = callable


func _on_tracked_enemy_died(enemy: Node) -> void:
	if enemy == null:
		return

	_enemy_death_hooks.erase(enemy.get_instance_id())

	if not _is_node_valid(enemy):
		return

	if get_stack_count(&"singularity_amplifier") <= 0:
		return

	var enemy_2d := enemy as Node2D

	if enemy_2d == null:
		return

	var tree := get_tree()

	if tree == null or tree.current_scene == null:
		return

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
	debris.global_position = enemy_2d.global_position

	tree.current_scene.call_deferred("add_child", debris)

	gravity_debris_spawned.emit(debris, enemy)


func _update_time_fracture_storage(delta: float) -> void:
	var stacks := get_stack_count(&"time_fracture_pulse")

	var time_manager := _get_time_dilation_manager()

	var is_dilating := false

	if _is_node_valid(time_manager):
		var dilating_value = time_manager.get("is_dilating")

		if dilating_value is bool:
			is_dilating = dilating_value

	if stacks > 0 and is_dilating:
		var velocity := _body_velocity(_player)

		if velocity.length_squared() > 1.0:
			_stored_time_fracture_velocity += (
				velocity.normalized()
				* velocity.length()
				* time_fracture_store_rate
				* delta
			)

			_stored_time_fracture_velocity = (
				_stored_time_fracture_velocity.limit_length(time_fracture_release_cap)
			)

	if (
		_was_time_dilating
		and not is_dilating
		and _stored_time_fracture_velocity.length_squared() > 1.0
	):
		var impulse := _stored_time_fracture_velocity

		_stored_time_fracture_velocity = Vector2.ZERO

		CombatStatus.add_velocity(_player, impulse)

		time_fracture_released.emit(impulse)

		if enable_law_fusions and get_stack_count(&"orbital_tether_upgrade") > 0:
			_fling_satellites_with_time_fracture(impulse, stacks)

	_was_time_dilating = is_dilating


func _update_barycentric_tether(delta: float) -> void:
	var stacks := get_stack_count(&"barycentric_tether")
	if stacks <= 0:
		return

	_barycentric_elapsed += delta
	var interval := maxf(barycentric_tick_interval, 0.03)
	if _barycentric_elapsed < interval:
		return

	var field_delta := minf(maxf(_barycentric_elapsed, interval), interval * 2.5)
	_barycentric_elapsed = 0.0

	var definition := PowerupLibrary.get_definition(&"barycentric_tether")
	var base_radius := 540.0
	var base_force := 260.0
	var orbit_bias := 0.36
	if definition != null:
		base_radius = maxf(definition.radius, base_radius)
		base_force = maxf(definition.amount, 1.0)
		orbit_bias = clampf(definition.secondary_amount, 0.2, 0.78)

	var search_radius := base_radius + 64.0 * float(stacks - 1)
	var pair_distance_cap := barycentric_max_pair_distance + 42.0 * float(stacks - 1)
	var pair_limit := maxi(2, barycentric_max_pairs * 2 + 2)
	var force := base_force * (1.0 + 0.18 * float(stacks - 1))
	var damage_per_second := barycentric_enemy_damage_per_second * (1.0 + 0.25 * float(stacks - 1))
	var tick_id := Time.get_ticks_msec()

	_fill_targets_in_radius(
		[&"enemies", &"wave_enemy", &"bosses"],
		_player.global_position,
		search_radius,
		false,
		_target_query,
		pair_limit
	)

	var pairs := 0
	var affected := 0

	for target_2d in _target_query:
		if pairs >= barycentric_max_pairs:
			break
		if not _is_node_valid(target_2d) or target_2d == _player:
			continue
		if _has_barycentric_tick(target_2d, tick_id):
			continue

		var partner := _find_barycentric_partner(
			target_2d,
			barycentric_min_pair_distance,
			pair_distance_cap,
			tick_id
		)
		if partner == null:
			continue

		target_2d.set_meta(&"barycentric_tether_tick", tick_id)
		partner.set_meta(&"barycentric_tether_tick", tick_id)

		var center := (target_2d.global_position + partner.global_position) * 0.5
		affected += _apply_barycentric_body(
			target_2d,
			center,
			force,
			orbit_bias,
			damage_per_second,
			field_delta,
			pair_distance_cap
		)
		affected += _apply_barycentric_body(
			partner,
			center,
			force,
			orbit_bias,
			damage_per_second,
			field_delta,
			pair_distance_cap
		)
		pairs += 1

	if pairs <= 0:
		return

	barycentric_tether_applied.emit({
		"position": _player.global_position,
		"radius": search_radius,
		"pairs": pairs,
		"affected": affected,
		"stacks": stacks,
	})


func _find_barycentric_partner(
	origin: Node2D,
	min_distance: float,
	max_distance: float,
	tick_id: int
) -> Node2D:
	var best: Node2D = null
	var min_distance_squared := min_distance * min_distance
	var best_distance_squared := max_distance * max_distance

	for candidate in _target_query:
		if candidate == origin or not _is_node_valid(candidate) or candidate == _player:
			continue
		if _has_barycentric_tick(candidate, tick_id):
			continue

		var distance_squared := candidate.global_position.distance_squared_to(origin.global_position)
		if distance_squared < min_distance_squared or distance_squared > best_distance_squared:
			continue

		best = candidate
		best_distance_squared = distance_squared

	return best


func _has_barycentric_tick(body: Node2D, tick_id: int) -> bool:
	return (
		_is_node_valid(body)
		and body.has_meta(&"barycentric_tether_tick")
		and int(body.get_meta(&"barycentric_tether_tick")) == tick_id
	)


func _apply_barycentric_body(
	body: Node2D,
	center: Vector2,
	force: float,
	orbit_bias: float,
	damage_per_second: float,
	field_delta: float,
	pair_distance_cap: float
) -> int:
	if not _is_node_valid(body):
		return 0

	var to_center := center - body.global_position
	var distance_squared := to_center.length_squared()
	if distance_squared <= 0.001:
		return 0

	var distance := sqrt(distance_squared)
	var inward := to_center / distance
	var tangent := inward.orthogonal()
	var velocity := _body_velocity(body)
	if velocity.length_squared() > 1.0:
		if velocity.dot(tangent) < 0.0:
			tangent = -tangent
	elif body.global_position.x > center.x:
		tangent = -tangent

	var falloff := clampf(1.0 - distance / maxf(pair_distance_cap, 1.0), 0.24, 1.0)
	var direction := (tangent * orbit_bias + inward * maxf(1.0 - orbit_bias, 0.18)).normalized()
	CombatStatus.add_velocity(body, direction * force * falloff * field_delta)

	if body.has_method("take_damage"):
		body.call("take_damage", damage_per_second * falloff * field_delta)

	body.set_meta(&"barycentric_tether_pressure", falloff)
	return 1


func _update_frame_dragging_anchor(delta: float) -> void:
	var stacks := get_stack_count(&"frame_dragging_anchor")
	if stacks <= 0:
		return

	_frame_dragging_elapsed += delta
	var interval := maxf(frame_dragging_tick_interval, 0.03)
	if _frame_dragging_elapsed < interval:
		return

	var field_delta := minf(maxf(_frame_dragging_elapsed, interval), interval * 2.5)
	_frame_dragging_elapsed = 0.0

	var definition := PowerupLibrary.get_definition(&"frame_dragging_anchor")
	var radius := 470.0
	var force := 300.0
	var spin_bias := 0.42
	if definition != null:
		radius = maxf(definition.radius, radius)
		force = maxf(definition.amount, 1.0)
		spin_bias = clampf(definition.secondary_amount, 0.24, 0.82)

	radius += 56.0 * float(stacks - 1)
	force *= 1.0 + 0.2 * float(stacks - 1)

	var center := _player.global_position
	var player_velocity := _body_velocity(_player)
	var spin_sign := _frame_dragging_spin_sign(player_velocity)
	var target_limit := frame_dragging_max_targets + 4 * maxi(stacks - 1, 0)

	_fill_targets_in_radius(
		[&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"],
		center,
		radius,
		false,
		_target_query,
		target_limit
	)

	var affected := 0
	for target_2d in _target_query:
		if _apply_frame_dragging_body(
			target_2d,
			center,
			radius,
			force,
			spin_bias,
			spin_sign,
			field_delta
		):
			affected += 1

	if player_velocity.length_squared() > 360000.0:
		var boost := (
			player_velocity.normalized()
			* force
			* frame_dragging_slingshot_boost
			* minf(float(stacks), 2.0)
			* field_delta
		)
		CombatStatus.add_velocity(_player, boost)

	if affected <= 0:
		return

	frame_dragging_anchor_applied.emit({
		"position": center,
		"radius": radius,
		"affected": affected,
		"stacks": stacks,
	})


func _frame_dragging_spin_sign(player_velocity: Vector2) -> float:
	if player_velocity.length_squared() <= 1.0:
		return 1.0

	var facing_tangent := Vector2.RIGHT.rotated(_player.global_rotation).orthogonal()
	return 1.0 if player_velocity.dot(facing_tangent) >= 0.0 else -1.0


func _apply_frame_dragging_body(
	body: Node2D,
	center: Vector2,
	radius: float,
	force: float,
	spin_bias: float,
	spin_sign: float,
	field_delta: float
) -> bool:
	if not _is_node_valid(body) or body == _player:
		return false

	var offset := body.global_position - center
	var distance_squared := offset.length_squared()
	if distance_squared <= 0.001:
		return false

	var distance := sqrt(distance_squared)
	var radial := offset / distance
	var tangent := radial.orthogonal() * spin_sign
	var inward := -radial
	var falloff := clampf(1.0 - distance / maxf(radius, 1.0), 0.18, 1.0)
	var projectile_multiplier := (
		frame_dragging_projectile_force_multiplier
		if body.is_in_group("enemy_projectiles")
		else 1.0
	)
	var direction := (tangent * spin_bias + inward * maxf(1.0 - spin_bias, 0.18)).normalized()

	CombatStatus.add_velocity(
		body,
		direction * force * projectile_multiplier * falloff * field_delta
	)
	body.set_meta(&"frame_dragging_pressure", falloff)
	return true


func _update_momentum_shockwave_law() -> void:
	var stacks := get_stack_count(&"momentum_shockwave_law")
	if _momentum_component == null or not is_instance_valid(_momentum_component):
		return
	if _momentum_component.get("shockwaves_enabled") != null:
		_momentum_component.set("shockwaves_enabled", stacks > 0)
	if stacks <= 0:
		return
	var definition := PowerupLibrary.get_definition(&"momentum_shockwave_law")
	if definition == null:
		return
	if _momentum_component.get("shockwave_radius") != null:
		_momentum_component.set("shockwave_radius", definition.radius + 40.0 * float(stacks - 1))
	if _momentum_component.get("shockwave_force") != null:
		_momentum_component.set("shockwave_force", 520.0 * definition.amount * (1.0 + definition.secondary_amount * float(stacks - 1)))


func _apply_momentum_shockwave_law(stacks: int) -> void:
	_update_momentum_shockwave_law()
	if stacks <= 0:
		return
	trigger_player_action()


func _apply_apex_vector_core(definition: PowerupDefinition, stacks: int) -> void:
	if not _is_node_valid(_player) or definition == null or stacks <= 0:
		return
	if _player.get("slingshot_gravity_boost_scale") != null:
		_player.set(
			"slingshot_gravity_boost_scale",
			float(_player.get("slingshot_gravity_boost_scale")) + definition.amount
		)
	if _player.get("slingshot_mastery_cap_bonus") != null:
		_player.set(
			"slingshot_mastery_cap_bonus",
			float(_player.get("slingshot_mastery_cap_bonus")) + definition.secondary_amount * 1000.0
		)
	_connect_player_slingshot_mastery()


func _activate_vector_anomaly_upgrade(definition: PowerupDefinition, stacks: int) -> void:
	var root := get_tree().current_scene
	if root == null or definition == null or not _is_node_valid(_player):
		return
	var director := root.find_child("VectorAnomalyDirector", true, false)
	if director != null and director.has_method("activate_upgrade_pulse"):
		director.call("activate_upgrade_pulse", definition.powerup_id, _player.global_position, stacks)


func _connect_momentum_component() -> void:
	if _is_node_valid(_momentum_component):
		return

	if not _is_node_valid(_player):
		return

	_momentum_component = _player.get_node_or_null("MomentumCombatComponent")

	if _momentum_component == null:
		return

	if _momentum_component.has_signal("kinetic_shockwave_created"):
		var callable := Callable(self, "_on_kinetic_shockwave_created")

		if not _momentum_component.is_connected("kinetic_shockwave_created", callable):
			_momentum_component.connect("kinetic_shockwave_created", callable)

	if _momentum_component.has_signal("slingshot_mastery_triggered"):
		var mastery_callable := Callable(self, "_on_slingshot_mastery_triggered")

		if not _momentum_component.is_connected("slingshot_mastery_triggered", mastery_callable):
			_momentum_component.connect("slingshot_mastery_triggered", mastery_callable)


func _connect_player_slingshot_mastery() -> void:
	if not _is_node_valid(_player):
		return
	if not _player.has_signal("slingshot_mastery_scored"):
		return
	var callable := Callable(self, "_on_player_slingshot_mastery_scored")
	if not _player.is_connected("slingshot_mastery_scored", callable):
		_player.connect("slingshot_mastery_scored", callable)


func _on_kinetic_shockwave_created(shockwave_data: Dictionary) -> void:
	if not enable_law_fusions:
		return

	if get_stack_count(&"singularity_amplifier") <= 0:
		return

	var center: Vector2 = shockwave_data.get("position", Vector2.ZERO)

	var base_radius := float(shockwave_data.get("radius", 180.0))
	var speed := float(shockwave_data.get("speed", 0.0))

	var radius := maxf(
		base_radius * fusion_debris_bend_radius_multiplier,
		base_radius + 24.0
	)

	var radius_squared := radius * radius

	var affected := 0

	_fill_group_nodes(&"law_gravity_debris", _debris_query)
	for debris_2d in _debris_query:
		if affected >= fusion_debris_bend_max_targets:
			break

		if not _is_node_valid(debris_2d):
			continue

		var offset := debris_2d.global_position - center
		var dist_squared := offset.length_squared()

		if dist_squared <= 0.001 or dist_squared > radius_squared:
			continue

		var falloff := 1.0 - sqrt(dist_squared) / radius

		var impulse := (
			offset.normalized()
			* fusion_debris_bend_force
			* falloff
			* (1.0 + speed / 2400.0)
		)

		if debris_2d.has_method("apply_fusion_impulse"):
			debris_2d.call(
				"apply_fusion_impulse",
				impulse,
				Color(0.36, 0.9, 1.0, 1.0)
			)

		affected += 1

	if affected <= 0:
		return

	_emit_law_fusion(
		&"momentum_singularity",
		{
			"position": center,
			"radius": radius,
			"affected": affected,
			"speed": speed,
		}
	)

	_spawn_fusion_ring(
		center,
		radius,
		Color(0.36, 0.9, 1.0, 0.72)
	)


func _on_slingshot_mastery_triggered(data: Dictionary) -> void:
	if not enable_law_fusions or not _is_node_valid(_player):
		return

	var now := _now_seconds()
	if now < _next_slingshot_convergence_time:
		return

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < 0.58:
		return

	_next_slingshot_convergence_time = now + slingshot_convergence_cooldown

	var position: Vector2 = data.get("position", _player.global_position)
	var tangent: Vector2 = data.get("tangent", _body_velocity(_player).normalized())
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	tangent = tangent.normalized()
	var combo := int(data.get("combo", 1))
	var radius := slingshot_convergence_radius * (0.82 + score * 0.34 + float(combo) * 0.045)

	var orbital_stacks := get_stack_count(&"orbital_tether_upgrade")
	var singularity_stacks := get_stack_count(&"singularity_amplifier")
	var time_stacks := get_stack_count(&"time_fracture_pulse")

	var before_satellites := _count_valid_satellites()
	if orbital_stacks > 0:
		_capture_nearby_projectiles(orbital_stacks, radius)
	var captured = max(_count_valid_satellites() - before_satellites, 0)

	var debris_bent := 0
	if singularity_stacks > 0:
		debris_bent = _bend_debris_from_slingshot(position, tangent, radius, score, combo)

	var slowed := 0
	if time_stacks > 0:
		slowed = _pulse_time_lens_from_slingshot(position, radius, score, combo, time_stacks)

	var released := 0
	if orbital_stacks > 0 and (time_stacks > 0 or score >= 0.82):
		released = _fling_satellites_along_slingshot(tangent, score, combo)

	var resonance_id := _amplify_resonance_from_slingshot(data, radius, orbital_stacks, singularity_stacks, time_stacks)

	var triggered : int = captured + debris_bent + slowed + released
	if resonance_id != 0:
		triggered += 1

	if triggered <= 0:
		return

	_emit_law_fusion(
		&"slingshot_law_convergence",
		{
			"position": position,
			"tangent": tangent,
			"radius": radius,
			"score": score,
			"combo": combo,
			"captured": captured,
			"debris_bent": debris_bent,
			"slowed": slowed,
			"released": released,
			"resonance_id": resonance_id,
		}
	)

	_spawn_fusion_ring(
		position,
		radius,
		Color(0.28, 1.0, 0.84, 0.82)
	)


func _on_player_slingshot_mastery_scored(data: Dictionary) -> void:
	var stacks := get_stack_count(&"apex_vector_core")
	if stacks <= 0:
		return

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < apex_vector_score_threshold:
		return

	var required := maxi(1, apex_vector_charge_required - mini(stacks - 1, 1))
	_apex_vector_charge += 1
	if _apex_vector_charge < required:
		return

	_apex_vector_charge = 0
	_release_apex_vector(data, stacks)


func _release_apex_vector(data: Dictionary, stacks: int) -> void:
	if not _is_node_valid(_player):
		return

	var position_value: Variant = data.get("position", _player.global_position)
	var position: Vector2 = position_value if position_value is Vector2 else _player.global_position
	var tangent_value: Variant = data.get("tangent", _body_velocity(_player).normalized())
	var tangent: Vector2 = tangent_value if tangent_value is Vector2 else _body_velocity(_player).normalized()
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT.rotated(_player.global_rotation)
	tangent = tangent.normalized()

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var definition := PowerupLibrary.get_definition(&"apex_vector_core")
	var base_radius := 380.0
	if definition != null and definition.radius > 0.0:
		base_radius = definition.radius
	var radius := base_radius + 70.0 * float(stacks - 1) + score * 54.0
	var force := apex_vector_release_force * (1.0 + 0.18 * float(stacks - 1) + score * 0.22)
	var damage := apex_vector_damage * (1.0 + 0.42 * float(stacks - 1) + score * 0.34)

	var affected := _affect_apex_vector_targets(position, tangent, radius, force, damage)
	var resonance_id := _spawn_apex_vector_resonance(position, tangent, radius, stacks)

	var payload := {
		"position": position,
		"tangent": tangent,
		"radius": radius,
		"force": force,
		"damage": damage,
		"affected": affected,
		"stacks": stacks,
		"score": score,
		"resonance_id": resonance_id,
	}
	_emit_law_fusion(&"apex_vector_core", payload)
	apex_vector_released.emit(payload)
	_spawn_fusion_ring(position, radius, Color(0.36, 1.0, 0.84, 0.74))


func _affect_apex_vector_targets(
	position: Vector2,
	tangent: Vector2,
	radius: float,
	force: float,
	damage: float
) -> int:
	var affected := 0
	_fill_targets_in_radius(
		[&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"],
		position,
		radius,
		false,
		_target_query,
		apex_vector_max_targets
	)
	for target_2d in _target_query:
		if not _is_node_valid(target_2d) or target_2d == _player:
			continue

		var offset := target_2d.global_position - position
		var distance := offset.length()
		var radial := offset.normalized()
		if radial == Vector2.ZERO:
			radial = tangent
		var falloff := clampf(1.0 - distance / maxf(radius, 1.0), 0.18, 1.0)
		var impulse_dir := (tangent * 0.72 + radial * 0.28).normalized()
		CombatStatus.add_velocity(target_2d, impulse_dir * force * falloff)

		if not target_2d.is_in_group("enemy_projectiles") and target_2d.has_method("take_damage"):
			target_2d.call("take_damage", damage * falloff)

		affected += 1

	return affected


func _spawn_apex_vector_resonance(
	position: Vector2,
	tangent: Vector2,
	radius: float,
	stacks: int
) -> int:
	var resonance := _find_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return 0
	return int(resonance.call(
		"create_manual_resonance_zone",
		position + tangent * radius * 0.22,
		radius * 0.72,
		GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
		0.68 + 0.06 * float(stacks - 1),
		2.1 + 0.24 * float(stacks - 1)
	))

func _bend_debris_from_slingshot(
	position: Vector2,
	tangent: Vector2,
	radius: float,
	score: float,
	combo: int
) -> int:
	var affected := 0
	var radius_squared := radius * radius
	var max_targets := fusion_debris_bend_max_targets + maxi(int(combo / 2), 0)

	_fill_group_nodes(&"law_gravity_debris", _debris_query)
	for debris_2d in _debris_query:
		if affected >= max_targets:
			break

		if not _is_node_valid(debris_2d):
			continue

		var offset := debris_2d.global_position - position
		var dist_squared := offset.length_squared()
		if dist_squared <= 0.001 or dist_squared > radius_squared:
			continue

		var radial := offset.normalized()
		var falloff := 1.0 - sqrt(dist_squared) / radius
		var impulse := (
			(radial * 0.68 + tangent * 0.32).normalized()
			* fusion_debris_bend_force
			* (0.9 + score + float(combo) * 0.08)
			* falloff
		)

		if debris_2d.has_method("apply_fusion_impulse"):
			debris_2d.call("apply_fusion_impulse", impulse, Color(0.28, 1.0, 0.84, 1.0))

		affected += 1

	return affected

func _pulse_time_lens_from_slingshot(
	position: Vector2,
	radius: float,
	score: float,
	combo: int,
	time_stacks: int
) -> int:
	var time_manager := _get_time_dilation_manager()
	var multiplier := clampf(
		slingshot_time_lens_multiplier - 0.035 * float(time_stacks - 1) - 0.025 * float(combo),
		0.24,
		0.72
	)
	var duration := 0.48 + score * 0.42 + 0.05 * float(combo)
	var affected := 0
	var max_affected := 34 + combo * 3

	_fill_targets_in_radius(
		[&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"],
		position,
		radius,
		false,
		_target_query,
		max_affected
	)
	for target_2d in _target_query:
		if not _is_node_valid(target_2d):
			continue

		if _is_node_valid(time_manager) and time_manager.has_method("apply_local_slow_to_target"):
			time_manager.call("apply_local_slow_to_target", target_2d, multiplier, duration)
		else:
			CombatStatus.apply_local_slow(target_2d, multiplier, duration)
		affected += 1

	return affected

func _fling_satellites_along_slingshot(tangent: Vector2, score: float, combo: int) -> int:
	if _captured_projectiles.is_empty():
		return 0

	var release_ids: Array[int] = []
	var released := 0
	var total := _captured_projectiles.size()

	for id in _captured_projectiles.keys():
		var entry := _captured_projectiles[id] as Dictionary
		var projectile := _node2d_from_instance_id(int(entry.get("projectile_id", -1)))

		if not _is_node_valid(projectile):
			release_ids.append(id)
			continue

		var spread := 0.0
		if total > 1:
			spread = lerpf(-0.34, 0.34, float(released) / float(total - 1))

		_release_satellite(
			projectile,
			tangent.rotated(spread),
			fusion_satellite_arc_speed * (0.82 + score * 0.42) + float(combo) * 42.0
		)

		release_ids.append(id)
		released += 1

	for id in release_ids:
		_captured_projectiles.erase(id)

	return released

func _amplify_resonance_from_slingshot(
	data: Dictionary,
	radius: float,
	orbital_stacks: int,
	singularity_stacks: int,
	time_stacks: int
) -> int:
	var resonance := _find_resonance_manager()
	if resonance == null or not resonance.has_method("amplify_slingshot_mastery"):
		return 0

	var resonance_data := data.duplicate(true)
	resonance_data["radius"] = radius
	resonance_data["orbital_stacks"] = orbital_stacks
	resonance_data["singularity_stacks"] = singularity_stacks
	resonance_data["time_stacks"] = time_stacks
	return int(resonance.call("amplify_slingshot_mastery", resonance_data))

func _find_resonance_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var managers := tree.get_nodes_in_group("gravity_resonance_manager")
	for manager in managers:
		if _is_node_valid(manager):
			return manager

	var root := tree.current_scene
	if root == null:
		return null

	return root.find_child("GravityResonanceManager", true, false)


func _fill_group_nodes(group_name: StringName, out_nodes: Array[Node2D], limit: int = -1) -> void:
	out_nodes.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(group_name, out_nodes, limit)
		return

	var added := 0
	for node in get_tree().get_nodes_in_group(group_name):
		if limit >= 0 and added >= limit:
			return
		if node == null or not is_instance_valid(node):
			continue
		var node_2d := node as Node2D
		if not _is_node_valid(node_2d):
			continue
		out_nodes.append(node_2d)
		added += 1


func _fill_targets_in_radius(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	include_player: bool,
	out_targets: Array[Node2D],
	limit: int
) -> void:
	out_targets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, limit, include_player, out_targets)
		return

	var radius_squared := radius * radius
	var seen := {}
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if limit > 0 and out_targets.size() >= limit:
				return
			if node == null or not is_instance_valid(node):
				continue
			var node_2d := node as Node2D
			if not _is_node_valid(node_2d):
				continue
			if not include_player and node_2d.is_in_group("Player"):
				continue
			var id := node_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if node_2d.global_position.distance_squared_to(center) > radius_squared:
				continue
			out_targets.append(node_2d)


func _acquire_ring(
	pool: Array[Line2D],
	root: Node,
	ring_name: String,
	point_count: int,
	width: float,
	z_index: int
) -> Line2D:
	for ring in pool:
		if ring != null and is_instance_valid(ring) and not ring.visible:
			_prepare_ring(ring, root, ring_name, point_count, width, z_index)
			return ring

	var created := Line2D.new()
	pool.append(created)
	_prepare_ring(created, root, ring_name, point_count, width, z_index)
	return created


func _prepare_ring(
	ring: Line2D,
	root: Node,
	ring_name: String,
	point_count: int,
	width: float,
	z_index: int
) -> void:
	ring.name = ring_name
	ring.closed = true
	ring.antialiased = true
	ring.width = width
	ring.z_index = z_index
	ring.points = _circle_points(point_count, 1.0)
	if ring.get_parent() == null:
		root.add_child(ring)
	elif ring.get_parent() != root:
		ring.reparent(root)


func _release_ring(ring: Line2D) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	ring.visible = false
	ring.modulate = Color.WHITE
	ring.scale = Vector2.ONE


func _try_anchor_satellite_to_debris(
	entry: Dictionary,
	projectile: Node2D,
	singularity_stacks: int
) -> void:

	var now := _now_seconds()

	if float(entry.get("debris_anchor_until", 0.0)) > now:
		return

	if float(entry.get("next_debris_anchor", 0.0)) > now:
		return

	var anchor := _nearest_debris(
		projectile.global_position,
		fusion_debris_satellite_capture_radius
		+ 28.0 * float(singularity_stacks - 1)
	)

	if anchor == null:
		entry["next_debris_anchor"] = now + 0.22
		return

	entry["debris_anchor_id"] = anchor.get_instance_id()
	entry["debris_anchor_until"] = now + fusion_debris_satellite_capture_duration
	entry["next_debris_anchor"] = now + fusion_debris_satellite_capture_duration + 0.35

	projectile.set_meta(
		&"singularity_debris_anchor",
		anchor.get_instance_id()
	)

	_emit_law_fusion(
		&"singularity_orbital",
		{
			"position": anchor.global_position,
			"projectile": projectile,
			"anchor": anchor,
		}
	)


func _valid_debris_anchor(entry: Dictionary) -> Node2D:
	if float(entry.get("debris_anchor_until", 0.0)) <= _now_seconds():
		return null

	var anchor_id := int(entry.get("debris_anchor_id", -1))

	if anchor_id == -1:
		return null

	if not is_instance_id_valid(anchor_id):
		return null

	var anchor := _node2d_from_instance_id(anchor_id)

	if not _is_node_valid(anchor):
		return null

	return anchor


func _nearest_debris(position: Vector2, search_radius: float) -> Node2D:
	var best: Node2D = null
	var best_distance := search_radius * search_radius

	_fill_group_nodes(&"law_gravity_debris", _debris_query)
	for debris_2d in _debris_query:
		if not _is_node_valid(debris_2d):
			continue

		var distance := debris_2d.global_position.distance_squared_to(position)

		if distance < best_distance:
			best = debris_2d
			best_distance = distance

	return best


func _fling_satellites_with_time_fracture(
	impulse: Vector2,
	time_stacks: int
) -> void:

	if impulse.length_squared() <= 1.0:
		return

	if _captured_projectiles.is_empty():
		return

	var release_ids: Array[int] = []

	var impulse_dir := impulse.normalized()

	var count := _captured_projectiles.size()
	var released := 0

	for id in _captured_projectiles.keys():

		var entry := _captured_projectiles[id] as Dictionary

		var projectile := _node2d_from_instance_id(int(entry.get("projectile_id", -1)))

		if not _is_node_valid(projectile):
			release_ids.append(id)
			continue

		var spread := 0.0

		if count > 1:
			spread = lerpf(-0.42, 0.42, float(released) / float(count - 1))

		var radial := (
			projectile.global_position - _player.global_position
		).normalized()

		if radial == Vector2.ZERO:
			radial = Vector2.RIGHT.rotated(float(entry.get("angle", 0.0)))

		var arc_dir := (
			impulse_dir.rotated(spread) * 0.72
			+ radial.orthogonal() * 0.28
		).normalized()

		_release_satellite(
			projectile,
			arc_dir,
			fusion_satellite_arc_speed
			+ impulse.length() * (0.36 + 0.08 * float(time_stacks - 1))
		)

		release_ids.append(id)
		released += 1

	for id in release_ids:
		_captured_projectiles.erase(id)

	if released <= 0:
		return

	_emit_law_fusion(
		&"orbital_time_fracture",
		{
			"position": _player.global_position,
			"impulse": impulse,
			"released": released,
		}
	)

	_spawn_fusion_ring(
		_player.global_position,
		180.0 + 28.0 * float(released),
		Color(0.35, 0.86, 1.0, 0.76)
	)


func _emit_law_fusion(
	fusion_id: StringName,
	fusion_data: Dictionary
) -> void:

	_last_fusion_id = fusion_id
	_last_fusion_time = _now_seconds()

	law_fusion_triggered.emit(fusion_id, fusion_data)


func _spawn_fusion_ring(
	center: Vector2,
	radius: float,
	ring_color: Color
) -> void:

	if not fusion_visuals_enabled:
		return

	var root := get_tree().current_scene

	if root == null:
		return

	var ring := _acquire_ring(_fusion_ring_pool, root, "LawFusionRing", 54, 2.6, 26)
	ring.default_color = _safe_flash_color(ring_color, 0.5)
	ring.global_position = center
	ring.scale = Vector2.ONE * 18.0
	ring.modulate = Color.WHITE
	ring.visible = true

	var tween := ring.create_tween()

	tween.tween_property(ring, "scale", Vector2.ONE * minf(radius, 620.0), 0.24)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.26)
	tween.tween_callback(Callable(self, "_release_ring").bind(ring))

func _spawn_powerup_burst(definition: PowerupDefinition, stacks: int) -> void:
	if not powerup_visuals_enabled or definition == null or not _is_node_valid(_player):
		return

	var root := get_tree().current_scene
	if root == null:
		return

	var burst_color := definition.color
	var radius := powerup_burst_radius + 24.0 * float(maxi(stacks - 1, 0))

	var ring := _acquire_ring(_powerup_ring_pool, root, "PowerupLawBurst", 60, 3.2, 28)
	ring.default_color = _safe_flash_color(Color(burst_color.r, burst_color.g, burst_color.b, 0.62), 0.42)
	ring.global_position = _player.global_position
	ring.scale = Vector2.ONE * 14.0
	ring.modulate = Color.WHITE
	ring.visible = true

	var echo := _acquire_ring(_powerup_echo_pool, root, "PowerupLawEcho", 36, 2.0, 29)
	echo.default_color = _safe_flash_color(Color(1.0, 1.0, 1.0, 0.28), 0.22)
	echo.global_position = _player.global_position
	echo.scale = Vector2.ONE * 8.0
	echo.modulate = Color.WHITE
	echo.visible = true

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.34)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.34)
	tween.tween_callback(Callable(self, "_release_ring").bind(ring))

	var echo_tween := echo.create_tween()
	echo_tween.tween_property(echo, "scale", Vector2.ONE * (radius * 0.58), 0.18)
	echo_tween.parallel().tween_property(echo, "modulate:a", 0.0, 0.18)
	echo_tween.tween_callback(Callable(self, "_release_ring").bind(echo))


func _safe_flash_color(color: Color, alpha_cap: float) -> Color:
	var alpha := minf(color.a, alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func get_law_fusion_debug_state() -> Dictionary:
	var active: Array[String] = []

	if get_stack_count(&"singularity_amplifier") > 0:
		active.append("Momentum+Singularity")

	if (
		get_stack_count(&"singularity_amplifier") > 0
		and get_stack_count(&"orbital_tether_upgrade") > 0
	):
		active.append("Singularity+Orbital")

	if (
		get_stack_count(&"orbital_tether_upgrade") > 0
		and get_stack_count(&"time_fracture_pulse") > 0
	):
		active.append("Orbital+Time")

	if _last_fusion_id == &"slingshot_law_convergence" and _now_seconds() - _last_fusion_time < 3.0:
		active.append("Slingshot+Law")

	if get_stack_count(&"apex_vector_core") > 0:
		active.append("Apex Vector")

	if get_stack_count(&"barycentric_tether") > 0:
		active.append("Barycentric Tether")

	if get_stack_count(&"frame_dragging_anchor") > 0:
		active.append("Frame-Dragging Anchor")

	return {
		"active": active,
		"satellites": _count_valid_satellites(),
		"last": String(_last_fusion_id),
		"last_age": _now_seconds() - _last_fusion_time,
	}


func _get_time_dilation_manager() -> Node:
	if _is_node_valid(_time_dilation_manager):
		return _time_dilation_manager

	var tree := get_tree()

	if tree == null:
		return null

	var root := tree.current_scene

	if root == null:
		return null

	_time_dilation_manager = root.find_child(
		"TimeDilationManager",
		true,
		false
	)

	return _time_dilation_manager


func _body_velocity(body: Node) -> Vector2:
	if not _is_node_valid(body):
		return Vector2.ZERO

	var velocity = body.get("velocity")

	if velocity is Vector2:
		return velocity

	var linear_velocity = body.get("linear_velocity")

	if linear_velocity is Vector2:
		return linear_velocity

	return Vector2.ZERO


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()

	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))

		points.append(
			Vector2(cos(angle), sin(angle)) * radius
		)

	return points


func _node2d_from_instance_id(instance_id: int) -> Node2D:
	if instance_id < 0 or not is_instance_id_valid(instance_id):
		return null
	var value: Object = instance_from_id(instance_id)
	if value == null or not is_instance_valid(value):
		return null
	var node_2d := value as Node2D
	if not _is_node_valid(node_2d):
		return null
	return node_2d


func _is_node_valid(node: Variant) -> bool:
	if node == null:
		return false

	if not is_instance_valid(node):
		return false

	if node.is_queued_for_deletion():
		return false

	if node is Node and not node.is_inside_tree():
		return false

	return true

func export_anchor_stacks() -> Dictionary:
	var out: Dictionary = {}
	for id in _stacks.keys():
		out[String(id)] = int(_stacks[id])
	return out


func import_anchor_stacks(data: Dictionary) -> void:
	_stacks.clear()
	for key in data.keys():
		_stacks[StringName(key)] = int(data[key])
