extends Area2D
class_name GravityTidePocket

# Temporary arena hazard used by ArenaDestabilizationManager.
# A pocket is a readable local rule mutation: compression pulls inward,
# slipstream accelerates tangential movement, and inversion pushes outward.
# The node is self-contained, lifetime-limited, and exposes all major tuning
# values so chaos can be scaled without rewriting gameplay systems.

signal pocket_activated(mode: int, position: Vector2)
signal pocket_expired(mode: int, position: Vector2)
signal body_affected(body: Node, impulse: Vector2, mode: int)
signal temporal_pocket_entered(body: Node, multiplier: float, duration: float)

enum TideMode { COMPRESSION, SLIPSTREAM, INVERSION, TEMPORAL }

const MODE_DISPLAY_NAMES = {
	TideMode.COMPRESSION: "Compression",
	TideMode.SLIPSTREAM: "Slipstream",
	TideMode.INVERSION: "Inversion",
	TideMode.TEMPORAL: "Temporal",
}

const MODE_RULE_NAMES = {
	TideMode.COMPRESSION: "PULL",
	TideMode.SLIPSTREAM: "FLOW",
	TideMode.INVERSION: "PUSH",
	TideMode.TEMPORAL: "SLOW",
}

@export_enum("Compression", "Slipstream", "Inversion", "Temporal") var mode: int = TideMode.COMPRESSION
@export var radius: float = 320.0
@export var lifetime: float = 9.0
@export var telegraph_time: float = 1.0
@export var mass: float = 210000.0
@export var field_acceleration: float = 760.0
@export var slipstream_acceleration: float = 430.0
@export var max_body_impulse_per_second: float = 720.0
@export var player_escape_floor_speed: float = 260.0
@export var player_trap_escape_boost: float = 520.0
@export var player_trap_escape_radius_ratio: float = 0.28
@export var player_escape_requires_thrust: bool = true
@export var enable_escape_buildup: bool = true
@export var escape_buildup_seconds: float = 0.85
@export var enemy_escape_floor_speed: float = 180.0
@export var enemy_trap_escape_boost: float = 360.0
@export var affects_player: bool = true
@export var affects_enemies: bool = true
@export var affects_projectiles: bool = true
@export var particle_cap: int = 150
@export var enable_particles: bool = true
@export var debug_visual_enabled: bool = true
@export var visual_radius_cap: float = 420.0
@export_range(0.0, 1.0, 0.01) var visual_fill_alpha_cap: float = 0.11
@export_range(0.0, 1.0, 0.01) var visual_ring_alpha_cap: float = 0.5
@export_range(0.0, 1.0, 0.01) var visual_glyph_alpha_cap: float = 0.44
@export_group("Temporal")
@export var temporal_slow_multiplier: float = 0.48
@export var temporal_slow_duration: float = 0.35
@export var temporal_player_tangent_boost: float = 120.0

var _active := false
var _age := 0.0
var _tracked_bodies: Dictionary = {}
var _escape_buildup: Dictionary = {}
var _ring: Polygon2D = null
var _core: Polygon2D = null
var _label: Label = null
var _glyphs: Array[Line2D] = []
var _particles: GPUParticles2D = null
var _collision: CollisionShape2D = null
var _time_dilation_manager: Node = null

func _ready() -> void:
	add_to_group("arena_hazard")
	add_to_group("arena_destabilization_hazard")
	add_to_group("gravity_tide_pocket")
	_apply_mode_gravity_groups()

	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_collision()
	_build_visuals()

	if telegraph_time <= 0.0:
		_activate()
	else:
		get_tree().create_timer(telegraph_time).timeout.connect(_activate)

func _process(delta: float) -> void:
	_age += delta
	_update_visuals(delta)

	if _age >= telegraph_time + lifetime:
		_expire()
		return

	if not _active:
		return

	_apply_field(delta)

func configure(new_mode: int, new_radius: float, new_lifetime: float, new_strength: float) -> void:
	mode = clampi(new_mode, TideMode.COMPRESSION, TideMode.TEMPORAL)
	radius = maxf(new_radius, 40.0)
	lifetime = maxf(new_lifetime, 0.5)
	field_acceleration = maxf(new_strength, 0.0)
	slipstream_acceleration = maxf(new_strength * 0.62, 0.0)
	mass = maxf(new_strength * 280.0, 1000.0)
	_apply_mode_gravity_groups()

	if _collision != null:
		var circle := _collision.shape as CircleShape2D
		if circle != null:
			circle.radius = radius

func _apply_mode_gravity_groups() -> void:
	if mode == TideMode.COMPRESSION or mode == TideMode.INVERSION:
		add_to_group("Objects_With_Gravity")
		add_to_group("planets")
		if RuntimeRegistry != null:
			RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
			RuntimeRegistry.register_node(self, &"planets")
		mass = absf(mass) * (-1.0 if mode == TideMode.INVERSION else 1.0)
	else:
		remove_from_group("Objects_With_Gravity")
		remove_from_group("planets")
		if RuntimeRegistry != null:
			RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
			RuntimeRegistry.unregister_node(self, &"planets")
		mass = 0.0


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")

func _activate() -> void:
	if _active:
		return

	_active = true
	for body in get_overlapping_bodies():
		_on_body_entered(body)
	pocket_activated.emit(int(mode), global_position)

func _expire() -> void:
	pocket_expired.emit(int(mode), global_position)
	queue_free()

func _build_collision() -> void:
	_collision = CollisionShape2D.new()
	_collision.name = "GravityTideCollision"
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape
	add_child(_collision)

func _build_visuals() -> void:
	var visual_radius: float = _visual_radius()
	if debug_visual_enabled:
		_ring = Polygon2D.new()
		_ring.name = "TidePocketRing"
		_ring.z_index = -2
		_ring.polygon = _ring_points(54, visual_radius * 0.92, visual_radius)
		_ring.color = _capped_mode_color(0.16, visual_ring_alpha_cap)
		add_child(_ring)

		_core = Polygon2D.new()
		_core.name = "TidePocketCore"
		_core.z_index = -3
		_core.polygon = _soft_circle_points(40, visual_radius * 0.48)
		_core.color = _capped_mode_color(0.04, visual_fill_alpha_cap)
		add_child(_core)

		for i in range(10):
			var glyph := Line2D.new()
			glyph.name = "TideRuleGlyph%d" % i
			glyph.antialiased = true
			glyph.width = 2.0
			glyph.z_index = -1
			add_child(glyph)
			_glyphs.append(glyph)

		_label = Label.new()
		_label.name = "TideRuleLabel"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.z_index = 0
		_label.add_theme_font_size_override("font_size", 12)
		_label.add_theme_color_override("font_color", Color.WHITE)
		add_child(_label)

	if enable_particles:
		_particles = GPUParticles2D.new()
		_particles.name = "TidePocketParticles"
		_particles.z_index = -4
		_particles.amount = maxi(0, particle_cap)
		_particles.lifetime = 2.2
		_particles.randomness = 0.68
		_particles.process_material = _make_particle_material()
		add_child(_particles)

func _update_visuals(delta: float) -> void:
	var telegraph_ratio := clampf(_age / maxf(telegraph_time, 0.001), 0.0, 1.0)
	var life_remaining := clampf((telegraph_time + lifetime - _age) / maxf(lifetime, 0.001), 0.0, 1.0)
	var alpha_scale := telegraph_ratio * minf(1.0, life_remaining * 2.0)
	var visual_radius: float = _visual_radius()

	if _ring != null:
		var spin := 0.75
		if mode == TideMode.SLIPSTREAM:
			spin = 1.85
		elif mode == TideMode.INVERSION:
			spin = -1.1
		_ring.rotation += delta * spin
		_ring.color = _capped_mode_color(lerpf(0.08, 0.36, alpha_scale), visual_ring_alpha_cap)
		_ring.scale = Vector2.ONE * lerpf(1.12, 1.0, telegraph_ratio)

	if _core != null:
		_core.rotation -= delta * 0.38
		_core.color = _capped_mode_color(lerpf(0.04, 0.16, alpha_scale), visual_fill_alpha_cap)

	if _label != null:
		_label.visible = alpha_scale > 0.12
		_label.text = "%s  %s" % [_mode_display_name().to_upper(), _mode_rule_name()]
		_label.position = Vector2(-90.0, -visual_radius - 34.0)
		_label.size = Vector2(180.0, 26.0)
		_label.modulate = _capped_mode_color(lerpf(0.46, 0.94, alpha_scale), 0.72)

	_update_rule_glyphs(alpha_scale)

	if _particles != null:
		_particles.emitting = _active

func _apply_field(delta: float) -> void:
	var expired: Array = []
	var impulse_limit := max_body_impulse_per_second * delta

	for id in _tracked_bodies.keys():
		var body := _tracked_bodies[id] as Node
		if body == null or not is_instance_valid(body):
			expired.append(id)
			continue

		var body_2d := body as Node2D
		if body_2d == null or not _should_affect_body(body):
			continue

		var offset := body_2d.global_position - global_position
		var distance := maxf(offset.length(), 0.001)
		if distance > radius:
			_escape_buildup.erase(id)
			continue

		var radial := offset / distance
		var falloff := 1.0 - clampf(distance / radius, 0.0, 1.0)
		var impulse := Vector2.ZERO

		if mode == TideMode.COMPRESSION:
			impulse = -radial * field_acceleration * falloff * delta
		elif mode == TideMode.INVERSION:
			impulse = radial * field_acceleration * falloff * delta
		elif mode == TideMode.SLIPSTREAM:
			var tangent := radial.orthogonal()
			var velocity := _body_velocity(body)
			if tangent.dot(velocity) < 0.0:
				tangent = -tangent
			impulse = tangent * slipstream_acceleration * (0.35 + falloff) * delta
		else:
			impulse = _apply_temporal_field(body, radial, falloff, delta)

		if body.is_in_group("Player"):
			impulse += _player_escape_impulse(body, radial, falloff, distance, delta)
		if enable_escape_buildup:
			impulse += _trap_escape_buildup_impulse(body, radial, falloff, distance, delta)

		if impulse.length() > impulse_limit:
			impulse = impulse.limit_length(impulse_limit)

		CombatStatus.add_velocity(body, impulse)
		body_affected.emit(body, impulse, int(mode))

	for id in expired:
		_tracked_bodies.erase(id)
		_escape_buildup.erase(id)

func _on_body_entered(body: Node) -> void:
	if body == null or not _should_affect_body(body):
		return

	_tracked_bodies[body.get_instance_id()] = body

func _on_body_exited(body: Node) -> void:
	if body == null:
		return

	_tracked_bodies.erase(body.get_instance_id())
	_escape_buildup.erase(body.get_instance_id())

func _should_affect_body(body: Node) -> bool:
	if affects_player and body.is_in_group("Player"):
		return true
	if affects_enemies and (body.is_in_group("enemies") or body.is_in_group("wave_enemy") or body.is_in_group("bosses")):
		return true
	if affects_projectiles and (body.is_in_group("Projectiles") or body.is_in_group("enemy_projectiles") or body.is_in_group("player_projectiles")):
		return true
	return false

func _body_velocity(body: Node) -> Vector2:
	var velocity: Variant = body.get("velocity")
	if velocity is Vector2:
		return velocity

	var linear_velocity: Variant = body.get("linear_velocity")
	if linear_velocity is Vector2:
		return linear_velocity

	return Vector2.ZERO

func _apply_temporal_field(body: Node, radial: Vector2, falloff: float, delta: float) -> Vector2:
	var tangent := radial.orthogonal()
	var velocity := _body_velocity(body)
	if velocity != Vector2.ZERO and tangent.dot(velocity) < 0.0:
		tangent = -tangent

	if body.is_in_group("Player"):
		return tangent * temporal_player_tangent_boost * falloff * delta

	var multiplier := lerpf(1.0, temporal_slow_multiplier, falloff)
	_apply_local_slow(body, multiplier, temporal_slow_duration)
	temporal_pocket_entered.emit(body, multiplier, temporal_slow_duration)
	return -velocity.normalized() * field_acceleration * 0.12 * falloff * delta if velocity != Vector2.ZERO else Vector2.ZERO


func _player_escape_impulse(body: Node, radial: Vector2, falloff: float, distance: float, delta: float) -> Vector2:
	if mode != TideMode.COMPRESSION and mode != TideMode.TEMPORAL:
		return Vector2.ZERO
	if body.is_in_group("Player") and player_escape_requires_thrust and not Input.is_action_pressed("thrust"):
		return Vector2.ZERO
	if distance > radius * clampf(player_trap_escape_radius_ratio, 0.08, 0.65):
		return Vector2.ZERO
	var velocity := _body_velocity(body)
	if velocity.length() >= player_escape_floor_speed:
		return Vector2.ZERO
	var tangent := radial.orthogonal()
	if velocity != Vector2.ZERO and tangent.dot(velocity) < 0.0:
		tangent = -tangent
	var escape_dir := (radial * 0.74 + tangent * 0.46).normalized()
	return escape_dir * player_trap_escape_boost * falloff * delta


func _trap_escape_buildup_impulse(body: Node, radial: Vector2, falloff: float, distance: float, delta: float) -> Vector2:
	if mode != TideMode.COMPRESSION and mode != TideMode.TEMPORAL:
		return Vector2.ZERO
	if distance > radius * clampf(player_trap_escape_radius_ratio, 0.08, 0.65):
		_escape_buildup.erase(body.get_instance_id())
		return Vector2.ZERO
	if not (body.is_in_group("Player") or body.is_in_group("enemies") or body.is_in_group("wave_enemy") or body.is_in_group("bosses")):
		return Vector2.ZERO
	if body.is_in_group("Player") and player_escape_requires_thrust and not Input.is_action_pressed("thrust"):
		_escape_buildup.erase(body.get_instance_id())
		return Vector2.ZERO

	var velocity := _body_velocity(body)
	var floor_speed := player_escape_floor_speed if body.is_in_group("Player") else enemy_escape_floor_speed
	if velocity.length() >= floor_speed:
		_escape_buildup.erase(body.get_instance_id())
		return Vector2.ZERO

	var id := body.get_instance_id()
	var buildup := clampf(float(_escape_buildup.get(id, 0.0)) + delta / maxf(escape_buildup_seconds, 0.1), 0.0, 1.0)
	_escape_buildup[id] = buildup

	var tangent := radial.orthogonal()
	if velocity != Vector2.ZERO and tangent.dot(velocity) < 0.0:
		tangent = -tangent
	var escape_dir := (radial * 0.68 + tangent * 0.54).normalized()
	var boost := player_trap_escape_boost if body.is_in_group("Player") else enemy_trap_escape_boost
	if body.is_in_group("bosses"):
		boost *= 0.58
	return escape_dir * boost * lerpf(0.25, 1.0, buildup) * falloff * delta


func _apply_local_slow(body: Node, multiplier: float, duration: float) -> void:
	var time_manager := _get_time_dilation_manager()
	if time_manager != null and time_manager.has_method("apply_local_slow_to_target"):
		time_manager.call("apply_local_slow_to_target", body, multiplier, duration)
	else:
		CombatStatus.apply_local_slow(body, multiplier, duration)

func get_tide_debug_state(sample_position: Vector2) -> Dictionary:
	var distance := sample_position.distance_to(global_position)
	if distance > radius * 1.15:
		return {}

	var local_intensity := clampf(1.0 - distance / maxf(radius, 0.001), 0.0, 1.0)
	if not _active:
		local_intensity *= 0.42

	return {
		"mode": int(mode),
		"display_name": _mode_display_name(),
		"rule_name": _mode_rule_name(),
		"color": _mode_color(1.0),
		"local_intensity": local_intensity,
		"active": _active,
		"radius": radius,
		"position": global_position,
	}

func _get_time_dilation_manager() -> Node:
	if _time_dilation_manager != null and is_instance_valid(_time_dilation_manager) and not _time_dilation_manager.is_queued_for_deletion():
		return _time_dilation_manager

	var root := get_tree().current_scene
	if root == null:
		return null

	_time_dilation_manager = root.find_child("TimeDilationManager", true, false)
	return _time_dilation_manager

func _make_particle_material() -> ParticleProcessMaterial:
	var gradient := Gradient.new()
	var base: Color = _capped_mode_color(0.72, visual_ring_alpha_cap)
	gradient.set_color(0, base)
	gradient.set_color(1, Color(base.r, base.g, base.b, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = _visual_radius() * 0.72
	material.spread = 180.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 58.0
	material.orbit_velocity_min = 0.2 if mode == TideMode.SLIPSTREAM else -0.12
	material.orbit_velocity_max = 1.2 if mode == TideMode.SLIPSTREAM else 0.12
	material.radial_accel_min = -42.0 if mode == TideMode.COMPRESSION else 12.0
	material.radial_accel_max = -10.0 if mode == TideMode.COMPRESSION else 74.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.6
	material.scale_max = 6.0
	material.color_ramp = texture
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.72
	return material

func _mode_color(alpha: float) -> Color:
	if mode == TideMode.SLIPSTREAM:
		return Color(0.0, 0.96, 0.78, alpha)
	if mode == TideMode.INVERSION:
		return Color(1.0, 0.38, 0.13, alpha)
	if mode == TideMode.TEMPORAL:
		return Color(0.72, 0.38, 1.0, alpha)
	return Color(0.28, 0.72, 1.0, alpha)


func _capped_mode_color(alpha: float, hard_cap: float) -> Color:
	var base: Color = _mode_color(_visual_alpha(alpha, hard_cap))
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(base)
	return base

func _mode_display_name() -> String:
	return String(MODE_DISPLAY_NAMES.get(mode, "Compression"))

func _mode_rule_name() -> String:
	return String(MODE_RULE_NAMES.get(mode, "PULL"))

func _update_rule_glyphs(alpha_scale: float) -> void:
	var visible := debug_visual_enabled and alpha_scale > 0.1
	var color: Color = _capped_mode_color(lerpf(0.16, 0.78, alpha_scale), visual_glyph_alpha_cap)
	var visual_radius: float = _visual_radius()

	for i in range(_glyphs.size()):
		var glyph := _glyphs[i]
		if glyph == null or not is_instance_valid(glyph):
			continue

		glyph.visible = visible
		if not visible:
			continue

		var angle := TAU * float(i) / float(maxi(_glyphs.size(), 1))
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := radial.orthogonal()
		var inner := visual_radius * 0.36
		var outer := visual_radius * 0.78
		var points := PackedVector2Array()

		if mode == TideMode.COMPRESSION:
			points.append(radial * outer)
			points.append(radial * inner)
		elif mode == TideMode.INVERSION:
			points.append(radial * inner)
			points.append(radial * outer)
		elif mode == TideMode.SLIPSTREAM:
			var center := radial * visual_radius * 0.62
			points.append(center - tangent * visual_radius * 0.18)
			points.append(center + tangent * visual_radius * 0.18)
		else:
			var center := radial * visual_radius * 0.52
			points.append(center - tangent * visual_radius * 0.12)
			points.append(center + tangent * visual_radius * 0.12)

		glyph.points = points
		glyph.width = lerpf(1.2, 3.2, alpha_scale)
		glyph.default_color = color


func _visual_radius() -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(radius, visual_radius_cap)
	return clampf(radius, 0.0, maxf(visual_radius_cap, 1.0))


func _visual_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)

func _ring_points(count: int, inner_radius: float, outer_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	return points

func _soft_circle_points(count: int, base_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var wave := sin(angle * 3.0) * 0.06 + cos(angle * 7.0) * 0.035
		points.append(Vector2(cos(angle), sin(angle)) * base_radius * (1.0 + wave))
	return points
