extends Node2D
func _ready() -> void:
	$Player/CanvasLayer/Health.show()
	$Player/CanvasLayer/Drag.show()
	$Player/CanvasLayer/Energy.show()
