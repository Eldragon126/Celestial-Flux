extends Control
class_name GravityGhostReplayPanel
## Reconstructs the final movement vector without replaying live physics state.

@export var replay_speed: float = 1.35
@export var loop_delay: float = 1.4
@export var path_padding: Vector2 = Vector2(28.0, 12.0)
@export var future_color: Color = Color(0.16, 0.72, 0.9, 0.13)
@export var trail_color: Color = Color(0.2, 0.96, 1.0, 0.92)
@export var danger_color: Color = Color(1.0, 0.42, 0.12, 0.96)
@export var highlight_color: Color = Color(1.0, 0.84, 0.28, 0.98)
@export var grid_color: Color = Color(0.16, 0.72, 0.86, 0.08)
@export var speed_color: Color = Color(0.38, 1.0, 0.78, 0.78)
@export var event_lane_color: Color = Color(0.16, 0.72, 0.86, 0.28)
@export var projectile_pressure_color: Color = Color(1.0, 0.52, 0.2, 0.74)
@export var enemy_pressure_color: Color = Color(1.0, 0.28, 0.14, 0.7)
@export var health_pressure_color: Color = Color(1.0, 0.18, 0.1, 0.74)
@export var gravity_pressure_color: Color = Color(0.64, 0.44, 1.0, 0.74)
@export var header_reserved_height: float = 46.0
@export var pressure_lane_reserved_height: float = 52.0

@export_group("Editable Labels")
@export var replay_title_template: String = "FINAL FLIGHT REPLAY // %.1f SECONDS // %s // W%d"
@export var unavailable_title_text: String = "FINAL FLIGHT REPLAY // SIGNAL LOST"
@export var unavailable_status_text: String = "No stable black-box movement vector was recorded."
@export var summary_template: String = "DIST %d // PEAK SPEED %d // PRIMARY %s"
@export var start_marker_text: String = "START"
@export var end_marker_text: String = "IMPACT"
@export var playhead_marker_text: String = "SHIP"
@export var show_route_markers: bool = true
@export var summary_label_path: NodePath = ^"SummaryLabel"
@export var start_marker_label_path: NodePath = ^"StartMarkerLabel"
@export var end_marker_label_path: NodePath = ^"EndMarkerLabel"
@export var playhead_marker_label_path: NodePath = ^"PlayheadMarkerLabel"

@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var summary_label: Label = get_node_or_null(summary_label_path) as Label
@onready var start_marker_label: Label = get_node_or_null(start_marker_label_path) as Label
@onready var end_marker_label: Label = get_node_or_null(end_marker_label_path) as Label
@onready var playhead_marker_label: Label = get_node_or_null(playhead_marker_label_path) as Label

var _positions := PackedVector2Array()
var _times := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _danger := PackedFloat32Array()
var _projectile_pressure := PackedFloat32Array()
var _enemy_pressure := PackedFloat32Array()
var _health_pressure := PackedFloat32Array()
var _gravity_pressure := PackedFloat32Array()
var _screen_points := PackedVector2Array()
var _highlights: Array[Dictionary] = []
var _incidents: Array[Dictionary] = []
var _duration: float = 0.0
var _peak_speed: float = 0.0
var _peak_danger: float = 0.0
var _peak_danger_time: float = 0.0
var _dominant_pressure: StringName = &"overall"
var _distance: float = 0.0
var _playhead: float = 0.0
var _valid: bool = false
var _last_layout_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_snapshot()
	queue_redraw()


func _process(delta: float) -> void:
	if not _valid:
		return
	_playhead += delta * maxf(replay_speed, 0.1)
	if _playhead > _duration + loop_delay:
		_playhead = 0.0
	_update_status()
	_update_route_marker_labels()
	queue_redraw()


func _load_snapshot() -> void:
	if RunProgress == null:
		_show_unavailable()
		return
	var value: Variant = RunProgress.call("get_last_gravity_ghost_replay") if RunProgress.has_method("get_last_gravity_ghost_replay") else RunProgress.arena_flags.get("gravity_ghost_replay", {})
	if not (value is Dictionary):
		_show_unavailable()
		return
	var snapshot: Dictionary = value
	var positions_value: Variant = snapshot.get("positions", PackedVector2Array())
	var times_value: Variant = snapshot.get("times", PackedFloat32Array())
	if not (positions_value is PackedVector2Array):
		_show_unavailable()
		return
	if not (times_value is PackedFloat32Array):
		_show_unavailable()
		return
	_positions = positions_value
	_times = times_value
	var danger_value: Variant = snapshot.get("danger", PackedFloat32Array())
	if danger_value is PackedFloat32Array:
		_danger = danger_value
	var speeds_value: Variant = snapshot.get("speeds", PackedFloat32Array())
	if speeds_value is PackedFloat32Array:
		_speeds = speeds_value
	var projectile_pressure_value: Variant = snapshot.get("projectile_pressure", PackedFloat32Array())
	if projectile_pressure_value is PackedFloat32Array:
		_projectile_pressure = projectile_pressure_value
	var enemy_pressure_value: Variant = snapshot.get("enemy_pressure", PackedFloat32Array())
	if enemy_pressure_value is PackedFloat32Array:
		_enemy_pressure = enemy_pressure_value
	var health_pressure_value: Variant = snapshot.get("health_pressure", PackedFloat32Array())
	if health_pressure_value is PackedFloat32Array:
		_health_pressure = health_pressure_value
	var gravity_pressure_value: Variant = snapshot.get("gravity_pressure", PackedFloat32Array())
	if gravity_pressure_value is PackedFloat32Array:
		_gravity_pressure = gravity_pressure_value
	_duration = maxf(float(snapshot.get("duration", 0.0)), 0.01)
	_peak_speed = float(snapshot.get("peak_speed", 0.0))
	_peak_danger = float(snapshot.get("peak_danger", 0.0))
	_peak_danger_time = float(snapshot.get("peak_danger_time", 0.0))
	_dominant_pressure = StringName(String(snapshot.get("dominant_pressure", &"overall")))
	_distance = float(snapshot.get("distance", 0.0))
	var highlights_value: Variant = snapshot.get("highlights", [])
	if highlights_value is Array:
		for value_entry in highlights_value:
			if value_entry is Dictionary:
				_highlights.append(value_entry as Dictionary)
	var incidents_value: Variant = snapshot.get("incidents", [])
	if incidents_value is Array:
		for value_entry in incidents_value:
			if value_entry is Dictionary:
				_incidents.append(value_entry as Dictionary)
	_valid = _positions.size() >= 2 and _times.size() == _positions.size()
	if not _valid:
		_show_unavailable()
		return
	title_label.text = replay_title_template % [
		_duration,
		_pressure_kind_label(_dominant_pressure),
		int(snapshot.get("wave", 0)),
	]
	if summary_label != null:
		summary_label.text = summary_template % [
			int(round(_distance)),
			int(round(_peak_speed)),
			_pressure_kind_label(_dominant_pressure),
		]
	_rebuild_screen_points()
	_update_status()
	_update_route_marker_labels()


func _show_unavailable() -> void:
	_valid = false
	if title_label != null:
		title_label.text = unavailable_title_text
	if status_label != null:
		status_label.text = unavailable_status_text
	if summary_label != null:
		summary_label.text = "BLACK BOX EMPTY"
	_set_route_markers_visible(false)


func _draw() -> void:
	_draw_grid()
	_draw_pressure_lane()
	if not _valid:
		return
	if _last_layout_size != size:
		_rebuild_screen_points()
	if _screen_points.size() < 2:
		return

	draw_polyline(_screen_points, future_color, 1.4, true)
	var active_index := _active_point_index()
	_draw_route_endpoints(active_index)
	for index in range(1, active_index + 1):
		var pressure := _danger[index] if index < _danger.size() else 0.0
		var color := trail_color.lerp(danger_color, clampf(pressure, 0.0, 1.0) * 0.82)
		draw_line(_screen_points[index - 1], _screen_points[index], Color(color, 0.18), 7.0, true)
		draw_line(_screen_points[index - 1], _screen_points[index], color, 2.4, true)
	_draw_highlights()
	_draw_ghost(active_index)
	_draw_event_timeline(active_index)
	_draw_incident_timeline(active_index)


func _draw_grid() -> void:
	var top := maxf(header_reserved_height, 30.0)
	var bottom := maxf(size.y - pressure_lane_reserved_height, top)
	for column in range(1, 10):
		var x := size.x * float(column) / 10.0
		draw_line(Vector2(x, top), Vector2(x, bottom), grid_color, 1.0)
	for row in range(1, 4):
		var y := lerpf(top, bottom, float(row) / 4.0)
		draw_line(Vector2(8.0, y), Vector2(size.x - 8.0, y), grid_color, 1.0)


func _rebuild_screen_points() -> void:
	_last_layout_size = size
	_screen_points.clear()
	if _positions.is_empty():
		return
	var minimum := _positions[0]
	var maximum := _positions[0]
	for point in _positions:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	var span := maximum - minimum
	span.x = maxf(span.x, 120.0)
	span.y = maxf(span.y, 120.0)
	var usable := Vector2(
		maxf(size.x - path_padding.x * 2.0, 1.0),
		maxf(size.y - path_padding.y * 2.0 - header_reserved_height - pressure_lane_reserved_height, 1.0)
	)
	var scale_factor := minf(usable.x / span.x, usable.y / span.y)
	var world_center := (minimum + maximum) * 0.5
	var screen_center := Vector2(size.x * 0.5, header_reserved_height + usable.y * 0.5)
	for point in _positions:
		_screen_points.append(screen_center + (point - world_center) * scale_factor)
	for index in range(_highlights.size()):
		var entry := _highlights[index]
		var world_position: Vector2 = entry.get("position", world_center)
		entry["screen_position"] = screen_center + (world_position - world_center) * scale_factor
		_highlights[index] = entry


func _active_point_index() -> int:
	if _times.is_empty() or _playhead <= 0.0:
		return 0
	for index in range(1, _times.size()):
		if _times[index] > _playhead:
			return index - 1
	return _times.size() - 1


func _draw_highlights() -> void:
	for entry in _highlights:
		if float(entry.get("time", 0.0)) > _playhead:
			continue
		var position: Vector2 = entry.get("screen_position", Vector2.ZERO)
		var strength := clampf(float(entry.get("strength", 0.5)), 0.2, 1.0)
		var kind := StringName(String(entry.get("kind", &"event")))
		var color := _highlight_kind_color(kind)
		draw_circle(position, 4.0 + strength * 4.0, Color(color, 0.13), false, 3.0, true)
		_draw_highlight_marker(position, 3.6 + strength * 1.8, color, kind)


func _draw_ghost(index: int) -> void:
	if index < 0 or index >= _screen_points.size():
		return
	var direction := Vector2.RIGHT
	if index > 0:
		direction = (_screen_points[index] - _screen_points[index - 1]).normalized()
	elif _screen_points.size() > 1:
		direction = (_screen_points[1] - _screen_points[0]).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var side := direction.orthogonal()
	var center := _screen_points[index]
	var ship := PackedVector2Array([
		center + direction * 11.0,
		center - direction * 7.0 + side * 5.5,
		center - direction * 4.0,
		center - direction * 7.0 - side * 5.5,
	])
	draw_circle(center, 12.0, Color(trail_color, 0.12), true)
	draw_colored_polygon(ship, trail_color)


func _draw_pressure_lane() -> void:
	if _times.size() < 2:
		return
	var left := 18.0
	var right := maxf(size.x - 18.0, left + 1.0)
	var base_y := _pressure_lane_y()
	var lane_height := 16.0
	draw_line(Vector2(left, base_y), Vector2(right, base_y), event_lane_color, 1.0, true)
	var active_index := _active_point_index()
	var last_point := Vector2(left, base_y)
	for index in range(_times.size()):
		var t := clampf(_times[index] / maxf(_duration, 0.01), 0.0, 1.0)
		var x := lerpf(left, right, t)
		var pressure := _danger[index] if index < _danger.size() else 0.0
		if pressure > 0.02:
			var danger_alpha := lerpf(0.08, 0.46, clampf(pressure, 0.0, 1.0))
			draw_line(Vector2(x, base_y), Vector2(x, base_y - lane_height * pressure), Color(danger_color, danger_alpha), 2.0, true)
		var speed_ratio := clampf((_speeds[index] if index < _speeds.size() else 0.0) / maxf(_peak_speed, 1.0), 0.0, 1.0)
		var speed_point := Vector2(x, base_y - 2.0 - speed_ratio * lane_height)
		if index > 0:
			draw_line(last_point, speed_point, Color(speed_color, 0.26 if index > active_index else speed_color.a), 1.4, true)
		last_point = speed_point
	_draw_pressure_component_track(_projectile_pressure, projectile_pressure_color, base_y - 22.0, 5.0, active_index)
	_draw_pressure_component_track(_enemy_pressure, enemy_pressure_color, base_y - 28.0, 5.0, active_index)
	_draw_pressure_component_track(_health_pressure, health_pressure_color, base_y - 34.0, 5.0, active_index)
	_draw_pressure_component_track(_gravity_pressure, gravity_pressure_color, base_y - 40.0, 5.0, active_index)


func _draw_pressure_component_track(values: PackedFloat32Array, color: Color, y: float, height: float, active_index: int) -> void:
	if values.size() < 2 or _times.size() < 2:
		return
	var left := 18.0
	var right := maxf(size.x - 18.0, left + 1.0)
	var last_point := Vector2(left, y)
	for index in range(mini(values.size(), _times.size())):
		var t := clampf(_times[index] / maxf(_duration, 0.01), 0.0, 1.0)
		var point := Vector2(lerpf(left, right, t), y - clampf(values[index], 0.0, 1.0) * height)
		if index > 0:
			draw_line(last_point, point, Color(color, color.a if index <= active_index else color.a * 0.28), 1.2, true)
		last_point = point


func _draw_route_endpoints(active_index: int) -> void:
	if _screen_points.is_empty() or not show_route_markers:
		return
	var start := _screen_points[0]
	var finish := _screen_points[_screen_points.size() - 1]
	var start_color := Color(trail_color, 0.64)
	var finish_color := danger_color if active_index >= _screen_points.size() - 2 else Color(danger_color, 0.42)
	draw_circle(start, 6.5, Color(start_color, 0.16), true)
	draw_circle(start, 6.5, start_color, false, 1.6, true)
	draw_circle(finish, 8.0, Color(finish_color, 0.16), true)
	draw_circle(finish, 8.0, finish_color, false, 1.8, true)


func _draw_event_timeline(active_index: int) -> void:
	if _highlights.is_empty():
		return
	var left := 18.0
	var right := maxf(size.x - 18.0, left + 1.0)
	var base_y := _pressure_lane_y()
	for entry in _highlights:
		var event_time := float(entry.get("time", 0.0))
		var t := clampf(event_time / maxf(_duration, 0.01), 0.0, 1.0)
		var position := Vector2(lerpf(left, right, t), base_y)
		var kind := StringName(String(entry.get("kind", &"event")))
		var color := _highlight_kind_color(kind)
		var active := active_index >= 0 and active_index < _times.size() and absf(event_time - _times[active_index]) <= 0.28
		draw_line(position + Vector2(0.0, -18.0), position + Vector2(0.0, 4.0), Color(color, 0.28 if not active else 0.58), 1.0, true)
		_draw_highlight_marker(position + Vector2(0.0, -2.0), 4.5 if active else 3.0, color, kind)


func _draw_incident_timeline(active_index: int) -> void:
	if _incidents.is_empty():
		return
	var left := 18.0
	var right := maxf(size.x - 18.0, left + 1.0)
	var base_y := _pressure_lane_y() - 47.0
	for entry in _incidents:
		var incident_time := float(entry.get("time", 0.0))
		var t := clampf(incident_time / maxf(_duration, 0.01), 0.0, 1.0)
		var position := Vector2(lerpf(left, right, t), base_y)
		var kind := StringName(String(entry.get("kind", &"overall")))
		var pressure := clampf(float(entry.get("pressure", 0.0)), 0.0, 1.0)
		var color := _pressure_kind_color(kind)
		var active := active_index >= 0 and active_index < _times.size() and absf(incident_time - _times[active_index]) <= 0.32
		var marker_radius := 2.6 + pressure * 3.4 + (1.5 if active else 0.0)
		draw_circle(position, marker_radius + 3.0, Color(color, 0.08 + pressure * 0.13), false, 2.0, true)
		draw_line(position + Vector2(0.0, 7.0), position + Vector2(0.0, 21.0), Color(color, 0.34 if not active else 0.68), 1.2, true)
		_draw_incident_marker(position, marker_radius, color, kind)


func _draw_incident_marker(position: Vector2, radius: float, color: Color, kind: StringName) -> void:
	match kind:
		&"health":
			var diamond := PackedVector2Array([
				position + Vector2(0.0, -radius),
				position + Vector2(radius, 0.0),
				position + Vector2(0.0, radius),
				position + Vector2(-radius, 0.0),
			])
			draw_colored_polygon(diamond, Color(color, 0.82))
		&"gravity":
			draw_circle(position, radius, Color(color, 0.12), true)
			draw_circle(position, radius * 1.24, color, false, 1.3, true)
			draw_line(position - Vector2(radius, 0.0), position + Vector2(radius, 0.0), color, 1.2, true)
		&"projectiles":
			draw_line(position - Vector2(radius, 0.0), position + Vector2(radius, 0.0), color, 1.4, true)
			draw_line(position + Vector2(radius * 0.34, -radius * 0.55), position + Vector2(radius, 0.0), color, 1.4, true)
			draw_line(position + Vector2(radius * 0.34, radius * 0.55), position + Vector2(radius, 0.0), color, 1.4, true)
		&"enemies":
			var tri := PackedVector2Array([
				position + Vector2(0.0, -radius),
				position + Vector2(radius * 0.9, radius * 0.72),
				position + Vector2(-radius * 0.9, radius * 0.72),
			])
			draw_colored_polygon(tri, Color(color, 0.78))
		_:
			draw_circle(position, radius, color, true)


func _pressure_lane_y() -> float:
	var reserved := maxf(pressure_lane_reserved_height - 18.0, 24.0)
	return maxf(size.y - reserved, header_reserved_height + 30.0)


func _draw_highlight_marker(position: Vector2, radius: float, color: Color, kind: StringName) -> void:
	match kind:
		&"slingshot":
			draw_polyline(_marker_arc(position, radius, PI * 0.7, TAU * 1.06, 9), color, 1.4, true)
			draw_line(position + Vector2(radius * 0.45, -radius * 0.24), position + Vector2(radius * 1.2, -radius * 0.78), color, 1.4, true)
		&"near_miss":
			draw_line(position - Vector2(radius, radius), position + Vector2(radius, radius), color, 1.4, true)
			draw_line(position + Vector2(-radius, radius), position + Vector2(radius, -radius), color, 1.4, true)
		&"recovery":
			var diamond := PackedVector2Array([
				position + Vector2(0.0, -radius),
				position + Vector2(radius, 0.0),
				position + Vector2(0.0, radius),
				position + Vector2(-radius, 0.0),
			])
			draw_colored_polygon(diamond, Color(color, 0.86))
		&"horizon_escape":
			draw_circle(position, radius, Color(color, 0.24), true)
			draw_circle(position, radius * 1.35, color, false, 1.4, true)
		_:
			draw_circle(position, radius, color, true)


func _update_status() -> void:
	if status_label == null or not _valid:
		return
	var active_highlight := ""
	for entry in _highlights:
		if absf(float(entry.get("time", -10.0)) - _playhead) <= 0.28:
			active_highlight = "%s %s" % [
				_highlight_kind_label(StringName(String(entry.get("kind", &"event")))),
				String(entry.get("label", "IMPOSSIBLE SAVE")),
			]
			break
	if not active_highlight.is_empty():
		status_label.text = "%s // VECTOR RECOVERED" % active_highlight
		status_label.modulate = highlight_color
		return
	var active_incident := _active_incident_label()
	if not active_incident.is_empty():
		status_label.text = "%s // PRESSURE SPIKE" % active_incident
		status_label.modulate = _pressure_kind_color(_active_incident_kind())
		return
	var active_index := _active_point_index()
	var current_speed := _speeds[active_index] if active_index >= 0 and active_index < _speeds.size() else 0.0
	var current_pressure := _danger[active_index] if active_index >= 0 and active_index < _danger.size() else 0.0
	status_label.text = "SPEED %d // PRESSURE %d%% // PEAK %d%% @ %.1fs // %s" % [
		int(current_speed),
		int(round(current_pressure * 100.0)),
		int(round(_peak_danger * 100.0)),
		_peak_danger_time,
		_pressure_kind_label(_dominant_pressure),
	]
	status_label.modulate = Color(0.72, 0.94, 1.0, 0.86)


func _update_route_marker_labels() -> void:
	if _screen_points.size() < 2 or not show_route_markers:
		_set_route_markers_visible(false)
		return
	_set_route_markers_visible(true)
	_place_marker_label(start_marker_label, _screen_points[0] + Vector2(-30.0, -22.0), start_marker_text, trail_color)
	_place_marker_label(end_marker_label, _screen_points[_screen_points.size() - 1] + Vector2(10.0, -22.0), end_marker_text, danger_color)
	var active_index := _active_point_index()
	if active_index >= 0 and active_index < _screen_points.size():
		_place_marker_label(playhead_marker_label, _screen_points[active_index] + Vector2(12.0, 10.0), playhead_marker_text, highlight_color)


func _set_route_markers_visible(visible: bool) -> void:
	for label in [start_marker_label, end_marker_label, playhead_marker_label]:
		if label != null:
			label.visible = visible


func _place_marker_label(label: Label, local_position: Vector2, text_value: String, color: Color) -> void:
	if label == null:
		return
	label.text = text_value
	label.modulate = color
	label.position = Vector2(
		clampf(local_position.x, 4.0, maxf(size.x - label.size.x - 4.0, 4.0)),
		clampf(local_position.y, header_reserved_height, maxf(size.y - pressure_lane_reserved_height - 16.0, header_reserved_height))
	)


func _active_incident_label() -> String:
	for entry in _incidents:
		if absf(float(entry.get("time", -10.0)) - _playhead) <= 0.32:
			return "%s %d%%" % [
				String(entry.get("label", "PRESSURE")).to_upper(),
				int(round(clampf(float(entry.get("pressure", 0.0)), 0.0, 1.0) * 100.0)),
			]
	return ""


func _active_incident_kind() -> StringName:
	for entry in _incidents:
		if absf(float(entry.get("time", -10.0)) - _playhead) <= 0.32:
			return StringName(String(entry.get("kind", &"overall")))
	return &"overall"


func _highlight_kind_color(kind: StringName) -> Color:
	match kind:
		&"slingshot":
			return Color(0.34, 1.0, 0.82, 0.98)
		&"near_miss":
			return Color(1.0, 0.68, 0.24, 0.98)
		&"recovery":
			return Color(0.42, 0.94, 1.0, 0.98)
		&"horizon_escape":
			return Color(0.92, 0.42, 1.0, 0.98)
	return highlight_color


func _pressure_kind_color(kind: StringName) -> Color:
	match kind:
		&"projectiles":
			return projectile_pressure_color
		&"enemies":
			return enemy_pressure_color
		&"health":
			return health_pressure_color
		&"gravity":
			return gravity_pressure_color
	return danger_color


func _pressure_kind_label(kind: StringName) -> String:
	match kind:
		&"projectiles":
			return "PROJECTILE PRESSURE"
		&"enemies":
			return "HOSTILE PRESSURE"
		&"health":
			return "HULL PRESSURE"
		&"gravity":
			return "GRAVITY PRESSURE"
	return "PEAK PRESSURE"


func _highlight_kind_label(kind: StringName) -> String:
	match kind:
		&"slingshot":
			return "SLING"
		&"near_miss":
			return "SKIM"
		&"recovery":
			return "RECOVERY"
		&"horizon_escape":
			return "HORIZON"
	return "EVENT"


func _marker_arc(center: Vector2, radius: float, start: float, finish: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(steps, 2)):
		var weight := float(index) / float(maxi(steps - 1, 1))
		var angle := lerpf(start, finish, weight)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
