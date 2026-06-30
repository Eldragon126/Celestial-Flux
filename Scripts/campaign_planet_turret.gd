extends StaticBody2D
class_name CampaignPlanetTurret

signal turret_defeated(turret: CampaignPlanetTurret, reward: int)

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

@export var hostile: bool = true
@export var max_health: float = 120.0
@export var fire_interval: float = 1.45
@export var projectile_speed: float = 780.0
@export var projectile_homing: bool = false
@export var use_global_bullet_budget: bool = true
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
@export_group("Visual Polish")
@export var base_radius: float = 55.0
@export var core_radius: float = 18.0
@export var shield_radius: float = 62.0
@export var charge_ring_radius: float = 31.0
@export var muzzle_flash_length: float = 26.0
@export_range(0.0, 1.0, 0.01) var shield_alpha: float = 0.16
@export_range(0.0, 1.0, 0.01) var charge_alpha: float = 0.34
@export var base_color: Color = Color(0.05, 0.11, 0.16, 0.82)
@export var core_color: Color = Color(1.0, 0.72, 0.38, 0.88)
@export var friendly_core_color: Color = Color(0.54, 1.0, 0.78, 0.82)

var current_health: float = 120.0
var faction_id: StringName = &"freehold"

var _elapsed: float = 0.0
var _flash_alpha: float = 0.0
var _base: Polygon2D = null
var _core: Polygon2D = null
var _ring: Line2D = null
var _barrel: Line2D = null
var _shield_ring: Line2D = null
var _charge_ring: Line2D = null
var _muzzle_flash: Line2D = null
var _collision: CollisionShape2D = null
var _defeated: bool = false
var _candidate_targets: Array[Node2D] = []
var _target_query_buffer: Array[Node2D] = []


func configure(new_faction: StringName, starts_hostile: bool) -> void:
	faction_id = new_faction
	hostile = starts_hostile
	_update_visual_state()


func _ready() -> void:
	add_to_group("campaign_planet_turret")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"campaign_planet_turret")
	if hostile:
		add_to_group("enemies")
		add_to_group("wave_enemy")
		if RuntimeRegistry != null:
			RuntimeRegistry.register_node(self, &"enemies")
			RuntimeRegistry.register_node(self, &"wave_enemy")
	current_health = max_health
	_base = get_node_or_null("TurretBase") as Polygon2D
	_core = get_node_or_null("TurretCore") as Polygon2D
	_ring = get_node_or_null("TurretRing") as Line2D
	_barrel = get_node_or_null("TurretBarrel") as Line2D
	_shield_ring = get_node_or_null("TurretShieldRing") as Line2D
	_charge_ring = get_node_or_null("TurretChargeRing") as Line2D
	_muzzle_flash = get_node_or_null("TurretMuzzleFlash") as Line2D
	_collision = get_node_or_null("TurretCollision") as CollisionShape2D
	_build_collision()
	_build_visuals()
	_update_visual_state()


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"campaign_planet_turret")
		RuntimeRegistry.unregister_node(self, &"enemies")
		RuntimeRegistry.unregister_node(self, &"wave_enemy")


func _process(delta: float) -> void:
	if _defeated:
		return
	_elapsed += delta * CombatStatus.get_time_scale(self)
	_update_visuals(delta)
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
	_candidate_targets.clear()
	for player in MultiplayerTargeting.live_players(get_tree()):
		_candidate_targets.append(player)
	_fill_group_cached(&"campaign_mother_planet", _target_query_buffer, 1)
	var mother: Node2D = _target_query_buffer[0] if not _target_query_buffer.is_empty() else null
	if mother != null and is_instance_valid(mother):
		_candidate_targets.append(mother)
	_fill_group_cached(&"campaign_escort", _target_query_buffer)
	for escort in _target_query_buffer:
		_candidate_targets.append(escort)
	var best: Node2D = null
	var best_score := range * range
	for candidate in _candidate_targets:
		if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
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
	if use_global_bullet_budget and BulletManager != null and not BulletManager.can_spawn_bullet():
		if target.has_method("take_damage"):
			target.call("take_damage", maxf(projectile_speed / 100.0, 1.0))
		if _barrel != null:
			_barrel.default_color = Color(barrel_flash_color.r, barrel_flash_color.g, barrel_flash_color.b, 0.48)
		_flash_alpha = 0.48
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
	var tree := get_tree()
	var projectile_parent := tree.current_scene if tree != null and tree.current_scene != null else get_parent()
	if projectile_parent != null:
		projectile_parent.call_deferred("add_child", projectile)
	if _barrel != null:
		_barrel.default_color = barrel_flash_color
	_flash_alpha = barrel_flash_color.a


func _fill_group_cached(group_name: StringName, out_nodes: Array[Node2D], limit: int = -1) -> void:
	out_nodes.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(group_name, out_nodes, limit)
		return
	for value in get_tree().get_nodes_in_group(String(group_name)):
		if limit >= 0 and out_nodes.size() >= limit:
			return
		var node := value as Node2D
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			out_nodes.append(node)


func _build_visuals() -> void:
	if _base == null:
		_base = Polygon2D.new()
		_base.name = "TurretBase"
		add_child(_base)
	_base.polygon = _circle_points(base_radius, 12)
	_base.color = base_color
	_base.z_index = -1
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "TurretCore"
		add_child(_core)
	_core.polygon = _circle_points(core_radius, 10)
	_core.z_index = 3
	if _ring == null:
		_ring = Line2D.new()
		_ring.name = "TurretRing"
		_ring.closed = true
		_ring.antialiased = true
		_ring.width = 2.4
		add_child(_ring)
	_ring.points = _circle_points(ring_radius, 36)
	_ring.z_index = 4
	if _barrel == null:
		_barrel = Line2D.new()
		_barrel.name = "TurretBarrel"
		_barrel.width = 3.2
		add_child(_barrel)
	_barrel.antialiased = true
	_barrel.points = PackedVector2Array([Vector2.ZERO, Vector2(barrel_length, 0.0)])
	_barrel.z_index = 5
	if _shield_ring == null:
		_shield_ring = Line2D.new()
		_shield_ring.name = "TurretShieldRing"
		add_child(_shield_ring)
	_shield_ring.closed = true
	_shield_ring.antialiased = true
	_shield_ring.width = 1.2
	_shield_ring.points = _circle_points(shield_radius, 44)
	_shield_ring.z_index = 1
	if _charge_ring == null:
		_charge_ring = Line2D.new()
		_charge_ring.name = "TurretChargeRing"
		add_child(_charge_ring)
	_charge_ring.closed = false
	_charge_ring.antialiased = true
	_charge_ring.width = 2.0
	_charge_ring.z_index = 6
	if _muzzle_flash == null:
		_muzzle_flash = Line2D.new()
		_muzzle_flash.name = "TurretMuzzleFlash"
		add_child(_muzzle_flash)
	_muzzle_flash.antialiased = true
	_muzzle_flash.width = 4.6
	_muzzle_flash.z_index = 7
	_muzzle_flash.points = PackedVector2Array([Vector2(barrel_length * 0.72, 0.0), Vector2(barrel_length + muzzle_flash_length, 0.0)])


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
	var core_tint := core_color if hostile else friendly_core_color
	if _base != null:
		_base.color = _safe_color(base_color.lerp(damaged_color, (1.0 - health_ratio) * 0.35))
	if _core != null:
		_core.color = _safe_color(core_tint.lerp(damaged_color, (1.0 - health_ratio) * 0.45))
	if _ring != null:
		_ring.default_color = _safe_color(color.lerp(damaged_color, 1.0 - health_ratio))
	if _barrel != null:
		_barrel.default_color = _safe_color(Color(color.r, color.g, color.b, 0.72))
	if _shield_ring != null:
		_shield_ring.default_color = _safe_color(Color(color.r, color.g, color.b, _safe_alpha(shield_alpha * (0.5 + health_ratio * 0.5), 0.22)))
	if _charge_ring != null:
		_charge_ring.default_color = _safe_color(Color(color.r, color.g, color.b, _safe_alpha(charge_alpha, 0.4)))


func _update_visuals(delta: float) -> void:
	var color := hostile_color if hostile else friendly_color
	var charge_ratio := clampf(_elapsed / maxf(fire_interval, 0.05), 0.0, 1.0)
	_flash_alpha = maxf(_flash_alpha - delta * 4.6, 0.0)
	if _ring != null:
		_ring.rotation += delta * (0.34 if hostile else -0.18)
	if _shield_ring != null:
		_shield_ring.rotation -= delta * (0.42 if hostile else 0.22)
		_shield_ring.width = 1.0 + charge_ratio * 1.1
	if _barrel != null:
		var base_barrel := Color(color.r, color.g, color.b, 0.72)
		_barrel.default_color = _safe_color(base_barrel.lerp(barrel_flash_color, clampf(_flash_alpha, 0.0, 1.0)))
	if _charge_ring != null:
		_charge_ring.points = _arc_points(charge_ring_radius + charge_ratio * 7.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(charge_ratio, 0.02), 36)
		_charge_ring.default_color = _safe_color(Color(color.r, color.g, color.b, _safe_alpha(charge_alpha * (0.28 + charge_ratio * 0.72), 0.4)))
	if _core != null:
		var pulse := 0.9 + charge_ratio * 0.22 + sin(Time.get_ticks_msec() * 0.008) * 0.04
		_core.scale = Vector2.ONE * pulse
	if _muzzle_flash != null:
		_muzzle_flash.default_color = _safe_color(Color(barrel_flash_color.r, barrel_flash_color.g, barrel_flash_color.b, _safe_alpha(_flash_alpha, 0.72)))
		_muzzle_flash.visible = _flash_alpha > 0.02


func _safe_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)


func _safe_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _arc_points(radius: float, start_angle: float, end_angle: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 2)
	for index in range(safe_count):
		var t := float(index) / float(maxi(safe_count - 1, 1))
		var angle := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
