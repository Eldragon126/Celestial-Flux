extends Node
class_name PowerupInventory

signal powerup_applied(definition: PowerupDefinition, stacks: int)
signal powerup_expired(powerup_id: StringName)
signal orbital_satellite_captured(projectile: Node, stacks: int)
signal gravity_debris_spawned(debris: Node, source_enemy: Node)
signal time_fracture_released(impulse: Vector2)

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

var _player: Node2D = null
var _stacks: Dictionary = {}
var _timed_effects: Dictionary = {}
var _time_pulse_ready = 0.0
var _captured_projectiles: Dictionary = {}
var _enemy_death_hooks: Dictionary = {}
var _stored_time_fracture_velocity := Vector2.ZERO
var _was_time_dilating := false
var _time_dilation_manager: Node = null

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
		}
		orbital_satellite_captured.emit(projectile_2d, stacks)

func _update_captured_projectiles(delta: float) -> void:
	var expired: Array[int] = []
	var orbit_speed := 3.7

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

		var angle := float(entry["angle"])
		var radius := float(entry.get("radius", satellite_orbit_radius))
		var offset := Vector2.RIGHT.rotated(angle) * radius
		var tangent := offset.normalized().orthogonal()
		
		projectile.global_position = _player.global_position + offset
		CombatStatus.add_velocity(projectile, tangent * 32.0)
		
		if projectile.get("linear_velocity") is Vector2:
			projectile.set("linear_velocity", tangent * 720.0 + _body_velocity(_player) * 0.2)

		if float(entry["age"]) >= satellite_duration:
			_release_satellite(projectile, tangent)
			expired.append(id)
		else:
			_captured_projectiles[id] = entry

	for id in expired:
		_captured_projectiles.erase(id)

func _release_satellite(projectile: Node2D, tangent: Vector2) -> void:
	if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
		return
		
	projectile.remove_meta(&"orbital_satellite_owner")
	if projectile.get("linear_velocity") is Vector2:
		projectile.set("linear_velocity", tangent.normalized() * 920.0 + _body_velocity(_player) * 0.25)

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

	_was_time_dilating = is_dilating

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
