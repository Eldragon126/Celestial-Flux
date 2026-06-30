extends CanvasLayer
class_name DamageIndicatorManager

signal damage_feedback_emitted(data: Dictionary)

@export var enabled: bool = true
@export_group("Pool Budgets")
@export var pool_size: int = 72
@export var allow_pool_growth: bool = true
@export var max_indicator_pool_size: int = 112
@export var max_ring_pool_size: int = 42
@export var max_streak_pool_size: int = 38
@export_group("Frame Budgets")
@export var max_indicators_per_frame: int = 12
@export var max_rings_per_frame: int = 8
@export var max_streaks_per_frame: int = 8
@export var max_target_flashes_per_frame: int = 16
@export_group("Indicator Motion")
@export var indicator_lifetime: float = 0.72
@export var drift_distance: float = 54.0
@export var merge_window_seconds: float = 0.08
@export var weapon_context_memory_seconds: float = 0.35
@export var large_hit_threshold: float = 32.0
@export var final_blow_threshold: float = 0.01
@export var health_state_marker_lifetime: float = 0.86
@export_group("Impact Rings")
@export var ring_lifetime: float = 0.28
@export var ring_segments: int = 42
@export var ring_base_radius: float = 26.0
@export_group("Directional Streaks")
@export var enable_direction_streaks: bool = true
@export var streak_lifetime: float = 0.22
@export var streak_length: float = 72.0
@export var streak_width: float = 4.0
@export_group("Target Reaction")
@export var target_flash_strength: float = 0.52
@export var target_flash_duration: float = 0.14
@export var enable_feedback_recoil: bool = true
@export var feedback_recoil_strength: float = 38.0
@export var feedback_recoil_large_hit_scale: float = 2.15
@export var feedback_recoil_max_impulse: float = 165.0
@export var feedback_recoil_on_bosses: bool = false
@export var screen_jitter: float = 12.0
@export_group("Damage Colors")
@export var normal_damage_color: Color = Color(0.76, 1.0, 0.96, 1.0)
@export var player_damage_color: Color = Color(1.0, 0.24, 0.14, 1.0)
@export var momentum_damage_color: Color = Color(1.0, 0.78, 0.24, 1.0)
@export var gravity_damage_color: Color = Color(0.34, 1.0, 0.84, 1.0)
@export var temporal_damage_color: Color = Color(0.74, 0.44, 1.0, 1.0)
@export var beam_damage_color: Color = Color(0.28, 0.92, 1.0, 1.0)
@export var shield_damage_color: Color = Color(0.42, 0.68, 1.0, 1.0)
@export var armor_damage_color: Color = Color(1.0, 0.56, 0.22, 1.0)
@export var modded_damage_color: Color = Color(0.62, 1.0, 0.5, 1.0)
@export var final_blow_color: Color = Color(1.0, 0.95, 0.36, 1.0)

var _indicator_pool: Array[Label] = []
var _active_indicators: Array[Dictionary] = []
var _ring_pool: Array[Line2D] = []
var _active_rings: Array[Dictionary] = []
var _streak_pool: Array[Line2D] = []
var _active_streaks: Array[Dictionary] = []
var _merge_cache: Dictionary = {}
var _shown_this_frame: int = 0
var _rings_this_frame: int = 0
var _streaks_this_frame: int = 0
var _flashes_this_frame: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 58
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("damage_feedback_manager")
	_rng.randomize()
	_prewarm_pool()


func _process(delta: float) -> void:
	_shown_this_frame = 0
	_rings_this_frame = 0
	_streaks_this_frame = 0
	_flashes_this_frame = 0
	_update_indicators(delta)
	_update_rings(delta)
	_update_streaks(delta)
	_prune_merge_cache()


func show_damage(target: Node, amount: float, context: Dictionary = {}) -> void:
	if not enabled or amount <= 0.0 or target == null or not is_instance_valid(target):
		return
	var resolved := _normalize_context(target, amount, context)
	var target_position := _target_world_position(target, resolved)
	_apply_target_flash(target, resolved)
	_apply_feedback_recoil(target, amount, resolved)
	if _should_show_number(amount, resolved):
		_spawn_indicator(target, target_position, amount, resolved)
	if _should_show_health_state_marker(resolved):
		_spawn_status_marker(target, target_position, resolved)
	if _should_spawn_ring(amount, resolved):
		_spawn_impact_ring(target_position, amount, resolved)
	if _should_spawn_streak(amount, resolved):
		_spawn_direction_streak(target_position, amount, resolved)
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
	for _i in range(maxi(int(pool_size * 0.28), 6)):
		var streak := _make_streak()
		_streak_pool.append(streak)
		add_child(streak)


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


func _make_streak() -> Line2D:
	var streak := Line2D.new()
	streak.visible = false
	streak.closed = false
	streak.antialiased = true
	streak.width = streak_width
	streak.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * streak_length])
	return streak


func _normalize_context(target: Node, amount: float, context: Dictionary) -> Dictionary:
	var resolved := context.duplicate(true)
	if not resolved.has("damage_type"):
		resolved["damage_type"] = _infer_damage_type(target)
	resolved["amount"] = amount
	resolved["is_player_target"] = target.is_in_group("Player") or target.is_in_group("player_allies")
	resolved["is_boss_target"] = target.is_in_group("bosses")
	resolved["is_large_hit"] = amount >= large_hit_threshold
	resolved["was_final_blow"] = bool(resolved.get("was_final_blow", false))
	resolved["was_momentum_hit"] = bool(resolved.get("was_momentum_hit", false))
	resolved["was_apex"] = bool(resolved.get("was_apex", false))
	resolved["was_slingshot_hit"] = bool(resolved.get("was_slingshot_hit", false))
	resolved["was_critical"] = bool(resolved.get("was_critical", false))
	resolved["was_shield_hit"] = bool(resolved.get("was_shield_hit", false))
	resolved["was_shield_break"] = bool(resolved.get("was_shield_break", false))
	resolved["was_armor_hit"] = bool(resolved.get("was_armor_hit", false))
	resolved["mod_source"] = String(resolved.get("mod_source", ""))
	if not resolved.has("health_ratio"):
		resolved["health_ratio"] = 1.0
	if not resolved.has("previous_health_ratio"):
		resolved["previous_health_ratio"] = resolved["health_ratio"]
	if not resolved.has("health_state"):
		resolved["health_state"] = _health_state_from_ratio(float(resolved.get("health_ratio", 1.0)))
	if not resolved.has("previous_health_state"):
		resolved["previous_health_state"] = _health_state_from_ratio(float(resolved.get("previous_health_ratio", 1.0)))
	return resolved


func _infer_damage_type(target: Node) -> StringName:
	var weapon_id := ""
	if target.has_meta(&"last_player_weapon_id"):
		var hit_time := float(target.get_meta(&"last_player_weapon_hit_time", -999.0))
		var age := Time.get_ticks_msec() / 1000.0 - hit_time
		if age > weapon_context_memory_seconds:
			return &"projectile"
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
	if _rings_this_frame >= max_rings_per_frame:
		return false
	if _combat_particles_mode() == 0 and not bool(context.get("was_final_blow", false)):
		return false
	return (
		bool(context.get("was_final_blow", false))
		or bool(context.get("was_momentum_hit", false))
		or bool(context.get("was_apex", false))
		or bool(context.get("was_critical", false))
		or bool(context.get("was_shield_break", false))
		or amount >= large_hit_threshold
	)


func _should_spawn_streak(amount: float, context: Dictionary) -> bool:
	if not enable_direction_streaks or _streaks_this_frame >= max_streaks_per_frame:
		return false
	if _combat_particles_mode() == 0:
		return false
	return (
		bool(context.get("was_final_blow", false))
		or bool(context.get("was_momentum_hit", false))
		or bool(context.get("was_apex", false))
		or bool(context.get("was_critical", false))
		or amount >= large_hit_threshold
	)


func _should_show_health_state_marker(context: Dictionary) -> bool:
	if _damage_numbers_mode() == 0:
		return false
	var previous := StringName(context.get("previous_health_state", &"stable"))
	var current := StringName(context.get("health_state", &"stable"))
	if previous == current:
		return false
	return current == &"fractured" or current == &"critical" or current == &"destroyed"


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


func _spawn_status_marker(target: Node, world_position: Vector2, context: Dictionary) -> void:
	if _shown_this_frame >= max_indicators_per_frame:
		return
	var label := _claim_indicator_label()
	if label == null:
		return
	var text := _health_state_text(StringName(context.get("health_state", &"stable")))
	if text.is_empty():
		return
	var color := _damage_color(context)
	var screen_offset := Vector2(_rng.randf_range(-8.0, 8.0), 18.0)
	label.text = text
	label.modulate = Color(color.r, color.g, color.b, 0.94)
	label.position = _indicator_screen_position(world_position, screen_offset, 0.0)
	label.scale = Vector2.ONE * 0.92
	label.visible = true
	_active_indicators.append({
		"label": label,
		"age": 0.0,
		"lifetime": health_state_marker_lifetime,
		"world_position": world_position,
		"screen_offset": screen_offset,
		"color": color,
		"rise": drift_distance * 0.62,
	})
	_shown_this_frame += 1


func _label_text(amount: float, context: Dictionary) -> String:
	var value := int(round(amount))
	if bool(context.get("was_final_blow", false)):
		return "BREAK %d" % value
	if bool(context.get("was_shield_break", false)):
		return "SHIELD BREAK"
	if bool(context.get("was_critical", false)):
		return "CRIT %d" % value
	if bool(context.get("was_apex", false)):
		return "APEX %d" % value
	if bool(context.get("was_momentum_hit", false)):
		return "KINETIC %d" % value
	if _skill_callout_mode() == 2 and bool(context.get("was_slingshot_hit", false)):
		return "SLING %d" % value
	match StringName(context.get("damage_type", &"projectile")):
		&"gravity":
			return "CRUSH %d" % value if bool(context.get("is_large_hit", false)) else "%d" % value
		&"temporal":
			return "PHASE %d" % value if bool(context.get("is_large_hit", false)) else "%d" % value
		&"beam":
			return "BEAM %d" % value if bool(context.get("is_large_hit", false)) else "%d" % value
	if bool(context.get("was_armor_hit", false)):
		return "ARMOR %d" % value
	if bool(context.get("was_shield_hit", false)):
		return "SHIELD %d" % value
	return "%d" % value


func _claim_indicator_label() -> Label:
	for label in _indicator_pool:
		if label != null and not label.visible:
			return label
	if not allow_pool_growth or _indicator_pool.size() >= max_indicator_pool_size:
		return null
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
	_rings_this_frame += 1


func _claim_ring() -> Line2D:
	for ring in _ring_pool:
		if ring != null and not ring.visible:
			return ring
	if not allow_pool_growth or _ring_pool.size() >= max_ring_pool_size:
		return null
	var ring := _make_ring()
	_ring_pool.append(ring)
	add_child(ring)
	return ring


func _spawn_direction_streak(world_position: Vector2, amount: float, context: Dictionary) -> void:
	var streak := _claim_streak()
	if streak == null:
		return
	var direction := _hit_direction(context)
	var color := _damage_color(context)
	var strength := clampf(amount / maxf(large_hit_threshold, 1.0), 0.7, 2.25)
	var half_length := streak_length * strength * 0.5
	var normal := direction.orthogonal()
	streak.points = PackedVector2Array([
		-direction * half_length - normal * streak_width,
		direction * half_length + normal * streak_width,
	])
	streak.position = _world_to_screen(world_position)
	streak.width = streak_width * (1.0 + strength * 0.28)
	streak.default_color = Color(color.r, color.g, color.b, 0.46)
	streak.visible = true
	_active_streaks.append({
		"streak": streak,
		"age": 0.0,
		"world_position": world_position,
		"direction": direction,
		"color": color,
		"strength": strength,
	})
	_streaks_this_frame += 1


func _claim_streak() -> Line2D:
	for streak in _streak_pool:
		if streak != null and not streak.visible:
			return streak
	if not allow_pool_growth or _streak_pool.size() >= max_streak_pool_size:
		return null
	var streak := _make_streak()
	_streak_pool.append(streak)
	add_child(streak)
	return streak


func _apply_target_flash(target: Node, context: Dictionary) -> void:
	if _hit_flash_mode() == 0 and not bool(context.get("is_player_target", false)):
		return
	if _flashes_this_frame >= max_target_flashes_per_frame:
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
	_flashes_this_frame += 1


func _apply_feedback_recoil(target: Node, amount: float, context: Dictionary) -> void:
	if not enable_feedback_recoil:
		return
	if bool(context.get("is_player_target", false)):
		return
	if bool(context.get("is_boss_target", false)) and not feedback_recoil_on_bosses:
		return
	if not _should_spawn_streak(amount, context):
		return
	var impulse_scale := 1.0
	if bool(context.get("is_large_hit", false)):
		impulse_scale *= feedback_recoil_large_hit_scale
	if bool(context.get("was_momentum_hit", false)) or bool(context.get("was_apex", false)):
		impulse_scale *= 1.55
	var impulse := _hit_direction(context) * clampf(feedback_recoil_strength * impulse_scale, 0.0, feedback_recoil_max_impulse)
	CombatStatus.add_velocity(target, impulse)


func _update_indicators(delta: float) -> void:
	for index in range(_active_indicators.size() - 1, -1, -1):
		var data := _active_indicators[index]
		var label := data.get("label", null) as Label
		if label == null or not is_instance_valid(label):
			_active_indicators.remove_at(index)
			continue
		var age := float(data.get("age", 0.0)) + delta
		var lifetime := float(data.get("lifetime", indicator_lifetime))
		var t := clampf(age / maxf(lifetime, 0.01), 0.0, 1.0)
		var world_position: Vector2 = data.get("world_position", _screen_to_world(label.position))
		var screen_offset: Vector2 = data.get("screen_offset", Vector2.ZERO)
		var rise := float(data.get("rise", drift_distance))
		var color: Color = data.get("color", normal_damage_color)
		label.position = _indicator_screen_position(world_position, screen_offset, rise * t)
		label.modulate = Color(color.r, color.g, color.b, 1.0 - smoothstep(0.62, 1.0, t))
		label.scale = Vector2.ONE * lerpf(1.08, 0.88, t)
		data["age"] = age
		_active_indicators[index] = data
		if age >= lifetime:
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


func _update_streaks(delta: float) -> void:
	for index in range(_active_streaks.size() - 1, -1, -1):
		var data := _active_streaks[index]
		var streak := data.get("streak", null) as Line2D
		if streak == null or not is_instance_valid(streak):
			_active_streaks.remove_at(index)
			continue
		var age := float(data.get("age", 0.0)) + delta
		var t := clampf(age / maxf(streak_lifetime, 0.01), 0.0, 1.0)
		var world_position: Vector2 = data.get("world_position", _screen_to_world(streak.position))
		var color: Color = data.get("color", normal_damage_color)
		var strength := float(data.get("strength", 1.0))
		streak.position = _world_to_screen(world_position)
		streak.scale = Vector2.ONE * lerpf(0.8, 1.18 + strength * 0.1, t)
		streak.default_color = Color(color.r, color.g, color.b, (1.0 - t) * 0.46)
		data["age"] = age
		_active_streaks[index] = data
		if age >= streak_lifetime:
			streak.visible = false
			_active_streaks.remove_at(index)


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
	if bool(context.get("was_shield_break", false)) or bool(context.get("was_shield_hit", false)):
		return _safe_color(shield_damage_color)
	if bool(context.get("was_armor_hit", false)):
		return _safe_color(armor_damage_color)
	if bool(context.get("was_momentum_hit", false)):
		return _safe_color(momentum_damage_color)
	if not String(context.get("mod_source", "")).is_empty():
		return _safe_color(modded_damage_color)
	match StringName(context.get("damage_type", &"projectile")):
		&"gravity":
			return _safe_color(gravity_damage_color)
		&"temporal":
			return _safe_color(temporal_damage_color)
		&"beam":
			return _safe_color(beam_damage_color)
		&"explosion":
			return _safe_color(final_blow_color)
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


func _hit_direction(context: Dictionary) -> Vector2:
	var direction_value: Variant = context.get("hit_direction", null)
	if direction_value is Vector2 and (direction_value as Vector2).length_squared() > 0.001:
		return (direction_value as Vector2).normalized()
	var source_velocity: Variant = context.get("source_velocity", null)
	if source_velocity is Vector2 and (source_velocity as Vector2).length_squared() > 0.001:
		return (source_velocity as Vector2).normalized()
	var source_position: Variant = context.get("source_position", null)
	var hit_position: Variant = context.get("hit_position", null)
	if source_position is Vector2 and hit_position is Vector2:
		var offset := (hit_position as Vector2) - (source_position as Vector2)
		if offset.length_squared() > 0.001:
			return offset.normalized()
	return Vector2.RIGHT.rotated(_rng.randf_range(-0.45, 0.45))


func _health_state_from_ratio(ratio: float) -> StringName:
	if ratio <= 0.0:
		return &"destroyed"
	if ratio <= 0.25:
		return &"critical"
	if ratio <= 0.5:
		return &"fractured"
	if ratio <= 0.75:
		return &"damaged"
	return &"stable"


func _health_state_text(state: StringName) -> String:
	match state:
		&"fractured":
			return "FRACTURED"
		&"critical":
			return "CRITICAL"
		&"destroyed":
			return "DESTROYED"
	return ""


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
