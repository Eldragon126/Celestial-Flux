extends PhaseBoss
class_name ExtradimensionalBreacherBoss

## Late-game flagship: a deterministic boundary-breaking boss that fights with
## gravity, screen-edge breaches, slipstream lanes, wormholes, and time faults.

const ENEMY_BULLET_SCENE = preload("res://Nodes/enemy_bullet.tscn")
const WORMHOLE_PAIR_SCENE = preload("res://Nodes/wormhole_pair.tscn")
const TIDE_POCKET_SCENE = preload("res://Nodes/gravity_tide_pocket.tscn")
const DYNAMIC_BODY_SCENE = preload("res://Nodes/dynamic_celestial_body.tscn")

signal breach_attack_started(attack_id: StringName, data: Dictionary)
signal breacher_distortion_pulsed(data: Dictionary)

@export var move_speed: float = 520.0
@export var outside_edge_distance: float = 360.0
@export var breach_telegraph_time: float = 0.85
@export var singularity_speed: float = 155.0
@export var singularity_mass: float = 360000.0
@export var moon_fragment_count: int = 5
@export var slipstream_lane_width: float = 320.0
@export var contact_damage: float = 24.0
@export var distortion_radius: float = 680.0
@export var max_targets_per_attack: int = 42
@export var projectile_speed: float = 880.0
@export_group("Desktop Breach")
@export var enable_desktop_breach_window: bool = true
@export var desktop_breach_window_size: Vector2i = Vector2i(460, 260)
@export var desktop_breach_window_lifetime: float = 3.6

var _core: Polygon2D = null
var _hull: Polygon2D = null
var _eye_ring: Line2D = null
var _breach_limbs: Array[Line2D] = []
var _telegraphs: Array[Node2D] = []
var _active_constructs: Array[Node] = []
var _target_buffer: Array[Node2D] = []
var _attack_sequence: int = 0
var _breach_angle: float = 0.0
var _edge_slot: int = 0
var _desktop_breach_window: Window = null


func _ready() -> void:
	max_health = max(max_health, 6800.0)
	mass = 520000.0
	attack_interval = 2.4
	_build_body()
	super._ready()


func _exit_tree() -> void:
	for construct in _active_constructs:
		if construct != null and is_instance_valid(construct):
			construct.queue_free()
	if _desktop_breach_window != null and is_instance_valid(_desktop_breach_window):
		_desktop_breach_window.queue_free()


func _boss_physics(delta: float) -> void:
	if player == null:
		return
	_breach_angle += delta * (0.24 + float(current_phase) * 0.08)
	var edge_target := _edge_world_position(_edge_slot)
	var inward := (player.global_position - edge_target).normalized()
	var phase_offset := Vector2.RIGHT.rotated(_breach_angle) * lerpf(110.0, 260.0, float(current_phase) / 3.0)
	var target := edge_target + inward * lerpf(120.0, -120.0, sin(_breach_angle) * 0.5 + 0.5) + phase_offset
	velocity = velocity.lerp((target - global_position).limit_length(move_speed + float(current_phase) * 70.0), clampf(delta * 1.45, 0.0, 1.0))
	move_and_slide()
	_apply_boundary_gravity(delta)
	_update_body_visuals(delta)


func _run_attack_pattern() -> void:
	_attack_sequence += 1
	_edge_slot = (_edge_slot + 1 + current_phase) % 4
	var attack_id := _choose_attack()
	var center := _attack_center(attack_id)
	_create_attack_telegraph(center, _telegraph_radius(attack_id), _attack_color(attack_id), attack_id)
	breach_attack_started.emit(attack_id, {
		"phase": current_phase,
		"sequence": _attack_sequence,
		"position": center,
	})
	await get_tree().create_timer(breach_telegraph_time).timeout
	if is_queued_for_deletion() or get_parent() == null:
		return
	match attack_id:
		&"moving_singularity":
			_attack_moving_singularity(center)
		&"moon_fragment_orbit":
			_attack_moon_fragment_orbit(center)
		&"slipstream_corridor":
			_attack_slipstream_corridor(center)
		&"unstable_wormhole":
			_attack_unstable_wormhole(center)
		&"outside_space_breach":
			_attack_outside_space_breach(center)
		&"timeline_slam":
			_attack_timeline_slam(center)
		_:
			_attack_moving_singularity(center)
	_request_camera_shake(0.28 + float(current_phase) * 0.16)


func _on_enter_phase(phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(1.05, attack_interval - 0.34 * float(phase - 1))
	if _core != null:
		_core.color = [
			Color(0.52, 0.9, 1.0, 1.0),
			Color(0.92, 0.42, 1.0, 1.0),
			Color(1.0, 0.74, 0.2, 1.0),
		][phase - 1]
	_pulse_distortion(&"phase_escalation")


func on_damage_taken(_amount: float) -> void:
	_breach_angle += 0.12
	if _eye_ring != null:
		var tween := create_tween()
		tween.tween_property(_eye_ring, "width", 7.0, 0.08)
		tween.tween_property(_eye_ring, "width", 3.0, 0.18)


func _choose_attack() -> StringName:
	var phase_attacks: Array[StringName] = [&"moving_singularity", &"moon_fragment_orbit", &"slipstream_corridor"]
	if current_phase >= 2:
		phase_attacks.append(&"unstable_wormhole")
		phase_attacks.append(&"outside_space_breach")
	if current_phase >= 3:
		phase_attacks.append(&"timeline_slam")
	var seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return phase_attacks[absi(hash("%d:%d:%d:%d" % [seed, current_phase, _attack_sequence, get_instance_id()])) % phase_attacks.size()]


func _attack_moving_singularity(center: Vector2) -> void:
	var direction := (player.global_position - center).normalized() if player != null else Vector2.RIGHT
	var body := DYNAMIC_BODY_SCENE.instantiate() as DynamicCelestialBody
	if body == null:
		return
	body.configure(
		DynamicCelestialBody.BodyKind.SINGULARITY,
		singularity_mass * (1.0 + 0.16 * float(current_phase - 1)),
		62.0,
		6.5,
		direction * singularity_speed * (1.0 + 0.14 * float(current_phase))
	)
	get_parent().add_child(body)
	body.global_position = center
	_active_constructs.append(body)
	_create_zone(center, 320.0, GravityResonanceManager.ZoneType.COMPRESSION, 0.72, 4.0)


func _attack_moon_fragment_orbit(center: Vector2) -> void:
	for i in range(moon_fragment_count + current_phase):
		var angle := TAU * float(i) / float(moon_fragment_count + current_phase) + _breach_angle
		var direction := Vector2.RIGHT.rotated(angle)
		_fire_projectile(center + direction * 130.0, direction.rotated(0.48), projectile_speed * 0.72)
	_create_zone(center, 420.0, GravityResonanceManager.ZoneType.HARMONIC_ORBIT, 0.68, 4.4)


func _attack_slipstream_corridor(center: Vector2) -> void:
	var axis := _player_axis()
	for offset in [-1, 0, 1]:
		var pocket := TIDE_POCKET_SCENE.instantiate()
		if pocket.has_method("configure"):
			pocket.call("configure", GravityTidePocket.TideMode.SLIPSTREAM, slipstream_lane_width, 4.8, 1120.0)
		get_parent().add_child(pocket)
		var pocket_2d := pocket as Node2D
		if pocket_2d != null:
			pocket_2d.global_position = center + axis * float(offset) * 280.0
		_active_constructs.append(pocket)
	_create_zone(center, 520.0, GravityResonanceManager.ZoneType.SLIPSTREAM, 0.76, 4.8)


func _attack_unstable_wormhole(center: Vector2) -> void:
	var wormhole := WORMHOLE_PAIR_SCENE.instantiate()
	get_parent().add_child(wormhole)
	var axis := _player_axis().orthogonal()
	var a := center - axis * 520.0
	var b := _edge_world_position(_edge_slot + 2) + axis * 140.0
	if wormhole.has_method("set_endpoint_positions"):
		wormhole.call("set_endpoint_positions", a, b)
	_active_constructs.append(wormhole)
	get_tree().create_timer(6.0).timeout.connect(Callable(self, "_queue_free_if_valid").bind(wormhole))
	_create_zone(a, 240.0, GravityResonanceManager.ZoneType.TEMPORAL_SCAR, 0.62, 4.2)
	_create_zone(b, 260.0, GravityResonanceManager.ZoneType.INVERSION, 0.58, 4.2)


func _attack_outside_space_breach(center: Vector2) -> void:
	_open_desktop_breach_window(center)
	var root := Node2D.new()
	root.name = "BreacherOutsideSpaceSection"
	root.z_index = 45
	var root_parent := get_parent()
	if root_parent == null:
		return
	root_parent.add_child(root)
	root.global_position = _edge_world_position(_edge_slot)
	var direction := (center - root.global_position).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	for i in range(3):
		var limb := Line2D.new()
		limb.name = "OutsideSpaceLimb%d" % i
		limb.antialiased = true
		limb.width = 8.0 - float(i)
		limb.default_color = _safe_color(Color(0.92, 0.34, 1.0, 1.0), 0.62)
		limb.points = PackedVector2Array([
			Vector2.ZERO,
			direction.rotated(-0.22 + float(i) * 0.22) * 460.0,
			direction.rotated(-0.1 + float(i) * 0.14) * 680.0,
		])
		root.add_child(limb)
	_active_constructs.append(root)
	get_tree().create_timer(3.6).timeout.connect(Callable(self, "_queue_free_if_valid").bind(root))
	_apply_breach_slam(center, direction)
	_create_fracture(center)


func _open_desktop_breach_window(center: Vector2) -> bool:
	if not enable_desktop_breach_window or not _is_desktop_os():
		return false
	if _desktop_breach_window != null and is_instance_valid(_desktop_breach_window):
		_desktop_breach_window.queue_free()

	var window := Window.new()
	window.name = "BreacherDesktopWindow"
	window.title = "VECTOR BREACH"
	window.size = desktop_breach_window_size
	window.always_on_top = true
	window.unresizable = false
	var screen_size := DisplayServer.screen_get_size()
	window.position = Vector2i(
		clampi(screen_size.x - desktop_breach_window_size.x - 48, 0, maxi(screen_size.x - desktop_breach_window_size.x, 0)),
		clampi(64 + (_edge_slot % 3) * 82, 0, maxi(screen_size.y - desktop_breach_window_size.y, 0))
	)
	get_tree().root.add_child(window)
	_desktop_breach_window = window

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.0, 0.055, 0.96)
	window.add_child(backdrop)

	var label := Label.new()
	label.text = "BOUNDARY BREACH\nTHE BOSS IS OUTSIDE THE ARENA"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.26, 1.0))
	window.add_child(label)

	var timer := get_tree().create_timer(maxf(desktop_breach_window_lifetime, 0.5))
	timer.timeout.connect(Callable(self, "_queue_free_if_valid").bind(window))
	_pulse_distortion(&"desktop_window_breach")
	return true


func _attack_timeline_slam(center: Vector2) -> void:
	_apply_slow_to_targets(center, distortion_radius, 0.42, 0.9)
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(_breach_angle + TAU * float(i) / 8.0)
		_fire_projectile(center, direction, projectile_speed * 0.92)
	_create_zone(center, 520.0, GravityResonanceManager.ZoneType.TEMPORAL_SCAR, 0.82, 3.8)
	_pulse_distortion(&"timeline_slam")


func _apply_breach_slam(center: Vector2, direction: Vector2) -> void:
	_fill_targets(center, distortion_radius)
	for target in _target_buffer:
		var offset := target.global_position - center
		var falloff := 1.0 - clampf(offset.length() / maxf(distortion_radius, 1.0), 0.0, 1.0)
		CombatStatus.add_velocity(target, direction * lerpf(180.0, 720.0, falloff))
		if target.is_in_group("Player") and target.has_method("take_damage") and offset.length() < 140.0:
			target.call("take_damage", contact_damage)


func _apply_boundary_gravity(delta: float) -> void:
	_fill_targets(global_position, distortion_radius)
	for target in _target_buffer:
		if target == self:
			continue
		var offset := global_position - target.global_position
		var distance := maxf(offset.length(), 80.0)
		var radial := offset / distance
		var tangent := radial.orthogonal() * (1.0 if current_phase % 2 == 1 else -1.0)
		var force = (radial * 0.42 + tangent * 0.58).normalized() * mass * 0.0012 / distance
		if target.is_in_group("bosses"):
			continue
		CombatStatus.add_velocity(target, force * delta * (0.7 + float(current_phase) * 0.2))


func _create_fracture(position: Vector2) -> void:
	var scar_manager := _find_scene_node("GravityScarManager")
	if scar_manager != null and scar_manager.has_method("create_gravity_scar"):
		scar_manager.call(
			"create_gravity_scar",
			position,
			360.0,
			GravityScarManager.ScarType.HARMONIC_FRACTURE,
			0.78,
			8.0,
			&"extradimensional_breacher"
		)
	var reality := _find_scene_node("RealityCollapseDirector")
	if reality != null and reality.has_method("force_reality_breach"):
		reality.call("force_reality_breach", &"screen_edge_breach")


func _create_zone(position: Vector2, radius: float, zone_type: int, intensity: float, duration: float) -> void:
	var resonance := _find_scene_node("GravityResonanceManager")
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		resonance.call("create_manual_resonance_zone", position, radius, zone_type, intensity, duration)


func _apply_slow_to_targets(center: Vector2, radius: float, multiplier: float, duration: float) -> void:
	var time_manager := _find_scene_node("TimeDilationManager")
	_fill_targets(center, radius)
	for target in _target_buffer:
		if target.is_in_group("Player"):
			continue
		if time_manager != null and time_manager.has_method("apply_local_slow_to_target"):
			time_manager.call("apply_local_slow_to_target", target, multiplier, duration)
		else:
			CombatStatus.apply_local_slow(target, multiplier, duration)


func _fill_targets(center: Vector2, radius: float) -> void:
	_target_buffer.clear()
	var groups: Array[StringName] = [&"Player", &"enemies", &"wave_enemy", &"Projectiles", &"enemy_projectiles"]
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(groups, center, radius, max_targets_per_attack, true, _target_buffer)
		return
	var radius_sq := radius * radius
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d := node as Node2D
			if node_2d == null or node_2d == self or node_2d.global_position.distance_squared_to(center) > radius_sq:
				continue
			_target_buffer.append(node_2d)
			if _target_buffer.size() >= max_targets_per_attack:
				return


func _fire_projectile(position: Vector2, direction: Vector2, speed: float) -> void:
	if get_parent() == null or not BulletManager.can_spawn_bullet():
		return
	var bullet := ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = position
	bullet.global_rotation = direction.angle()
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction.normalized(), speed, self)
	elif bullet.get("initial_speed") != null:
		bullet.set("initial_speed", speed)
	get_parent().call_deferred("add_child", bullet)


func _attack_center(attack_id: StringName) -> Vector2:
	if player == null:
		return global_position
	if attack_id == &"outside_space_breach":
		return player.global_position + _player_axis().orthogonal() * 220.0
	if attack_id == &"unstable_wormhole":
		return player.global_position + _player_axis() * 360.0
	return player.global_position + _player_axis() * 520.0


func _telegraph_radius(attack_id: StringName) -> float:
	match attack_id:
		&"moving_singularity":
			return 260.0
		&"moon_fragment_orbit":
			return 420.0
		&"slipstream_corridor":
			return 560.0
		&"unstable_wormhole":
			return 340.0
		&"timeline_slam":
			return 620.0
	return 480.0


func _create_attack_telegraph(position: Vector2, radius: float, color: Color, attack_id: StringName) -> void:
	var root := Node2D.new()
	root.name = "BreacherTelegraph_%s" % String(attack_id)
	root.z_index = 39
	var root_parent := get_parent()
	if root_parent == null:
		return
	root_parent.add_child(root)
	root.global_position = position
	_active_constructs.append(root)
	var ring := Line2D.new()
	ring.closed = true
	ring.antialiased = true
	ring.width = 3.0
	ring.default_color = _safe_color(color, 0.72)
	ring.points = _circle_points(radius, 60)
	root.add_child(ring)
	var line := Line2D.new()
	line.antialiased = true
	line.width = 2.4
	line.default_color = _safe_color(Color.WHITE, 0.62)
	line.points = PackedVector2Array([Vector2(-radius, 0.0), Vector2(radius, 0.0)])
	root.add_child(line)
	_telegraphs.append(root)
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector2(0.72, 0.72), breach_telegraph_time)
	tween.parallel().tween_property(root, "modulate:a", 0.0, breach_telegraph_time)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(root))


func _build_body() -> void:
	_hull = Polygon2D.new()
	_hull.name = "BreacherHull"
	_hull.color = Color(0.035, 0.018, 0.065, 0.92)
	_hull.polygon = PackedVector2Array([
		Vector2(0.0, -170.0),
		Vector2(138.0, -92.0),
		Vector2(182.0, 20.0),
		Vector2(72.0, 142.0),
		Vector2(0.0, 190.0),
		Vector2(-72.0, 142.0),
		Vector2(-182.0, 20.0),
		Vector2(-138.0, -92.0),
	])
	add_child(_hull)

	_core = Polygon2D.new()
	_core.name = "BreacherCore"
	_core.color = Color(0.52, 0.9, 1.0, 1.0)
	_core.polygon = _circle_points(58.0, 11)
	add_child(_core)

	_eye_ring = Line2D.new()
	_eye_ring.name = "BreacherEyeRing"
	_eye_ring.closed = true
	_eye_ring.antialiased = true
	_eye_ring.width = 3.0
	_eye_ring.default_color = Color(1.0, 0.82, 0.24, 0.86)
	_eye_ring.points = _circle_points(86.0, 40)
	add_child(_eye_ring)

	for i in range(4):
		var limb := Line2D.new()
		limb.name = "BoundaryLimb%d" % i
		limb.antialiased = true
		limb.width = 5.0
		limb.default_color = _safe_color(Color(0.85, 0.32, 1.0, 1.0), 0.36)
		limb.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(TAU * float(i) / 4.0) * 250.0])
		limb.z_index = -1
		add_child(limb)
		_breach_limbs.append(limb)

	if not has_node("CollisionPolygon2D"):
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = _hull.polygon
		add_child(collision)


func _update_body_visuals(delta: float) -> void:
	if _core != null:
		_core.rotation -= delta * (0.9 + float(current_phase) * 0.2)
		_core.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() / 95.0) * 0.04)
	if _eye_ring != null:
		_eye_ring.rotation += delta * (0.6 + float(current_phase) * 0.18)
	for i in range(_breach_limbs.size()):
		var limb := _breach_limbs[i]
		if limb != null:
			limb.rotation = _breach_angle * (0.4 + float(i) * 0.08) + TAU * float(i) / 4.0


func _pulse_distortion(source: StringName) -> void:
	breacher_distortion_pulsed.emit({
		"source": source,
		"phase": current_phase,
		"position": global_position,
		"intensity": clampf(0.35 + float(current_phase) * 0.22, 0.0, 1.0),
	})
	_request_camera_shake(0.2 + float(current_phase) * 0.12)


func _edge_world_position(slot: int) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return player.global_position if player != null else global_position
	var screen_pos := Vector2.ZERO
	match slot % 4:
		0:
			screen_pos = Vector2(-outside_edge_distance, viewport_size.y * 0.22)
		1:
			screen_pos = Vector2(viewport_size.x + outside_edge_distance, viewport_size.y * 0.38)
		2:
			screen_pos = Vector2(viewport_size.x * 0.72, -outside_edge_distance)
		_:
			screen_pos = Vector2(viewport_size.x * 0.28, viewport_size.y + outside_edge_distance)
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _player_axis() -> Vector2:
	if player == null:
		return Vector2.RIGHT
	var velocity_value: Variant = player.get("velocity")
	if velocity_value is Vector2:
		var velocity_vector := velocity_value as Vector2
		if velocity_vector.length_squared() > 1.0:
			return velocity_vector.normalized()
	var direction := player.global_position - global_position
	if direction.length_squared() <= 0.001:
		return Vector2.RIGHT
	return direction.normalized()


func _find_scene_node(node_name: String) -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child(node_name, true, false)


func _request_camera_shake(amount: float) -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D")
	if camera == null:
		return
	var shake := camera.get_node_or_null("DamageCameraShake")
	if shake != null and shake.has_method("add_trauma"):
		shake.call("add_trauma", amount)


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	if node == _desktop_breach_window:
		_desktop_breach_window = null


func _is_desktop_os() -> bool:
	var os_name := OS.get_name()
	return os_name == "Windows" or os_name == "macOS" or os_name == "Linux" or os_name == "FreeBSD"


func _attack_color(attack_id: StringName) -> Color:
	match attack_id:
		&"moving_singularity":
			return Color(0.84, 0.36, 1.0, 1.0)
		&"moon_fragment_orbit":
			return Color(1.0, 0.76, 0.22, 1.0)
		&"slipstream_corridor":
			return Color(0.24, 1.0, 0.78, 1.0)
		&"unstable_wormhole":
			return Color(0.72, 0.42, 1.0, 1.0)
		&"timeline_slam":
			return Color(0.42, 0.92, 1.0, 1.0)
	return Color(1.0, 0.34, 0.16, 1.0)


func _safe_color(color: Color, alpha_cap: float) -> Color:
	var alpha := minf(color.a, alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
