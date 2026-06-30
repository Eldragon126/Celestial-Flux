extends StaticBody2D
class_name CampaignMothership

signal docking_requested(mothership: CampaignMothership)
signal hostile_alert(mothership: CampaignMothership, target: Node2D)
signal support_action_emitted(mothership: CampaignMothership, target: Node2D, action: StringName, amount: float)
signal mothership_destroyed(mothership: CampaignMothership, reward: int)
signal movement_state_changed(mothership: CampaignMothership, state: StringName)

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

enum Faction {
	FRIENDLY,
	TRADER,
	NEUTRAL,
	HOSTILE,
}

@export_enum("Friendly", "Trader", "Neutral", "Hostile") var faction: int = Faction.TRADER:
	set(value):
		faction = clampi(value, Faction.FRIENDLY, Faction.HOSTILE)
		_apply_faction_palette()
@export var callsign: String = "FREEHOLD CARRIER"
@export var docking_radius: float = 300.0
@export var prompt_radius: float = 460.0
@export var max_health: float = 260.0
@export var reward_credits: int = 32
@export var hull_radius: float = 76.0
@export var drift_radius: float = 42.0
@export var drift_speed: float = 0.24
@export var friendly_color: Color = Color(0.32, 1.0, 0.78, 0.95)
@export var trader_color: Color = Color(1.0, 0.78, 0.32, 0.95)
@export var neutral_color: Color = Color(0.62, 0.82, 1.0, 0.9)
@export var hostile_color: Color = Color(1.0, 0.22, 0.12, 0.96)
@export_group("Visual Polish")
@export var core_color: Color = Color(0.82, 1.0, 0.92, 0.94)
@export var beacon_radius: float = 98.0
@export var faction_beacon_segments: int = 48
@export_group("Hostile Attack")
@export var hostile_attack_range: float = 1350.0
@export var hostile_fire_interval: float = 1.25
@export var hostile_projectile_speed: float = 920.0
@export var bullet_scene: PackedScene = ENEMY_BULLET_SCENE
@export var use_global_bullet_budget: bool = true
@export_group("Friendly Support")
@export var support_enabled: bool = true
@export var support_scan_interval: float = 0.28
@export var support_attack_range: float = 1550.0
@export var support_fire_interval: float = 1.05
@export var support_damage: float = 18.0
@export var support_repair_radius: float = 920.0
@export var support_repair_per_second: float = 14.0
@export var support_beam_lifetime: float = 0.14
@export var support_beam_width: float = 3.5
@export var support_beam_color: Color = Color(0.44, 1.0, 0.84, 0.74)
@export_group("Smart Movement")
@export var movement_enabled: bool = true
@export var movement_max_speed: float = 260.0
@export var movement_acceleration: float = 760.0
@export var movement_drag: float = 0.92
@export var orbit_radius_min: float = 2600.0
@export var orbit_radius_max: float = 5800.0
@export var orbit_angular_speed: float = 0.028
@export var arrival_radius: float = 320.0
@export var allied_support_standoff: float = 980.0
@export var hostile_pursuit_range: float = 2600.0
@export var hostile_standoff_distance: float = 1120.0
@export var dock_hold_radius: float = 420.0
@export var damaged_retreat_health_ratio: float = 0.32
@export var retreat_distance: float = 980.0
@export var separation_radius: float = 920.0
@export var separation_strength: float = 620.0
@export var anchor_leash_extra: float = 900.0
@export var movement_debug_state_label: bool = false
@export_group("Advanced Maneuvers")
@export var advanced_maneuvers_enabled: bool = true
@export var maneuver_replan_min: float = 4.8
@export var maneuver_replan_max: float = 8.4
@export_range(0.0, 0.85, 0.01) var maneuver_orbit_eccentricity: float = 0.34
@export var maneuver_gravity_dip: float = 760.0
@export var maneuver_lateral_burn: float = 620.0
@export var maneuver_radial_burn: float = 720.0
@export var maneuver_support_lead_time: float = 0.8
@export var maneuver_hostile_flank_angle: float = 0.86
@export var maneuver_hostile_feint_distance: float = 680.0
@export var maneuver_near_dock_speed_scale: float = 0.34
@export var show_maneuver_vector: bool = true
@export var maneuver_vector_length: float = 220.0
@export_range(0.0, 1.0, 0.01) var maneuver_vector_alpha: float = 0.34
@export var maneuver_vector_color: Color = Color(0.48, 1.0, 0.86, 0.34)

var current_health: float = 0.0
var _anchor_node: Node2D = null
var _anchor_position := Vector2.ZERO
var _seed_phase: float = 0.0
var _elapsed: float = 0.0
var _fire_elapsed: float = 0.0
var _support_scan_elapsed: float = 999.0
var _support_fire_elapsed: float = 0.0
var _support_beam_alpha: float = 0.0
var _movement_velocity := Vector2.ZERO
var _orbit_radius: float = 0.0
var _orbit_angle: float = 0.0
var _orbit_direction: float = 1.0
var _movement_state: StringName = &"orbit"
var _maneuver_state: StringName = &"distant_orbit"
var _maneuver_elapsed: float = 999.0
var _maneuver_duration: float = 6.0
var _maneuver_axis_angle: float = 0.0
var _maneuver_target_position := Vector2.ZERO
var _player: Node2D = null
var _support_target: Node2D = null
var _hull: Polygon2D = null
var _core: Polygon2D = null
var _spine: Line2D = null
var _ring: Line2D = null
var _beacon: Line2D = null
var _support_beam: Line2D = null
var _maneuver_vector: Line2D = null
var _dock_area: Area2D = null
var _collision: CollisionShape2D = null
var _body_collision: CollisionShape2D = null
var _prompt_label: Label = null
var _destroyed: bool = false
var _query_targets: Array[Node2D] = []


func configure(index: int, faction_id: int, anchor: Node2D = null, seed_value: int = 0) -> void:
	faction = faction_id
	callsign = _callsign_for_index(index)
	_anchor_node = anchor
	_anchor_position = anchor.global_position if anchor != null else global_position
	_seed_phase = float(abs(seed_value % 1000)) * 0.00628 + float(index) * 0.72
	_orbit_radius = clampf(global_position.distance_to(_anchor_position), orbit_radius_min, orbit_radius_max)
	_orbit_angle = (global_position - _anchor_position).angle() if global_position.distance_squared_to(_anchor_position) > 4.0 else _seed_phase
	_orbit_direction = -1.0 if index % 2 == 0 else 1.0
	_maneuver_axis_angle = _orbit_angle + _seed_phase * 0.17


func _ready() -> void:
	add_to_group("campaign_mothership")
	add_to_group("player_allies" if faction != Faction.HOSTILE else "enemies")
	current_health = max_health
	if _anchor_position == Vector2.ZERO:
		_anchor_position = global_position
	if _orbit_radius <= 0.0:
		_orbit_radius = clampf(global_position.distance_to(_anchor_position), orbit_radius_min, orbit_radius_max)
	_orbit_angle = (global_position - _anchor_position).angle() if global_position.distance_squared_to(_anchor_position) > 4.0 else _seed_phase
	_build_runtime_nodes()
	_apply_faction_palette()
	_replan_maneuver(true)
	_register_runtime_groups()
	set_process(true)


func _exit_tree() -> void:
	_unregister_runtime_groups()


func _process(delta: float) -> void:
	if _destroyed:
		return
	_elapsed += delta
	_fire_elapsed += delta
	_support_scan_elapsed += delta
	_support_fire_elapsed += delta
	_player = MultiplayerTargeting.local_player(get_tree())
	_update_movement(delta)
	_update_prompt()
	if faction == Faction.HOSTILE:
		_update_hostile_attack()
	else:
		_update_support_behavior(delta)
	_update_support_beam(delta)


func take_damage(amount: float) -> void:
	if _destroyed or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	_emit_damage_feedback(amount)
	_apply_faction_palette()
	if current_health <= 0.0:
		_destroy_mothership()


func is_hostile() -> bool:
	return faction == Faction.HOSTILE


func docking_status_text() -> String:
	match faction:
		Faction.FRIENDLY:
			return "%s // allied repair dock" % callsign
		Faction.TRADER:
			return "%s // energy-credit trader" % callsign
		Faction.NEUTRAL:
			return "%s // cautious freehold" % callsign
	return "%s // hostile carrier" % callsign


func _build_runtime_nodes() -> void:
	if _body_collision == null:
		_body_collision = get_node_or_null("HullCollision") as CollisionShape2D
	if _body_collision == null:
		_body_collision = CollisionShape2D.new()
		_body_collision.name = "HullCollision"
		var hull_shape := CircleShape2D.new()
		hull_shape.radius = hull_radius
		_body_collision.shape = hull_shape
		add_child(_body_collision)
	elif _body_collision.shape is CircleShape2D:
		(_body_collision.shape as CircleShape2D).radius = hull_radius

	if _dock_area == null:
		_dock_area = get_node_or_null("DockingArea") as Area2D
	if _dock_area == null:
		_dock_area = Area2D.new()
		_dock_area.name = "DockingArea"
		add_child(_dock_area)
	if _collision == null and _dock_area != null:
		_collision = _dock_area.get_node_or_null("DockingShape") as CollisionShape2D
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "DockingShape"
		var shape := CircleShape2D.new()
		shape.radius = docking_radius
		_collision.shape = shape
		_dock_area.add_child(_collision)
	elif _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = docking_radius

	if _hull == null:
		_hull = get_node_or_null("MothershipHull") as Polygon2D
	if _hull == null:
		_hull = Polygon2D.new()
		_hull.name = "MothershipHull"
		_hull.polygon = PackedVector2Array([
			Vector2(86.0, 0.0),
			Vector2(28.0, 34.0),
			Vector2(-72.0, 48.0),
			Vector2(-92.0, 0.0),
			Vector2(-72.0, -48.0),
			Vector2(28.0, -34.0),
		])
		add_child(_hull)
	if _core == null:
		_core = get_node_or_null("MothershipCore") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "MothershipCore"
		_core.polygon = PackedVector2Array([
			Vector2(42.0, 0.0),
			Vector2(12.0, 16.0),
			Vector2(-34.0, 18.0),
			Vector2(-48.0, 0.0),
			Vector2(-34.0, -18.0),
			Vector2(12.0, -16.0),
		])
		add_child(_core)
	if _spine == null:
		_spine = get_node_or_null("MothershipSpine") as Line2D
	if _spine == null:
		_spine = Line2D.new()
		_spine.name = "MothershipSpine"
		_spine.antialiased = true
		_spine.width = 3.0
		_spine.points = PackedVector2Array([
			Vector2(-74.0, -30.0),
			Vector2(-18.0, -13.0),
			Vector2(64.0, 0.0),
			Vector2(-18.0, 13.0),
			Vector2(-74.0, 30.0),
		])
		add_child(_spine)
	if _ring == null:
		_ring = get_node_or_null("MothershipDockRing") as Line2D
	if _ring == null:
		_ring = Line2D.new()
		_ring.name = "MothershipDockRing"
		_ring.closed = true
		_ring.antialiased = true
		_ring.width = 2.0
		_ring.points = _circle_points(72, docking_radius)
		add_child(_ring)
	if _beacon == null:
		_beacon = get_node_or_null("FactionBeacon") as Line2D
	if _beacon == null:
		_beacon = Line2D.new()
		_beacon.name = "FactionBeacon"
		_beacon.closed = true
		_beacon.antialiased = true
		_beacon.width = 1.5
		_beacon.points = _circle_points(faction_beacon_segments, beacon_radius)
		add_child(_beacon)
	if _support_beam == null:
		_support_beam = get_node_or_null("SupportBeam") as Line2D
	if _support_beam == null:
		_support_beam = Line2D.new()
		_support_beam.name = "SupportBeam"
		_support_beam.antialiased = true
		_support_beam.width = support_beam_width
		_support_beam.visible = false
		_support_beam.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		add_child(_support_beam)
	if _maneuver_vector == null:
		_maneuver_vector = get_node_or_null("ManeuverVector") as Line2D
	if _maneuver_vector == null:
		_maneuver_vector = Line2D.new()
		_maneuver_vector.name = "ManeuverVector"
		_maneuver_vector.antialiased = true
		_maneuver_vector.width = 2.0
		_maneuver_vector.visible = false
		_maneuver_vector.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		add_child(_maneuver_vector)
	if _prompt_label == null:
		_prompt_label = get_node_or_null("DockPrompt") as Label
	if _prompt_label == null:
		_prompt_label = Label.new()
		_prompt_label.name = "DockPrompt"
		_prompt_label.position = Vector2(-150.0, -128.0)
		_prompt_label.custom_minimum_size = Vector2(300.0, 28.0)
		_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt_label.add_theme_font_size_override("font_size", 15)
		_prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
		_prompt_label.add_theme_constant_override("outline_size", 4)
		_prompt_label.visible = false
		add_child(_prompt_label)


func _apply_faction_palette() -> void:
	if _hull == null or _ring == null:
		return
	var base := _faction_color()
	var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	_hull.color = Color(base.r, base.g, base.b, base.a).lerp(Color(1.0, 0.12, 0.08, base.a), 1.0 - health_ratio)
	_ring.default_color = Color(base.r, base.g, base.b, 0.42 if faction != Faction.HOSTILE else 0.58)
	if _core != null:
		_core.color = core_color.lerp(base, 0.42)
		_core.modulate.a = 0.76 + health_ratio * 0.18
	if _spine != null:
		_spine.default_color = Color(base.r, base.g, base.b, 0.58)
	if _beacon != null:
		_beacon.default_color = Color(base.r, base.g, base.b, 0.24 if faction != Faction.HOSTILE else 0.42)


func _update_movement(delta: float) -> void:
	_refresh_anchor_position()
	if not movement_enabled:
		_update_legacy_drift(delta)
		return
	_update_maneuver_plan(delta)
	_orbit_angle += orbit_angular_speed * _orbit_direction * delta
	var target_info := _movement_target()
	var desired_value: Variant = target_info.get("position", global_position)
	var desired_position: Vector2 = desired_value if desired_value is Vector2 else global_position
	var speed_scale := float(target_info.get("speed_scale", 1.0))
	var state_value: Variant = target_info.get("state", &"orbit")
	var state = state_value if state_value is StringName else StringName(str(state_value))
	_set_movement_state(state)
	_maneuver_target_position = desired_position

	var to_target := desired_position - global_position
	var distance := to_target.length()
	var desired_velocity := Vector2.ZERO
	if distance > 2.0:
		var arrival_scale := clampf(distance / maxf(arrival_radius, 1.0), 0.18, 1.0)
		desired_velocity = to_target / distance * movement_max_speed * speed_scale * arrival_scale
	desired_velocity += _separation_velocity()
	desired_velocity = _apply_anchor_leash(desired_velocity)
	_movement_velocity = _movement_velocity.move_toward(desired_velocity, movement_acceleration * delta)
	_movement_velocity *= pow(clampf(movement_drag, 0.01, 1.0), delta * 60.0)
	_movement_velocity = _movement_velocity.limit_length(movement_max_speed * maxf(speed_scale, 0.25))
	global_position += _movement_velocity * delta
	if _movement_velocity.length_squared() > 9.0:
		rotation = lerp_angle(rotation, _movement_velocity.angle(), clampf(delta * 3.2, 0.0, 1.0))
	else:
		rotation = lerp_angle(rotation, sin(_elapsed * 0.18 + _seed_phase) * 0.045, clampf(delta * 2.0, 0.0, 1.0))
	if _ring != null:
		_ring.rotation += delta * (0.18 if faction != Faction.HOSTILE else -0.32)
	if _beacon != null:
		_beacon.rotation -= delta * (0.11 if faction != Faction.HOSTILE else 0.38)
	if _core != null:
		_core.scale = Vector2.ONE * (1.0 + sin(_elapsed * 1.6 + _seed_phase) * 0.018)
	_update_maneuver_vector()


func _update_legacy_drift(delta: float) -> void:
	var offset := Vector2(cos(_elapsed * drift_speed + _seed_phase), sin(_elapsed * drift_speed * 0.73 + _seed_phase)) * drift_radius
	global_position = global_position.lerp(_anchor_position + offset, clampf(delta * 0.9, 0.0, 1.0))
	rotation = sin(_elapsed * 0.18 + _seed_phase) * 0.045


func _movement_target() -> Dictionary:
	var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var threat := _movement_threat()
	if health_ratio <= damaged_retreat_health_ratio and threat != null:
		var retreat_direction := (global_position - threat.global_position).normalized()
		if retreat_direction.length_squared() < 0.001:
			retreat_direction = (global_position - _anchor_position).normalized()
		if retreat_direction.length_squared() < 0.001:
			retreat_direction = Vector2.RIGHT.rotated(_seed_phase)
		return {
			"position": _anchor_position + retreat_direction * minf(_orbit_radius + retreat_distance, orbit_radius_max + anchor_leash_extra),
			"state": &"retreat",
			"speed_scale": 1.15,
		}
	if faction == Faction.HOSTILE and _player != null and is_instance_valid(_player):
		if advanced_maneuvers_enabled:
			return _hostile_maneuver_target()
		if global_position.distance_to(_player.global_position) > hostile_pursuit_range:
			return {
				"position": _orbit_position(),
				"state": &"hostile_patrol",
				"speed_scale": 0.9,
			}
		var to_ship := global_position - _player.global_position
		var direction := to_ship.normalized() if to_ship.length_squared() > 0.001 else Vector2.RIGHT.rotated(_seed_phase)
		return {
			"position": _player.global_position + direction * hostile_standoff_distance,
			"state": &"hostile_standoff",
			"speed_scale": 1.05,
		}
	if faction != Faction.HOSTILE and _player != null and is_instance_valid(_player):
		var dock_distance := global_position.distance_to(_player.global_position)
		if dock_distance <= dock_hold_radius:
			return {
				"position": global_position,
				"state": &"dock_hold",
				"speed_scale": maneuver_near_dock_speed_scale,
			}
	if faction == Faction.FRIENDLY or faction == Faction.TRADER:
		var support_target := _support_target if _support_target != null and is_instance_valid(_support_target) and not _support_target.is_queued_for_deletion() else _nearest_support_target()
		if support_target != null:
			if advanced_maneuvers_enabled:
				return _support_maneuver_target(support_target)
			var support_offset := global_position - support_target.global_position
			var support_direction := support_offset.normalized() if support_offset.length_squared() > 0.001 else (_anchor_position - support_target.global_position).normalized()
			if support_direction.length_squared() < 0.001:
				support_direction = Vector2.RIGHT.rotated(_seed_phase)
			return {
				"position": support_target.global_position + support_direction * allied_support_standoff,
				"state": &"support",
				"speed_scale": 1.0,
			}
	return {
		"position": _advanced_orbit_position() if advanced_maneuvers_enabled else _orbit_position(),
		"state": _maneuver_state if advanced_maneuvers_enabled else &"orbit",
		"speed_scale": _maneuver_speed_scale() if advanced_maneuvers_enabled else 0.82,
	}


func _movement_threat() -> Node2D:
	if faction == Faction.HOSTILE:
		if _player != null and is_instance_valid(_player):
			return _player
		return null
	if faction != Faction.HOSTILE and _support_target != null and is_instance_valid(_support_target) and not _support_target.is_queued_for_deletion():
		return _support_target
	return _nearest_support_target()


func _orbit_position() -> Vector2:
	var radius := clampf(_orbit_radius + sin(_elapsed * 0.19 + _seed_phase) * drift_radius, orbit_radius_min, orbit_radius_max)
	return _anchor_position + Vector2.RIGHT.rotated(_orbit_angle) * radius


func _update_maneuver_plan(delta: float) -> void:
	if not advanced_maneuvers_enabled:
		return
	_maneuver_elapsed += delta
	if _maneuver_elapsed >= _maneuver_duration:
		_replan_maneuver(false)


func _replan_maneuver(force: bool = false) -> void:
	_maneuver_elapsed = 0.0
	var duration_blend := 0.5 + sin(_elapsed * 0.37 + _seed_phase) * 0.5
	_maneuver_duration = lerpf(maneuver_replan_min, maneuver_replan_max, duration_blend)
	_maneuver_axis_angle = _orbit_angle + sin(_elapsed * 0.11 + _seed_phase) * 0.9
	var options := _maneuver_options()
	if options.is_empty():
		_maneuver_state = &"distant_orbit"
		return
	var index_seed := _seed_phase if force else _elapsed + _seed_phase * 1.7
	var option_index := int(abs(sin(index_seed * 1.913) * 1000.0)) % options.size()
	_maneuver_state = options[option_index]


func _maneuver_options() -> Array[StringName]:
	if faction == Faction.HOSTILE:
		return [&"pincer_vector", &"false_retreat", &"gravity_shear", &"distant_orbit"]
	if faction == Faction.FRIENDLY or faction == Faction.TRADER:
		return [&"distant_orbit", &"gravity_shear", &"support_perch", &"radial_burn"]
	return [&"distant_orbit", &"gravity_shear", &"radial_burn"]


func _advanced_orbit_position() -> Vector2:
	match _maneuver_state:
		&"gravity_shear":
			return _gravity_shear_position()
		&"radial_burn":
			return _radial_burn_position()
		&"false_retreat":
			return _radial_burn_position(1.0)
	var radius := clampf(_orbit_radius + sin(_elapsed * 0.17 + _seed_phase) * drift_radius * 3.0, orbit_radius_min, orbit_radius_max)
	var axis_ratio := clampf(1.0 - maneuver_orbit_eccentricity, 0.15, 1.0)
	var angle := _orbit_angle + sin(_elapsed * 0.09 + _seed_phase) * 0.2
	var local := Vector2(cos(angle) * radius, sin(angle) * radius * axis_ratio)
	return _anchor_position + local.rotated(_maneuver_axis_angle)


func _gravity_shear_position() -> Vector2:
	var progress := clampf(_maneuver_elapsed / maxf(_maneuver_duration, 0.01), 0.0, 1.0)
	var angle := _orbit_angle + _orbit_direction * lerpf(-0.7, 1.15, progress)
	var radius := clampf(_orbit_radius - maneuver_gravity_dip * sin(progress * PI), orbit_radius_min * 0.72, orbit_radius_max)
	var tangent := Vector2.RIGHT.rotated(angle + PI * 0.5 * _orbit_direction)
	var lateral := tangent * maneuver_lateral_burn * sin(progress * PI)
	return _anchor_position + Vector2.RIGHT.rotated(angle) * radius + lateral


func _radial_burn_position(direction_scale: float = -1.0) -> Vector2:
	var progress := clampf(_maneuver_elapsed / maxf(_maneuver_duration, 0.01), 0.0, 1.0)
	var radius := clampf(_orbit_radius + maneuver_radial_burn * direction_scale * sin(progress * PI), orbit_radius_min, orbit_radius_max + anchor_leash_extra * 0.35)
	var angle := _orbit_angle + _orbit_direction * progress * 0.55
	return _anchor_position + Vector2.RIGHT.rotated(angle) * radius


func _support_maneuver_target(support_target: Node2D) -> Dictionary:
	var target_velocity := _node_velocity(support_target)
	var lead_position := support_target.global_position + target_velocity * maneuver_support_lead_time
	if _maneuver_state == &"gravity_shear":
		return {
			"position": _gravity_shear_position().lerp(lead_position, 0.42),
			"state": &"support_shear",
			"speed_scale": 1.08,
		}
	var from_anchor := lead_position - _anchor_position
	var direction := from_anchor.normalized() if from_anchor.length_squared() > 0.001 else Vector2.RIGHT.rotated(_seed_phase)
	var flank := direction.rotated(_orbit_direction * 0.72)
	var standoff := allied_support_standoff
	if _maneuver_state == &"support_perch":
		standoff *= 0.72
	elif _maneuver_state == &"radial_burn":
		standoff *= 1.18
	return {
		"position": lead_position + flank * standoff,
		"state": _maneuver_state if _maneuver_state != &"distant_orbit" else &"support_perch",
		"speed_scale": _maneuver_speed_scale(),
	}


func _hostile_maneuver_target() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {
			"position": _advanced_orbit_position(),
			"state": _maneuver_state,
			"speed_scale": _maneuver_speed_scale(),
		}
	if global_position.distance_to(_player.global_position) > hostile_pursuit_range:
		return {
			"position": _advanced_orbit_position(),
			"state": &"hostile_far_patrol",
			"speed_scale": 0.9,
		}
	var lead_position := _player.global_position + _node_velocity(_player) * maneuver_support_lead_time
	var from_player := global_position - lead_position
	var outward := from_player.normalized() if from_player.length_squared() > 0.001 else Vector2.RIGHT.rotated(_seed_phase)
	var flank := outward.rotated(_orbit_direction * maneuver_hostile_flank_angle).normalized()
	match _maneuver_state:
		&"pincer_vector":
			return {
				"position": lead_position + flank * hostile_standoff_distance,
				"state": &"hostile_pincer",
				"speed_scale": 1.12,
			}
		&"false_retreat":
			return {
				"position": lead_position + outward * (hostile_standoff_distance + maneuver_hostile_feint_distance),
				"state": &"hostile_feint",
				"speed_scale": 1.0,
			}
		&"gravity_shear":
			return {
				"position": _gravity_shear_position().lerp(lead_position + flank * hostile_standoff_distance, 0.36),
				"state": &"hostile_shear",
				"speed_scale": 1.18,
			}
	return {
		"position": lead_position + outward * hostile_standoff_distance,
		"state": &"hostile_standoff",
		"speed_scale": 1.02,
	}


func _maneuver_speed_scale() -> float:
	match _maneuver_state:
		&"gravity_shear":
			return 1.18
		&"radial_burn":
			return 1.08
		&"support_perch":
			return 0.94
		&"pincer_vector":
			return 1.12
		&"false_retreat":
			return 1.0
	return 0.82


func _node_velocity(node: Node) -> Vector2:
	if node == null:
		return Vector2.ZERO
	var velocity_value: Variant = node.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	return Vector2.ZERO


func _update_maneuver_vector() -> void:
	if _maneuver_vector == null:
		return
	_maneuver_vector.visible = show_maneuver_vector and movement_enabled and _movement_state != &"dock_hold"
	if not _maneuver_vector.visible:
		return
	var to_target := to_local(_maneuver_target_position)
	var length := minf(to_target.length(), maneuver_vector_length)
	var direction := to_target.normalized() if to_target.length_squared() > 0.001 else Vector2.RIGHT
	_maneuver_vector.points = PackedVector2Array([Vector2.ZERO, direction * length])
	_maneuver_vector.width = 1.6 + clampf(_movement_velocity.length() / maxf(movement_max_speed, 1.0), 0.0, 1.0) * 2.4
	var base := _faction_color().lerp(maneuver_vector_color, 0.5)
	_maneuver_vector.default_color = Color(base.r, base.g, base.b, maneuver_vector_alpha)


func _refresh_anchor_position() -> void:
	if _anchor_node != null and is_instance_valid(_anchor_node):
		_anchor_position = _anchor_node.global_position


func _separation_velocity() -> Vector2:
	if separation_radius <= 0.0 or separation_strength <= 0.0:
		return Vector2.ZERO
	var separation := Vector2.ZERO
	_query_targets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(&"campaign_mothership", _query_targets)
	else:
		for value in get_tree().get_nodes_in_group("campaign_mothership"):
			var candidate := value as Node2D
			if candidate != null:
				_query_targets.append(candidate)
	for other in _query_targets:
		if other == null or other == self or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance <= 0.001 or distance >= separation_radius:
			continue
		separation += offset / distance * (1.0 - distance / separation_radius) * separation_strength
	return separation


func _apply_anchor_leash(desired_velocity: Vector2) -> Vector2:
	var from_anchor := global_position - _anchor_position
	var leash_radius := orbit_radius_max + anchor_leash_extra
	var distance := from_anchor.length()
	if distance <= leash_radius or distance <= 0.001:
		return desired_velocity
	var return_velocity := -from_anchor / distance * movement_max_speed
	return desired_velocity.lerp(return_velocity, clampf((distance - leash_radius) / maxf(anchor_leash_extra, 1.0), 0.0, 1.0))


func _set_movement_state(state: StringName) -> void:
	if _movement_state == state:
		return
	_movement_state = state
	movement_state_changed.emit(self, state)
	if movement_debug_state_label and _prompt_label != null:
		_prompt_label.visible = true
		_prompt_label.text = "%s // %s" % [callsign, String(state).to_upper()]


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	if _player == null or not is_instance_valid(_player) or faction == Faction.HOSTILE:
		_prompt_label.visible = false
		return
	var distance := _player.global_position.distance_to(global_position)
	var close := distance <= prompt_radius
	_prompt_label.visible = close
	if close:
		_prompt_label.text = "DOCK: %s" % callsign
		if distance <= docking_radius and (Input.is_action_just_pressed("Confirm") or Input.is_action_just_pressed("ui_accept")):
			docking_requested.emit(self)


func _update_hostile_attack() -> void:
	if _player == null or not is_instance_valid(_player) or bullet_scene == null:
		return
	var to_player := _player.global_position - global_position
	if to_player.length() > hostile_attack_range:
		return
	if _fire_elapsed < hostile_fire_interval:
		return
	if use_global_bullet_budget and BulletManager != null and not BulletManager.can_spawn_bullet():
		return
	_fire_elapsed = 0.0
	hostile_alert.emit(self, _player)
	var direction := to_player.normalized()
	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return
	var parent := get_parent()
	if parent == null:
		bullet.queue_free()
		return
	parent.add_child(bullet)
	var bullet_2d := bullet as Node2D
	if bullet_2d != null:
		bullet_2d.global_position = global_position + direction * (hull_radius + 18.0)
		bullet_2d.global_rotation = direction.angle()
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, hostile_projectile_speed, self)


func _update_support_behavior(delta: float) -> void:
	if not support_enabled:
		return
	if faction != Faction.FRIENDLY and faction != Faction.TRADER:
		return
	if _support_scan_elapsed >= maxf(support_scan_interval, 0.05):
		_support_scan_elapsed = 0.0
		_support_target = _nearest_support_target()
	if _support_target != null and is_instance_valid(_support_target) and not _support_target.is_queued_for_deletion():
		if _support_fire_elapsed >= maxf(support_fire_interval, 0.08):
			_support_fire_elapsed = 0.0
			_fire_support_beam(_support_target)
	if faction == Faction.FRIENDLY:
		_repair_nearby_ally(delta)


func _nearest_support_target() -> Node2D:
	var best: Node2D = null
	var best_distance := support_attack_range * support_attack_range
	_query_targets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius([&"campaign_invader", &"enemies", &"wave_enemy"], global_position, support_attack_range, 42, false, _query_targets)
	else:
		for group_name in [&"campaign_invader", &"enemies", &"wave_enemy"]:
			for value in get_tree().get_nodes_in_group(group_name):
				var candidate := value as Node2D
				if candidate != null:
					_query_targets.append(candidate)
	for candidate in _query_targets:
		if candidate == null or candidate == self or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if candidate.is_in_group("player_allies"):
			continue
		if candidate.is_in_group("campaign_mothership"):
			if not (candidate.has_method("is_hostile") and bool(candidate.call("is_hostile"))):
				continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _fire_support_beam(target: Node2D) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var target_position := target.global_position
	if target.has_method("take_damage"):
		target.call("take_damage", support_damage)
		support_action_emitted.emit(self, target, &"support_fire", support_damage)
	_draw_support_beam(target_position)


func _repair_nearby_ally(delta: float) -> void:
	if support_repair_per_second <= 0.0:
		return
	var mother := get_tree().get_first_node_in_group("campaign_mother_planet") as Node2D
	if mother != null and is_instance_valid(mother):
		if global_position.distance_to(mother.global_position) <= support_repair_radius and mother.has_method("repair"):
			var amount := support_repair_per_second * delta
			var repaired := float(mother.call("repair", amount))
			if repaired > 0.0:
				support_action_emitted.emit(self, mother, &"repair", repaired)


func _draw_support_beam(target_position: Vector2) -> void:
	if _support_beam == null:
		return
	_support_beam.points = PackedVector2Array([Vector2.ZERO, to_local(target_position)])
	_support_beam.width = support_beam_width
	_support_beam.default_color = support_beam_color
	_support_beam.visible = true
	_support_beam_alpha = support_beam_color.a


func _update_support_beam(delta: float) -> void:
	if _support_beam == null or not _support_beam.visible:
		return
	_support_beam_alpha = maxf(_support_beam_alpha - delta / maxf(support_beam_lifetime, 0.01), 0.0)
	_support_beam.default_color = Color(support_beam_color.r, support_beam_color.g, support_beam_color.b, _support_beam_alpha)
	if _support_beam_alpha <= 0.0:
		_support_beam.visible = false


func _destroy_mothership() -> void:
	if _destroyed:
		return
	_destroyed = true
	_unregister_runtime_groups()
	remove_from_group("campaign_mothership")
	remove_from_group("enemies")
	remove_from_group("wave_enemy")
	remove_from_group("player_allies")
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _body_collision != null:
		_body_collision.set_deferred("disabled", true)
	mothership_destroyed.emit(self, reward_credits)
	call_deferred("queue_free")


func _register_runtime_groups() -> void:
	if RuntimeRegistry == null:
		return
	RuntimeRegistry.register_node(self, &"campaign_mothership")
	if faction == Faction.HOSTILE:
		RuntimeRegistry.register_node(self, &"enemies")
	else:
		RuntimeRegistry.register_node(self, &"player_allies")


func _unregister_runtime_groups() -> void:
	if RuntimeRegistry == null:
		return
	RuntimeRegistry.unregister_node(self, &"campaign_mothership")
	RuntimeRegistry.unregister_node(self, &"enemies")
	RuntimeRegistry.unregister_node(self, &"player_allies")


func _emit_damage_feedback(amount: float) -> void:
	var context: Dictionary = {}
	if has_meta(&"last_damage_feedback_context"):
		var meta_value: Variant = get_meta(&"last_damage_feedback_context")
		if meta_value is Dictionary:
			context = (meta_value as Dictionary).duplicate(true)
	context["current_health"] = current_health
	context["max_health"] = max_health
	context["was_final_blow"] = current_health <= 0.001
	var manager := get_tree().get_first_node_in_group("damage_feedback_manager")
	if manager != null and manager.has_method("show_damage"):
		manager.call("show_damage", self, amount, context)


func _faction_color() -> Color:
	match faction:
		Faction.FRIENDLY:
			return friendly_color
		Faction.TRADER:
			return trader_color
		Faction.NEUTRAL:
			return neutral_color
	return hostile_color


func _callsign_for_index(index: int) -> String:
	var names := ["FREEHOLD CARRIER", "ION BAZAAR", "OATHKEEPER DOCK", "NULL PRIVATEER", "HARMONIC TRADER"]
	return names[abs(index) % names.size()]


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 8)):
		var angle := TAU * float(i) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
