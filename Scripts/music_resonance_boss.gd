extends PhaseBoss
class_name MusicResonanceBoss

## Finale boss. MusicFinaleDirector owns timing; this boss owns readable physics responses.

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

@export var orbit_distance: float = 620.0
@export var move_speed: float = 420.0
@export var pulse_knock_force: float = 620.0
@export var sweep_projectile_count: int = 14
@export var projectile_speed: float = 760.0
@export var collapse_radius: float = 720.0
@export var collapse_force: float = 980.0

var _orbit_angle: float = 0.0
var _collapse_charge: float = 0.0
var _body_poly: Polygon2D = null
var _core_poly: Polygon2D = null
var _rings: Array[Line2D] = []
var _trail_particles: GPUParticles2D = null


func _ready() -> void:
	max_health = maxf(max_health, 1800.0)
	mass = 520000.0
	attack_interval = 99.0
	_build_editable_body()
	super._ready()


func _boss_physics(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_orbit_angle += delta * (0.22 + 0.05 * float(current_phase))
	var target := player.global_position + Vector2.from_angle(_orbit_angle) * orbit_distance
	if current_phase >= 3:
		target = player.global_position + Vector2.from_angle(_orbit_angle * -1.4) * (orbit_distance * 0.72)

	velocity = velocity.lerp((target - global_position).limit_length(move_speed), clampf(delta * 1.8, 0.0, 1.0))
	move_and_slide()
	_apply_collapse_field(delta)
	_update_visuals(delta)


func on_music_pulse(intensity: float = 1.0) -> void:
	_pulse_rings(Color(0.42, 1.0, 0.92, 0.72), 1.12 + intensity * 0.16)
	_push_player(intensity)


func on_music_burst(intensity: float = 1.0) -> void:
	_pulse_rings(Color(1.0, 0.42, 0.88, 0.76), 1.2 + intensity * 0.22)
	_spawn_projectile_sweep(projectile_speed * (0.94 + intensity * 0.12))


func on_music_finale(intensity: float = 1.0) -> void:
	_pulse_rings(Color(1.0, 0.82, 0.25, 0.82), 1.36 + intensity * 0.22)
	_collapse_charge = maxf(_collapse_charge, 0.75 + intensity * 0.2)
	_spawn_projectile_sweep(projectile_speed * 1.08)


func _run_attack_pattern() -> void:
	# Finale attacks are music-driven. This timer is kept only for PhaseBoss compatibility.
	if attack_timer != null:
		attack_timer.wait_time = maxf(attack_interval, 1.0)


func _build_editable_body() -> void:
	_body_poly = get_node_or_null("ResonanceHull") as Polygon2D
	if _body_poly == null:
		_body_poly = Polygon2D.new()
		_body_poly.name = "ResonanceHull"
		_body_poly.color = Color(0.22, 0.7, 1.0, 0.78)
		add_child(_body_poly)
	if _body_poly.polygon.is_empty():
		_body_poly.polygon = _circle_points(104.0, 12)

	_core_poly = get_node_or_null("ResonanceCore") as Polygon2D
	if _core_poly == null:
		_core_poly = Polygon2D.new()
		_core_poly.name = "ResonanceCore"
		_core_poly.color = Color(0.84, 1.0, 0.95, 1.0)
		add_child(_core_poly)
	if _core_poly.polygon.is_empty():
		_core_poly.polygon = _circle_points(44.0, 8)

	_rings.clear()
	for child in get_children():
		if child is Line2D and String(child.name).begins_with("ResonanceRing"):
			_rings.append(child as Line2D)
	if _rings.is_empty():
		for i in range(3):
			var ring := Line2D.new()
			ring.name = "ResonanceRing%d" % i
			ring.closed = true
			ring.width = 2.2
			ring.default_color = Color(0.42, 1.0, 0.92, 0.34)
			add_child(ring)
			_rings.append(ring)

	_trail_particles = get_node_or_null("ResonanceTrail") as GPUParticles2D
	if _trail_particles != null:
		_trail_particles.emitting = true

	if not has_node("CollisionPolygon2D"):
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = _circle_points(106.0, 12)
		add_child(collision)


func _apply_collapse_field(delta: float) -> void:
	if _collapse_charge <= 0.0:
		return
	_collapse_charge = maxf(_collapse_charge - delta * 0.55, 0.0)

	for group_name in [&"Player", &"Projectiles", &"enemy_projectiles"]:
		for body in get_tree().get_nodes_in_group(group_name):
			if body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var body_2d := body as Node2D
			if body_2d == null:
				continue
			var offset := global_position - body_2d.global_position
			var dist := offset.length()
			if dist <= 1.0 or dist > collapse_radius:
				continue
			var falloff := 1.0 - dist / collapse_radius
			CombatStatus.add_velocity(body_2d, offset.normalized() * collapse_force * _collapse_charge * falloff * delta)


func _push_player(intensity: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	if offset.length_squared() <= 1.0:
		return
	var tangent := offset.normalized().orthogonal()
	CombatStatus.add_velocity(player, (offset.normalized() + tangent * 0.42).normalized() * pulse_knock_force * intensity)


func _spawn_projectile_sweep(speed: float) -> void:
	if get_parent() == null:
		return
	var count := maxi(sweep_projectile_count + current_phase * 2, 6)
	var lead_angle := 0.0
	if player != null and is_instance_valid(player):
		lead_angle = (player.global_position - global_position).angle()
	for i in range(count):
		# Check global bullet cap before spawning each projectile
		if not BulletManager.can_spawn_bullet():
			break

		var spread := TAU * float(i) / float(count)
		var dir := Vector2.from_angle(lead_angle + spread + _orbit_angle * 0.18)
		var bullet := ENEMY_BULLET_SCENE.instantiate()
		bullet.global_position = global_position + dir * 132.0
		if bullet.has_method("configure_launch"):
			bullet.call("configure_launch", dir, speed, self)
		elif bullet.get("initial_speed") != null:
			bullet.set("initial_speed", speed)
		get_parent().call_deferred("add_child", bullet)


func _pulse_rings(color: Color, scale_target: float) -> void:
	for ring in _rings:
		if ring == null or not is_instance_valid(ring):
			continue
		ring.default_color = color
		var tween := ring.create_tween()
		tween.tween_property(ring, "scale", Vector2.ONE * scale_target, 0.12)
		tween.parallel().tween_property(ring, "width", 5.0, 0.12)
		tween.tween_property(ring, "scale", Vector2.ONE, 0.32)
		tween.parallel().tween_property(ring, "width", 2.2, 0.32)


func _update_visuals(delta: float) -> void:
	rotation += delta * (0.25 + 0.08 * float(current_phase))
	for i in range(_rings.size()):
		var ring := _rings[i]
		if ring == null:
			continue
		var radius := 128.0 + float(i) * 42.0 + _collapse_charge * 24.0
		ring.points = _circle_points(radius, 72)
		ring.rotation += delta * (0.42 + float(i) * 0.18) * (-1.0 if i % 2 == 0 else 1.0)
	if _core_poly != null:
		_core_poly.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() / 140.0) * 0.035)


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
