extends CharacterBody2D

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

@onready var polygon_2d = $Polygon2D
@onready var collision_polygon_2d = $CollisionPolygon2D

@export var gravity_constant: float = 200.0
@export var max_speed: float = 500.0
@export var min_grav_dist: float = 50.0
@export var drag: float = 0.5
@export var gravity_refresh_interval: float = 0.45
@export var max_gravity_sources: int = 4
@export var planet_escape_clearance: float = 52.0
@export var planet_escape_force: float = 620.0
@export var planet_escape_spin: float = 220.0
@export var offscreen_simulation_distance: float = 2400.0
@export var offscreen_simulation_interval: float = 0.1

var Player: Node = null
var planets: Array[Node2D] = []
var _gravity_refresh_elapsed = 0.0
var _simulation_accumulator: float = 0.0

func _ready() -> void:
	Player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_refresh_planets()

func _process(delta: float) -> void:
	delta *= CombatStatus.get_time_scale(self)
	if _should_use_coarse_simulation():
		_simulation_accumulator += delta
		if _simulation_accumulator < maxf(offscreen_simulation_interval, 0.016):
			return
		delta = _simulation_accumulator
		_simulation_accumulator = 0.0
	else:
		_simulation_accumulator = 0.0

	_gravity_refresh_elapsed += delta
	if _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_planets()

	var grav_accel: Vector2 = Vector2.ZERO

	# Safe loop through planets
	for planet in planets:
		if not is_instance_valid(planet):
			continue

		var to_planet: float = global_position.distance_to(planet.global_position)

		if to_planet < min_grav_dist:
			to_planet = min_grav_dist

		var dir: Vector2 = (planet.global_position - global_position).normalized()

		var mass_value: Variant = planet.get("mass")
		var mass_type = typeof(mass_value)
		var p_mass = float(mass_value) if mass_type == TYPE_FLOAT or mass_type == TYPE_INT else 100.0

		var strength: float = gravity_constant * p_mass / (to_planet * to_planet)
		grav_accel += dir * strength

	# Player tracking
	if Player == null or not is_instance_valid(Player):
		Player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	else:
		var direction_to_player: Vector2 = (Player.global_position - global_position).normalized()
		var distance_to_player: float = global_position.distance_to(Player.global_position)

		if distance_to_player < 300:
			velocity += direction_to_player * 100
			velocity = velocity.limit_length(200)
		else:
			velocity += direction_to_player * 500

		rotation = (global_position - Player.global_position).angle()

	# Apply physics
	velocity += grav_accel * delta
	velocity += _planet_escape_velocity(delta)
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)

	move_and_slide()

# ========================
# == SHOOTING ==
# ========================

func _on_shoot_animation_animation_started(anim_name: StringName) -> void:
	if anim_name == "Blast":
		if _should_hold_offscreen_fire():
			return
		# Check global bullet cap before spawning
		if not BulletManager.can_spawn_bullet():
			return

		var projectile := ENEMY_BULLET_SCENE.instantiate()

		var force_of_impulse := 900.0

		if Player != null and is_instance_valid(Player):
			var dir: Vector2 = (Player.global_position - global_position).normalized()
			if projectile.has_method("configure_launch"):
				projectile.call("configure_launch", dir, force_of_impulse, self)
			elif projectile.get("initial_speed") != null:
				projectile.set("initial_speed", force_of_impulse)
			projectile.global_rotation = dir.angle()
		else:
			Player = MultiplayerTargeting.nearest_player(global_position, get_tree())

		projectile.global_position = $ShootGPU.global_position

		# Use deferred to avoid physics issues
		get_parent().add_child.call_deferred(projectile)

func _on_shoot_animation_animation_finished(anim_name: StringName) -> void:
	$ShootAnimation.play("Blast")

# ========================
# == DAMAGE SYSTEM ==
# ========================

func take_damage(amount: float) -> void:
	if has_node("HealthComponent"):
		$HealthComponent.take_damage(amount)

func _on_health_component_died() -> void:
	queue_free()

# ========================
# == PLAYER COLLISION ==
# ========================

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(20.0)

		var knockback_dir: Vector2 = (global_position - body.global_position).normalized()

		velocity += knockback_dir * 500

		CombatStatus.add_velocity(body, -knockback_dir * 400)

func _refresh_planets() -> void:
	_gravity_refresh_elapsed = 0.0
	planets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			global_position,
			planets,
			max_gravity_sources,
			0.0,
			self
		)
		return

	var seen: Dictionary = {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == null or not is_instance_valid(source):
				continue
			var source_2d := source as Node2D
			if source_2d == null or source_2d == self or source_2d.is_queued_for_deletion():
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			planets.append(source_2d)


func _should_use_coarse_simulation() -> bool:
	if offscreen_simulation_distance <= 0.0:
		return false
	var player_2d := Player as Node2D
	if player_2d == null or not is_instance_valid(player_2d):
		return false
	return global_position.distance_squared_to(player_2d.global_position) > offscreen_simulation_distance * offscreen_simulation_distance


func _should_hold_offscreen_fire() -> bool:
	var player_2d := Player as Node2D
	if player_2d == null or not is_instance_valid(player_2d):
		return false
	var fire_distance := offscreen_simulation_distance * 1.25
	return global_position.distance_squared_to(player_2d.global_position) > fire_distance * fire_distance


func _planet_escape_velocity(delta: float) -> Vector2:
	var impulse := Vector2.ZERO
	for planet in planets:
		if planet == null or not is_instance_valid(planet):
			continue
		var radius := _planet_radius(planet)
		var escape_radius := radius + planet_escape_clearance
		var offset := global_position - planet.global_position
		var distance := maxf(offset.length(), 0.001)
		if distance >= escape_radius:
			continue
		var outward := offset / distance
		var tangent := outward.orthogonal()
		if Player != null and is_instance_valid(Player):
			var player_2d := Player as Node2D
			if player_2d != null and tangent.dot(player_2d.global_position - global_position) < 0.0:
				tangent = -tangent
		var pressure := 1.0 - clampf(distance / escape_radius, 0.0, 1.0)
		set_meta(&"planet_escape_blastoff", pressure)
		impulse += (outward * planet_escape_force + tangent * planet_escape_spin) * pressure * delta
	return impulse


func _planet_radius(planet: Node2D) -> float:
	var radius_value: Variant = planet.get("radius")
	if radius_value is float or radius_value is int:
		return maxf(float(radius_value), 24.0)
	var collision := planet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return maxf((collision.shape as CircleShape2D).radius, 24.0)
	return 150.0
