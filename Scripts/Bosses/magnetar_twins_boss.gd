extends PhaseBoss

# --- Scenes ---
const ORBITER_SCENE: PackedScene = preload("res://Nodes/orbiter_drone.tscn")
const SEEKER_SCENE: PackedScene = preload("res://Nodes/seeker_fragment.tscn")
const ENEMY_BULLET_SCENE: PackedScene = preload("res://Nodes/enemy_bullet.tscn")

# --- Constants & Colors ---
const COLOR_LOBE_NORTH := Color(0.26, 0.86, 1.0, 0.52)
const COLOR_LOBE_SOUTH := Color(1.0, 0.18, 0.72, 0.52)
const COLOR_HULL := Color(0.08, 0.06, 0.18, 1.0)
const CORE_COLORS: Array[Color] = [
	Color(0.96, 0.25, 0.92, 1.0), # Phase 1
	Color(0.25, 0.86, 1.0, 1.0),  # Phase 2
	Color(1.0, 0.28, 0.18, 1.0)   # Phase 3
]

@export_group("Movement & Orbit")
@export var orbit_distance: float = 640.0
@export var move_speed: float = 500.0

@export_group("Magnetic Lobes")
@export var lobe_radius: float = 165.0
@export var lobe_force: float = 1320.0
@export var polarity_window_duration: float = 2.6

@export_group("Combat")
@export var projectile_speed: float = 900.0

# --- Private Variables ---
var _angle: float = 0.0
var _polarity_sign: float = 1.0
var _polarity_timer: float = 0.0

var _core: Polygon2D
var _north_lobe: Polygon2D
var _south_lobe: Polygon2D

func _ready() -> void:
	max_health = maxf(max_health, 980.0)
	mass = 320000.0
	attack_interval = 2.15
	_build_body()
	super._ready()

func _boss_physics(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_angle += delta * (0.45 + current_phase * 0.14)
	_update_polarity_window(delta)
	
	var target := player.global_position + Vector2(cos(_angle), sin(_angle * 0.7)) * orbit_distance
	var speed_limit = move_speed + 30.0 * current_phase
	
	velocity = velocity.lerp((target - global_position).limit_length(speed_limit), clampf(delta * 1.9, 0.0, 1.0))
	move_and_slide()
	
	_apply_lobe_forces(delta)
	_update_lobes()

func _run_attack_pattern() -> void:
	_pulse_core()
	await get_tree().create_timer(0.22).timeout

	if is_queued_for_deletion() or not is_instance_valid(get_parent()):
		return

	match current_phase:
		1:
			_fire_paired_shots()
		2:
			_fire_paired_shots()
			_spawn_orbiter_pair()
		_:
			_magnetic_inversion()
			_spawn_seekers()

func on_damage_taken(_amount: float) -> void:
	_angle += 0.22

func _on_enter_phase(phase: int) -> void:
	if is_instance_valid(attack_timer):
		attack_timer.wait_time = maxf(1.05, attack_interval - 0.35 * float(phase - 1))
	
	if is_instance_valid(_core):
		var color_index := clampi(phase - 1, 0, CORE_COLORS.size() - 1)
		_core.color = CORE_COLORS[color_index]

func _build_body() -> void:
	_north_lobe = _get_or_make_lobe("NorthMagnetarLobe", COLOR_LOBE_NORTH)
	_south_lobe = _get_or_make_lobe("SouthMagnetarLobe", COLOR_LOBE_SOUTH)

	var hull := get_node_or_null("MagnetarHull") as Polygon2D
	if not is_instance_valid(hull):
		hull = Polygon2D.new()
		hull.name = "MagnetarHull"
		hull.color = COLOR_HULL
		add_child(hull)
	if hull.polygon.is_empty():
		hull.polygon = _circle_points(94.0, 10)

	_core = get_node_or_null("MagnetarCore") as Polygon2D
	if not is_instance_valid(_core):
		_core = Polygon2D.new()
		_core.name = "MagnetarCore"
		_core.color = CORE_COLORS[0]
		add_child(_core)
	if _core.polygon.is_empty():
		_core.polygon = _circle_points(42.0, 8)

	if not has_node("CollisionPolygon2D"):
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = hull.polygon
		add_child(collision)

func _get_or_make_lobe(node_name: String, color: Color) -> Polygon2D:
	var lobe := get_node_or_null(node_name) as Polygon2D
	if not is_instance_valid(lobe):
		lobe = Polygon2D.new()
		lobe.name = node_name
		lobe.z_index = -2
		lobe.color = color
		add_child(lobe)
	if lobe.polygon.is_empty():
		lobe.polygon = _circle_points(46.0, 24)
	return lobe

func _apply_lobe_forces(delta: float) -> void:
	if not is_instance_valid(player) or not "velocity" in player:
		return

	for lobe: Polygon2D in [_north_lobe, _south_lobe]:
		if not is_instance_valid(lobe):
			continue
			
		var offset := lobe.global_position - player.global_position
		var distance := offset.length()
		
		if distance <= 1.0 or distance > 540.0:
			continue
			
		var player_velocity: Vector2 = player.velocity
		var polarity := _polarity_sign if lobe == _north_lobe else -_polarity_sign
		var force_vector := offset.normalized() * lobe_force * polarity * delta * 540.0 / maxf(distance, 90.0)
		
		player.velocity = player_velocity + force_vector

func _update_lobes() -> void:
	var lobe_axis := Vector2.RIGHT.rotated(_angle)
	if is_instance_valid(_north_lobe):
		_north_lobe.position = lobe_axis * lobe_radius
		_north_lobe.rotation = _angle
	if is_instance_valid(_south_lobe):
		_south_lobe.position = -lobe_axis * lobe_radius
		_south_lobe.rotation = _angle + PI

func _fire_paired_shots() -> void:
	var parent := get_parent()
	if not is_instance_valid(player) or not is_instance_valid(parent):
		return

	var aim := (player.global_position - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT.rotated(rotation)

	if _polarity_sign > 0.0:
		_spawn_bullet(aim, projectile_speed * 0.94, parent)
	else:
		_spawn_bullet(aim.rotated(-0.12), projectile_speed * 0.88, parent)

func _spawn_bullet(direction: Vector2, speed: float, parent: Node) -> void:
	if not BulletManager.can_spawn_bullet():
		return

	var bullet: Node2D = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position + direction * 118.0
	bullet.global_rotation = direction.angle()
	
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, speed, self)
	elif "initial_speed" in bullet:
		bullet.set("initial_speed", speed)
		
	parent.call_deferred("add_child", bullet)

func _spawn_orbiter_pair() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
		
	for i in range(2):
		var orbiter: Node2D = ORBITER_SCENE.instantiate()
		orbiter.global_position = global_position + Vector2.RIGHT.rotated(_angle + PI * float(i)) * 210.0
		orbiter.add_to_group("wave_enemy")
		parent.call_deferred("add_child", orbiter)

func _spawn_seekers() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
		
	for i in range(3):
		var seeker: Node2D = SEEKER_SCENE.instantiate()
		seeker.global_position = global_position + Vector2.RIGHT.rotated(_angle + TAU * float(i) / 3.0) * 150.0
		seeker.add_to_group("wave_enemy")
		parent.call_deferred("add_child", seeker)

func _magnetic_inversion() -> void:
	if not is_instance_valid(player):
		return
		
	_polarity_sign *= -1.0
	_polarity_timer = 0.0
	
	var offset := player.global_position - global_position
	if offset.length() < 760.0 and "velocity" in player:
		player.velocity += offset.normalized() * 460.0
		if player.has_method("apply_shield_disruption"):
			player.call("apply_shield_disruption", 0.38, 0.75)

func _update_polarity_window(delta: float) -> void:
	_polarity_timer += delta
	if _polarity_timer >= maxf(polarity_window_duration, 0.4):
		_polarity_timer = 0.0
		_polarity_sign *= -1.0
		_pulse_core()

	if is_instance_valid(_north_lobe):
		_north_lobe.color = COLOR_LOBE_NORTH if _polarity_sign > 0.0 else COLOR_LOBE_SOUTH
	if is_instance_valid(_south_lobe):
		_south_lobe.color = COLOR_LOBE_SOUTH if _polarity_sign > 0.0 else COLOR_LOBE_NORTH

func _pulse_core() -> void:
	if not is_instance_valid(_core):
		return
		
	var tween := create_tween()
	_core.scale = Vector2.ONE
	tween.tween_property(_core, "scale", Vector2(1.28, 1.28), 0.1)
	tween.tween_property(_core, "scale", Vector2.ONE, 0.2)

func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
