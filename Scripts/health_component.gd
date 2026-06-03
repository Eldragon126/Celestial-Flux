extends Node
class_name HealthComponent

# Signals to tell other nodes when things happen (like updating a UI or dying)
signal died
signal health_changed(current_health, max_health)

@export var max_health: float = 100.0
var current_health: float
var _dead: bool = false

func _ready():
	current_health = max_health

func take_damage(amount: float):
	if _dead or amount <= 0.0:
		return

	current_health -= amount
	current_health = maxf(current_health, 0.0)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		_dead = true
		died.emit()

func heal(amount: float):
	if amount <= 0.0:
		return
	if _dead:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return _dead
