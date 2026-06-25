extends CanvasLayer
class_name DamageIndicatorManager

signal damage_feedback_emitted(data: Dictionary)

@export var enabled: bool = true
@export var pool_size: int = 72
@export var max_indicators_per_frame: int = 12
@export var indicator_lifetime: float = 0.72
@export var drift_distance: float = 54.0
@export var merge_window_seconds: float = 0.08
@export var large_hit_threshold: float = 32.0
@export var final_blow_threshold: float = 0.01
@export var ring_lifetime: float = 0.28
@export var ring_segments: int = 42
@export var ring_base_radius: float = 26.0
@export var target_flash_strength: float = 0.52
@export var target_flash_duration: float = 0.14
@export var screen_jitter: float = 12.0
@export var normal_damage_color: Color = Color(0.76, 1.0, 0.96, 1.0)
@export var player_damage_color: Color = Color(1.0, 0.24, 0.14, 1.0)
@export var momentum_damage_color: Color = Color(1.0, 0.78, 0.24, 1.0)
@export var gravity_damage_color: Color = Color(0.34, 1.0, 0.84, 1.0)
@export var temporal_damage_color: Color = Color(0.74, 0.44, 1.0, 1.0)
@export var final_blow_color: Color = Color(1.0, 0.95, 0.36, 1.0)

var _indicator_pool: Array[Label] = []
var _active_indicators: Array[Dictionary] = []
var _ring_pool: Array[Line2D] = []
var _active_rings: Array[Dictionary] = []
var _merge_cache: Dictionary = {}
var _shown_this_frame: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 58
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("damage_feedback_manager")
	_rng.randomize()
	_prewarm_pool()


func _process(delta: float) -> void:
	_shown_this_frame = 0
	_update_indicators(delta)
	_update_rings(delta)
	_prune_merge_cache()


func show_damage(target: Node, amount: float, context: Dictionary = {}) -> void:
	if not enabled or amount <= 0.0 or target == null or not is_instance_valid(target):
		return
	var resolved := _normalize_context(target, amount, context)
	var target_position := _target_world_position(target, resolved)
	_apply_target_flash(target, resolved)
	if _should_show_number(amount, resolved):
		_spawn_indicator(target, target_position, amount, resolved)
	if _should_spawn_ring(amount, resolved):
		_spawn_impact_ring(target_position, amount, resolved)
	damage_feedback_emitted.emit({
		"target": target,
		"amount": amount,
		"context": resolved,
		"position": target_position,
	})


func _prewarm_pool() -> void:
	for _i in range(maxi(pool_size, 0)):
		var label := _make_indicator_label()
		_indicator_pool.append(label)
		add_child(label)
	for _i in range(maxi(int(pool_size * 0.35), 6)):
		var ring := _make_ring()
		_ring_pool.append(ring)
		add_child(ring)


func _make_indicator_label() -> Label:
	var label := Label.new()
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
	label.add_theme_constant_override("outline_size", 5)
	label.custom_minimum_size = Vector2(96.0, 28.0)
	label.pivot_offset = Vector2(48.0, 14.0)
	return label


func _make_ring() -> Line2D:
	var ring := Line2D.new()
	ring.visible = false
	ring.closed = true
	ring.antialiased = true
	ring.width = 2.0
	ring.points = _circle_points(ring_segments, ring_base_radius)
	return ring


func _normalize_context(target: Node, amount: float, context: Dictionary) -> Dictionary:
	var resolved := context.duplicate(true)
	if not resolved.has("damage_type"):
		resolved["damage_type"] = _infer_damage_type(target)
	resolved["amount"] = amount
	resolved["is_player_target"] = target.is_in_group("Player") or target.is_in_group("player_allies")
	resolved["is_large_hit"] = amount >= large_hit_threshold
	resolved["was_final_blow"] = bool(resolved.get("was_final_blow", false))
	resolved["was_momentum_hit"] = bool(resolved.get("was_momentum_hit", false))
	resolved["was_apex"] = bool(resolved.get("was_apex", false))
	resolved["was_slingshot_hit"] = bool(resolved.get("was_slingshot_hit", false))
	return resolved


func _infer_damage_type(target: Node) -> StringName:
	var weapon_id := ""
	if target.has_meta(&"last_player_weapon_id"):
		weapon_id = String(target.get_meta(&"last_player_weapon_id", ""))
	weapon_id = weapon_id.to_lower()
	if weapon_id.contains("gravity") or weapon_id.contains("singularity") or weapon_id.contains("resonance"):
		return &"gravity"
	if weapon_id.contains("time") or weapon_id.contains("chronal") or weapon_id.contains("temporal"):
		return &"temporal"
	if weapon_id.contains("beam"):
		return &"beam"
	return &"projectile"


func _target_world_position(target: Node, context: Dictionary) -> Vector2:
	var hit_position: Variant = context.get("hit_position", null)
	if hit_position is Vector2:
		return hit_position
	var target_2d := target as Node2D
	if target_2d != null:
		return target_2d.global_position
	return Vector2.ZERO


func _should_show_number(amount: float, context: Dictionary) -> bool:
	if _shown_this_frame >= max_indicators_per_frame:
		return false
	match _damage_numbers_mode():
		0:
			return false
		1:
			return bool(context.get("is_player_target", false)) or bool(context.get("is_large_hit", false)) or bool(context.get("was_final_blow", false)) or bool(context.get("was_momentum_hit", false))
	return amount > 0.0


func _should_spawn_ring(amount: float, context: Dictionary) -> bool:
	if _combat_particles_mode() == 0 and not bool(context.get("was_final_blow", false)):
		return false
	return (
		bool(context.get("was_final_blow", false))
		or bool(context.get("was_momentum_hit", false))
		or bool(context.get("was_apex", false))
		or amount >= large_hit_threshold
	)


func _spawn_indicator(target: Node, world_position: Vector2, amount: float, context: Dictionary) -> void:
	var merge_key := target.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var cached: Dictionary = _merge_cache.get(merge_key, {})
	if not cached.is_empty() and now - float(cached.get("time", 0.0)) <= merge_window_seconds:
		var cached_label := cached.get("label", null) as Label
		if cached_label != null and is_instance_valid(cached_label):
			var total := float(cached.get("amount", 0.0)) + amount
			cached["amount"] = total
			cached["time"] = now
			cached_label.text = _label_text(total, context)
			_merge_cache[merge_key] = cached
			return

	var label := _claim_indicator_label()
	if label == null:
		return
	var color := _damage_color(context)
	var screen_offset := Vector2(_rng.randf_range(-screen_jitter, screen_jitter), -screen_jitter)
	label.text = _label_text(amount, context)
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	label.position = _indicator_screen_position(world_position, screen_offset, 0.0)
	label.scale = Vector2.ONE * (1.12 if bool(context.get("is_large_hit", false)) else 1.0)
	label.visible = true
	_active_indicators.append({
		"label": label,
		"age": 0.0,
		"world_position": world_position,
		"screen_offset": screen_offset,
		"color": color,
		"rise": drift_distance * _rng.randf_range(0.82, 1.18),
	})
	_merge_cache[merge_key] = {"label": label, "amount": amount, "time": now}
	_shown_this_frame += 1


func _label_text(amount: float, context: Dictionary) -> String:
	var value := int(round(amount))
	if bool(context.get("was_final_blow", false)):
		return "BREAK %d" % value
	if bool(context.get("was_apex", false)):
		return "APEX %d" % value
	if bool(context.get("was_momentum_hit", false)):
		return "KINETIC %d" % value
	if _skill_callout_mode() == 2 and bool(context.get("was_slingshot_hit", false)):
		return "SLING %d" % value
	return "%d" % value


func _claim_indicator_label() -> Label:
	for label in _indicator_pool:
		if label != null and not label.visible:
			return label
	var label := _make_indicator_label()
	_indicator_pool.append(label)
	add_child(label)
	return label


func _spawn_impact_ring(world_position: Vector2, amount: float, context: Dictionary) -> void:
	var ring := _claim_ring()
	if ring == null:
		return
	var color := _damage_color(context)
	var strength := clampf(amount / maxf(large_hit_threshold, 1.0), 0.75, 2.4)
	ring.position = _world_to_screen(world_position)
	ring.scale = Vector2.ONE * 0.35
	ring.default_color = Color(color.r, color.g, color.b, 0.38)
	ring.width = 1.6 + strength
	ring.visible = true
	_active_rings.append({
		"ring": ring,
		"age": 0.0,
		"world_position": world_position,
		"radius": ring_base_radius * (2.2 + strength),
		"color": color,
	})


func _claim_ring() -> Line2D:
	for ring in _ring_pool:
		if ring != null and not ring.visible:
			return ring
	var ring := _make_ring()
	_ring_pool.append(ring)
	add_child(ring)
	return ring


func _apply_target_flash(target: Node, context: Dictionary) -> void:
	if _hit_flash_mode() == 0 and not bool(context.get("is_player_target", false)):
		return
	var canvas := target as CanvasItem
	if canvas == null:
		return
	var base_color := canvas.modulate
	var flash_color := _damage_color(context)
	var strength := target_flash_strength
	if Settings != null and bool(Settings.reduce_flash):
		strength *= 0.42
	if _hit_flash_mode() == 0:
		strength *= 0.45
	var target_color := base_color.lerp(Color(flash_color.r, flash_color.g, flash_color.b, base_color.a), clampf(strength, 0.0, 0.85))
	var tween := canvas.create_tween()
	tween.tween_property(canvas, "modulate", target_color, minf(target_flash_duration * 0.36, 0.06))
	tween.tween_property(canvas, "modulate", base_color, target_flash_duration)


func _update_indicators(delta: float) -> void:
	for index in range(_active_indicators.size() - 1, -1, -1):
		var data := _active_indicators[index]
		var label := data.get("label", null) as Label
		if label == null or not is_instance_valid(label):
			_active_indicators.remove_at(index)
			continue
		var age := float(data.get("age", 0.0)) + delta
		var t := clampf(age / maxf(indicator_lifetime, 0.01), 0.0, 1.0)
		var world_position: Vector2 = data.get("world_position", _screen_to_world(label.position))
		var screen_offset: Vector2 = data.get("screen_offset", Vector2.ZERO)
		var rise := float(data.get("rise", drift_distance))
		var color: Color = data.get("color", normal_damage_color)
		label.position = _indicator_screen_position(world_position, screen_offset, rise * t)
		label.modulate = Color(color.r, color.g, color.b, 1.0 - smoothstep(0.62, 1.0, t))
		label.scale = Vector2.ONE * lerpf(1.08, 0.88, t)
		data["age"] = age
		_active_indicators[index] = data
		if age >= indicator_lifetime:
			label.visible = false
			_active_indicators.remove_at(index)


func _update_rings(delta: float) -> void:
	for index in range(_active_rings.size() - 1, -1, -1):
		var data := _active_rings[index]
		var ring := data.get("ring", null) as Line2D
		if ring == null or not is_instance_valid(ring):
			_active_rings.remove_at(index)
			continue
		var age := float(data.get("age", 0.0)) + delta
		var t := clampf(age / maxf(ring_lifetime, 0.01), 0.0, 1.0)
		var world_position: Vector2 = data.get("world_position", _screen_to_world(ring.position))
		var radius := float(data.get("radius", ring_base_radius))
		var color: Color = data.get("color", normal_damage_color)
		ring.position = _world_to_screen(world_position)
		ring.scale = Vector2.ONE * lerpf(0.45, maxf(radius / maxf(ring_base_radius, 1.0), 1.0), t)
		ring.default_color = Color(color.r, color.g, color.b, (1.0 - t) * 0.36)
		data["age"] = age
		_active_rings[index] = data
		if age >= ring_lifetime:
			ring.visible = false
			_active_rings.remove_at(index)


func _prune_merge_cache() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for key in _merge_cache.keys():
		var cached: Dictionary = _merge_cache.get(key, {})
		var label := cached.get("label", null) as Label
		if now - float(cached.get("time", 0.0)) > merge_window_seconds or label == null or not is_instance_valid(label) or not label.visible:
			_merge_cache.erase(key)


func _damage_color(context: Dictionary) -> Color:
	if bool(context.get("was_final_blow", false)):
		return _safe_color(final_blow_color)
	if bool(context.get("is_player_target", false)):
		return _safe_color(player_damage_color)
	if bool(context.get("was_momentum_hit", false)):
		return _safe_color(momentum_damage_color)
	match StringName(context.get("damage_type", &"projectile")):
		&"gravity":
			return _safe_color(gravity_damage_color)
		&"temporal":
			return _safe_color(temporal_damage_color)
	return _safe_color(normal_damage_color)


func _safe_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _world_to_screen(world_position: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_position
	return viewport.get_canvas_transform() * world_position


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return screen_position
	return viewport.get_canvas_transform().affine_inverse() * screen_position


func _indicator_screen_position(world_position: Vector2, screen_offset: Vector2, rise: float) -> Vector2:
	return _world_to_screen(world_position) + screen_offset + Vector2(0.0, -rise)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 8)):
		var angle := TAU * float(i) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _damage_numbers_mode() -> int:
	if Settings != null and Settings.get("damage_numbers_mode") != null:
		return int(Settings.damage_numbers_mode)
	return 2


func _hit_flash_mode() -> int:
	if Settings != null and Settings.get("hit_flash_mode") != null:
		return int(Settings.hit_flash_mode)
	return 1


func _skill_callout_mode() -> int:
	if Settings != null and Settings.get("skill_callout_mode") != null:
		return int(Settings.skill_callout_mode)
	return 2


func _combat_particles_mode() -> int:
	if Settings != null and Settings.get("combat_particles_mode") != null:
		return int(Settings.combat_particles_mode)
	return 1
