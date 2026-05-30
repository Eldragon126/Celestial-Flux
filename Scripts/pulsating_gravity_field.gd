extends StaticBody2D

@export var base_mass: float = 300000.0
@export var base_radius: float = 10.0
@export var base_how_big: float = 1000
var t = 0.0
var mass: float
var rand_factor: float
var radius: float
var how_big: float
var osscilation = 0.0
func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")
	radius = base_radius * randf_range(0.4,2)
	how_big = base_how_big * randf_range(0.4,2)
	rand_factor = 1 * randf_range(0.5,4)
	mass = base_mass * rand_factor
	draw_big_sphere_polygon(100, radius)
	draw_small_sphere_polygon(100, radius/3)
	

func draw_big_sphere_polygon(points_nb: int, circle_radius: float) -> void:
	if not $BigSphere: return
	
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(points_nb):
		var angle := TAU * float(i) / float(points_nb) - PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))

		points.push_back(dir * circle_radius)

		# UV mapping
		uvs.push_back((dir + Vector2.ONE) * 0.5)

	$BigSphere.polygon = points
	$BigSphere.uv = uvs
	
	
func draw_small_sphere_polygon(points_nb: int, circle_radius: float) -> void:
	if not $SmallSphere: return
	
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(points_nb):
		var angle := TAU * float(i) / float(points_nb) - PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))

		points.push_back(dir * circle_radius)

		# UV mapping
		uvs.push_back((dir + Vector2.ONE) * 0.5)

	$SmallSphere.polygon = points
	$SmallSphere.uv = uvs

func _process(delta: float) -> void:
	var big_color = 0.0
	var small_color = 0.0
	t = t + (delta * 100)
	osscilation = delta + osscilation
	if osscilation >= TAU:
		osscilation = 0
	if t > (how_big - 100):
		if big_color == 0.0 or small_color == 0.0:
			big_color = $BigSphere.color
			small_color = $SmallSphere.color
		$BigSphere.color = lerp(big_color,Color(0.059, 0.933, 0.933, 0 ), delta * 5)
		$SmallSphere.color = lerp(small_color,Color(0.0, 0.208, 0.208, 0),delta * 5)
	else:
		$BigSphere.color = Color(0.059, 0.933, 0.933, 0.5 * sin(osscilation)+0.5)
		$SmallSphere.color = Color(0.0, 0.207, 0.207, 0.502)
	if t > how_big:
		queue_free()
	
	draw_big_sphere_polygon(100, (radius + t))
	draw_small_sphere_polygon(100, (radius/3 + 1.05*t))
	
	mass = base_mass* rand_factor * sin(osscilation)

	
