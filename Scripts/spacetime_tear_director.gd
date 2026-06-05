extends Node2D
class_name SpacetimeTearDirector

signal spacetime_tear_opened(data: Dictionary)
signal spacetime_tear_enemy_spawned(enemy: Node, data: Dictionary)

const BASE_ENEMY_SCENE = preload("res://Nodes/base_enemy.tscn")
const BASE_SHOOTER_SCENE = preload("res://Nodes/base_shooter_enemy.tscn")
const CHAOS_WISP_SCENE = preload("res://Nodes/chaos_wisp.tscn")
const SEEKER_FRAGMENT_SCENE = preload("res://Nodes/seeker_fragment.tscn")

@export var enabled: bool = true
@export var min_wave_for_tears: int = 12
@export var scar_intensity_threshold: float = 0.58
@export var intensified_scar_threshold_bonus: float = -0.08
@export var spawn_cooldown: float = 15.0
@export var max_active_tears: int = 2
@export var max_alive_tear_enemies: int = 4
@export var max_enemies_per_tear: int = 2
@export var tear_lifetime: float = 3.6
@export var first_spawn_delay: float = 0.75
@export var spawn_interval: float = 1.1
@export var min_player_distance: float = 320.0
@export var spawn_offset_radius: float = 72.0
@export var simple_polygon_visuals: bool = true
@export var ring_segments: int = 28
@export var visual_radius: float = 112.0
@export var visual_radius_cap: float = 180.0

var _player: Node2D = null
var _scar_manager: Node = null
var _time_manager: Node = null
var _wave_director: Node = null
var _tears: Array[Dictionary] = []
var _last_spawn_time: float = -999.0
var _time_tear_intensity: float = 0.0
var _spawn_counter: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("spacetime_tear_director")
	_rng.randomize()
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		return
	_resolve_soft_references()
	_update_tears(delta)


func _bootstrap() -> void:
	_resolve_references()
	_connect_sources()


func _resolve_references() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_scar_manager = get_tree().get_first_node_in_group("gravity_scar_manager")
	if root != null:
		_time_manager = root.find_child("TimeDilationManager", true, false)
		_wave_director = root.find_child("WaveDirector", true, false)


func _resolve_soft_references() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _wave_director == null or not is_instance_valid(_wave_director):
		var root := get_tree().current_scene
		if root != null:
			_wave_director = root.find_child("WaveDirector", true, false)


func _connect_sources() -> void:
	_connect_once(_scar_manager, &"gravity_scar_created", Callable(self, "_on_gravity_scar_created"))
	_connect_once(_scar_manager, &"gravity_scar_intensified", Callable(self, "_on_gravity_scar_intensified"))
	_connect_once(_time_manager, &"time_tear_intensity_changed", Callable(self, "_on_time_tear_intensity_changed"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_time_tear_intensity_changed(intensity: float) -> void:
	_time_tear_intensity = clampf(intensity, 0.0, 1.0)


func _on_gravity_scar_created(scar_data: Dictionary) -> void:
	_try_open_tear(scar_data, false)


func _on_gravity_scar_intensified(scar_data: Dictionary) -> void:
	_try_open_tear(scar_data, true)


func _try_open_tear(scar_data: Dictionary, intensified: bool) -> void:
	if not enabled or _current_wave() < min_wave_for_tears:
		return

	var type_name := StringName(scar_data.get("type_name", &"curvature"))
	var intensity := _scar_spawn_intensity(scar_data, intensified)
	if intensity < _threshold_for_scar(type_name, intensified):
		return
	if not _scar_type_can_open_tear(type_name, intensity):
		return
	if _now_seconds() - _last_spawn_time < spawn_cooldown:
		return

	var position: Vector2 = scar_data.get("position", global_position)
	position = _push_away_from_player(position)
	if _tears.size() >= max_active_tears:
		_remove_oldest_tear()
	_open_tear(position, intensity, type_name)
	_last_spawn_time = _now_seconds()


func _scar_spawn_intensity(scar_data: Dictionary, intensified: bool) -> float:
	var intensity := clampf(float(scar_data.get("intensity", 0.0)), 0.0, 1.0)
	if intensified:
		intensity += 0.08
	intensity += _time_tear_intensity * 0.18
	return clampf(intensity, 0.0, 1.0)


func _threshold_for_scar(type_name: StringName, intensified: bool) -> float:
	var threshold := scar_intensity_threshold
	if type_name == &"temporal_rip":
		threshold -= 0.14
	elif type_name == &"harmonic_fracture":
		threshold -= 0.06
	if intensified:
		threshold += intensified_scar_threshold_bonus
	return clampf(threshold, 0.2, 0.96)


func _scar_type_can_open_tear(type_name: StringName, intensity: float) -> bool:
	if type_name == &"temporal_rip" or type_name == &"harmonic_fracture":
		return true
	if type_name == &"inversion_wake" and intensity >= 0.72:
		return true
	return intensity >= 0.86


func _open_tear(position: Vector2, intensity: float, type_name: StringName) -> void:
	var visual := _create_tear_visual(position, intensity, type_name)
	var max_spawns := clampi(int(round(lerpf(1.0, float(max_enemies_per_tear), intensity))), 1, max_enemies_per_tear)
	_tears.append({
		"visual": visual,
		"position": position,
		"intensity": intensity,
		"type_name": type_name,
		"age": 0.0,
		"next_spawn": first_spawn_delay,
		"spawned": 0,
		"max_spawns": max_spawns,
	})
	spacetime_tear_opened.emit({
		"position": position,
		"intensity": intensity,
		"type_name": type_name,
		"max_spawns": max_spawns,
	})


func _update_tears(delta: float) -> void:
	for i in range(_tears.size() - 1, -1, -1):
		var entry := _tears[i]
		var age := float(entry.get("age", 0.0)) + delta
		var lifetime := maxf(tear_lifetime * lerpf(0.85, 1.3, float(entry.get("intensity", 0.0))), 0.2)
		_update_tear_visual(entry, age, lifetime, delta)

		var next_spawn := float(entry.get("next_spawn", first_spawn_delay)) - delta
		var spawned := int(entry.get("spawned", 0))
		var max_spawns := int(entry.get("max_spawns", 1))
		if next_spawn <= 0.0 and spawned < max_spawns:
			if _alive_tear_enemy_count() < max_alive_tear_enemies:
				_spawn_enemy_from_tear(entry)
				spawned += 1
			next_spawn = spawn_interval

		entry["age"] = age
		entry["next_spawn"] = next_spawn
		entry["spawned"] = spawned
		_tears[i] = entry

		if age >= lifetime:
			_free_tear(entry)
			_tears.remove_at(i)


func _spawn_enemy_from_tear(entry: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var position: Vector2 = entry.get("position", global_position)
	var intensity := clampf(float(entry.get("intensity", 0.5)), 0.0, 1.0)
	var scene := _pick_enemy_scene(_current_wave(), intensity)
	var enemy := scene.instantiate()
	_spawn_counter += 1
	enemy.name = "SpacetimeTearEnemy%d" % _spawn_counter
	enemy.add_to_group("enemies")
	enemy.add_to_group("spacetime_tear_enemy")
	enemy.add_to_group("wave_enemy")

	var enemy_2d := enemy as Node2D
	if enemy_2d != null:
		var offset := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(18.0, spawn_offset_radius)
		enemy_2d.global_position = position + offset

	root.add_child(enemy)

	if enemy_2d != null:
		_launch_enemy(enemy_2d, intensity)

	_register_with_wave_director(enemy)
	spacetime_tear_enemy_spawned.emit(enemy, {
		"position": position,
		"intensity": intensity,
	})


func _pick_enemy_scene(wave: int, intensity: float) -> PackedScene:
	if intensity > 0.82 and wave >= 10:
		return CHAOS_WISP_SCENE
	if wave >= 8 and _rng.randf() < 0.45:
		return SEEKER_FRAGMENT_SCENE
	if wave >= 6 and _rng.randf() < 0.34:
		return BASE_SHOOTER_SCENE
	return BASE_ENEMY_SCENE


func _launch_enemy(enemy: Node2D, intensity: float) -> void:
	var direction := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	if _player != null and is_instance_valid(_player):
		direction = (_player.global_position - enemy.global_position).normalized()
	var launch_velocity := direction * lerpf(240.0, 680.0, intensity)
	if enemy is RigidBody2D:
		(enemy as RigidBody2D).linear_velocity = launch_velocity
	elif enemy.get("velocity") is Vector2:
		enemy.set("velocity", launch_velocity)


func _register_with_wave_director(enemy: Node) -> void:
	if _wave_director == null or not is_instance_valid(_wave_director):
		return
	if _wave_director.has_method("register_external_enemy"):
		_wave_director.call("register_external_enemy", enemy)


func _create_tear_visual(position: Vector2, intensity: float, type_name: StringName) -> Dictionary:
	var root := Node2D.new()
	root.name = "SpacetimeTear"
	root.global_position = position
	root.z_index = 32
	add_child(root)

	var color := _color_for_type(type_name)
	var radius := _visual_radius(visual_radius * lerpf(0.84, 1.32, intensity))

	var core := Polygon2D.new()
	core.name = "TearCore"
	core.color = _safe_color(color, 0.08)
	core.polygon = _soft_circle_points(_visual_segments(12), radius * 0.5, intensity)
	root.add_child(core)

	var ring := Line2D.new()
	ring.name = "TearBoundary"
	ring.closed = true
	ring.antialiased = true
	ring.width = lerpf(1.2, 3.0, intensity)
	ring.default_color = _safe_color(color, 0.24)
	ring.points = _circle_points(_visual_segments(ring_segments), radius)
	root.add_child(ring)

	var seam := Line2D.new()
	seam.name = "TearSeam"
	seam.antialiased = true
	seam.width = lerpf(1.8, 3.6, intensity)
	seam.default_color = _safe_color(Color.WHITE, 0.32)
	seam.points = PackedVector2Array([
		Vector2(-radius * 0.2, -radius * 0.9),
		Vector2(radius * 0.12, -radius * 0.42),
		Vector2(-radius * 0.08, 0.0),
		Vector2(radius * 0.18, radius * 0.48),
		Vector2(-radius * 0.12, radius * 0.92),
	])
	root.add_child(seam)

	return {
		"root": root,
		"ring": ring,
		"seam": seam,
		"core": core,
		"radius": radius,
		"spin": _rng.randf_range(-0.55, 0.55),
	}


func _update_tear_visual(entry: Dictionary, age: float, lifetime: float, delta: float) -> void:
	var visual_value: Variant = entry.get("visual", {})
	if typeof(visual_value) != TYPE_DICTIONARY:
		return
	var visual: Dictionary = visual_value
	var root := visual.get("root") as Node2D
	if root == null or not is_instance_valid(root):
		return

	var intensity := clampf(float(entry.get("intensity", 0.5)), 0.0, 1.0)
	var t := clampf(age / maxf(lifetime, 0.1), 0.0, 1.0)
	var pulse := 1.0 + sin(age * 8.0) * 0.035 * intensity
	root.rotation += float(visual.get("spin", 0.0)) * delta
	root.scale = Vector2.ONE * pulse
	root.modulate.a = pow(1.0 - t, 0.82)

	var ring := visual.get("ring") as Line2D
	if ring != null and is_instance_valid(ring):
		ring.width = lerpf(1.0, 3.2, intensity) * lerpf(1.0, 0.38, t)


func _free_tear(entry: Dictionary) -> void:
	var visual_value: Variant = entry.get("visual", {})
	if typeof(visual_value) != TYPE_DICTIONARY:
		return
	var visual: Dictionary = visual_value
	var root := visual.get("root") as Node
	if root != null and is_instance_valid(root):
		root.queue_free()


func _remove_oldest_tear() -> void:
	if _tears.is_empty():
		return
	var oldest := _tears.pop_front() as Dictionary
	_free_tear(oldest)


func _alive_tear_enemy_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("spacetime_tear_enemy"):
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count


func _push_away_from_player(position: Vector2) -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return position
	var offset := position - _player.global_position
	if offset.length() >= min_player_distance:
		return position
	if offset.length_squared() <= 0.001:
		offset = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	return _player.global_position + offset.normalized() * min_player_distance


func _current_wave() -> int:
	if _wave_director != null and is_instance_valid(_wave_director) and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return 1


func _color_for_type(type_name: StringName) -> Color:
	match type_name:
		&"temporal_rip":
			return Color(0.55, 0.66, 1.0, 1.0)
		&"harmonic_fracture":
			return Color(1.0, 0.82, 0.24, 1.0)
		&"inversion_wake":
			return Color(1.0, 0.28, 0.16, 1.0)
	return Color(0.2, 0.88, 1.0, 1.0)


func _safe_color(color: Color, alpha_cap: float) -> Color:
	var alpha := minf(color.a, alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 3)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _soft_circle_points(count: int, radius: float, intensity: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 3)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		var wobble := 1.0 + sin(angle * 3.0) * 0.08 * intensity + cos(angle * 7.0) * 0.04
		points.append(Vector2(cos(angle), sin(angle)) * radius * wobble)
	return points


func _visual_radius(radius: float) -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(radius, visual_radius_cap)
	return clampf(radius, 0.0, maxf(visual_radius_cap, 1.0))


func _visual_segments(requested: int, hard_cap: int = 32) -> int:
	var cap_limit := 16 if simple_polygon_visuals else 32
	var local_cap := mini(hard_cap, cap_limit)
	if Settings != null and Settings.has_method("world_polygon_segments"):
		return Settings.world_polygon_segments(requested, local_cap)
	return clampi(requested, 3, local_cap)


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
