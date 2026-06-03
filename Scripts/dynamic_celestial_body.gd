extends Area2D
class_name DynamicCelestialBody

signal celestial_body_destabilized(body: DynamicCelestialBody, data: Dictionary)
signal celestial_body_collected(body: DynamicCelestialBody, other: Node)

enum BodyKind { PLANET, MOON, SINGULARITY, ANOMALY, ORBITAL_STRUCTURE }

const KIND_NAMES := {
	BodyKind.PLANET: &"planet",
	BodyKind.MOON: &"moon",
	BodyKind.SINGULARITY: &"singularity",
	BodyKind.ANOMALY: &"anomaly",
	BodyKind.ORBITAL_STRUCTURE: &"orbital_structure",
}

@export var kind: int = BodyKind.PLANET
@export var mass: float = 150000.0
@export var body_radius: float = 84.0
@export var lifetime: float = 32.0
@export var angular_velocity: float = 0.0
@export var orbit_radius: float = 0.0
@export var orbit_angle: float = 0.0
@export var destabilize_at_life_ratio: float = 0.82
@export var gravity_color_alpha_cap: float = 0.38

var orbit_anchor: Node2D = null
var drift_velocity: Vector2 = Vector2.ZERO

var _age: float = 0.0
var _destabilized: bool = false
var _core: Polygon2D = null
var _ring: Line2D = null
var _orbit_trace: Line2D = null


func _ready() -> void:
	add_to_group("dynamic_celestial_body")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	_build_collision()
	_build_visuals()


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")


func _process(delta: float) -> void:
	_age += delta
	_update_motion(delta)
	_update_visuals(delta)
	if not _destabilized and _age >= lifetime * destabilize_at_life_ratio:
		_destabilize()
	if _age >= lifetime:
		queue_free()


func configure(
	new_kind: int,
	new_mass: float,
	new_radius: float,
	new_lifetime: float,
	new_drift_velocity: Vector2,
	new_orbit_anchor: Node2D = null,
	new_orbit_radius: float = 0.0,
	new_orbit_angle: float = 0.0,
	new_angular_velocity: float = 0.0
) -> void:
	kind = clampi(new_kind, BodyKind.PLANET, BodyKind.ORBITAL_STRUCTURE)
	mass = new_mass
	body_radius = maxf(new_radius, 16.0)
	lifetime = maxf(new_lifetime, 4.0)
	drift_velocity = new_drift_velocity
	orbit_anchor = new_orbit_anchor
	orbit_radius = maxf(new_orbit_radius, 0.0)
	orbit_angle = new_orbit_angle
	angular_velocity = new_angular_velocity
	_apply_kind_defaults()


func absorb_body(other: DynamicCelestialBody) -> void:
	if other == null or other == self or not is_instance_valid(other):
		return
	var combined_mass := mass + other.mass
	var blend := clampf(other.mass / maxf(combined_mass, 1.0), 0.0, 1.0)
	global_position = global_position.lerp(other.global_position, blend)
	mass = combined_mass
	body_radius = sqrt(body_radius * body_radius + other.body_radius * other.body_radius) * 0.88
	lifetime = maxf(lifetime, other.lifetime * 0.72)
	other.queue_free()
	_destabilize()


func get_celestial_state() -> Dictionary:
	return {
		"kind": KIND_NAMES.get(kind, &"planet"),
		"mass": mass,
		"radius": body_radius,
		"age": _age,
		"lifetime": lifetime,
		"position": global_position,
		"destabilized": _destabilized,
	}


func _apply_kind_defaults() -> void:
	match kind:
		BodyKind.MOON:
			mass = absf(mass) * 0.58
		BodyKind.SINGULARITY:
			mass = absf(mass) * 1.65
			body_radius *= 0.72
		BodyKind.ANOMALY:
			mass = -absf(mass) * 0.72
		BodyKind.ORBITAL_STRUCTURE:
			mass = absf(mass) * 0.34


func _update_motion(delta: float) -> void:
	if orbit_anchor != null and is_instance_valid(orbit_anchor):
		orbit_angle += angular_velocity * delta
		global_position = orbit_anchor.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
	else:
		global_position += drift_velocity * delta
		drift_velocity = drift_velocity.move_toward(Vector2.ZERO, 6.0 * delta)


func _destabilize() -> void:
	_destabilized = true
	celestial_body_destabilized.emit(self, get_celestial_state())


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return
	celestial_body_collected.emit(self, area)


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CelestialBodyCollision"
	var shape := CircleShape2D.new()
	shape.radius = body_radius
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	_core = Polygon2D.new()
	_core.name = "CelestialCore"
	_core.color = _body_color(0.72)
	_core.polygon = _soft_circle_points(18, body_radius)
	add_child(_core)

	_ring = Line2D.new()
	_ring.name = "CelestialRuleRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.0
	_ring.default_color = _body_color(0.48)
	_ring.points = _circle_points(44, body_radius * 1.24)
	add_child(_ring)

	_orbit_trace = Line2D.new()
	_orbit_trace.name = "CelestialOrbitTrace"
	_orbit_trace.closed = true
	_orbit_trace.antialiased = true
	_orbit_trace.width = 1.2
	_orbit_trace.default_color = _body_color(0.18)
	_orbit_trace.points = _circle_points(60, maxf(orbit_radius, body_radius * 1.8))
	_orbit_trace.visible = orbit_radius > body_radius * 2.0
	add_child(_orbit_trace)


func _update_visuals(delta: float) -> void:
	var life := clampf(1.0 - _age / maxf(lifetime, 0.001), 0.0, 1.0)
	var pulse := 1.0 + sin(_age * 3.2) * (0.04 + (0.04 if _destabilized else 0.0))
	if _core != null:
		_core.scale = Vector2.ONE * pulse
		_core.color = _body_color(lerpf(0.26, 0.76, life))
	if _ring != null:
		_ring.rotation += delta * (0.35 + absf(angular_velocity))
		_ring.default_color = _body_color(0.26 + (0.2 if _destabilized else 0.0))
	if _orbit_trace != null:
		_orbit_trace.visible = orbit_radius > body_radius * 2.0
		if orbit_anchor != null and is_instance_valid(orbit_anchor):
			_orbit_trace.global_position = orbit_anchor.global_position - global_position


func _body_color(alpha: float) -> Color:
	var color := Color(0.3, 0.72, 1.0, minf(alpha, gravity_color_alpha_cap))
	match kind:
		BodyKind.MOON:
			color = Color(0.62, 0.82, 1.0, minf(alpha, gravity_color_alpha_cap))
		BodyKind.SINGULARITY:
			color = Color(0.86, 0.38, 1.0, minf(alpha, gravity_color_alpha_cap))
		BodyKind.ANOMALY:
			color = Color(1.0, 0.34, 0.18, minf(alpha, gravity_color_alpha_cap))
		BodyKind.ORBITAL_STRUCTURE:
			color = Color(1.0, 0.82, 0.24, minf(alpha, gravity_color_alpha_cap))
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _circle_points(count: int, radius_value: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius_value)
	return points


func _soft_circle_points(count: int, radius_value: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		var wobble := 1.0 + sin(angle * 3.0) * 0.055 + cos(angle * 7.0) * 0.028
		points.append(Vector2(cos(angle), sin(angle)) * radius_value * wobble)
	return points
