extends CharacterBody2D

@export var max_health = 88.0
@export var thrust_power = 610.0
@export var max_speed = 520.0
@export var drag = 0.9
@export var contact_shield_damage = 28.0
@export var pulse_shield_damage = 44.0
@export var pulse_radius = 340.0
@export var pulse_interval = 4.0

var _player: Node2D = null
var _health: HealthComponent = null
var _pulse_timer: Timer
var _pulse_ring: Polygon2D

func _ready() -> void:
	add_to_group("enemies")
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	_build_timer()

func _physics_process(delta: float) -> void:
	var scaled_delta = delta * CombatStatus.get_time_scale(self)
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return

	var shielded = _player.has_method("is_shield_active") and bool(_player.call("is_shield_active"))
	var to_player = _player.global_position - global_position
	var desired = to_player.normalized() * thrust_power
	if not shielded:
		desired = desired.rotated(0.8) * 0.62

	velocity += desired * scaled_delta
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)
	move_and_slide()

	if to_player != Vector2.ZERO:
		rotation = lerp_angle(rotation, to_player.angle(), clampf(scaled_delta * 6.0, 0.0, 1.0))

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func _build_body() -> void:
	var core := get_node_or_null("ShieldBreakerPolygon") as Polygon2D
	if core == null:
		core = Polygon2D.new()
		core.name = "ShieldBreakerPolygon"
		core.color = Color(1.0, 0.16, 0.08, 1.0)
		add_child(core)
	if core.polygon.is_empty():
		core.polygon = PackedVector2Array([
			Vector2(42.0, 0.0),
			Vector2(10.0, 28.0),
			Vector2(-34.0, 18.0),
			Vector2(-18.0, 0.0),
			Vector2(-34.0, -18.0),
			Vector2(10.0, -28.0),
		])

	_pulse_ring = get_node_or_null("DisruptionPulseRing") as Polygon2D
	if _pulse_ring == null:
		_pulse_ring = Polygon2D.new()
		_pulse_ring.name = "DisruptionPulseRing"
		_pulse_ring.z_index = -1
		_pulse_ring.color = Color(1.0, 0.2, 0.08, 0.13)
		add_child(_pulse_ring)
	if _pulse_ring.polygon.is_empty():
		_pulse_ring.polygon = _circle_points(30, 58.0)

	if not has_node("CollisionPolygon2D"):
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = core.polygon
		add_child(collision)

	var attack_area := get_node_or_null("AttackArea") as Area2D
	if attack_area == null:
		attack_area = Area2D.new()
		attack_area.name = "AttackArea"
		add_child(attack_area)
	attack_area.monitoring = true
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)

	var shape := attack_area.get_node_or_null("AttackShape") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "AttackShape"
		attack_area.add_child(shape)
	if shape.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 54.0
		shape.shape = circle

func _build_health() -> void:
	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		add_child(_health)
	_health.max_health = max_health
	if not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)

func _build_timer() -> void:
	_pulse_timer = Timer.new()
	_pulse_timer.name = "ShieldDisruptionPulseTimer"
	_pulse_timer.wait_time = pulse_interval
	_pulse_timer.timeout.connect(_telegraph_pulse)
	add_child(_pulse_timer)
	_pulse_timer.start()

func _telegraph_pulse() -> void:
	if _pulse_ring != null:
		_pulse_ring.scale = Vector2.ONE
		var tween = create_tween()
		tween.tween_property(_pulse_ring, "scale", Vector2(pulse_radius / 58.0, pulse_radius / 58.0), 0.42)
		tween.parallel().tween_property(_pulse_ring, "color:a", 0.36, 0.18)
		tween.tween_property(_pulse_ring, "color:a", 0.12, 0.2)

	await get_tree().create_timer(0.42).timeout
	if is_queued_for_deletion():
		return
	_emit_disruption_pulse()

func _emit_disruption_pulse() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_squared_to(_player.global_position) > pulse_radius * pulse_radius:
		return

	CombatStatus.damage_shield_only(_player, pulse_shield_damage)
	if _player.has_method("apply_shield_disruption"):
		_player.call("apply_shield_disruption", 0.65, 0.8)

func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		CombatStatus.damage_shield_only(body, contact_shield_damage)

func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.14)
	queue_free()

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
