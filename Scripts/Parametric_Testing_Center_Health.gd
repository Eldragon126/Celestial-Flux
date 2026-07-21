extends Label
@onready var health_component = $"../HealthComponent"

func _process(delta):
	text = str(health_component.current_health)
