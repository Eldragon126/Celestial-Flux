extends Node
class_name PhysicsAwareEnemyDirector

# Lightweight enemy intelligence layer for Vector Anomaly.

signal enemy_profile_assigned(enemy: Node, profile: StringName)
signal enemy_physics_nudge(enemy: Node, profile: StringName, impulse: Vector2)
signal anchor_field_applied(enemy: Node, position: Vector2, intensity: float)
signal tidal_surge_triggered(enemy: Node, position: Vector2, radius: float)

const FIELD_TARGET_GROUPS: Array[StringName] = [&"Player", &"enemies", &"Projectiles", &"enemy_projectiles", &"player_projectiles"]

@export var enabled: bool = true
@export var scan_interval: float = 0.45
@export var think_interval: float = 0.12
@export var max_tracked_enemies: int = 34
@export var max_gravity_sources_sampled: int = 6
@export var gravity_source_refresh_interval: float = 0.4
@export var max_bodies_per_field: int = 48
@export var max_nudge_per_second: float = 520.0
@export var late_game_nudge_scale: float = 0.58
@export var late_game_max_tracked: int = 22
@export var debug_logging: bool = false

@export_group("Orbit Hunters")
@export var orbit_distance: float = 430.0
@export var orbit_band: float = 145.0
@export var orbit_tangent_force: float = 330.0
@export var orbit_radial_force: float = 250.0
@export var orbit_gravity_assist: float = 0.34

@export_group("Anchor Units")
@export var anchor_radius: float = 360.0
@export var anchor_damping: float = 0.16
@export var anchor_player_damping: float = 0.04
@export var anchor_cooldown: float = 1.1

@export_group("Tidal Bombers")
@export var tide_radius: float = 520.0
@export var tide_interval: float = 2.8
@export var tide_push_strength: float = 420.0
@export var tide_pull_strength: float = 360.0

@export_group("Relativistic Snipers")
@export var sniper_lead_time: float = 0.82
@export var sniper_orbit_bias: float = 220.0
@export var sniper_standoff_distance: float = 760.0

@export_group("Gravity Parasites")
@export var parasite_well_distance: float = 185.0
@export var parasite_latch_force: float = 390.0
@export var parasite_amplification_radius: float = 420.0
@export var parasite_amplification_strength: float = 180.0

var _player: Node2D = null
var _tracked: Dictionary = {}
var _scan_elapsed := 0.0
var _think_elapsed := 0.0
var _gravity_refresh_elapsed := 999.0
var _gravity_sources: Array[Node2D] = []
var _enemy_scan_buffer: Array[Node2D] = []
var _nearby_body_buffer: Array[Node2D] = []
var _next_tracked: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("physics_aware_enemy_director")
	_rng.randomize()
	set_process(true)

func _process(delta: float) -> void:
	if not enabled:
		return
	
	_scan_elapsed += delta
	_think_elapsed += delta
	_gravity_refresh_elapsed += delta
	
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	
	if _scan_elapsed >= maxf(scan_interval, 0.1):
		_scan_elapsed = 0.0
		_refresh_targets()
	
	if _gravity_refresh_elapsed >= maxf(gravity_source_refresh_interval, 0.05):
		_gravity_refresh_elapsed = 0.0
		_refresh_gravity_sources()
	
	if _think_elapsed >= maxf(think_interval, 0.03):
		var think_delta := _think_elapsed
		_think_elapsed = 0.0
		_update_enemy_physics(think_delta)

func _refresh_targets() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	
	_enemy_scan_buffer.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(&"enemies", _enemy_scan_buffer)
	else:
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Node2D
			if enemy == null:
				continue
			_enemy_scan_buffer.append(enemy)

	for index in range(_enemy_scan_buffer.size() - 1, -1, -1):
		var enemy := _enemy_scan_buffer[index]
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_in_group("Player"):
			_enemy_scan_buffer.remove_at(index)
	
	if is_instance_valid(_player) and not _enemy_scan_buffer.is_empty():
		_enemy_scan_buffer.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			if not is_instance_valid(a) or not is_instance_valid(b):
				return false
			return a.global_position.distance_squared_to(_player.global_position) < \
				   b.global_position.distance_squared_to(_player.global_position)
		)
	
	_next_tracked.clear()
	var tracked_count := 0
	var track_cap := max_tracked_enemies
	if _wave_nudge_scale() < 0.95:
		track_cap = mini(track_cap, late_game_max_tracked)

	for enemy in _enemy_scan_buffer:
		if not is_instance_valid(enemy):
			continue
		if tracked_count >= track_cap:
			break
			
		var id := enemy.get_instance_id()
		var existing = _tracked.get(id)
		var data: Dictionary
		
		if typeof(existing) == TYPE_DICTIONARY:
			data = existing
		else:
			data = _make_tracking_data(enemy)
			enemy_profile_assigned.emit(enemy, data["profile"])
		
		data["enemy"] = enemy
		_next_tracked[id] = data
		tracked_count += 1
	
	var previous := _tracked
	_tracked = _next_tracked
	_next_tracked = previous

func _make_tracking_data(enemy: Node2D) -> Dictionary:
	var profile := _classify_enemy(enemy)
	return {
		"enemy": enemy,
		"profile": profile,
		"phase": _rng.randf() * TAU,
		"next_anchor": 0.0,
		"next_tide": _rng.randf_range(0.4, tide_interval),
		"polarity": 1.0 if _rng.randf() > 0.5 else -1.0,
	}

func _classify_enemy(enemy: Node) -> StringName:
	if not is_instance_valid(enemy):
		return &"drifter"
	var key := "%s %s" % [String(enemy.name).to_lower(), enemy.scene_file_path.to_lower()]
	if key.contains("gravity_leech") or key.contains("leech_parasite"):
		return &"gravity_parasite"
	if key.contains("shield_breaker") or key.contains("harasser") or key.contains("accretion"):
		return &"tidal_bomber"
	if key.contains("phase_slip") or key.contains("phase"):
		return &"orbit_hunter"
	if key.contains("echo_drone") or key.contains("echo"):
		return &"anchor_unit"
	if key.contains("null_harvester") or key.contains("harvester"):
		return &"gravity_parasite"
	if key.contains("paralytic") or key.contains("construct"):
		return &"anchor_unit"
	if key.contains("event_horizon_warden"):
		return &"anchor_unit"
	if key.contains("sniper") or key.contains("seraph"):
		return &"relativistic_sniper"
	if key.contains("warden") or key.contains("magnetar") or key.contains("shielder"):
		return &"anchor_unit"
	if key.contains("orbiter") or key.contains("seeker") or key.contains("wisp"):
		return &"orbit_hunter"
	return &"drifter"

func _update_enemy_physics(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	
	var expired: Array[int] = []
	
	for id in _tracked.keys():
		var data = _tracked.get(id)
		if typeof(data) != TYPE_DICTIONARY:
			expired.append(id)
			continue
		
		# SAFEST WAY - avoid direct cast that can fail
		var enemy = data.get("enemy")
		if not is_instance_valid(enemy):
			expired.append(id)
			continue
		
		var enemy_2d := enemy as Node2D
		if enemy_2d == null or enemy_2d.is_queued_for_deletion():
			expired.append(id)
			continue
		
		var profile: StringName = data.get("profile", &"drifter")
		var impulse := Vector2.ZERO
		
		match profile:
			&"orbit_hunter":     impulse = _orbit_hunter_impulse(enemy_2d, data)
			&"anchor_unit":      impulse = _anchor_unit_impulse(enemy_2d, data, delta)
			&"tidal_bomber":     impulse = _tidal_bomber_impulse(enemy_2d, data, delta)
			&"relativistic_sniper": impulse = _relativistic_sniper_impulse(enemy_2d, data)
			&"gravity_parasite": impulse = _gravity_parasite_impulse(enemy_2d, data, delta)
			_:                   impulse = _drifter_impulse(enemy_2d)
		
		_apply_limited_impulse(enemy_2d, profile, impulse, delta)
		_tracked[id] = data  # keep modified data (timers etc.)
	
	for id in expired:
		_tracked.erase(id)

# ==================== IMPULSE FUNCTIONS ====================

func _orbit_hunter_impulse(enemy: Node2D, data: Dictionary) -> Vector2:
	if not is_instance_valid(enemy): return Vector2.ZERO
	var to_player := _player.global_position - enemy.global_position
	var distance := maxf(to_player.length(), 0.001)
	var radial := to_player / distance
	var tangent := radial.orthogonal() * float(data.get("polarity", 1.0))
	var band_error := clampf((distance - orbit_distance) / maxf(orbit_band, 1.0), -1.0, 1.0)
	var gravity_assist := _gravity_assist_direction(enemy, tangent) * orbit_tangent_force * orbit_gravity_assist
	return tangent * orbit_tangent_force + radial * band_error * orbit_radial_force + gravity_assist

func _anchor_unit_impulse(enemy: Node2D, data: Dictionary, delta: float) -> Vector2:
	if not is_instance_valid(enemy): return Vector2.ZERO
	var to_player := _player.global_position - enemy.global_position
	var distance := maxf(to_player.length(), 0.001)
	var desired := orbit_distance * 0.9
	var radial := to_player / distance
	var impulse := radial * clampf((distance - desired) / orbit_band, -1.0, 1.0) * orbit_radial_force
	
	var now := _now_seconds()
	if now >= float(data.get("next_anchor", 0.0)):
		data["next_anchor"] = now + anchor_cooldown
		_apply_anchor_field(enemy, delta)
	return impulse

func _tidal_bomber_impulse(enemy: Node2D, data: Dictionary, delta: float) -> Vector2:
	if not is_instance_valid(enemy): return Vector2.ZERO
	var to_player := _player.global_position - enemy.global_position
	var distance := maxf(to_player.length(), 0.001)
	var radial := to_player / distance
	var desired := tide_radius * 0.78
	var impulse := radial * clampf((distance - desired) / tide_radius, -1.0, 1.0) * orbit_radial_force
	
	data["next_tide"] = float(data.get("next_tide", tide_interval)) - delta
	if float(data.get("next_tide")) <= 0.0:
		data["next_tide"] = tide_interval * _rng.randf_range(0.72, 1.22)
		_apply_tidal_surge(enemy, float(data.get("polarity", 1.0)))
	return impulse

func _relativistic_sniper_impulse(enemy: Node2D, data: Dictionary) -> Vector2:
	if not is_instance_valid(enemy): return Vector2.ZERO
	var player_velocity := _body_velocity(_player)
	var predicted := _player.global_position + player_velocity * sniper_lead_time
	predicted += _nearest_gravity_vector(enemy) * sniper_orbit_bias
	var to_predicted := predicted - enemy.global_position
	var distance_to_player := enemy.global_position.distance_to(_player.global_position)
	var standoff := (enemy.global_position - _player.global_position).normalized()
	if standoff.length_squared() < 0.001:
		standoff = Vector2.RIGHT.rotated(float(data.get("phase", 0.0)))
	var desired := to_predicted.normalized() * orbit_radial_force
	if distance_to_player < sniper_standoff_distance:
		desired += standoff * orbit_radial_force * 1.2
	return desired

func _gravity_parasite_impulse(enemy: Node2D, data: Dictionary, delta: float) -> Vector2:
	if not is_instance_valid(enemy): return Vector2.ZERO
	var source := _nearest_gravity_source(enemy)
	if source == null:
		return _orbit_hunter_impulse(enemy, data) * 0.55
	var offset := source.global_position - enemy.global_position
	var distance := maxf(offset.length(), 0.001)
	var radial := offset / distance
	var tangent := radial.orthogonal() * float(data.get("polarity", 1.0))
	var latch_error := clampf((distance - parasite_well_distance) / parasite_well_distance, -1.0, 1.0)
	var impulse := radial * latch_error * parasite_latch_force + tangent * orbit_tangent_force * 0.52
	
	if enemy.global_position.distance_squared_to(source.global_position) < parasite_amplification_radius * parasite_amplification_radius:
		var to_player := (_player.global_position - source.global_position).normalized()
		CombatStatus.add_velocity(_player, to_player * parasite_amplification_strength * delta)
		anchor_field_applied.emit(enemy, source.global_position, 0.5)
	return impulse

func _drifter_impulse(enemy: Node2D) -> Vector2:
	if not is_instance_valid(enemy): return Vector2.ZERO
	var source := _nearest_gravity_source(enemy)
	if source == null: return Vector2.ZERO
	var to_source := source.global_position - enemy.global_position
	if to_source.length_squared() <= 0.001: return Vector2.ZERO
	return to_source.normalized().orthogonal() * orbit_tangent_force * 0.25

# ==================== UTILITY FUNCTIONS ====================

func _apply_anchor_field(enemy: Node2D, _delta: float) -> void:
	if not is_instance_valid(enemy): return
	for body in _nearby_bodies(enemy.global_position, anchor_radius):
		if body == enemy: continue
		var velocity := _body_velocity(body)
		if velocity == Vector2.ZERO: continue
		var damping := anchor_player_damping if body.is_in_group("Player") else anchor_damping
		CombatStatus.add_velocity(body, -velocity * damping)
		anchor_field_applied.emit(enemy, enemy.global_position, anchor_damping)

func _apply_tidal_surge(enemy: Node2D, polarity: float) -> void:
	if not is_instance_valid(enemy): return
	for body in _nearby_bodies(enemy.global_position, tide_radius):
		if body == enemy: continue
		var body_2d = body as Node2D
		if not is_instance_valid(body_2d): continue
		var offset = body_2d.global_position - enemy.global_position
		var distance := maxf(offset.length(), 0.001)
		var falloff := 1.0 - clampf(distance / tide_radius, 0.0, 1.0)
		var direction = offset / distance
		var strength := tide_push_strength if polarity > 0.0 else tide_pull_strength
		CombatStatus.add_velocity(body, direction * strength * falloff * polarity)
		tidal_surge_triggered.emit(enemy, enemy.global_position, tide_radius)

func _nearby_bodies(center: Vector2, radius: float) -> Array[Node2D]:
	_nearby_body_buffer.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(
			FIELD_TARGET_GROUPS,
			center,
			radius,
			max_bodies_per_field,
			true,
			_nearby_body_buffer
		)
		return _nearby_body_buffer

	var radius_squared := radius * radius
	var seen := {}
	
	for group_name in FIELD_TARGET_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node): continue
			var body_2d := _motion_body(node)
			if not is_instance_valid(body_2d): continue
			var id := body_2d.get_instance_id()
			if seen.has(id): continue
			seen[id] = true
			if body_2d.global_position.distance_squared_to(center) <= radius_squared:
				_nearby_body_buffer.append(body_2d)
				if _nearby_body_buffer.size() >= max_bodies_per_field:
					return _nearby_body_buffer
	return _nearby_body_buffer

func _motion_body(node: Node) -> Node2D:
	if not is_instance_valid(node): return null
	var current = node
	while current != null:
		if not is_instance_valid(current): return null
		var cur_2d := current as Node2D
		if cur_2d != null:
			if (cur_2d.get("velocity") is Vector2 or 
				cur_2d.get("linear_velocity") is Vector2 or 
				cur_2d.is_in_group("Player") or cur_2d.is_in_group("enemies")):
				return cur_2d
		current = current.get_parent()
	return null

func _gravity_assist_direction(enemy: Node2D, fallback: Vector2) -> Vector2:
	var source := _nearest_gravity_source(enemy)
	if source == null: return fallback.normalized()
	var offset := source.global_position - enemy.global_position
	if offset.length_squared() <= 0.001: return fallback.normalized()
	var tangent := offset.normalized().orthogonal()
	if tangent.dot(fallback) < 0.0: tangent = -tangent
	return tangent

func _nearest_gravity_vector(enemy: Node2D) -> Vector2:
	var source := _nearest_gravity_source(enemy)
	if source == null: return Vector2.ZERO
	var offset := source.global_position - enemy.global_position
	if offset.length_squared() <= 0.001: return Vector2.ZERO
	return offset.normalized()

func _nearest_gravity_source(enemy: Node2D) -> Node2D:
	if not is_instance_valid(enemy): return null
	var best: Node2D = null
	var best_dist := INF
	var sampled := 0
	for source in _gravity_sources:
		if sampled >= max_gravity_sources_sampled: break
		if not is_instance_valid(source) or source == enemy: continue
		sampled += 1
		var d := source.global_position.distance_squared_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = source
	return best

func _refresh_gravity_sources() -> void:
	_gravity_sources.clear()
	if RuntimeRegistry != null and is_instance_valid(_player):
		RuntimeRegistry.fill_nearest_gravity_sources(
			_player.global_position,
			_gravity_sources,
			max_gravity_sources_sampled,
			0.0,
			_player
		)
		return

	var seen := {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node): continue
			var s2d := node as Node2D
			if s2d == null or s2d.is_queued_for_deletion(): continue
			var id := s2d.get_instance_id()
			if seen.has(id): continue
			seen[id] = true
			_gravity_sources.append(s2d)
	
	if is_instance_valid(_player) and not _gravity_sources.is_empty():
		_gravity_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			if not is_instance_valid(a) or not is_instance_valid(b): return false
			return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
		)
	
	if max_gravity_sources_sampled > 0 and _gravity_sources.size() > max_gravity_sources_sampled:
		_gravity_sources.resize(max_gravity_sources_sampled)

func _wave_nudge_scale() -> float:
	if RunProgress == null:
		return 1.0
	var scene := get_tree().current_scene
	if scene == null:
		return 1.0
	var wave_director := scene.find_child("WaveDirector", true, false)
	if wave_director == null or not wave_director.has_method("get_current_wave"):
		return 1.0
	if int(wave_director.call("get_current_wave")) >= RunProgress.LATE_GAME_START_WAVE:
		return late_game_nudge_scale
	return 1.0


func _apply_limited_impulse(enemy: Node, profile: StringName, impulse: Vector2, delta: float) -> void:
	if impulse == Vector2.ZERO or not is_instance_valid(enemy):
		return
	var limited := impulse.limit_length(max_nudge_per_second * _wave_nudge_scale()) * delta
	CombatStatus.add_velocity(enemy, limited)
	enemy_physics_nudge.emit(enemy, profile, limited)

func _body_velocity(body: Node) -> Vector2:
	if not is_instance_valid(body): return Vector2.ZERO
	var v = body.get("velocity")
	if v is Vector2: return v
	v = body.get("linear_velocity")
	if v is Vector2: return v
	return Vector2.ZERO

func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func get_ai_debug_state() -> Dictionary:
	var counts := {}
	for data in _tracked.values():
		if typeof(data) == TYPE_DICTIONARY:
			var p := String(data.get("profile", &"drifter"))
			counts[p] = counts.get(p, 0) + 1
	return {"tracked": _tracked.size(), "profiles": counts}
