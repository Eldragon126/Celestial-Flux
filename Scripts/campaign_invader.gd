extends CharacterBody2D
class_name CampaignInvader

signal destroyed(invader: CampaignInvader, reward: int, position: Vector2)
signal breached_target(invader: CampaignInvader, target: Node, damage: float)

@export var max_health: float = 44.0
@export var thrust_power: float = 1550.0
@export var max_speed: float = 430.0
@export var drag: float = 0.84
@export var gravity_constant: float = 180.0
@export var gravity_pull_radius: float = 2100.0
@export var max_gravity_sources: int = 4
@export var breach_damage: float = 34.0
@export var breach_radius: float = 66.0
@export var reward_credits: int = 8
@export var march_amplitude: float = 270.0
@export var march_frequency: float = 0.75
@export var collision_radius: float = 24.0
@export var hull_color: Color = Color(1.0, 0.34, 0.16, 0.92)
@export var damaged_hull_color: Color = Color(1.0, 0.16, 0.12, 0.92)
@export var vector_color: Color = Color(1.0, 0.62, 0.28, 0.42)

var target: Node2D = null
var current_health: float = 44.0
var march_row: int = 0
var march_column: int = 0
var fleet_seed: int = 0

var _visual: Polygon2D = null
var _aim_line: Line2D = null
var _gravity_sources: Array[Node2D] = []
var _elapsed: float = 0.0
var _destroyed: bool = false


func configure(target_node: Node2D, row: int, column: int, seed_value: int) -> void:
	target = target_node
	march_row = row
	march_column = column
	fleet_seed = seed_value


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wave_enemy")
	add_to_group("campaign_invader")
	current_health = max_health
	_visual = get_node_or_null("CampaignInvaderHull") as Polygon2D
	_aim_line = get_node_or_null("CampaignInvaderVector") as Line2D
	_build_collision()
	_build_visuals()
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
		RuntimeRegistry.register_node(self, &"wave_enemy")


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
		RuntimeRegistry.unregister_node(self, &"wave_enemy")


func _physics_process(delta: float) -> void:
	if _destroyed:
		return
	delta *= CombatStatus.get_time_scale(self)
	_elapsed += delta
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		target = _resolve_target()
	if target == null:
		return

	var gravity := _gravity_acceleration()
	var to_target := target.global_position - global_position
	var desired := to_target.normalized()
	var lateral := desired.orthogonal() * sin(_elapsed * march_frequency + float(march_column) * 0.72) * march_amplitude
	var row_bias := desired.orthogonal() * float(march_row - 1) * 42.0
	var steering := (desired * thrust_power + lateral + row_bias) * delta
	velocity += steering + gravity * delta
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)
	rotation = lerp_angle(rotation, desired.angle(), clampf(delta * 6.0, 0.0, 1.0))
	move_and_slide()
	_update_visuals(to_target)
	_try_breach_target(to_target)


func take_damage(amount: float) -> void:
	if _destroyed or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	set_meta(&"campaign_hull_ratio", current_health / maxf(max_health, 1.0))
	if current_health <= 0.0:
		_destroyed = true
		destroyed.emit(self, reward_credits, global_position)
		queue_free()


func _try_breach_target(to_target: Vector2) -> void:
	if to_target.length() > breach_radius:
		return
	var damage_target := target
	if damage_target == null or not is_instance_valid(damage_target):
		return
	if damage_target.has_method("take_damage"):
		damage_target.call("take_damage", breach_damage)
	else:
		var health := damage_target.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			health.call("take_damage", breach_damage)
	breached_target.emit(self, damage_target, breach_damage)
	queue_free()


func _resolve_target() -> Node2D:
	var mother := get_tree().get_first_node_in_group("campaign_mother_planet") as Node2D
	var player := MultiplayerTargeting.nearest_player(global_position, get_tree())
	if mother != null and is_instance_valid(mother):
		if player == null or not is_instance_valid(player):
			return mother
		var mother_weight := global_position.distance_squared_to(mother.global_position)
		var player_weight := global_position.distance_squared_to(player.global_position) * 1.35
		return player if player_weight < mother_weight else mother
	return player


func _gravity_acceleration() -> Vector2:
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(global_position, _gravity_sources, max_gravity_sources, gravity_pull_radius, self)
	else:
		for source in get_tree().get_nodes_in_group("Objects_With_Gravity"):
			var source_2d := source as Node2D
			if source_2d != null and source_2d != self and is_instance_valid(source_2d):
				_gravity_sources.append(source_2d)
				if _gravity_sources.size() >= max_gravity_sources:
					break
	var total := Vector2.ZERO
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var offset := source.global_position - global_position
		var distance := maxf(offset.length(), 80.0)
		if distance > gravity_pull_radius:
			continue
		var mass_value: Variant = source.get("mass")
		var source_mass := float(mass_value) if mass_value is float or mass_value is int else 100.0
		total += offset.normalized() * gravity_constant * source_mass / (distance * distance)
	return total


func _build_collision() -> void:
	var existing := get_node_or_null("CampaignInvaderCollision") as CollisionShape2D
	if existing != null:
		if existing.shape is CircleShape2D:
			(existing.shape as CircleShape2D).radius = collision_radius
		return
	var collision := CollisionShape2D.new()
	collision.name = "CampaignInvaderCollision"
	var shape := CircleShape2D.new()
	shape.radius = collision_radius
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "CampaignInvaderHull"
		_visual.polygon = PackedVector2Array([
			Vector2(26.0, 0.0),
			Vector2(-18.0, 17.0),
			Vector2(-9.0, 0.0),
			Vector2(-18.0, -17.0),
		])
		add_child(_visual)
	_visual.color = hull_color
	if _aim_line == null:
		_aim_line = Line2D.new()
		_aim_line.name = "CampaignInvaderVector"
		_aim_line.width = 1.5
		add_child(_aim_line)
	_aim_line.default_color = vector_color


func _update_visuals(to_target: Vector2) -> void:
	if _visual != null:
		var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
		_visual.color = damaged_hull_color.lerp(hull_color, health_ratio)
	if _aim_line != null:
		var length := clampf(to_target.length(), 80.0, 420.0)
		_aim_line.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * length])
