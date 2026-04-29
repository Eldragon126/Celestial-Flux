extends StaticBody2D

var mass = 400000
@export var radius: float = 150.0

func _ready() -> void:
	# 1. Randomize radius first
	radius *= randf_range(0.5, 1.75)
	
	# 2. Draw the polygon AND set UVs in one go
	draw_circle_polygon(40, radius)
	
	# 3. Update physics and particles
	$CollisionShape2D.shape.radius = radius
	$GPUParticles2D.process_material.emission_sphere_radius = radius

func draw_circle_polygon(points_nb: int, circle_radius: float) -> void:
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	for i in range(points_nb): # Removed +1 to prevent a tiny overlap gap
		var angle = deg_to_rad(i * 360.0 / points_nb - 90)
		var dir = Vector2(cos(angle), sin(angle))
		
		# Add the vertex position
		points.push_back(dir * circle_radius)
		
		# Add the UV coordinate (Maps the circle to a 0.0 - 1.0 square)
		# This is the secret sauce that makes the shader visible!
		uvs.push_back((dir + Vector2.ONE) / 2.0)
	
	$Polygon2D.polygon = points
	$Polygon2D.uv = uvs # Apply the coordinates to the polygon
