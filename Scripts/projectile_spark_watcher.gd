extends Node

# Watches for projectile instances and attaches a tiny listener that spawns
# sparks on collision. This avoids editing projectile.gd or enemy_bullet.gd.

const SPARK_LISTENER_SCRIPT := preload("res://Scripts/projectile_collision_spark_listener.gd")

func _ready() -> void:
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_scan_existing_projectiles")

func _scan_existing_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("Projectiles"):
		_try_attach_listener(node)

func _on_tree_node_added(node: Node) -> void:
	call_deferred("_try_attach_listener", node)

func _try_attach_listener(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	var projectile := _find_projectile_body(node)
	if projectile == null:
		return
	if projectile.has_node("CollisionSparkListener"):
		return

	var listener := Node.new()
	listener.name = "CollisionSparkListener"
	listener.set_script(SPARK_LISTENER_SCRIPT)
	projectile.add_child(listener)

func _find_projectile_body(node: Node) -> RigidBody2D:
	var current := node
	while current != null:
		if current is RigidBody2D and _looks_like_projectile(current):
			return current
		current = current.get_parent()

	return null

func _looks_like_projectile(node: Node) -> bool:
	var path := node.scene_file_path
	return path.ends_with("projectile.tscn") or path.ends_with("enemy_bullet.tscn") or node.is_in_group("Projectiles")
