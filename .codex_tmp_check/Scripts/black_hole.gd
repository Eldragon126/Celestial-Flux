extends StaticBody2D
var mass = 1000000

func _ready() -> void:
	add_to_group("planets")
	add_to_group("Objects_With_Gravity")


func _on_detector_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(10000000)
