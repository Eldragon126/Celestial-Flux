extends StaticBody2D

@export var base_mass: float = 300000.0
@export var base_radius: float = 150.0

var mass: float
var radius: float

@onready var polygon: Polygon2D = $Polygon2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var particles: GPUParticles2D = $GPUParticles2D


func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")

	# =========================
	# RANDOMIZE SIZE
	# =========================
	var rand_scale := randf_range(0.5, 1.5)

	radius = base_radius * rand_scale
	mass = base_mass * rand_scale

	# =========================
	# MAKE COLLISION SHAPE UNIQUE
	# VERY IMPORTANT
	# =========================
	collision.shape = collision.shape.duplicate()

	# =========================
	# UPDATE VISUALS
	# =========================
	draw_circle_polygon(64, radius)

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

	# =========================
	# ENSURE NO NODE SCALING
	# =========================
	scale = Vector2.ONE
	polygon.scale = Vector2.ONE


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
