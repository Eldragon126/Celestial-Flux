extends Node
class_name EnergyComponent

signal energy_changed(current_energy, max_energy)
signal energy_depleted

@export var max_energy: float = 300.0
@export var starting_energy: float = -1.0

var current_energy: float

func _ready() -> void:
	if starting_energy < 0.0:
		current_energy = max_energy
	else:
		current_energy = clampf(starting_energy, 0.0, max_energy)

	energy_changed.emit(current_energy, max_energy)

func spend(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var spent: float = minf(amount, current_energy)
	current_energy -= spent
	energy_changed.emit(current_energy, max_energy)

	if current_energy <= 0.0:
		energy_depleted.emit()

	return spent

func restore(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var previous_energy: float = current_energy
	current_energy = minf(current_energy + amount, max_energy)
	var restored: float = current_energy - previous_energy

	if restored > 0.0:
		energy_changed.emit(current_energy, max_energy)

	return restored

func has_energy(amount: float = 0.0) -> bool:
	return current_energy > 0.0 and current_energy >= amount

func get_energy_percent() -> float:
	if max_energy <= 0.0:
		return 0.0

	return current_energy / max_energy
