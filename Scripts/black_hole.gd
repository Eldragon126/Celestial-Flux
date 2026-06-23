extends StaticBody2D

signal spaghettification_started(body: Node, intensity: float)
signal horizon_body_consumed(body: Node)

@export var mass: float = 3200.0
@export var event_horizon_radius: float = 620.0
@export var spaghettify_radius: float = 260.0
@export var consume_radius: float = 58.0
@export var pull_force: float = 1250.0
@export var tangent_shear_force: float = 240.0
@export var spaghettify_damage_per_second: float = 36.0
@export var consume_damage: float = 10000000.0
@export var disable_consumed_collision: bool = true
@export var consumption_safe_delay_frames: int = 1
@export var max_targets_per_tick: int = 48
@export var field_tick_interval: float = 0.045
@export var particle_focus_radius: float = 1900.0
@export var max_particle_amount: int = 180
@export var max_field_impulse_per_tick: float = 145.0
@export var max_body_speed_after_pull: float = 2600.0
@export var tracking_prune_interval: float = 1.2
@export var invalid_body_quarantine_distance: float = 840.0
@export var max_collision_disable_depth: int = 4
@export var affected_groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]
@export_group("Readability Visuals")
@export var enable_horizon_rings: bool = true
@export var horizon_ring_segments: int = 48
@export var horizon_ring_width: float = 3.2
@export_range(0.0, 1.0, 0.01) var horizon_ring_alpha: float = 0.32
@export_range(0.0, 1.0, 0.01) var shear_ring_alpha: float = 0.18

var _spaghettified_ids: Dictionary = {}
var _target_buffer: Array[Node2D] = []
var _consumed_ids: Dictionary = {}
var _pending_consumption_ids: Dictionary = {}
var _pending_damage_ids: Dictionary = {}
var _pending_free_ids: Dictionary = {}
var _field_elapsed: float = 999.0
var _tracking_prune_elapsed: float = 0.0
var _player: Node2D = null
var _particles: GPUParticles2D = null
var _horizon_ring: Line2D = null
var _shear_ring: Line2D = null
var _visual_time: float = 0.0


func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"planets")
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_particles = get_node_or_null("GPUParticles2D") as GPUParticles2D
	_ensure_horizon_visuals()
	if _particles != null:
		_particles.amount = mini(_particles.amount, max_particle_amount)
	_update_particle_focus()
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"planets")
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")


func _process(delta: float) -> void:
	_update_horizon_visuals(delta)


func _physics_process(delta: float) -> void:
	_field_elapsed += delta
	if _field_elapsed < maxf(field_tick_interval, 0.02):
		_update_particle_focus()
		return
	var field_delta := _field_elapsed
	_field_elapsed = 0.0
	_tracking_prune_elapsed += field_delta
	var affected := 0
	_refresh_targets()

	for body in _target_buffer:
		if affected >= max_targets_per_tick:
			break
		if not _body_can_receive_field(body):
			continue
		if not _finite_vector(body.global_position):
			_stabilize_invalid_body(body)
			continue
		var offset := global_position - body.global_position
		if not _finite_vector(offset):
			_stabilize_invalid_body(body)
			continue
		var distance_squared := offset.length_squared()
		if not _finite_float(distance_squared):
			_stabilize_invalid_body(body)
			continue
		if distance_squared <= 0.001:
			_consume_body(body)
			continue

		var distance := sqrt(distance_squared)
		if not _finite_float(distance):
			_stabilize_invalid_body(body)
			continue
		if distance <= consume_radius:
			_consume_body(body)
			continue

		var radial := offset / distance
		var tangent := radial.orthogonal()
		var falloff := 1.0 - clampf(distance / event_horizon_radius, 0.0, 1.0)
		var pull := radial * pull_force * falloff
		var shear := tangent * tangent_shear_force * falloff * signf(sin(float(body.get_instance_id()) * 0.17 + Time.get_ticks_msec() / 420.0))
		_apply_safe_field_velocity(body, (pull + shear) * field_delta)
		if not _body_can_receive_field(body):
			continue

		if distance <= spaghettify_radius:
			_apply_spaghettification(body, radial, 1.0 - distance / spaghettify_radius, field_delta)
		else:
			_restore_spaghettified_shape(body)
		if not _body_can_receive_field(body):
			continue

		if distance <= consume_radius:
			_consume_body(body)
			continue
		affected += 1
	if _tracking_prune_elapsed >= maxf(tracking_prune_interval, 0.2):
		_tracking_prune_elapsed = 0.0
		_prune_tracking_ids()
	_update_particle_focus()


func _on_detector_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if bool(body.get_meta(&"black_hole_consumed", false)):
		return
	if not _finite_vector(body.global_position):
		_stabilize_invalid_body(body)
		return
	var offset := global_position - body.global_position
	if not _finite_vector(offset):
		_stabilize_invalid_body(body)
		return
	var distance := offset.length()
	if _finite_float(distance) and distance <= consume_radius:
		_consume_body(body)


func _apply_spaghettification(body: Node2D, radial: Vector2, intensity: float, delta: float) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if bool(body.get_meta(&"black_hole_consumed", false)):
		return
	if _body_death_in_progress(body):
		return
	if not _finite_vector(radial):
		return
	var clamped := clampf(intensity, 0.0, 1.0)
	if not _spaghettified_ids.has(body.get_instance_id()):
		var visual := _spaghettification_visual(body)
		_spaghettified_ids[body.get_instance_id()] = {
			"visual_id": visual.get_instance_id() if visual != null else 0,
			"scale": visual.scale if visual != null else Vector2.ONE,
			"rotation": visual.rotation if visual != null else 0.0,
		}
		spaghettification_started.emit(body, clamped)
	# Never non-uniformly scale or rotate a live CollisionObject2D here. That
	# rebuilds physics shapes while the object is already overlapping the core
	# and can terminate the physics backend without a GDScript error. Consumers
	# render the distortion from metadata instead.
	body.set_meta(&"spaghettification_axis", radial)
	var visual_entry_value: Variant = _spaghettified_ids.get(body.get_instance_id(), {})
	var visual_entry: Dictionary = visual_entry_value if visual_entry_value is Dictionary else {}
	var visual_id := int(visual_entry.get("visual_id", 0))
	if visual_id > 0 and is_instance_id_valid(visual_id):
		var visual_value := instance_from_id(visual_id)
		var visual_node := visual_value as Node2D
		if visual_node != null and is_instance_valid(visual_node):
			var stretch := 1.0 + clamped * 1.45
			var pinch := maxf(1.0 - clamped * 0.42, 0.34)
			var original_scale: Vector2 = visual_entry.get("scale", Vector2.ONE)
			visual_node.scale = original_scale * Vector2(stretch, pinch)
			visual_node.rotation = lerp_angle(float(visual_entry.get("rotation", 0.0)), radial.angle(), clampf(clamped * 0.72, 0.0, 0.72))
	if body.has_method("take_damage"):
		_queue_damage(body, minf(spaghettify_damage_per_second * clamped * delta, spaghettify_damage_per_second * 0.18))
	body.set_meta(&"spaghettification_intensity", clamped)


func _restore_spaghettified_shape(body: Node2D) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	var id := body.get_instance_id()
	if not _spaghettified_ids.has(id):
		return
	var visual_entry_value: Variant = _spaghettified_ids.get(id, {})
	var visual_entry: Dictionary = visual_entry_value if visual_entry_value is Dictionary else {}
	var visual_id := int(visual_entry.get("visual_id", 0))
	if visual_id > 0 and is_instance_id_valid(visual_id):
		var visual_value := instance_from_id(visual_id)
		var visual_node := visual_value as Node2D
		if visual_node != null and is_instance_valid(visual_node):
			visual_node.scale = visual_entry.get("scale", Vector2.ONE)
			visual_node.rotation = float(visual_entry.get("rotation", 0.0))
	_spaghettified_ids.erase(id)
	if body.has_meta(&"spaghettification_intensity"):
		body.remove_meta(&"spaghettification_intensity")
	if body.has_meta(&"spaghettification_axis"):
		body.remove_meta(&"spaghettification_axis")


func _spaghettification_visual(body: Node) -> Node2D:
	if body == null or not is_instance_valid(body):
		return null
	var direct := body.get_node_or_null("Polygon2D") as Node2D
	if direct != null:
		return direct
	var polygons := body.find_children("*", "Polygon2D", true, false)
	if polygons.is_empty():
		return null
	return polygons[0] as Node2D


func _consume_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body == self:
		return
	if body.is_queued_for_deletion() or _body_death_in_progress(body):
		return
	var id := body.get_instance_id()
	if _consumed_ids.has(id):
		return
	_consumed_ids[id] = true
	_pending_consumption_ids[id] = true
	body.set_meta(&"black_hole_consumed", true)
	# The player owns its death transition. Mutating its collision tree from a
	# black-hole physics callback used to race move_and_slide and scene teardown.
	if not body.is_in_group("Player"):
		_make_body_safe_for_consumption(body)
	horizon_body_consumed.emit(body)
	call_deferred("_finish_consumption", id)


func _finish_consumption(instance_id: int) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for _frame in range(maxi(consumption_safe_delay_frames, 0)):
		await tree.process_frame
		if not is_inside_tree():
			return
	_pending_consumption_ids.erase(instance_id)
	if not is_instance_id_valid(instance_id):
		return
	var value := instance_from_id(instance_id)
	if value == null or not is_instance_valid(value):
		return
	var body := value as Node
	if body == null or body.is_queued_for_deletion():
		return
	if _body_death_in_progress(body):
		return
	if body.has_method("consume_by_black_hole"):
		body.call("consume_by_black_hole")
		return
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.set_meta(&"last_death_context", &"black_hole")
		body.call("take_damage", consume_damage)
		return
	elif body.has_method("take_damage"):
		body.set_meta(&"last_death_context", &"black_hole")
		body.call("take_damage", consume_damage)
	elif body is RigidBody2D or body is Area2D or body is CollisionObject2D or body.is_in_group("Projectiles"):
		_queue_free_body(body)


func _make_body_safe_for_consumption(body: Node) -> void:
	if body == null or not is_instance_valid(body) or not disable_consumed_collision:
		return
	if body is CollisionObject2D:
		var collision_body := body as CollisionObject2D
		collision_body.set_deferred("collision_layer", 0)
		collision_body.set_deferred("collision_mask", 0)
	if body is Area2D:
		var area := body as Area2D
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	if body is RigidBody2D:
		var rigid := body as RigidBody2D
		rigid.set_deferred("linear_velocity", Vector2.ZERO)
		rigid.set_deferred("angular_velocity", 0.0)
		rigid.set_deferred("freeze", true)
	elif body is CharacterBody2D:
		var character := body as CharacterBody2D
		character.set_deferred("velocity", Vector2.ZERO)
	_disable_collision_children(body, 0)


func _disable_collision_children(body: Node, depth: int) -> void:
	if body == null or not is_instance_valid(body) or depth > max_collision_disable_depth:
		return
	for child in body.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		_disable_collision_children(child, depth + 1)


func _queue_free_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	var id := body.get_instance_id()
	if _pending_free_ids.has(id):
		return
	_pending_free_ids[id] = true
	body.call_deferred("queue_free")


func _queue_damage(body: Node, amount: float) -> void:
	if body == null or amount <= 0.0 or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if _body_death_in_progress(body):
		return
	var id := body.get_instance_id()
	if _pending_damage_ids.has(id):
		_pending_damage_ids[id] = float(_pending_damage_ids[id]) + amount
		return
	_pending_damage_ids[id] = amount
	call_deferred("_deal_queued_damage", id)


func _body_can_receive_field(body: Node) -> bool:
	if body == null or body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	if bool(body.get_meta(&"black_hole_consumed", false)):
		return false
	if _body_death_in_progress(body):
		return false
	return body is Node2D


func _apply_safe_field_velocity(body: Node, impulse: Vector2) -> void:
	if not _body_can_receive_field(body) or not _finite_vector(impulse):
		return
	var safe_impulse := impulse.limit_length(maxf(max_field_impulse_per_tick, 1.0))
	if body is RigidBody2D:
		var rigid_body := body as RigidBody2D
		if rigid_body.freeze:
			return
		rigid_body.apply_central_impulse(safe_impulse * maxf(rigid_body.mass, 0.01))
		var next_linear := rigid_body.linear_velocity
		if _finite_vector(next_linear) and next_linear.length() > max_body_speed_after_pull:
			rigid_body.linear_velocity = next_linear.limit_length(maxf(max_body_speed_after_pull, 1.0))
		return
	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		var next_velocity: Vector2 = velocity
		if not _finite_vector(next_velocity):
			next_velocity = Vector2.ZERO
		body.set("velocity", (next_velocity + safe_impulse).limit_length(maxf(max_body_speed_after_pull, 1.0)))
		return
	var linear_velocity: Variant = body.get("linear_velocity")
	if linear_velocity is Vector2:
		var next_linear_velocity: Vector2 = linear_velocity
		if not _finite_vector(next_linear_velocity):
			next_linear_velocity = Vector2.ZERO
		body.set("linear_velocity", (next_linear_velocity + safe_impulse).limit_length(maxf(max_body_speed_after_pull, 1.0)))


func _stabilize_invalid_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if body.is_in_group("Player"):
		_consume_body(body)
		return
	_make_body_safe_for_consumption(body)
	if body is Node2D:
		var body_2d := body as Node2D
		if _finite_vector(global_position):
			body_2d.set_deferred(
				"global_position",
				global_position + Vector2.RIGHT.rotated(float(body.get_instance_id()) * 0.37) * invalid_body_quarantine_distance
			)
	_queue_free_body(body)


func _body_death_in_progress(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return true
	if body.has_method("is_death_in_progress") and bool(body.call("is_death_in_progress")):
		return true
	return bool(body.get_meta(&"death_in_progress", false))


func _finite_vector(value: Vector2) -> bool:
	return _finite_float(value.x) and _finite_float(value.y)


func _finite_float(value: float) -> bool:
	return value == value and absf(value) < INF


func _prune_tracking_ids() -> void:
	_prune_instance_dictionary(_spaghettified_ids)
	_prune_instance_dictionary(_consumed_ids)
	_prune_instance_dictionary(_pending_consumption_ids)
	_prune_instance_dictionary(_pending_damage_ids)
	_prune_instance_dictionary(_pending_free_ids)


func _prune_instance_dictionary(dictionary: Dictionary) -> void:
	for key in dictionary.keys():
		if not is_instance_id_valid(int(key)):
			dictionary.erase(key)


func _deal_queued_damage(instance_id: int) -> void:
	if not _pending_damage_ids.has(instance_id):
		return
	var amount := float(_pending_damage_ids.get(instance_id, 0.0))
	_pending_damage_ids.erase(instance_id)
	if amount <= 0.0 or not is_instance_id_valid(instance_id):
		return
	var value := instance_from_id(instance_id)
	if value == null or not is_instance_valid(value):
		return
	var body := value as Node
	if body == null or body.is_queued_for_deletion() or not body.has_method("take_damage"):
		return
	if body.has_method("is_death_in_progress") and bool(body.call("is_death_in_progress")):
		return
	if bool(body.get_meta(&"black_hole_consumed", false)):
		return
	body.call("take_damage", amount)


func _deal_consumption_damage(instance_id: int) -> void:
	if not is_instance_id_valid(instance_id):
		return
	var value := instance_from_id(instance_id)
	if value == null or not is_instance_valid(value):
		return
	var body := value as Node
	if body == null or body.is_queued_for_deletion():
		return
	if body.has_method("is_death_in_progress") and bool(body.call("is_death_in_progress")):
		return
	if body.has_method("consume_by_black_hole"):
		body.call_deferred("consume_by_black_hole")
		return
	if not body.has_method("take_damage"):
		_queue_free_body(body)
		return
	body.set_meta(&"last_death_context", &"black_hole")
	body.call("take_damage", consume_damage)


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
			if bool(body.get_meta(&"black_hole_consumed", false)):
				continue
			if _body_death_in_progress(body):
				continue
			if not _finite_vector(body.global_position):
				_stabilize_invalid_body(body)
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


func _ensure_horizon_visuals() -> void:
	if not enable_horizon_rings:
		return
	if _horizon_ring == null:
		_horizon_ring = Line2D.new()
		_horizon_ring.name = "EventHorizonReadabilityRing"
		_horizon_ring.closed = true
		_horizon_ring.antialiased = true
		_horizon_ring.width = horizon_ring_width
		_horizon_ring.z_index = 3
		add_child(_horizon_ring)
	if _shear_ring == null:
		_shear_ring = Line2D.new()
		_shear_ring.name = "SpaghettifyShearRing"
		_shear_ring.closed = true
		_shear_ring.antialiased = true
		_shear_ring.width = maxf(1.0, horizon_ring_width * 0.54)
		_shear_ring.z_index = 2
		add_child(_shear_ring)


func _update_horizon_visuals(delta: float) -> void:
	if not enable_horizon_rings:
		_set_horizon_rings_visible(false)
		return
	_ensure_horizon_visuals()
	if _horizon_ring == null or _shear_ring == null:
		return
	_visual_time += delta
	var in_focus := true
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _player != null and is_instance_valid(_player):
		in_focus = global_position.distance_squared_to(_player.global_position) <= particle_focus_radius * particle_focus_radius
	_set_horizon_rings_visible(in_focus)
	if not in_focus:
		return

	var pulse := 0.5 + 0.5 * sin(_visual_time * 2.4)
	var horizon_radius := _world_effect_radius(event_horizon_radius, 420.0)
	var shear_radius := _world_effect_radius(spaghettify_radius, 320.0)
	_horizon_ring.points = _ring_points(horizon_radius, horizon_ring_segments, 0.018 + pulse * 0.012)
	_horizon_ring.width = horizon_ring_width * lerpf(0.82, 1.22, pulse)
	_horizon_ring.default_color = Color(1.0, 0.2, 0.08, _world_visual_alpha(horizon_ring_alpha * lerpf(0.72, 1.0, pulse), horizon_ring_alpha))
	_horizon_ring.rotation += delta * 0.16

	_shear_ring.points = _ring_points(shear_radius, maxi(20, int(horizon_ring_segments / 2)), 0.04)
	_shear_ring.width = maxf(1.0, horizon_ring_width * lerpf(0.38, 0.72, pulse))
	_shear_ring.default_color = Color(0.72, 0.42, 1.0, _world_visual_alpha(shear_ring_alpha, shear_ring_alpha))
	_shear_ring.rotation -= delta * 0.34


func _set_horizon_rings_visible(visible: bool) -> void:
	if _horizon_ring != null:
		_horizon_ring.visible = visible
	if _shear_ring != null:
		_shear_ring.visible = visible


func _ring_points(radius: float, count: int, wobble: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 8)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		var radius_offset := 1.0 + sin(angle * 5.0 + _visual_time * 3.0) * wobble
		points.append(Vector2(cos(angle), sin(angle)) * radius * radius_offset)
	return points


func _world_visual_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)


func _world_effect_radius(value: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(value, hard_cap)
	return clampf(value, 0.0, maxf(hard_cap, 1.0))
