extends Node

# Child listener added to projectile bodies by ProjectileSparkWatcher.

const COLLISION_SPARK_SCENE = preload("res://Nodes/collision_sparks.tscn")
const SPARK_PRESSURE_SOFT_CAP := 54
const SPARK_PRESSURE_HARD_CAP := 96
const SPARK_FOCUS_RADIUS := 1500.0

var _projectile: RigidBody2D = null


func _ready() -> void:
	_projectile = get_parent() as RigidBody2D
	if _projectile != null and not _projectile.body_entered.is_connected(_on_body_entered):
		_projectile.body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	if _projectile == null or not is_instance_valid(_projectile):
		return
	var pressure := _projectile_pressure()
	if pressure >= SPARK_PRESSURE_HARD_CAP:
		return
	if not _projectile_in_focus():
		return

	var sparks := COLLISION_SPARK_SCENE.instantiate() as CPUParticles2D
	if sparks == null or get_tree().current_scene == null:
		return
	if pressure >= SPARK_PRESSURE_SOFT_CAP:
		sparks.amount = 10
	else:
		sparks.amount = mini(sparks.amount, 22)

	get_tree().current_scene.add_child(sparks)
	sparks.global_position = _projectile.global_position
	if _projectile.linear_velocity.length() > 0.01:
		sparks.global_rotation = _projectile.linear_velocity.angle()


func _projectile_pressure() -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(&"Projectiles")
	return get_tree().get_nodes_in_group("Projectiles").size()


func _projectile_in_focus() -> bool:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null or not is_instance_valid(player):
		return true
	return _projectile.global_position.distance_squared_to(player.global_position) <= SPARK_FOCUS_RADIUS * SPARK_FOCUS_RADIUS
