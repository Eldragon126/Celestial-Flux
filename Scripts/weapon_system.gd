extends Node2D
class_name WeaponSystem

signal weapon_changed(weapon_id: StringName, display_name: String, weapon_data: Dictionary)
signal weapon_fired(weapon_id: StringName, weapon_data: Dictionary)
signal weapon_energy_failed(weapon_id: StringName, required_energy: float, available_energy: float)

const WEAPON_IDS: Array[StringName] = [&"vector_bolt", &"positron_beam", &"gravity_wave_beam", &"chronal_refraction_beam"]
const WEAPON_NAMES := {
	&"vector_bolt": "Vector Bolt",
	&"positron_beam": "Positron Beam",
	&"gravity_wave_beam": "Gravity Wave Beam",
	&"chronal_refraction_beam": "Chronal Refraction Beam",
}

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
@export var positron_energy_per_second: float = 34.0
@export var gravity_wave_energy_per_second: float = 22.0
@export var chronal_energy_per_second: float = 30.0
@export var minimum_beam_tick_cost: float = 2.2

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

@export_group("Chronal Refraction Beam")
@export var chronal_slow_multiplier: float = 0.46
@export var chronal_slow_duration: float = 0.52
@export var chronal_refraction_damage_per_second: float = 30.0
@export var chronal_delayed_impulse: float = 280.0
@export var chronal_delay_seconds: float = 0.36
@export var chronal_zone_interval: float = 0.42

@export_group("Visuals")
@export var vector_bolt_color: Color = Color(0.34, 1.0, 0.86, 1.0)
@export var positron_color: Color = Color(1.0, 0.72, 0.28, 1.0)
@export var gravity_wave_color: Color = Color(0.3, 0.72, 1.0, 1.0)
@export var chronal_color: Color = Color(0.74, 0.36, 1.0, 1.0)
@export var beam_alpha_cap: float = 0.72
@export var beam_pulse_speed: float = 10.0

@onready var _beam_root: Node2D = get_node_or_null("BeamRoot") as Node2D
@onready var _beam_glow: Line2D = get_node_or_null("BeamRoot/BeamGlow") as Line2D
@onready var _beam_core: Line2D = get_node_or_null("BeamRoot/BeamCore") as Line2D
@onready var _impact_ring: Line2D = get_node_or_null("BeamRoot/ImpactRing") as Line2D

var _player: Node2D = null
var _energy_component: Node = null
var _powerup_inventory: Node = null
var _query_shape := RectangleShape2D.new()
var _query_params := PhysicsShapeQueryParameters2D.new()
var _active_weapon_id: StringName = &"vector_bolt"
var _beam_active := false
var _beam_heat := 0.0
var _last_switch_time := -999.0
var _last_positron_scar_time := -999.0
var _last_wave_resonance_time := -999.0
var _last_chronal_zone_time := -999.0


func _ready() -> void:
	add_to_group("weapon_system")
	_resolve_player()
	_configure_query()
	_ensure_visual_nodes()
	select_weapon(selected_weapon_index)
	set_process_unhandled_input(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _is_gameplay_blocked():
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
	if not enable_switch_hotkeys or _is_gameplay_blocked():
		return

	if _input_pressed(event, &"weapon_next", KEY_TAB):
		select_next_weapon()
		get_viewport().set_input_as_handled()
	elif _input_pressed(event, &"weapon_previous", KEY_BACKTAB):
		select_previous_weapon()
		get_viewport().set_input_as_handled()


func try_primary_fire() -> bool:
	if not _is_beam_weapon(_active_weapon_id):
		return false
	return true


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
	return {
		"weapon_id": _active_weapon_id,
		"display_name": _display_name(_active_weapon_id),
		"index": selected_weapon_index,
		"count": WEAPON_IDS.size(),
		"beam_active": _beam_active,
		"energy": energy,
		"max_energy": max_energy,
		"energy_percent": energy / maxf(max_energy, 1.0),
		"cost_per_second": cost,
		"color": _weapon_color(_active_weapon_id),
	}


func _fire_selected_beam(delta: float) -> void:
	_resolve_player()
	if _player == null or not is_instance_valid(_player):
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
	})


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
	var damage := gravity_wave_damage_per_second * delta

	for target in hits:
		if target == null or not is_instance_valid(target):
			continue

		var target_2d := target as Node2D
		if target_2d == null:
			continue

		var offset := target_2d.global_position - origin
		var along := clampf(offset.dot(direction) / maxf(beam_range, 1.0), 0.0, 1.0)
		var lateral := offset - direction * offset.dot(direction)
		var lateral_dir := lateral.normalized()
		if lateral_dir == Vector2.ZERO:
			lateral_dir = direction.orthogonal()
		var bend_dir := (direction * 0.66 + lateral_dir * 0.34).normalized()
		var multiplier := gravity_wave_projectile_force_multiplier if target.is_in_group("enemy_projectiles") else 1.0

		CombatStatus.add_velocity(target_2d, bend_dir * force * multiplier * lerpf(1.0, 0.42, along))

		if target.has_method("take_damage") and _is_hostile_target(target):
			target.call("take_damage", damage)

	_stamp_gravity_wave_resonance(origin, direction)


func _apply_chronal_refraction_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
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

		CombatStatus.apply_local_time_scale(target_2d, slow, duration)
		target_2d.set_meta(&"chronal_refraction_delay", chronal_delay_seconds)
		target_2d.set_meta(&"chronal_phantom_position", target_2d.global_position - _body_velocity(target_2d) * chronal_delay_seconds)

		if target_2d.has_method("take_damage") and _is_hostile_target(target_2d):
			target_2d.call("take_damage", damage)

		_spawn_chronal_phantom(target_2d)
		_apply_delayed_chronal_chain(target_2d, impulse, damage * 0.8, chronal_delay_seconds)

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
		GravityResonanceManager.ZoneType.SLIPSTREAM,
		0.52,
		1.5
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
	if target.has_method("take_damage") and _is_hostile_target(target):
		target.call("take_damage", damage)


func _spawn_chronal_phantom(target: Node2D) -> void:
	var root := get_tree().current_scene
	if root == null or target == null:
		return
	var phantom_position: Vector2 = target.get_meta(&"chronal_phantom_position", target.global_position)
	var line := Line2D.new()
	line.name = "ChronalPhantomTrace"
	line.antialiased = true
	line.width = 2.0
	line.default_color = Color(chronal_color.r, chronal_color.g, chronal_color.b, 0.42)
	line.points = PackedVector2Array([phantom_position, target.global_position])
	line.top_level = true
	line.z_index = 34
	root.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.32)
	tween.tween_callback(line.queue_free)


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
		var collider := collider_value as Node
		if collider == null:
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
	var safe_alpha := minf(beam_alpha_cap, Settings.flash_alpha(beam_alpha_cap) if Settings != null and Settings.has_method("flash_alpha") else beam_alpha_cap)
	var visual_range := _visual_range_from_hits(origin, direction, hits)

	_beam_root.visible = true
	_beam_root.global_position = origin
	_beam_root.rotation = direction.angle()

	_beam_glow.points = PackedVector2Array([Vector2.ZERO, Vector2(visual_range, 0.0)])
	_beam_glow.width = width * 0.78
	_beam_glow.default_color = Color(color.r, color.g, color.b, safe_alpha * 0.24 * pulse)

	_beam_core.points = PackedVector2Array([Vector2.ZERO, Vector2(visual_range, 0.0)])
	_beam_core.width = maxf(width * 0.18, 6.0)
	_beam_core.default_color = Color(color.r, color.g, color.b, safe_alpha * pulse)

	if _impact_ring != null:
		_impact_ring.position = Vector2(visual_range, 0.0)
		_impact_ring.points = _circle_points(28, maxf(width * 0.18, 12.0))
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
		_impact_ring.width = 2.0
		_beam_root.add_child(_impact_ring)
	_beam_root.visible = false


func _input_pressed(event: InputEvent, action_name: StringName, fallback_key: Key) -> bool:
	if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == fallback_key


func _is_beam_weapon(weapon_id: StringName) -> bool:
	return weapon_id == &"positron_beam" or weapon_id == &"gravity_wave_beam" or weapon_id == &"chronal_refraction_beam"


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
	var pause_menu := get_tree().get_first_node_in_group("PauseMenu")
	if pause_menu != null and pause_menu.has_method("is_gameplay_blocked"):
		return bool(pause_menu.call("is_gameplay_blocked"))
	return get_tree().paused


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
