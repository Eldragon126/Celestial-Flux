extends Node
## Phase-driven visual hooks for trails, glow, shield, and orbit readability.

signal visual_state_changed(state_name: StringName, intensity: float)

@export var player_path: NodePath = ^".."
@export_group("Phase Aura")
@export var enable_phase_aura: bool = true
@export var aura_radius: float = 48.0
@export var aura_segments: int = 40
@export var aura_width: float = 2.2
@export var inner_aura_radius: float = 28.0
@export var wing_length: float = 72.0
@export var wing_width: float = 1.6
@export var speed_glint_threshold: float = 0.42

var _player: Node2D = null
var _thrusters: Node = null
var _shield: Node = null
var _aura_root: Node2D = null
var _phase_ring: Line2D = null
var _inner_ring: Line2D = null
var _left_wing: Line2D = null
var _right_wing: Line2D = null
var _current_state: StringName = &"stable"
var _intensity: float = 0.0
var _pulse_time: float = 0.0
var _speed_ratio: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D
	if _player != null:
		_thrusters = _player.get_node_or_null("PlayerThrusterTrails")
		_shield = _player.get_node_or_null("Shield")
		_ensure_phase_aura()

	if RunProgress != null and not RunProgress.phase_changed.is_connected(_on_phase_changed):
		RunProgress.phase_changed.connect(_on_phase_changed)
	if RunProgress != null:
		_apply_phase(RunProgress.phase)
	set_process(true)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _thrusters == null:
		_thrusters = _player.get_node_or_null("PlayerThrusterTrails")
	if _shield == null:
		_shield = _player.get_node_or_null("Shield")
	_pulse_time += delta
	_update_speed_ratio()
	_update_phase_aura()


func _on_phase_changed(_old: RunProgress.Phase, new_phase: RunProgress.Phase) -> void:
	_apply_phase(new_phase)


func _apply_phase(phase: RunProgress.Phase) -> void:
	match phase:
		RunProgress.Phase.RUPTURE:
			_set_visual_state(&"rupture", 0.85)
		RunProgress.Phase.MUSIC_FINALE:
			_set_visual_state(&"finale", 1.0)
		RunProgress.Phase.LATE_GAME:
			_set_visual_state(&"late", 0.65)
		RunProgress.Phase.BOSS_ARC:
			_set_visual_state(&"boss", 0.5)
		RunProgress.Phase.CREDITS:
			_set_visual_state(&"calm", 0.0)
		_:
			_set_visual_state(&"stable", 0.25)


func _set_visual_state(state_name: StringName, intensity: float) -> void:
	_current_state = state_name
	_intensity = clampf(intensity, 0.0, 1.0)
	_apply_thruster_mod()
	_apply_shield_mod()
	visual_state_changed.emit(_current_state, _intensity)


func _apply_thruster_mod() -> void:
	if _thrusters == null:
		return
	var color := _state_color(_current_state)
	var boost := 1.0 + _intensity * 0.28
	_thrusters.modulate = Color(
		lerpf(boost, color.r + 0.18, _intensity * 0.38),
		lerpf(boost, color.g + 0.18, _intensity * 0.38),
		lerpf(boost, color.b + 0.24, _intensity * 0.45),
		1.0
	)


func _apply_shield_mod() -> void:
	if _shield == null:
		return
	if _shield.get("shader_time_parameter") == null:
		return
	# Shield shader time is driven internally; modulate for phase read.
	var color := _state_color(_current_state)
	_shield.modulate = Color(
		lerpf(1.0, color.r + 0.2, _intensity * 0.22),
		lerpf(1.0, color.g + 0.2, _intensity * 0.22),
		lerpf(1.0, color.b + 0.32, _intensity * 0.3),
		1.0
	)


func get_visual_state() -> StringName:
	return _current_state


func _ensure_phase_aura() -> void:
	if not enable_phase_aura or _player == null:
		return
	if _aura_root != null and is_instance_valid(_aura_root):
		return
	_aura_root = Node2D.new()
	_aura_root.name = "VectorPhaseAura"
	_aura_root.z_index = -1
	_player.add_child(_aura_root)

	_phase_ring = _make_line("PhaseOuterRing", true, aura_width)
	_inner_ring = _make_line("PhaseInnerRing", true, aura_width * 0.65)
	_left_wing = _make_line("LeftVectorWing", false, wing_width)
	_right_wing = _make_line("RightVectorWing", false, wing_width)


func _make_line(node_name: String, closed: bool, width: float) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.closed = closed
	line.antialiased = true
	line.width = width
	line.visible = false
	_aura_root.add_child(line)
	return line


func _update_phase_aura() -> void:
	if not enable_phase_aura:
		return
	_ensure_phase_aura()
	if _aura_root == null:
		return
	var visual_energy := clampf(maxf(_intensity, _speed_ratio * 0.42), 0.0, 1.0)
	var visible := visual_energy > 0.035
	_aura_root.visible = visible
	if not visible:
		return

	var pulse := 0.5 + 0.5 * sin(_pulse_time * lerpf(3.2, 7.6, visual_energy))
	var state_color := _state_color(_current_state)
	var speed_color := Color(0.32, 1.0, 0.86, 1.0)
	var color := state_color.lerp(speed_color, clampf((_speed_ratio - speed_glint_threshold) / 0.8, 0.0, 0.45))
	var outer_radius := aura_radius * lerpf(0.9, 1.22, visual_energy) + pulse * 3.5
	var inner_radius := inner_aura_radius * lerpf(0.88, 1.15, visual_energy)

	if _phase_ring != null:
		_phase_ring.points = _ring_points(outer_radius, aura_segments, pulse)
		_phase_ring.width = aura_width * lerpf(0.82, 1.34, visual_energy)
		_phase_ring.default_color = _safe_color(color, lerpf(0.08, 0.32, visual_energy))
		_phase_ring.visible = true
	if _inner_ring != null:
		_inner_ring.points = _ring_points(inner_radius, maxi(18, int(aura_segments / 2)), 1.0 - pulse)
		_inner_ring.width = aura_width * 0.58
		_inner_ring.default_color = _safe_color(color.lerp(Color.WHITE, 0.32), lerpf(0.05, 0.18, visual_energy))
		_inner_ring.visible = true
	_update_vector_wing(_left_wing, -1.0, color, visual_energy, pulse)
	_update_vector_wing(_right_wing, 1.0, color, visual_energy, 1.0 - pulse)


func _update_vector_wing(line: Line2D, side: float, color: Color, visual_energy: float, pulse: float) -> void:
	if line == null:
		return
	var length := wing_length * lerpf(0.72, 1.28, visual_energy)
	var spread := lerpf(16.0, 28.0, visual_energy) + pulse * 4.0
	line.points = PackedVector2Array([
		Vector2(-12.0, side * 6.0),
		Vector2(-length * 0.48, side * spread),
		Vector2(-length, side * spread * 0.42),
	])
	line.width = wing_width * lerpf(0.8, 1.55, visual_energy)
	line.default_color = _safe_color(color, lerpf(0.04, 0.24, visual_energy))
	line.visible = visual_energy > 0.08


func _update_speed_ratio() -> void:
	if _player == null:
		_speed_ratio = 0.0
		return
	var velocity_value: Variant = _player.get("velocity")
	var max_speed_value: Variant = _player.get("current_max_speed")
	if not (velocity_value is Vector2):
		_speed_ratio = 0.0
		return
	var velocity: Vector2 = velocity_value
	var maximum := float(max_speed_value) if typeof(max_speed_value) == TYPE_FLOAT or typeof(max_speed_value) == TYPE_INT else 1200.0
	_speed_ratio = clampf(velocity.length() / maxf(maximum, 1.0), 0.0, 1.4)


func _state_color(state_name: StringName) -> Color:
	match state_name:
		&"rupture":
			return Color(1.0, 0.24, 0.12, 1.0)
		&"finale":
			return Color(0.76, 0.96, 1.0, 1.0)
		&"late":
			return Color(0.64, 0.42, 1.0, 1.0)
		&"boss":
			return Color(1.0, 0.62, 0.2, 1.0)
		&"calm":
			return Color(0.42, 0.72, 0.86, 1.0)
	return Color(0.32, 1.0, 0.86, 1.0)


func _ring_points(radius: float, segments: int, pulse: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(segments, 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var notch := 1.0 + sin(angle * 4.0 + _pulse_time * 2.5) * 0.018 * pulse
		points.append(Vector2(cos(angle), sin(angle)) * radius * notch)
	return points


func _safe_color(color: Color, alpha: float) -> Color:
	var safe_alpha := alpha
	if Settings != null and Settings.has_method("world_visual_alpha"):
		safe_alpha = Settings.world_visual_alpha(alpha, 0.28)
	elif Settings != null and Settings.has_method("flash_alpha"):
		safe_alpha = minf(Settings.flash_alpha(alpha), 0.28)
	else:
		safe_alpha = minf(alpha, 0.28)
	return Color(color.r, color.g, color.b, safe_alpha)
