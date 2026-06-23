# Player Controller with Improved Slingshot Mechanics
extends CharacterBody2D

signal slingshot_assist_applied(source: Node, gravity: Vector2, impulse: Vector2, assist_strength: float, speed: float)
signal slingshot_mastery_scored(data: Dictionary)
signal slingshot_window_changed(data: Dictionary)
signal momentum_projectile_spawned(projectile: Node, direction: Vector2)
signal death_lesson_generated(lesson: String)
signal player_hit_invulnerability_started(duration: float)
signal damage_ignored_during_invulnerability(amount: float)
signal planet_super_boost_activated(source: Node, impulse: Vector2, energy_spent: float)

# ========================
# == EXPORT VARIABLES ==
# ========================

@export var thrust_power: float = 4150.0
@export var rotation_speed: float = 9.0
@export var orbit_alignment_assist_strength: float = 0.08
@export var max_speed: float = 1000.0
@export var drag: float = 0.97
@export var idle_drag: float = 0.9
@export var drag_disabled_speed_multiplier: float = 1.34
@export var dash_speed_cap: float = 2300.0
@export var absolute_velocity_cap: float = 2800.0
@export var high_speed_thrust_falloff_start: float = 0.86
@export var counter_thrust_control_bonus: float = 0.38
@export var lateral_thrust_control_bonus: float = 0.24

@export_group("Drag Precision")
@export var drag_precision_alignment_rate: float = 6.4
@export var drag_precision_brake_blend: float = 0.44
@export var drag_gravity_turn_blend: float = 0.28
@export_range(0.0, 1.0, 0.01) var drag_tangent_assist_min_ratio: float = 0.4
@export var drag_slingshot_energy_recovery: float = 5.0
@export var drag_precision_min_speed: float = 190.0

@export_group("Gravity")
@export var gravity_constant: float = 400.0
@export var min_grav_dist: float = 50.0
@export var gravity_pull_radius: float = 1800.0
@export var max_gravity_sources: int = 4
@export var gravity_source_refresh_interval: float = 0.35
@export var max_gravity_acceleration_per_source: float = 3600.0
@export var max_total_gravity_acceleration: float = 7200.0

@export_group("Slingshot")
@export var slingshot_factor: float = 1.48
@export var slingshot_max_impulse: float = 640.0
@export var slingshot_speed_cap: float = 2480.0
@export var slingshot_cooldown: float = 0.24
@export var slingshot_min_tangential_speed: float = 210.0
@export var slingshot_gravity_boost_scale: float = 2.55
@export var slingshot_proximity_boost_scale: float = 0.32
@export var slingshot_proximity_max_impulse_per_second: float = 360.0
@export var slingshot_proximity_close_margin: float = 48.0
@export var slingshot_proximity_curve: float = 1.35
@export var slingshot_sweet_spot_distance: float = 265.0
@export var slingshot_sweet_spot_width: float = 170.0
@export var slingshot_perfect_score: float = 0.8
@export var slingshot_apex_score: float = 0.93
@export var slingshot_mastery_cap_bonus: float = 300.0
@export var slingshot_camera_kick: float = 20.0
@export var slingshot_camera_roll: float = 0.034
@export var slingshot_burst_scale: float = 0.46
@export var slingshot_min_burst_impulse: float = 45.0
@export_range(0.0, 1.0, 0.01) var slingshot_impulse_immediate_ratio: float = 0.58
@export var slingshot_impulse_smoothing_time: float = 0.11
@export var slingshot_precision_grace_duration: float = 0.34
@export_range(0.0, 1.0, 0.01) var slingshot_precision_grace_blend: float = 0.2
@export var slingshot_inward_pull_scale: float = 0.2
@export_range(0.0, 1.0, 0.01) var slingshot_outward_damping: float = 0.26
@export_range(0.0, 1.0, 0.01) var slingshot_min_curve_score: float = 0.28
@export_range(0.0, 1.0, 0.01) var slingshot_min_entry_factor: float = 0.46
@export_range(0.0, 1.0, 0.01) var slingshot_passive_curve_scale: float = 0.58
@export_range(0.0, 1.0, 0.01) var slingshot_departure_penalty: float = 0.72
@export var recoil_instability: float = 0.0
@export var max_gravity_anchors: int = 1
@export var orbit_control_bonus: float = 0.0

@export_group("Energy")
@export var energy_cost_per_work: float = 0.00001
@export var minimum_thrust_energy_cost_per_second: float = 5.0
@export var gravity_charge_per_work: float = 0.0001

@export_group("Planet Super Boost")
@export var super_boost_enabled: bool = true
@export var super_boost_stuck_seconds: float = 0.42
@export var super_boost_energy_cost: float = 140.0
@export var super_boost_impulse: float = 1250.0
@export var super_boost_clearance: float = 96.0
@export var super_boost_stuck_speed_threshold: float = 360.0
@export_range(0.0, 1.0, 0.01) var super_boost_tangent_bias: float = 0.76
@export var super_boost_cooldown: float = 0.75
@export var pin_escape_enabled: bool = false
@export var pin_escape_seconds: float = 0.28
@export var pin_escape_impulse: float = 760.0
@export var pin_escape_cooldown: float = 0.36
@export_range(0.0, 1.0, 0.01) var pin_escape_tangent_bias: float = 0.34

@export_group("Shooting")
@export var projectile_hold_fire_interval: float = 0.18

@export_group("Death")
@export var death_watch_duration: float = 0.82

@export_group("Damage Grace")
@export var post_hit_invulnerability_seconds: float = 0.62
@export var post_hit_invulnerability_flash_rate: float = 14.0

@export_group("Network")
@export var network_state_send_interval: float = 0.035
@export var network_position_lerp_rate: float = 18.0
@export var network_velocity_lerp_rate: float = 14.0
@export var network_nameplate_offset: Vector2 = Vector2(0.0, -72.0)
@export var network_nameplate_font_size: int = 13
@export var network_nameplate_visible_for_local: bool = true

@export_group("Camera")
@export var mouse_camera_offset_distance: float = 180.0
@export var trackpad_camera_offset_distance: float = 54.0
@export_range(0.05, 1.0, 0.01) var trackpad_camera_follow_weight_scale: float = 0.72

# ========================
# == STATE VARIABLES ==
# ========================

var current_max_speed: float = 800.0
var planets: Array = []

var DRAG_enabled = true
var drag_enabled_by_player = true
var _dash_drag_suppressed = false
var can_dash = true

var last_thrust_release = 0.0

var shields_on = false
var shield_health = 10

var shield_component: Node = null
var powerup_inventory: PowerupInventory = null

var _gravity_refresh_elapsed = 0.0

var closest_planet: Node = null
var closest_dist: float = INF

var last_slingshot_strength: float = 0.0
var last_slingshot_source: Node = null
var last_slingshot_time: float = -999.0
var last_slingshot_score: float = 0.0
var last_slingshot_grade: StringName = &"none"
var last_slingshot_window: Dictionary = {}

var slingshot_ready: bool = true
var _last_slingshot_window_state: StringName = &"offline"
var _camera_base_rotation: float = 0.0
var _camera_feedback_offset: Vector2 = Vector2.ZERO
var _camera_feedback_roll: float = 0.0
var _next_held_projectile_time: float = 0.0
var _slingshot_precision_until: float = -999.0

var menu_is_hidden := true
var time_tween: Tween
var _last_damage_amount: float = 0.0
var _last_damage_time: float = -999.0
var _damage_invulnerable_until: float = -999.0
var _invulnerability_flash_elapsed: float = 0.0
var _death_in_progress: bool = false
var _gravity_source_query: Array[Node2D] = []
var _planet_stuck_time: float = 0.0
var _planet_stuck_source_id: int = 0
var _last_super_boost_time: float = -999.0
var _last_pin_escape_time: float = -999.0
var _pending_slingshot_impulse: Vector2 = Vector2.ZERO
var _pending_slingshot_cap: float = 0.0
var _pending_slingshot_time_left: float = 0.0
var network_peer_id: int = 1
var network_is_local: bool = true
var network_display_name: String = "VECTOR"
var network_color: Color = Color(0.08, 0.88, 1.0, 1.0)
var _network_send_elapsed: float = 0.0
var _remote_target_position: Vector2 = Vector2.ZERO
var _remote_target_velocity: Vector2 = Vector2.ZERO
var _remote_target_rotation: float = 0.0
var _remote_state_received: bool = false
var _network_nameplate: Label = null
# ========================
# == NODE REFERENCES ==
# ========================

@onready var camera = $Camera2D
@onready var drag_label = $CanvasLayer/Drag
@onready var health_label = $CanvasLayer/Health
@onready var energy_label = $CanvasLayer/Energy

@onready var shield_node = $Shield
@onready var dash_timer = $Dash
@onready var energy_component = $EnergyComponent

@onready var health_component = get_node_or_null("HealthComponent")
@onready var projectile_scene = preload("res://Nodes/projectile.tscn")
@onready var hull_polygon: Polygon2D = get_node_or_null("Polygon2D") as Polygon2D
@onready var shield_polygon: Polygon2D = get_node_or_null("Shield/Polygon2D") as Polygon2D

# ========================
# == READY ==
# ========================

func _ready():
	_refresh_gravity_sources(true)
	_bind_shield()
	_ensure_powerup_inventory()
	_connect_pause_menu_state()

	if Settings.input_type == false:
		camera.ignore_rotation = true
		camera.rotation_degrees = 0
	#else:
	#	camera.ignore_rotation = false
	#	camera.rotation_degrees = 270

	_camera_base_rotation = camera.rotation
	_ensure_network_nameplate()
	_apply_network_locality()
	_update_network_nameplate()

func _connect_pause_menu_state() -> void:
	var pause_menu := get_pause_menu()
	if pause_menu == null or not pause_menu.has_signal("pause_state_changed"):
		return

	var callable := Callable(self, "_on_pause_menu_state_changed")
	if not pause_menu.is_connected("pause_state_changed", callable):
		pause_menu.connect("pause_state_changed", callable)
	_sync_pause_menu_state(pause_menu)

func _on_pause_menu_state_changed(blocked: bool) -> void:
	menu_is_hidden = not blocked

# ========================
# == PHYSICS LOOP ==
# ========================

func _physics_process(delta: float):
	if not network_is_local:
		_apply_remote_network_state(delta)
		return

	if _death_in_progress:
		_pending_slingshot_impulse = Vector2.ZERO
		_pending_slingshot_time_left = 0.0
		velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
		_submit_network_state(delta)
		return

	# 1. ALWAYS process inputs first so state updates map cleanly to forces
	handle_input()
	
	# 2. Safety Lock: If the cinematic pause menu is actively dropping time scale down,
	# completely halt space movement processing to prevent calculation stutter.
	if _is_pause_blocking():
		return

	_gravity_refresh_elapsed += delta

	var gravity = calculate_gravity()
	_update_slingshot_window(gravity)
	_update_planet_stuck_state(delta)
	_apply_planet_pin_escape()

	handle_rotation(delta)

	# Apply forces
	apply_thrust(delta)
	apply_slingshot(gravity, delta)
	apply_gravity(gravity, delta)

	# Movement & resistance
	apply_drag(gravity, delta)
	update_max_speed(delta)

	# Constraints
	_drain_smoothed_slingshot_impulse(delta)
	clamp_velocity()
	move_and_slide()

	# Energy reactions
	apply_gravity_recharge(gravity, delta)
	update_ui()
	_submit_network_state(delta)

# ========================
# == GRAVITY SYSTEM ==
# ========================

func calculate_gravity() -> Vector2:
	var total = Vector2.ZERO

	closest_dist = INF
	closest_planet = null

	_refresh_gravity_sources(false)

	for i in range(planets.size() - 1, -1, -1):
		var p = planets[i]

		if not is_instance_valid(p):
			planets.remove_at(i)
			continue

		var offset = p.global_position - global_position
		var raw_dist = offset.length()

		var dist = max(raw_dist, min_grav_dist)

		if gravity_pull_radius > 0.0 and raw_dist > gravity_pull_radius:
			continue

		if raw_dist < closest_dist:
			closest_dist = raw_dist
			closest_planet = p

		if raw_dist > 0.001:
			var dir = offset / raw_dist

			var mass_value: Variant = p.get("mass")
			var mass_type = typeof(mass_value)

			var source_mass = float(mass_value) if mass_type == TYPE_FLOAT or mass_type == TYPE_INT else 100.0

			var strength = gravity_constant * source_mass / (dist * dist)
			var contribution = (dir * strength).limit_length(maxf(max_gravity_acceleration_per_source, 1.0))
			total = (total + contribution).limit_length(maxf(max_total_gravity_acceleration, 1.0))

	return total

# ========================
# == ROTATION ==
# ========================

func handle_rotation(delta: float) -> void:
	if Settings.input_type:
		var aim_direction := _controller_aim_vector()
		if aim_direction.length() > 0.70:
			rotation = (-aim_direction).angle()
	else:
		rotation = (global_position - get_global_mouse_position()).angle() #This may look opposite, but it works correctly.
	if Settings != null and bool(Settings.alternate_movement_enabled):
		var side_input := _alternate_side_input()
		if absf(side_input) > 0.001:
			rotation += side_input * clampf(float(Settings.strafe_turn_assist), 0.0, 0.6)

# ========================
# == SLINGSHOT SYSTEM ==
# ========================

func apply_slingshot(gravity: Vector2, delta: float):
	if not _has_orbital_juice_manager():
		apply_regular_slingshot(gravity, delta)
		return
	last_slingshot_strength = maxf(last_slingshot_strength - delta * 2.0, 0.0)
	_try_apply_slingshot_proximity_boost(gravity, delta)

	if not slingshot_ready:
		return

	if not is_instance_valid(closest_planet):
		return
	if velocity.length() < 1.0:
		return
	if closest_dist > 500.0 or closest_dist < 70.0:
		return
	if gravity.length_squared() <= 0.001:
		return

	var impulse := Vector2.ZERO
	var radial = global_position - closest_planet.global_position
	if radial.length_squared() <= 0.001:
		return

	var radial_dir = radial.normalized()
	var tangent = radial_dir.orthogonal()

	if tangent.dot(velocity) < 0:
		tangent = -tangent

	var tangential_speed = maxf(velocity.dot(tangent), 0.0)
	if tangential_speed < slingshot_min_tangential_speed:
		return

	var inward_speed = maxf(velocity.dot(-radial_dir), 0.0)
	var outward_speed = maxf(velocity.dot(radial_dir), 0.0)
	var speed_before := velocity.length()
	var quality_data := _score_slingshot_window(gravity, radial_dir, tangent, tangential_speed, inward_speed)
	var slingshot_score := float(quality_data.get("score", 0.0))
	var proximity_score := float(quality_data.get("proximity_score", 0.0))
	var entry_factor := float(quality_data.get("entry_factor", 1.0))
	if slingshot_score < slingshot_min_curve_score or entry_factor < slingshot_min_entry_factor:
		return
	var quality_bonus := lerpf(0.92, 1.24, slingshot_score)
	var speed_factor = clampf(tangential_speed / maxf(slingshot_speed_cap, 1.0), 0.28, 1.12)
	var assist_strength = gravity.length() * speed_factor * slingshot_gravity_boost_scale * lerpf(0.52, 1.0, entry_factor)
	var inward_pull := Vector2.ZERO
	var outward_damp := 0.0
	if assist_strength > 0:
		var auto_orbit_assist := _player_auto_orbit_enabled()
		var curve_scale := 1.0 if auto_orbit_assist else slingshot_passive_curve_scale
		inward_pull = (
			-radial_dir
			* minf(
				gravity.length()
				* slingshot_inward_pull_scale
				* curve_scale
				* lerpf(0.35, 0.95, slingshot_score)
				* lerpf(0.55, 1.0, entry_factor),
				slingshot_max_impulse * (0.2 if auto_orbit_assist else 0.12)
			)
		)
		outward_damp = minf(
			outward_speed * slingshot_outward_damping * curve_scale * lerpf(0.75, 1.35, 1.0 - entry_factor),
			slingshot_max_impulse * (0.22 if auto_orbit_assist else 0.14)
		)
		if outward_damp > 0.0:
			velocity -= radial_dir * outward_damp
		if inward_pull.length_squared() > 0.001:
			velocity += inward_pull

		var burst_scale := maxf(slingshot_burst_scale, 0.0) * lerpf(0.58, 0.92, slingshot_score)
		impulse = tangent * assist_strength * (slingshot_factor + orbit_control_bonus) * quality_bonus * burst_scale
		var minimum_impulse := slingshot_min_burst_impulse * clampf((slingshot_score - 0.32) / 0.68, 0.0, 1.0)
		if minimum_impulse > 0.0 and impulse.length() < minimum_impulse:
			impulse = tangent * minimum_impulse

		var impulse_cap := slingshot_max_impulse * lerpf(0.72, 1.08, slingshot_score) * lerpf(0.92, 1.18, proximity_score)
		if impulse.length() > impulse_cap:
			impulse = impulse.normalized() * impulse_cap

		var momentum_comp = get_node_or_null("MomentumCombatComponent")
		if momentum_comp != null and momentum_comp.has_method("modify_slingshot_impulse"):
			impulse = momentum_comp.modify_slingshot_impulse(impulse, gravity, delta)
			impulse = tangent * maxf(impulse.dot(tangent), 0.0)

		var proposed = velocity + impulse
		var mastery_speed_cap := slingshot_speed_cap + slingshot_mastery_cap_bonus * maxf(slingshot_score, proximity_score * 0.65)
		if proposed.length() > mastery_speed_cap:
			var allowed = max(0, mastery_speed_cap - velocity.length())
			if allowed > 0:
				impulse = impulse.normalized() * min(impulse.length(), allowed)
			else:
				impulse = Vector2.ZERO

		_apply_smoothed_slingshot_impulse(impulse, mastery_speed_cap)
		current_max_speed = maxf(current_max_speed, minf(mastery_speed_cap, maxf(velocity.length(), max_speed)))
		_slingshot_precision_until = _now_seconds() + maxf(slingshot_precision_grace_duration, 0.0)
		var effective_strength := minf(
			maxf(impulse.length(), inward_pull.length() + outward_damp),
			slingshot_max_impulse * 1.08
		)

		last_slingshot_strength = maxf(last_slingshot_strength, effective_strength)
		last_slingshot_source = closest_planet
		last_slingshot_time = Time.get_ticks_msec() / 1000.0
		last_slingshot_score = slingshot_score
		last_slingshot_grade = _slingshot_grade_for_score(slingshot_score)
		slingshot_ready = false

		var mastery_data := quality_data.duplicate()
		mastery_data["source"] = closest_planet
		mastery_data["gravity"] = gravity
		mastery_data["impulse"] = impulse
		mastery_data["assist_strength"] = effective_strength
		mastery_data["inward_pull"] = inward_pull
		mastery_data["outward_damp"] = outward_damp
		mastery_data["outward_speed_before"] = outward_speed
		mastery_data["speed_before"] = speed_before
		mastery_data["speed_after"] = velocity.length()
		mastery_data["grade"] = last_slingshot_grade
		mastery_data["position"] = global_position
		mastery_data["source_position"] = closest_planet.global_position
		mastery_data["time"] = last_slingshot_time
		last_slingshot_window = mastery_data
		_apply_slingshot_camera_feedback(mastery_data)

		slingshot_assist_applied.emit(
			closest_planet,
			gravity,
			impulse,
			effective_strength,
			velocity.length()
		)
		slingshot_mastery_scored.emit(mastery_data)
		if is_inside_tree():
			get_tree().create_timer(slingshot_cooldown).connect("timeout", Callable(self, "_on_slingshot_cooldown"))

func _try_apply_slingshot_proximity_boost(gravity: Vector2, delta: float) -> Vector2:
	if slingshot_proximity_boost_scale <= 0.0 or delta <= 0.0:
		return Vector2.ZERO
	if not is_instance_valid(closest_planet):
		return Vector2.ZERO
	var source := closest_planet as Node2D
	if source == null:
		return Vector2.ZERO
	if velocity.length() < 1.0:
		return Vector2.ZERO
	if closest_dist > 500.0 or closest_dist < 70.0:
		return Vector2.ZERO
	if gravity.length_squared() <= 0.001:
		return Vector2.ZERO

	var radial: Vector2 = global_position - source.global_position
	if radial.length_squared() <= 0.001:
		return Vector2.ZERO

	var radial_dir: Vector2 = radial.normalized()
	var tangent: Vector2 = radial_dir.orthogonal()
	if tangent.dot(velocity) < 0.0:
		tangent = -tangent

	var tangential_speed := maxf(velocity.dot(tangent), 0.0)
	if tangential_speed < slingshot_min_tangential_speed:
		return Vector2.ZERO
	var inward_speed := maxf(velocity.dot(-radial_dir), 0.0)
	var outward_speed := maxf(velocity.dot(radial_dir), 0.0)
	var entry_factor := _slingshot_entry_factor(inward_speed, outward_speed, tangential_speed)
	if entry_factor < slingshot_min_entry_factor:
		return Vector2.ZERO

	var proximity_score := _slingshot_proximity_score(source)
	if proximity_score <= 0.001:
		return Vector2.ZERO

	var auto_orbit_assist := _player_auto_orbit_enabled()
	var curve_scale := 1.0 if auto_orbit_assist else slingshot_passive_curve_scale
	var curve := maxf(slingshot_proximity_curve, 0.01)
	var tangent_ratio := tangential_speed / maxf(velocity.length(), 1.0)
	var proximity_strength := (
		gravity.length()
		* clampf(tangent_ratio, 0.0, 1.0)
		* slingshot_proximity_boost_scale
		* pow(proximity_score, curve)
		* (slingshot_factor + orbit_control_bonus)
		* curve_scale
		* entry_factor
	)
	proximity_strength = minf(proximity_strength, maxf(slingshot_proximity_max_impulse_per_second, 0.0))
	if proximity_strength <= 0.001:
		return Vector2.ZERO

	var inward_bias := gravity.length() * slingshot_inward_pull_scale * 0.18 * curve_scale * entry_factor * delta
	if inward_bias > 0.0:
		velocity += -radial_dir * minf(inward_bias, slingshot_max_impulse * (0.04 if auto_orbit_assist else 0.026))
	if outward_speed > 0.0:
		velocity -= radial_dir * minf(
			outward_speed * slingshot_outward_damping * curve_scale * delta * 2.0,
			slingshot_max_impulse * (0.04 if auto_orbit_assist else 0.03)
		)

	var impulse: Vector2 = tangent * proximity_strength * delta
	var proximity_cap := slingshot_speed_cap + slingshot_mastery_cap_bonus * maxf(proximity_score * 0.65, 0.0)
	var proposed: Vector2 = velocity + impulse
	if proposed.length() > proximity_cap:
		var allowed := maxf(proximity_cap - velocity.length(), 0.0)
		if allowed <= 0.001:
			return Vector2.ZERO
		impulse = impulse.normalized() * minf(impulse.length(), allowed)

	if impulse.length_squared() <= 0.001:
		return Vector2.ZERO

	velocity += impulse
	current_max_speed = maxf(current_max_speed, minf(proximity_cap, maxf(velocity.length(), max_speed)))
	last_slingshot_strength = maxf(last_slingshot_strength, proximity_strength)
	last_slingshot_source = source
	last_slingshot_time = Time.get_ticks_msec() / 1000.0
	slingshot_assist_applied.emit(
		source,
		gravity,
		impulse,
		proximity_strength,
		velocity.length()
	)
	return impulse


func _apply_smoothed_slingshot_impulse(impulse: Vector2, speed_cap: float) -> void:
	if impulse.length_squared() <= 0.001:
		return
	var immediate_ratio := clampf(slingshot_impulse_immediate_ratio, 0.0, 1.0)
	var immediate := impulse * immediate_ratio
	var remaining := impulse - immediate
	velocity = _velocity_with_speed_cap(velocity, immediate, speed_cap)
	if remaining.length_squared() <= 0.001 or slingshot_impulse_smoothing_time <= 0.0:
		velocity = _velocity_with_speed_cap(velocity, remaining, speed_cap)
		return
	_pending_slingshot_impulse += remaining
	_pending_slingshot_cap = maxf(_pending_slingshot_cap, speed_cap)
	_pending_slingshot_time_left = maxf(_pending_slingshot_time_left, slingshot_impulse_smoothing_time)


func _drain_smoothed_slingshot_impulse(delta: float) -> void:
	if _pending_slingshot_time_left <= 0.0 or _pending_slingshot_impulse.length_squared() <= 0.001:
		_pending_slingshot_impulse = Vector2.ZERO
		_pending_slingshot_time_left = 0.0
		_pending_slingshot_cap = 0.0
		return
	var step_ratio := clampf(delta / maxf(_pending_slingshot_time_left, 0.001), 0.0, 1.0)
	var step_impulse := _pending_slingshot_impulse * step_ratio
	_pending_slingshot_impulse -= step_impulse
	_pending_slingshot_time_left = maxf(_pending_slingshot_time_left - delta, 0.0)
	velocity = _velocity_with_speed_cap(velocity, step_impulse, maxf(_pending_slingshot_cap, slingshot_speed_cap))


func _velocity_with_speed_cap(base_velocity: Vector2, impulse: Vector2, speed_cap: float) -> Vector2:
	var proposed := base_velocity + impulse
	var cap := maxf(speed_cap, max_speed)
	if proposed.length() <= cap:
		return proposed
	var allowed := maxf(cap - base_velocity.length(), 0.0)
	if allowed <= 0.001 or impulse.length_squared() <= 0.001:
		return base_velocity.limit_length(cap)
	return base_velocity + impulse.normalized() * minf(impulse.length(), allowed)

func apply_regular_slingshot(gravity: Vector2, delta: float):
	last_slingshot_strength = maxf(last_slingshot_strength - delta * 2.0, 0.0)
	
	if not is_instance_valid(closest_planet):
		return
	
	if velocity.length() < 1.0:
		return
	
	if closest_dist > 500.0 or closest_dist < 70.0:
		current_max_speed = lerp(current_max_speed, max_speed, delta * 0.5)
		return
	else:
		current_max_speed = maxf(current_max_speed, slingshot_speed_cap)
	
	var radial = global_position - closest_planet.global_position
	if radial.length_squared() <= 0.001:
		return

	var radial_dir = radial.normalized()
	var tangent = radial_dir.orthogonal()

	if tangent.dot(velocity) < 0:
		tangent = -tangent

	var tangential_speed := maxf(velocity.dot(tangent), 0.0)
	var inward_speed := maxf(velocity.dot(-radial_dir), 0.0)
	var outward_speed := maxf(velocity.dot(radial_dir), 0.0)
	var entry_factor := _slingshot_entry_factor(inward_speed, outward_speed, tangential_speed)
	var auto_orbit_assist := _player_auto_orbit_enabled()
	var curve_scale := 1.0 if auto_orbit_assist else slingshot_passive_curve_scale
	if DRAG_enabled:
		var inward_bias := gravity.length() * slingshot_inward_pull_scale * 0.25 * curve_scale * entry_factor * delta
		if inward_bias > 0.0:
			velocity += -radial_dir * minf(inward_bias, slingshot_max_impulse * (0.05 if auto_orbit_assist else 0.03))
		if outward_speed > 0.0:
			var outward_softening := minf(
				outward_speed * slingshot_outward_damping * curve_scale * delta * 2.0,
				slingshot_max_impulse * (0.05 if auto_orbit_assist else 0.035)
			)
			velocity -= radial_dir * outward_softening

	if tangential_speed >= slingshot_min_tangential_speed and DRAG_enabled and entry_factor >= slingshot_min_entry_factor:
		var tangent_ratio := tangential_speed / maxf(velocity.length(), 1.0)
		var proximity_score := _slingshot_proximity_score(closest_planet)
		var proximity_multiplier := lerpf(0.76, 1.28, pow(proximity_score, maxf(slingshot_proximity_curve, 0.01)))
		var accel_tangent := gravity.length() * clampf(tangent_ratio, 0.0, 1.0) * proximity_multiplier * curve_scale * entry_factor
		var impulse = tangent * accel_tangent * (slingshot_factor + orbit_control_bonus) * delta
		velocity += impulse
		
		last_slingshot_strength = maxf(last_slingshot_strength, accel_tangent)
		last_slingshot_source = closest_planet
		last_slingshot_time = Time.get_ticks_msec() / 1000.0
		
		slingshot_assist_applied.emit(
			closest_planet,
			gravity,
			impulse,
			accel_tangent,
			velocity.length()
		)
		
func _on_slingshot_cooldown():
	slingshot_ready = true

# ========================
# == MOVEMENT ==
# ========================

func apply_thrust(delta):
	var forward_pressed := Input.is_action_pressed("thrust")
	var reverse_pressed := Settings != null and bool(Settings.alternate_movement_enabled) and _alternate_reverse_pressed()
	if not forward_pressed and not reverse_pressed:
		return

	var dir = -transform.x.normalized()
	var thrust_scale := 1.0
	if reverse_pressed and not forward_pressed:
		dir = -dir
		thrust_scale = clampf(float(Settings.reverse_thrust_scale), 0.15, 0.8)
	var force = dir * thrust_power * thrust_scale

	var predicted_velocity = velocity + force * delta
	var displacement = ((velocity + predicted_velocity) * 0.5) * delta

	var work = absf(force.dot(displacement))

	var energy_cost = max(
		work * energy_cost_per_work,
		minimum_thrust_energy_cost_per_second * delta
	)

	var scale = 0.0

	if energy_component:
		var spent = energy_component.spend(energy_cost)
		scale = clamp(spent / energy_cost, 0.0, 1.0)

	if scale > 0.0:
		var hard_cap := _get_current_hard_speed_cap()
		var speed := velocity.length()
		var forward_speed := velocity.dot(dir)
		if speed > 1.0:
			var thrust_alignment := forward_speed / speed
			if thrust_alignment < -0.2:
				scale *= 1.0 + counter_thrust_control_bonus * absf(thrust_alignment)
			elif absf(thrust_alignment) < 0.45:
				var lateral_control := 1.0 - absf(thrust_alignment) / 0.45
				scale *= 1.0 + lateral_thrust_control_bonus * lateral_control
		var falloff_start := hard_cap * high_speed_thrust_falloff_start
		if forward_speed > 0.0 and speed > falloff_start:
			var remaining := maxf(hard_cap - speed, 0.0)
			var falloff_band := maxf(hard_cap - falloff_start, 1.0)
			scale *= clampf(remaining / falloff_band, 0.0, 1.0)

		velocity += force * scale * delta


func _alternate_reverse_pressed() -> bool:
	return _input_action_or_key_pressed(&"back", KEY_S) or _input_action_or_key_pressed(&"move_down", KEY_DOWN)


func _alternate_side_input() -> float:
	var value := 0.0
	if _input_action_or_key_pressed(&"left", KEY_A) or _input_action_or_key_pressed(&"move_left", KEY_LEFT):
		value -= 1.0
	if _input_action_or_key_pressed(&"right", KEY_D) or _input_action_or_key_pressed(&"move_right", KEY_RIGHT):
		value += 1.0
	return clampf(value, -1.0, 1.0)


func _controller_aim_vector() -> Vector2:
	var deadzone := clampf(float(Settings.controller_deadzone) if Settings != null else 0.24, 0.08, 0.55)
	var joypad_id := _active_joypad_id()
	var right_stick := Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_RIGHT_Y)
	)
	if Settings == null or bool(Settings.controller_right_stick_aim):
		if right_stick.length() >= deadzone:
			return right_stick
	var left_stick := Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y)
	)
	if left_stick.length() >= maxf(deadzone, 0.42):
		return left_stick
	return right_stick if right_stick.length() >= deadzone else Vector2.ZERO


func _active_joypad_id() -> int:
	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		return 0
	return int(connected[0])


func _input_action_or_key_pressed(action_name: StringName, key: Key) -> bool:
	if InputMap.has_action(action_name) and Input.is_action_pressed(action_name):
		return true
	return Input.is_key_pressed(key)

func apply_gravity(gravity: Vector2, delta: float):
	velocity += gravity * delta

# ========================
# == ENERGY REGEN ==
# ========================

func apply_gravity_recharge(gravity: Vector2, delta: float):
	if energy_component == null:
		return

	energy_component.restore(0.8 * delta)

	var displacement = velocity * delta
	var work = gravity.dot(displacement)

	if work > 0.0:
		energy_component.restore(work * gravity_charge_per_work)

# ========================
# == DRAG ==
# ========================

func apply_drag(gravity: Vector2, delta: float):
	if not DRAG_enabled or velocity.length() < 1:
		return

	var thrusting := Input.is_action_pressed("thrust") or (
		Settings != null
		and bool(Settings.alternate_movement_enabled)
		and _alternate_reverse_pressed()
	)
	var coeff := drag if thrusting else idle_drag
	var old_v := velocity
	var in_slingshot_band := _is_drag_slingshot_band(gravity)

	if in_slingshot_band:
		coeff = lerpf(coeff, 0.992, drag_gravity_turn_blend)
	elif thrusting:
		var speed := velocity.length()
		if speed > drag_precision_min_speed:
			var forward := -transform.x.normalized()
			var alignment := velocity.normalized().dot(forward)
			if alignment < -0.18:
				coeff = lerpf(coeff, 0.988, drag_precision_brake_blend)

	velocity *= pow(coeff, delta * 60.0)
	_apply_drag_precision_control(gravity, old_v, delta, thrusting, in_slingshot_band)

	var energy_loss = 0.0

	if coeff < 0.95:
		if velocity.length() > gravity.length() + 20:
			energy_loss = (old_v.length() - velocity.length()) * 0.01

	if energy_component and energy_loss > 0.0001:
		energy_component.spend(energy_loss)

	if energy_component and in_slingshot_band:
		var recovery_scale := clampf(old_v.length() / maxf(slingshot_speed_cap, 1.0), 0.0, 1.0)
		energy_component.restore(drag_slingshot_energy_recovery * recovery_scale * delta)


func _apply_drag_precision_control(
	gravity: Vector2,
	old_velocity: Vector2,
	delta: float,
	thrusting: bool,
	in_slingshot_band: bool
) -> void:
	var starting_speed := velocity.length()
	if starting_speed < drag_precision_min_speed:
		return

	var blend := 0.0
	var target_direction := Vector2.ZERO

	if in_slingshot_band and is_instance_valid(closest_planet):
		var radial = global_position - closest_planet.global_position
		if radial.length_squared() > 0.001:
			var radial_dir = radial.normalized()
			var tangent = radial_dir.orthogonal()
			if tangent.dot(old_velocity) < 0.0:
				tangent = -tangent
			var tangential_speed := maxf(old_velocity.dot(tangent), 0.0)
			var tangent_ratio := tangential_speed / maxf(old_velocity.length(), 1.0)
			var inward_speed := maxf(old_velocity.dot(-radial_dir), 0.0)
			var outward_speed := maxf(old_velocity.dot(radial_dir), 0.0)
			var entry_factor := _slingshot_entry_factor(inward_speed, outward_speed, tangential_speed)
			var auto_orbit_assist := _player_auto_orbit_enabled()
			var curve_scale := 1.0 if auto_orbit_assist else slingshot_passive_curve_scale
			var inward_bias := gravity.length() * slingshot_inward_pull_scale * 0.35 * curve_scale * entry_factor * delta
			if inward_bias > 0.0:
				velocity += -radial_dir * minf(inward_bias, slingshot_max_impulse * (0.08 if auto_orbit_assist else 0.04))
			if outward_speed > 0.0:
				var outward_softening := minf(
					outward_speed * slingshot_outward_damping * curve_scale * delta * 3.0,
					slingshot_max_impulse * (0.08 if auto_orbit_assist else 0.045)
				)
				velocity -= radial_dir * outward_softening
			if (
				entry_factor >= slingshot_min_entry_factor
				and tangent_ratio >= drag_tangent_assist_min_ratio
				and tangential_speed > outward_speed * 0.72
			):
				var tangent_boost = (
					tangent
					* gravity.length()
					* drag_gravity_turn_blend
					* clampf(tangent_ratio, 0.0, 1.0)
					* curve_scale
					* entry_factor
					* delta
				)
				velocity += tangent_boost.limit_length(slingshot_max_impulse * (0.1 if auto_orbit_assist else 0.055))

	var sling_precision_grace := _now_seconds() <= _slingshot_precision_until
	if thrusting and (not in_slingshot_band or sling_precision_grace):
		var forward := -transform.x.normalized()
		var speed_dir := old_velocity.normalized()
		var alignment := speed_dir.dot(forward)
		var aim_quality := clampf(1.0 - alignment, 0.0, 1.0)
		target_direction = (target_direction + forward * (0.62 + aim_quality)).normalized()
		var thrust_blend := drag_precision_brake_blend * (0.5 + aim_quality * 0.65)
		if sling_precision_grace:
			thrust_blend = maxf(thrust_blend, slingshot_precision_grace_blend)
		blend = maxf(blend, thrust_blend)

	if target_direction.length_squared() <= 0.001 or blend <= 0.0:
		return

	var adjusted_speed := velocity.length()
	var gravity_bonus := clampf(gravity.length() / 440.0, 0.0, 0.55)
	var turn_amount := clampf(delta * drag_precision_alignment_rate * (blend + gravity_bonus), 0.0, 0.34)
	velocity = velocity.lerp(target_direction.normalized() * adjusted_speed, turn_amount)


func _is_drag_slingshot_band(gravity: Vector2) -> bool:
	return (
		is_instance_valid(closest_planet)
		and closest_dist > 70.0
		and closest_dist < 540.0
		and gravity.length_squared() > 0.001
		and velocity.length() >= slingshot_min_tangential_speed
	)


func _player_auto_orbit_enabled() -> bool:
	return Settings != null and bool(Settings.player_auto_orbit_enabled)


func _has_orbital_juice_manager() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	return (
		tree.get_first_node_in_group("orbital_juice_manager") != null
		or tree.get_first_node_in_group("Orbital_Juice_Manager") != null
	)

# ========================
# == CONSTRAINTS ==
# ========================

func clamp_velocity():
	velocity = velocity.limit_length(_get_current_hard_speed_cap())

# ========================
# == DASH ==
# ========================

func boost(dir):
	velocity += dir * 2000.0

	_dash_drag_suppressed = true
	_update_drag_state()
	current_max_speed = maxf(current_max_speed, dash_speed_cap)
	can_dash = false

	if energy_component:
		energy_component.spend(10)

	if powerup_inventory != null:
		powerup_inventory.trigger_player_action()

	if is_inside_tree():
		await get_tree().create_timer(0.3).timeout

	if is_instance_valid(dash_timer):
		dash_timer.start()

	_dash_drag_suppressed = false
	_update_drag_state()

func _try_planet_super_boost() -> bool:
	if not _can_planet_super_boost():
		return false

	var source := closest_planet as Node2D
	var outward := global_position - source.global_position
	if outward.length_squared() <= 0.001:
		outward = -transform.x
	outward = outward.normalized()

	var tangent := outward.orthogonal()
	if tangent.dot(velocity) < 0.0:
		tangent = -tangent
	var inward := -outward
	var bias := clampf(super_boost_tangent_bias, 0.0, 0.92)
	var boost_dir := (inward * (1.0 - bias) + tangent * bias).normalized()
	var impulse := boost_dir * maxf(super_boost_impulse, 0.0)
	var spent := float(energy_component.spend(super_boost_energy_cost)) if energy_component != null else 0.0
	if spent < super_boost_energy_cost:
		if energy_component != null:
			energy_component.restore(spent)
		return false

	var outward_speed := maxf(velocity.dot(outward), 0.0)
	if outward_speed > 0.0:
		velocity -= outward * minf(outward_speed * 0.55, super_boost_impulse * 0.18)
	velocity = (velocity + impulse).limit_length(maxf(_get_current_hard_speed_cap(), dash_speed_cap + super_boost_impulse * 0.35))
	current_max_speed = maxf(current_max_speed, dash_speed_cap + super_boost_impulse * 0.35)
	_planet_stuck_time = 0.0
	_last_super_boost_time = _now_seconds()
	can_dash = false
	_dash_drag_suppressed = true
	_update_drag_state()

	if powerup_inventory != null:
		powerup_inventory.trigger_player_action()

	planet_super_boost_activated.emit(source, impulse, spent)

	if is_instance_valid(dash_timer):
		dash_timer.start(maxf(super_boost_cooldown, 0.05))
	_dash_drag_suppressed = false
	_update_drag_state()
	return true


func _can_planet_super_boost() -> bool:
	if not super_boost_enabled:
		return false
	if _now_seconds() - _last_super_boost_time < super_boost_cooldown:
		return false
	if _planet_stuck_time < super_boost_stuck_seconds:
		return false
	if energy_component == null or not energy_component.has_energy(super_boost_energy_cost):
		return false
	if not is_instance_valid(closest_planet):
		return false
	if not _is_boostable_planet(closest_planet):
		return false
	var source := closest_planet as Node2D
	if source == null:
		return false
	var boost_radius := _gravity_source_radius(source) + maxf(super_boost_clearance, 0.0)
	return closest_dist <= boost_radius


func _update_planet_stuck_state(delta: float) -> void:
	if not super_boost_enabled or not is_instance_valid(closest_planet) or not _is_boostable_planet(closest_planet):
		_planet_stuck_time = 0.0
		_planet_stuck_source_id = 0
		return

	var source := closest_planet as Node2D
	if source == null:
		_planet_stuck_time = 0.0
		_planet_stuck_source_id = 0
		return

	var stuck_radius := _gravity_source_radius(source) + maxf(super_boost_clearance, 0.0)
	var source_id := source.get_instance_id()
	var close_enough := closest_dist <= stuck_radius
	var slow_enough := velocity.length() <= super_boost_stuck_speed_threshold
	var pressing_out := Input.is_action_pressed("thrust")

	if close_enough and (slow_enough or pressing_out):
		if _planet_stuck_source_id != source_id:
			_planet_stuck_time = 0.0
			_planet_stuck_source_id = source_id
		_planet_stuck_time += delta
	else:
		_planet_stuck_time = maxf(_planet_stuck_time - delta * 1.8, 0.0)
		if _planet_stuck_time <= 0.001:
			_planet_stuck_source_id = 0


func _apply_planet_pin_escape() -> void:
	if not pin_escape_enabled or _planet_stuck_time < pin_escape_seconds:
		return
	if _now_seconds() - _last_pin_escape_time < pin_escape_cooldown:
		return
	if not is_instance_valid(closest_planet) or not _is_boostable_planet(closest_planet):
		return
	var source := closest_planet as Node2D
	if source == null:
		return
	var outward := global_position - source.global_position
	if outward.length_squared() <= 0.001:
		outward = -transform.x
	outward = outward.normalized()
	var tangent := outward.orthogonal()
	if tangent.dot(velocity) < 0.0:
		tangent = -tangent
	var bias := clampf(pin_escape_tangent_bias, 0.0, 0.7)
	var escape_dir := (outward * (1.0 - bias) + tangent * bias).normalized()
	var pressure := clampf(_planet_stuck_time / maxf(super_boost_stuck_seconds, 0.01), 0.0, 1.0)
	var impulse := escape_dir * pin_escape_impulse * lerpf(0.52, 1.0, pressure)
	velocity = (velocity + impulse).limit_length(maxf(_get_current_hard_speed_cap(), dash_speed_cap + pin_escape_impulse * 0.4))
	current_max_speed = maxf(current_max_speed, dash_speed_cap + pin_escape_impulse * 0.25)
	_last_pin_escape_time = _now_seconds()
	_planet_stuck_time = minf(_planet_stuck_time, pin_escape_seconds * 0.5)


func _is_boostable_planet(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if String(source.name).to_lower().contains("blackhole") or String(source.name).to_lower().contains("black_hole"):
		return false
	var script_value: Variant = source.get_script()
	if script_value is Script:
		var script_path := (script_value as Script).resource_path
		if script_path.ends_with("black_hole.gd"):
			return false
	return source.is_in_group("planets") or source.is_in_group("Objects_With_Gravity")


func _gravity_source_radius(source: Node2D) -> float:
	if source == null or not is_instance_valid(source):
		return 70.0
	var radius_value: Variant = source.get("radius")
	if radius_value is float or radius_value is int:
		return maxf(float(radius_value), 24.0) * maxf(source.scale.x, source.scale.y)
	var base_radius_value: Variant = source.get("base_radius")
	if base_radius_value is float or base_radius_value is int:
		return maxf(float(base_radius_value), 24.0) * maxf(source.scale.x, source.scale.y)
	var collision := source.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return maxf((collision.shape as CircleShape2D).radius, 24.0) * maxf(source.scale.x, source.scale.y)
	return 70.0 * maxf(source.scale.x, source.scale.y)


func _on_dash_timeout():
	can_dash = true

# ========================
# == SHOOTING ==
# ========================

func shoot():
	if not network_is_local:
		return
	if _death_in_progress:
		return

	var weapon_system := get_node_or_null("WeaponSystem")
	if weapon_system != null and weapon_system.has_method("try_primary_fire"):
		if bool(weapon_system.call("try_primary_fire")):
			return

	if not is_inside_tree() or get_tree().current_scene == null:
		return

	var p = projectile_scene.instantiate() as RigidBody2D

	if not p:
		return

	var spawn_dir = -transform.x.normalized()

	p.global_position = global_position + spawn_dir * 70
	p.global_rotation = rotation

	var momentum_component = get_node_or_null("MomentumCombatComponent")

	if momentum_component != null and momentum_component.has_method("prepare_projectile"):
		momentum_component.call("prepare_projectile", p, spawn_dir)

	momentum_projectile_spawned.emit(p, spawn_dir)
	get_tree().current_scene.call_deferred("add_child", p)

	$BulletBlastSoundEffect.play()

	if p.has_method("launch"):
		p.call_deferred("launch", spawn_dir)
	else:
		p.call_deferred("apply_central_impulse", spawn_dir * 900)

	if recoil_instability > 0.0:
		velocity -= spawn_dir.rotated(randf_range(-0.22, 0.22)) * recoil_instability

	if powerup_inventory != null:
		powerup_inventory.trigger_player_action()

# ========================
# == INPUT / UI ==
# ========================

func handle_input():
	if _death_in_progress:
		return

	if Input.is_action_just_released("Menu"):
		var pause_menu = get_pause_menu()
		if pause_menu:
			pause_menu.toggle_pause()
			_sync_pause_menu_state(pause_menu)
		return

	if _is_pause_blocking():
		return

	_handle_shoot_input()

	if Input.is_action_just_released("Toggle"):
		drag_enabled_by_player = !drag_enabled_by_player
		_update_drag_state()

	if Input.is_action_just_released("thrust"):
		var now = Time.get_ticks_msec() / 1000.0

		if now - last_thrust_release < 0.35 and can_dash:
			if not _try_planet_super_boost():
				boost(-transform.x.normalized())

		last_thrust_release = now


func _handle_shoot_input() -> void:
	if _death_in_progress:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if Input.is_action_just_pressed("shoot"):
		shoot()
		_next_held_projectile_time = now + _current_weapon_fire_interval()
		return

	if Input.is_action_pressed("shoot") and now >= _next_held_projectile_time:
		shoot()
		_next_held_projectile_time = now + _current_weapon_fire_interval()

	if Input.is_action_just_released("shoot"):
		_next_held_projectile_time = 0.0


func _current_weapon_fire_interval() -> float:
	var multiplier := clampf(float(get_meta(&"momentum_fire_interval_multiplier", 1.0)), 0.45, 1.25)
	var now := Time.get_ticks_msec() / 1000.0
	var chain_until := float(get_meta(&"run_chain_fire_interval_until", 0.0))
	if chain_until > now:
		multiplier *= clampf(float(get_meta(&"run_chain_fire_interval_multiplier", 1.0)), 0.55, 1.0)
	elif has_meta(&"run_chain_fire_interval_multiplier"):
		remove_meta(&"run_chain_fire_interval_multiplier")
		if has_meta(&"run_chain_fire_interval_until"):
			remove_meta(&"run_chain_fire_interval_until")
	var weapon_system := get_node_or_null("WeaponSystem")
	if weapon_system != null and weapon_system.has_method("get_current_fire_interval"):
		return maxf(float(weapon_system.call("get_current_fire_interval")) * multiplier, 0.03)
	return maxf(projectile_hold_fire_interval * multiplier, 0.03)


func _sync_pause_menu_state(pause_menu: Node) -> void:
	if pause_menu != null and pause_menu.has_method("is_gameplay_blocked"):
		menu_is_hidden = not bool(pause_menu.call("is_gameplay_blocked"))
	else:
		menu_is_hidden = not bool(pause_menu.get("active"))


func _is_pause_blocking() -> bool:
	var pause_menu := get_pause_menu()
	if pause_menu != null and pause_menu.has_method("is_gameplay_blocked"):
		return bool(pause_menu.call("is_gameplay_blocked"))
	return not menu_is_hidden or get_tree().paused

func update_ui():
	drag_label.text = "Drag: " + ("Precision" if DRAG_enabled else "Momentum")

	if health_component:
		var shield_text = ""

		if shield_component != null and shield_component.get("max_capacity") != null:
			shield_text = " | Shield: %d/%d" % [
				int(round(float(shield_component.get("current_energy")))),
				int(round(float(shield_component.get("max_capacity"))))
			]

		health_label.text = "Health: %s%s" % [
			health_component.current_health,
			shield_text
		]

	if energy_component:
		energy_label.text = "Energy: %d/%d" % [
			int(round(energy_component.current_energy)),
			int(round(energy_component.max_energy))
		]

# ========================
# == PROCESS ==
# ========================

func _process(delta):
	_update_network_nameplate()
	_update_hit_invulnerability_visual(delta)
	if not network_is_local:
		shield_process()
		return
	if _death_in_progress:
		update_camera(delta)
		return

	if not _is_pause_blocking():
		update_camera(delta)
		shield_process()

func update_camera(delta: float):
	if camera == null:
		return
	_camera_feedback_offset = _camera_feedback_offset.lerp(
		Vector2.ZERO,
		clampf(delta * 7.5, 0.0, 1.0)
	)
	_camera_feedback_roll = lerpf(
		_camera_feedback_roll,
		0.0,
		clampf(delta * 8.5, 0.0, 1.0)
	)

	var using_controller := Settings != null and bool(Settings.input_type)
	if not using_controller:
		var mouse_offset := get_global_mouse_position() - global_position
		var trackpad_mode := Settings != null and bool(Settings.trackpad_direct_camera)
		var offset_distance := trackpad_camera_offset_distance if trackpad_mode else mouse_camera_offset_distance
		var target := mouse_offset.normalized() * offset_distance if mouse_offset.length_squared() > 1.0 else Vector2.ZERO
		var base_offset = camera.offset - _camera_feedback_offset
		var follow_strength := float(Settings.camera_follow_strength) if Settings != null else 1.0
		var follow_weight := 0.075 * follow_strength
		if trackpad_mode:
			follow_weight *= trackpad_camera_follow_weight_scale
		follow_weight = clampf(follow_weight, 0.03 if trackpad_mode else 0.035, 0.12 if trackpad_mode else 0.24)
		camera.offset = base_offset.lerp(target, follow_weight) + _camera_feedback_offset
	else:
		camera.offset = camera.offset.lerp(_camera_feedback_offset, clampf(delta * 8.0, 0.0, 1.0))

	camera.rotation = _camera_base_rotation + _camera_feedback_roll

# ========================
# == SHIELDS ==
# ========================

func shield_process():
	if not is_instance_valid(shield_node):
		return

	if shield_component != null and shield_component.has_method("is_shield_active"):
		shields_on = bool(shield_component.call("is_shield_active"))

	shield_node.visible = shields_on

	var poly = shield_node.get_node_or_null("Polygon2D")
	var coll = shield_node.get_node_or_null("CollisionPolygon2D")

	if poly:
		poly.visible = shields_on

	if coll:
		coll.visible = shields_on

func take_damage(amount: float):
	if not network_is_local:
		return
	if _death_in_progress:
		return
	if amount <= 0.0:
		return
	if is_damage_invulnerable():
		damage_ignored_during_invulnerability.emit(amount)
		return

	_last_damage_amount = amount
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	var remaining = amount

	if shield_component != null and shield_component.has_method("take_shield_damage"):
		remaining = float(shield_component.call("take_shield_damage", amount))

	if remaining > 0.0 and health_component:
		health_component.take_damage(remaining)

	_start_hit_invulnerability()


func consume_by_black_hole() -> void:
	if _death_in_progress:
		return
	set_meta(&"black_hole_consumed", true)
	set_meta(&"last_death_context", &"black_hole")
	_damage_invulnerable_until = -999.0
	_last_damage_amount = 10000000.0
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	velocity = Vector2.ZERO

	if not network_is_local:
		_death_in_progress = true
		set_meta(&"death_in_progress", true)
		_apply_remote_death_visuals()
		return

	if health_component != null and health_component.has_method("take_damage"):
		health_component.call("take_damage", 10000000.0)
		if health_component.has_method("is_dead") and bool(health_component.call("is_dead")) and not _death_in_progress:
			call_deferred("_on_health_component_died")
		return

	take_damage(10000000.0)


func is_damage_invulnerable() -> bool:
	return _now_seconds() < _damage_invulnerable_until


func _start_hit_invulnerability() -> void:
	if post_hit_invulnerability_seconds <= 0.0:
		return
	_damage_invulnerable_until = maxf(_damage_invulnerable_until, _now_seconds() + post_hit_invulnerability_seconds)
	_invulnerability_flash_elapsed = 0.0
	player_hit_invulnerability_started.emit(post_hit_invulnerability_seconds)


func _update_hit_invulnerability_visual(delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_damage_invulnerable():
		if hull_polygon != null:
			hull_polygon.modulate.a = 1.0
		if shield_polygon != null:
			shield_polygon.modulate.a = 1.0
		return

	_invulnerability_flash_elapsed += delta
	var pulse := 0.52 + 0.48 * absf(sin(_invulnerability_flash_elapsed * post_hit_invulnerability_flash_rate))
	if hull_polygon != null:
		hull_polygon.modulate.a = pulse
	if shield_polygon != null:
		shield_polygon.modulate.a = maxf(pulse, 0.72)

func take_shield_damage(amount: float) -> float:
	if not network_is_local:
		return 0.0
	if is_damage_invulnerable():
		damage_ignored_during_invulnerability.emit(amount)
		return 0.0
	if shield_component != null and shield_component.has_method("take_shield_damage"):
		var remaining := float(shield_component.call("take_shield_damage", amount))
		_start_hit_invulnerability()
		return remaining
	return amount

func restore_shield(amount: float) -> float:
	if shield_component != null and shield_component.has_method("restore_shield"):
		return float(shield_component.call("restore_shield", amount))
	return 0.0

func apply_shield_disruption(strength: float, duration: float) -> void:
	if shield_component != null and shield_component.has_method("apply_gravity_distortion"):
		shield_component.call("apply_gravity_distortion", strength, duration)

func is_shield_active() -> bool:
	if shield_component != null and shield_component.has_method("is_shield_active"):
		return bool(shield_component.call("is_shield_active"))
	return false

func is_dead() -> bool:
	if health_component != null and health_component.has_method("is_dead"):
		return bool(health_component.call("is_dead"))
	return _death_in_progress

func is_death_in_progress() -> bool:
	return _death_in_progress

func _bind_shield() -> void:
	shield_component = shield_node

	if shield_component == null:
		return

	if shield_component.has_signal("shield_broken") and not shield_component.is_connected("shield_broken", Callable(self, "_on_shield_broken")):
		shield_component.connect("shield_broken", Callable(self, "_on_shield_broken"))

	if shield_component.has_signal("shield_hit") and not shield_component.is_connected("shield_hit", Callable(self, "_on_shield_hit")):
		shield_component.connect("shield_hit", Callable(self, "_on_shield_hit"))

	if shield_component.has_signal("shield_restored") and not shield_component.is_connected("shield_restored", Callable(self, "_on_shield_restored")):
		shield_component.connect("shield_restored", Callable(self, "_on_shield_restored"))

func _ensure_powerup_inventory() -> void:
	powerup_inventory = get_node_or_null("PowerupInventory") as PowerupInventory

	if powerup_inventory != null:
		return

	powerup_inventory = PowerupInventory.new()
	powerup_inventory.name = "PowerupInventory"
	add_child(powerup_inventory)

# ========================
# == FIXED GRAVITY REFRESH ==
# ========================

func _refresh_gravity_sources(force: bool) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return

	var tree := get_tree()

	if tree == null:
		return

	if not force and _gravity_refresh_elapsed < gravity_source_refresh_interval:
		return

	_gravity_refresh_elapsed = 0.0

	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			global_position,
			_gravity_source_query,
			max_gravity_sources,
			gravity_pull_radius,
			self
		)
		planets = _gravity_source_query
		return

	var seen := {}
	var sources: Array[Node2D] = []

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in tree.get_nodes_in_group(group_name):
			if source == self:
				continue
			if source == null or not is_instance_valid(source):
				continue
			var source_2d := source as Node2D
			if source_2d == null or source_2d.is_queued_for_deletion():
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			sources.append(source_2d)

	sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)

	if max_gravity_sources > 0 and sources.size() > max_gravity_sources:
		sources.resize(max_gravity_sources)

	planets = sources

# ========================
# == SIGNAL CALLBACKS ==
# ========================

func _on_health_component_died():
	if _death_in_progress:
		return

	if not network_is_local:
		_death_in_progress = true
		set_meta(&"death_in_progress", true)
		_apply_remote_death_visuals()
		return

	_death_in_progress = true
	set_meta(&"death_in_progress", true)
	velocity = Vector2.ZERO
	_next_held_projectile_time = INF

	var weapon_system := get_node_or_null("WeaponSystem")
	if weapon_system != null and weapon_system.has_method("force_cease_fire"):
		weapon_system.call("force_cease_fire")

	# Disable collision and hide ship visuals immediately
	var col_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape:
		col_shape.set_deferred("disabled", true)
	
	var poly = get_node_or_null("Polygon2D") as Polygon2D
	if poly:
		poly.visible = false

	var shield = get_node_or_null("Shield") as Node2D
	if shield:
		shield.visible = false

	var predictor = get_node_or_null("OrbitalTrajectoryPredictor") as Node2D
	if predictor:
		predictor.visible = false

	var aim_pred = get_node_or_null("ProjectileAimPredictor") as Node2D
	if aim_pred:
		aim_pred.visible = false

	var particles = get_node_or_null("GPUParticles2D") as GPUParticles2D
	if particles:
		particles.emitting = false

	# Spawn explosion
	var explosion_scene = load("res://Nodes/player_death_explosion.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		get_parent().add_child(explosion)

	var lesson := _build_death_lesson()
	RunProgress.set_last_death_message(lesson)
	death_lesson_generated.emit(lesson)
	call_deferred("_go_to_game_over_after_lesson")

func _go_to_game_over_after_lesson() -> void:
	await get_tree().create_timer(maxf(death_watch_duration, 0.18)).timeout
	_go_to_game_over()

func _go_to_game_over() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Nodes/game_over_scene.tscn")

func _build_death_lesson() -> String:
	if StringName(get_meta(&"last_death_context", &"")) == &"black_hole":
		return "DEATH VECTOR: the event horizon ate your exit angle. Graze wide, then slingshot out before the core."
	var speed := velocity.length()
	var gravity := calculate_gravity()
	if gravity.length() > gravity_constant * 1.7:
		return "DEATH VECTOR: gravity stacked faster than your exit angle. Cross the field edge before it folds."
	if speed < max_speed * 0.32 and _last_damage_amount > 0.0:
		return "DEATH VECTOR: low momentum left you pinned. Build speed before trading hits."
	if speed > max_speed * 1.18:
		return "DEATH VECTOR: high velocity needs a recovery orbit. Aim for a wide slingshot, then brake."
	if shield_component != null and shield_component.get("is_broken") == true:
		return "DEATH VECTOR: shield break is a retreat signal. Drift wide until the bubble reforms."
	return "DEATH VECTOR: read the nearest field rule first, then move. The arena always telegraphs the law."

func _on_health_component_health_changed(current, _max):
	health_label.text = "Health: " + str(current)

func _on_shield_broken() -> void:
	shields_on = false

func _on_shield_hit(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	shields_on = is_shield_active()

func _on_shield_restored(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	shields_on = is_shield_active()

# ========================
# == SPEED CAP ==
# ========================

func update_max_speed(delta: float):
	var target_max = max_speed
	var momentum_bonus := _get_momentum_speed_cap_bonus()

	target_max += momentum_bonus

	if not drag_enabled_by_player:
		target_max = maxf(target_max, max_speed * drag_disabled_speed_multiplier + momentum_bonus)

	if _dash_drag_suppressed:
		target_max = maxf(target_max, dash_speed_cap + momentum_bonus * 0.45)

	target_max = minf(target_max, absolute_velocity_cap)
	var lerp_rate := 5.8 if current_max_speed > target_max else 3.2
	current_max_speed = lerp(current_max_speed, target_max, clampf(lerp_rate * delta, 0.0, 1.0))

func _get_momentum_speed_cap_bonus() -> float:
	var momentum_comp = get_node_or_null("MomentumCombatComponent")

	if momentum_comp == null:
		return 0.0

	if momentum_comp.has_method("_get_current_speed_cap_bonus"):
		return float(momentum_comp.call("_get_current_speed_cap_bonus"))

	var bonus_value: Variant = momentum_comp.get("_speed_cap_bonus")
	if typeof(bonus_value) == TYPE_FLOAT or typeof(bonus_value) == TYPE_INT:
		return float(bonus_value)

	return 0.0

func _get_current_hard_speed_cap() -> float:
	var cap := minf(maxf(current_max_speed, max_speed), absolute_velocity_cap)

	if not drag_enabled_by_player and not _dash_drag_suppressed:
		cap = minf(cap, max_speed * drag_disabled_speed_multiplier + _get_momentum_speed_cap_bonus())

	return maxf(cap, 1.0)

func _update_drag_state() -> void:
	DRAG_enabled = drag_enabled_by_player and not _dash_drag_suppressed

func _update_slingshot_window(gravity: Vector2) -> void:
	var state := &"offline"
	var window_data := {
		"state": state,
		"score": 0.0,
		"grade": &"none",
		"ready": slingshot_ready,
		"distance": closest_dist,
		"sweet_distance": slingshot_sweet_spot_distance,
		"sweet_width": slingshot_sweet_spot_width,
		"tangential_speed": 0.0,
		"inward_speed": 0.0,
		"source": closest_planet,
		"position": global_position,
	}

	if not slingshot_ready:
		state = &"cooldown"
	elif not is_instance_valid(closest_planet):
		state = &"search"
	elif velocity.length() < 1.0 or gravity.length_squared() <= 0.001:
		state = &"align"
	elif closest_dist > 500.0:
		state = &"approach"
	elif closest_dist < 70.0:
		state = &"danger"
	else:
		var radial = global_position - closest_planet.global_position
		if radial.length_squared() > 0.001:
			var radial_dir = radial.normalized()
			var tangent = radial_dir.orthogonal()
			if tangent.dot(velocity) < 0.0:
				tangent = -tangent
			var tangential_speed := maxf(velocity.dot(tangent), 0.0)
			var inward_speed := maxf(velocity.dot(-radial_dir), 0.0)
			var score_data := _score_slingshot_window(
				gravity,
				radial_dir,
				tangent,
				tangential_speed,
				inward_speed
			)
			window_data.merge(score_data, true)
			var score := float(score_data.get("score", 0.0))
			var entry_factor := float(score_data.get("entry_factor", 1.0))
			if tangential_speed < slingshot_min_tangential_speed:
				state = &"align"
			elif entry_factor < slingshot_min_entry_factor or score < slingshot_min_curve_score:
				state = &"approach"
			elif score >= slingshot_apex_score:
				state = &"apex"
			elif score >= slingshot_perfect_score:
				state = &"perfect"
			elif float(score_data.get("distance_score", 0.0)) > 0.5:
				state = &"sweet"
			else:
				state = &"ready"

	window_data["state"] = state
	window_data["grade"] = _slingshot_grade_for_score(float(window_data.get("score", 0.0)))
	window_data["ready"] = slingshot_ready
	last_slingshot_window = window_data

	if state != _last_slingshot_window_state:
		_last_slingshot_window_state = state
		slingshot_window_changed.emit(window_data)

func _score_slingshot_window(
	gravity: Vector2,
	radial_dir: Vector2,
	tangent: Vector2,
	tangential_speed: float,
	inward_speed: float
) -> Dictionary:
	var proximity_score := _slingshot_proximity_score(closest_planet)
	var distance_score := 0.0
	if slingshot_sweet_spot_width > 0.001:
		distance_score = 1.0 - absf(closest_dist - slingshot_sweet_spot_distance) / slingshot_sweet_spot_width
	distance_score = clampf(distance_score, 0.0, 1.0)

	var full_tangent_speed := maxf(slingshot_speed_cap * 0.68, slingshot_min_tangential_speed + 1.0)
	var tangent_score := clampf(
		(tangential_speed - slingshot_min_tangential_speed)
		/ maxf(full_tangent_speed - slingshot_min_tangential_speed, 1.0),
		0.0,
		1.0
	)
	var dive_score := clampf(inward_speed / 580.0, 0.0, 1.0)
	var speed_score := clampf(velocity.length() / maxf(current_max_speed, 1.0), 0.0, 1.0)
	var gravity_score := clampf(gravity.length() / 400.0, 0.0, 1.0)
	var outward_speed := maxf(velocity.dot(radial_dir), 0.0)
	var entry_factor := _slingshot_entry_factor(inward_speed, outward_speed, tangential_speed)
	var base_score := clampf(
		distance_score * 0.4
		+ tangent_score * 0.38
		+ dive_score * 0.14
		+ speed_score * 0.05
		+ gravity_score * 0.03,
		0.0,
		1.0
	)
	var score := clampf(base_score * lerpf(0.42, 1.0, entry_factor), 0.0, 1.0)

	return {
		"score": score,
		"base_score": base_score,
		"entry_factor": entry_factor,
		"distance_score": distance_score,
		"proximity_score": proximity_score,
		"tangent_score": tangent_score,
		"dive_score": dive_score,
		"speed_score": speed_score,
		"gravity_score": gravity_score,
		"tangential_speed": tangential_speed,
		"inward_speed": inward_speed,
		"outward_speed": outward_speed,
		"distance": closest_dist,
		"sweet_distance": slingshot_sweet_spot_distance,
		"sweet_width": slingshot_sweet_spot_width,
		"radial_dir": radial_dir,
		"tangent": tangent,
		"position": global_position,
	}


func _slingshot_entry_factor(inward_speed: float, outward_speed: float, tangential_speed: float) -> float:
	var departure_speed := maxf(outward_speed - inward_speed * 0.45, 0.0)
	if departure_speed <= 0.001:
		return 1.0
	var curve_speed := maxf(tangential_speed + inward_speed * 0.75, 1.0)
	var penalty := clampf(departure_speed / curve_speed, 0.0, 1.0) * slingshot_departure_penalty
	return clampf(1.0 - penalty, 0.28, 1.0)


func _slingshot_proximity_score(source: Node) -> float:
	if source == null or not is_instance_valid(source):
		return 0.0
	var source_2d := source as Node2D
	if source_2d == null:
		return 0.0
	var source_radius := _gravity_source_radius(source_2d)
	var close_distance := maxf(source_radius + maxf(slingshot_proximity_close_margin, 0.0), 70.0)
	var far_distance := maxf(500.0, close_distance + 1.0)
	return 1.0 - clampf(
		(closest_dist - close_distance) / maxf(far_distance - close_distance, 1.0),
		0.0,
		1.0
	)

func _slingshot_grade_for_score(score: float) -> StringName:
	if score >= slingshot_apex_score:
		return &"apex"
	if score >= slingshot_perfect_score:
		return &"perfect"
	if score >= 0.64:
		return &"great"
	if score >= 0.38:
		return &"good"
	return &"assist"

func _apply_slingshot_camera_feedback(data: Dictionary) -> void:
	if camera == null:
		return

	var coordinator := JuiceCoordinator.find_coordinator(get_tree())
	if coordinator != null and not coordinator.should_apply_slingshot_camera(data):
		return

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	score = min(score, 0.95)
	var kick_scale := 1.0
	if coordinator != null:
		kick_scale = coordinator.camera_kick_scale_for_tier(coordinator.slingshot_tier_from_data(data))
	
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT

	var grade := StringName(data.get("grade", &"assist"))
	var grade_boost := 1.0
	if grade == &"perfect":
		grade_boost = 1.25
	elif grade == &"apex":
		grade_boost = 1.55

	_camera_feedback_offset += -tangent.normalized() * slingshot_camera_kick * (0.25 + score) * grade_boost * kick_scale
	_camera_feedback_offset = _camera_feedback_offset.limit_length(slingshot_camera_kick * 2.2)
	var roll_axis := tangent.x if absf(tangent.x) > 0.05 else tangent.y
	_camera_feedback_roll += slingshot_camera_roll * (0.25 + score) * grade_boost * kick_scale * signf(roll_axis)
	_camera_feedback_roll = clampf(_camera_feedback_roll, -slingshot_camera_roll * 2.1, slingshot_camera_roll * 2.1)

func get_slingshot_debug_state() -> Dictionary:
	var state := last_slingshot_window.duplicate()
	state["last_score"] = last_slingshot_score
	state["last_grade"] = last_slingshot_grade
	state["last_age"] = Time.get_ticks_msec() / 1000.0 - last_slingshot_time
	state["cooldown_ready"] = slingshot_ready
	return state

func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


func configure_network_peer(
	peer_id: int,
	is_local: bool,
	display_name: String = "VECTOR",
	player_color: Color = Color(0.08, 0.88, 1.0, 1.0)
) -> void:
	network_peer_id = peer_id
	network_is_local = is_local
	network_display_name = display_name
	network_color = player_color
	set_meta(&"network_peer_id", network_peer_id)
	set_meta(&"network_is_local", network_is_local)
	set_multiplayer_authority(network_peer_id)
	_apply_network_locality()
	_update_network_nameplate()


func export_network_state() -> Dictionary:
	var health_value := 0.0
	var max_health_value := 0.0
	if health_component != null:
		health_value = float(health_component.get("current_health"))
		max_health_value = float(health_component.get("max_health"))

	var energy_value := 0.0
	var max_energy_value := 0.0
	if energy_component != null:
		energy_value = float(energy_component.get("current_energy"))
		max_energy_value = float(energy_component.get("max_energy"))

	var weapon_id := "vector_bolt"
	var weapon_system := get_node_or_null("WeaponSystem")
	if weapon_system != null and weapon_system.has_method("get_weapon_debug_state"):
		var weapon_state_value: Variant = weapon_system.call("get_weapon_debug_state")
		if weapon_state_value is Dictionary:
			var weapon_state: Dictionary = weapon_state_value
			weapon_id = String(weapon_state.get("weapon_id", &"vector_bolt"))

	return {
		"position": global_position,
		"rotation": rotation,
		"velocity": velocity,
		"drag_enabled": DRAG_enabled,
		"shield_active": shields_on,
		"health": health_value,
		"max_health": max_health_value,
		"energy": energy_value,
		"max_energy": max_energy_value,
		"dead": _death_in_progress,
		"slingshot_grade": String(last_slingshot_grade),
		"slingshot_score": last_slingshot_score,
		"input_device": "controller" if Settings != null and bool(Settings.input_type) else "mouse_keyboard",
		"weapon_id": weapon_id,
	}


func apply_network_state(state: Dictionary) -> void:
	if network_is_local:
		return
	_remote_target_position = _network_vector2(state.get("position", global_position))
	_remote_target_velocity = _network_vector2(state.get("velocity", velocity))
	_remote_target_rotation = float(state.get("rotation", rotation))
	_remote_state_received = true
	DRAG_enabled = bool(state.get("drag_enabled", DRAG_enabled))
	shields_on = bool(state.get("shield_active", shields_on))
	set_meta(&"network_weapon_id", String(state.get("weapon_id", "vector_bolt")))
	set_meta(&"network_input_device", String(state.get("input_device", "mouse_keyboard")))
	last_slingshot_score = clampf(float(state.get("slingshot_score", last_slingshot_score)), 0.0, 1.0)
	last_slingshot_grade = StringName(str(state.get("slingshot_grade", String(last_slingshot_grade))))

	if health_component != null:
		var max_health_value := float(state.get("max_health", health_component.get("max_health")))
		health_component.set("max_health", max_health_value)
		health_component.set("current_health", float(state.get("health", health_component.get("current_health"))))
	if energy_component != null:
		energy_component.set("max_energy", float(state.get("max_energy", energy_component.get("max_energy"))))
		energy_component.set("current_energy", float(state.get("energy", energy_component.get("current_energy"))))

	var remote_dead := bool(state.get("dead", false))
	if remote_dead and not _death_in_progress:
		_death_in_progress = true
		set_meta(&"death_in_progress", true)
		_apply_remote_death_visuals()
	elif not remote_dead and _death_in_progress:
		_death_in_progress = false
		set_meta(&"death_in_progress", false)
		_restore_remote_visuals()


func _apply_network_locality() -> void:
	_apply_network_color()
	if camera != null:
		camera.enabled = network_is_local
		if network_is_local:
			camera.make_current()

	var player_canvas := get_node_or_null("CanvasLayer") as CanvasLayer
	if player_canvas != null:
		player_canvas.visible = network_is_local
		player_canvas.process_mode = Node.PROCESS_MODE_ALWAYS if network_is_local else Node.PROCESS_MODE_DISABLED

	var pause_menu := get_node_or_null("CanvasLayer/PauseMenu")
	if pause_menu != null and not network_is_local:
		pause_menu.visible = false
		pause_menu.remove_from_group("PauseMenu")

	var trajectory := get_node_or_null("OrbitalTrajectoryPredictor") as Node2D
	if trajectory != null:
		trajectory.visible = network_is_local
	var aim_predictor := get_node_or_null("ProjectileAimPredictor") as Node2D
	if aim_predictor != null:
		aim_predictor.visible = network_is_local
	_update_network_nameplate()


func _apply_network_color() -> void:
	if hull_polygon == null:
		return
	hull_polygon.color = network_color
	var shader_material := hull_polygon.material as ShaderMaterial
	if shader_material == null:
		return
	if not shader_material.resource_local_to_scene:
		shader_material = shader_material.duplicate() as ShaderMaterial
		shader_material.resource_local_to_scene = true
		hull_polygon.material = shader_material
	shader_material.set_shader_parameter("hull_color", network_color)


func _ensure_network_nameplate() -> void:
	if _network_nameplate != null and is_instance_valid(_network_nameplate):
		return
	var label := Label.new()
	label.name = "NetworkNameplate"
	label.set_as_top_level(true)
	label.z_index = 80
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(150.0, 24.0)
	label.size = Vector2(150.0, 24.0)
	label.add_theme_font_size_override("font_size", network_nameplate_font_size)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	_network_nameplate = label


func _update_network_nameplate() -> void:
	_ensure_network_nameplate()
	if _network_nameplate == null or not is_instance_valid(_network_nameplate):
		return
	var network_active := NetworkSession != null and NetworkSession.is_network_active()
	var should_show := network_active and not _death_in_progress and (network_nameplate_visible_for_local or not network_is_local)
	_network_nameplate.visible = should_show
	if not should_show:
		return
	var display_name := network_display_name.strip_edges()
	if display_name.is_empty():
		display_name = "PEER %d" % network_peer_id
	_network_nameplate.text = display_name
	_network_nameplate.add_theme_color_override("font_color", network_color)
	_network_nameplate.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.08, 0.92))
	_network_nameplate.add_theme_constant_override("outline_size", 2)
	var width := maxf(118.0, float(display_name.length()) * 8.5 + 34.0)
	_network_nameplate.size = Vector2(width, 24.0)
	_network_nameplate.global_position = global_position + network_nameplate_offset - _network_nameplate.size * 0.5


func _apply_remote_network_state(delta: float) -> void:
	if not _remote_state_received:
		return
	var position_weight := clampf(delta * network_position_lerp_rate, 0.0, 1.0)
	var velocity_weight := clampf(delta * network_velocity_lerp_rate, 0.0, 1.0)
	global_position = global_position.lerp(_remote_target_position, position_weight)
	velocity = velocity.lerp(_remote_target_velocity, velocity_weight)
	rotation = lerp_angle(rotation, _remote_target_rotation, position_weight)


func _submit_network_state(delta: float) -> void:
	if not network_is_local:
		return
	if NetworkSession == null or not NetworkSession.is_network_active():
		return
	_network_send_elapsed += delta
	if _network_send_elapsed < maxf(network_state_send_interval, 0.016):
		return
	_network_send_elapsed = 0.0
	NetworkSession.submit_player_state(self)


func _apply_remote_death_visuals() -> void:
	velocity = Vector2.ZERO
	var col_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape != null:
		col_shape.set_deferred("disabled", true)
	if hull_polygon != null:
		hull_polygon.visible = false
	if shield_node != null:
		shield_node.visible = false
	var particles = get_node_or_null("GPUParticles2D") as GPUParticles2D
	if particles != null:
		particles.emitting = false
	_update_network_nameplate()


func _restore_remote_visuals() -> void:
	var col_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape != null:
		col_shape.set_deferred("disabled", false)
	if hull_polygon != null:
		hull_polygon.visible = true
	var particles = get_node_or_null("GPUParticles2D") as GPUParticles2D
	if particles != null:
		particles.emitting = true
	_update_network_nameplate()


func _network_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
	
func get_pause_menu() -> Node:
	# First try direct path (works in player scene)
	var direct = $CanvasLayer/PauseMenu
	if is_instance_valid(direct):
		return direct
	
	# Fallback: Search the tree (works when player is instanced in main scene)
	var menu = get_tree().get_first_node_in_group("PauseMenu")
	if is_instance_valid(menu):
		return menu
	
	# Last resort
	return get_tree().current_scene.find_child("PauseMenu", true, false)
