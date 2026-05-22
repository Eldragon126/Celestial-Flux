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

var _player: Node2D = null
var _stacks: Dictionary = {}
var _timed_effects: Dictionary = {}
var _time_pulse_ready := 0.0
var _next_slingshot_convergence_time := 0.0

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


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
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

	for enemy in tree.get_nodes_in_group("enemies"):
		var enemy_2d := enemy as Node2D

		if not _is_node_valid(enemy_2d):
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
	_update_momentum_shockwave_law()
	_update_orbital_satellites(delta)
	_update_singularity_death_hooks()
	_update_time_fracture_storage(delta)


func _update_orbital_satellites(delta: float) -> void:
	var stacks := get_stack_count(&"orbital_tether_upgrade")

	if stacks <= 0:
		_release_all_satellites()
		return

	_capture_nearby_projectiles(stacks)
	_update_captured_projectiles(delta)


func _capture_nearby_projectiles(stacks: int, override_radius: float = -1.0) -> void:
	var tree := get_tree()

	if tree == null:
		return

	var max_satellites = max(1, stacks * max_satellites_per_stack)

	if _count_valid_satellites() >= max_satellites:
		return

	var capture_radius := satellite_capture_radius if override_radius <= 0.0 else override_radius
	var radius_squared := capture_radius * capture_radius

	for projectile in tree.get_nodes_in_group("enemy_projectiles"):

		if _count_valid_satellites() >= max_satellites:
			return

		var projectile_2d := projectile as Node2D

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

		var projectile := instance_from_id(entry.get("projectile_id", -1)) as Node2D

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

		var projectile := instance_from_id(entry.get("projectile_id", -1)) as Node2D

		if _is_node_valid(projectile):
			_release_satellite(projectile, Vector2.RIGHT)

		erase_ids.append(id)

	for id in erase_ids:
		_captured_projectiles.erase(id)


func _count_valid_satellites() -> int:
	var count := 0

	for entry_value in _captured_projectiles.values():
		var entry := entry_value as Dictionary

		var projectile := instance_from_id(entry.get("projectile_id", -1)) as Node2D

		if _is_node_valid(projectile):
			count += 1

	return count


func _update_singularity_death_hooks() -> void:
	var stacks := get_stack_count(&"singularity_amplifier")

	if stacks <= 0:
		return

	var tree := get_tree()

	if tree == null:
		return

	var stale: Array[int] = []

	for id in _enemy_death_hooks.keys():
		if not is_instance_id_valid(id):
			stale.append(id)

	for id in stale:
		_enemy_death_hooks.erase(id)

	for enemy in tree.get_nodes_in_group("enemies"):

		if enemy == _player:
			continue

		var enemy_node := enemy as Node

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

	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):

		if affected >= fusion_debris_bend_max_targets:
			break

		var debris_2d := debris as Node2D

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

	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):
		if affected >= max_targets:
			break

		var debris_2d := debris as Node2D
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
	var radius_squared := radius * radius
	var affected := 0
	var max_affected := 34 + combo * 3

	for group_name in [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if affected >= max_affected:
				return affected
			var target_2d := target as Node2D
			if not _is_node_valid(target_2d):
				continue
			if target_2d.global_position.distance_squared_to(position) > radius_squared:
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
		var projectile := instance_from_id(entry.get("projectile_id", -1)) as Node2D

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

	var anchor := instance_from_id(anchor_id) as Node2D

	if not _is_node_valid(anchor):
		return null

	return anchor


func _nearest_debris(position: Vector2, search_radius: float) -> Node2D:
	var best: Node2D = null
	var best_distance := search_radius * search_radius

	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):

		var debris_2d := debris as Node2D

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

		var projectile := instance_from_id(entry.get("projectile_id", -1)) as Node2D

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

func _spawn_powerup_burst(definition: PowerupDefinition, stacks: int) -> void:
	if not powerup_visuals_enabled or definition == null or not _is_node_valid(_player):
		return

	var root := get_tree().current_scene
	if root == null:
		return

	var burst_color := definition.color
	var radius := powerup_burst_radius + 24.0 * float(maxi(stacks - 1, 0))

	var ring := Line2D.new()
	ring.name = "PowerupLawBurst"
	ring.closed = true
	ring.antialiased = true
	ring.width = 6.0
	ring.default_color = Color(burst_color.r, burst_color.g, burst_color.b, 0.9)
	ring.points = _circle_points(60, 1.0)
	ring.global_position = _player.global_position
	ring.scale = Vector2.ONE * 14.0
	ring.z_index = 28
	root.add_child(ring)

	var echo := Line2D.new()
	echo.name = "PowerupLawEcho"
	echo.closed = true
	echo.antialiased = true
	echo.width = 2.0
	echo.default_color = Color(1.0, 1.0, 1.0, 0.58)
	echo.points = _circle_points(36, 1.0)
	echo.global_position = _player.global_position
	echo.scale = Vector2.ONE * 8.0
	echo.z_index = 29
	root.add_child(echo)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.34)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.34)
	tween.tween_callback(ring.queue_free)

	var echo_tween := echo.create_tween()
	echo_tween.tween_property(echo, "scale", Vector2.ONE * (radius * 0.58), 0.18)
	echo_tween.parallel().tween_property(echo, "modulate:a", 0.0, 0.18)
	echo_tween.tween_callback(echo.queue_free)


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
