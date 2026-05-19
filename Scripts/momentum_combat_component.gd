extends Node2D
class_name MomentumCombatComponent

# ==========================================
# == SIGNALS ==
# ==========================================
signal momentum_state_changed(state: StringName, speed_ratio: float)
signal orbit_charge_changed(charge: float)
signal orbit_escape_boost_applied(boost: float, charge_spent: float)
signal near_miss_velocity_gained(target: Node, amount: float)
signal kinetic_overload_started(speed: float)
signal kinetic_overload_ended(speed: float)
signal kinetic_impact_dealt(target: Node, damage: float, speed: float)
signal momentum_projectile_prepared(projectile: Node, damage_multiplier: float, inherited_speed: float)
signal kinetic_shockwave_created(shockwave_data: Dictionary)
signal slingshot_mastery_triggered(data: Dictionary)
signal momentum_combo_changed(combo: int, tier: StringName, timer: float)
signal flow_state_changed(active: bool, intensity: float)

# ========================
# == EXPORT VARIABLES ==
# ========================
@export var enabled: bool = true
@export var debug_logging: bool = false

@export_group("Projectile Momentum")
@export var projectile_speed_damage_start: float = 650.0
@export var projectile_speed_damage_full: float = 1750.0
@export var projectile_max_damage_multiplier: float = 2.15
@export var projectile_velocity_inherit: float = 0.34
@export var projectile_max_inherited_speed: float = 520.0
@export var overload_projectile_damage_bonus: float = 0.35

@export_group("Orbit Assist")
@export var orbit_assist_enabled: bool = true
@export var orbit_assist_radius: float = 620.0
@export var orbit_min_distance: float = 95.0
@export var orbit_min_tangential_speed: float = 420.0
@export var orbit_charge_rate: float = 0.42
@export var orbit_charge_decay: float = 0.38
@export var orbit_escape_radial_speed: float = 190.0
@export var orbit_escape_min_charge: float = 0.34
@export var orbit_escape_boost_min: float = 160.0
@export var orbit_escape_boost_max: float = 540.0
@export var orbit_escape_cooldown: float = 0.85

@export_group("Near Miss")
@export var near_miss_enabled: bool = true
@export var near_miss_scan_interval: float = 0.08
@export var near_miss_radius: float = 82.0
@export var near_miss_inner_deadzone: float = 28.0
@export var near_miss_min_speed: float = 540.0
@export var near_miss_side_dot: float = 0.52
@export var near_miss_velocity_gain: float = 95.0
@export var near_miss_cooldown: float = 0.7

@export_group("Kinetic Impact")
@export var kinetic_impact_enabled: bool = true
@export var kinetic_impact_radius: float = 60.0
@export var kinetic_impact_min_speed: float = 760.0
@export var kinetic_impact_full_speed: float = 1850.0
@export var kinetic_impact_damage_min: float = 10.0
@export var kinetic_impact_damage_max: float = 46.0
@export var kinetic_impact_cooldown: float = 0.42
@export var kinetic_impact_player_boost: float = 58.0
@export var kinetic_impact_target_knockback: float = 380.0

@export_group("Momentum Shockwaves")
@export var shockwaves_enabled: bool = true
@export var shockwave_min_speed: float = 1050.0
@export var shockwave_radius: float = 250.0
@export var shockwave_force: float = 520.0
@export var shockwave_max_targets: int = 18
@export var shockwave_visual_enabled: bool = true

@export_group("Kinetic Overload")
@export var overload_enter_speed: float = 1450.0
@export var overload_exit_speed: float = 1120.0
@export var overload_speed_cap_bonus: float = 820.0
@export var overload_near_miss_bonus_multiplier: float = 1.35

@export_group("Momentum Preservation")
@export var speed_cap_bonus_decay: float = 640.0
@export var orbit_speed_cap_bonus: float = 420.0
@export var near_miss_speed_cap_bonus: float = 180.0
@export var impact_speed_cap_bonus: float = 260.0

@export_group("Slingshot Mastery")
@export var mastery_good_threshold: float = 0.42
@export var mastery_perfect_threshold: float = 0.82
@export var mastery_apex_threshold: float = 0.94
@export var mastery_combo_window: float = 2.6
@export var mastery_max_combo: int = 7
@export var mastery_speed_cap_bonus: float = 320.0
@export var mastery_near_miss_bonus_multiplier: float = 1.75
@export var mastery_impact_damage_bonus_per_combo: float = 0.13
@export var flow_enter_combo: int = 3
@export var flow_speed_ratio: float = 1.12
@export var flow_speed_cap_bonus: float = 360.0

@export_group("Mastery Feedback")
@export var slingshot_visuals_enabled: bool = true
@export var flow_visuals_enabled: bool = true
@export var mastery_audio_enabled: bool = true
@export var mastery_particle_cap: int = 18

# ========================
# == INTERNAL STATE ==
# ========================
var _player: CharacterBody2D = null
var _impact_area: Area2D = null

var _orbit_charge: float = 0.0
var _speed_cap_bonus: float = 0.0
var _near_miss_elapsed: float = 0.0
var _overload_active: bool = false
var _was_orbiting: bool = false

var _near_miss_cooldowns: Dictionary = {}
var _impact_cooldowns: Dictionary = {}
var _mastery_combo: int = 0
var _mastery_timer: float = 0.0
var _flow_active: bool = false
var _flow_intensity: float = 0.0
var _last_mastery_data: Dictionary = {}
var _aura_root: Node2D = null
var _aura_ring: Line2D = null
var _aura_inner: Line2D = null
var _aura_particles: GPUParticles2D = null
var _mastery_audio_stream: AudioStream = preload("res://Assets/Sound Effects/PlayerShoot.wav")
var _rng := RandomNumberGenerator.new()

# ========================
# == LIFECYCLE ==
# ========================
func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	
	if _player == null:
		push_warning("MomentumCombatComponent: Parent is not a CharacterBody2D!")
		set_physics_process(false)
		return
	
	if debug_logging:
		print("MomentumCombatComponent successfully attached to Player.")
	
	_rng.randomize()
	_build_impact_area()
	_build_flow_visuals()
	_connect_player_signals()
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(_player):
		return

	_update_mastery_timer(delta)
	_update_flow_state(delta)
	_update_flow_visuals(delta)


func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(_player):
		return
	
	_update_orbit_assist(delta)
	_update_near_misses(delta)
	_update_kinetic_overload()
	_update_speed_cap(delta)


# ========================
# == CORE SYSTEMS ==
# ========================
func _update_speed_cap(delta: float) -> void:
	if _overload_active:
		_speed_cap_bonus = maxf(_speed_cap_bonus, overload_speed_cap_bonus)

	if _flow_active:
		_speed_cap_bonus = maxf(_speed_cap_bonus, flow_speed_cap_bonus * maxf(_flow_intensity, 0.25))
	
	if _speed_cap_bonus > 0.0:
		_speed_cap_bonus = maxf(_speed_cap_bonus - speed_cap_bonus_decay * delta, 0.0)


func _get_current_speed_cap_bonus() -> float:
	return _speed_cap_bonus


func prepare_projectile(projectile: Node, direction: Vector2) -> void:
	if projectile == null or not is_instance_valid(_player):
		return
	
	var speed := _player.velocity.length()
	var damage_multiplier := _get_projectile_damage_multiplier(speed)
	var inherited_speed := minf(
		maxf(_player.velocity.dot(direction), 0.0) * projectile_velocity_inherit,
		projectile_max_inherited_speed
	)
	
	projectile.set_meta(&"momentum_damage_multiplier", damage_multiplier)
	projectile.set_meta(&"momentum_source_speed", speed)
	
	if projectile.get("initial_speed") != null:
		projectile.set("initial_speed", float(projectile.get("initial_speed")) + inherited_speed)
	
	momentum_projectile_prepared.emit(projectile, damage_multiplier, inherited_speed)


# ========================
# == DEBUG INTERFACE ==
# ========================
func get_momentum_debug_state() -> Dictionary:
	var state_name := "overload" if _overload_active else ("orbit" if _was_orbiting else "stable")
	var current_speed := _player.velocity.length() if _player else 0.0
	
	return {
		"state": state_name,
		"damage_multiplier": _get_projectile_damage_multiplier(current_speed),
		"orbit_charge": _orbit_charge,
		"speed_cap_bonus": _speed_cap_bonus,
		"near_miss_cooldowns": _near_miss_cooldowns.size(),
		"mastery_combo": _mastery_combo,
		"mastery_timer": _mastery_timer,
		"flow_active": _flow_active,
		"flow_intensity": _flow_intensity,
		"mastery_tier": String(_current_mastery_tier()),
	}


# ========================
# == OTHER SYSTEMS ==
# ========================
func _update_orbit_assist(delta: float) -> void:
	if not orbit_assist_enabled: 
		return
	
	var source = _player.get("closest_planet")
	var dist = _player.get("closest_dist")
	
	if is_instance_valid(source) and dist is float and dist < orbit_assist_radius and dist > orbit_min_distance:
		var velocity_len = _player.velocity.length()
		if velocity_len >= orbit_min_tangential_speed:
			_orbit_charge = clampf(_orbit_charge + orbit_charge_rate * delta, 0.0, 1.0)
			_speed_cap_bonus = maxf(_speed_cap_bonus, orbit_speed_cap_bonus * _orbit_charge)
			_was_orbiting = true
			orbit_charge_changed.emit(_orbit_charge)
			return
	
	_orbit_charge = maxf(_orbit_charge - orbit_charge_decay * delta, 0.0)
	_was_orbiting = false


func _update_near_misses(delta: float) -> void:
	_near_miss_elapsed += delta
	if _near_miss_elapsed < near_miss_scan_interval:
		return
	_near_miss_elapsed = 0.0
	
	var speed = _player.velocity.length()
	if speed < near_miss_min_speed:
		return
	
	var targets = get_tree().get_nodes_in_group("Objects_With_Gravity")
	for target in targets:
		if target == _player or not is_instance_valid(target):
			continue
		var target_2d := target as Node2D
		if target_2d == null or target_2d.is_queued_for_deletion():
			continue
		var dist = _player.global_position.distance_to(target_2d.global_position)
		if dist < near_miss_radius and dist > near_miss_inner_deadzone:
			var id = target_2d.get_instance_id()
			if not _near_miss_cooldowns.has(id) or Time.get_ticks_msec() > _near_miss_cooldowns[id]:
				_apply_near_miss(target_2d)
				_near_miss_cooldowns[id] = Time.get_ticks_msec() + (near_miss_cooldown * 1000)


func _apply_near_miss(target: Node) -> void:
	var boost = near_miss_velocity_gain
	_speed_cap_bonus = maxf(_speed_cap_bonus, near_miss_speed_cap_bonus)

	if _mastery_timer > 0.0:
		boost *= mastery_near_miss_bonus_multiplier
		_extend_mastery_combo(&"near_miss", _node_position_or_player(target))

	var speed := _player.velocity.length()
	var boost_dir := _player.velocity.normalized() if speed > 1.0 else -_player.transform.x.normalized()
	var base_cap := float(_player.get("max_speed")) if _player.get("max_speed") != null else 800.0
	var cap := base_cap + _speed_cap_bonus + near_miss_speed_cap_bonus
	_player.velocity = (_player.velocity + boost_dir * boost).limit_length(cap)

	near_miss_velocity_gained.emit(target, boost)


func _update_kinetic_overload() -> void:
	var speed = _player.velocity.length()
	if not _overload_active and speed >= overload_enter_speed:
		_overload_active = true
		kinetic_overload_started.emit(speed)
		momentum_state_changed.emit(&"overload", speed / maxf(overload_enter_speed, 1.0))
	elif _overload_active and speed <= overload_exit_speed:
		_overload_active = false
		kinetic_overload_ended.emit(speed)
		momentum_state_changed.emit(&"stable", speed / maxf(overload_enter_speed, 1.0))


func _get_projectile_damage_multiplier(speed: float) -> float:
	if speed < projectile_speed_damage_start:
		return 1.0
	var t = (speed - projectile_speed_damage_start) / (projectile_speed_damage_full - projectile_speed_damage_start)
	var mult = lerpf(1.0, projectile_max_damage_multiplier, clampf(t, 0.0, 1.0))
	if _overload_active:
		mult += overload_projectile_damage_bonus
	return mult


# ========================
# == HELPER FUNCTIONS ==
# ========================
func _build_impact_area() -> void:
	_impact_area = Area2D.new()
	_impact_area.name = "KineticImpactArea"
	_impact_area.collision_mask = 4294967295
	
	var coll = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = kinetic_impact_radius
	coll.shape = shape
	_impact_area.add_child(coll)
	add_child(_impact_area)
	_impact_area.body_entered.connect(_on_impact)


func _on_impact(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if not kinetic_impact_enabled or body == _player:
		return
	var speed = _player.velocity.length()
	if speed < kinetic_impact_min_speed:
		return
	
	var id = body.get_instance_id()
	if _impact_cooldowns.has(id) and Time.get_ticks_msec() < _impact_cooldowns[id]:
		return
	
	if body.has_method("take_damage"):
		var damage = lerpf(kinetic_impact_damage_min, kinetic_impact_damage_max, clampf(speed / kinetic_impact_full_speed, 0.0, 1.0))
		if _mastery_combo > 0:
			damage *= 1.0 + float(_mastery_combo) * mastery_impact_damage_bonus_per_combo
		body.call("take_damage", damage)
		_speed_cap_bonus = maxf(_speed_cap_bonus, impact_speed_cap_bonus)
		_impact_cooldowns[id] = Time.get_ticks_msec() + (kinetic_impact_cooldown * 1000)
		kinetic_impact_dealt.emit(body, damage, speed)
		if _mastery_timer > 0.0:
			var impact_position := _node_position_or_player(body)
			_extend_mastery_combo(&"impact", impact_position)
			_spawn_impact_mastery_flash(impact_position, damage)
		if shockwaves_enabled and speed >= shockwave_min_speed:
			_create_kinetic_shockwave(body, speed)


func _connect_player_signals() -> void:
	if _player.has_signal("slingshot_assist_applied"):
		_player.slingshot_assist_applied.connect(_on_slingshot)
	if _player.has_signal("slingshot_mastery_scored"):
		_player.slingshot_mastery_scored.connect(_on_slingshot_mastery_scored)


func _on_slingshot(_source, _grav, _impulse, strength, _speed) -> void:
	_speed_cap_bonus = maxf(_speed_cap_bonus, strength * 0.5)

func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 0.65)
	if score < mastery_good_threshold:
		if slingshot_visuals_enabled:
			_spawn_slingshot_mastery_visual(data, false)
		return

	var increment := 1
	if score >= mastery_apex_threshold:
		increment = 3
	elif score >= mastery_perfect_threshold:
		increment = 2

	_mastery_combo = mini(_mastery_combo + increment, mastery_max_combo)
	_mastery_timer = mastery_combo_window + score * 0.85
	_speed_cap_bonus = maxf(
		_speed_cap_bonus,
		mastery_speed_cap_bonus * (0.75 + score) * (1.0 + float(_mastery_combo - 1) * 0.12)
	)

	var enriched := data.duplicate(true)
	enriched["combo"] = _mastery_combo
	enriched["tier"] = _current_mastery_tier()
	enriched["flow_intensity"] = _flow_intensity
	_last_mastery_data = enriched

	momentum_combo_changed.emit(_mastery_combo, _current_mastery_tier(), _mastery_timer)
	slingshot_mastery_triggered.emit(enriched)

	if slingshot_visuals_enabled:
		_spawn_slingshot_mastery_visual(enriched, true)
	if mastery_audio_enabled:
		_play_mastery_whoosh(enriched)

func modify_slingshot_impulse(impulse: Vector2, _gravity: Vector2, _delta: float) -> Vector2:
	if not enabled or impulse.length_squared() <= 0.001:
		return impulse

	var orbit_bonus := 1.0 + _orbit_charge * 0.28
	var overload_bonus := 1.12 if _overload_active else 1.0
	var mastery_bonus := 1.0 + float(_mastery_combo) * 0.035 + _flow_intensity * 0.08
	return impulse * orbit_bonus * overload_bonus * mastery_bonus

func _create_kinetic_shockwave(primary_target: Node, speed: float) -> void:
	if primary_target == null or not is_instance_valid(primary_target):
		return

	var center_node := primary_target as Node2D
	if center_node == null:
		center_node = _player
	var center := center_node.global_position
	var radius_squared := shockwave_radius * shockwave_radius
	var affected := 0
	var seen := {}

	for group_name in [&"enemies", &"wave_enemy", &"Projectiles", &"enemy_projectiles"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if affected >= shockwave_max_targets:
				break
			if candidate == _player or candidate == primary_target:
				continue
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
				continue

			var candidate_2d := candidate as Node2D
			if candidate_2d == null:
				continue

			var id := candidate_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true

			var offset := candidate_2d.global_position - center
			var dist_squared := offset.length_squared()
			if dist_squared <= 0.001 or dist_squared > radius_squared:
				continue

			var falloff := 1.0 - sqrt(dist_squared) / shockwave_radius
			CombatStatus.add_velocity(candidate_2d, offset.normalized() * shockwave_force * falloff)
			affected += 1

	kinetic_shockwave_created.emit({
		"position": center,
		"radius": shockwave_radius,
		"speed": speed,
		"affected": affected,
	})

	if shockwave_visual_enabled:
		_spawn_shockwave_visual(center)

func _spawn_shockwave_visual(center: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := Line2D.new()
	ring.name = "KineticShockwave"
	ring.closed = true
	ring.antialiased = true
	ring.width = 2.0
	ring.default_color = Color(0.42, 0.95, 1.0, 0.28)
	ring.points = _circle_points(48, 1.0)
	ring.global_position = center
	ring.scale = Vector2.ONE * 8.0
	ring.z_index = 24
	root.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * (shockwave_radius * 0.45), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)

func _update_mastery_timer(delta: float) -> void:
	if _mastery_timer <= 0.0:
		if _mastery_combo != 0:
			_mastery_combo = 0
			momentum_combo_changed.emit(_mastery_combo, &"idle", 0.0)
		return

	_mastery_timer = maxf(_mastery_timer - delta, 0.0)
	if _mastery_timer <= 0.0:
		_mastery_combo = 0
		momentum_combo_changed.emit(_mastery_combo, &"idle", 0.0)

func _update_flow_state(delta: float) -> void:
	var speed_ratio := 0.0
	if is_instance_valid(_player):
		var cap_value: Variant = _player.get("current_max_speed")
		var cap := _player.velocity.length()
		if typeof(cap_value) == TYPE_FLOAT or typeof(cap_value) == TYPE_INT:
			cap = float(cap_value)
		cap = maxf(cap, 1.0)
		speed_ratio = _player.velocity.length() / cap

	var combo_pressure := clampf(float(_mastery_combo) / float(maxi(flow_enter_combo, 1)), 0.0, 1.25)
	var speed_pressure := clampf(speed_ratio / maxf(flow_speed_ratio, 0.1), 0.0, 1.25)
	var target_intensity := clampf(maxf(combo_pressure, speed_pressure) - 0.55, 0.0, 1.0)
	if _overload_active:
		target_intensity = maxf(target_intensity, 0.62)

	_flow_intensity = lerpf(_flow_intensity, target_intensity, clampf(delta * 6.0, 0.0, 1.0))
	var next_active := _flow_intensity > 0.18
	if next_active != _flow_active:
		_flow_active = next_active
		flow_state_changed.emit(_flow_active, _flow_intensity)

func _extend_mastery_combo(reason: StringName, event_position: Vector2) -> void:
	if _mastery_combo <= 0:
		return

	_mastery_combo = mini(_mastery_combo + 1, mastery_max_combo)
	_mastery_timer = maxf(_mastery_timer, mastery_combo_window * 0.72)
	_speed_cap_bonus = maxf(_speed_cap_bonus, mastery_speed_cap_bonus * 0.72)
	momentum_combo_changed.emit(_mastery_combo, _current_mastery_tier(), _mastery_timer)

	var data := _last_mastery_data.duplicate(true)
	data["combo"] = _mastery_combo
	data["tier"] = _current_mastery_tier()
	data["reason"] = reason
	data["position"] = event_position
	
	# BUG FIX 1: This is intentionally removed to stop the HUD from rapidly flashing with redundant triggers
	# slingshot_mastery_triggered.emit(data) 

	if slingshot_visuals_enabled:
		_spawn_combo_ping(event_position, reason)

func _current_mastery_tier() -> StringName:
	if _mastery_combo >= mastery_max_combo:
		return &"god_vector"
	if _mastery_combo >= flow_enter_combo:
		return &"flow"
	if _mastery_combo > 0:
		return &"charged"
	return &"idle"

func _build_flow_visuals() -> void:
	if not flow_visuals_enabled:
		return

	_aura_root = Node2D.new()
	_aura_root.name = "MomentumFlowAura"
	_aura_root.z_index = 32
	add_child(_aura_root)

	_aura_ring = Line2D.new()
	_aura_ring.name = "OuterVectorRing"
	_aura_ring.closed = true
	_aura_ring.antialiased = true
	_aura_ring.width = 2.5
	_aura_ring.points = _circle_points(72, 52.0)
	_aura_root.add_child(_aura_ring)

	_aura_inner = Line2D.new()
	_aura_inner.name = "InnerVectorRing"
	_aura_inner.closed = true
	_aura_inner.antialiased = true
	_aura_inner.width = 1.4
	_aura_inner.points = _circle_points(36, 34.0)
	_aura_root.add_child(_aura_inner)

	if mastery_particle_cap > 0:
		_aura_particles = GPUParticles2D.new()
		_aura_particles.name = "FlowIonParticles"
		_aura_particles.amount = mastery_particle_cap
		_aura_particles.lifetime = 0.75
		_aura_particles.randomness = 0.38
		_aura_particles.local_coords = true
		_aura_particles.process_material = _make_flow_particle_material()
		_aura_root.add_child(_aura_particles)

	_aura_root.visible = false

func _update_flow_visuals(delta: float) -> void:
	if not flow_visuals_enabled or _aura_root == null or not is_instance_valid(_aura_root):
		return

	var visible := _flow_intensity > 0.04 or _mastery_combo > 0
	_aura_root.visible = visible
	if not visible:
		if _aura_particles != null:
			_aura_particles.emitting = false
		return

	var combo_alpha := float(_mastery_combo) / float(maxi(mastery_max_combo, 1))
	var intensity := clampf(maxf(_flow_intensity, combo_alpha * 0.72), 0.0, 1.0)
	var hot := _current_mastery_tier() == &"god_vector"
	var color := Color(0.18, 0.96, 1.0, lerpf(0.16, 0.88, intensity))
	if hot:
		color = Color(1.0, 0.88, 0.32, lerpf(0.26, 0.96, intensity))

	_aura_root.rotation += delta * lerpf(1.4, 4.8, intensity)
	_aura_root.scale = Vector2.ONE * lerpf(0.96, 1.08, intensity)

	if _aura_ring != null:
		_aura_ring.width = lerpf(0.8, 2.4, intensity)
		_aura_ring.default_color = color
	if _aura_inner != null:
		_aura_inner.rotation = -_aura_root.rotation * 1.7
		_aura_inner.width = lerpf(0.6, 1.8, intensity)
		_aura_inner.default_color = Color(1.0, 1.0, 1.0, color.a * 0.54)
	if _aura_particles != null:
		_aura_particles.emitting = intensity > 0.16
		_aura_particles.amount = int(lerpf(12.0, float(mastery_particle_cap), intensity))

func _spawn_slingshot_mastery_visual(data: Dictionary, mastered: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var fallback_center := _player.global_position if is_instance_valid(_player) else global_position
	var center: Vector2 = data.get("position", fallback_center)
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var grade := StringName(data.get("grade", &"assist"))
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	tangent = tangent.normalized()

	var color := _grade_color(grade, mastered)
	var radius := lerpf(18.0, 52.0, score)
	var width := lerpf(1.0, 3.0, score)
	var duration := lerpf(0.18, 0.34, score)

	var ring := Line2D.new()
	ring.name = "SlingshotMasteryRing"
	ring.closed = true
	ring.antialiased = true
	ring.width = width
	ring.default_color = color
	ring.points = _circle_points(80, 10.0)
	ring.global_position = center
	ring.rotation = tangent.angle()
	# BUG FIX 2: Start the ring much larger so it diffuses the light
	ring.scale = Vector2.ONE * lerpf(4.0, 8.0, score)
	ring.z_index = 38
	root.add_child(ring)

	var vector_line := Line2D.new()
	vector_line.name = "SlingshotVectorFlash"
	vector_line.antialiased = true
	# BUG FIX 3: Thinner and shorter vector flash
	vector_line.width = width * 0.05
	vector_line.default_color = Color(1.0, 1.0, 1.0, color.a * 0.12)
	vector_line.points = PackedVector2Array([
		-tangent * radius * 0.05,
		tangent * radius * 0.15,
	])
	vector_line.global_position = center
	vector_line.z_index = 39
	root.add_child(vector_line)

	var tween := ring.create_tween()
	tween.tween_property(ring,"scale",Vector2.ONE * lerpf(10.0, 22.0, score),duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)

	var line_tween := vector_line.create_tween()
	line_tween.tween_property(vector_line, "modulate:a", 0.0, duration * 0.78)
	# Removed the parallel tween here that caused the vector flash to scale and bloom
	line_tween.tween_callback(vector_line.queue_free)

func _spawn_combo_ping(position: Vector2, reason: StringName) -> void:
	var color := Color(0.35, 1.0, 0.84, 0.58)
	if reason == &"impact":
		color = Color(1.0, 0.72, 0.26, 0.88)
	_spawn_transient_ring(position, 24.0 + 6.0 * float(_mastery_combo), color, 0.18, 3.5)

func _spawn_impact_mastery_flash(position: Vector2, damage: float) -> void:
	# BUG FIX 4: Smaller radius base, clamped damage scaling, reduced width and transparency
	var radius := 36.0 + clampf(damage * 0.5, 0.0, 60.0) 
	_spawn_transient_ring(position, radius, Color(1.0, 0.32, 0.18, 0.45), 0.22, 2.5)

func _spawn_transient_ring(center: Vector2, radius: float, color: Color, duration: float, width: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := Line2D.new()
	ring.name = "MomentumComboPing"
	ring.closed = true
	ring.antialiased = true
	ring.width = width
	ring.default_color = color
	ring.points = _circle_points(36, 1.0)
	ring.global_position = center
	ring.scale = Vector2.ONE * 2.0
	ring.z_index = 37
	root.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * radius, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)

func _play_mastery_whoosh(data: Dictionary) -> void:
	if DisplayServer.get_name() == "headless" or _mastery_audio_stream == null:
		return

	var root := get_tree().current_scene
	if root == null:
		return

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var player := AudioStreamPlayer2D.new()
	player.name = "SlingshotMasteryWhoosh"
	player.stream = _mastery_audio_stream
	var fallback_position := _player.global_position if is_instance_valid(_player) else global_position
	player.global_position = data.get("position", fallback_position)
	player.pitch_scale = lerpf(0.72, 1.58, score) + float(_mastery_combo) * 0.035
	player.volume_db = lerpf(-18.0, -5.0, score)
	player.bus = &"Player Sound Effects"
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _grade_color(grade: StringName, mastered: bool) -> Color:
	match grade:
		&"apex":
			return Color(1.0, 0.9, 0.25, 0.28)
		&"perfect":
			return Color(0.35, 1.0, 0.88, 0.66)
		&"great":
			# BUG FIX 5: Dropped the transparency of the 'great' UI ping down to 0.10
			return Color(0.22, 0.72, 1.0, 0.10)
		&"good":
			return Color(0.42, 0.86, 1.0, 0.42)
	return Color(0.48, 0.66, 0.84, 0.68 if mastered else 0.46)

func _make_flow_particle_material() -> ParticleProcessMaterial:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.26, 1.0, 0.88, 0.82))
	gradient.set_color(1, Color(0.22, 0.38, 1.0, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 42.0
	material.spread = 180.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 4.0
	material.orbit_velocity_min = -1.2
	material.orbit_velocity_max = 1.2
	material.radial_accel_min = -24.0
	material.radial_accel_max = 18.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.4
	material.scale_max = 4.8
	material.color_ramp = texture
	return material

func _node_position_or_player(node: Node) -> Vector2:
	var node_2d := node as Node2D
	if node_2d != null and is_instance_valid(node_2d):
		return node_2d.global_position
	if is_instance_valid(_player):
		return _player.global_position
	return global_position

func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
