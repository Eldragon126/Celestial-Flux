extends Node
class_name EnemyReadabilityDirector

## Adds small role glyphs to enemies so silhouettes communicate behavior fast.
## The markers are cheap Line2D children and update on a capped cadence.

@export var enabled: bool = true
@export var scan_interval: float = 0.55
@export var max_marked_enemies: int = 42
@export var glyph_radius: float = 28.0
@export var glyph_width: float = 2.4

var _elapsed := 999.0
var _marked: Dictionary = {}


func _ready() -> void:
	add_to_group("enemy_readability_director")
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
	var enemies := get_tree().get_nodes_in_group("enemies")
	var marked_this_pass := 0
	var live_ids := {}

	for enemy in enemies:
		if marked_this_pass >= max_marked_enemies:
			break
		var enemy_2d := enemy as Node2D
		if enemy_2d == null or not is_instance_valid(enemy_2d) or enemy_2d.is_queued_for_deletion():
			continue
		if enemy_2d.is_in_group("Player"):
			continue

		var id := enemy_2d.get_instance_id()
		live_ids[id] = true
		_ensure_glyph(enemy_2d)
		marked_this_pass += 1

	for id in _marked.keys():
		if live_ids.has(id):
			continue
		var marker = _marked[id]
		if is_instance_valid(marker):
			marker.queue_free()
		_marked.erase(id)


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


func _update_glyph(glyph: Line2D, profile: StringName) -> void:
	glyph.points = _points_for_profile(profile)
	glyph.default_color = _color_for_profile(profile)


func _profile_for_enemy(enemy: Node) -> StringName:
	var key := "%s %s" % [String(enemy.name).to_lower(), enemy.scene_file_path.to_lower()]
	if key.contains("leech") or key.contains("parasite"):
		return &"drain"
	if key.contains("shield"):
		return &"shield"
	if key.contains("sniper") or key.contains("seraph"):
		return &"line"
	if key.contains("harasser") or key.contains("wisp") or key.contains("seeker"):
		return &"chaser"
	if key.contains("warden") or key.contains("magnetar") or key.contains("accretion"):
		return &"law"
	if key.contains("orbiter"):
		return &"orbit"
	return &"drifter"


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
		&"law":
			return _regular_points(4, glyph_radius * 1.05)
		&"orbit":
			return _arc_points(glyph_radius, -PI * 0.85, PI * 0.85, 16)
	return _regular_points(3, glyph_radius)


func _color_for_profile(profile: StringName) -> Color:
	match profile:
		&"drain":
			return Color(0.78, 0.42, 1.0, 0.82)
		&"shield":
			return Color(0.16, 0.95, 1.0, 0.82)
		&"line":
			return Color(1.0, 0.34, 0.28, 0.86)
		&"chaser":
			return Color(1.0, 0.76, 0.24, 0.84)
		&"law":
			return Color(0.42, 1.0, 0.74, 0.86)
		&"orbit":
			return Color(0.34, 0.68, 1.0, 0.82)
	return Color(0.64, 0.78, 0.86, 0.7)


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
