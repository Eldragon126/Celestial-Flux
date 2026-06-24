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

var player: Node2D = null
var mother_planet: Node2D = null
var escort_index: int = 0
var damage_multiplier: float = 1.0
var current_health: float = 130.0

var _gravity_sources: Array[Node2D] = []
var _fire_elapsed: float = 0.0
var _beam: Line2D = null
var _hull: Polygon2D = null


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
	_update_beam(delta)


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
		_hull.polygon = PackedVector2Array([
			Vector2(25.0, 0.0),
			Vector2(-15.0, 14.0),
			Vector2(-8.0, 0.0),
			Vector2(-15.0, -14.0),
		])
		add_child(_hull)
	_hull.color = hull_color
	if _beam == null:
		_beam = Line2D.new()
		_beam.name = "EscortBeam"
		_beam.width = 2.0
		add_child(_beam)
	_beam.default_color = Color(attack_beam_color.r, attack_beam_color.g, attack_beam_color.b, 0.0)


func _draw_beam(target_position: Vector2) -> void:
	if _beam == null:
		return
	_beam.points = PackedVector2Array([Vector2.ZERO, to_local(target_position)])
	_beam.default_color = attack_beam_color


func _update_beam(delta: float) -> void:
	if _beam == null:
		return
	_beam.default_color.a = maxf(_beam.default_color.a - delta * 5.8, 0.0)
