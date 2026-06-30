extends Node
class_name HealthComponent

# Signals to tell other nodes when things happen (like updating a UI or dying).
signal died
signal health_changed(current_health: float, max_health: float)
signal damage_taken(amount: float, current_health: float, max_health: float, context: Dictionary)

@export var max_health: float = 100.0
@export_group("Damage Feedback")
@export var emit_damage_feedback: bool = true
@export var clear_feedback_context_after_hit: bool = true
@export var damage_context_meta_name: StringName = &"last_damage_feedback_context"

var current_health: float
var _dead: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return

	var target := _damage_target_node()
	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	var context := _damage_feedback_context(target, amount, previous_health)
	_clear_consumed_damage_context(target)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount, current_health, max_health, context)
	_emit_damage_feedback(target, amount, context)
	
	if current_health <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if _dead:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return _dead


func _damage_target_node() -> Node:
	var parent := get_parent()
	return parent if parent != null else self


func _damage_feedback_context(target: Node, amount: float, previous_health: float) -> Dictionary:
	var context: Dictionary = {}
	if target != null and target.has_meta(damage_context_meta_name):
		var meta_value: Variant = target.get_meta(damage_context_meta_name)
		if meta_value is Dictionary:
			context = (meta_value as Dictionary).duplicate(true)
	elif has_meta(damage_context_meta_name):
		var component_meta: Variant = get_meta(damage_context_meta_name)
		if component_meta is Dictionary:
			context = (component_meta as Dictionary).duplicate(true)

	context["amount"] = amount
	context["previous_health"] = previous_health
	context["current_health"] = current_health
	context["max_health"] = max_health
	context["previous_health_ratio"] = _health_ratio(previous_health)
	context["health_ratio"] = _health_ratio(current_health)
	context["health_state"] = _health_state(current_health)
	context["previous_health_state"] = _health_state(previous_health)
	context["was_final_blow"] = current_health <= final_blow_threshold()
	if not context.has("damage_type"):
		context["damage_type"] = &"generic"
	return context


func final_blow_threshold() -> float:
	return 0.001


func _emit_damage_feedback(target: Node, amount: float, context: Dictionary) -> void:
	if not emit_damage_feedback:
		return
	if get_tree() == null:
		return
	var manager := get_tree().get_first_node_in_group("damage_feedback_manager")
	if manager != null and manager.has_method("show_damage"):
		manager.call("show_damage", target if target != null else self, amount, context)


func _clear_consumed_damage_context(target: Node) -> void:
	if not clear_feedback_context_after_hit:
		return
	if target != null and target.has_meta(damage_context_meta_name):
		target.remove_meta(damage_context_meta_name)
	if has_meta(damage_context_meta_name):
		remove_meta(damage_context_meta_name)


func _health_ratio(value: float) -> float:
	return clampf(value / maxf(max_health, 0.001), 0.0, 1.0)


func _health_state(value: float) -> StringName:
	var ratio := _health_ratio(value)
	if ratio <= 0.0:
		return &"destroyed"
	if ratio <= 0.25:
		return &"critical"
	if ratio <= 0.5:
		return &"fractured"
	if ratio <= 0.75:
		return &"damaged"
	return &"stable"
