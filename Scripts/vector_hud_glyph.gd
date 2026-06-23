extends Control
class_name VectorHudGlyph
## Compact code-native HUD icon that reflects live physics state.

@export var glyph_kind: StringName = &"field"
@export var primary_color: Color = Color(0.34, 1.0, 0.86, 1.0)
@export var accent_color: Color = Color(1.0, 0.82, 0.3, 1.0)
@export var warning_color: Color = Color(1.0, 0.2, 0.12, 1.0)
@export_range(1.0, 3.0, 0.1) var line_width: float = 1.6
@export_range(0.0, 1.0, 0.01) var activity: float = 0.0
@export_range(0.0, 1.0, 0.01) var secondary_activity: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(kind: StringName, color: Color, accent: Color = Color(1.0, 0.82, 0.3, 1.0), warning: Color = Color(1.0, 0.2, 0.12, 1.0)) -> void:
	glyph_kind = kind
	primary_color = color
	accent_color = accent
	warning_color = warning
	queue_redraw()


func set_activity(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, activity):
		return
	activity = next
	queue_redraw()


func set_signal(value: float, warning: float = -1.0) -> void:
	var next_activity := clampf(value, 0.0, 1.0)
	var next_warning := secondary_activity if warning < 0.0 else clampf(warning, 0.0, 1.0)
	if is_equal_approx(next_activity, activity) and is_equal_approx(next_warning, secondary_activity):
		return
	activity = next_activity
	secondary_activity = next_warning
	queue_redraw()


func set_palette(color: Color, accent: Color = Color.TRANSPARENT, warning: Color = Color.TRANSPARENT) -> void:
	var changed := not _colors_equal(primary_color, color)
	primary_color = color
	if accent.a > 0.0:
		changed = changed or not _colors_equal(accent_color, accent)
		accent_color = accent
	if warning.a > 0.0:
		changed = changed or not _colors_equal(warning_color, warning)
		warning_color = warning
	if changed:
		queue_redraw()


func refresh_readability() -> void:
	queue_redraw()


func _draw() -> void:
	var diameter := minf(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var center := size * 0.5
	var radius := maxf(diameter * 0.42, 4.0)
	var signall = clampf(activity, 0.0, 1.0)
	var alert := clampf(secondary_activity, 0.0, 1.0)
	var color := _readability_color(primary_color).lerp(_readability_color(warning_color), alert * 0.62)
	var accent := _readability_color(accent_color)
	var warning := _readability_color(warning_color)
	var glow = _with_alpha(color, 0.1 + signall * 0.12 + alert * 0.14)
	draw_circle(center, radius * (0.74 + signall * 0.12 + alert * 0.1), glow, false, line_width + 1.4 + alert, true)
	if alert > 0.01:
		draw_polyline(_arc(center, radius * 1.02, -PI * 0.45, PI * 0.45 + alert * PI, 12), _with_alpha(warning, 0.36 + alert * 0.32), line_width, true)

	match glyph_kind:
		&"hull":
			_draw_hull(center, radius, color, warning)
		&"shield":
			_draw_shield(center, radius, color, accent, warning)
		&"energy":
			_draw_energy(center, radius, color, accent)
		&"speed":
			_draw_speed(center, radius, color, accent)
		&"gravity":
			_draw_gravity(center, radius, color, accent, warning)
		&"time":
			_draw_time(center, radius, color, accent)
		&"horizon":
			_draw_horizon(center, radius, color, accent, warning)
		&"chaos":
			_draw_chaos(center, radius, color, accent)
		&"slingshot":
			_draw_slingshot(center, radius, color, accent)
		&"weapon":
			_draw_weapon(center, radius, color, accent)
		&"phase":
			_draw_phase(center, radius, color, accent)
		_:
			_draw_field(center, radius, color, accent)


func _draw_hull(center: Vector2, radius: float, color: Color, warning: Color) -> void:
	var hull_color := color.lerp(warning, activity * 0.42)
	var hull := PackedVector2Array([
		center + Vector2(radius, 0.0),
		center + Vector2(-radius * 0.62, -radius * 0.72),
		center + Vector2(-radius * 0.3, 0.0),
		center + Vector2(-radius * 0.62, radius * 0.72),
		center + Vector2(radius, 0.0),
	])
	draw_polyline(hull, hull_color, line_width, true)
	draw_line(center - Vector2(radius * 0.22, 0.0), center + Vector2(radius * 0.48, 0.0), hull_color, line_width, true)


func _draw_shield(center: Vector2, radius: float, color: Color, accent: Color, warning: Color) -> void:
	draw_polyline(_arc(center, radius, -PI * 0.78, PI * 0.78, 13), color, line_width, true)
	draw_polyline(_arc(center, radius * 0.58, -PI * 0.72, PI * 0.72, 9), _with_alpha(color, 0.62), line_width, true)
	draw_circle(center, 1.5 + activity * 1.2, accent.lerp(warning, secondary_activity), true)


func _draw_energy(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	var bolt := PackedVector2Array([
		center + Vector2(radius * 0.18, -radius),
		center + Vector2(-radius * 0.5, radius * 0.05),
		center + Vector2(-radius * 0.02, radius * 0.05),
		center + Vector2(-radius * 0.2, radius),
		center + Vector2(radius * 0.56, -radius * 0.15),
		center + Vector2(radius * 0.08, -radius * 0.15),
	])
	draw_polyline(bolt, color.lerp(accent, activity * 0.5), line_width + 0.2, true)


func _draw_speed(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	var stretch := 0.8 + activity * 0.42
	var spine_start := center + Vector2(-radius * 0.9, 0.0)
	var spine_end := center + Vector2(radius * stretch, 0.0)
	draw_line(spine_start, spine_end, color, line_width, true)
	for lane in [-0.48, 0.48]:
		var y = radius * lane
		draw_line(center + Vector2(-radius * 0.68, y), center + Vector2(radius * 0.28, y * 0.34), _with_alpha(color, 0.54), line_width, true)
	var chevron := PackedVector2Array([
		spine_end,
		spine_end - Vector2(radius * 0.32, radius * 0.24),
		spine_end - Vector2(radius * 0.18, 0.0),
		spine_end - Vector2(radius * 0.32, -radius * 0.24),
		spine_end,
	])
	draw_polyline(chevron, accent, line_width, true)


func _draw_gravity(center: Vector2, radius: float, color: Color, accent: Color, warning: Color) -> void:
	draw_polyline(_arc(center, radius, -PI * 0.94, PI * 0.94, 16), color, line_width, true)
	draw_polyline(_arc(center, radius * 0.58, PI * 0.12, TAU - PI * 0.12, 14), _with_alpha(color, 0.66), line_width, true)
	var pull_color := accent.lerp(warning, secondary_activity)
	for angle in [-PI * 0.5, PI * 0.16, PI * 0.84]:
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * 0.92
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * (0.28 + activity * 0.12)
		draw_line(outer, inner, pull_color, line_width, true)
	draw_circle(center, 1.7 + activity * 1.7, pull_color, true)


func _draw_field(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	draw_polyline(_arc(center, radius, -PI * 0.92, PI * 0.24, 11), color, line_width, true)
	draw_polyline(_arc(center, radius * 0.62, PI * 0.08, PI * 1.22, 10), _with_alpha(color, 0.72), line_width, true)
	draw_circle(center, 1.7 + activity * 1.2, accent, true)


func _draw_time(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	draw_line(center + Vector2(-radius * 0.62, -radius), center + Vector2(radius * 0.62, -radius), color, line_width, true)
	draw_line(center + Vector2(-radius * 0.62, radius), center + Vector2(radius * 0.62, radius), color, line_width, true)
	draw_line(center + Vector2(-radius * 0.5, -radius * 0.84), center + Vector2(radius * 0.5, radius * 0.84), color, line_width, true)
	draw_line(center + Vector2(radius * 0.5, -radius * 0.84), center + Vector2(-radius * 0.5, radius * 0.84), color, line_width, true)
	draw_circle(center, 1.2 + activity * 1.5, accent, true)


func _draw_horizon(center: Vector2, radius: float, color: Color, accent: Color, warning: Color) -> void:
	var event_color := warning.lerp(accent, 0.28 + activity * 0.34)
	draw_circle(center, radius * (0.22 + activity * 0.08), _with_alpha(event_color, 0.34 + activity * 0.22), true)
	draw_polyline(_arc(center, radius, -PI * 0.1, PI * 1.26, 18), color.lerp(event_color, activity * 0.7), line_width, true)
	draw_polyline(_arc(center, radius * 0.68, PI * 0.86, PI * 2.28, 16), _with_alpha(event_color, 0.74), line_width, true)
	draw_line(center - Vector2(radius * 0.88, radius * 0.18), center + Vector2(radius * 0.88, radius * 0.18), color, line_width, true)


func _draw_chaos(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	var fracture := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.74, -radius * 0.1),
		center + Vector2(radius * 0.18, radius * 0.18),
		center + Vector2(radius * 0.62, radius),
		center + Vector2(-radius * 0.12, radius * 0.42),
		center + Vector2(-radius * 0.72, radius * 0.72),
		center + Vector2(-radius * 0.4, -radius * 0.12),
		center + Vector2(0.0, -radius),
	])
	draw_polyline(fracture, color.lerp(accent, activity * 0.65), line_width, true)


func _draw_slingshot(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	var orbit := _arc(center, radius * 0.82, PI * 0.72, TAU * 1.04, 12)
	draw_polyline(orbit, color, line_width, true)
	var tip := orbit[orbit.size() - 1]
	var angle := TAU * 1.04 + PI * 0.5
	var tangent := Vector2(cos(angle), sin(angle))
	var side := Vector2(-tangent.y, tangent.x)
	draw_line(tip, tip + tangent * radius * 0.62, accent, line_width + activity, true)
	draw_line(tip + tangent * radius * 0.62, tip + tangent * radius * 0.38 + side * radius * 0.2, accent, line_width, true)


func _draw_weapon(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	draw_circle(center, radius * 0.78, _with_alpha(color, 0.78), false, line_width, true)
	draw_line(center - Vector2(radius, 0.0), center - Vector2(radius * 0.34, 0.0), color, line_width, true)
	draw_line(center + Vector2(radius * 0.34, 0.0), center + Vector2(radius, 0.0), color, line_width, true)
	draw_line(center - Vector2(0.0, radius), center - Vector2(0.0, radius * 0.34), color, line_width, true)
	draw_line(center + Vector2(0.0, radius * 0.34), center + Vector2(0.0, radius), color, line_width, true)
	var bolt := PackedVector2Array([
		center + Vector2(radius * 0.1, -radius * 0.52),
		center + Vector2(-radius * 0.3, radius * 0.05),
		center + Vector2(0.0, radius * 0.05),
		center + Vector2(-radius * 0.12, radius * 0.52),
		center + Vector2(radius * 0.34, -radius * 0.08),
	])
	draw_polyline(bolt, accent.lerp(color, activity * 0.4), line_width, true)


func _draw_phase(center: Vector2, radius: float, color: Color, accent: Color) -> void:
	for index in range(3):
		var ring_radius := radius * (1.0 - float(index) * 0.24)
		var start := -PI * 0.65 + float(index) * 0.72
		draw_polyline(_arc(center, ring_radius, start, start + PI * (1.08 + activity * 0.24), 10), color.lerp(accent, float(index) * 0.22), line_width, true)


func _arc(center: Vector2, radius: float, start: float, finish: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(steps, 2)):
		var weight := float(index) / float(maxi(steps - 1, 1))
		var angle := lerpf(start, finish, weight)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _colors_equal(a: Color, b: Color) -> bool:
	return (
		is_equal_approx(a.r, b.r)
		and is_equal_approx(a.g, b.g)
		and is_equal_approx(a.b, b.b)
		and is_equal_approx(a.a, b.a)
	)


func _readability_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color
