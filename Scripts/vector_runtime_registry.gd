extends Node
class_name VectorRuntimeRegistry

signal group_count_changed(group_name: StringName, count: int)

const GRAVITY_GROUPS: Array[StringName] = [&"Objects_With_Gravity", &"planets"]
const TRACKED_GROUPS: Array[StringName] = [
	&"Objects_With_Gravity",
	&"planets",
	&"Projectiles",
	&"player_projectiles",
	&"enemy_projectiles",
	&"enemies",
	&"wave_enemy",
	&"bosses",
	&"player_allies",
	&"campaign_mother_planet",
	&"campaign_mothership",
	&"campaign_escort",
	&"campaign_invader",
	&"campaign_planet_turret",
	&"campaign_salvage",
	&"law_gravity_debris",
	&"anomaly_shard",
	&"blackbox_tape",
	&"gravity_leeches",
	&"Player",
	&"spacetime_tear",
	&"arena_hazard",
	&"arena_destabilization_hazard",
	&"gravity_tide_pocket",
	&"gravity_wave_maker",
	&"pulsating_gravity_spawner",
]

@export var refresh_interval: float = 0.35
@export var gravity_refresh_interval: float = 0.5
@export_range(1, 32, 1) var max_combat_group_refreshes_per_tick: int = 10
@export var compact_invalid_entries_on_fill: bool = true

var _groups: Dictionary = {}
var _group_ids: Dictionary = {}
var _counts: Dictionary = {}
var _elapsed: float = 999.0
var _gravity_elapsed: float = 999.0
var _combat_refresh_cursor: int = 0
var _combat_refresh_groups: Array[StringName] = []
var _nearest_sources_buffer: Array[Node2D] = []
var _nearest_distances_buffer: Array[float] = []
var _seen_ids_buffer: Dictionary = {}
var _target_seen_ids_buffer: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for group_name in TRACKED_GROUPS:
		_groups[group_name] = []
		_group_ids[group_name] = {}
		_counts[group_name] = 0
		if not GRAVITY_GROUPS.has(group_name):
			_combat_refresh_groups.append(group_name)
	_refresh_all_groups()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_gravity_elapsed += delta
	if _elapsed >= refresh_interval:
		_elapsed = 0.0
		_refresh_combat_groups()
	if _gravity_elapsed >= gravity_refresh_interval:
		_gravity_elapsed = 0.0
		_refresh_gravity_groups()


func register_node(node: Node, group_name: StringName) -> void:
	if not _is_valid_node(node):
		return
	if not _groups.has(group_name):
		_groups[group_name] = []
		_group_ids[group_name] = {}
		_counts[group_name] = 0
	var ids: Dictionary = _group_ids[group_name]
	var id := node.get_instance_id()
	if ids.has(id):
		return
	ids[id] = true
	_groups[group_name].append(node)
	_set_count(group_name, int(_counts.get(group_name, 0)) + 1)


func unregister_node(node: Node, group_name: StringName) -> void:
	if node == null or not _groups.has(group_name):
		return
	var id := node.get_instance_id()
	var ids: Dictionary = _group_ids[group_name]
	if not ids.has(id):
		return
	ids.erase(id)
	var list: Array = _groups[group_name]
	for index in range(list.size() - 1, -1, -1):
		var candidate_value: Variant = list[index]
		if candidate_value == null or not is_instance_valid(candidate_value):
			list.remove_at(index)
			continue
		var candidate := candidate_value as Node
		if candidate == null or candidate.is_queued_for_deletion() or candidate.get_instance_id() == id:
			list.remove_at(index)
	_groups[group_name] = list
	_set_count(group_name, list.size())


func get_count(group_name: StringName) -> int:
	if not _groups.has(group_name):
		_refresh_group(group_name)
	return int(_counts.get(group_name, 0))


func fill_group(group_name: StringName, out_nodes: Array[Node2D], limit: int = -1) -> void:
	out_nodes.clear()
	if not _groups.has(group_name):
		_refresh_group(group_name)
	var list: Array = _groups.get(group_name, [])
	var invalid_removed := false
	for value in list:
		if limit >= 0 and out_nodes.size() >= limit:
			break
		if value == null or not is_instance_valid(value):
			invalid_removed = true
			continue
		var node := value as Node2D
		if _is_valid_node(node):
			out_nodes.append(node)
		else:
			invalid_removed = true
	if invalid_removed and compact_invalid_entries_on_fill:
		_compact_group(group_name)


func fill_nearest_gravity_sources(
	position: Vector2,
	out_sources: Array[Node2D],
	max_sources: int,
	max_distance: float = 0.0,
	exclude: Node = null
) -> void:
	out_sources.clear()
	var max_count := maxi(max_sources, 0)
	if max_count == 0:
		return

	_nearest_sources_buffer.clear()
	_nearest_distances_buffer.clear()
	_seen_ids_buffer.clear()
	var max_distance_squared := max_distance * max_distance

	for group_name in GRAVITY_GROUPS:
		var list: Array = _groups.get(group_name, [])
		for value in list:
			if value == null or not is_instance_valid(value):
				continue
			var source := value as Node2D
			if not _is_valid_node(source) or source == exclude:
				continue
			var id := source.get_instance_id()
			if _seen_ids_buffer.has(id):
				continue
			_seen_ids_buffer[id] = true
			var distance_squared := source.global_position.distance_squared_to(position)
			if max_distance > 0.0 and distance_squared > max_distance_squared:
				continue
			_insert_nearest(source, distance_squared, _nearest_sources_buffer, _nearest_distances_buffer, max_count)

	for source in _nearest_sources_buffer:
		out_sources.append(source)


func fill_targets_in_radius(
	groups: Array[StringName],
	center: Vector2,
	radius: float,
	limit: int,
	include_player: bool,
	out_targets: Array[Node2D]
) -> void:
	out_targets.clear()
	var radius_squared := radius * radius
	_target_seen_ids_buffer.clear()
	var max_count := maxi(limit, 0)

	for group_name in groups:
		var list: Array = _groups.get(group_name, [])
		for value in list:
			if max_count > 0 and out_targets.size() >= max_count:
				return
			if value == null or not is_instance_valid(value):
				continue
			var body := value as Node2D
			if not _is_valid_node(body):
				continue
			if not include_player and body.is_in_group("Player"):
				continue
			var id := body.get_instance_id()
			if _target_seen_ids_buffer.has(id):
				continue
			_target_seen_ids_buffer[id] = true
			if body.global_position.distance_squared_to(center) > radius_squared:
				continue
			out_targets.append(body)


func _insert_nearest(
	source: Node2D,
	distance_squared: float,
	best_sources: Array[Node2D],
	best_distances: Array[float],
	max_count: int
) -> void:
	var insert_at := best_distances.size()
	for index in range(best_distances.size()):
		if distance_squared < best_distances[index]:
			insert_at = index
			break
	if insert_at >= max_count:
		return
	best_sources.insert(insert_at, source)
	best_distances.insert(insert_at, distance_squared)
	while best_sources.size() > max_count:
		best_sources.remove_at(best_sources.size() - 1)
		best_distances.remove_at(best_distances.size() - 1)


func _refresh_all_groups() -> void:
	for group_name in TRACKED_GROUPS:
		_refresh_group(group_name)


func _refresh_combat_groups() -> void:
	if _combat_refresh_groups.is_empty():
		return
	var refresh_count := mini(maxi(max_combat_group_refreshes_per_tick, 1), _combat_refresh_groups.size())
	for _index in range(refresh_count):
		var group_name := _combat_refresh_groups[_combat_refresh_cursor]
		_refresh_group(group_name)
		_combat_refresh_cursor = (_combat_refresh_cursor + 1) % _combat_refresh_groups.size()


func _refresh_gravity_groups() -> void:
	for group_name in GRAVITY_GROUPS:
		_refresh_group(group_name)


func _refresh_group(group_name: StringName) -> void:
	if not is_inside_tree():
		return
	var list: Array = []
	var ids: Dictionary = {}
	for value in get_tree().get_nodes_in_group(group_name):
		if value == null or not is_instance_valid(value):
			continue
		var node := value as Node
		if node == null or node.is_queued_for_deletion():
			continue
		var id := node.get_instance_id()
		if ids.has(id):
			continue
		ids[id] = true
		list.append(node)
	_groups[group_name] = list
	_group_ids[group_name] = ids
	_set_count(group_name, list.size())


func _compact_group(group_name: StringName) -> void:
	if not _groups.has(group_name):
		return
	var list: Array = _groups[group_name]
	var ids: Dictionary = {}
	for index in range(list.size() - 1, -1, -1):
		var value: Variant = list[index]
		if value == null or not is_instance_valid(value):
			list.remove_at(index)
			continue
		var node := value as Node
		if node == null or node.is_queued_for_deletion() or not node.is_inside_tree():
			list.remove_at(index)
			continue
		var id := node.get_instance_id()
		if ids.has(id):
			list.remove_at(index)
			continue
		ids[id] = true
	_groups[group_name] = list
	_group_ids[group_name] = ids
	_set_count(group_name, list.size())


func _set_count(group_name: StringName, count: int) -> void:
	var previous := int(_counts.get(group_name, -1))
	_counts[group_name] = count
	if previous != count:
		group_count_changed.emit(group_name, count)


func _is_valid_node(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree()
