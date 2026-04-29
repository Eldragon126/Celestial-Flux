extends Node
class_name HealthComponent

# Signals to tell other nodes when things happen (like updating a UI or dying)
signal died
signal health_changed(current_health, max_health)

@export var max_health: float = 100.0
var current_health: float

func _ready():
	current_health = max_health

func take_damage(amount: float):
	current_health -= amount
	# Emit signal so UI health bars can update automatically
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		died.emit()

func heal(amount: float):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
