extends Node
class_name EnemyReadabilityDirector

## Adds small role glyphs to enemies so silhouettes communicate behavior fast.
## The markers are cheap Line2D children and update on a capped cadence.

@export var enabled: bool = true
@export var scan_interval: float = 0.55
@export var max_marked_enemies: int = 42
@export var glyph_radius: float = 28.0
@export var glyph_width: float = 2.4
@export var enable_enemy_halos: bool = true
@export var enemy_halo_radius: float = 44.0
@export var enemy_halo_width: float = 1.8
@export_range(0.0, 1.0, 0.01) var enemy_halo_alpha: float = 0.22
@export var enable_boss_silhouettes: bool = true
@export var boss_silhouette_radius: float = 92.0
@export var boss_silhouette_width: float = 4.2
@export var enable_player_halos: bool = true
@export var player_halo_radius: float = 68.0
@export var player_halo_width: float = 2.4
@export var enable_object_halos: bool = true
@export var object_halo_radius: float = 96.0
@export var object_halo_width: float = 1.7
@export var max_marked_objects: int = 18

var _elapsed := 999.0
var _marked: Dictionary = {}
var _enemy_halos: Dictionary = {}
var _boss_outlines: Dictionary = {}
var _player_halos: Dictionary = {}
var _object_halos: Dictionary = {}
var _enemy_buffer: Array[Node2D] = []
var _object_buffer: Array[Node2D] = []
var _live_ids: Dictionary = {}
var _live_player_ids: Dictionary = {}
var _live_object_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("enemy_readability_director")
	_connect_accessibility_settings()
	_apply_readability_halo_setting()
	set_process(true)


func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	if _elapsed < maxf(scan_interval, 0.12):
		return
	_elapsed = 0.0
	_refresh_enemy_glyphs()


func _refresh_enemy_glyphs() -> void:
	var marked_this_pass := 0
	_live_ids.clear()
	_fill_enemy_buffer()
	if not _readability_halos_enabled():
		_clear_readability_halos()
		_clear_line_dictionary(_player_halos)
		_clear_line_dictionary(_object_halos)

	for enemy_2d in _enemy_buffer:
		if marked_this_pass >= max_marked_enemies:
			break
		if enemy_2d == null or not is_instance_valid(enemy_2d) or enemy_2d.is_queued_for_deletion():
			continue
		if enemy_2d.is_in_group("Player"):
			continue

		var id := enemy_2d.get_instance_id()
		_live_ids[id] = true
		_ensure_enemy_halo(enemy_2d)
		_ensure_glyph(enemy_2d)
		_ensure_boss_silhouette(enemy_2d)
		marked_this_pass += 1

	for id in _marked.keys():
		if _live_ids.has(id):
			continue
		var marker = _marked[id]
		if marker != null and is_instance_valid(marker) and not marker.is_queued_for_deletion():
			marker.queue_free()
		_marked.erase(id)
	for id in _enemy_halos.keys():
		if _live_ids.has(id):
			continue
		var halo = _enemy_halos[id]
		if halo != null and is_instance_valid(halo) and not halo.is_queued_for_deletion():
			halo.queue_free()
		_enemy_halos.erase(id)
	for id in _boss_outlines.keys():
		if _live_ids.has(id):
			continue
		var outline = _boss_outlines[id]
		if outline != null and is_instance_valid(outline) and not outline.is_queued_for_deletion():
			outline.queue_free()
		_boss_outlines.erase(id)
	_refresh_player_halos()
	_refresh_object_halos()


func _fill_enemy_buffer() -> void:
	_enemy_buffer.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(&"enemies", _enemy_buffer, max_marked_enemies)
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _enemy_buffer.size() >= max_marked_enemies:
			return
		var enemy_2d := enemy as Node2D
		if enemy_2d != null and is_instance_valid(enemy_2d) and not enemy_2d.is_queued_for_deletion():
			_enemy_buffer.append(enemy_2d)


func _refresh_player_halos() -> void:
	_live_player_ids.clear()
	if not enable_player_halos or not _readability_halos_enabled():
		_clear_line_dictionary(_player_halos)
		return
	for player in MultiplayerTargeting.live_players(get_tree()):
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		var id := player.get_instance_id()
		_live_player_ids[id] = true
		_ensure_player_halo(player)
	for id in _player_halos.keys():
		if _live_player_ids.has(id):
			continue
		var halo = _player_halos[id]
		if halo != null and is_instance_valid(halo) and not halo.is_queued_for_deletion():
			halo.queue_free()
		_player_halos.erase(id)


func _refresh_object_halos() -> void:
	_live_object_ids.clear()
	if not enable_object_halos or not _readability_halos_enabled():
		_clear_line_dictionary(_object_halos)
		return
	_fill_object_buffer()
	for object_2d in _object_buffer:
		if object_2d == null or not is_instance_valid(object_2d) or object_2d.is_queued_for_deletion():
			continue
		if object_2d.is_in_group("Player") or object_2d.is_in_group("enemies"):
			continue
		var id := object_2d.get_instance_id()
		_live_object_ids[id] = true
		_ensure_object_halo(object_2d)
	for id in _object_halos.keys():
		if _live_object_ids.has(id):
			continue
		var halo = _object_halos[id]
		if halo != null and is_instance_valid(halo) and not halo.is_queued_for_deletion():
			halo.queue_free()
		_object_halos.erase(id)


func _fill_object_buffer() -> void:
	_object_buffer.clear()
	var seen := {}
	for group_name in [&"Objects_With_Gravity", &"planets", &"arena_hazard", &"gravity_tide_pocket"]:
		var scratch: Array[Node2D] = []
		if RuntimeRegistry != null:
			RuntimeRegistry.fill_group(group_name, scratch, max_marked_objects)
		else:
			for value in get_tree().get_nodes_in_group(group_name):
				var node := value as Node2D
				if node != null:
					scratch.append(node)
		for node in scratch:
			if _object_buffer.size() >= max_marked_objects:
				return
			if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			var id := node.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_object_buffer.append(node)


func _ensure_glyph(enemy: Node2D) -> void:
	var id := enemy.get_instance_id()
	var existing := _marked.get(id, null) as Line2D
	if existing != null and is_instance_valid(existing):
		_update_glyph(existing, _profile_for_enemy(enemy))
		return

	var glyph := Line2D.new()
	glyph.name = "RoleSilhouetteGlyph"
	glyph.closed = false
	glyph.antialiased = true
	glyph.width = glyph_width
	glyph.z_index = 18
	enemy.add_child(glyph)
	_marked[id] = glyph
	_update_glyph(glyph, _profile_for_enemy(enemy))


func _ensure_enemy_halo(enemy: Node2D) -> void:
	if not enable_enemy_halos or not _readability_halos_enabled():
		return
	var id := enemy.get_instance_id()
	var profile := _profile_for_enemy(enemy)
	var existing := _enemy_halos.get(id, null) as Line2D
	if existing != null and is_instance_valid(existing):
		_update_enemy_halo(existing, profile, enemy.is_in_group("bosses"))
		return
	var halo := Line2D.new()
	halo.name = "RoleSilhouetteHalo"
	halo.closed = true
	halo.antialiased = true
	halo.width = enemy_halo_width
	halo.z_index = 16
	enemy.add_child(halo)
	_enemy_halos[id] = halo
	_update_enemy_halo(halo, profile, enemy.is_in_group("bosses"))


func _ensure_player_halo(player: Node2D) -> void:
	var id := player.get_instance_id()
	var existing := _player_halos.get(id, null) as Line2D
	if existing != null and is_instance_valid(existing):
		_update_player_halo(existing, player)
		return
	var halo := Line2D.new()
	halo.name = "PlayerReadabilityHalo_ControlVector"
	halo.closed = true
	halo.antialiased = true
	halo.width = player_halo_width
	halo.z_index = 15
	halo.set_meta(&"readability_shape_role", "player control vector")
	player.add_child(halo)
	_player_halos[id] = halo
	_update_player_halo(halo, player)


func _ensure_object_halo(object_2d: Node2D) -> void:
	var id := object_2d.get_instance_id()
	var profile := _profile_for_object(object_2d)
	var existing := _object_halos.get(id, null) as Line2D
	if existing != null and is_instance_valid(existing):
		_update_object_halo(existing, profile, object_2d)
		return
	var halo := Line2D.new()
	halo.name = "ObjectReadabilityHalo_%s" % String(profile)
	halo.closed = profile != &"flow"
	halo.antialiased = true
	halo.width = object_halo_width
	halo.z_index = 12
	halo.set_meta(&"readability_shape_role", "gravity object %s" % String(profile))
	object_2d.add_child(halo)
	_object_halos[id] = halo
	_update_object_halo(halo, profile, object_2d)


func _update_glyph(glyph: Line2D, profile: StringName) -> void:
	glyph.points = _points_for_profile(profile)
	glyph.default_color = _color_for_profile(profile)


func _update_enemy_halo(halo: Line2D, profile: StringName, is_boss: bool) -> void:
	var radius := boss_silhouette_radius * 0.72 if is_boss else enemy_halo_radius
	halo.points = _halo_points(profile, radius)
	halo.width = enemy_halo_width * (1.7 if is_boss else 1.0)
	var color := _color_for_profile(profile)
	halo.default_color = Color(color.r, color.g, color.b, _safe_alpha(enemy_halo_alpha * (1.45 if is_boss else 1.0), 0.24))


func _update_player_halo(halo: Line2D, player: Node2D) -> void:
	var velocity_value: Variant = player.get("velocity")
	var speed_ratio := 0.0
	if velocity_value is Vector2:
		var velocity: Vector2 = velocity_value
		var max_speed_value: Variant = player.get("current_max_speed")
		var max_speed := float(max_speed_value) if typeof(max_speed_value) == TYPE_FLOAT or typeof(max_speed_value) == TYPE_INT else 1200.0
		speed_ratio = clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.3)
	var radius := player_halo_radius * lerpf(0.92, 1.18, speed_ratio)
	halo.points = _player_control_vector_points(radius)
	halo.width = player_halo_width * lerpf(0.86, 1.28, speed_ratio)
	var color := _readability_color(Color(0.28, 1.0, 0.86, 1.0))
	halo.default_color = Color(color.r, color.g, color.b, _safe_alpha(0.24 + speed_ratio * 0.08, 0.34))


func _update_object_halo(halo: Line2D, profile: StringName, object_2d: Node2D) -> void:
	var radius := _object_radius(object_2d)
	halo.closed = profile != &"flow"
	halo.points = _object_points(profile, radius)
	halo.width = object_halo_width * (1.35 if profile == &"horizon" else 1.0)
	var color := _object_color(profile)
	halo.default_color = Color(color.r, color.g, color.b, _safe_alpha(color.a, 0.28))


func _ensure_boss_silhouette(enemy: Node2D) -> void:
	if not enable_boss_silhouettes or not enemy.is_in_group("bosses") or not _readability_halos_enabled():
		return
	var id := enemy.get_instance_id()
	var profile := _profile_for_enemy(enemy)
	var existing := _boss_outlines.get(id, null) as Line2D
	if existing != null and is_instance_valid(existing):
		_update_boss_silhouette(existing, profile)
		return
	var outline := Line2D.new()
	outline.name = "BossSilhouetteOutline"
	outline.closed = true
	outline.antialiased = true
	outline.width = boss_silhouette_width
	outline.z_index = 17
	enemy.add_child(outline)
	_boss_outlines[id] = outline
	_update_boss_silhouette(outline, profile)


func _update_boss_silhouette(outline: Line2D, profile: StringName) -> void:
	outline.points = _boss_points_for_profile(profile)
	var color := _color_for_profile(profile)
	outline.default_color = Color(color.r, color.g, color.b, _safe_alpha(0.42, 0.42))


func _connect_accessibility_settings() -> void:
	if Settings == null or not Settings.has_signal("accessibility_changed"):
		return
	var callable := Callable(self, "_on_accessibility_changed")
	if not Settings.is_connected("accessibility_changed", callable):
		Settings.connect("accessibility_changed", callable)


func _on_accessibility_changed(_settings: Dictionary) -> void:
	_apply_readability_halo_setting()


func _apply_readability_halo_setting() -> void:
	if _readability_halos_enabled():
		return
	_clear_readability_halos()


func _readability_halos_enabled() -> bool:
	return Settings != null and bool(Settings.readability_halos_enabled)


func _clear_readability_halos() -> void:
	_clear_line_dictionary(_enemy_halos)
	_clear_line_dictionary(_boss_outlines)
	_clear_line_dictionary(_player_halos)
	_clear_line_dictionary(_object_halos)


func _clear_line_dictionary(nodes: Dictionary) -> void:
	for id in nodes.keys():
		var line = nodes[id]
		if line != null and is_instance_valid(line) and not line.is_queued_for_deletion():
			line.queue_free()
	nodes.clear()


func _profile_for_enemy(enemy: Node) -> StringName:
	var key := "%s %s" % [String(enemy.name).to_lower(), enemy.scene_file_path.to_lower()]
	if key.contains("leech") or key.contains("parasite"):
		return &"drain"
	if key.contains("null_harvester") or key.contains("harvester"):
		return &"drain"
	if key.contains("shield"):
		return &"shield"
	if key.contains("sniper") or key.contains("seraph"):
		return &"line"
	if key.contains("echo_drone") or key.contains("echo"):
		return &"echo"
	if key.contains("phase_slip") or key.contains("phase"):
		return &"phase"
	if key.contains("maw") or key.contains("accretion"):
		return &"drain"
	if key.contains("rift") or key.contains("weaver") or key.contains("magnetar") or key.contains("resonance"):
		return &"orbit"
	if key.contains("harasser") or key.contains("wisp") or key.contains("seeker"):
		return &"chaser"
	if key.contains("warden") or key.contains("magnetar") or key.contains("accretion") or key.contains("paralytic") or key.contains("construct"):
		return &"law"
	if key.contains("orbiter"):
		return &"orbit"
	return &"drifter"


func _profile_for_object(object_2d: Node) -> StringName:
	var key := "%s %s" % [String(object_2d.name).to_lower(), object_2d.scene_file_path.to_lower()]
	if key.contains("black") or key.contains("maw") or key.contains("singularity"):
		return &"horizon"
	if key.contains("tide") or key.contains("slip") or key.contains("flow"):
		return &"flow"
	if key.contains("wormhole") or key.contains("portal") or key.contains("tear"):
		return &"gate"
	if key.contains("moon") or key.contains("planet") or object_2d.is_in_group("planets"):
		return &"gravity"
	return &"field"


func _points_for_profile(profile: StringName) -> PackedVector2Array:
	match profile:
		&"drain":
			return PackedVector2Array([Vector2(-glyph_radius, 0.0), Vector2(0.0, -glyph_radius * 0.55), Vector2(glyph_radius, 0.0), Vector2(0.0, glyph_radius * 0.55), Vector2(-glyph_radius, 0.0)])
		&"shield":
			return _regular_points(6, glyph_radius)
		&"line":
			return PackedVector2Array([Vector2(-glyph_radius, 0.0), Vector2(glyph_radius, 0.0), Vector2(glyph_radius * 0.55, -glyph_radius * 0.34), Vector2(glyph_radius, 0.0), Vector2(glyph_radius * 0.55, glyph_radius * 0.34)])
		&"chaser":
			return PackedVector2Array([Vector2(-glyph_radius * 0.7, -glyph_radius * 0.55), Vector2(glyph_radius, 0.0), Vector2(-glyph_radius * 0.7, glyph_radius * 0.55), Vector2(-glyph_radius * 0.36, 0.0), Vector2(-glyph_radius * 0.7, -glyph_radius * 0.55)])
		&"echo":
			return PackedVector2Array([Vector2(-glyph_radius, -glyph_radius * 0.45), Vector2(-glyph_radius * 0.25, -glyph_radius * 0.45), Vector2(-glyph_radius * 0.25, glyph_radius * 0.45), Vector2(glyph_radius * 0.45, glyph_radius * 0.45), Vector2(glyph_radius * 0.45, -glyph_radius * 0.45), Vector2(glyph_radius, -glyph_radius * 0.45)])
		&"phase":
			return PackedVector2Array([Vector2(-glyph_radius, 0.0), Vector2(-glyph_radius * 0.25, -glyph_radius * 0.5), Vector2(glyph_radius * 0.25, glyph_radius * 0.5), Vector2(glyph_radius, 0.0)])
		&"law":
			return _regular_points(4, glyph_radius * 1.05)
		&"orbit":
			return _arc_points(glyph_radius, -PI * 0.85, PI * 0.85, 16)
	return _regular_points(3, glyph_radius)


func _boss_points_for_profile(profile: StringName) -> PackedVector2Array:
	match profile:
		&"line":
			return PackedVector2Array([
				Vector2(-boss_silhouette_radius * 1.15, 0.0),
				Vector2(-boss_silhouette_radius * 0.32, -boss_silhouette_radius * 0.68),
				Vector2(boss_silhouette_radius * 1.2, 0.0),
				Vector2(-boss_silhouette_radius * 0.32, boss_silhouette_radius * 0.68),
				Vector2(-boss_silhouette_radius * 1.15, 0.0),
			])
		&"drain":
			return PackedVector2Array([
				Vector2(0.0, -boss_silhouette_radius),
				Vector2(boss_silhouette_radius * 0.82, -boss_silhouette_radius * 0.28),
				Vector2(boss_silhouette_radius * 0.54, boss_silhouette_radius * 0.86),
				Vector2(-boss_silhouette_radius * 0.54, boss_silhouette_radius * 0.86),
				Vector2(-boss_silhouette_radius * 0.82, -boss_silhouette_radius * 0.28),
				Vector2(0.0, -boss_silhouette_radius),
			])
		&"orbit":
			return _regular_points(8, boss_silhouette_radius)
		&"phase":
			return PackedVector2Array([
				Vector2(-boss_silhouette_radius, -boss_silhouette_radius * 0.42),
				Vector2(-boss_silhouette_radius * 0.22, -boss_silhouette_radius),
				Vector2(boss_silhouette_radius * 0.18, -boss_silhouette_radius * 0.28),
				Vector2(boss_silhouette_radius, boss_silhouette_radius * 0.42),
				Vector2(boss_silhouette_radius * 0.22, boss_silhouette_radius),
				Vector2(-boss_silhouette_radius * 0.18, boss_silhouette_radius * 0.28),
				Vector2(-boss_silhouette_radius, -boss_silhouette_radius * 0.42),
			])
		&"law":
			return _regular_points(4, boss_silhouette_radius * 1.08)
	return _regular_points(6, boss_silhouette_radius)


func _halo_points(profile: StringName, radius: float) -> PackedVector2Array:
	match profile:
		&"line":
			return PackedVector2Array([
				Vector2(-radius * 1.08, 0.0),
				Vector2(-radius * 0.22, -radius * 0.72),
				Vector2(radius * 1.08, 0.0),
				Vector2(-radius * 0.22, radius * 0.72),
				Vector2(-radius * 1.08, 0.0),
			])
		&"phase":
			return PackedVector2Array([
				Vector2(-radius, -radius * 0.35),
				Vector2(-radius * 0.08, -radius),
				Vector2(radius, radius * 0.35),
				Vector2(radius * 0.08, radius),
				Vector2(-radius, -radius * 0.35),
			])
		&"orbit":
			return _arc_points(radius, -PI * 0.92, PI * 0.92, 22)
		&"drain":
			return _regular_points(5, radius)
		&"law":
			return _regular_points(4, radius * 1.08)
	return _regular_points(8, radius)


func _player_control_vector_points(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius * 0.24, -radius * 0.34),
		Vector2(radius, 0.0),
		Vector2(radius * 0.24, radius * 0.34),
		Vector2(0.0, radius),
		Vector2(-radius * 0.34, radius * 0.24),
		Vector2(-radius * 0.72, 0.0),
		Vector2(-radius * 0.34, -radius * 0.24),
		Vector2(0.0, -radius),
	])


func _object_points(profile: StringName, radius: float) -> PackedVector2Array:
	match profile:
		&"horizon":
			return _regular_points(12, radius)
		&"flow":
			return _arc_points(radius, -PI * 0.82, PI * 0.82, 24)
		&"gate":
			return PackedVector2Array([
				Vector2(0.0, -radius),
				Vector2(radius * 0.72, -radius * 0.18),
				Vector2(radius * 0.38, radius),
				Vector2(-radius * 0.38, radius),
				Vector2(-radius * 0.72, -radius * 0.18),
				Vector2(0.0, -radius),
			])
		&"gravity":
			return _regular_points(10, radius)
	return _regular_points(6, radius)


func _object_radius(object_2d: Node2D) -> float:
	if object_2d == null or not is_instance_valid(object_2d):
		return object_halo_radius
	var radius_value: Variant = object_2d.get("radius")
	if radius_value is float or radius_value is int:
		return clampf(float(radius_value) * maxf(object_2d.scale.x, object_2d.scale.y) + 22.0, 42.0, object_halo_radius * 2.4)
	var collision := object_2d.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return clampf((collision.shape as CircleShape2D).radius * maxf(object_2d.scale.x, object_2d.scale.y) + 22.0, 42.0, object_halo_radius * 2.4)
	return object_halo_radius


func _color_for_profile(profile: StringName) -> Color:
	match profile:
		&"drain":
			return Color(0.78, 0.42, 1.0, 0.82)
		&"shield":
			return Color(0.16, 0.95, 1.0, 0.82)
		&"line":
			return Color(1.0, 0.34, 0.28, 0.86)
		&"chaser":
			return Color(1.0, 0.34, 0.18, 0.86)
		&"echo":
			return Color(0.34, 0.9, 1.0, 0.84)
		&"phase":
			return Color(1.0, 0.18, 0.38, 0.86)
		&"law":
			return Color(0.95, 0.22, 0.18, 0.86)
		&"orbit":
			return Color(0.34, 0.68, 1.0, 0.82)
	return Color(0.64, 0.78, 0.86, 0.7)


func _object_color(profile: StringName) -> Color:
	match profile:
		&"horizon":
			return _readability_color(Color(1.0, 0.22, 0.12, 0.24))
		&"flow":
			return _readability_color(Color(0.2, 0.88, 1.0, 0.2))
		&"gate":
			return _readability_color(Color(0.72, 0.5, 1.0, 0.22))
		&"gravity":
			return _readability_color(Color(0.14, 0.95, 1.0, 0.2))
	return _readability_color(Color(0.62, 0.92, 1.0, 0.18))


func _readability_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _safe_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)


func _regular_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count + 1):
		var angle := -PI * 0.5 + TAU * float(i % count) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _arc_points(radius: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps):
		var t := float(i) / float(maxi(steps - 1, 1))
		var angle := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
