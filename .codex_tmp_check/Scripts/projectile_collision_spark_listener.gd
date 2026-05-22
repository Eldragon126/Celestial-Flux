extends Node

# Child listener added to projectile bodies by ProjectileSparkWatcher.

const COLLISION_SPARK_SCENE = preload("res://Nodes/collision_sparks.tscn")

var _projectile: RigidBody2D = null


func _ready() -> void:
	_projectile = get_parent() as RigidBody2D
	if _projectile != null and not _projectile.body_entered.is_connected(_on_body_entered):
		_projectile.body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	if _projectile == null or not is_instance_valid(_projectile):
		return

	var sparks := COLLISION_SPARK_SCENE.instantiate() as CPUParticles2D
	if sparks == null or get_tree().current_scene == null:
		return

	get_tree().current_scene.add_child(sparks)
	sparks.global_position = _projectile.global_position
	if _projectile.linear_velocity.length() > 0.01:
		sparks.global_rotation = _projectile.linear_velocity.angle()
