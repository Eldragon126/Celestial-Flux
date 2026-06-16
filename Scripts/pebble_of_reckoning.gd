extends CharacterBody2D
class_name PebbleOfReckoning

signal pebble_defeated(lifetime_seconds: float)
signal pebble_expired

@export var max_health: float = 1.0
@export var max_lifetime: float = 11.0
@export var touch_radius: float = 24.0
@export var collision_radius: float = 12.0
@export var spin_speed: float = 1.4

var _health: float = 1.0
var _age: float = 0.0
var _finished: bool = false
var _visual_root: Node2D = null
var _aura_ring: Line2D = null
var _collision_shape: CollisionShape2D = null
var _touch_area: Area2D = null


func configure_lifetime(seconds: float) -> void:
	max_lifetime = maxf(seconds, 1.0)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("easter_egg_pebble")
	set_meta(&"fake_miniboss_gag", true)
	set_meta(&"does_not_damage_player", true)
	_health = maxf(max_health, 1.0)
	_build_collision()
	_build_visuals()


func _process(delta: float) -> void:
	if _finished:
		return
	_age += delta
	if _visual_root != null:
		_visual_root.rotation += spin_speed * delta
	if _aura_ring != null:
		var pulse := 0.5 + 0.5 * sin(_age * 8.0)
		_aura_ring.width = lerpf(1.4, 3.2, pulse)
		_aura_ring.default_color = _safe_color(Color(1.0, 0.24, 0.12, 0.22 + pulse * 0.18), 0.4)
	if _age >= max_lifetime:
		_expire()


func take_damage(amount: float) -> void:
	if _finished or amount <= 0.0:
		return
	_health = maxf(_health - amount, 0.0)
	if _health <= 0.0:
		_defeat()


func get_health_ratio() -> float:
	return clampf(_health / maxf(max_health, 1.0), 0.0, 1.0)


func _build_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = collision_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)

	_touch_area = Area2D.new()
	_touch_area.name = "PebbleTouchArea"
	_touch_area.monitoring = true
	_touch_area.monitorable = false
	var touch_shape := CollisionShape2D.new()
	touch_shape.name = "TouchShape"
	var touch_circle := CircleShape2D.new()
	touch_circle.radius = touch_radius
	touch_shape.shape = touch_circle
	_touch_area.add_child(touch_shape)
	add_child(_touch_area)
	_touch_area.body_entered.connect(_on_touch_body_entered)


func _build_visuals() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "PebbleVisualRoot"
	_visual_root.z_index = 34
	add_child(_visual_root)

	var body := Polygon2D.new()
	body.name = "TinyAsteroidBody"
	body.color = _safe_color(Color(0.62, 0.54, 0.46, 1.0), 1.0)
	body.polygon = PackedVector2Array([
		Vector2(-12.0, -4.0),
		Vector2(-7.0, -13.0),
		Vector2(4.0, -11.0),
		Vector2(13.0, -4.0),
		Vector2(10.0, 8.0),
		Vector2(0.0, 14.0),
		Vector2(-10.0, 7.0),
	])
	_visual_root.add_child(body)

	var crack := Line2D.new()
	crack.name = "TinyDramaticCrack"
	crack.width = 1.4
	crack.antialiased = true
	crack.default_color = _safe_color(Color(1.0, 0.92, 0.56, 0.82), 0.82)
	crack.points = PackedVector2Array([
		Vector2(-4.0, -8.0),
		Vector2(1.0, -2.0),
		Vector2(-2.0, 4.0),
		Vector2(5.0, 10.0),
	])
	_visual_root.add_child(crack)

	_aura_ring = Line2D.new()
	_aura_ring.name = "FakeBossAura"
	_aura_ring.closed = true
	_aura_ring.antialiased = true
	_aura_ring.width = 2.0
	_aura_ring.default_color = _safe_color(Color(1.0, 0.24, 0.12, 0.3), 0.3)
	_aura_ring.points = _circle_points(19.0, 38)
	add_child(_aura_ring)


func _on_touch_body_entered(body: Node2D) -> void:
	if _finished or body == null:
		return
	if body.is_in_group("Player") or body.is_in_group("Projectiles") or body.is_in_group("player_projectiles"):
		_defeat()


func _defeat() -> void:
	if _finished:
		return
	_finished = true
	_disable_collision()
	_spawn_pop_rings()
	pebble_defeated.emit(_age)
	_fade_and_free(0.24, Vector2.ONE * 1.55)


func _expire() -> void:
	if _finished:
		return
	_finished = true
	_disable_collision()
	pebble_expired.emit()
	_fade_and_free(0.42, Vector2.ONE * 0.2)


func _disable_collision() -> void:
	if _collision_shape != null:
		_collision_shape.disabled = true
	if _touch_area != null:
		_touch_area.monitoring = false


func _spawn_pop_rings() -> void:
	for i in range(2):
		var ring := Line2D.new()
		ring.name = "PebblePopRing%d" % i
		ring.closed = true
		ring.antialiased = true
		ring.width = 1.6
		ring.default_color = _safe_color(Color(1.0, 0.72, 0.28, 0.48 - float(i) * 0.14), 0.48)
		ring.points = _circle_points(16.0 + float(i) * 7.0, 34)
		add_child(ring)
		var tween := ring.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2.ONE * (2.2 + float(i) * 0.35), 0.34)
		tween.tween_property(ring, "modulate:a", 0.0, 0.34)
		var free_ring := func() -> void:
			if ring != null and is_instance_valid(ring) and not ring.is_queued_for_deletion():
				ring.queue_free()
		tween.finished.connect(free_ring, CONNECT_ONE_SHOT)


func _fade_and_free(duration: float, target_scale: Vector2) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)


func _safe_color(color: Color, alpha: float) -> Color:
	var safe_alpha := alpha
	if Settings != null and Settings.has_method("world_visual_alpha"):
		safe_alpha = Settings.world_visual_alpha(alpha, 0.5)
	elif Settings != null and Settings.has_method("flash_alpha"):
		safe_alpha = minf(Settings.flash_alpha(alpha), alpha)
	return Color(color.r, color.g, color.b, safe_alpha)


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 8)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
