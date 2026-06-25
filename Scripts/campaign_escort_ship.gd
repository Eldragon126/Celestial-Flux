extends CharacterBody2D
class_name CampaignEscortShip

signal escort_destroyed(escort: CampaignEscortShip)
signal escort_hit_target(target: Node, damage: float)

@export var max_health: float = 130.0
@export var follow_force: float = 1850.0
@export var gravity_constant: float = 120.0
@export var max_speed: float = 760.0
@export var drag: float = 0.9
@export var formation_radius: float = 210.0
@export var attack_radius: float = 520.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 0.42
@export var max_gravity_sources: int = 4
@export var collision_radius: float = 20.0
@export var hull_color: Color = Color(0.24, 0.92, 1.0, 0.95)
@export var attack_beam_color: Color = Color(0.42, 1.0, 0.86, 0.72)
@export_group("Visual Polish")
@export var shield_radius: float = 31.0
@export var shield_alpha: float = 0.22
@export var core_color: Color = Color(0.72, 1.0, 0.92, 0.96)
@export var wing_color: Color = Color(0.22, 1.0, 0.82, 0.48)
@export var engine_color: Color = Color(0.18, 0.9, 1.0, 0.72)
@export var engine_trail_length: float = 54.0
@export var beam_idle_alpha: float = 0.0

var player: Node2D = null
var mother_planet: Node2D = null
var escort_index: int = 0
var damage_multiplier: float = 1.0
var current_health: float = 130.0

var _gravity_sources: Array[Node2D] = []
var _fire_elapsed: float = 0.0
var _beam: Line2D = null
var _hull: Polygon2D = null
var _core: Polygon2D = null
var _shield_ring: Line2D = null
var _wing_line: Line2D = null
var _engine_trail: Line2D = null


func configure(index: int, player_node: Node2D, mother_node: Node2D, hull_color: Color) -> void:
	escort_index = index
	player = player_node
	mother_planet = mother_node
	self.hull_color = hull_color
	if _hull != null:
		_hull.color = hull_color


func _ready() -> void:
	add_to_group("campaign_escort")
	add_to_group("player_allies")
	current_health = max_health
	_hull = get_node_or_null("CampaignEscortHull") as Polygon2D
	_core = get_node_or_null("CampaignEscortCore") as Polygon2D
	_shield_ring = get_node_or_null("CampaignEscortShield") as Line2D
	_wing_line = get_node_or_null("CampaignEscortWingLine") as Line2D
	_engine_trail = get_node_or_null("CampaignEscortEngineTrail") as Line2D
	_beam = get_node_or_null("EscortBeam") as Line2D
	_build_collision()
	_build_visuals()


func _physics_process(delta: float) -> void:
	delta *= CombatStatus.get_time_scale(self)
	_fire_elapsed += delta
	if player == null or not is_instance_valid(player):
		player = MultiplayerTargeting.local_player(get_tree())
	if mother_planet == null or not is_instance_valid(mother_planet):
		mother_planet = get_tree().get_first_node_in_group("campaign_mother_planet") as Node2D

	var target := _nearest_hostile()
	var desired_position := _formation_position()
	if target != null:
		var target_offset := target.global_position - global_position
		if target_offset.length() > attack_radius * 0.55:
			desired_position = target.global_position - target_offset.normalized() * attack_radius * 0.42
		_try_fire(target)

	var to_desired := desired_position - global_position
	var steering := to_desired.limit_length(1.0) * follow_force
	velocity += (steering + _gravity_acceleration()) * delta
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)
	if velocity.length_squared() > 4.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 8.0, 0.0, 1.0))
	move_and_slide()
	_update_visuals(delta)


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		escort_destroyed.emit(self)
		queue_free()


func _formation_position() -> Vector2:
	var anchor := player if player != null and is_instance_valid(player) else mother_planet
	if anchor == null or not is_instance_valid(anchor):
		return global_position
	var angle := TAU * float(escort_index) / 6.0 + Time.get_ticks_msec() * 0.00028
	var mother_bias := Vector2.ZERO
	if mother_planet != null and is_instance_valid(mother_planet):
		mother_bias = (mother_planet.global_position - anchor.global_position) * 0.18
	return anchor.global_position + mother_bias + Vector2.RIGHT.rotated(angle) * formation_radius


func _nearest_hostile() -> Node2D:
	var best: Node2D = null
	var best_distance := attack_radius * attack_radius
	for group_name in [&"campaign_invader", &"enemies", &"wave_enemy"]:
		for value in get_tree().get_nodes_in_group(group_name):
			var candidate := value as Node2D
			if candidate == null or candidate == self or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
				continue
			if candidate.is_in_group("player_allies"):
				continue
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best


func _try_fire(target: Node2D) -> void:
	if _fire_elapsed < attack_interval:
		return
	_fire_elapsed = 0.0
	var damage := attack_damage * maxf(damage_multiplier, 0.1)
	if target.has_method("take_damage"):
		target.call("take_damage", damage)
		escort_hit_target.emit(target, damage)
	_draw_beam(target.global_position)


func _gravity_acceleration() -> Vector2:
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(global_position, _gravity_sources, max_gravity_sources, 1900.0, self)
	else:
		for source in get_tree().get_nodes_in_group("Objects_With_Gravity"):
			var source_2d := source as Node2D
			if source_2d != null and source_2d != self:
				_gravity_sources.append(source_2d)
				if _gravity_sources.size() >= max_gravity_sources:
					break
	var total := Vector2.ZERO
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source):
			continue
		var offset := source.global_position - global_position
		var distance := maxf(offset.length(), 90.0)
		var mass_value: Variant = source.get("mass")
		var source_mass := float(mass_value) if mass_value is float or mass_value is int else 100.0
		total += offset.normalized() * gravity_constant * source_mass / (distance * distance)
	return total


func _build_collision() -> void:
	var existing := get_node_or_null("CampaignEscortCollision") as CollisionShape2D
	if existing != null:
		if existing.shape is CircleShape2D:
			(existing.shape as CircleShape2D).radius = collision_radius
		return
	var collision := CollisionShape2D.new()
	collision.name = "CampaignEscortCollision"
	var shape := CircleShape2D.new()
	shape.radius = collision_radius
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	if _hull == null:
		_hull = Polygon2D.new()
		_hull.name = "CampaignEscortHull"
		add_child(_hull)
	_hull.polygon = PackedVector2Array([
		Vector2(30.0, 0.0),
		Vector2(6.0, 13.0),
		Vector2(-20.0, 17.0),
		Vector2(-10.0, 0.0),
		Vector2(-20.0, -17.0),
		Vector2(6.0, -13.0),
	])
	_hull.color = hull_color
	_hull.z_index = 3
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "CampaignEscortCore"
		add_child(_core)
	_core.polygon = PackedVector2Array([
		Vector2(9.0, 0.0),
		Vector2(-4.0, 7.0),
		Vector2(-13.0, 0.0),
		Vector2(-4.0, -7.0),
	])
	_core.color = core_color
	_core.z_index = 5
	if _shield_ring == null:
		_shield_ring = Line2D.new()
		_shield_ring.name = "CampaignEscortShield"
		add_child(_shield_ring)
	_shield_ring.closed = true
	_shield_ring.antialiased = true
	_shield_ring.width = 1.3
	_shield_ring.points = _circle_points(shield_radius, 36)
	_shield_ring.z_index = 1
	if _wing_line == null:
		_wing_line = Line2D.new()
		_wing_line.name = "CampaignEscortWingLine"
		add_child(_wing_line)
	_wing_line.antialiased = true
	_wing_line.width = 1.8
	_wing_line.points = PackedVector2Array([
		Vector2(-18.0, -18.0),
		Vector2(4.0, -9.0),
		Vector2(27.0, 0.0),
		Vector2(4.0, 9.0),
		Vector2(-18.0, 18.0),
	])
	_wing_line.z_index = 4
	if _engine_trail == null:
		_engine_trail = Line2D.new()
		_engine_trail.name = "CampaignEscortEngineTrail"
		add_child(_engine_trail)
	_engine_trail.antialiased = true
	_engine_trail.width = 2.2
	_engine_trail.z_index = 0
	if _beam == null:
		_beam = Line2D.new()
		_beam.name = "EscortBeam"
		_beam.width = 2.0
		add_child(_beam)
	_beam.antialiased = true
	_beam.z_index = 6
	_beam.default_color = Color(attack_beam_color.r, attack_beam_color.g, attack_beam_color.b, beam_idle_alpha)


func _draw_beam(target_position: Vector2) -> void:
	if _beam == null:
		return
	_beam.points = PackedVector2Array([Vector2.ZERO, to_local(target_position)])
	_beam.default_color = attack_beam_color


func _update_visuals(delta: float) -> void:
	if _beam != null:
		_beam.default_color.a = maxf(_beam.default_color.a - delta * 5.8, beam_idle_alpha)
	var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var speed_ratio := clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.0)
	if _shield_ring != null:
		_shield_ring.rotation += delta * (0.7 + float(escort_index) * 0.08)
		_shield_ring.default_color = Color(hull_color.r, hull_color.g, hull_color.b, _safe_alpha(shield_alpha * health_ratio, 0.28))
		_shield_ring.width = 1.0 + (1.0 - health_ratio) * 1.8
	if _wing_line != null:
		_wing_line.default_color = Color(wing_color.r, wing_color.g, wing_color.b, wing_color.a * (0.7 + speed_ratio * 0.3))
	if _core != null:
		var pulse := 0.76 + sin(Time.get_ticks_msec() * 0.008 + float(escort_index)) * 0.16
		_core.modulate.a = clampf(pulse, 0.48, 0.96)
		_core.scale = Vector2.ONE * (0.9 + speed_ratio * 0.14)
	if _engine_trail != null:
		var trail := engine_trail_length * lerpf(0.28, 1.0, speed_ratio)
		_engine_trail.points = PackedVector2Array([
			Vector2(-14.0, 0.0),
			Vector2(-22.0 - trail * 0.48, sin(Time.get_ticks_msec() * 0.012 + float(escort_index)) * 2.2),
			Vector2(-22.0 - trail, sin(Time.get_ticks_msec() * 0.009 + float(escort_index)) * 4.0),
		])
		_engine_trail.default_color = Color(engine_color.r, engine_color.g, engine_color.b, 0.16 + speed_ratio * 0.44)
		_engine_trail.width = lerpf(1.1, 3.4, speed_ratio)


func _safe_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
