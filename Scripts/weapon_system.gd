extends Node2D
class_name WeaponSystem

signal weapon_changed(weapon_id: StringName, display_name: String, weapon_data: Dictionary)
signal weapon_fired(weapon_id: StringName, weapon_data: Dictionary)
signal weapon_energy_failed(weapon_id: StringName, required_energy: float, available_energy: float)

const PROJECTILE_SCENE := preload("res://Nodes/projectile.tscn")
const WEAPON_IDS: Array[StringName] = [
	&"vector_bolt",
	&"relativistic_rail",
	&"barycentric_splitter",
	&"vacuum_collapse_seed",
	&"positron_beam",
	&"gravity_wave_beam",
	&"chronal_refraction_beam",
]
const WEAPON_NAMES := {
	&"vector_bolt": "Vector Bolt",
	&"relativistic_rail": "Relativistic Rail",
	&"barycentric_splitter": "Barycentric Splitter",
	&"vacuum_collapse_seed": "Vacuum Collapse Seed",
	&"positron_beam": "Positron Beam",
	&"gravity_wave_beam": "Gravity Wave Beam",
	&"chronal_refraction_beam": "Chronal Refraction Beam",
}
const IMPACT_RING_WIDTH: float = 2.0

@export_node_path("Node2D") var player_path: NodePath = ^".."
@export var selected_weapon_index: int = 0
@export var enable_switch_hotkeys: bool = true
@export var switch_cooldown: float = 0.14

@export_group("Beam Geometry")
@export var beam_range: float = 1180.0
@export var positron_beam_width: float = 74.0
@export var gravity_wave_width: float = 118.0
@export var chronal_beam_width: float = 96.0
@export var max_beam_hits_per_tick: int = 36

@export_group("Energy")
@export var vector_bolt_energy_per_shot: float = 0.0
@export var relativistic_rail_energy_per_shot: float = 8.0
@export var barycentric_splitter_energy_per_shot: float = 11.0
@export var vacuum_seed_energy_per_shot: float = 24.0
@export var positron_energy_per_second: float = 34.0
@export var gravity_wave_energy_per_second: float = 22.0
@export var chronal_energy_per_second: float = 30.0
@export var minimum_beam_tick_cost: float = 2.2

@export_group("Projectile Cadence")
@export var vector_bolt_fire_interval: float = 0.18
@export var relativistic_rail_fire_interval: float = 0.34
@export var barycentric_splitter_fire_interval: float = 0.44
@export var vacuum_seed_fire_interval: float = 0.78
@export var projectile_spawn_offset: float = 70.0
@export var projectile_side_offset: float = 24.0
@export var projectile_minimum_energy_buffer: float = 0.0

@export_group("Projectile Profiles")
@export var vector_bolt_speed: float = 1080.0
@export var vector_bolt_damage_min: float = 28.0
@export var vector_bolt_damage_max: float = 38.0
@export var vector_bolt_gravity: float = 200.0
@export var relativistic_rail_speed: float = 1320.0
@export var relativistic_rail_damage_min: float = 42.0
@export var relativistic_rail_damage_max: float = 56.0
@export var relativistic_rail_impulse: float = 260.0
@export var barycentric_splitter_speed: float = 860.0
@export var barycentric_splitter_damage_min: float = 18.0
@export var barycentric_splitter_damage_max: float = 26.0
@export var barycentric_splitter_curve_force: float = 560.0
@export var barycentric_splitter_axis_impulse: float = 130.0
@export var vacuum_seed_speed: float = 620.0
@export var vacuum_seed_damage_min: float = 22.0
@export var vacuum_seed_damage_max: float = 32.0
@export var vacuum_seed_collapse_stacks: int = 1
@export var vacuum_seed_resonance_radius: float = 190.0

@export_group("Positron Beam")
@export var positron_damage_per_second: float = 145.0
@export var positron_planet_damage_per_second: float = 92.0
@export var positron_recoil: float = 36.0
@export var positron_scar_interval: float = 0.38

@export_group("Gravity Wave Beam")
@export var gravity_wave_force_per_second: float = 980.0
@export var gravity_wave_damage_per_second: float = 34.0
@export var gravity_wave_resonance_interval: float = 0.48
@export var gravity_wave_projectile_force_multiplier: float = 1.45
@export var gravity_wave_axis_pull_per_second: float = 1220.0
@export var gravity_wave_enemy_pull_multiplier: float = 1.25
@export var gravity_wave_forward_drift: float = 0.18
@export var gravity_wave_planet_damage_per_second: float = 46.0
@export var gravity_wave_planet_displacement_per_second: float = 42.0
@export var gravity_wave_planet_fracture_interval: float = 0.72

@export_group("Chronal Refraction Beam")
@export var chronal_slow_multiplier: float = 0.46
@export var chronal_slow_duration: float = 0.52
@export var chronal_refraction_damage_per_second: float = 30.0
@export var chronal_delayed_impulse: float = 280.0
@export var chronal_delay_seconds: float = 0.36
@export var chronal_zone_interval: float = 0.42
@export var chronal_echo_count: int = 3
@export var chronal_echo_spacing: float = 0.11
@export var chronal_echo_max_per_tick: int = 10
@export var chronal_desync_lateral_impulse: float = 150.0
@export var chronal_echo_zone_interval: float = 0.16

@export_group("Visuals")
@export var vector_bolt_color: Color = Color(0.34, 1.0, 0.86, 1.0)
@export var relativistic_rail_color: Color = Color(0.86, 1.0, 1.0, 1.0)
@export var barycentric_splitter_color: Color = Color(0.56, 1.0, 0.58, 1.0)
@export var vacuum_seed_color: Color = Color(1.0, 0.38, 0.2, 1.0)
@export var positron_color: Color = Color(1.0, 0.72, 0.28, 1.0)
@export var gravity_wave_color: Color = Color(0.3, 0.72, 1.0, 1.0)
@export var chronal_color: Color = Color(0.74, 0.36, 1.0, 1.0)
@export_range(0.0, 0.42, 0.01) var beam_alpha_cap: float = 0.34
@export var beam_impact_radius_cap: float = 96.0
@export var beam_pulse_speed: float = 10.0

@onready var _beam_root: Node2D = get_node_or_null("BeamRoot") as Node2D
@onready var _beam_glow: Line2D = get_node_or_null("BeamRoot/BeamGlow") as Line2D
@onready var _beam_core: Line2D = get_node_or_null("BeamRoot/BeamCore") as Line2D
@onready var _impact_ring: Line2D = get_node_or_null("BeamRoot/ImpactRing") as Line2D

var _player: Node2D = null
var _energy_component: Node = null
var _powerup_inventory: Node = null
var _pause_menu: Node = null
var _query_shape := RectangleShape2D.new()
var _query_params := PhysicsShapeQueryParameters2D.new()
var _active_weapon_id: StringName = &"vector_bolt"
var _beam_active := false
var _beam_heat := 0.0
var _last_switch_time := -999.0
var _last_projectile_fire_time := -999.0
var _projectile_pattern_index := 0
var _last_positron_scar_time := -999.0
var _last_wave_resonance_time := -999.0
var _last_wave_planet_fracture_time := -999.0
var _last_chronal_zone_time := -999.0
var _last_chronal_echo_zone_time := -999.0
var _chronal_phantoms_this_tick: int = 0
var _beam_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _chronal_trace_pool: Array[Line2D] = []


func _ready() -> void:
	add_to_group("weapon_system")
	_resolve_player()
	call_deferred("_resolve_pause_menu")
	_configure_query()
	_ensure_visual_nodes()
	select_weapon(selected_weapon_index)
	set_process_unhandled_input(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _is_gameplay_blocked() or _is_player_dead():
		_end_beam()
		return

	if not _is_beam_weapon(_active_weapon_id):
		_end_beam()
		return

	if Input.is_action_pressed("shoot"):
		_fire_selected_beam(delta)
	else:
		_end_beam()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_switch_hotkeys or _is_gameplay_blocked() or _is_player_dead():
		return

	if _input_pressed(event, &"weapon_next", KEY_TAB):
		select_next_weapon()
		get_viewport().set_input_as_handled()
	elif _input_pressed(event, &"weapon_previous", KEY_BACKTAB):
		select_previous_weapon()
		get_viewport().set_input_as_handled()


func try_primary_fire() -> bool:
	if _is_player_dead():
		return false
	if _is_beam_weapon(_active_weapon_id):
		return true
	if _is_projectile_weapon(_active_weapon_id):
		_fire_projectile_weapon()
		return true
	return false


func force_cease_fire() -> void:
	_end_beam()


func get_current_fire_interval() -> float:
	if _is_beam_weapon(_active_weapon_id):
		return 0.03
	return _projectile_fire_interval(_active_weapon_id)


func is_current_weapon_projectile() -> bool:
	return _is_projectile_weapon(_active_weapon_id)


func get_projectile_prediction_state() -> Dictionary:
	return _projectile_prediction_state(_active_weapon_id)


func select_next_weapon() -> void:
	select_weapon(selected_weapon_index + 1)


func select_previous_weapon() -> void:
	select_weapon(selected_weapon_index - 1)


func select_weapon(index: int) -> void:
	var now := _now_seconds()
	if now - _last_switch_time < switch_cooldown:
		return
	_last_switch_time = now

	selected_weapon_index = posmod(index, WEAPON_IDS.size())
	_active_weapon_id = WEAPON_IDS[selected_weapon_index]
	_end_beam()
	weapon_changed.emit(_active_weapon_id, _display_name(_active_weapon_id), get_weapon_debug_state())


func select_weapon_by_id(weapon_id: StringName) -> void:
	var index := WEAPON_IDS.find(weapon_id)
	if index >= 0:
		select_weapon(index)


func get_weapon_debug_state() -> Dictionary:
	var energy := _current_energy()
	var max_energy := _max_energy()
	var cost := _energy_cost_for_weapon(_active_weapon_id)
	var is_beam := _is_beam_weapon(_active_weapon_id)
	var is_projectile := _is_projectile_weapon(_active_weapon_id)
	var interval := get_current_fire_interval()
	var cooldown_remaining := maxf(interval - (_now_seconds() - _last_projectile_fire_time), 0.0) if is_projectile else 0.0
	return {
		"weapon_id": _active_weapon_id,
		"display_name": _display_name(_active_weapon_id),
		"index": selected_weapon_index,
		"count": WEAPON_IDS.size(),
		"fire_mode": &"beam" if is_beam else &"projectile",
		"is_projectile": is_projectile,
		"beam_active": _beam_active,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_percent": 1.0 - clampf(cooldown_remaining / maxf(interval, 0.001), 0.0, 1.0),
		"fire_interval": interval,
		"energy": energy,
		"max_energy": max_energy,
		"energy_percent": energy / maxf(max_energy, 1.0),
		"cost_per_second": cost,
		"cost_per_shot": _projectile_energy_cost(_active_weapon_id),
		"ready": cooldown_remaining <= 0.001 and energy >= _minimum_energy_for_weapon(_active_weapon_id),
		"role": _weapon_role(_active_weapon_id),
		"color": _weapon_color(_active_weapon_id),
	}


func _fire_selected_beam(delta: float) -> void:
	_resolve_player()
	if _player == null or not is_instance_valid(_player) or _is_player_dead():
		_end_beam()
		return

	var tick_cost := maxf(_energy_cost_for_weapon(_active_weapon_id) * delta, minimum_beam_tick_cost)
	if not _spend_energy(tick_cost):
		weapon_energy_failed.emit(_active_weapon_id, tick_cost, _current_energy())
		_end_beam()
		return

	var origin := _player.global_position + _aim_direction() * 74.0
	var direction := _aim_direction()
	var width := _beam_width_for_weapon(_active_weapon_id)
	var hits := _collect_beam_hits(origin, direction, width)

	if _active_weapon_id == &"positron_beam":
		_apply_positron_beam(origin, direction, hits, delta)
	elif _active_weapon_id == &"gravity_wave_beam":
		_apply_gravity_wave_beam(origin, direction, hits, delta)
	else:
		_apply_chronal_refraction_beam(origin, direction, hits, delta)

	_update_beam_visual(origin, direction, width, hits)
	weapon_fired.emit(_active_weapon_id, {
		"origin": origin,
		"direction": direction,
		"hits": hits.size(),
		"energy_spent": tick_cost,
		"fire_mode": &"beam",
	})


func _fire_projectile_weapon() -> bool:
	_resolve_player()
	if _player == null or not is_instance_valid(_player) or _is_player_dead():
		return false
	if _is_gameplay_blocked():
		return false

	var now := _now_seconds()
	var interval := _projectile_fire_interval(_active_weapon_id)
	if now - _last_projectile_fire_time < interval:
		return false

	var shot_cost := _projectile_energy_cost(_active_weapon_id)
	if shot_cost > 0.0 and not _spend_energy(shot_cost):
		weapon_energy_failed.emit(_active_weapon_id, shot_cost, _current_energy())
		return false

	var direction := _aim_direction()
	var origin := _player.global_position + direction * projectile_spawn_offset
	var spawned := _spawn_projectile_pattern(_active_weapon_id, origin, direction)
	if spawned <= 0:
		if shot_cost > 0.0:
			_restore_energy(shot_cost)
		return false

	_last_projectile_fire_time = now
	_play_projectile_sound(spawned)
	_apply_projectile_recoil(direction)
	if _powerup_inventory != null and is_instance_valid(_powerup_inventory) and _powerup_inventory.has_method("trigger_player_action"):
		_powerup_inventory.call("trigger_player_action")

	weapon_fired.emit(_active_weapon_id, {
		"origin": origin,
		"direction": direction,
		"projectiles": spawned,
		"energy_spent": shot_cost,
		"fire_mode": &"projectile",
	})
	return true


func _spawn_projectile_pattern(weapon_id: StringName, origin: Vector2, direction: Vector2) -> int:
	var count := _projectile_count_for_weapon(weapon_id)
	var spawned := 0
	for shot_index in range(count):
		var shot_direction := _projectile_direction_for_index(weapon_id, direction, shot_index, count)
		var side_offset := _projectile_side_offset_for_index(shot_direction, shot_index, count)
		if _spawn_configured_projectile(weapon_id, origin + side_offset, shot_direction, shot_index, count):
			spawned += 1
	_projectile_pattern_index += 1
	return spawned


func _spawn_configured_projectile(
	weapon_id: StringName,
	origin: Vector2,
	direction: Vector2,
	shot_index: int,
	shot_count: int
) -> bool:
	var projectile := PROJECTILE_SCENE.instantiate() as RigidBody2D
	if projectile == null:
		return false

	projectile.global_position = origin
	projectile.global_rotation = direction.angle()
	_apply_projectile_payload(projectile, _projectile_payload(weapon_id, shot_index, shot_count))

	var momentum_component := _player.get_node_or_null("MomentumCombatComponent")
	if momentum_component != null and momentum_component.has_method("prepare_projectile"):
		momentum_component.call("prepare_projectile", projectile, direction)
		_refresh_payload_from_projectile(projectile)

	if _player.has_signal("momentum_projectile_spawned"):
		_player.emit_signal("momentum_projectile_spawned", projectile, direction)

	var root := get_tree().current_scene
	if root == null:
		return false
	root.call_deferred("add_child", projectile)

	if projectile.has_method("launch"):
		projectile.call_deferred("launch", direction)
	else:
		projectile.call_deferred("apply_central_impulse", direction * _projectile_speed_for_weapon(weapon_id))
	return true


func _apply_positron_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
	var damage := positron_damage_per_second * delta
	var planet_damage := positron_planet_damage_per_second * delta
	var damaged_planet := false

	for target in hits:
		if target == null or not is_instance_valid(target):
			continue

		if _is_destructible_planet(target):
			target.call("apply_spacetime_damage", planet_damage, target.global_position, &"positron_beam")
			damaged_planet = true
			continue

		if target.has_method("take_damage") and _is_hostile_target(target):
			target.call("take_damage", damage)

	if positron_recoil > 0.0:
		CombatStatus.add_velocity(_player, -direction * positron_recoil * delta)

	if damaged_planet:
		_stamp_positron_scar(origin + direction * beam_range * 0.55)


func _apply_gravity_wave_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
	var force := gravity_wave_force_per_second * delta
	var axis_pull := gravity_wave_axis_pull_per_second * delta
	var damage := gravity_wave_damage_per_second * delta

	for target in hits:
		if target == null or not is_instance_valid(target):
			continue

		var target_2d := target as Node2D
		if target_2d == null:
			continue

		var offset := target_2d.global_position - origin
		var along_distance := offset.dot(direction)
		var along := clampf(along_distance / maxf(beam_range, 1.0), 0.0, 1.0)
		var axis_point := origin + direction * clampf(along_distance, 0.0, beam_range)
		var to_axis := axis_point - target_2d.global_position
		var axis_dir := to_axis.normalized()
		if axis_dir == Vector2.ZERO:
			axis_dir = direction.orthogonal()
		var warp_dir := (axis_dir + direction * gravity_wave_forward_drift).normalized()
		var hostile_multiplier := gravity_wave_enemy_pull_multiplier if _is_hostile_target(target_2d) else 1.0
		var projectile_multiplier := gravity_wave_projectile_force_multiplier if target_2d.is_in_group("enemy_projectiles") else 1.0
		var falloff := lerpf(1.0, 0.48, along)

		if _is_destructible_planet(target_2d):
			_apply_gravity_wave_to_planet(target_2d, warp_dir, falloff, delta)
			continue

		CombatStatus.add_velocity(target_2d, warp_dir * (force + axis_pull) * hostile_multiplier * projectile_multiplier * falloff)
		target_2d.set_meta(&"gravity_wave_beam_pressure", clampf(1.0 - along * 0.42, 0.0, 1.0))

		if target.has_method("take_damage") and _is_hostile_target(target):
			target.call("take_damage", damage)

	_stamp_gravity_wave_resonance(origin, direction)


func _apply_chronal_refraction_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
	_chronal_phantoms_this_tick = 0
	var stacks := maxi(_powerup_stack_count(&"chronal_refraction_beam"), 1)
	var slow := clampf(chronal_slow_multiplier - 0.035 * float(stacks - 1), 0.25, 0.86)
	var duration := chronal_slow_duration * (1.0 + 0.12 * float(stacks - 1))
	var damage := chronal_refraction_damage_per_second * delta * (1.0 + 0.18 * float(stacks - 1))
	var impulse := direction * chronal_delayed_impulse * (1.0 + 0.14 * float(stacks - 1))

	for target in hits:
		var target_2d := target as Node2D
		if target_2d == null or not is_instance_valid(target_2d):
			continue
		if target_2d.is_in_group("Player"):
			continue

		var body_velocity := _body_velocity(target_2d)
		var lateral := direction.orthogonal()
		if lateral.dot(body_velocity) < 0.0:
			lateral = -lateral
		var desync_impulse := lateral * chronal_desync_lateral_impulse * (1.0 + 0.08 * float(stacks - 1))

		CombatStatus.apply_local_time_scale(target_2d, slow, duration)
		target_2d.set_meta(&"chronal_refraction_delay", chronal_delay_seconds)
		target_2d.set_meta(&"chronal_phantom_position", target_2d.global_position - body_velocity * chronal_delay_seconds)
		target_2d.set_meta(&"chronal_desync_impulse", desync_impulse)

		if target_2d.has_method("take_damage") and _is_hostile_target(target_2d):
			target_2d.call("take_damage", damage)

		_spawn_chronal_echoes(target_2d, body_velocity)
		_apply_delayed_chronal_chain(target_2d, impulse + desync_impulse, damage * 0.9, chronal_delay_seconds)

	_stamp_chronal_refraction_zone(origin, direction, stacks)


func _stamp_positron_scar(position: Vector2) -> void:
	var now := _now_seconds()
	if now - _last_positron_scar_time < positron_scar_interval:
		return
	_last_positron_scar_time = now

	var scars := _get_gravity_scar_manager()
	if scars == null or not scars.has_method("create_gravity_scar"):
		return
	scars.call(
		"create_gravity_scar",
		position,
		260.0,
		GravityScarManager.ScarType.TEMPORAL_RIP,
		0.46,
		30.0,
		&"positron_beam"
	)


func _stamp_gravity_wave_resonance(origin: Vector2, direction: Vector2) -> void:
	var now := _now_seconds()
	if now - _last_wave_resonance_time < gravity_wave_resonance_interval:
		return
	_last_wave_resonance_time = now

	var resonance := _get_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	resonance.call(
		"create_manual_resonance_zone",
		origin + direction * beam_range * 0.42,
		260.0,
		GravityResonanceManager.ZoneType.COMPRESSION,
		0.48,
		1.0
	)


func _apply_gravity_wave_to_planet(target: Node2D, warp_dir: Vector2, falloff: float, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var displacement := warp_dir * gravity_wave_planet_displacement_per_second * falloff * delta
	target.global_position += displacement
	target.set_meta(&"gravity_wave_beam_pressure", falloff)
	target.set_meta(&"gravity_wave_displacement", displacement)

	var now := _now_seconds()
	if now - _last_wave_planet_fracture_time < gravity_wave_planet_fracture_interval:
		return
	_last_wave_planet_fracture_time = now

	if target.has_method("apply_spacetime_damage"):
		target.call(
			"apply_spacetime_damage",
			gravity_wave_planet_damage_per_second * falloff * maxf(delta, 0.016),
			target.global_position,
			&"gravity_wave_beam"
		)


func _stamp_chronal_refraction_zone(origin: Vector2, direction: Vector2, stacks: int) -> void:
	var now := _now_seconds()
	if now - _last_chronal_zone_time < chronal_zone_interval:
		return
	_last_chronal_zone_time = now

	var resonance := _get_resonance_manager()
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		resonance.call(
			"create_manual_resonance_zone",
			origin + direction * beam_range * 0.38,
			230.0 + 28.0 * float(stacks - 1),
			GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
			0.54 + 0.06 * float(stacks - 1),
			1.35
		)

	var anomaly := _get_anomaly_director()
	if anomaly != null and anomaly.has_method("record_chronal_refraction"):
		anomaly.call(
			"record_chronal_refraction",
			origin + direction * beam_range * 0.38,
			direction,
			0.54 + 0.08 * float(stacks - 1),
			260.0 + 32.0 * float(stacks - 1)
		)


func _apply_delayed_chronal_chain(target: Node2D, impulse: Vector2, damage: float, delay: float) -> void:
	await get_tree().create_timer(maxf(delay, 0.02)).timeout
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	CombatStatus.add_velocity(target, impulse)
	CombatStatus.apply_local_time_scale(target, 0.72, 0.22)
	if target.has_method("take_damage") and _is_hostile_target(target):
		target.call("take_damage", damage)
	_stamp_chronal_echo_zone(target.global_position)


func _spawn_chronal_echoes(target: Node2D, body_velocity: Vector2) -> void:
	for echo_index in range(maxi(chronal_echo_count, 1)):
		if _chronal_phantoms_this_tick >= chronal_echo_max_per_tick:
			return
		var echo_delay := chronal_delay_seconds + chronal_echo_spacing * float(echo_index)
		var phantom_position := target.global_position - body_velocity * echo_delay
		_spawn_chronal_phantom(target, phantom_position, echo_index)
		_chronal_phantoms_this_tick += 1


func _spawn_chronal_phantom(target: Node2D, phantom_position: Vector2, echo_index: int) -> void:
	var root := get_tree().current_scene
	if root == null or target == null:
		return
	var line := _acquire_chronal_trace(root)
	line.antialiased = true
	line.width = maxf(1.2, 2.6 - float(echo_index) * 0.35)
	line.default_color = Color(chronal_color.r, chronal_color.g, chronal_color.b, _visual_alpha(0.38 - float(echo_index) * 0.055))
	line.points = PackedVector2Array([phantom_position, target.global_position])
	line.top_level = true
	line.z_index = 34
	line.modulate = Color.WHITE
	line.visible = true
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.38 + float(echo_index) * 0.05)
	tween.tween_callback(Callable(self, "_release_chronal_trace").bind(line))


func _acquire_chronal_trace(root: Node) -> Line2D:
	for line in _chronal_trace_pool:
		if line != null and is_instance_valid(line) and not line.visible:
			if line.get_parent() == null:
				root.add_child(line)
			elif line.get_parent() != root:
				line.reparent(root)
			return line
	var line := Line2D.new()
	line.name = "ChronalPhantomTrace"
	_chronal_trace_pool.append(line)
	root.add_child(line)
	return line


func _release_chronal_trace(line: Line2D) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.visible = false
	line.modulate = Color.WHITE


func _stamp_chronal_echo_zone(position: Vector2) -> void:
	var now := _now_seconds()
	if now - _last_chronal_echo_zone_time < chronal_echo_zone_interval:
		return
	_last_chronal_echo_zone_time = now
	var resonance := _get_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	resonance.call(
		"create_manual_resonance_zone",
		position,
		150.0,
		GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
		0.38,
		0.62
	)


func _projectile_payload(weapon_id: StringName, shot_index: int, shot_count: int) -> Dictionary:
	var color := _weapon_color(weapon_id)
	var payload := {
		"weapon_id": weapon_id,
		"display_name": _display_name(weapon_id),
		"initial_speed": _projectile_speed_for_weapon(weapon_id),
		"damage_min": _projectile_damage_min_for_weapon(weapon_id),
		"damage_max": _projectile_damage_max_for_weapon(weapon_id),
		"gravity_constant": _projectile_gravity_for_weapon(weapon_id),
		"gravity_pull_radius": 2000.0,
		"player_gravity_deadzone_radius": 520.0,
		"windowkill_visual_scale": _projectile_visual_scale_for_weapon(weapon_id),
		"vector_core_color": Color(color.r, color.g, color.b, 0.82),
		"vector_trail_fade_color": _projectile_trail_color_for_weapon(weapon_id),
		"weapon_axis_impulse": 0.0,
		"weapon_temporal_slow_multiplier": 1.0,
		"weapon_temporal_slow_duration": 0.0,
		"weapon_pierce_count": 0,
		"weapon_resonance_zone_type": -1,
		"weapon_resonance_radius": 0.0,
		"weapon_resonance_intensity": 0.0,
		"weapon_curve_force": 0.0,
		"weapon_curve_side": _projectile_side_for_index(shot_index, shot_count),
		"weapon_curve_frequency": 7.0,
		"weapon_planet_damage": 0.0,
		"relativistic_rail_stacks": 0,
		"vacuum_collapse_stacks": 0,
	}

	match weapon_id:
		&"relativistic_rail":
			payload["weapon_axis_impulse"] = relativistic_rail_impulse
			payload["weapon_pierce_count"] = 1
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.SLIPSTREAM
			payload["weapon_resonance_radius"] = 145.0
			payload["weapon_resonance_intensity"] = 0.34
			payload["relativistic_rail_stacks"] = 1
			payload["gravity_pull_radius"] = 1500.0
			payload["player_gravity_deadzone_radius"] = 620.0
		&"barycentric_splitter":
			payload["weapon_curve_force"] = barycentric_splitter_curve_force
			payload["weapon_axis_impulse"] = barycentric_splitter_axis_impulse
			payload["weapon_temporal_slow_multiplier"] = 0.82
			payload["weapon_temporal_slow_duration"] = 0.16
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.HARMONIC_ORBIT
			payload["weapon_resonance_radius"] = 132.0
			payload["weapon_resonance_intensity"] = 0.31
		&"vacuum_collapse_seed":
			payload["vacuum_collapse_stacks"] = vacuum_seed_collapse_stacks
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.COMPRESSION
			payload["weapon_resonance_radius"] = vacuum_seed_resonance_radius
			payload["weapon_resonance_intensity"] = 0.46
			payload["weapon_planet_damage"] = 34.0
			payload["gravity_pull_radius"] = 1700.0
			payload["player_gravity_deadzone_radius"] = 760.0
		_:
			pass
	return payload


func _apply_projectile_payload(projectile: Node, payload: Dictionary) -> void:
	if projectile == null:
		return
	if projectile.has_method("apply_weapon_payload"):
		projectile.call("apply_weapon_payload", payload)
		return

	projectile.set_meta(&"weapon_payload", payload.duplicate(true))
	for key in payload.keys():
		var property_name := String(key)
		if projectile.get(property_name) != null:
			projectile.set(property_name, payload[key])


func _refresh_payload_from_projectile(projectile: Node) -> void:
	if projectile == null or not projectile.has_meta(&"weapon_payload"):
		return
	var payload_value: Variant = projectile.get_meta(&"weapon_payload")
	if typeof(payload_value) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = payload_value
	for property_name in [
		"initial_speed",
		"damage_min",
		"damage_max",
		"gravity_constant",
		"gravity_pull_radius",
		"player_gravity_deadzone_radius",
	]:
		var value: Variant = projectile.get(property_name)
		if value != null:
			payload[property_name] = value
	projectile.set_meta(&"weapon_payload", payload.duplicate(true))


func _projectile_prediction_state(weapon_id: StringName) -> Dictionary:
	if not _is_projectile_weapon(weapon_id):
		return {"is_projectile": false}
	var color := _weapon_color(weapon_id)
	return {
		"is_projectile": true,
		"weapon_id": weapon_id,
		"display_name": _display_name(weapon_id),
		"initial_speed": _projectile_speed_for_weapon(weapon_id),
		"gravity_constant": _projectile_gravity_for_weapon(weapon_id),
		"gravity_pull_radius": 2000.0,
		"player_gravity_deadzone_radius": 520.0,
		"spawn_offset": projectile_spawn_offset,
		"collision_radius": 68.5 * _projectile_visual_scale_for_weapon(weapon_id),
		"prediction_color": Color(color.r, color.g, color.b, 0.62),
		"danger_color": _projectile_trail_color_for_weapon(weapon_id),
	}


func _projectile_count_for_weapon(weapon_id: StringName) -> int:
	if weapon_id == &"barycentric_splitter":
		return 2
	return 1


func _projectile_direction_for_index(
	weapon_id: StringName,
	direction: Vector2,
	shot_index: int,
	shot_count: int
) -> Vector2:
	if weapon_id != &"barycentric_splitter" or shot_count <= 1:
		return direction
	var spread := -0.08 if shot_index == 0 else 0.08
	return direction.rotated(spread).normalized()


func _projectile_side_offset_for_index(direction: Vector2, shot_index: int, shot_count: int) -> Vector2:
	if shot_count <= 1:
		return Vector2.ZERO
	return direction.orthogonal() * _projectile_side_for_index(shot_index, shot_count) * projectile_side_offset


func _projectile_side_for_index(shot_index: int, shot_count: int) -> float:
	if shot_count <= 1:
		return 0.0
	return -1.0 if shot_index % 2 == 0 else 1.0


func _projectile_fire_interval(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return maxf(relativistic_rail_fire_interval, 0.05)
		&"barycentric_splitter":
			return maxf(barycentric_splitter_fire_interval, 0.05)
		&"vacuum_collapse_seed":
			return maxf(vacuum_seed_fire_interval, 0.05)
	return maxf(vector_bolt_fire_interval, 0.05)


func _projectile_energy_cost(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_energy_per_shot
		&"barycentric_splitter":
			return barycentric_splitter_energy_per_shot
		&"vacuum_collapse_seed":
			return vacuum_seed_energy_per_shot
	return vector_bolt_energy_per_shot


func _projectile_speed_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_speed
		&"barycentric_splitter":
			return barycentric_splitter_speed
		&"vacuum_collapse_seed":
			return vacuum_seed_speed
	return vector_bolt_speed


func _projectile_damage_min_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_damage_min
		&"barycentric_splitter":
			return barycentric_splitter_damage_min
		&"vacuum_collapse_seed":
			return vacuum_seed_damage_min
	return vector_bolt_damage_min


func _projectile_damage_max_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_damage_max
		&"barycentric_splitter":
			return barycentric_splitter_damage_max
		&"vacuum_collapse_seed":
			return vacuum_seed_damage_max
	return vector_bolt_damage_max


func _projectile_gravity_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return vector_bolt_gravity * 0.62
		&"barycentric_splitter":
			return vector_bolt_gravity * 1.22
		&"vacuum_collapse_seed":
			return vector_bolt_gravity * 0.84
	return vector_bolt_gravity


func _projectile_visual_scale_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"relativistic_rail":
			return 1.28
		&"barycentric_splitter":
			return 0.92
		&"vacuum_collapse_seed":
			return 1.18
	return 1.18


func _projectile_trail_color_for_weapon(weapon_id: StringName) -> Color:
	match weapon_id:
		&"relativistic_rail":
			return Color(0.24, 0.55, 1.0, 0.9)
		&"barycentric_splitter":
			return Color(0.18, 1.0, 0.62, 0.86)
		&"vacuum_collapse_seed":
			return Color(1.0, 0.18, 0.08, 0.88)
	return Color(1.0, 0.35, 0.1, 0.95)


func _minimum_energy_for_weapon(weapon_id: StringName) -> float:
	if _is_beam_weapon(weapon_id):
		return minimum_beam_tick_cost
	return maxf(_projectile_energy_cost(weapon_id), projectile_minimum_energy_buffer)


func _weapon_role(weapon_id: StringName) -> String:
	match weapon_id:
		&"relativistic_rail":
			return "velocity pierce"
		&"barycentric_splitter":
			return "linked orbit pressure"
		&"vacuum_collapse_seed":
			return "delayed compression"
		&"positron_beam":
			return "direct fracture beam"
		&"gravity_wave_beam":
			return "field control beam"
		&"chronal_refraction_beam":
			return "local time shear"
	return "baseline vector shot"


func _play_projectile_sound(spawned: int) -> void:
	var sound := _player.get_node_or_null("BulletBlastSoundEffect") as AudioStreamPlayer
	if sound == null:
		return
	sound.pitch_scale = clampf(0.92 + float(spawned - 1) * 0.06, 0.7, 1.35)
	sound.play()


func _apply_projectile_recoil(direction: Vector2) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var recoil_value: Variant = _player.get("recoil_instability")
	if not (typeof(recoil_value) == TYPE_FLOAT or typeof(recoil_value) == TYPE_INT):
		return
	var recoil := float(recoil_value)
	if recoil <= 0.0:
		return
	CombatStatus.add_velocity(_player, -direction.rotated(randf_range(-0.22, 0.22)) * recoil)


func _restore_energy(amount: float) -> void:
	if amount <= 0.0 or _energy_component == null:
		return
	if _energy_component.has_method("restore"):
		_energy_component.call("restore", amount)


func _collect_beam_hits(origin: Vector2, direction: Vector2, width: float) -> Array[Node]:
	_query_shape.size = Vector2(beam_range, width)
	_query_params.transform = Transform2D(direction.angle(), origin + direction * beam_range * 0.5)

	var exclude: Array[RID] = []
	var collision_object := _player as CollisionObject2D
	if collision_object != null:
		exclude.append(collision_object.get_rid())
	_query_params.exclude = exclude

	var results := get_world_2d().direct_space_state.intersect_shape(_query_params, max_beam_hits_per_tick)
	var hits: Array[Node] = []
	var seen := {}

	for result in results:
		var collider_value: Variant = result.get("collider")
		if collider_value == null or not is_instance_valid(collider_value):
			continue
		var collider := collider_value as Node
		if collider == null or collider.is_queued_for_deletion():
			continue
		if _is_player_owned(collider):
			continue
		var id := collider.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		hits.append(collider)

	return hits


func _update_beam_visual(origin: Vector2, direction: Vector2, width: float, hits: Array[Node]) -> void:
	_ensure_visual_nodes()
	if _beam_root == null or _beam_core == null or _beam_glow == null:
		return

	var pulse := 0.72 + 0.28 * sin(_now_seconds() * beam_pulse_speed)
	var color := _weapon_color(_active_weapon_id)
	var safe_alpha := _visual_alpha(beam_alpha_cap)
	var visual_range := _visual_range_from_hits(origin, direction, hits)
	_beam_points[1] = Vector2(visual_range, 0.0)

	_beam_root.visible = true
	_beam_root.global_position = origin
	_beam_root.rotation = direction.angle()

	_beam_glow.points = _beam_points
	_beam_glow.width = width * 0.78
	_beam_glow.default_color = Color(color.r, color.g, color.b, safe_alpha * 0.24 * pulse)

	_beam_core.points = _beam_points
	_beam_core.width = maxf(width * 0.18, 6.0)
	_beam_core.default_color = Color(color.r, color.g, color.b, safe_alpha * pulse)

	if _impact_ring != null:
		var ring_radius := _impact_radius(maxf(width * 0.18, 12.0))
		_impact_ring.position = Vector2(visual_range, 0.0)
		_impact_ring.scale = Vector2.ONE * ring_radius
		_impact_ring.width = IMPACT_RING_WIDTH / maxf(ring_radius, 1.0)
		_impact_ring.default_color = Color(color.r, color.g, color.b, safe_alpha * 0.64)
		_impact_ring.rotation += get_physics_process_delta_time() * 3.2

	_beam_active = true
	_beam_heat = minf(_beam_heat + get_physics_process_delta_time() * 3.0, 1.0)


func _visual_range_from_hits(origin: Vector2, direction: Vector2, hits: Array[Node]) -> float:
	var best := beam_range
	for target in hits:
		var target_2d := target as Node2D
		if target_2d == null:
			continue
		if _is_destructible_planet(target):
			var along := (target_2d.global_position - origin).dot(direction)
			best = minf(best, clampf(along, beam_range * 0.18, beam_range))
	return best


func _end_beam() -> void:
	_beam_active = false
	_beam_heat = maxf(_beam_heat - get_physics_process_delta_time() * 4.0, 0.0) if is_inside_tree() else 0.0
	if _beam_root != null:
		_beam_root.visible = false


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	_energy_component = _player.get_node_or_null("EnergyComponent") if _player != null else null
	_powerup_inventory = _player.get_node_or_null("PowerupInventory") if _player != null else null


func _configure_query() -> void:
	_query_params.shape = _query_shape
	_query_params.collide_with_areas = true
	_query_params.collide_with_bodies = true


func _ensure_visual_nodes() -> void:
	if _beam_root == null:
		_beam_root = Node2D.new()
		_beam_root.name = "BeamRoot"
		_beam_root.top_level = true
		_beam_root.z_index = 35
		add_child(_beam_root)
	if _beam_glow == null:
		_beam_glow = Line2D.new()
		_beam_glow.name = "BeamGlow"
		_beam_glow.antialiased = true
		_beam_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_root.add_child(_beam_glow)
	if _beam_core == null:
		_beam_core = Line2D.new()
		_beam_core.name = "BeamCore"
		_beam_core.antialiased = true
		_beam_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_core.end_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_root.add_child(_beam_core)
	if _impact_ring == null:
		_impact_ring = Line2D.new()
		_impact_ring.name = "ImpactRing"
		_impact_ring.closed = true
		_impact_ring.antialiased = true
		_impact_ring.width = IMPACT_RING_WIDTH
		_beam_root.add_child(_impact_ring)
	if _impact_ring.points.size() < 3:
		_impact_ring.points = _circle_points(28, 1.0)
	_beam_root.visible = false


func _input_pressed(event: InputEvent, action_name: StringName, fallback_key: Key) -> bool:
	if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == fallback_key


func _is_beam_weapon(weapon_id: StringName) -> bool:
	return weapon_id == &"positron_beam" or weapon_id == &"gravity_wave_beam" or weapon_id == &"chronal_refraction_beam"


func _is_projectile_weapon(weapon_id: StringName) -> bool:
	return (
		weapon_id == &"vector_bolt"
		or weapon_id == &"relativistic_rail"
		or weapon_id == &"barycentric_splitter"
		or weapon_id == &"vacuum_collapse_seed"
	)


func _is_hostile_target(target: Node) -> bool:
	return target.is_in_group("enemies") or target.is_in_group("wave_enemy") or target.is_in_group("bosses")


func _is_destructible_planet(target: Node) -> bool:
	return (
		target.is_in_group("planets")
		and not _is_hostile_target(target)
		and target.has_method("apply_spacetime_damage")
	)


func _is_player_owned(target: Node) -> bool:
	if target == _player:
		return true
	if _player != null and _player.is_ancestor_of(target):
		return true
	return target.is_in_group("Player") or target.is_in_group("player_projectiles")


func _is_player_dead() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_death_in_progress"):
		return bool(_player.call("is_death_in_progress"))
	if _player.has_method("is_dead"):
		return bool(_player.call("is_dead"))
	if _player.has_meta(&"death_in_progress"):
		return bool(_player.get_meta(&"death_in_progress"))
	return false


func _aim_direction() -> Vector2:
	if _player == null:
		return Vector2.RIGHT
	var direction := -_player.transform.x.normalized()
	return direction if direction.length_squared() > 0.001 else Vector2.RIGHT


func _spend_energy(amount: float) -> bool:
	_resolve_player()
	if _energy_component == null:
		return false
	if _energy_component.has_method("has_energy") and not bool(_energy_component.call("has_energy", amount)):
		return false
	if _energy_component.has_method("spend"):
		_energy_component.call("spend", amount)
		return true
	return false


func _current_energy() -> float:
	_resolve_player()
	if _energy_component == null:
		return 0.0
	var value: Variant = _energy_component.get("current_energy")
	return float(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else 0.0


func _max_energy() -> float:
	_resolve_player()
	if _energy_component == null:
		return 1.0
	var value: Variant = _energy_component.get("max_energy")
	return float(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else 1.0


func _energy_cost_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"positron_beam":
			return positron_energy_per_second
		&"gravity_wave_beam":
			return gravity_wave_energy_per_second
		&"chronal_refraction_beam":
			return chronal_energy_per_second
	return 0.0


func _beam_width_for_weapon(weapon_id: StringName) -> float:
	if weapon_id == &"positron_beam":
		return positron_beam_width
	if weapon_id == &"chronal_refraction_beam":
		return chronal_beam_width
	return gravity_wave_width


func _weapon_color(weapon_id: StringName) -> Color:
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_color
		&"barycentric_splitter":
			return barycentric_splitter_color
		&"vacuum_collapse_seed":
			return vacuum_seed_color
		&"positron_beam":
			return positron_color
		&"gravity_wave_beam":
			return gravity_wave_color
		&"chronal_refraction_beam":
			return chronal_color
	return vector_bolt_color


func _display_name(weapon_id: StringName) -> String:
	return String(WEAPON_NAMES.get(weapon_id, "Vector Bolt"))


func _get_resonance_manager() -> Node:
	var root := get_tree().current_scene
	return root.find_child("GravityResonanceManager", true, false) if root != null else null


func _get_gravity_scar_manager() -> Node:
	var root := get_tree().current_scene
	return root.find_child("GravityScarManager", true, false) if root != null else null


func _get_anomaly_director() -> Node:
	var root := get_tree().current_scene
	return root.find_child("VectorAnomalyDirector", true, false) if root != null else null


func _powerup_stack_count(powerup_id: StringName) -> int:
	_resolve_player()
	if _powerup_inventory != null and is_instance_valid(_powerup_inventory) and _powerup_inventory.has_method("get_stack_count"):
		return int(_powerup_inventory.call("get_stack_count", powerup_id))
	return 0


func _body_velocity(body: Node) -> Vector2:
	if body == null or not is_instance_valid(body):
		return Vector2.ZERO
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	return Vector2.ZERO


func _is_gameplay_blocked() -> bool:
	if _pause_menu != null and is_instance_valid(_pause_menu) and _pause_menu.has_method("is_gameplay_blocked"):
		return bool(_pause_menu.call("is_gameplay_blocked"))
	return get_tree().paused


func _resolve_pause_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_pause_menu = tree.get_first_node_in_group("PauseMenu")


func _visual_alpha(alpha: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, beam_alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), beam_alpha_cap)
	return minf(alpha, beam_alpha_cap)


func _impact_radius(radius: float) -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(radius, beam_impact_radius_cap)
	return minf(radius, beam_impact_radius_cap)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
