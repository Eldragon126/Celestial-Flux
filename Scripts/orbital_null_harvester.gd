extends CharacterBody2D
class_name OrbitalNullHarvester

signal instability_absorbed(absorb_data: Dictionary)

@export var max_health: float = 96.0
@export var max_speed: float = 420.0
@export var acceleration: float = 560.0
@export var harvest_radius: float = 360.0
@export var shield_per_absorb: float = 16.0
@export var shield_max: float = 120.0
@export var scar_dampen_amount: float = 0.22
@export var resonance_dampen_amount: float = 0.28
@export var contact_damage: float = 18.0
@export var harvest_interval: float = 0.38

var _player: Node2D = null
var _health: HealthComponent = null
var _scar_manager: Node = null
var _resonance_manager: Node = null
var _shield := 0.0
var _harvest_elapsed := 999.0
var _ring: Line2D = null


func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_build_body()
	_build_health()
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	_resolve_managers()
	_harvest_elapsed += delta
	if _harvest_elapsed >= harvest_interval:
		_harvest_elapsed = 0.0
		_harvest_instability()
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return
	var target_position := _best_harvest_target()
	var direction := (target_position - global_position).normalized()
	velocity += direction * acceleration * delta * CombatStatus.get_time_scale(self)
	velocity = velocity.limit_length(max_speed)
	velocity *= pow(0.92, delta * 60.0)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 7.0, 0.0, 1.0))


func take_damage(amount: float) -> void:
	var remaining := amount
	if _shield > 0.0:
		var absorbed := minf(_shield, remaining)
		_shield -= absorbed
		remaining -= absorbed
	if remaining > 0.0 and _health != null:
		_health.take_damage(remaining)


func _resolve_managers() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	if _scar_manager == null or not is_instance_valid(_scar_manager):
		_scar_manager = root.find_child("GravityScarManager", true, false)
	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)


func _harvest_instability() -> void:
	var absorbed := 0
	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):
		var debris_2d := debris as Node2D
		if debris_2d == null or not is_instance_valid(debris_2d) or debris_2d.is_queued_for_deletion():
			continue
		if debris_2d.global_position.distance_squared_to(global_position) > harvest_radius * harvest_radius:
			continue
		debris_2d.queue_free()
		absorbed += 1

	if _scar_manager != null and _scar_manager.has_method("dampen_scars_in_radius"):
		absorbed += int(_scar_manager.call("dampen_scars_in_radius", global_position, harvest_radius, scar_dampen_amount))
	if _resonance_manager != null and _resonance_manager.has_method("dampen_zones_in_radius"):
		absorbed += int(_resonance_manager.call("dampen_zones_in_radius", global_position, harvest_radius, resonance_dampen_amount))

	if absorbed <= 0:
		return
	_shield = minf(_shield + shield_per_absorb * float(absorbed), shield_max)
	instability_absorbed.emit({
		"position": global_position,
		"absorbed": absorbed,
		"shield": _shield,
		"radius": harvest_radius,
	})


func _best_harvest_target() -> Vector2:
	var best := _player.global_position if _player != null and is_instance_valid(_player) else global_position
	var best_distance := INF
	for debris in get_tree().get_nodes_in_group("law_gravity_debris"):
		var debris_2d := debris as Node2D
		if debris_2d == null or not is_instance_valid(debris_2d):
			continue
		var distance := debris_2d.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = debris_2d.global_position
	if _scar_manager != null and _scar_manager.has_method("get_active_gravity_scars"):
		var scars_value: Variant = _scar_manager.call("get_active_gravity_scars")
		if typeof(scars_value) == TYPE_ARRAY:
			for scar_value in scars_value:
				if typeof(scar_value) != TYPE_DICTIONARY:
					continue
				var scar: Dictionary = scar_value
				var position: Vector2 = scar.get("position", best)
				var distance := position.distance_squared_to(global_position)
				if distance < best_distance:
					best_distance = distance
					best = position
	return best


func _build_body() -> void:
	var core := Polygon2D.new()
	core.name = "NullHarvesterCore"
	core.color = Color(0.86, 0.08, 0.18, 1.0)
	core.polygon = PackedVector2Array([Vector2(42, 0), Vector2(16, 30), Vector2(-30, 22), Vector2(-44, 0), Vector2(-30, -22), Vector2(16, -30)])
	add_child(core)
	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = core.polygon
	add_child(collision)
	_ring = Line2D.new()
	_ring.name = "NullHarvestRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.2
	_ring.points = _circle_points(48, harvest_radius)
	_ring.default_color = Color(0.16, 0.92, 1.0, 0.22)
	add_child(_ring)
	var area := Area2D.new()
	area.name = "AttackArea"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_attack_area_body_entered)
	add_child(area)


func _build_health() -> void:
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)


func _update_visuals(delta: float) -> void:
	if _ring == null:
		return
	_ring.rotation -= delta * (1.0 + _shield / maxf(shield_max, 1.0))
	_ring.default_color = Color(0.16, 0.92, 1.0, 0.18 + 0.42 * (_shield / maxf(shield_max, 1.0)))


func _on_attack_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)


func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.16, true)
	queue_free()


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
