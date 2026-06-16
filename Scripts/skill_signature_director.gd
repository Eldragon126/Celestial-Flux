extends Node2D
class_name SkillSignatureDirector

signal signature_stamped(signature_data: Dictionary)

@export var enabled: bool = true
@export var min_signature_score: float = 0.82
@export var max_active_signatures: int = 10
@export var signature_lifetime: float = 5.5
@export var apex_lifetime_bonus: float = 2.0
@export var ring_segments: int = 42
@export var base_radius: float = 104.0
@export var vector_length: float = 260.0
@export var line_width: float = 2.4

var _player: Node = null
var _momentum: Node = null
var _inventory: Node = null
var _event_horizon: Node = null
var _signatures: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("skill_signature_director")
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		return
	_update_signatures(delta)


func _bootstrap() -> void:
	_resolve_sources()
	_connect_sources()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player")
	if _player != null:
		_momentum = _player.get_node_or_null("MomentumCombatComponent")
		_inventory = _player.get_node_or_null("PowerupInventory")
	if root != null:
		_event_horizon = root.find_child("EventHorizonDirector", true, false)


func _connect_sources() -> void:
	_connect_once(_player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))
	_connect_once(_momentum, &"kinetic_shockwave_created", Callable(self, "_on_kinetic_shockwave_created"))
	_connect_once(_inventory, &"apex_vector_released", Callable(self, "_on_apex_vector_released"))
	_connect_once(_event_horizon, &"horizon_escape_scored", Callable(self, "_on_horizon_escape_scored"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < min_signature_score:
		return

	var player_2d := _player as Node2D
	var fallback := player_2d.global_position if player_2d != null else global_position
	var position: Vector2 = data.get("position", fallback)
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT

	var grade := StringName(data.get("grade", &"perfect"))
	var color := Color(0.34, 1.0, 0.86, 1.0) if grade != &"apex" else Color(1.0, 0.86, 0.28, 1.0)
	var radius := base_radius * lerpf(0.9, 1.55, score)
	var lifetime := signature_lifetime + (apex_lifetime_bonus if grade == &"apex" else 0.0)
	_stamp_signature(position, tangent.normalized(), radius, color, lifetime, &"slingshot")


func _on_kinetic_shockwave_created(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", Vector2.ZERO)
	var speed := float(data.get("speed", 0.0))
	if speed < 1200.0:
		return
	var tangent: Vector2 = data.get("velocity", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	_stamp_signature(position, tangent.normalized(), base_radius * 1.28, Color(1.0, 0.58, 0.22, 1.0), signature_lifetime * 0.72, &"impact")


func _on_apex_vector_released(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", Vector2.ZERO)
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	var radius := float(data.get("radius", base_radius * 2.0)) * 0.42
	_stamp_signature(position, tangent.normalized(), radius, Color(0.36, 1.0, 0.84, 1.0), signature_lifetime + apex_lifetime_bonus, &"apex_vector")


func _on_horizon_escape_scored(data: Dictionary) -> void:
	var player_2d := _player as Node2D
	var position: Vector2 = player_2d.global_position if player_2d != null else data.get("position", Vector2.ZERO)
	var tangent: Vector2 = data.get("escape_vector", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001 and player_2d != null:
		var velocity_value: Variant = player_2d.get("velocity")
		if velocity_value is Vector2:
			tangent = velocity_value.normalized()
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	_stamp_signature(position, tangent.normalized(), base_radius * 1.8, Color(0.82, 0.42, 1.0, 1.0), signature_lifetime + 1.2, &"horizon_escape")


func _stamp_signature(
	position: Vector2,
	tangent: Vector2,
	radius: float,
	color: Color,
	lifetime: float,
	signature_id: StringName
) -> void:
	if not enabled:
		return
	_trim_signature_count()

	var holder := Node2D.new()
	holder.name = "SkillSignature"
	holder.global_position = position
	holder.z_index = 34
	add_child(holder)

	var ring := Line2D.new()
	ring.name = "OrbitGlyph"
	ring.closed = true
	ring.antialiased = true
	ring.width = line_width
	ring.default_color = _safe_color(color, 0.64)
	ring.points = _circle_points(ring_segments, radius)
	holder.add_child(ring)

	var vector := Line2D.new()
	vector.name = "VectorEcho"
	vector.antialiased = true
	vector.width = line_width * 0.82
	vector.default_color = _safe_color(color, 0.72)
	vector.points = PackedVector2Array([
		-tangent * vector_length * 0.28,
		tangent * vector_length,
	])
	holder.add_child(vector)

	var cross := Line2D.new()
	cross.name = "CrossAxis"
	cross.antialiased = true
	cross.width = line_width * 0.48
	cross.default_color = _safe_color(Color.WHITE, 0.34)
	var normal := tangent.orthogonal()
	cross.points = PackedVector2Array([
		-normal * radius * 0.64,
		normal * radius * 0.64,
	])
	holder.add_child(cross)

	_signatures.append({
		"node": holder,
		"age": 0.0,
		"lifetime": maxf(lifetime, 0.2),
		"radius": radius,
		"color": color,
		"id": signature_id,
	})
	signature_stamped.emit({
		"position": position,
		"tangent": tangent,
		"radius": radius,
		"signature_id": signature_id,
	})


func _trim_signature_count() -> void:
	while _signatures.size() >= max_active_signatures and not _signatures.is_empty():
		var oldest := _signatures.pop_front() as Dictionary
		var node := oldest.get("node") as Node
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()


func _update_signatures(delta: float) -> void:
	for i in range(_signatures.size() - 1, -1, -1):
		var entry := _signatures[i]
		var node := entry.get("node") as Node2D
		if node == null or not is_instance_valid(node):
			_signatures.remove_at(i)
			continue

		var lifetime := maxf(float(entry.get("lifetime", signature_lifetime)), 0.1)
		var age := float(entry.get("age", 0.0)) + delta
		var t := clampf(age / lifetime, 0.0, 1.0)
		var alpha := pow(1.0 - t, 1.25)
		node.modulate.a = alpha
		node.rotation += delta * lerpf(0.16, 0.52, t)
		node.scale = Vector2.ONE * lerpf(0.96, 1.18, t)
		entry["age"] = age
		_signatures[i] = entry

		if age >= lifetime:
			if not node.is_queued_for_deletion():
				node.queue_free()
			_signatures.remove_at(i)


func _safe_color(color: Color, alpha_cap: float) -> Color:
	var alpha := minf(color.a, alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 3)):
		var angle := TAU * float(i) / float(maxi(count, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
