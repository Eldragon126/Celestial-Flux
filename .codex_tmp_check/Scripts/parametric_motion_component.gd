extends Node2D
class_name ParametricMotionComponent

## Parametric Motion System for ORBITRON: VECTORFALL
## Supports circles, spirals, ellipses, figure eights, rose curves, lissajous curves, and custom equations
## Movement itself teaches calculus intuitively through velocity, speed, and acceleration visualization

enum ParametricType {
	CIRCLE,
	ELLIPSE,
	SPIRAL,
	FIGURE_EIGHT,
	ROSE_CURVE,
	LISSAJOUS,
	CUSTOM
}

@export var motion_type: ParametricType = ParametricType.CIRCLE
@export var center_offset: Vector2 = Vector2.ZERO
@export var frequency: Vector2 = Vector2(1.0, 1.0)
@export var amplitude: Vector2 = Vector2(100.0, 100.0)
@export var phase_offset: float = 0.0
@export var local_time_scale: float = 1.0
@export var enable_velocity_output: bool = true
@export var enable_acceleration_output: bool = false
@export var show_debug_trail: bool = false
@export var debug_trail_length: int = 60

@export_group("Dance Windows")
@export var beat_count: int = 4
@export var beat_window_width: float = 0.12
@export var emit_rhythm_signals: bool = true

# Rose curve parameter
@export var rose_petals: int = 3

# Custom equation (unused by default, for runtime injection)
var custom_equation: Callable = func(_t: float) -> Vector2: return Vector2.ZERO

# Runtime state
var _local_time: float = 0.0
var _previous_position: Vector2 = Vector2.ZERO
var _previous_velocity: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _acceleration: Vector2 = Vector2.ZERO
var _speed: float = 0.0
var _curvature: float = 0.0
var _trail_positions: Array[Vector2] = []
var _last_beat_index: int = -1
var _vulnerability_active: bool = false
var _vulnerability_intensity: float = 0.0

# Signals for motion-based behavior
signal position_updated(new_pos: Vector2, velocity: Vector2, acceleration: Vector2)
signal curvature_changed(curvature: float)
signal motion_phase_changed(phase: float)
signal motion_beat(phase: float, position: Vector2, tangent: Vector2)
signal vulnerability_window_changed(active: bool, intensity: float)

func _ready() -> void:
	_previous_position = _calculate_parametric_position(phase_offset)
	global_position = _previous_position + center_offset
	_trail_positions.clear()
	if show_debug_trail:
		set_process(true)

func _physics_process(delta: float) -> void:
	_local_time += delta * local_time_scale * frequency.x
	
	var t = _local_time + phase_offset
	var new_position = _calculate_parametric_position(t)
	
	# Apply center offset and parent transform
	var final_position = new_position + center_offset
	
	# Calculate derivatives for physics feel
	_calculate_derivatives(delta, new_position)
	
	# Update position
	global_position = final_position
	
	# Emit signals for reactive systems
	position_updated.emit(global_position, _velocity, _acceleration)
	_update_rhythm_state(t)
	
	# Track trail for debugging
	if show_debug_trail:
		_update_trail()

func _calculate_parametric_position(t: float) -> Vector2:
	match motion_type:
		ParametricType.CIRCLE:
			return _circle(t)
		ParametricType.ELLIPSE:
			return _ellipse(t)
		ParametricType.SPIRAL:
			return _spiral(t)
		ParametricType.FIGURE_EIGHT:
			return _figure_eight(t)
		ParametricType.ROSE_CURVE:
			return _rose_curve(t)
		ParametricType.LISSAJOUS:
			return _lissajous(t)
		ParametricType.CUSTOM:
			return custom_equation.call(t) if custom_equation.is_valid() else Vector2.ZERO
	return Vector2.ZERO

func _circle(t: float) -> Vector2:
	var x = amplitude.x * cos(t)
	var y = amplitude.y * sin(t)
	return Vector2(x, y)

func _ellipse(t: float) -> Vector2:
	var x = amplitude.x * cos(frequency.x * t)
	var y = amplitude.y * sin(frequency.y * t)
	return Vector2(x, y)

func _spiral(t: float) -> Vector2:
	var spiral_factor = t * 0.5
	var x = amplitude.x * spiral_factor * cos(t)
	var y = amplitude.y * spiral_factor * sin(t)
	return Vector2(x, y)

func _figure_eight(t: float) -> Vector2:
	# Lemniscate of Gerono
	var x = amplitude.x * sin(t)
	var y = amplitude.y * sin(t) * cos(t)
	return Vector2(x, y)

func _rose_curve(t: float) -> Vector2:
	var k = float(rose_petals)
	var r = amplitude.x * cos(k * t)
	var x = r * cos(t)
	var y = r * sin(t)
	return Vector2(x, y)

func _lissajous(t: float) -> Vector2:
	var x = amplitude.x * sin(frequency.x * t)
	var y = amplitude.y * sin(frequency.y * t + PI / 2.0)
	return Vector2(x, y)

func _calculate_derivatives(delta: float, current_pos: Vector2) -> void:
	if delta <= 0.0:
		return
	
	# Velocity = dr/dt
	_velocity = (current_pos - _previous_position) / delta
	
	# Speed = |v|
	_speed = _velocity.length()
	
	# Acceleration = dv/dt (simplified finite difference)
	_acceleration = (_velocity - _previous_velocity) / delta
	_previous_velocity = _velocity
	
	# Curvature approximation for motion-based FX
	if _speed > 0.1:
		var tangent = _velocity.normalized()
		var normal = Vector2(-tangent.y, tangent.x)
		_curvature = abs(_acceleration.dot(normal)) / (_speed * _speed + 0.001)
	else:
		_curvature = 0.0
	
	_previous_position = current_pos
	
	# Emit curvature changes for FX systems
	curvature_changed.emit(_curvature)

func _update_rhythm_state(t: float) -> void:
	if not emit_rhythm_signals:
		return

	var phase := fposmod(t, TAU) / TAU
	motion_phase_changed.emit(phase)

	var beats := maxi(beat_count, 1)
	var beat_float := phase * float(beats)
	var beat_index := int(floor(beat_float))
	var beat_phase := fposmod(beat_float, 1.0)
	var distance_to_beat := minf(beat_phase, 1.0 - beat_phase)
	var width := clampf(beat_window_width, 0.01, 0.48)
	_vulnerability_intensity = clampf(1.0 - distance_to_beat / width, 0.0, 1.0)
	var active := _vulnerability_intensity > 0.0

	if beat_index != _last_beat_index and beat_phase < 0.24:
		_last_beat_index = beat_index
		motion_beat.emit(phase, global_position, get_tangent_direction())

	if active != _vulnerability_active:
		_vulnerability_active = active
		vulnerability_window_changed.emit(_vulnerability_active, _vulnerability_intensity)

func _update_trail() -> void:
	_trail_positions.append(global_position)
	if _trail_positions.size() > debug_trail_length:
		_trail_positions.pop_front()

func get_current_velocity() -> Vector2:
	return _velocity

func get_current_speed() -> float:
	return _speed

func get_current_acceleration() -> Vector2:
	return _acceleration

func get_curvature() -> float:
	return _curvature

func get_tangent_direction() -> Vector2:
	if _speed > 0.01:
		return _velocity.normalized()
	return Vector2.RIGHT

func get_normal_direction() -> Vector2:
	var tangent = get_tangent_direction()
	return Vector2(-tangent.y, tangent.x)

func set_motion_type(new_type: ParametricType) -> void:
	motion_type = new_type

func blend_to_motion_type(new_type: ParametricType, blend_duration: float) -> void:
	var tween = create_tween()
	var old_type = motion_type
	tween.tween_method(func(_t): motion_type = new_type, 0.0, 1.0, blend_duration)

func set_frequency(new_freq: Vector2) -> void:
	frequency = new_freq

func set_amplitude(new_amp: Vector2) -> void:
	amplitude = new_amp

func set_phase(phase: float) -> void:
	phase_offset = phase

func reset_time() -> void:
	_local_time = 0.0
	_previous_position = _calculate_parametric_position(phase_offset)
	_previous_velocity = Vector2.ZERO

func get_local_time() -> float:
	return _local_time

func get_predicted_position(ahead_time: float) -> Vector2:
	var future_t = _local_time + ahead_time * local_time_scale * frequency.x + phase_offset
	return _calculate_parametric_position(future_t) + center_offset

func get_predicted_velocity(ahead_time: float) -> Vector2:
	var dt = 0.016
	var pos_now = get_predicted_position(0.0)
	var pos_future = get_predicted_position(ahead_time + dt)
	return (pos_future - pos_now) / dt

func get_rhythm_debug_state() -> Dictionary:
	return {
		"phase": fposmod(_local_time + phase_offset, TAU) / TAU,
		"beat_count": beat_count,
		"vulnerability_active": _vulnerability_active,
		"vulnerability_intensity": _vulnerability_intensity,
		"tangent": get_tangent_direction(),
	}

func draw_debug(gizmo: CanvasItem) -> void:
	if not show_debug_trail or _trail_positions.size() < 2:
		return
	
	for i in range(1, _trail_positions.size()):
		var alpha = float(i) / float(_trail_positions.size())
		gizmo.draw_line(_trail_positions[i - 1], _trail_positions[i], Color(0.0, 0.9, 1.0, alpha * 0.5), 2.0)
	
	# Draw velocity vector
	gizmo.draw_line(global_position, global_position + _velocity * 0.1, Color(0.0, 1.0, 0.5, 1.0), 3.0)
	
	# Draw acceleration vector
	gizmo.draw_line(global_position, global_position + _acceleration * 0.05, Color(1.0, 0.5, 0.0, 1.0), 3.0)
