extends Node2D
class_name PersonalGravityFlipComponent

signal gravity_flip_changed(mode: int, polarity: int)

enum FlipMode {
	POLARITY,
	ORBIT,
	ANCHOR,
	AXIS,
}

@export var enabled: bool = false
@export var allow_player_input: bool = true
@export var input_action: StringName = &"gravity_flip"
@export var fallback_key: Key = KEY_F
@export var flip_cooldown: float = 0.18
@export var gravity_constant_multiplier: float = 1.0
@export var repulsion_compensation_multiplier: float = 2.08
@export var orbit_tangent_bias: float = 420.0
@export var anchor_pull_strength: float = 780.0
@export var axis_flip_strength: float = 620.0
@export var max_gravity_sources: int = 4
@export var pull_radius: float = 1800.0
@export var min_distance: float = 50.0
@export var visual_radius: float = 58.0
@export_range(0.0, 0.5, 0.01) var visual_alpha: float = 0.26

var mode: FlipMode = FlipMode.POLARITY
var polarity: int = 1
var orbit_direction: int = 1
var axis_direction: int = 1
var locked_polarity: bool = false

var _player: CharacterBody2D = null
var _sources: Array[Node2D] = []
var _last_flip_time: float = -999.0
var _ring: Line2D = null
var _state_label: Label = null


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	set_physics_process(true)
	set_process(true)
	_build_visuals()


func configure_from_rift(config) -> void:
	if config == null:
		set_enabled(false)
		return
	enabled = true
	mode = config.gravity_flip_mode as FlipMode
	locked_polarity = config.inverted_orbit_for_player and not config.enable_personal_gravity_flip
	if config.inverted_orbit_for_player:
		polarity = -1
		orbit_direction = -1
	else:
		polarity = 1
		orbit_direction = 1
	allow_player_input = config.enable_personal_gravity_flip
	gravity_flip_changed.emit(mode, polarity)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		locked_polarity = false
		polarity = 1
		orbit_direction = 1
		axis_direction = 1
	gravity_flip_changed.emit(mode, polarity)


func _process(_delta: float) -> void:
	_update_visuals()


func _physics_process(delta: float) -> void:
	if not enabled or _player == null or not is_instance_valid(_player):
		return
	if allow_player_input and _flip_pressed():
		_try_flip()
	match mode:
		FlipMode.POLARITY:
			_apply_polarity(delta)
		FlipMode.ORBIT:
			_apply_orbit_bias(delta)
		FlipMode.ANCHOR:
			_apply_anchor_flip(delta)
		FlipMode.AXIS:
			_apply_axis_flip(delta)


func _try_flip() -> void:
	var now := _now_seconds()
	if now - _last_flip_time < flip_cooldown:
		return
	_last_flip_time = now
	if mode == FlipMode.ORBIT:
		orbit_direction *= -1
	elif mode == FlipMode.AXIS:
		axis_direction *= -1
	elif mode == FlipMode.ANCHOR:
		orbit_direction *= -1
	elif not locked_polarity:
		polarity *= -1
	_player.set_meta(&"personal_gravity_flip_polarity", polarity)
	_player.set_meta(&"personal_gravity_flip_mode", mode)
	gravity_flip_changed.emit(mode, polarity)


func _flip_pressed() -> bool:
	if InputMap.has_action(input_action) and Input.is_action_just_pressed(input_action):
		return true
	return Input.is_key_pressed(fallback_key) and _now_seconds() - _last_flip_time >= flip_cooldown


func _apply_polarity(delta: float) -> void:
	var gravity := _sample_player_gravity()
	if polarity >= 0 or gravity.length_squared() <= 0.001:
		return
	_player.velocity += -gravity * repulsion_compensation_multiplier * gravity_constant_multiplier * delta


func _apply_orbit_bias(delta: float) -> void:
	var source := _nearest_source()
	if source == null:
		return
	var radial := _player.global_position - source.global_position
	if radial.length_squared() <= 0.001:
		return
	var tangent := radial.normalized().orthogonal() * float(orbit_direction)
	_player.velocity += tangent * orbit_tangent_bias * delta


func _apply_anchor_flip(delta: float) -> void:
	_refresh_sources()
	if _sources.is_empty():
		return
	var index := 0 if orbit_direction > 0 or _sources.size() == 1 else mini(1, _sources.size() - 1)
	var source := _sources[index]
	if source == null or not is_instance_valid(source):
		return
	var offset := source.global_position - _player.global_position
	if offset.length_squared() <= 0.001:
		return
	_player.velocity += offset.normalized() * anchor_pull_strength * delta


func _apply_axis_flip(delta: float) -> void:
	var axis := Vector2(0.0, float(axis_direction))
	_player.velocity += axis * axis_flip_strength * delta


func _sample_player_gravity() -> Vector2:
	_refresh_sources()
	var total := Vector2.ZERO
	var gravity_constant := float(_player.get("gravity_constant") or 400.0)
	var per_source_cap := float(_player.get("max_gravity_acceleration_per_source") or 3600.0)
	var total_cap := float(_player.get("max_total_gravity_acceleration") or 7200.0)
	for source in _sources:
		if source == null or not is_instance_valid(source):
			continue
		var offset := source.global_position - _player.global_position
		var raw_distance := offset.length()
		if raw_distance <= 0.001 or (pull_radius > 0.0 and raw_distance > pull_radius):
			continue
		var mass_value: Variant = source.get("mass")
		var source_mass := float(mass_value) if mass_value is float or mass_value is int else 100.0
		var distance := maxf(raw_distance, min_distance)
		var contribution := offset / raw_distance * gravity_constant * source_mass / (distance * distance)
		total = (total + contribution.limit_length(per_source_cap)).limit_length(total_cap)
	return total


func _nearest_source() -> Node2D:
	_refresh_sources()
	return _sources[0] if not _sources.is_empty() else null


func _refresh_sources() -> void:
	_sources.clear()
	if _player == null:
		return
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(_player.global_position, _sources, max_gravity_sources, pull_radius, _player)
		return
	var seen := {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var source := node as Node2D
			if source == null or source == _player or not is_instance_valid(source) or source.is_queued_for_deletion():
				continue
			var id := source.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_sources.append(source)
	_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)
	if _sources.size() > max_gravity_sources:
		_sources.resize(max_gravity_sources)


func _build_visuals() -> void:
	_ring = Line2D.new()
	_ring.name = "GravityFlipStateRing"
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 2.0
	_ring.points = _circle_points(48, visual_radius)
	_ring.z_index = 35
	add_child(_ring)

	_state_label = Label.new()
	_state_label.name = "GravityFlipStateLabel"
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", 10)
	_state_label.position = Vector2(-72.0, -visual_radius - 24.0)
	_state_label.size = Vector2(144.0, 22.0)
	add_child(_state_label)


func _update_visuals() -> void:
	if _ring == null or _state_label == null:
		return
	_ring.visible = enabled
	_state_label.visible = enabled
	if not enabled:
		return
	var color := Color(0.32, 1.0, 0.82, visual_alpha)
	if polarity < 0 or orbit_direction < 0:
		color = Color(1.0, 0.42, 0.2, visual_alpha)
	if Settings != null and Settings.has_method("world_visual_alpha"):
		color.a = Settings.world_visual_alpha(color.a, visual_alpha)
	_ring.default_color = color
	_ring.rotation += get_process_delta_time() * (1.2 * float(maxi(abs(orbit_direction), 1)))
	_state_label.modulate = Color(color.r, color.g, color.b, 0.82)
	_state_label.text = _mode_label()


func _mode_label() -> String:
	match mode:
		FlipMode.ORBIT:
			return "ORBIT %s" % ("CW" if orbit_direction > 0 else "CCW")
		FlipMode.ANCHOR:
			return "ANCHOR %d" % (1 if orbit_direction > 0 else 2)
		FlipMode.AXIS:
			return "AXIS %s" % ("DOWN" if axis_direction > 0 else "UP")
	return "PULL" if polarity > 0 else "PUSH"


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 8)):
		var angle := TAU * float(i) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001
