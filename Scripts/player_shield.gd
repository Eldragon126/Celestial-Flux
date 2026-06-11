extends Area2D

signal shield_broken
signal shield_hit(amount: float, current_energy: float, max_capacity: float)
signal shield_restored(amount: float, current_energy: float, max_capacity: float)

# =====================================================
# == SHIELD SETTINGS
# =====================================================

@export var radius: float = 60.0

@export var max_capacity: float = 125.0
@export var starting_energy: float = -1.0

@export var recharge_delay: float = 2.35
@export var passive_regen_rate: float = 12.0
@export var break_recover_delay: float = 3.2

@export_group("Energy Recharge Link")
@export var require_energy_for_recharge: bool = true
@export_range(0.0, 1.0, 0.01) var minimum_energy_recharge_ratio: float = 0.16
@export var energy_cost_per_shield_point: float = 0.8
@export var broken_reboot_energy_multiplier: float = 1.35

# Shader parameter name
@export var shader_time_parameter: String = "time_multiplier"

# =====================================================
# == STATE
# =====================================================

var current_energy: float = 0.0
var is_broken := false

var _base_max_capacity: float = 0.0

var _recharge_delay_remaining := 0.0
var _break_remaining := 0.0

var _temporary_capacity_bonuses: Dictionary = {}
var _next_bonus_id := 1

var _gravity_distortion_time := 0.0
var _gravity_distortion_strength := 0.0

# Cached nodes
@onready var polygon: Polygon2D = $Polygon2D
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

# =====================================================
# == READY
# =====================================================

func _ready() -> void:
	_base_max_capacity = max_capacity

	current_energy = (
		max_capacity
		if starting_energy < 0.0
		else clampf(starting_energy, 0.0, max_capacity)
	)

	_build_hexagon()

	_update_active_state()

# =====================================================
# == PROCESS
# =====================================================

func _process(delta: float) -> void:
	_update_temporary_bonuses(delta)
	_recharge_shield(delta)
	_update_active_state()

# =====================================================
# == SHIELD DAMAGE
# =====================================================

func take_shield_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if is_broken or current_energy <= 0.0:
		return amount

	var absorbed := minf(amount, current_energy)

	current_energy -= absorbed
	_recharge_delay_remaining = recharge_delay

	shield_hit.emit(absorbed, current_energy, max_capacity)

	_play_hit_effect()

	if current_energy <= 0.0:
		_break_shield()

	return maxf(amount - absorbed, 0.0)

# =====================================================
# == REGEN
# =====================================================

func _recharge_shield(delta: float) -> void:
	if max_capacity <= 0.0:
		return

	# Broken cooldown
	if is_broken:
		_break_remaining -= delta

		if _break_remaining <= 0.0:
			is_broken = false
			var reboot_amount := _consume_recharge_energy(max_capacity * 0.18, broken_reboot_energy_multiplier)
			if reboot_amount <= 0.0:
				is_broken = true
				_break_remaining = 0.35
				return
			restore_shield(reboot_amount)

		return

	# Recharge delay
	if _recharge_delay_remaining > 0.0:
		_recharge_delay_remaining -= delta
		return

	# Already full
	if current_energy >= max_capacity:
		return

	var distortion_multiplier := 1.0

	if _gravity_distortion_time > 0.0:
		_gravity_distortion_time -= delta

		distortion_multiplier = clampf(
			1.0 - _gravity_distortion_strength,
			0.2,
			1.0
		)
	else:
		_gravity_distortion_strength = 0.0

	var requested_restore := passive_regen_rate * distortion_multiplier * delta
	var allowed_restore := _consume_recharge_energy(requested_restore, 1.0)
	if allowed_restore <= 0.0:
		return

	current_energy = minf(current_energy + allowed_restore, max_capacity)

# =====================================================
# == BREAK
# =====================================================

func _break_shield() -> void:
	if is_broken:
		return

	is_broken = true
	current_energy = 0.0
	_break_remaining = break_recover_delay

	shield_broken.emit()

	_flash_break()

# =====================================================
# == RESTORE
# =====================================================

func restore_shield(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var previous := current_energy

	if is_broken:
		is_broken = false
		_break_remaining = 0.0

	current_energy = minf(current_energy + amount, max_capacity)

	var restored := current_energy - previous

	if restored > 0.0:
		shield_restored.emit(
			restored,
			current_energy,
			max_capacity
		)

		_update_active_state()
		_play_hit_effect()

	return restored


func _consume_recharge_energy(shield_points: float, multiplier: float) -> float:
	if shield_points <= 0.0:
		return 0.0
	if not require_energy_for_recharge:
		return shield_points

	var energy := _energy_component()
	if energy == null:
		return shield_points

	var max_value: Variant = energy.get("max_energy")
	var current_value: Variant = energy.get("current_energy")
	if not (max_value is float or max_value is int) or not (current_value is float or current_value is int):
		return shield_points

	var max_energy := maxf(float(max_value), 1.0)
	var current := maxf(float(current_value), 0.0)
	if current / max_energy < minimum_energy_recharge_ratio:
		return 0.0

	var energy_cost := maxf(energy_cost_per_shield_point * maxf(multiplier, 0.0), 0.0)
	if energy_cost <= 0.0:
		return shield_points

	var affordable_points := current / energy_cost
	var restored_points := minf(shield_points, affordable_points)
	if restored_points <= 0.0:
		return 0.0

	var spend_amount := restored_points * energy_cost
	if energy.has_method("spend"):
		var spent: Variant = energy.call("spend", spend_amount)
		if (spent is float or spent is int) and float(spent) <= 0.0:
			return 0.0
	else:
		energy.set("current_energy", maxf(current - spend_amount, 0.0))

	return restored_points


func _energy_component() -> Node:
	var owner := get_parent()
	if owner == null:
		return null
	return owner.get_node_or_null("EnergyComponent")

# =====================================================
# == TEMPORARY BONUS
# =====================================================

func add_temporary_max_bonus(
	amount: float,
	duration: float,
	key: StringName = &""
) -> void:

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

# =====================================================
# == GRAVITY DISTORTION
# =====================================================

func apply_gravity_distortion(
	strength: float,
	duration: float
) -> void:

	_gravity_distortion_strength = maxf(
		_gravity_distortion_strength,
		clampf(strength, 0.0, 0.8)
	)

	_gravity_distortion_time = maxf(
		_gravity_distortion_time,
		duration
	)

	_play_shader_distortion()

# =====================================================
# == STATUS
# =====================================================

func is_shield_active() -> bool:
	return not is_broken and current_energy > 0.0

# =====================================================
# == VISUALS
# =====================================================

func _play_hit_effect() -> void:
	if not is_instance_valid(polygon):
		return

	var tween := create_tween()

	tween.tween_property(
		polygon,
		"self_modulate:a",
		1.0,
		0.08
	)

	tween.parallel().tween_property(
		polygon,
		"scale",
		Vector2(1.12, 1.12),
		0.08
	)

	tween.tween_property(
		polygon,
		"self_modulate:a",
		0.35,
		0.32
	)

	tween.parallel().tween_property(
		polygon,
		"scale",
		Vector2.ONE,
		0.32
	)

func _play_shader_distortion() -> void:
	if not is_instance_valid(polygon):
		return

	var mat := polygon.material as ShaderMaterial

	if mat == null:
		return

	# Verify shader parameter exists
	var parameter_exists = false

	for uniform_data in mat.shader.get_shader_uniform_list():
		if uniform_data.name == shader_time_parameter:
			parameter_exists = true
			break

	if not parameter_exists:
		return

	# Stop previous tweens cleanly
	var tween := create_tween()

	tween.tween_method(
		func(v):
			if is_instance_valid(mat):
				mat.set_shader_parameter(shader_time_parameter, v),
		1.0,
		5.0,
		0.08
	)

	tween.tween_method(
		func(v):
			if is_instance_valid(mat):
				mat.set_shader_parameter(shader_time_parameter, v),
		5.0,
		1.0,
		0.45
	)

func _flash_break() -> void:
	if not is_instance_valid(polygon):
		return

	var tween := create_tween()

	tween.tween_property(
		polygon,
		"self_modulate:a",
		1.0,
		0.05
	)

	tween.tween_property(
		polygon,
		"self_modulate:a",
		0.0,
		0.16
	)

# =====================================================
# == ACTIVE STATE
# =====================================================

func _update_active_state() -> void:
	var active := is_shield_active()

	visible = active
	monitoring = active
	set_deferred("monitorable", true)

	if is_instance_valid(polygon):
		polygon.visible = active

		var ratio := current_energy / maxf(max_capacity, 1.0)

		polygon.self_modulate.a = lerpf(
			0.18,
			0.55,
			ratio
		)

	if is_instance_valid(collision):
		collision.disabled = not active

# =====================================================
# == TEMP BONUS UPDATE
# =====================================================

func _update_temporary_bonuses(delta: float) -> void:
	var changed := false
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
	var total_bonus := 0.0

	for entry in _temporary_capacity_bonuses.values():
		total_bonus += float(entry["amount"])

	max_capacity = _base_max_capacity + total_bonus

	current_energy = minf(current_energy, max_capacity)

# =====================================================
# == BUILD SHAPE
# =====================================================

func _build_hexagon() -> void:
	if not is_instance_valid(polygon):
		return

	var points := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(6):
		var angle := i * PI / 3.0

		var pos := Vector2(
			cos(angle),
			sin(angle)
		)

		points.append(pos * radius)

		uvs.append(
			(pos + Vector2.ONE) / 2.0
		)

	polygon.polygon = points
	polygon.uv = uvs

	if is_instance_valid(collision):
		collision.polygon = points
