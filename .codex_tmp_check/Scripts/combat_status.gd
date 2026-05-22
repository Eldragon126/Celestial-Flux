extends Object
class_name CombatStatus

static func apply_local_slow(target: Node, multiplier: float, duration: float) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion() or duration <= 0.0:
		return

	var now = Time.get_ticks_msec() / 1000.0
	var until = maxf(float(target.get_meta("local_time_scale_until", 0.0)), now + duration)
	target.set_meta("local_time_scale", clampf(multiplier, 0.05, 1.0))
	target.set_meta("local_time_scale_until", until)

	var velocity: Variant = target.get("velocity")
	if velocity is Vector2:
		target.set("velocity", velocity * maxf(multiplier, 0.25))

	var linear_velocity: Variant = target.get("linear_velocity")
	if linear_velocity is Vector2:
		target.set("linear_velocity", linear_velocity * maxf(multiplier, 0.25))

	if target.has_method("on_local_slow_applied"):
		target.call("on_local_slow_applied", multiplier, duration)

static func get_time_scale(target: Node) -> float:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return 1.0

	var now = Time.get_ticks_msec() / 1000.0
	var until = float(target.get_meta("local_time_scale_until", 0.0))
	if now >= until:
		if target.has_meta("local_time_scale"):
			target.remove_meta("local_time_scale")
		return 1.0

	return clampf(float(target.get_meta("local_time_scale", 1.0)), 0.05, 1.0)

static func add_velocity(target: Node, impulse: Vector2) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return

	var velocity: Variant = target.get("velocity")
	if velocity is Vector2:
		target.set("velocity", velocity + impulse)
		return

	var linear_velocity: Variant = target.get("linear_velocity")
	if linear_velocity is Vector2:
		target.set("linear_velocity", linear_velocity + impulse)

static func damage_shield_only(target: Node, amount: float) -> float:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion() or amount <= 0.0:
		return 0.0

	if target.has_method("take_shield_damage"):
		return float(target.call("take_shield_damage", amount))

	var shield = target.get_node_or_null("Shield")
	if shield != null and shield.has_method("take_shield_damage"):
		return float(shield.call("take_shield_damage", amount))

	return amount
