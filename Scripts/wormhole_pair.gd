extends Node2D

# Celestial hazard/utility: a paired teleporter with polygon rings and particles.

signal wormhole_teleport(position: Vector2, destination: Vector2, body: Node)

@export var endpoint_radius: float = 82.0
@export var cooldown_seconds: float = 0.85
@export var endpoint_planet_clearance_margin: float = 126.0
@export var endpoint_reposition_attempts: int = 10
@export_range(0.0, 0.42, 0.01) var ring_alpha_cap: float = 0.26

var _entry: Area2D = null
var _exit: Area2D = null
var _pending_entry_global: Vector2 = Vector2(-280.0, 0.0)
var _pending_exit_global: Vector2 = Vector2(280.0, 0.0)


func _ready() -> void:
	add_to_group("wormhole_pair")
	_entry = _build_endpoint("EntryWormhole", Color(0.0, 0.92, 1.0, 0.78))
	_exit = _build_endpoint("ExitWormhole", Color(1.0, 0.32, 0.92, 0.78))
	_entry.body_entered.connect(_on_entry_body_entered)
	_exit.body_entered.connect(_on_exit_body_entered)
	_position_endpoints_global()


func _process(delta: float) -> void:
	if _entry != null:
		_entry.rotation += delta * 1.4
	if _exit != null:
		_exit.rotation -= delta * 1.15


func set_endpoint_positions(entry_global: Vector2, exit_global: Vector2) -> void:
	_pending_entry_global = _safe_endpoint_position(entry_global, exit_global)
	_pending_exit_global = _safe_endpoint_position(exit_global, _pending_entry_global)
	if is_inside_tree() and _entry != null and _exit != null:
		_position_endpoints_global()


func _position_endpoints_global() -> void:
	if _entry == null or _exit == null:
		return
	_pending_entry_global = _safe_endpoint_position(_pending_entry_global, _pending_exit_global)
	_pending_exit_global = _safe_endpoint_position(_pending_exit_global, _pending_entry_global)
	global_position = (_pending_entry_global + _pending_exit_global) * 0.5
	_entry.position = _pending_entry_global - global_position
	_exit.position = _pending_exit_global - global_position


func _build_endpoint(endpoint_name: String, ring_color: Color) -> Area2D:
	var endpoint := Area2D.new()
	endpoint.name = endpoint_name
	endpoint.monitoring = true
	add_child(endpoint)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = endpoint_radius
	collision.shape = circle
	endpoint.add_child(collision)

	var ring := Polygon2D.new()
	ring.name = "WormholeRingPolygon"
	ring.color = _ring_color(ring_color)
	ring.polygon = _circle_points(36, _visual_radius(endpoint_radius))
	endpoint.add_child(ring)

	var core := Polygon2D.new()
	core.name = "WormholeCorePolygon"
	core.color = Color(ring_color.r, ring_color.g, ring_color.b, Settings.world_fill_alpha(0.26))
	core.polygon = _circle_points(24, _visual_radius(endpoint_radius * 0.52))
	endpoint.add_child(core)

	var particles := GPUParticles2D.new()
	particles.name = "WormholeParticles"
	particles.z_index = -1
	particles.amount = 130
	particles.lifetime = 1.4
	particles.randomness = 0.6
	particles.process_material = _make_wormhole_material(ring_color)
	endpoint.add_child(particles)
	return endpoint


func _on_entry_body_entered(body: Node) -> void:
	_teleport_body(body, _exit)


func _on_exit_body_entered(body: Node) -> void:
	_teleport_body(body, _entry)


func _teleport_body(body: Node, destination: Node2D) -> void:
	if destination == null or not is_instance_valid(destination):
		return
	if body == null or not is_instance_valid(body):
		return
	var body_2d := body as Node2D
	if body_2d == null:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var next_allowed := float(body_2d.get_meta("wormhole_cooldown_until", 0.0))
	if now < next_allowed:
		return

	body_2d.set_meta("wormhole_cooldown_until", now + cooldown_seconds)
	var offset := (body_2d.global_position - global_position).normalized()
	if offset == Vector2.ZERO:
		offset = Vector2.RIGHT

	var arrival_position := destination.global_position + offset * (endpoint_radius + 42.0)
	body_2d.global_position = arrival_position
	wormhole_teleport.emit(arrival_position, destination.global_position, body)

	var velocity_value: Variant = body_2d.get("velocity")
	if velocity_value is Vector2:
		var velocity: Vector2 = velocity_value
		body_2d.set("velocity", velocity.rotated(PI * 0.12))


func _make_wormhole_material(ring_color: Color) -> ParticleProcessMaterial:
	var gradient := Gradient.new()
	gradient.set_color(0, _ring_color(ring_color))
	gradient.set_color(1, Color(ring_color.r, ring_color.g, ring_color.b, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = _visual_radius(endpoint_radius)
	material.spread = 180.0
	material.initial_velocity_min = 38.0
	material.initial_velocity_max = 130.0
	material.radial_accel_min = -110.0
	material.radial_accel_max = -45.0
	material.orbit_velocity_min = 0.45
	material.orbit_velocity_max = 1.2
	material.gravity = Vector3.ZERO
	material.scale_min = 2.0
	material.scale_max = 6.0
	material.color_ramp = texture
	return material


func _ring_color(source_color: Color) -> Color:
	var color := source_color
	color.a = Settings.world_visual_alpha(color.a, ring_alpha_cap)
	return color


func _visual_radius(radius: float) -> float:
	return Settings.world_effect_radius(radius)


func _safe_endpoint_position(position: Vector2, partner_position: Vector2) -> Vector2:
	if not is_inside_tree():
		return position
	var adjusted := position
	for _attempt in range(maxi(endpoint_reposition_attempts, 1)):
		var blocker := _blocking_planet(adjusted)
		if blocker == null:
			return adjusted
		var offset := adjusted - blocker.global_position
		if offset.length_squared() <= 0.001:
			offset = adjusted - partner_position
		if offset.length_squared() <= 0.001:
			offset = Vector2.RIGHT
		var safe_radius := _node_radius(blocker) + endpoint_radius + endpoint_planet_clearance_margin
		adjusted = blocker.global_position + offset.normalized() * safe_radius
	return adjusted


func _blocking_planet(position: Vector2) -> Node2D:
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Node2D
		if planet == null or not is_instance_valid(planet) or planet.is_queued_for_deletion():
			continue
		var safe_radius := _node_radius(planet) + endpoint_radius + endpoint_planet_clearance_margin
		if position.distance_squared_to(planet.global_position) < safe_radius * safe_radius:
			return planet
	return null


func _node_radius(node: Node2D) -> float:
	var radius_value: Variant = node.get("radius")
	if radius_value is float or radius_value is int:
		return float(radius_value) * maxf(node.scale.x, node.scale.y)
	var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return (collision.shape as CircleShape2D).radius * maxf(node.scale.x, node.scale.y)
	return 96.0 * maxf(node.scale.x, node.scale.y)


func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
