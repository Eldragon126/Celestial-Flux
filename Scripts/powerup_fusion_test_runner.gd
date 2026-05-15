extends SceneTree

func _initialize() -> void:
	var level := Node2D.new()
	root.add_child(level)

	var player := CharacterBody2D.new()
	player.name = "FusionTestPlayer"
	player.global_position = Vector2.ZERO
	player.velocity = Vector2(420.0, 0.0)
	player.add_to_group("Player")
	level.add_child(player)

	var inventory := PowerupInventory.new()
	inventory.name = "PowerupInventory"
	player.add_child(inventory)
	await process_frame

	_apply_test_powerup(inventory, &"singularity_amplifier", &"singularity_amplifier")
	_apply_test_powerup(inventory, &"orbital_tether_upgrade", &"orbital_tether_upgrade")
	_apply_test_powerup(inventory, &"time_fracture_pulse", &"time_fracture_pulse", 18.0)

	var debris := GravityDebris.new()
	debris.name = "FusionTestDebris"
	debris.configure(90000.0, 90.0, 3.0, Color(0.78, 0.32, 1.0, 1.0))
	debris.global_position = Vector2(96.0, 0.0)
	level.add_child(debris)
	await process_frame

	inventory.call("_on_kinetic_shockwave_created", {
		"position": Vector2.ZERO,
		"radius": 150.0,
		"speed": 1400.0,
	})
	await process_frame

	var drift: Vector2 = debris.get("_drift_velocity")
	if drift.x <= 0.0:
		push_error("Expected Momentum+Singularity to bend debris outward, got drift %s." % drift)
		quit(1)
		return

	var projectile := RigidBody2D.new()
	projectile.name = "FusionTestSatellite"
	projectile.global_position = Vector2(120.0, 0.0)
	projectile.linear_velocity = Vector2.ZERO
	level.add_child(projectile)
	projectile.add_to_group("player_projectiles")

	inventory.set("_captured_projectiles", {
		projectile.get_instance_id(): {
			"projectile": projectile,
			"age": 0.0,
			"angle": 0.0,
			"radius": 118.0,
		}
	})

	inventory.call("_fling_satellites_with_time_fracture", Vector2.RIGHT * 460.0, 1)

	if projectile.linear_velocity.length() < 900.0:
		push_error("Expected Orbital+Time fusion to fling satellite, got %s." % projectile.linear_velocity)
		quit(1)
		return

	var fusion_state: Dictionary = inventory.call("get_law_fusion_debug_state")
	if String(fusion_state.get("last", "none")) != "orbital_time_fracture":
		push_error("Expected last fusion to be orbital_time_fracture, got %s." % fusion_state)
		quit(1)
		return

	print("Powerup fusion tests passed.")
	quit(0)

func _apply_test_powerup(inventory: PowerupInventory, powerup_id: StringName, effect_type: StringName, duration: float = 0.0) -> void:
	var definition := PowerupDefinition.new()
	definition.powerup_id = powerup_id
	definition.effect_type = effect_type
	definition.stack_policy = PowerupDefinition.StackPolicy.STACKABLE if duration <= 0.0 else PowerupDefinition.StackPolicy.REFRESH_DURATION
	definition.max_stacks = 4
	definition.duration = duration
	definition.amount = 1.0
	inventory.apply_powerup(definition)
