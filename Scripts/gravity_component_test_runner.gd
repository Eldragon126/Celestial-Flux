extends SceneTree

const GravityComponentScene := preload("res://Nodes/gravity_component.tscn")

class TestGravitySource extends Node2D:
	var mass := 100.0

func _initialize() -> void:
	var root_node := Node2D.new()
	root.add_child(root_node)

	var planet := TestGravitySource.new()
	planet.name = "TestPlanet"
	planet.global_position = Vector2(10.0, 0.0)
	root_node.add_child(planet)
	planet.add_to_group("planets")

	var body := CharacterBody2D.new()
	body.name = "TestBody"
	body.global_position = Vector2.ZERO
	root_node.add_child(body)

	var gravity_component := GravityComponentScene.instantiate() as GravityComponent
	gravity_component.gravity_constant = 2.0
	gravity_component.min_gravity_distance = 1.0
	gravity_component.auto_apply = false
	body.add_child(gravity_component)

	await process_frame

	var acceleration: Vector2 = gravity_component.calculate_gravity()
	var expected := Vector2(2.0, 0.0)

	if not acceleration.is_equal_approx(expected):
		push_error("Expected acceleration %s, got %s." % [expected, acceleration])
		quit(1)
		return

	gravity_component.apply_gravity(0.5)

	if not body.velocity.is_equal_approx(Vector2(1.0, 0.0)):
		push_error("Expected velocity (1, 0), got %s." % body.velocity)
		quit(1)
		return

	gravity_component.max_gravity_distance = 5.0
	acceleration = gravity_component.calculate_gravity()

	if not acceleration.is_zero_approx():
		push_error("Expected max distance to ignore planet, got %s." % acceleration)
		quit(1)
		return

	var auto_body := CharacterBody2D.new()
	auto_body.name = "AutoTestBody"
	auto_body.global_position = Vector2.ZERO
	root_node.add_child(auto_body)

	var auto_component := GravityComponentScene.instantiate() as GravityComponent
	auto_component.gravity_constant = 2.0
	auto_component.min_gravity_distance = 1.0
	auto_component.auto_apply = true
	auto_body.add_child(auto_component)

	await process_frame
	await physics_frame
	await process_frame

	if auto_body.velocity.x <= 0.0:
		push_error("Expected auto-applied gravity to push the body right, got %s." % auto_body.velocity)
		quit(1)
		return

	print("GravityComponent tests passed.")
	quit(0)
