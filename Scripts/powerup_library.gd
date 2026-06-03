extends Object
class_name PowerupLibrary

const PICKUP_SCENE = preload("res://Nodes/powerup_pickup.tscn")
const SINGULARITY_AMPLIFIER = preload("res://Scripts/Powerups/singularity_amplifier.tres")
const TIME_FRACTURE_PULSE = preload("res://Scripts/Powerups/time_fracture_pulse.tres")
const SHIELD_OVERCHARGE = preload("res://Scripts/Powerups/shield_overcharge.tres")
const ORBITAL_TETHER_UPGRADE = preload("res://Scripts/Powerups/orbital_tether_upgrade.tres")
const MOMENTUM_SHOCKWAVE_LAW = preload("res://Scripts/Powerups/momentum_shockwave_law.tres")
const APEX_VECTOR_CORE = preload("res://Scripts/Powerups/apex_vector_core.tres")
const MICRO_LENSING_EMITTER = preload("res://Scripts/Powerups/micro_lensing_emitter.tres")
const VACUUM_COLLAPSE_INJECTOR = preload("res://Scripts/Powerups/vacuum_collapse_injector.tres")
const RELATIVISTIC_RAIL = preload("res://Scripts/Powerups/relativistic_rail.tres")
const ORBITAL_DEBRIS_SEEDER = preload("res://Scripts/Powerups/orbital_debris_seeder.tres")
const CHRONAL_REFRACTION_BEAM = preload("res://Scripts/Powerups/chronal_refraction_beam.tres")
const BARYCENTRIC_TETHER = preload("res://Scripts/Powerups/barycentric_tether.tres")
const FRAME_DRAGGING_ANCHOR = preload("res://Scripts/Powerups/frame_dragging_anchor.tres")

static func get_all_definitions() -> Array[PowerupDefinition]:
	return [
		SINGULARITY_AMPLIFIER,
		TIME_FRACTURE_PULSE,
		SHIELD_OVERCHARGE,
		ORBITAL_TETHER_UPGRADE,
		MOMENTUM_SHOCKWAVE_LAW,
		APEX_VECTOR_CORE,
		MICRO_LENSING_EMITTER,
		VACUUM_COLLAPSE_INJECTOR,
		RELATIVISTIC_RAIL,
		ORBITAL_DEBRIS_SEEDER,
		CHRONAL_REFRACTION_BEAM,
		BARYCENTRIC_TETHER,
		FRAME_DRAGGING_ANCHOR,
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
