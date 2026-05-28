extends StaticBody2D

signal planet_fractured(fracture_data: Dictionary)
signal planet_collapsed(fracture_data: Dictionary)

enum PlanetKind { AUTO, BLUE_DENSE, RED_VOLATILE, CYAN_LENS, VIOLET_TEMPORAL }

@export_enum("Auto", "Blue Dense", "Red Volatile", "Cyan Lens", "Violet Temporal") var planet_type: int = PlanetKind.AUTO
@export var base_mass: float = 300000.0
@export var base_radius: float = 150.0
@export var spacetime_stability_per_radius: float = 2.8
@export var positron_mass_loss_scale: float = 0.22
@export var minimum_fractured_radius_ratio: float = 0.36
@export var fracture_scar_cooldown: float = 0.7
@export var collapse_scar_radius_multiplier: float = 2.2

var mass: float
var radius: float
var max_spacetime_stability: float = 1.0
var current_spacetime_stability: float = 1.0
var planet_type_id: StringName = &"blue_dense"
var planet_display_name: String = "Blue Dense"

@onready var polygon: Polygon2D = $Polygon2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var point_light: PointLight2D = $PointLight2D

var _starting_mass: float = 0.0
var _starting_radius: float = 0.0
var _fracture_flash: float = 0.0
var _last_fracture_scar_time: float = -999.0
var _collapsed := false


func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")

	# =========================
	# RANDOMIZE SIZE
	# =========================
	var rand_scale := randf_range(0.5, 1.5)
	var type_data := _planet_type_data(_resolve_planet_type())
	planet_type_id = type_data.get("id", &"blue_dense")
	planet_display_name = String(type_data.get("display_name", "Blue Dense"))

	radius = base_radius * rand_scale * float(type_data.get("radius_multiplier", 1.0))
	mass = base_mass * rand_scale * float(type_data.get("mass_multiplier", 1.0))
	_starting_radius = radius
	_starting_mass = mass
	max_spacetime_stability = maxf(_starting_radius * spacetime_stability_per_radius * float(type_data.get("stability_multiplier", 1.0)), 1.0)
	current_spacetime_stability = max_spacetime_stability

	# =========================
	# MAKE COLLISION SHAPE UNIQUE
	# VERY IMPORTANT
	# =========================
	collision.shape = collision.shape.duplicate()

	# =========================
	# UPDATE VISUALS
	# =========================
	draw_circle_polygon(64, radius)
	_apply_planet_type_visuals(type_data)

	# =========================
	# UPDATE COLLISION
	# =========================
	if collision.shape is CircleShape2D:
		collision.shape.radius = radius

	# =========================
	# UPDATE PARTICLES
	# =========================
	if particles.process_material is ParticleProcessMaterial:
		var mat := particles.process_material as ParticleProcessMaterial
		mat = mat.duplicate()
		particles.process_material = mat
		mat.emission_sphere_radius = radius
		mat.color = type_data.get("particle_color", Color(0.0, 0.92, 0.86, 1.0))

	# =========================
	# ENSURE NO NODE SCALING
	# =========================
	scale = Vector2.ONE
	polygon.scale = Vector2.ONE
	set_process(true)


func _process(delta: float) -> void:
	if _fracture_flash <= 0.0:
		return
	_fracture_flash = maxf(_fracture_flash - delta * 2.8, 0.0)
	var flash := Color(1.0, 0.72, 0.28, 1.0)
	polygon.modulate = Color.WHITE.lerp(flash, _fracture_flash)


func apply_spacetime_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, source_label: StringName = &"spacetime") -> bool:
	if _collapsed or amount <= 0.0:
		return false

	current_spacetime_stability = maxf(current_spacetime_stability - amount, 0.0)
	var stability_ratio := current_spacetime_stability / maxf(max_spacetime_stability, 1.0)
	var damage_ratio := 1.0 - stability_ratio
	var minimum_radius := _starting_radius * clampf(minimum_fractured_radius_ratio, 0.12, 1.0)
	radius = maxf(lerpf(_starting_radius, minimum_radius, damage_ratio), 24.0)
	mass = maxf(_starting_mass * (1.0 - damage_ratio * positron_mass_loss_scale), _starting_mass * 0.18)
	_fracture_flash = 1.0

	draw_circle_polygon(64, radius)
	_update_collision_radius()
	_update_particle_radius()
	_emit_fracture(hit_position, source_label, stability_ratio)

	if current_spacetime_stability <= 0.0:
		_collapse_into_spacetime_rip(hit_position, source_label)

	return true


func draw_circle_polygon(points_nb: int, circle_radius: float) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(points_nb):
		var angle := TAU * float(i) / float(points_nb) - PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))

		points.push_back(dir * circle_radius)

		# UV mapping
		uvs.push_back((dir + Vector2.ONE) * 0.5)

	polygon.polygon = points
	polygon.uv = uvs


func _update_collision_radius() -> void:
	if collision == null or collision.shape == null:
		return
	if collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = radius


func _update_particle_radius() -> void:
	if particles == null or not (particles.process_material is ParticleProcessMaterial):
		return
	var mat := particles.process_material as ParticleProcessMaterial
	mat.emission_sphere_radius = radius


func _emit_fracture(hit_position: Vector2, source_label: StringName, stability_ratio: float) -> void:
	var fracture_data := {
		"planet": self,
		"position": global_position,
		"hit_position": hit_position if hit_position != Vector2.ZERO else global_position,
		"radius": radius,
		"mass": mass,
		"stability": stability_ratio,
		"source": source_label,
	}
	planet_fractured.emit(fracture_data)
	_stamp_fracture_scar(fracture_data)


func _stamp_fracture_scar(fracture_data: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_fracture_scar_time < fracture_scar_cooldown:
		return
	_last_fracture_scar_time = now

	var scars := _get_gravity_scar_manager()
	if scars == null or not scars.has_method("create_gravity_scar"):
		return

	var stability := clampf(float(fracture_data.get("stability", 1.0)), 0.0, 1.0)
	scars.call(
		"create_gravity_scar",
		global_position,
		maxf(radius * 1.35, 180.0),
		GravityScarManager.ScarType.CURVATURE if stability > 0.34 else GravityScarManager.ScarType.TEMPORAL_RIP,
		clampf(0.24 + (1.0 - stability) * 0.52, 0.18, 0.86),
		28.0 + (1.0 - stability) * 22.0,
		StringName(fracture_data.get("source", &"planet_fracture"))
	)


func _collapse_into_spacetime_rip(hit_position: Vector2, source_label: StringName) -> void:
	if _collapsed:
		return
	_collapsed = true
	remove_from_group("planets")
	remove_from_group("Objects_With_Gravity")

	var collapse_data := {
		"planet": self,
		"position": global_position,
		"hit_position": hit_position if hit_position != Vector2.ZERO else global_position,
		"radius": _starting_radius,
		"mass": _starting_mass,
		"source": source_label,
	}
	planet_collapsed.emit(collapse_data)
	_stamp_collapse_scar(collapse_data)
	_fade_and_free()


func _stamp_collapse_scar(collapse_data: Dictionary) -> void:
	var scars := _get_gravity_scar_manager()
	if scars == null or not scars.has_method("create_gravity_scar"):
		return
	scars.call(
		"create_gravity_scar",
		global_position,
		maxf(_starting_radius * collapse_scar_radius_multiplier, 340.0),
		GravityScarManager.ScarType.HARMONIC_FRACTURE,
		0.92,
		72.0,
		StringName(collapse_data.get("source", &"planet_collapse"))
	)


func _fade_and_free() -> void:
	if collision != null:
		collision.set_deferred("disabled", true)
	if particles != null:
		particles.emitting = false
	var tween := create_tween()
	tween.tween_property(polygon, "modulate:a", 0.0, 0.34)
	tween.tween_callback(queue_free)


func _get_gravity_scar_manager() -> Node:
	var root := get_tree().current_scene
	return root.find_child("GravityScarManager", true, false) if root != null else null
