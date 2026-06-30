extends Node2D
class_name CampaignVisualDirector

@export var enabled: bool = true
@export var refresh_interval: float = 0.35
@export var field_radius: float = 3600.0
@export var orbit_ring_count: int = 7
@export var ring_spacing: float = 420.0
@export var radial_line_count: int = 18
@export var ring_segments: int = 96
@export var max_lane_count: int = 18
@export var max_threat_lane_count: int = 16
@export var pulse_speed: float = 0.22
@export var ring_alpha: float = 0.12
@export var radial_alpha: float = 0.055
@export var mothership_lane_alpha: float = 0.28
@export var escort_lane_alpha: float = 0.16
@export var invader_lane_alpha: float = 0.16
@export var show_invader_threat_lanes: bool = true
@export var show_directive_pulse: bool = true
@export_range(0.0, 1.0, 0.01) var directive_pulse_alpha_bonus: float = 0.06
@export var lattice_color: Color = Color(0.18, 0.88, 1.0, 1.0)
@export var friendly_lane_color: Color = Color(0.34, 1.0, 0.76, 1.0)
@export var hostile_lane_color: Color = Color(1.0, 0.2, 0.1, 1.0)
@export var neutral_lane_color: Color = Color(0.7, 0.86, 1.0, 1.0)
@export var invader_lane_color: Color = Color(1.0, 0.18, 0.08, 1.0)
@export_group("Directive Colors")
@export var breach_directive_color: Color = Color(1.0, 0.22, 0.08, 1.0)
@export var intercept_directive_color: Color = Color(1.0, 0.66, 0.18, 1.0)
@export var salvage_directive_color: Color = Color(0.44, 1.0, 0.72, 1.0)
@export var hijack_directive_color: Color = Color(0.36, 1.0, 0.78, 1.0)
@export var escort_directive_color: Color = Color(0.24, 0.92, 1.0, 1.0)
@export var freehold_directive_color: Color = Color(1.0, 0.78, 0.32, 1.0)
@export_group("Threat Reticles")
@export var show_threat_reticles: bool = true
@export var max_threat_reticle_count: int = 10
@export var threat_reticle_segments: int = 24
@export var threat_reticle_radius: float = 54.0
@export var threat_reticle_width: float = 1.45
@export var threat_reticle_rotation_speed: float = 1.35
@export_range(0.0, 1.0, 0.01) var threat_reticle_alpha: float = 0.22
@export var threat_reticle_color: Color = Color(1.0, 0.18, 0.08, 1.0)

var _director: Node = null
var _directive_id_cache: StringName = &"standard"
var _mother: Node2D = null
var _motherships: Array[Node2D] = []
var _escorts: Array[Node2D] = []
var _invaders: Array[Node2D] = []
var _query_targets: Array[Node2D] = []
var _rings: Array[Line2D] = []
var _radials: Array[Line2D] = []
var _lanes: Array[Line2D] = []
var _threat_lanes: Array[Line2D] = []
var _threat_reticles: Array[Line2D] = []
var _elapsed: float = 0.0
var _refresh_elapsed: float = 999.0


func _ready() -> void:
	z_index = -140
	add_to_group("campaign_visual_director")
	_build_field_nodes()
	_refresh_targets()


func _process(delta: float) -> void:
	_elapsed += delta
	_refresh_elapsed += delta
	if _refresh_elapsed >= refresh_interval:
		_refresh_elapsed = 0.0
		_refresh_targets()
	_prune_cached_targets()
	_update_visibility()
	if not enabled:
		return
	_update_lattice()
	_update_lanes()
	_update_threat_lanes()
	_update_threat_reticles()


func _build_field_nodes() -> void:
	for index in range(maxi(orbit_ring_count, 0)):
		var ring := _make_line("CampaignOrbitRing%d" % index, true, 1.2)
		_rings.append(ring)
		add_child(ring)
	for index in range(maxi(radial_line_count, 0)):
		var radial := _make_line("CampaignRadialVector%d" % index, false, 0.8)
		_radials.append(radial)
		add_child(radial)
	for index in range(maxi(max_lane_count, 0)):
		var lane := _make_line("CampaignFactionLane%d" % index, false, 1.3)
		_lanes.append(lane)
		add_child(lane)
	for index in range(maxi(max_threat_lane_count, 0)):
		var threat_lane := _make_line("CampaignThreatLane%d" % index, false, 1.0)
		_threat_lanes.append(threat_lane)
		add_child(threat_lane)
	for index in range(maxi(max_threat_reticle_count, 0)):
		var reticle := _make_line("CampaignThreatReticle%d" % index, true, threat_reticle_width)
		_threat_reticles.append(reticle)
		add_child(reticle)


func _make_line(node_name: String, closed: bool, width: float) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.top_level = true
	line.closed = closed
	line.antialiased = true
	line.width = width
	line.visible = false
	return line


func _refresh_targets() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_director = tree.get_first_node_in_group("campaign_mode_director")
	_refresh_directive_snapshot()
	_query_targets.clear()
	_fill_group_cached(&"campaign_mother_planet", _query_targets, 1)
	if not _query_targets.is_empty():
		_mother = _query_targets[0]
	else:
		_mother = tree.get_first_node_in_group("campaign_mother_planet") as Node2D
	_fill_group_cached(&"campaign_mothership", _motherships)
	_fill_group_cached(&"campaign_escort", _escorts)
	_fill_group_cached(&"campaign_invader", _invaders)


func _update_visibility() -> void:
	for line in _rings + _radials + _lanes + _threat_lanes + _threat_reticles:
		if line != null:
			line.visible = false if not enabled else line.visible


func _update_lattice() -> void:
	var center := _anchor_position()
	var directive_color := _directive_color()
	var directive_alpha := _directive_alpha_bonus()
	for index in range(_rings.size()):
		var ring := _rings[index]
		if ring == null:
			continue
		var radius := ring_spacing * float(index + 1)
		var pulse := sin(_elapsed * pulse_speed + float(index) * 0.7) * 0.5 + 0.5
		ring.global_position = center
		ring.points = _circle_points(radius + pulse * 18.0, ring_segments)
		ring.width = 0.8 + pulse * 0.7
		var ring_tint := lattice_color.lerp(directive_color, 0.28)
		ring.default_color = _safe_color(Color(ring_tint.r, ring_tint.g, ring_tint.b, _safe_alpha(ring_alpha * (1.0 - float(index) * 0.08) + directive_alpha, 0.2)))
		ring.visible = radius <= field_radius

	for index in range(_radials.size()):
		var radial := _radials[index]
		if radial == null:
			continue
		var angle := TAU * float(index) / float(maxi(_radials.size(), 1)) + _elapsed * 0.018
		var direction := Vector2(cos(angle), sin(angle))
		radial.global_position = Vector2.ZERO
		radial.points = PackedVector2Array([
			center + direction * ring_spacing * 0.35,
			center + direction * field_radius,
		])
		var radial_tint := lattice_color.lerp(directive_color, 0.22)
		radial.default_color = _safe_color(Color(radial_tint.r, radial_tint.g, radial_tint.b, _safe_alpha(radial_alpha + directive_alpha * 0.4, 0.1)))
		radial.visible = true


func _update_lanes() -> void:
	var center := _anchor_position()
	var lane_index := 0
	for ship in _motherships:
		if lane_index >= _lanes.size():
			break
		if not _is_live_node(ship):
			continue
		_configure_lane(_lanes[lane_index], center, ship.global_position, _mothership_lane_color(ship), mothership_lane_alpha, true)
		lane_index += 1
	for escort in _escorts:
		if lane_index >= _lanes.size():
			break
		if not _is_live_node(escort):
			continue
		_configure_lane(_lanes[lane_index], center, escort.global_position, friendly_lane_color, escort_lane_alpha, false)
		lane_index += 1
	for index in range(lane_index, _lanes.size()):
		if _lanes[index] != null:
			_lanes[index].visible = false


func _update_threat_lanes() -> void:
	if not show_invader_threat_lanes:
		_hide_lines(_threat_lanes)
		return
	var lane_index := 0
	for invader in _invaders:
		if lane_index >= _threat_lanes.size():
			break
		if not _is_live_node(invader):
			continue
		var target := _invader_target(invader)
		if not _is_live_node(target):
			continue
		_configure_threat_lane(_threat_lanes[lane_index], invader.global_position, target.global_position)
		lane_index += 1
	for index in range(lane_index, _threat_lanes.size()):
		if _threat_lanes[index] != null:
			_threat_lanes[index].visible = false


func _update_threat_reticles() -> void:
	if not show_invader_threat_lanes or not show_threat_reticles:
		_hide_lines(_threat_reticles)
		return
	var reticle_index := 0
	for invader in _invaders:
		if reticle_index >= _threat_reticles.size():
			break
		if not _is_live_node(invader):
			continue
		var target := _invader_target(invader)
		if not _is_live_node(target):
			continue
		var distance := invader.global_position.distance_to(target.global_position)
		if distance > field_radius * 1.2:
			continue
		var pressure := clampf(1.0 - distance / maxf(field_radius * 1.2, 1.0), 0.12, 1.0)
		_configure_threat_reticle(_threat_reticles[reticle_index], target.global_position, pressure, reticle_index)
		reticle_index += 1
	for index in range(reticle_index, _threat_reticles.size()):
		if _threat_reticles[index] != null:
			_threat_reticles[index].visible = false


func _configure_lane(line: Line2D, start: Vector2, end: Vector2, color: Color, alpha: float, important: bool) -> void:
	if line == null:
		return
	var midpoint := start.lerp(end, 0.5)
	var bend := (end - start).orthogonal().normalized() * minf(start.distance_to(end) * 0.08, 110.0)
	line.global_position = Vector2.ZERO
	line.points = PackedVector2Array([start, midpoint + bend, end])
	line.width = 1.8 if important else 1.1
	line.default_color = _safe_color(Color(color.r, color.g, color.b, _safe_alpha(alpha, 0.34)))
	line.visible = start.distance_to(end) <= field_radius * 1.2


func _configure_threat_lane(line: Line2D, start: Vector2, end: Vector2) -> void:
	if line == null:
		return
	var distance := start.distance_to(end)
	var direction := (end - start).normalized() if distance > 0.01 else Vector2.RIGHT
	var shortened_end := start + direction * minf(distance, field_radius * 0.46)
	var midpoint := start.lerp(shortened_end, 0.58)
	var bend := direction.orthogonal() * sin(_elapsed * 1.6 + start.x * 0.002) * minf(distance * 0.035, 46.0)
	line.global_position = Vector2.ZERO
	line.points = PackedVector2Array([start, midpoint + bend, shortened_end])
	line.width = 0.9 + 0.5 * (sin(_elapsed * 3.0 + start.y * 0.002) * 0.5 + 0.5)
	var threat_color := invader_lane_color.lerp(_directive_color(), 0.28)
	line.default_color = _safe_color(Color(threat_color.r, threat_color.g, threat_color.b, _safe_alpha(invader_lane_alpha + _directive_alpha_bonus(), 0.24)))
	line.visible = distance <= field_radius * 1.15


func _configure_threat_reticle(line: Line2D, position: Vector2, pressure: float, index: int) -> void:
	if line == null:
		return
	var clamped_pressure := clampf(pressure, 0.0, 1.0)
	var radius := threat_reticle_radius * lerpf(0.82, 1.36, clamped_pressure)
	radius += sin(_elapsed * 3.1 + float(index) * 0.63) * threat_reticle_radius * 0.08
	line.global_position = position
	line.rotation = _elapsed * threat_reticle_rotation_speed * (-1.0 if index % 2 == 0 else 1.0)
	line.points = _reticle_points(radius, threat_reticle_segments)
	line.width = threat_reticle_width * lerpf(0.78, 1.32, clamped_pressure)
	var directive_tint := threat_reticle_color.lerp(_directive_color(), 0.22)
	var alpha := _safe_alpha(threat_reticle_alpha * lerpf(0.55, 1.0, clamped_pressure) + _directive_alpha_bonus() * 0.55, 0.34)
	line.default_color = _safe_color(Color(directive_tint.r, directive_tint.g, directive_tint.b, alpha))
	line.visible = true


func _directive_color() -> Color:
	var directive := _directive_id()
	match directive:
		&"breach":
			return breach_directive_color
		&"intercept":
			return intercept_directive_color
		&"salvage":
			return salvage_directive_color
		&"hijack":
			return hijack_directive_color
		&"escort":
			return escort_directive_color
		&"freehold":
			return freehold_directive_color
	return lattice_color


func _directive_alpha_bonus() -> float:
	if not show_directive_pulse:
		return 0.0
	var pulse := 0.5 + sin(_elapsed * 1.7) * 0.5
	return directive_pulse_alpha_bonus * pulse


func _directive_id() -> StringName:
	return _directive_id_cache


func _refresh_directive_snapshot() -> void:
	_directive_id_cache = &"standard"
	if _director != null and is_instance_valid(_director) and _director.has_method("get_campaign_visual_snapshot"):
		var snapshot_value: Variant = _director.call("get_campaign_visual_snapshot")
		if snapshot_value is Dictionary:
			var snapshot: Dictionary = snapshot_value
			_directive_id_cache = StringName(str(snapshot.get("directive", "standard")))


func _mothership_lane_color(ship: Node2D) -> Color:
	if not _is_live_node(ship):
		return neutral_lane_color
	if ship.has_method("is_hostile") and bool(ship.call("is_hostile")):
		return hostile_lane_color
	var faction_value: Variant = ship.get("faction")
	match int(faction_value):
		0, 1:
			return friendly_lane_color
		3:
			return hostile_lane_color
	return neutral_lane_color


func _invader_target(invader: Node2D) -> Node2D:
	if not _is_live_node(invader):
		return _mother if _is_live_node(_mother) else null
	var target_value: Variant = invader.get("target")
	var target: Node2D = null
	if target_value is Object and is_instance_valid(target_value):
		target = target_value as Node2D
	if _is_live_node(target):
		return target
	return _mother if _is_live_node(_mother) else null


func _hide_lines(lines: Array[Line2D]) -> void:
	for line in lines:
		if line != null:
			line.visible = false


func _anchor_position() -> Vector2:
	if _mother != null and is_instance_valid(_mother):
		return _mother.global_position
	return Vector2.ZERO


func _prune_cached_targets() -> void:
	if not _is_live_node(_mother):
		_mother = null
	_prune_node_array(_motherships)
	_prune_node_array(_escorts)
	_prune_node_array(_invaders)


func _prune_node_array(nodes: Array[Node2D]) -> void:
	for index in range(nodes.size() - 1, -1, -1):
		if not _is_live_node(nodes[index]):
			nodes.remove_at(index)


func _fill_group_cached(group_name: StringName, out_nodes: Array[Node2D], limit: int = -1) -> void:
	out_nodes.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(group_name, out_nodes, limit)
		return
	for value in get_tree().get_nodes_in_group(String(group_name)):
		if limit >= 0 and out_nodes.size() >= limit:
			return
		var node := value as Node2D
		if _is_live_node(node):
			out_nodes.append(node)


func _is_live_node(node) -> bool:
	if node == null or not (node is Object):
		return false
	if not is_instance_valid(node):
		return false
	if not (node is Node):
		return false
	var live_node := node as Node
	return not live_node.is_queued_for_deletion()


func _safe_color(color: Color) -> Color:
	var settings := _settings()
	if settings != null and settings.has_method("apply_readability_color"):
		return settings.call("apply_readability_color", color)
	return color


func _safe_alpha(alpha: float, cap: float) -> float:
	var settings := _settings()
	if settings != null and settings.has_method("world_visual_alpha"):
		return float(settings.call("world_visual_alpha", alpha, cap))
	if settings != null and settings.has_method("flash_alpha"):
		return minf(float(settings.call("flash_alpha", alpha)), cap)
	return minf(alpha, cap)


func _settings() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Settings")


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _reticle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segment_count := maxi(count, 12)
	for index in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		var notch := 0.78 if index % 6 == 0 else 1.0
		points.append(Vector2(cos(angle), sin(angle)) * radius * notch)
	return points
