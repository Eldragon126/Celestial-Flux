extends Object
class_name PowerupLibrary

const PICKUP_SCENE = preload("res://Nodes/powerup_pickup.tscn")
const SINGULARITY_AMPLIFIER = preload("res://Scripts/Powerups/singularity_amplifier.tres")
const TIME_FRACTURE_PULSE = preload("res://Scripts/Powerups/time_fracture_pulse.tres")
const SHIELD_OVERCHARGE = preload("res://Scripts/Powerups/shield_overcharge.tres")
const ORBITAL_TETHER_UPGRADE = preload("res://Scripts/Powerups/orbital_tether_upgrade.tres")

static func get_all_definitions() -> Array[PowerupDefinition]:
	return [
		SINGULARITY_AMPLIFIER,
		TIME_FRACTURE_PULSE,
		SHIELD_OVERCHARGE,
		ORBITAL_TETHER_UPGRADE,
	]

static func get_definition(powerup_id: StringName) -> PowerupDefinition:
	for definition in get_all_definitions():
		if definition.powerup_id == powerup_id:
			return definition
	return null

static func get_random_definition() -> PowerupDefinition:
	var definitions = get_all_definitions()
	return definitions[randi() % definitions.size()]

static func try_spawn_drop(parent: Node, global_pos: Vector2, chance: float, guaranteed: bool = false) -> Node:
	if parent == null:
		return null
	if not guaranteed and randf() > chance:
		return null

	var pickup = PICKUP_SCENE.instantiate() as PowerupPickup
	pickup.definition = get_random_definition()
	pickup.global_position = global_pos
	parent.call_deferred("add_child", pickup)
	return pickup
