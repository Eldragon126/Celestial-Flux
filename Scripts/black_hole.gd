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
@export var affected_groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"bosses", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]

var _spaghettified_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var affected := 0
	var seen := {}
	var horizon_squared := event_horizon_radius * event_horizon_radius

	for group_name in affected_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if affected >= max_targets_per_tick:
				return
			var body := node as Node2D
			if body == null or body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var id := body.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			var offset := global_position - body.global_position
			var distance_squared := offset.length_squared()
			if distance_squared <= 0.001 or distance_squared > horizon_squared:
				_restore_spaghettified_shape(body)
				continue

			var distance := sqrt(distance_squared)
			var radial := offset / distance
			var tangent := radial.orthogonal()
			var falloff := 1.0 - clampf(distance / event_horizon_radius, 0.0, 1.0)
			var pull := radial * pull_force * falloff
			var shear := tangent * tangent_shear_force * falloff * signf(sin(float(id) * 0.17 + Time.get_ticks_msec() / 420.0))
			CombatStatus.add_velocity(body, (pull + shear) * delta)

			if distance <= spaghettify_radius:
				_apply_spaghettification(body, radial, 1.0 - distance / spaghettify_radius, delta)
			else:
				_restore_spaghettified_shape(body)

			if distance <= consume_radius:
				_consume_body(body)
			affected += 1


func _on_detector_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
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
		body.call("take_damage", 10000000.0)
	elif body.has_method("take_damage"):
		body.call("take_damage", 10000000.0)
	elif body is RigidBody2D or body.is_in_group("Projectiles"):
		body.queue_free()
	horizon_body_consumed.emit(body)
