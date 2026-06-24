extends StaticBody2D
class_name CampaignPlanetTurret

signal turret_defeated(turret: CampaignPlanetTurret, reward: int)

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

@export var hostile: bool = true
@export var max_health: float = 120.0
@export var fire_interval: float = 1.45
@export var projectile_speed: float = 780.0
@export var projectile_homing: bool = false
@export var range: float = 1250.0
@export var reward_credits: int = 28
@export var target_mother_weight: float = 0.65
@export var ring_radius: float = 42.0
@export var collision_radius: float = 46.0
@export var barrel_length: float = 58.0
@export var hostile_color: Color = Color(1.0, 0.3, 0.14, 0.72)
@export var friendly_color: Color = Color(0.32, 1.0, 0.72, 0.58)
@export var damaged_color: Color = Color(1.0, 0.18, 0.08, 0.9)
@export var barrel_flash_color: Color = Color(1.0, 0.58, 0.26, 0.78)

var current_health: float = 120.0
var faction_id: StringName = &"freehold"

var _elapsed: float = 0.0
var _ring: Line2D = null
var _barrel: Line2D = null
var _collision: CollisionShape2D = null
var _defeated: bool = false


func configure(new_faction: StringName, starts_hostile: bool) -> void:
	faction_id = new_faction
	hostile = starts_hostile
	_update_visual_state()


func _ready() -> void:
	add_to_group("campaign_planet_turret")
	if hostile:
		add_to_group("enemies")
		add_to_group("wave_enemy")
		if RuntimeRegistry != null:
			RuntimeRegistry.register_node(self, &"enemies")
			RuntimeRegistry.register_node(self, &"wave_enemy")
	current_health = max_health
	_ring = get_node_or_null("TurretRing") as Line2D
	_barrel = get_node_or_null("TurretBarrel") as Line2D
	_collision = get_node_or_null("TurretCollision") as CollisionShape2D
	_build_collision()
	_build_visuals()
	_update_visual_state()


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
		RuntimeRegistry.unregister_node(self, &"wave_enemy")


func _process(delta: float) -> void:
	if _defeated:
		return
	_elapsed += delta * CombatStatus.get_time_scale(self)
	if not hostile:
		return
	var target := _select_target()
	if target == null:
		return
	var to_target := target.global_position - global_position
	rotation = lerp_angle(rotation, to_target.angle(), clampf(delta * 6.0, 0.0, 1.0))
	if _elapsed >= fire_interval:
		_elapsed = 0.0
		_fire_at(target)


func set_hostile(value: bool) -> void:
	hostile = value
	if hostile:
		add_to_group("enemies")
		add_to_group("wave_enemy")
		if RuntimeRegistry != null and is_inside_tree():
			RuntimeRegistry.register_node(self, &"enemies")
			RuntimeRegistry.register_node(self, &"wave_enemy")
	else:
		remove_from_group("enemies")
		remove_from_group("wave_enemy")
		if RuntimeRegistry != null:
			RuntimeRegistry.unregister_node(self, &"enemies")
			RuntimeRegistry.unregister_node(self, &"wave_enemy")
	_update_visual_state()


func take_damage(amount: float) -> void:
	if _defeated or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	set_hostile(true)
	if current_health <= 0.0:
		_defeated = true
		turret_defeated.emit(self, reward_credits)
		queue_free()
	else:
		_update_visual_state()


func _select_target() -> Node2D:
	var candidates: Array[Node2D] = []
	var mother := get_tree().get_first_node_in_group("campaign_mother_planet") as Node2D
	for player in MultiplayerTargeting.live_players(get_tree()):
		candidates.append(player)
	if mother != null and is_instance_valid(mother):
		candidates.append(mother)
	for escort_value in get_tree().get_nodes_in_group("campaign_escort"):
		var escort := escort_value as Node2D
		if escort != null and is_instance_valid(escort):
			candidates.append(escort)
	var best: Node2D = null
	var best_score := range * range
	for candidate in candidates:
		var distance := global_position.distance_squared_to(candidate.global_position)
		if candidate.is_in_group("campaign_mother_planet"):
			distance *= target_mother_weight
		if distance < best_score:
			best_score = distance
			best = candidate
	return best


func _fire_at(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var direction := (target.global_position - global_position).normalized()
	if not BulletManager.can_spawn_bullet():
		if target.has_method("take_damage"):
			target.call("take_damage", maxf(projectile_speed / 100.0, 1.0))
		if _barrel != null:
			_barrel.default_color = Color(barrel_flash_color.r, barrel_flash_color.g, barrel_flash_color.b, 0.48)
		return
	var projectile := ENEMY_BULLET_SCENE.instantiate()
	var projectile_2d := projectile as Node2D
	if projectile_2d == null:
		return
	projectile_2d.global_position = global_position + direction * 42.0
	projectile_2d.global_rotation = direction.angle()
	if projectile.get("is_homing") != null:
		projectile.set("is_homing", projectile_homing)
	if projectile.has_method("configure_launch"):
		projectile.call("configure_launch", direction, projectile_speed, self)
	get_tree().current_scene.call_deferred("add_child", projectile)
	if _barrel != null:
		_barrel.default_color = barrel_flash_color


func _build_visuals() -> void:
	if _ring == null:
		_ring = Line2D.new()
		_ring.name = "TurretRing"
		_ring.closed = true
		_ring.antialiased = true
		_ring.width = 2.4
		add_child(_ring)
	_ring.points = _circle_points(ring_radius, 36)
	if _barrel == null:
		_barrel = Line2D.new()
		_barrel.name = "TurretBarrel"
		_barrel.width = 3.2
		add_child(_barrel)
	_barrel.points = PackedVector2Array([Vector2.ZERO, Vector2(barrel_length, 0.0)])


func _build_collision() -> void:
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "TurretCollision"
		add_child(_collision)
	if _collision.shape == null:
		_collision.shape = CircleShape2D.new()
	if _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = collision_radius


func _update_visual_state() -> void:
	var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var color := hostile_color if hostile else friendly_color
	if _ring != null:
		_ring.default_color = color.lerp(damaged_color, 1.0 - health_ratio)
	if _barrel != null:
		_barrel.default_color = Color(color.r, color.g, color.b, 0.72)


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
