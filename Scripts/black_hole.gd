extends StaticBody2D

signal spaghettification_started(body: Node, intensity: float)
signal horizon_body_consumed(body: Node)

@export var mass: float = 1000000.0
@export var event_horizon_radius: float = 620.0
@export var spaghettify_radius: float = 260.0
@export var consume_radius: float = 58.0
@export var pull_force: float = 1250.0
@export var tangent_shear_force: float = 240.0
@export var spaghettify_damage_per_second: float = 36.0
@export var max_targets_per_tick: int = 48
@export var field_tick_interval: float = 0.045
@export var particle_focus_radius: float = 1900.0
@export var max_particle_amount: int = 180
@export var affected_groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]

var _spaghettified_ids: Dictionary = {}
var _target_buffer: Array[Node2D] = []
var _field_elapsed: float = 999.0
var _player: Node2D = null
var _particles: GPUParticles2D = null


func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"planets")
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_particles = get_node_or_null("GPUParticles2D") as GPUParticles2D
	if _particles != null:
		_particles.amount = mini(_particles.amount, max_particle_amount)
	_update_particle_focus()
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"planets")
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")


func _physics_process(delta: float) -> void:
	_field_elapsed += delta
	if _field_elapsed < maxf(field_tick_interval, 0.02):
		_update_particle_focus()
		return
	var field_delta := _field_elapsed
	_field_elapsed = 0.0
	var affected := 0
	_refresh_targets()

	for body in _target_buffer:
		if affected >= max_targets_per_tick:
			break
		if body == null or body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var offset := global_position - body.global_position
		var distance_squared := offset.length_squared()
		if distance_squared <= 0.001:
			continue

		var distance := sqrt(distance_squared)
		var radial := offset / distance
		var tangent := radial.orthogonal()
		var falloff := 1.0 - clampf(distance / event_horizon_radius, 0.0, 1.0)
		var pull := radial * pull_force * falloff
		var shear := tangent * tangent_shear_force * falloff * signf(sin(float(body.get_instance_id()) * 0.17 + Time.get_ticks_msec() / 420.0))
		CombatStatus.add_velocity(body, (pull + shear) * field_delta)

		if distance <= spaghettify_radius:
			_apply_spaghettification(body, radial, 1.0 - distance / spaghettify_radius, field_delta)
		else:
			_restore_spaghettified_shape(body)

		if distance <= consume_radius:
			_consume_body(body)
		affected += 1
	_update_particle_focus()


func _on_detector_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var offset := global_position - body.global_position
	if offset.length() <= consume_radius:
		_consume_body(body)


func _apply_spaghettification(body: Node2D, radial: Vector2, intensity: float, delta: float) -> void:
	var clamped := clampf(intensity, 0.0, 1.0)
	if not _spaghettified_ids.has(body.get_instance_id()):
		_spaghettified_ids[body.get_instance_id()] = body.scale
		spaghettification_started.emit(body, clamped)
	body.rotation = lerp_angle(body.rotation, radial.angle(), clampf(delta * 5.0, 0.0, 1.0))
	var stretch := 1.0 + clamped * 1.45
	var pinch := maxf(1.0 - clamped * 0.42, 0.34)
	body.scale = Vector2(stretch, pinch)
	if body.has_method("take_damage"):
		body.call("take_damage", spaghettify_damage_per_second * clamped * delta)
	body.set_meta(&"spaghettification_intensity", clamped)


func _restore_spaghettified_shape(body: Node2D) -> void:
	var id := body.get_instance_id()
	if not _spaghettified_ids.has(id):
		return
	var original_scale: Vector2 = _spaghettified_ids[id]
	body.scale = body.scale.lerp(original_scale, 0.12)
	if body.scale.distance_to(original_scale) < 0.02:
		body.scale = original_scale
		_spaghettified_ids.erase(id)
	if body.has_meta(&"spaghettification_intensity"):
		body.remove_meta(&"spaghettification_intensity")


func _consume_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body == self:
		return
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.set_meta(&"last_death_context", &"black_hole")
		body.call("take_damage", 10000000.0)
	elif body.has_method("take_damage"):
		body.call("take_damage", 10000000.0)
	elif body is RigidBody2D or body.is_in_group("Projectiles"):
		body.queue_free()
	horizon_body_consumed.emit(body)


func _refresh_targets() -> void:
	_target_buffer.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(
			affected_groups,
			global_position,
			event_horizon_radius,
			max_targets_per_tick,
			true,
			_target_buffer
		)
		return
	var seen: Dictionary = {}
	var horizon_squared := event_horizon_radius * event_horizon_radius
	for group_name in affected_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if _target_buffer.size() >= max_targets_per_tick:
				return
			var body := node as Node2D
			if body == null or body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var id := body.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if body.global_position.distance_squared_to(global_position) > horizon_squared:
				continue
			_target_buffer.append(body)


func _update_particle_focus() -> void:
	if _particles == null or not is_instance_valid(_particles):
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	var in_focus := true
	if _player != null and is_instance_valid(_player):
		in_focus = global_position.distance_squared_to(_player.global_position) <= particle_focus_radius * particle_focus_radius
	_particles.visible = in_focus
	_particles.emitting = in_focus
