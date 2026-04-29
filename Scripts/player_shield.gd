extends Area2D

@export var radius: float = 60.0

func _ready():
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	for i in range(6):
		var angle = i * PI / 3 
		var pos = Vector2(cos(angle), sin(angle))
		points.append(pos * radius)
		
		# UVs usually range from 0 to 1. 
		# This maps the circle math to a 0.0 - 1.0 square range.
		uvs.append((pos + Vector2.ONE) / 2.0)
	
	$Polygon2D.polygon = points
	$Polygon2D.uv = uvs # This tells the shader where to draw what
func hit():
	var tween = create_tween()
	# Pulse the shield opacity and scale slightly
	tween.tween_property($Polygon2D, "self_modulate:a", 1.0, 0.1)
	tween.parallel().tween_property($Polygon2D, "scale", Vector2(1.1, 1.1), 0.1)
	
	# Return to normal
	tween.tween_property($Polygon2D, "self_modulate:a", 0.3, 0.4)
	tween.parallel().tween_property($Polygon2D, "scale", Vector2(1.0, 1.0), 0.4)
	
func on_shield_hit():
	var mat = $Polygon2D.material as ShaderMaterial
	var tween = create_tween()
	
	# Briefly spike the pattern scale or brightness
	tween.tween_property(mat, "shader_parameter/time_multiplier", 5.0, 0.1)
	tween.tween_property(mat, "shader_parameter/time_multiplier", 1.0, 0.5)
