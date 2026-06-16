extends Node2D
@export var mass: float = 300000.0

var _gravity_active: bool = true


func _ready() -> void:
	set_gravity_active(_gravity_active)


func set_gravity_active(active: bool) -> void:
	_gravity_active = active
	visible = active
	if active:
		_register_gravity_groups()
	else:
		_unregister_gravity_groups()


func is_gravity_active() -> bool:
	return _gravity_active


func _register_gravity_groups() -> void:
	if not is_in_group("Objects_With_Gravity"):
		add_to_group("Objects_With_Gravity")
	if not is_in_group("planets"):
		add_to_group("planets")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")


func _unregister_gravity_groups() -> void:
	if is_in_group("Objects_With_Gravity"):
		remove_from_group("Objects_With_Gravity")
	if is_in_group("planets"):
		remove_from_group("planets")
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")


func _exit_tree() -> void:
	_unregister_gravity_groups()
