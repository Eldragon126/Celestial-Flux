extends Node2D

# Celestial hazard/utility: a paired teleporter with polygon rings and particles.

@export var endpoint_radius := 82.0
@export var cooldown_seconds := 0.85

var _entry: Area2D
var _exit: Area2D
var _pending_entry_global := Vector2(-280.0, 0.0)
var _pending_exit_global := Vector2(280.0, 0.0)

func _ready() -> void:
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
	_pending_entry_global = entry_global
	_pending_exit_global = exit_global
	if is_inside_tree() and _entry != null and _exit != null:
		_position_endpoints_global()

func _position_endpoints_global() -> void:
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
	ring.color = ring_color
	ring.polygon = _circle_points(36, endpoint_radius)
	endpoint.add_child(ring)

	var core := Polygon2D.new()
	core.name = "WormholeCorePolygon"
	core.color = Color(ring_color.r, ring_color.g, ring_color.b, 0.26)
	core.polygon = _circle_points(24, endpoint_radius * 0.52)
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
	if destination == null or not (body is Node2D):
		return

	var now := Time.get_ticks_msec() / 1000.0
	var next_allowed := float(body.get_meta("wormhole_cooldown_until", 0.0))
	if now < next_allowed:
		return

	body.set_meta("wormhole_cooldown_until", now + cooldown_seconds)
	var offset = (body.global_position - global_position).normalized()
	if offset == Vector2.ZERO:
		offset = Vector2.RIGHT

	body.global_position = destination.global_position + offset * (endpoint_radius + 42.0)

	var velocity = body.get("velocity")
	if velocity is Vector2:
		body.set("velocity", velocity.rotated(PI * 0.12))

func _make_wormhole_material(ring_color: Color) -> ParticleProcessMaterial:
	var gradient := Gradient.new()
	gradient.set_color(0, ring_color)
	gradient.set_color(1, Color(ring_color.r, ring_color.g, ring_color.b, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = endpoint_radius
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

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
