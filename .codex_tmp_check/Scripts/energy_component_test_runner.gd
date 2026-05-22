extends SceneTree

const EnergyComponentScene = preload("res://Nodes/energy_component.tscn")

func _initialize() -> void:
	var energy_component = EnergyComponentScene.instantiate()
	root.add_child(energy_component)

	await process_frame

	if not is_equal_approx(energy_component.current_energy, energy_component.max_energy):
		push_error("Expected energy to start full, got %s/%s." % [
			energy_component.current_energy,
			energy_component.max_energy
		])
		quit(1)
		return

	var spent: float = energy_component.spend(25.0)

	if not is_equal_approx(spent, 25.0):
		push_error("Expected to spend 25 energy, spent %s." % spent)
		quit(1)
		return

	if not is_equal_approx(energy_component.current_energy, 75.0):
		push_error("Expected 75 energy after spending, got %s." % energy_component.current_energy)
		quit(1)
		return

	spent = energy_component.spend(1000.0)

	if not is_equal_approx(spent, 75.0):
		push_error("Expected overspend to spend remaining 75 energy, spent %s." % spent)
		quit(1)
		return

	var restored: float = energy_component.restore(12.5)

	if not is_equal_approx(restored, 12.5):
		push_error("Expected to restore 12.5 energy, restored %s." % restored)
		quit(1)
		return

	if not is_equal_approx(energy_component.get_energy_percent(), 0.125):
		push_error("Expected energy percent 0.125, got %s." % energy_component.get_energy_percent())
		quit(1)
		return

	print("EnergyComponent tests passed.")
	quit(0)
