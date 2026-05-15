extends Node2D
class_name MomentumCombatComponent

# ==========================================
# == SIGNALS ==
# ==========================================
signal momentum_state_changed(state: StringName, speed_ratio: float)
signal orbit_charge_changed(charge: float)
signal orbit_escape_boost_applied(boost: float, charge_spent: float)
signal near_miss_velocity_gained(target: Node, amount: float)
signal kinetic_overload_started(speed: float)
signal kinetic_overload_ended(speed: float)
signal kinetic_impact_dealt(target: Node, damage: float, speed: float)
signal momentum_projectile_prepared(projectile: Node, damage_multiplier: float, inherited_speed: float)
signal kinetic_shockwave_created(shockwave_data: Dictionary)

# ========================
# == EXPORT VARIABLES ==
# ========================
@export var enabled: bool = true
@export var debug_logging: bool = false

@export_group("Projectile Momentum")
@export var projectile_speed_damage_start: float = 650.0
@export var projectile_speed_damage_full: float = 1750.0
@export var projectile_max_damage_multiplier: float = 2.15
@export var projectile_velocity_inherit: float = 0.34
@export var projectile_max_inherited_speed: float = 520.0
@export var overload_projectile_damage_bonus: float = 0.35

@export_group("Orbit Assist")
@export var orbit_assist_enabled: bool = true
@export var orbit_assist_radius: float = 620.0
@export var orbit_min_distance: float = 95.0
@export var orbit_min_tangential_speed: float = 420.0
@export var orbit_charge_rate: float = 0.42
@export var orbit_charge_decay: float = 0.38
@export var orbit_escape_radial_speed: float = 190.0
@export var orbit_escape_min_charge: float = 0.34
@export var orbit_escape_boost_min: float = 160.0
@export var orbit_escape_boost_max: float = 540.0
@export var orbit_escape_cooldown: float = 0.85

@export_group("Near Miss")
@export var near_miss_enabled: bool = true
@export var near_miss_scan_interval: float = 0.08
@export var near_miss_radius: float = 82.0
@export var near_miss_inner_deadzone: float = 28.0
@export var near_miss_min_speed: float = 540.0
@export var near_miss_side_dot: float = 0.52
@export var near_miss_velocity_gain: float = 95.0
@export var near_miss_cooldown: float = 0.7

@export_group("Kinetic Impact")
@export var kinetic_impact_enabled: bool = true
@export var kinetic_impact_radius: float = 60.0
@export var kinetic_impact_min_speed: float = 760.0
@export var kinetic_impact_full_speed: float = 1850.0
@export var kinetic_impact_damage_min: float = 10.0
@export var kinetic_impact_damage_max: float = 46.0
@export var kinetic_impact_cooldown: float = 0.42
@export var kinetic_impact_player_boost: float = 58.0
@export var kinetic_impact_target_knockback: float = 380.0

@export_group("Momentum Shockwaves")
@export var shockwaves_enabled: bool = true
@export var shockwave_min_speed: float = 1180.0
@export var shockwave_radius: float = 210.0
@export var shockwave_force: float = 430.0
@export var shockwave_max_targets: int = 18
@export var shockwave_visual_enabled: bool = true

@export_group("Kinetic Overload")
@export var overload_enter_speed: float = 1450.0
@export var overload_exit_speed: float = 1120.0
@export var overload_speed_cap_bonus: float = 820.0
@export var overload_near_miss_bonus_multiplier: float = 1.35

@export_group("Momentum Preservation")
@export var speed_cap_bonus_decay: float = 640.0
@export var orbit_speed_cap_bonus: float = 420.0
@export var near_miss_speed_cap_bonus: float = 180.0
@export var impact_speed_cap_bonus: float = 260.0

# ========================
# == INTERNAL STATE ==
# ========================
var _player: CharacterBody2D = null
var _impact_area: Area2D = null

var _orbit_charge: float = 0.0
var _speed_cap_bonus: float = 0.0
var _near_miss_elapsed: float = 0.0
var _overload_active: bool = false
var _was_orbiting: bool = false

var _near_miss_cooldowns: Dictionary = {}
var _impact_cooldowns: Dictionary = {}

# ========================
# == LIFECYCLE ==
# ========================
func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	
	if _player == null:
		push_warning("MomentumCombatComponent: Parent is not a CharacterBody2D!")
		set_physics_process(false)
		return
	
	if debug_logging:
		print("MomentumCombatComponent successfully attached to Player.")
	
	_build_impact_area()
	_connect_player_signals()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(_player):
		return
	
	_update_orbit_assist(delta)
	_update_near_misses(delta)
	_update_kinetic_overload()
	_update_speed_cap(delta)


# ========================
# == CORE SYSTEMS ==
# ========================
func _update_speed_cap(delta: float) -> void:
	var current_speed := _player.velocity.length()
	var base_cap := float(_player.get("max_speed")) if _player.get("max_speed") != null else 800.0
	
	if _overload_active:
		_speed_cap_bonus = maxf(_speed_cap_bonus, overload_speed_cap_bonus)
	
	if _speed_cap_bonus > 0.0:
		_speed_cap_bonus = maxf(_speed_cap_bonus - speed_cap_bonus_decay * delta, 0.0)
	
	var desired_cap = maxf(base_cap + _speed_cap_bonus, current_speed + 50.0)
	_player.set("current_max_speed", desired_cap)


func _get_current_speed_cap_bonus() -> float:
	return _speed_cap_bonus


func prepare_projectile(projectile: Node, direction: Vector2) -> void:
	if projectile == null or not is_instance_valid(_player):
		return
	
	var speed := _player.velocity.length()
	var damage_multiplier := _get_projectile_damage_multiplier(speed)
	var inherited_speed := minf(
		maxf(_player.velocity.dot(direction), 0.0) * projectile_velocity_inherit,
		projectile_max_inherited_speed
	)
	
	projectile.set_meta(&"momentum_damage_multiplier", damage_multiplier)
	projectile.set_meta(&"momentum_source_speed", speed)
	
	if projectile.get("initial_speed") != null:
		projectile.set("initial_speed", float(projectile.get("initial_speed")) + inherited_speed)
	
	momentum_projectile_prepared.emit(projectile, damage_multiplier, inherited_speed)


# ========================
# == DEBUG INTERFACE (Required by Balance Overlay) ==
# ========================
func get_momentum_debug_state() -> Dictionary:
	var state_name := "overload" if _overload_active else ("orbit" if _was_orbiting else "stable")
	var current_speed := _player.velocity.length() if _player else 0.0
	
	return {
		"state": state_name,
		"damage_multiplier": _get_projectile_damage_multiplier(current_speed),
		"orbit_charge": _orbit_charge,
		"speed_cap_bonus": _speed_cap_bonus,
		"near_miss_cooldowns": _near_miss_cooldowns.size()
	}


# ========================
# == OTHER SYSTEMS (unchanged but cleaned) ==
# ========================
func _update_orbit_assist(delta: float) -> void:
	if not orbit_assist_enabled: 
		return
	
	var source = _player.get("closest_planet")
	var dist = _player.get("closest_dist")
	
	if is_instance_valid(source) and dist is float and dist < orbit_assist_radius and dist > orbit_min_distance:
		var velocity_len = _player.velocity.length()
		if velocity_len >= orbit_min_tangential_speed:
			_orbit_charge = clampf(_orbit_charge + orbit_charge_rate * delta, 0.0, 1.0)
			_speed_cap_bonus = maxf(_speed_cap_bonus, orbit_speed_cap_bonus * _orbit_charge)
			_was_orbiting = true
			orbit_charge_changed.emit(_orbit_charge)
			return
	
	_orbit_charge = maxf(_orbit_charge - orbit_charge_decay * delta, 0.0)
	_was_orbiting = false


func _update_near_misses(delta: float) -> void:
	_near_miss_elapsed += delta
	if _near_miss_elapsed < near_miss_scan_interval:
		return
	_near_miss_elapsed = 0.0
	
	var speed = _player.velocity.length()
	if speed < near_miss_min_speed:
		return
	
	var targets = get_tree().get_nodes_in_group("Objects_With_Gravity")
	for target in targets:
		if target == _player or not is_instance_valid(target):
			continue
		var target_2d := target as Node2D
		if target_2d == null or target_2d.is_queued_for_deletion():
			continue
		var dist = _player.global_position.distance_to(target_2d.global_position)
		if dist < near_miss_radius and dist > near_miss_inner_deadzone:
			var id = target_2d.get_instance_id()
			if not _near_miss_cooldowns.has(id) or Time.get_ticks_msec() > _near_miss_cooldowns[id]:
				_apply_near_miss(target_2d)
				_near_miss_cooldowns[id] = Time.get_ticks_msec() + (near_miss_cooldown * 1000)


func _apply_near_miss(target: Node) -> void:
	var boost = near_miss_velocity_gain
	_player.velocity += _player.velocity.normalized() * boost
	_speed_cap_bonus = maxf(_speed_cap_bonus, near_miss_speed_cap_bonus)
	near_miss_velocity_gained.emit(target, boost)


func _update_kinetic_overload() -> void:
	var speed = _player.velocity.length()
	if not _overload_active and speed >= overload_enter_speed:
		_overload_active = true
		kinetic_overload_started.emit(speed)
	elif _overload_active and speed <= overload_exit_speed:
		_overload_active = false
		kinetic_overload_ended.emit(speed)


func _get_projectile_damage_multiplier(speed: float) -> float:
	if speed < projectile_speed_damage_start:
		return 1.0
	var t = (speed - projectile_speed_damage_start) / (projectile_speed_damage_full - projectile_speed_damage_start)
	var mult = lerpf(1.0, projectile_max_damage_multiplier, clampf(t, 0.0, 1.0))
	if _overload_active:
		mult += overload_projectile_damage_bonus
	return mult


# ========================
# == HELPER FUNCTIONS ==
# ========================
func _build_impact_area() -> void:
	_impact_area = Area2D.new()
	_impact_area.name = "KineticImpactArea"
	_impact_area.collision_mask = 4294967295
	
	var coll = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = kinetic_impact_radius
	coll.shape = shape
	_impact_area.add_child(coll)
	add_child(_impact_area)
	_impact_area.body_entered.connect(_on_impact)


func _on_impact(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if not kinetic_impact_enabled or body == _player:
		return
	var speed = _player.velocity.length()
	if speed < kinetic_impact_min_speed:
		return
	
	var id = body.get_instance_id()
	if _impact_cooldowns.has(id) and Time.get_ticks_msec() < _impact_cooldowns[id]:
		return
	
	if body.has_method("take_damage"):
		var damage = lerpf(kinetic_impact_damage_min, kinetic_impact_damage_max, clampf(speed / kinetic_impact_full_speed, 0.0, 1.0))
		body.call("take_damage", damage)
		_speed_cap_bonus = maxf(_speed_cap_bonus, impact_speed_cap_bonus)
		_impact_cooldowns[id] = Time.get_ticks_msec() + (kinetic_impact_cooldown * 1000)
		kinetic_impact_dealt.emit(body, damage, speed)
		if shockwaves_enabled and speed >= shockwave_min_speed:
			_create_kinetic_shockwave(body, speed)


func _connect_player_signals() -> void:
	if _player.has_signal("slingshot_assist_applied"):
		_player.slingshot_assist_applied.connect(_on_slingshot)


func _on_slingshot(_source, _grav, _impulse, strength, _speed) -> void:
	_speed_cap_bonus = maxf(_speed_cap_bonus, strength * 0.5)

func _create_kinetic_shockwave(primary_target: Node, speed: float) -> void:
	if primary_target == null or not is_instance_valid(primary_target):
		return

	var center_node := primary_target as Node2D
	if center_node == null:
		center_node = _player
	var center := center_node.global_position
	var radius_squared := shockwave_radius * shockwave_radius
	var affected := 0
	var seen := {}

	for group_name in [&"enemies", &"wave_enemy", &"Projectiles", &"enemy_projectiles"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if affected >= shockwave_max_targets:
				break
			if candidate == _player or candidate == primary_target:
				continue
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
				continue

			var candidate_2d := candidate as Node2D
			if candidate_2d == null:
				continue

			var id := candidate_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var offset := candidate_2d.global_position - center
			var dist_squared := offset.length_squared()
			if dist_squared <= 0.001 or dist_squared > radius_squared:
				continue

			var falloff := 1.0 - sqrt(dist_squared) / shockwave_radius
			CombatStatus.add_velocity(candidate_2d, offset.normalized() * shockwave_force * falloff)
			affected += 1

	kinetic_shockwave_created.emit({
		"position": center,
		"radius": shockwave_radius,
		"speed": speed,
		"affected": affected,
	})

	if shockwave_visual_enabled:
		_spawn_shockwave_visual(center)

func _spawn_shockwave_visual(center: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := Line2D.new()
	ring.name = "KineticShockwave"
	ring.closed = true
	ring.antialiased = true
	ring.width = 5.0
	ring.default_color = Color(0.42, 0.95, 1.0, 0.78)
	ring.points = _circle_points(48, 1.0)
	ring.global_position = center
	ring.scale = Vector2.ONE * 18.0
	ring.z_index = 24
	root.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * shockwave_radius, 0.24)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
