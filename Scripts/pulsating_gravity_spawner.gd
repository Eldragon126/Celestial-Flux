extends StaticBody2D

var radius = 60
var pulsating_gravity_field = preload("res://Nodes/pulsating_gravity_field.tscn")
func _ready() -> void:
	draw_small_sphere_polygon(60, radius)
	$Timer.wait_time = randf_range(5,10)
func draw_small_sphere_polygon(points_nb: int, circle_radius: float) -> void:
	if not $CollisionPolygon2D: return
	
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(points_nb):
		var angle := TAU * float(i) / float(points_nb) - PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))

		points.push_back(dir * circle_radius)

		# UV mapping
		uvs.push_back((dir + Vector2.ONE) * 0.5)

	$CollisionPolygon2D.polygon = points
	$Polygon2D.polygon = points
	$Polygon2D.uv = uvs


func _on_timer_timeout() -> void:
	var i = pulsating_gravity_field.instantiate()
	i.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", i)
	$Timer.start()
