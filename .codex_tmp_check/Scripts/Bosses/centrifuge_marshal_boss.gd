extends PhaseBoss

## Wave 35 capstone: rotating shear halos twist velocity tangentially when crossed.
## Readable rule: orbit the boss, but crossing the rings bends your trajectory.

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")

@export var orbit_distance: float = 680.0
@export var move_speed: float = 410.0
@export var gravity_radius: float = 860.0
@export var gravity_strength: float = 1420.0
@export var projectile_speed: float = 780.0
@export var halo_spin_speed: float = 0.62
@export var halo_shear_force: float = 540.0
@export var halo_inner_radius: float = 220.0
@export var halo_outer_radius: float = 520.0
@export var halo_band_width: float = 58.0

var _orbit_angle: float = 0.0
var _halo_angle: float = 0.0
var _aura: Polygon2D
var _core: Polygon2D
var _halo_lines: Array[Line2D] = []


func _ready() -> void:
	max_health = max(max_health, 1120.0)
	mass = 310000.0
	attack_interval = 2.45
	_build_body()
	super._ready()


func _boss_physics(delta: float) -> void:
	if player == null:
		return

	_orbit_angle += delta * (0.2 + 0.08 * float(current_phase))
	_halo_angle += delta * halo_spin_speed * (0.85 + 0.2 * float(current_phase))
	var target := player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_distance
	if current_phase >= 3:
		target = player.global_position.lerp(global_position, 0.22)

	velocity = velocity.lerp(
		(target - global_position).limit_length(move_speed + 55.0 * current_phase),
		clampf(delta * 1.7, 0.0, 1.0)
	)
	move_and_slide()
	_pull_player(delta)
	_apply_shear_halos(delta)
	_update_halo_visuals()

	if _aura != null:
		_aura.rotation = _halo_angle * 0.35


func _run_attack_pattern() -> void:
	_telegraph_halos()
	await get_tree().create_timer(0.36).timeout
	if is_queued_for_deletion() or get_parent() == null:
		return

	match current_phase:
		1:
			halo_spin_speed = 0.58
			_spawn_aimed_shot(projectile_speed * 0.9)
		2:
			halo_spin_speed = 0.82
			_apply_shear_snap(0.55)
			_spawn_aimed_shot(projectile_speed)
		3:
			halo_spin_speed = 1.05
			_apply_shear_snap(0.95)
			_spawn_aimed_shot(projectile_speed * 1.04)


func on_damage_taken(_amount: float) -> void:
	_halo_angle += 0.22
	if _core != null:
		var tween := create_tween()
		tween.tween_property(_core, "scale", Vector2(1.2, 1.2), 0.08)
		tween.tween_property(_core, "scale", Vector2.ONE, 0.14)


func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.02, attack_interval - 0.38 * float(phase - 1))
	gravity_radius = [820.0, 940.0, 1080.0][phase - 1]
	if _core != null:
		_core.color = [
			Color(0.35, 0.95, 1.0, 1.0),
			Color(0.95, 0.45, 1.0, 1.0),
			Color(1.0, 0.72, 0.22, 1.0),
		][phase - 1]
	for line in _halo_lines:
		if line != null:
			line.default_color = Color(0.35, 0.95, 1.0, 0.22 + 0.12 * float(phase))


func _build_body() -> void:
	if has_node("CentrifugeAura"):
		_aura = get_node("CentrifugeAura") as Polygon2D
		_core = get_node("CentrifugeCore") as Polygon2D
		_collect_halo_lines()
		if _aura != null and _aura.polygon.is_empty():
			_aura.polygon = _circle_points(48, 168.0)
		if _core != null and _core.polygon.is_empty():
			_core.polygon = _circle_points(10, 52.0)
	else:
		_build_body_polygons()

	if not has_node("CollisionPolygon2D"):
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = _circle_points(12, 118.0)
		add_child(collision)

	if _halo_lines.is_empty():
		for i in range(3):
			var line := Line2D.new()
			line.name = "ShearHaloLine%d" % i
			line.width = 2.4
			line.default_color = Color(0.35, 0.95, 1.0, 0.28)
			line.z_index = -4
			add_child(line)
			_halo_lines.append(line)


func _build_body_polygons() -> void:
	_aura = Polygon2D.new()
	_aura.name = "CentrifugeAura"
	_aura.z_index = -3
	_aura.color = Color(0.2, 0.82, 1.0, 0.1)
	_aura.polygon = _circle_points(48, 168.0)
	add_child(_aura)

	_core = Polygon2D.new()
	_core.name = "CentrifugeCore"
	_core.color = Color(0.35, 0.95, 1.0, 1.0)
	_core.polygon = _circle_points(10, 52.0)
	add_child(_core)


func _collect_halo_lines() -> void:
	_halo_lines.clear()
	for child in get_children():
		if child is Line2D and String(child.name).begins_with("ShearHaloLine"):
			_halo_lines.append(child as Line2D)


func _apply_shear_halos(delta: float) -> void:
	var halo_count = 2 + current_phase
	var radii := _halo_radii_for_phase(halo_count)
	for halo_index in range(radii.size()):
		var radius: float = radii[halo_index]
		var spin_sign := 1.0 if halo_index % 2 == 0 else -1.0
		var tangent_angle := _halo_angle + float(halo_index) * TAU / float(maxi(halo_count, 1))
		_shear_band(radius, tangent_angle, spin_sign, delta, 0.72 + 0.18 * float(current_phase))


func _apply_shear_snap(multiplier: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	if offset.length_squared() <= 1.0:
		return
	var tangent := offset.orthogonal().normalized()
	CombatStatus.add_velocity(player, tangent * halo_shear_force * multiplier)


func _shear_band(radius: float, base_angle: float, spin_sign: float, delta: float, strength_scale: float) -> void:
	var inner := maxf(radius - halo_band_width * 0.5, halo_inner_radius * 0.5)
	var outer := radius + halo_band_width * 0.5
	var inner_sq := inner * inner
	var outer_sq := outer * outer
	var seen := {}

	for group_name in [&"Player", &"enemies", &"wave_enemy", &"Projectiles", &"enemy_projectiles"]:
		for body in get_tree().get_nodes_in_group(group_name):
			if body == self or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var body_2d := body as Node2D
			if body_2d == null:
				continue
			var id := body_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var offset := body_2d.global_position - global_position
			var dist_sq := offset.length_squared()
			if dist_sq < inner_sq or dist_sq > outer_sq:
				continue

			var radial := offset.normalized()
			var tangent := radial.orthogonal() * spin_sign
			var falloff := 1.0 - absf(sqrt(dist_sq) - radius) / maxf(halo_band_width, 1.0)
			CombatStatus.add_velocity(
				body_2d,
				tangent * halo_shear_force * strength_scale * falloff * delta
			)


func _update_halo_visuals() -> void:
	var halo_count := _halo_lines.size()
	if halo_count <= 0:
		return
	var radii := _halo_radii_for_phase(halo_count)
	for i in range(halo_count):
		var line := _halo_lines[i]
		if line == null:
			continue
		var radius: float = radii[i] if i < radii.size() else halo_outer_radius
		var arc_angle := _halo_angle + float(i) * TAU / float(halo_count)
		line.points = _arc_points(radius, arc_angle, 0.62)


func _halo_radii_for_phase(count: int) -> Array[float]:
	var radii: Array[float] = []
	for i in range(count):
		var t := float(i) / float(maxi(count - 1, 1))
		radii.append(lerpf(halo_inner_radius, halo_outer_radius, t))
	return radii


func _telegraph_halos() -> void:
	for line in _halo_lines:
		if line == null:
			continue
		var tween := line.create_tween()
		tween.tween_property(line, "width", line.width * 2.2, 0.22)
		tween.parallel().tween_property(line, "default_color:a", 0.55, 0.22)
		tween.tween_property(line, "width", 2.4, 0.2)
		tween.parallel().tween_property(line, "default_color:a", 0.28, 0.2)


func _pull_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var offset := global_position - player.global_position
	var distance := offset.length()
	if distance <= 1.0 or distance > gravity_radius:
		return
	var player_velocity: Variant = player.get("velocity")
	if not player_velocity is Vector2:
		return
	var pull = offset.normalized() * gravity_strength * mass / maxf(distance * distance, 1800.0)
	player.set("velocity", player_velocity + pull * delta)


func _spawn_aimed_shot(speed: float) -> void:
	if player == null or get_parent() == null:
		return
	var aim := (player.global_position - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT.rotated(rotation)
	var bullet := ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position + aim * 128.0
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", aim, speed, self)
	elif bullet.get("initial_speed") != null:
		bullet.set("initial_speed", speed)
	get_parent().call_deferred("add_child", bullet)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _arc_points(radius: float, start_angle: float, arc_span: float) -> PackedVector2Array:
	var segments := 28
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var angle := start_angle + arc_span * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
