extends CharacterBody2D
class_name CampaignInvader

signal destroyed(invader: CampaignInvader, reward: int, position: Vector2)
signal breached_target(invader: CampaignInvader, target: Node, damage: float)
signal disabled_for_hijack(invader: CampaignInvader, position: Vector2)

const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")

enum AIState {
	PATROL,
	INVESTIGATE,
	PURSUE,
	ORBIT_ATTACK,
	STRAFE_ATTACK,
	SLINGSHOT,
	RETREAT,
	GUARD,
}

enum BehaviorProfile {
	RAIDER,
	SKIRMISHER,
	INTERCEPTOR,
	BOMBER,
	GUARD,
}

enum CampaignRole {
	PLANET_BREACHER,
	INTERCEPTOR,
	SIEGE_BOMBER,
	HIJACKER,
	CARRIER_DRONE,
	SALVAGE_THIEF,
	SHIELD_BREAKER,
	FLEET_HUNTER,
	GRAVITY_DIVER,
}

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
@export_group("Visual Polish")
@export var show_tactical_state_ring: bool = true
@export var show_attack_vector_arc: bool = true
@export var state_ring_radius: float = 34.0
@export var engine_trail_length: float = 46.0
@export var core_color: Color = Color(1.0, 0.88, 0.42, 0.95)
@export var engine_color: Color = Color(0.36, 1.0, 0.88, 0.72)
@export_group("AI")
@export_enum("Raider", "Skirmisher", "Interceptor", "Bomber", "Guard") var behavior_profile: int = BehaviorProfile.RAIDER
@export var auto_assign_profile_from_fleet: bool = true
@export_group("Campaign Role")
@export_enum("Planet Breacher", "Interceptor", "Siege Bomber", "Hijacker", "Carrier Drone", "Salvage Thief", "Shield Breaker", "Fleet Hunter", "Gravity Diver") var campaign_role: int = CampaignRole.PLANET_BREACHER
@export var role_overrides_profile: bool = true
@export var fleet_hunter_scan_radius: float = 1800.0
@export var mothership_target_scan_radius: float = 2400.0
@export var shield_breaker_damage_multiplier: float = 1.32
@export var carrier_drone_guard_radius_multiplier: float = 1.28
@export var gravity_diver_slingshot_multiplier: float = 1.25
@export var salvage_thief_reward_multiplier: float = 1.35
@export var ai_state_refresh_interval: float = 0.34
@export var attack_range: float = 760.0
@export var orbit_radius: float = 460.0
@export var strafe_distance: float = 680.0
@export var retreat_health_ratio: float = 0.28
@export var retreat_distance: float = 940.0
@export var tactical_orbit_weight: float = 0.55
@export var strafe_weight: float = 0.4
@export var slingshot_min_distance: float = 380.0
@export var slingshot_gravity_weight: float = 1.28
@export var guard_radius: float = 900.0
@export_group("Ranged Attack")
@export var bullet_scene: PackedScene = ENEMY_BULLET_SCENE
@export var projectile_speed: float = 760.0
@export var fire_interval: float = 1.45
@export var fire_windup: float = 0.12
@export var fire_range: float = 820.0
@export var lead_prediction: float = 0.34
@export var fire_only_when_visible: bool = false
@export var use_global_bullet_budget: bool = true
@export_group("Campaign Capture")
@export var hijack_disable_health_ratio: float = 0.24
@export var hijack_disabled_duration: float = 4.8
@export var hijack_disabled_drag: float = 0.78
@export var hijack_capture_ready_scale: float = 1.28
@export var hijack_capture_ring_color: Color = Color(0.36, 1.0, 0.78, 0.72)
@export_range(0.0, 1.0, 0.01) var hijack_capture_ring_alpha: float = 0.42

var target: Node2D = null
var current_health: float = 44.0
var march_row: int = 0
var march_column: int = 0
var fleet_seed: int = 0

var _visual: Polygon2D = null
var _core: Polygon2D = null
var _wing_line: Line2D = null
var _threat_arc: Line2D = null
var _state_ring: Line2D = null
var _capture_ring: Line2D = null
var _engine_trail: Line2D = null
var _gravity_sources: Array[Node2D] = []
var _elapsed: float = 0.0
var _destroyed: bool = false
var _free_queued: bool = false
var _hijack_capture_armed: bool = false
var _hijack_disabled: bool = false
var _hijack_disabled_remaining: float = 0.0
var _ai_state: int = AIState.PURSUE
var _state_elapsed: float = 0.0
var _state_refresh_elapsed: float = 999.0
var _fire_elapsed: float = 0.0
var _profile_phase: float = 0.0
var _query_targets: Array[Node2D] = []


func configure(target_node: Node2D, row: int, column: int, seed_value: int) -> void:
	target = target_node
	march_row = row
	march_column = column
	fleet_seed = seed_value
	_profile_phase = float(abs(seed_value % 1000)) * 0.0061
	if auto_assign_profile_from_fleet:
		behavior_profile = [BehaviorProfile.RAIDER, BehaviorProfile.SKIRMISHER, BehaviorProfile.INTERCEPTOR, BehaviorProfile.BOMBER][abs(seed_value + column) % 4]


func apply_campaign_role(role_id: int) -> void:
	campaign_role = clampi(role_id, CampaignRole.PLANET_BREACHER, CampaignRole.GRAVITY_DIVER)
	set_meta(&"campaign_role", campaign_role)
	if role_overrides_profile:
		match campaign_role:
			CampaignRole.INTERCEPTOR, CampaignRole.FLEET_HUNTER:
				behavior_profile = BehaviorProfile.INTERCEPTOR
			CampaignRole.SIEGE_BOMBER, CampaignRole.SHIELD_BREAKER:
				behavior_profile = BehaviorProfile.BOMBER
			CampaignRole.CARRIER_DRONE:
				behavior_profile = BehaviorProfile.GUARD
			CampaignRole.GRAVITY_DIVER, CampaignRole.SALVAGE_THIEF:
				behavior_profile = BehaviorProfile.SKIRMISHER
			CampaignRole.HIJACKER:
				behavior_profile = BehaviorProfile.SKIRMISHER
	if campaign_role == CampaignRole.SALVAGE_THIEF:
		reward_credits = maxi(int(round(float(reward_credits) * salvage_thief_reward_multiplier)), reward_credits)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wave_enemy")
	add_to_group("campaign_invader")
	current_health = max_health
	_visual = get_node_or_null("CampaignInvaderHull") as Polygon2D
	_core = get_node_or_null("CampaignInvaderCore") as Polygon2D
	_wing_line = get_node_or_null("CampaignInvaderWingLine") as Line2D
	_threat_arc = get_node_or_null("CampaignInvaderThreatArc") as Line2D
	if _threat_arc == null:
		_threat_arc = get_node_or_null("CampaignInvaderVector") as Line2D
	_state_ring = get_node_or_null("CampaignInvaderStateRing") as Line2D
	_engine_trail = get_node_or_null("CampaignInvaderEngineTrail") as Line2D
	_build_collision()
	_build_visuals()
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
		RuntimeRegistry.register_node(self, &"wave_enemy")
		RuntimeRegistry.register_node(self, &"campaign_invader")


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
		RuntimeRegistry.unregister_node(self, &"wave_enemy")
		RuntimeRegistry.unregister_node(self, &"campaign_invader")


func _physics_process(delta: float) -> void:
	if _destroyed:
		return
	delta *= CombatStatus.get_time_scale(self)
	_elapsed += delta
	_state_elapsed += delta
	_state_refresh_elapsed += delta
	_fire_elapsed += delta
	if _hijack_disabled:
		_update_disabled_capture(delta)
		return
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		target = _resolve_target()
	if target == null:
		return

	var gravity := _gravity_acceleration()
	var to_target := target.global_position - global_position
	if _state_refresh_elapsed >= ai_state_refresh_interval:
		_state_refresh_elapsed = 0.0
		_select_ai_state(to_target)
	var desired := _steering_for_state(to_target, gravity)
	var steering := desired * delta
	velocity += steering + gravity * delta
	velocity *= pow(drag, delta * 60.0)
	velocity = velocity.limit_length(max_speed)
	if velocity.length_squared() > 4.0:
		rotation = lerp_angle(rotation, velocity.angle(), clampf(delta * 6.0, 0.0, 1.0))
	move_and_slide()
	_try_ranged_attack(to_target)
	_update_visuals(to_target, delta)
	_try_breach_target(to_target)


func _select_ai_state(to_target: Vector2) -> void:
	var previous := _ai_state
	var distance := to_target.length()
	var health_ratio := current_health / maxf(max_health, 1.0)
	if health_ratio <= retreat_health_ratio and distance < retreat_distance:
		_ai_state = AIState.RETREAT
	elif campaign_role == CampaignRole.CARRIER_DRONE and distance <= guard_radius * carrier_drone_guard_radius_multiplier:
		_ai_state = AIState.GUARD
	elif campaign_role == CampaignRole.SIEGE_BOMBER and distance <= fire_range:
		_ai_state = AIState.STRAFE_ATTACK
	elif campaign_role == CampaignRole.GRAVITY_DIVER and _nearest_gravity_source() != null:
		_ai_state = AIState.SLINGSHOT
	elif behavior_profile == BehaviorProfile.GUARD and distance <= guard_radius:
		_ai_state = AIState.GUARD
	elif distance > attack_range * 1.55:
		_ai_state = AIState.PURSUE
	elif _nearest_gravity_source() != null and distance >= slingshot_min_distance and _profile_likes_slingshot():
		_ai_state = AIState.SLINGSHOT
	elif distance <= orbit_radius * 1.18 and _profile_likes_orbit():
		_ai_state = AIState.ORBIT_ATTACK
	else:
		_ai_state = AIState.STRAFE_ATTACK if _profile_likes_strafe() else AIState.PURSUE
	if previous != _ai_state:
		_state_elapsed = 0.0


func _steering_for_state(to_target: Vector2, gravity: Vector2) -> Vector2:
	var desired := to_target.normalized() if to_target.length_squared() > 0.001 else Vector2.RIGHT.rotated(rotation)
	var lateral := desired.orthogonal() * sin(_elapsed * march_frequency + float(march_column) * 0.72 + _profile_phase) * march_amplitude
	var row_bias := desired.orthogonal() * float(march_row - 1) * 42.0
	match _ai_state:
		AIState.RETREAT:
			return (-desired * thrust_power * 1.16) + lateral * 0.34 + _gravity_tangent_vector(gravity) * thrust_power * 0.18
		AIState.ORBIT_ATTACK:
			var orbit_dir := desired.orthogonal()
			if float((march_column + march_row) % 2) > 0.0:
				orbit_dir = -orbit_dir
			var distance_error := to_target.length() - orbit_radius
			return orbit_dir * thrust_power * tactical_orbit_weight - desired * distance_error * 2.4 + row_bias
		AIState.STRAFE_ATTACK:
			var strafe_dir := desired.orthogonal()
			if sin(_elapsed * 0.6 + _profile_phase) < 0.0:
				strafe_dir = -strafe_dir
			var range_error := to_target.length() - strafe_distance
			return strafe_dir * thrust_power * strafe_weight + desired * range_error * 2.1 + lateral * 0.28
		AIState.SLINGSHOT:
			var source := _nearest_gravity_source()
			if source != null:
				var from_source := global_position - source.global_position
				if from_source.length_squared() > 0.001:
					var tangent := from_source.normalized().orthogonal()
					if tangent.dot(desired) < 0.0:
						tangent = -tangent
					var dive_multiplier := gravity_diver_slingshot_multiplier if campaign_role == CampaignRole.GRAVITY_DIVER else 1.0
					return tangent * thrust_power * slingshot_gravity_weight * dive_multiplier + desired * thrust_power * 0.34
			return desired * thrust_power + lateral
		AIState.GUARD:
			var anchor := _mother_planet_position()
			var from_anchor := global_position - anchor
			if from_anchor.length_squared() > 0.001:
				var tangent := from_anchor.normalized().orthogonal()
				return tangent * thrust_power * 0.46 + desired * thrust_power * 0.42
			return desired * thrust_power
	return desired * thrust_power + lateral + row_bias


func _gravity_tangent_vector(gravity: Vector2) -> Vector2:
	if gravity.length_squared() <= 0.001:
		return Vector2.ZERO
	return gravity.normalized().orthogonal()


func _profile_likes_orbit() -> bool:
	return behavior_profile == BehaviorProfile.SKIRMISHER or behavior_profile == BehaviorProfile.GUARD or _profile_roll(tactical_orbit_weight)


func _profile_likes_strafe() -> bool:
	return behavior_profile == BehaviorProfile.INTERCEPTOR or behavior_profile == BehaviorProfile.BOMBER or _profile_roll(strafe_weight)


func _profile_likes_slingshot() -> bool:
	return behavior_profile == BehaviorProfile.SKIRMISHER or behavior_profile == BehaviorProfile.INTERCEPTOR or _profile_roll(0.28)


func _profile_roll(weight: float) -> bool:
	var seed_ratio := float(abs((fleet_seed + march_column * 73 + march_row * 31) % 1000)) / 1000.0
	return seed_ratio <= clampf(weight, 0.0, 1.0)


func _try_ranged_attack(to_target: Vector2) -> void:
	if bullet_scene == null or _fire_elapsed < fire_interval + fire_windup:
		return
	var distance := to_target.length()
	if distance > fire_range or distance <= breach_radius * 1.2:
		return
	if fire_only_when_visible and not _target_on_screen():
		return
	if use_global_bullet_budget and BulletManager != null and not BulletManager.can_spawn_bullet():
		return
	_fire_elapsed = 0.0
	var target_position := target.global_position
	var target_velocity := Vector2.ZERO
	var velocity_value: Variant = target.get("velocity") if target != null else null
	if velocity_value is Vector2:
		target_velocity = velocity_value
	var lead_position := target_position + target_velocity * lead_prediction
	var direction := (lead_position - global_position).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT.rotated(rotation)
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
		bullet_2d.global_position = global_position + direction * (collision_radius + 12.0)
		bullet_2d.global_rotation = direction.angle()
	if bullet.has_method("configure_launch"):
		bullet.call("configure_launch", direction, projectile_speed, self)


func _target_on_screen() -> bool:
	if target == null or get_viewport() == null:
		return true
	var screen_position := get_viewport().get_canvas_transform() * target.global_position
	var rect := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(96.0)
	return rect.has_point(screen_position)


func _nearest_gravity_source() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var distance := source.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best = source
			best_distance = distance
	return best


func _mother_planet_position() -> Vector2:
	var mother := get_tree().get_first_node_in_group("campaign_mother_planet") as Node2D
	if mother != null and is_instance_valid(mother):
		return mother.global_position
	return target.global_position if target != null else global_position


func take_damage(amount: float) -> void:
	if _destroyed or amount <= 0.0:
		return
	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	set_meta(&"campaign_hull_ratio", current_health / maxf(max_health, 1.0))
	_emit_damage_feedback(amount, previous_health)
	if _should_disable_for_hijack():
		_enter_hijack_disabled()
		return
	if current_health / maxf(max_health, 1.0) <= retreat_health_ratio:
		_ai_state = AIState.RETREAT
		_state_elapsed = 0.0
	if current_health <= 0.0:
		_destroyed = true
		destroyed.emit(self, reward_credits, global_position)
		_queue_free_once()


func arm_hijack_capture(duration: float = -1.0, disable_ratio: float = -1.0) -> void:
	if _destroyed:
		return
	_hijack_capture_armed = true
	if duration > 0.0:
		hijack_disabled_duration = duration
	if disable_ratio > 0.0:
		hijack_disable_health_ratio = clampf(disable_ratio, 0.05, 0.95)
	set_meta(&"campaign_hijack_armed", true)


func clear_hijack_capture() -> void:
	_hijack_capture_armed = false
	set_meta(&"campaign_hijack_armed", false)
	if not _hijack_disabled and _capture_ring != null:
		_capture_ring.visible = false


func complete_hijack_capture() -> void:
	if _destroyed:
		return
	_destroyed = true
	set_meta(&"campaign_hijack_captured", true)
	_queue_free_once()


func _emit_damage_feedback(amount: float, previous_health: float) -> void:
	var context: Dictionary = {}
	if has_meta(&"last_damage_feedback_context"):
		var meta_value: Variant = get_meta(&"last_damage_feedback_context")
		if meta_value is Dictionary:
			context = (meta_value as Dictionary).duplicate(true)
	context["previous_health"] = previous_health
	context["current_health"] = current_health
	context["max_health"] = max_health
	context["was_final_blow"] = current_health <= 0.001
	var manager := get_tree().get_first_node_in_group("damage_feedback_manager")
	if manager != null and manager.has_method("show_damage"):
		manager.call("show_damage", self, amount, context)


func _try_breach_target(to_target: Vector2) -> void:
	if _hijack_disabled:
		return
	if to_target.length() > breach_radius:
		return
	var damage_target := target
	if damage_target == null or not is_instance_valid(damage_target):
		return
	var damage := breach_damage * _role_breach_multiplier()
	if damage_target.has_method("take_damage"):
		damage_target.call("take_damage", damage)
	else:
		var health := damage_target.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			health.call("take_damage", damage)
	_destroyed = true
	breached_target.emit(self, damage_target, damage)
	_queue_free_once()


func _resolve_target() -> Node2D:
	var mother := get_tree().get_first_node_in_group("campaign_mother_planet") as Node2D
	var player := MultiplayerTargeting.nearest_player(global_position, get_tree())
	match campaign_role:
		CampaignRole.PLANET_BREACHER, CampaignRole.SIEGE_BOMBER, CampaignRole.SHIELD_BREAKER:
			if mother != null and is_instance_valid(mother):
				return mother
		CampaignRole.INTERCEPTOR, CampaignRole.GRAVITY_DIVER:
			if player != null and is_instance_valid(player):
				return player
		CampaignRole.FLEET_HUNTER:
			var escort := _nearest_campaign_target(&"campaign_escort", fleet_hunter_scan_radius)
			if escort != null:
				return escort
		CampaignRole.CARRIER_DRONE:
			var screen_target := _nearest_campaign_target(&"campaign_escort", fleet_hunter_scan_radius)
			if screen_target != null:
				return screen_target
			if player != null and is_instance_valid(player):
				return player
		CampaignRole.SALVAGE_THIEF:
			var trader := _nearest_campaign_target(&"campaign_mothership", mothership_target_scan_radius, false)
			if trader != null:
				return trader
	if mother != null and is_instance_valid(mother):
		if player == null or not is_instance_valid(player):
			return mother
		var mother_weight := global_position.distance_squared_to(mother.global_position)
		var player_weight := global_position.distance_squared_to(player.global_position) * 1.35
		return player if player_weight < mother_weight else mother
	return player


func _nearest_campaign_target(group_name: StringName, radius: float, hostile_only: bool = false) -> Node2D:
	var best: Node2D = null
	var best_distance := radius * radius
	_query_targets.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius([group_name], global_position, radius, 24, true, _query_targets)
	else:
		for value in get_tree().get_nodes_in_group(group_name):
			var candidate := value as Node2D
			if candidate != null:
				_query_targets.append(candidate)
	for candidate in _query_targets:
		if candidate == null or candidate == self or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if hostile_only and not (candidate.has_method("is_hostile") and bool(candidate.call("is_hostile"))):
			continue
		if not hostile_only and candidate.has_method("is_hostile") and bool(candidate.call("is_hostile")):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _role_breach_multiplier() -> float:
	match campaign_role:
		CampaignRole.SHIELD_BREAKER:
			return shield_breaker_damage_multiplier
		CampaignRole.SIEGE_BOMBER:
			return maxf(shield_breaker_damage_multiplier * 0.92, 1.0)
		CampaignRole.INTERCEPTOR, CampaignRole.SALVAGE_THIEF:
			return 0.82
	return 1.0


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
		add_child(_visual)
	_visual.polygon = _profile_hull_points()
	_visual.color = hull_color
	_visual.z_index = 2

	if _core == null:
		_core = Polygon2D.new()
		_core.name = "CampaignInvaderCore"
		add_child(_core)
	_core.polygon = PackedVector2Array([
		Vector2(8.0, 0.0),
		Vector2(-2.0, 7.0),
		Vector2(-11.0, 0.0),
		Vector2(-2.0, -7.0),
	])
	_core.color = core_color
	_core.z_index = 3

	if _wing_line == null:
		_wing_line = Line2D.new()
		_wing_line.name = "CampaignInvaderWingLine"
		add_child(_wing_line)
	_wing_line.antialiased = true
	_wing_line.width = 2.0
	_wing_line.points = PackedVector2Array([
		Vector2(-18.0, -20.0),
		Vector2(6.0, -12.0),
		Vector2(20.0, 0.0),
		Vector2(6.0, 12.0),
		Vector2(-18.0, 20.0),
	])
	_wing_line.z_index = 4

	if _threat_arc == null:
		_threat_arc = Line2D.new()
		_threat_arc.name = "CampaignInvaderThreatArc"
		add_child(_threat_arc)
	_threat_arc.name = "CampaignInvaderThreatArc"
	_threat_arc.antialiased = true
	_threat_arc.width = 1.6
	_threat_arc.points = _nose_arc_points(18.0)
	_threat_arc.z_index = 5

	if _state_ring == null:
		_state_ring = Line2D.new()
		_state_ring.name = "CampaignInvaderStateRing"
		add_child(_state_ring)
	_state_ring.closed = true
	_state_ring.antialiased = true
	_state_ring.width = 1.2
	_state_ring.points = _circle_points(32, state_ring_radius)
	_state_ring.z_index = 1

	if _capture_ring == null:
		_capture_ring = get_node_or_null("CampaignInvaderCaptureRing") as Line2D
	if _capture_ring == null:
		_capture_ring = Line2D.new()
		_capture_ring.name = "CampaignInvaderCaptureRing"
		add_child(_capture_ring)
	_capture_ring.closed = true
	_capture_ring.antialiased = true
	_capture_ring.width = 2.0
	_capture_ring.points = _circle_points(36, state_ring_radius * hijack_capture_ready_scale)
	_capture_ring.z_index = 7
	_capture_ring.visible = false

	if _engine_trail == null:
		_engine_trail = Line2D.new()
		_engine_trail.name = "CampaignInvaderEngineTrail"
		add_child(_engine_trail)
	_engine_trail.antialiased = true
	_engine_trail.width = 3.0
	_engine_trail.z_index = 0


func _update_visuals(_to_target: Vector2, delta: float) -> void:
	var health_ratio := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var state_color := _state_hull_color()
	if _visual != null:
		_visual.color = damaged_hull_color.lerp(state_color, health_ratio)
	if _core != null:
		var pulse := 0.64 + sin(_elapsed * 8.0 + _profile_phase) * 0.12
		_core.color = core_color.lerp(_state_vector_color(), 1.0 - health_ratio)
		_core.modulate.a = clampf(pulse, 0.38, 0.92)
		_core.scale = Vector2.ONE * lerpf(0.86, 1.12, 1.0 - health_ratio)
	if _wing_line != null:
		_wing_line.default_color = Color(state_color.r, state_color.g, state_color.b, 0.42)
	if _threat_arc != null:
		var charge_ratio := clampf(_fire_elapsed / maxf(fire_interval + fire_windup, 0.1), 0.0, 1.0)
		_threat_arc.visible = show_attack_vector_arc
		_threat_arc.points = _nose_arc_points(16.0 + charge_ratio * 12.0)
		_threat_arc.width = 1.1 + charge_ratio * 2.2
		var arc_color := _state_vector_color()
		_threat_arc.default_color = Color(arc_color.r, arc_color.g, arc_color.b, 0.22 + charge_ratio * 0.46)
	if _state_ring != null:
		_state_ring.visible = show_tactical_state_ring
		_state_ring.rotation += delta * (0.7 if _ai_state != AIState.RETREAT else -1.1)
		_state_ring.default_color = Color(state_color.r, state_color.g, state_color.b, 0.12 + (1.0 - health_ratio) * 0.22)
		_state_ring.width = 1.0 + (1.0 - health_ratio) * 1.6
	if _capture_ring != null:
		_capture_ring.visible = _hijack_capture_armed or _hijack_disabled
		_capture_ring.rotation -= delta * (1.4 if _hijack_disabled else 0.5)
		var pulse := 0.5 + sin(_elapsed * 9.0 + _profile_phase) * 0.5
		var alpha := hijack_capture_ring_alpha * (0.45 + pulse * 0.55)
		if _hijack_disabled:
			alpha = hijack_capture_ring_alpha
			_capture_ring.width = 2.6 + pulse * 1.4
		else:
			_capture_ring.width = 1.4 + pulse * 0.5
		_capture_ring.default_color = Color(hijack_capture_ring_color.r, hijack_capture_ring_color.g, hijack_capture_ring_color.b, _safe_alpha(alpha, 0.58))
	if _engine_trail != null:
		var speed_ratio := clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.0)
		var flicker := 0.82 + sin(_elapsed * 18.0 + _profile_phase) * 0.18
		var trail_length := engine_trail_length * lerpf(0.35, 1.0, speed_ratio) * flicker
		_engine_trail.points = PackedVector2Array([
			Vector2(-14.0, 0.0),
			Vector2(-22.0 - trail_length * 0.42, sin(_elapsed * 11.0) * 3.0),
			Vector2(-22.0 - trail_length, sin(_elapsed * 7.0 + 1.2) * 5.0),
		])
		_engine_trail.default_color = Color(engine_color.r, engine_color.g, engine_color.b, 0.18 + speed_ratio * 0.42)
		_engine_trail.width = lerpf(1.4, 4.2, speed_ratio)


func _state_hull_color() -> Color:
	if _hijack_disabled:
		return Color(0.36, 1.0, 0.78, hull_color.a)
	match campaign_role:
		CampaignRole.SIEGE_BOMBER, CampaignRole.SHIELD_BREAKER:
			return Color(1.0, 0.42, 0.14, hull_color.a)
		CampaignRole.CARRIER_DRONE:
			return Color(0.82, 0.34, 1.0, hull_color.a)
		CampaignRole.SALVAGE_THIEF:
			return Color(1.0, 0.78, 0.24, hull_color.a)
		CampaignRole.FLEET_HUNTER:
			return Color(1.0, 0.28, 0.42, hull_color.a)
		CampaignRole.GRAVITY_DIVER:
			return Color(0.52, 1.0, 0.72, hull_color.a)
	match _ai_state:
		AIState.RETREAT:
			return Color(1.0, 0.24, 0.16, hull_color.a)
		AIState.ORBIT_ATTACK, AIState.SLINGSHOT:
			return Color(1.0, 0.72, 0.22, hull_color.a)
		AIState.GUARD:
			return Color(0.44, 0.94, 1.0, hull_color.a)
	return hull_color


func _state_vector_color() -> Color:
	if _hijack_disabled:
		return hijack_capture_ring_color
	match _ai_state:
		AIState.RETREAT:
			return Color(1.0, 0.16, 0.1, 0.62)
		AIState.ORBIT_ATTACK:
			return Color(1.0, 0.82, 0.28, 0.62)
		AIState.SLINGSHOT:
			return Color(0.68, 1.0, 0.52, 0.66)
		AIState.STRAFE_ATTACK:
			return Color(1.0, 0.5, 0.22, 0.56)
		AIState.GUARD:
			return Color(0.35, 0.92, 1.0, 0.56)
	return vector_color


func _profile_hull_points() -> PackedVector2Array:
	match behavior_profile:
		BehaviorProfile.SKIRMISHER:
			return PackedVector2Array([
				Vector2(32.0, 0.0), Vector2(8.0, 12.0), Vector2(-16.0, 24.0), Vector2(-8.0, 6.0),
				Vector2(-30.0, 0.0), Vector2(-8.0, -6.0), Vector2(-16.0, -24.0), Vector2(8.0, -12.0),
			])
		BehaviorProfile.INTERCEPTOR:
			return PackedVector2Array([
				Vector2(38.0, 0.0), Vector2(4.0, 10.0), Vector2(-24.0, 16.0), Vector2(-10.0, 0.0),
				Vector2(-24.0, -16.0), Vector2(4.0, -10.0),
			])
		BehaviorProfile.BOMBER:
			return PackedVector2Array([
				Vector2(30.0, 0.0), Vector2(12.0, 18.0), Vector2(-22.0, 20.0), Vector2(-32.0, 8.0),
				Vector2(-24.0, 0.0), Vector2(-32.0, -8.0), Vector2(-22.0, -20.0), Vector2(12.0, -18.0),
			])
		BehaviorProfile.GUARD:
			return PackedVector2Array([
				Vector2(28.0, 0.0), Vector2(10.0, 20.0), Vector2(-20.0, 22.0), Vector2(-34.0, 0.0),
				Vector2(-20.0, -22.0), Vector2(10.0, -20.0),
			])
	return PackedVector2Array([
		Vector2(34.0, 0.0), Vector2(10.0, 14.0), Vector2(-20.0, 18.0), Vector2(-12.0, 5.0),
		Vector2(-32.0, 0.0), Vector2(-12.0, -5.0), Vector2(-20.0, -18.0), Vector2(10.0, -14.0),
	])


func _nose_arc_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(9):
		var t := float(index) / 8.0
		var angle := lerpf(-0.72, 0.72, t)
		points.append(Vector2(16.0, 0.0) + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _should_disable_for_hijack() -> bool:
	if not _hijack_capture_armed or _hijack_disabled:
		return false
	if current_health <= 0.0:
		return false
	return current_health / maxf(max_health, 1.0) <= hijack_disable_health_ratio


func _enter_hijack_disabled() -> void:
	_hijack_disabled = true
	_hijack_capture_armed = false
	_hijack_disabled_remaining = maxf(hijack_disabled_duration, 0.2)
	_ai_state = AIState.RETREAT
	velocity *= 0.18
	set_meta(&"campaign_hijack_disabled", true)
	disabled_for_hijack.emit(self, global_position)


func _update_disabled_capture(delta: float) -> void:
	_hijack_disabled_remaining = maxf(_hijack_disabled_remaining - delta, 0.0)
	velocity *= pow(clampf(hijack_disabled_drag, 0.01, 1.0), delta * 60.0)
	move_and_slide()
	_update_visuals(Vector2.ZERO, delta)
	if _hijack_disabled_remaining > 0.0:
		return
	_hijack_disabled = false
	set_meta(&"campaign_hijack_disabled", false)
	current_health = maxf(current_health, max_health * minf(hijack_disable_health_ratio + 0.12, 0.9))
	_ai_state = AIState.RETREAT


func _safe_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)


func _queue_free_once() -> void:
	if _free_queued or is_queued_for_deletion():
		return
	_free_queued = true
	call_deferred("queue_free")
