extends Area2D

signal shield_broken
signal shield_hit(amount: float, current_energy: float, max_capacity: float)
signal shield_restored(amount: float, current_energy: float, max_capacity: float)

@export var radius: float = 60.0
@export var max_capacity: float = 125.0
@export var starting_energy: float = -1.0
@export var recharge_delay: float = 1.45
@export var passive_regen_rate: float = 24.0
@export var break_recover_delay: float = 2.45

var current_energy: float = 0.0
var is_broken = false

var _base_max_capacity: float = 0.0
var _recharge_delay_remaining = 0.0
var _break_remaining = 0.0
var _temporary_capacity_bonuses: Dictionary = {}
var _next_bonus_id = 1
var _gravity_distortion_time = 0.0
var _gravity_distortion_strength = 0.0

func _ready():
	_base_max_capacity = max_capacity
	current_energy = max_capacity if starting_energy < 0.0 else clampf(starting_energy, 0.0, max_capacity)
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	for i in range(6):
		var angle = i * PI / 3 
		var pos = Vector2(cos(angle), sin(angle))
		points.append(pos * radius)
		
		# UVs usually range from 0 to 1. 
		# This maps the circle math to a 0.0 - 1.0 square range.
		uvs.append((pos + Vector2.ONE) / 2.0)
	
	$Polygon2D.polygon = points
	$Polygon2D.uv = uvs # This tells the shader where to draw what

	var collision = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision != null:
		collision.polygon = points

	_update_active_state()

func _process(delta: float) -> void:
	_update_temporary_bonuses(delta)
	recharge_shield(delta)
	_update_active_state()

func take_shield_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	if is_broken or current_energy <= 0.0:
		return amount

	var absorbed = minf(amount, current_energy)
	current_energy -= absorbed
	_recharge_delay_remaining = recharge_delay

	shield_hit.emit(absorbed, current_energy, max_capacity)
	hit()

	if current_energy <= 0.0:
		break_shield()

	return maxf(amount - absorbed, 0.0)

func recharge_shield(delta: float) -> void:
	if max_capacity <= 0.0:
		return

	if is_broken:
		_break_remaining -= delta
		if _break_remaining <= 0.0:
			is_broken = false
			restore_shield(max_capacity * 0.24)
		return

	if _recharge_delay_remaining > 0.0:
		_recharge_delay_remaining -= delta
		return

	if current_energy >= max_capacity:
		return

	var distortion_multiplier = 1.0
	if _gravity_distortion_time > 0.0:
		_gravity_distortion_time -= delta
		distortion_multiplier = clampf(1.0 - _gravity_distortion_strength, 0.2, 1.0)
	else:
		_gravity_distortion_strength = 0.0

	current_energy = minf(current_energy + passive_regen_rate * distortion_multiplier * delta, max_capacity)

func break_shield() -> void:
	if is_broken:
		return

	is_broken = true
	current_energy = 0.0
	_break_remaining = break_recover_delay
	shield_broken.emit()
	_flash_break()

func restore_shield(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var previous = current_energy
	if is_broken:
		is_broken = false
		_break_remaining = 0.0

	current_energy = minf(current_energy + amount, max_capacity)
	var restored = current_energy - previous

	if restored > 0.0:
		shield_restored.emit(restored, current_energy, max_capacity)
		_update_active_state()
		hit()

	return restored

func add_temporary_max_bonus(amount: float, duration: float, key: StringName = &"") -> void:
	if amount <= 0.0 or duration <= 0.0:
		return

	var id: Variant = key
	if String(key).is_empty():
		id = _next_bonus_id
		_next_bonus_id += 1

	_temporary_capacity_bonuses[id] = {
		"amount": amount,
		"remaining": duration,
	}
	_recalculate_max_capacity()
	restore_shield(amount)

func apply_gravity_distortion(strength: float, duration: float) -> void:
	_gravity_distortion_strength = maxf(_gravity_distortion_strength, clampf(strength, 0.0, 0.8))
	_gravity_distortion_time = maxf(_gravity_distortion_time, duration)
	on_shield_hit()

func is_shield_active() -> bool:
	return not is_broken and current_energy > 0.0

func hit():
	if not is_instance_valid(get_node_or_null("Polygon2D")):
		return

	var tween = create_tween()
	# Pulse the shield opacity and scale slightly
	tween.tween_property($Polygon2D, "self_modulate:a", 1.0, 0.1)
	tween.parallel().tween_property($Polygon2D, "scale", Vector2(1.1, 1.1), 0.1)
	
	# Return to normal
	tween.tween_property($Polygon2D, "self_modulate:a", 0.3, 0.4)
	tween.parallel().tween_property($Polygon2D, "scale", Vector2(1.0, 1.0), 0.4)
	
func on_shield_hit():
	var mat = $Polygon2D.material as ShaderMaterial
	if mat == null:
		return

	var tween = create_tween()
	
	# Briefly spike the pattern scale or brightness
	tween.tween_property(mat, "shader_parameter/time_multiplier", 5.0, 0.1)
	tween.tween_property(mat, "shader_parameter/time_multiplier", 1.0, 0.5)

func _update_active_state() -> void:
	var active = is_shield_active()
	visible = active
	monitoring = active
	monitorable = active

	var poly = get_node_or_null("Polygon2D") as Polygon2D
	if poly != null:
		poly.visible = active
		poly.self_modulate.a = lerpf(0.18, 0.55, current_energy / maxf(max_capacity, 1.0))

	var collision = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision != null:
		collision.disabled = not active

func _update_temporary_bonuses(delta: float) -> void:
	var changed = false
	var expired: Array = []

	for id in _temporary_capacity_bonuses.keys():
		var entry: Dictionary = _temporary_capacity_bonuses[id]
		entry["remaining"] = float(entry["remaining"]) - delta
		_temporary_capacity_bonuses[id] = entry
		if float(entry["remaining"]) <= 0.0:
			expired.append(id)

	for id in expired:
		_temporary_capacity_bonuses.erase(id)
		changed = true

	if changed:
		_recalculate_max_capacity()

func _recalculate_max_capacity() -> void:
	var total_bonus = 0.0
	for entry in _temporary_capacity_bonuses.values():
		total_bonus += float(entry["amount"])

	max_capacity = _base_max_capacity + total_bonus
	current_energy = minf(current_energy, max_capacity)

func _flash_break() -> void:
	var poly = get_node_or_null("Polygon2D") as Polygon2D
	if poly == null:
		return

	var tween = create_tween()
	tween.tween_property(poly, "self_modulate:a", 1.0, 0.05)
	tween.tween_property(poly, "self_modulate:a", 0.0, 0.16)
