extends CanvasLayer

# DebugBalanceOverlay is a developer-only telemetry panel for fast balance passes.
# It samples the live combat loop at a capped interval so wave tuning, gravity
# readability, shield pressure, and time dilation behavior can be evaluated
# without adding permanent dependencies to the gameplay nodes.

@export var visible_on_start: bool = true
@export var enable_toggle: bool = true
@export var toggle_key: int = KEY_F3
@export var update_interval: float = 0.16
@export var max_gravity_sources_sampled: int = 8
@export var panel_width: float = 380.0
@export var max_value_text_length: int = 52

var _player: Node2D = null
var _wave_director: Node = null
var _time_dilation_manager: Node = null
var _resonance_manager: Node = null
var _arena_destabilization_manager: Node = null
var _physics_aware_enemy_director: Node = null
var _vfx_director: Node = null
var _performance_budget_director: Node = null
var _juice_manager: Node = null

var _rows: Dictionary = {}
var _elapsed: float = 0.0
var _last_frame_msec: int = 0
var _worst_frame_msec: int = 0
var _last_frame_tick: int = 0

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = visible_on_start

	_build_overlay()
	_resolve_references(true)
	set_process(true)

func _process(delta: float) -> void:
	_sample_frame_time()
	_elapsed += delta
	if _elapsed < maxf(update_interval, 0.04):
		return

	_elapsed = 0.0
	_resolve_references(false)
	_update_telemetry()

func _unhandled_input(event: InputEvent) -> void:
	if not enable_toggle:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != toggle_key:
		return

	visible = not visible
	get_viewport().set_input_as_handled()

func _build_overlay() -> void:
	var root := Control.new()
	root.name = "DebugBalanceOverlayRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "TelemetryPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -panel_width - 18.0
	panel.offset_right = -18.0
	panel.offset_top = 18.0
	panel.offset_bottom = 530.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "TelemetryRows"
	rows.add_theme_constant_override("separation", 5)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "BALANCE TELEMETRY F3"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.72, 1.0, 0.96, 1.0)
	rows.add_child(title)

	_add_row(rows, &"wave", "Wave")
	_add_row(rows, &"enemies", "Enemies")
	_add_row(rows, &"enemy_ai", "Enemy AI")
	_add_row(rows, &"boss", "Boss")
	_add_row(rows, &"health", "HP")
	_add_row(rows, &"shield", "Shield")
	_add_row(rows, &"energy", "Energy")
	_add_row(rows, &"velocity", "Velocity")
	_add_row(rows, &"momentum", "Momentum")
	_add_row(rows, &"powerups", "Powerups")
	_add_row(rows, &"gravity", "Local G")
	_add_row(rows, &"time", "Time")
	_add_row(rows, &"fps", "FPS")
	_add_row(rows, &"perf", "Perf")
	_add_row(rows, &"budget", "Budget")
	_add_row(rows, &"projectiles", "Shots")
	_add_row(rows, &"resonance", "Resonance")
	_add_row(rows, &"arena", "Arena")
	_add_row(rows, &"vfx", "VFX")
	_add_row(rows, &"stress", "Stress")

func _add_row(parent: VBoxContainer, key: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = "%sRow" % String(key).capitalize()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92.0, 0.0)
	label.modulate = Color(0.48, 0.78, 0.84, 1.0)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var value := Label.new()
	value.text = "n/a"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	value.add_theme_font_size_override("font_size", 13)
	row.add_child(value)

	_rows[key] = value

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.014, 0.024, 0.78)
	style.border_color = Color(0.0, 0.9, 1.0, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 12.0)
	style.set_content_margin(SIDE_TOP, 10.0)
	style.set_content_margin(SIDE_RIGHT, 12.0)
	style.set_content_margin(SIDE_BOTTOM, 10.0)
	return style

func _resolve_references(force: bool) -> void:
	if force or not _is_valid_node(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D

	if force or not _is_valid_node(_wave_director):
		_wave_director = _find_node_by_name(&"WaveDirector")

	if force or not _is_valid_node(_time_dilation_manager):
		_time_dilation_manager = _find_node_by_name(&"TimeDilationManager")

	if force or not _is_valid_node(_resonance_manager):
		_resonance_manager = _find_node_by_name(&"GravityResonanceManager")
		if _resonance_manager == null:
			_resonance_manager = _find_node_with_method(get_tree().current_scene, &"get_active_resonance_zones")

	if force or not _is_valid_node(_arena_destabilization_manager):
		_arena_destabilization_manager = _find_node_by_name(&"ArenaDestabilizationManager")

	if force or not _is_valid_node(_physics_aware_enemy_director):
		_physics_aware_enemy_director = _find_node_by_name(&"PhysicsAwareEnemyDirector")

	if force or not _is_valid_node(_vfx_director):
		_vfx_director = _find_node_by_name(&"OrbitalVFXDirector")

	if force or not _is_valid_node(_performance_budget_director):
		_performance_budget_director = _find_node_by_name(&"PerformanceBudgetDirector")

	if force or not _is_valid_node(_juice_manager):
		_juice_manager = get_tree().get_first_node_in_group("orbital_juice_manager")

func _update_telemetry() -> void:
	_set_row(&"wave", _format_wave_state())
	_set_row(&"enemies", _format_enemy_count())
	_set_row(&"enemy_ai", _format_enemy_ai_state())
	_set_row(&"boss", _format_boss_state())
	_set_row(&"health", _format_health_state())
	_set_row(&"shield", _format_shield_state())
	_set_row(&"energy", _format_energy_state())
	_set_row(&"velocity", _format_velocity_state())
	_set_row(&"momentum", _format_momentum_state())
	_set_row(&"powerups", _format_powerups())
	_set_row(&"gravity", _format_local_gravity())
	_set_row(&"time", _format_time_dilation())
	_set_row(&"fps", "%d" % Engine.get_frames_per_second())
	_set_row(&"perf", _format_perf_state())
	_set_row(&"budget", _format_budget_state())
	_set_row(&"projectiles", _format_projectile_state())
	_set_row(&"resonance", _format_resonance_state())
	_set_row(&"arena", _format_arena_state())
	_set_row(&"vfx", _format_vfx_state())
	_set_row(&"stress", _format_stress_state())

# ==================== FORMATTING ====================

func _format_wave_state() -> String:
	if not _is_valid_node(_wave_director):
		return "director n/a"
	var wave := int(_safe_float(_wave_director.get("_wave"), 0.0))
	var running := _safe_bool(_wave_director.get("_wave_running"), false)
	var spawning := _safe_bool(_wave_director.get("_spawning"), false)
	var state := "SPAWNING" if spawning else ("RUNNING" if running else "REST")
	return "%d %s" % [wave, state]

func _format_enemy_count() -> String:
	var wave_count := 0
	if _is_valid_node(_wave_director):
		wave_count = _count_valid_nodes(_wave_director.get("_active_enemies"))
	var total := _count_valid_nodes(get_tree().get_nodes_in_group("enemies"))

	if _is_valid_node(_wave_director):
		return "%d wave / %d total" % [wave_count, total]
	return "%d total" % total

func _format_enemy_ai_state() -> String:
	if not _is_valid_node(_physics_aware_enemy_director) or not _physics_aware_enemy_director.has_method("get_ai_debug_state"):
		return "director n/a"
	var state_value: Variant = _physics_aware_enemy_director.call("get_ai_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return "state n/a"

	var state: Dictionary = state_value
	var tracked := int(_safe_float(state.get("tracked"), 0.0))
	var profiles: Dictionary = state.get("profiles", {})

	var top_profile := "none"
	var top_count := 0
	for key in profiles.keys():
		var count := int(profiles[key])
		if count > top_count:
			top_count = count
			top_profile = String(key)

	var skip_ratio := _safe_float(state.get("skip_ratio"), 0.0)
	return "%d tracked %s %d skip %d%%" % [tracked, top_profile, top_count, int(round(skip_ratio * 100.0))]

func _format_boss_state() -> String:
	var boss := _get_active_boss()
	if not _is_valid_node(boss):
		return "none"

	var phase := int(_safe_float(boss.get("current_phase"), -1.0))
	if phase < 0:
		phase = int(_safe_float(boss.get("_phase"), -1.0))

	var health_ratio := -1.0
	if boss.has_method("get_health_ratio"):
		health_ratio = clampf(float(boss.call("get_health_ratio")), 0.0, 1.0)

	var phase_text := "p?" if phase < 0 else "p%d" % phase
	var hp_text := "" if health_ratio < 0.0 else " %d%%" % int(round(health_ratio * 100.0))
	return "%s %s%s" % [_clean_node_name(String(boss.name)), phase_text, hp_text]

func _format_health_state() -> String:
	if not _is_valid_node(_player):
		return "player n/a"
	var health := _player.get_node_or_null("HealthComponent")
	if health == null:
		return "component n/a"

	var current := _safe_float(health.get("current_health"), 0.0)
	var maximum := maxf(_safe_float(health.get("max_health"), 1.0), 1.0)
	return "%s %d%%" % [_format_resource_pair(current, maximum), int(round(current / maximum * 100.0))]

func _format_shield_state() -> String:
	if not _is_valid_node(_player): return "player n/a"
	var shield := _player.get_node_or_null("Shield")
	if shield == null: return "node n/a"

	var current := _safe_float(shield.get("current_energy"), 0.0)
	var maximum := maxf(_safe_float(shield.get("max_capacity"), 1.0), 1.0)
	var broken := _safe_bool(shield.get("is_broken"), false)
	var active := false
	if shield.has_method("is_shield_active"):
		active = bool(shield.call("is_shield_active"))

	var state := "ACTIVE" if active else "RECHARGE"
	if broken: state = "BROKEN"

	var timer := _safe_float(shield.get("_break_remaining"), 0.0) if broken else _safe_float(shield.get("_recharge_delay_remaining"), 0.0)
	var timer_text := "" if timer <= 0.05 else " %.1fs" % timer

	return "%s %s%s" % [_format_resource_pair(current, maximum), state, timer_text]

func _format_energy_state() -> String:
	if not _is_valid_node(_player): return "player n/a"
	var energy := _player.get_node_or_null("EnergyComponent")
	if energy == null: return "component n/a"

	var current := _safe_float(energy.get("current_energy"), 0.0)
	var maximum := maxf(_safe_float(energy.get("max_energy"), 1.0), 1.0)
	return "%s %d%%" % [_format_resource_pair(current, maximum), int(round(current / maximum * 100.0))]

func _format_velocity_state() -> String:
	if not _is_valid_node(_player): return "player n/a"
	var velocity: Vector2 = _safe_vector2(_player.get("velocity"))
	return "%d px/s x%d y%d" % [int(round(velocity.length())), int(round(velocity.x)), int(round(velocity.y))]

func _format_momentum_state() -> String:
	if not _is_valid_node(_player): return "player n/a"
	var component := _player.get_node_or_null("MomentumCombatComponent")
	if component == null or not component.has_method("get_momentum_debug_state"):
		return "component n/a"

	var state_value: Variant = component.call("get_momentum_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return "state n/a"

	var state: Dictionary = state_value
	var state_name := String(state.get("state", &"stable"))
	var damage_multiplier := _safe_float(state.get("damage_multiplier"), 1.0)
	var orbit_charge := _safe_float(state.get("orbit_charge"), 0.0)

	return "%s x%.2f orbit %d%%" % [state_name, damage_multiplier, int(round(orbit_charge * 100.0))]

func _format_powerups() -> String:
	if not _is_valid_node(_player): return "player n/a"
	var inventory := _player.get_node_or_null("PowerupInventory")
	if inventory == null: return "none"

	var stacks: Dictionary = inventory.get("_stacks") if typeof(inventory.get("_stacks")) == TYPE_DICTIONARY else {}
	var timed: Dictionary = inventory.get("_timed_effects") if typeof(inventory.get("_timed_effects")) == TYPE_DICTIONARY else {}

	if stacks.is_empty():
		return "none"

	var parts: Array[String] = []
	for id in stacks.keys():
		var stack_count := int(stacks[id])
		var text := "%s x%d" % [String(id), stack_count]
		if timed.has(id):
			var entry: Dictionary = timed[id] if typeof(timed[id]) == TYPE_DICTIONARY else {}
			if not entry.is_empty():
				text += " %.0fs" % _safe_float(entry.get("remaining"), 0.0)
		parts.append(text)

	parts.sort()
	if inventory.has_method("get_law_fusion_debug_state"):
		var fusion_value: Variant = inventory.call("get_law_fusion_debug_state")
		if typeof(fusion_value) == TYPE_DICTIONARY:
			var fusion_state: Dictionary = fusion_value
			var active_value: Variant = fusion_state.get("active", [])
			var active_fusions: Array = active_value if typeof(active_value) == TYPE_ARRAY else []
			if not active_fusions.is_empty():
				parts.append("fusion %d last %s" % [active_fusions.size(), String(fusion_state.get("last", "none"))])
	return _trim_value_text(_join_strings(parts, ", "))

func _format_local_gravity() -> String:
	if not _is_valid_node(_player):
		return "player n/a"
	var gravity := _calculate_local_gravity()
	return "%d vx %.1f vy %.1f" % [int(round(gravity.length())), gravity.x, gravity.y]

func _format_time_dilation() -> String:
	if not _is_valid_node(_time_dilation_manager):
		return "Engine x%.2f" % Engine.time_scale

	var scale := _safe_float(_time_dilation_manager.get("current_time_scale"), Engine.time_scale)
	var capacity := _safe_float(_time_dilation_manager.get("current_dilation_capacity"), 0.0)
	var max_capacity := maxf(_safe_float(_time_dilation_manager.get("initial_dilation_capacity"), 1.0), 1.0)
	var dilating := _safe_bool(_time_dilation_manager.get("is_dilating"), false)
	var pockets := _dictionary_size(_time_dilation_manager.get("_local_slow_effects"))
	var state := "DILATING" if dilating else "READY"

	return "%s x%.2f %d%% P%d" % [state, scale, int(round(capacity / max_capacity * 100.0)), pockets]

func _format_perf_state() -> String:
	var spike := " SPIKE" if _last_frame_msec >= 24 or _worst_frame_msec >= 34 else ""
	return "%dms worst %dms%s" % [_last_frame_msec, _worst_frame_msec, spike]

func _format_budget_state() -> String:
	if not _is_valid_node(_performance_budget_director) or not _performance_budget_director.has_method("get_budget_debug_state"):
		return "director n/a"

	var state_value: Variant = _performance_budget_director.call("get_budget_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return "state n/a"

	var state: Dictionary = state_value
	var quality := int(_safe_float(state.get("quality"), 2.0))
	var quality_text := "LOW" if quality <= 0 else ("MED" if quality == 1 else "HIGH")
	var enabled := _safe_bool(state.get("enabled"), true)
	var projectiles := int(_safe_float(state.get("projectile_pressure"), 0.0))
	var enemies := int(_safe_float(state.get("enemy_pressure"), 0.0))
	return "%s %s fps %d P%d E%d" % ["ON" if enabled else "OFF", quality_text, int(_safe_float(state.get("fps"), 0.0)), projectiles, enemies]

func _format_projectile_state() -> String:
	var player_shots := _count_group(&"player_projectiles")
	var enemy_shots := _count_group(&"enemy_projectiles")
	var generic := _count_group(&"Projectiles")
	var total := player_shots + enemy_shots + generic
	return "%d total P%d E%d G%d" % [total, player_shots, enemy_shots, generic]

func _format_resonance_state() -> String:
	if not _is_valid_node(_resonance_manager) or not _resonance_manager.has_method("get_active_resonance_zones"):
		return "manager n/a"

	var zones_value: Variant = _resonance_manager.call("get_active_resonance_zones")
	var zones: Array = zones_value if typeof(zones_value) == TYPE_ARRAY else []

	var max_intensity := 0.0
	var strongest_type := "none"
	var strongest_rule := ""
	for zone in zones:
		if typeof(zone) == TYPE_DICTIONARY:
			var intensity := _safe_float(zone.get("intensity"), 0.0)
			if intensity > max_intensity:
				max_intensity = intensity
				strongest_type = String(zone.get("zone_type_name", &"untyped"))
				strongest_rule = String(zone.get("zone_rule_name", ""))

	var local_intensity := 0.0
	var local_type := "none"
	var local_rule := ""
	if _is_valid_node(_player) and _resonance_manager.has_method("get_resonance_at_position"):
		local_intensity = float(_resonance_manager.call("get_resonance_at_position", _player.global_position))
	if _is_valid_node(_player) and _resonance_manager.has_method("get_resonance_zone_at_position"):
		var local_zone_value: Variant = _resonance_manager.call("get_resonance_zone_at_position", _player.global_position)
		if typeof(local_zone_value) == TYPE_DICTIONARY:
			var local_zone: Dictionary = local_zone_value
			if not local_zone.is_empty():
				local_type = String(local_zone.get("zone_type_name", &"zone"))
				local_rule = String(local_zone.get("zone_rule_name", ""))

	return "%d %s %s %.2f local %s %s %.2f" % [
		zones.size(),
		strongest_rule,
		strongest_type,
		max_intensity,
		local_rule,
		local_type,
		local_intensity,
	]

func _format_arena_state() -> String:
	if not _is_valid_node(_arena_destabilization_manager) or not _arena_destabilization_manager.has_method("get_instability_debug_state"):
		return "manager n/a"

	var state_value: Variant = _arena_destabilization_manager.call("get_instability_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return "state n/a"

	var state: Dictionary = state_value
	var instability := _safe_float(state.get("instability"), 0.0)
	var stage := String(state.get("stage", &"early"))
	var hazards := int(_safe_float(state.get("active_hazards"), 0.0))
	var next_event := _safe_float(state.get("next_event"), 0.0)

	return "%s %d%% H%d %.0fs" % [stage, int(round(instability * 100.0)), hazards, next_event]

func _format_vfx_state() -> String:
	if not _is_valid_node(_vfx_director) or not _vfx_director.has_method("get_vfx_debug_state"):
		return "director n/a"

	var state_value: Variant = _vfx_director.call("get_vfx_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return "state n/a"

	var state: Dictionary = state_value
	var active := int(_safe_float(state.get("active_bursts"), 0.0))
	var cap := int(_safe_float(state.get("burst_cap"), 0.0))
	var chaos := _safe_float(state.get("chaos"), 0.0)
	var quality := int(_safe_float(state.get("quality"), 0.0))
	var quality_text := "OFF" if quality <= 0 else ("LOW" if quality == 1 else "HIGH")
	return "%s %d/%d chaos %d%%" % [quality_text, active, cap, int(round(chaos * 100.0))]


func _format_stress_state() -> String:
	if not _is_valid_node(_juice_manager) or not _juice_manager.has_method("get_juice_debug_state"):
		return "F6 showcase F7 stress F9 clear"

	var juice_state: Dictionary = _juice_manager.call("get_juice_debug_state")
	var stress: Dictionary = juice_state.get("stress", {})
	if stress.is_empty():
		return "idle (F7 run)"

	var spawned := int(stress.get("spawned", 0))
	var projectiles := int(stress.get("projectile_count", 0))
	var wells := int(stress.get("gravity_well_count", 0))
	return "on %d nodes %d shots %d wells" % [spawned, projectiles, wells]

# ==================== HELPERS ====================

func _calculate_local_gravity() -> Vector2:
	if not _is_valid_node(_player):
		return Vector2.ZERO

	var gravity_constant := _safe_float(_player.get("gravity_constant"), 0.0)
	var min_dist := maxf(_safe_float(_player.get("min_grav_dist"), 1.0), 1.0)
	var pull_radius := _safe_float(_player.get("gravity_pull_radius"), 0.0)
	var pull_radius_squared := pull_radius * pull_radius

	var total := Vector2.ZERO
	for source in _nearby_gravity_sources():
		if not _is_valid_node(source):
			continue
		var offset := source.global_position - _player.global_position
		var raw_dist_squared := offset.length_squared()
		if raw_dist_squared <= 0.001:
			continue
		if pull_radius > 0.0 and raw_dist_squared > pull_radius_squared:
			continue

		var raw_dist := sqrt(raw_dist_squared)
		var dist := maxf(raw_dist, min_dist)
		var mass := _safe_float(source.get("mass"), 100.0)
		total += (offset / raw_dist) * gravity_constant * mass / (dist * dist)

	return total

func _sample_frame_time() -> void:
	var now := Time.get_ticks_msec()
	var previous := now if _last_frame_tick <= 0 else _last_frame_tick
	_last_frame_msec = maxi(now - previous, 0)
	_worst_frame_msec = maxi(maxi(_worst_frame_msec - 1, 0), _last_frame_msec)
	_last_frame_tick = now

func _nearby_gravity_sources() -> Array[Node2D]:
	var sources: Array[Node2D] = []
	var seen := {}

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == _player:
				continue
			if source == null or not is_instance_valid(source):
				continue
			var source_2d := source as Node2D
			if source_2d == null or source_2d.is_queued_for_deletion():
				continue
			var id := source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			sources.append(source_2d)

	sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)

	if max_gravity_sources_sampled > 0 and sources.size() > max_gravity_sources_sampled:
		sources.resize(max_gravity_sources_sampled)

	return sources

func _get_active_boss() -> Node:
	if _is_valid_node(_wave_director):
		var boss_value: Variant = _wave_director.get("_boss")
		var boss: Node = null
		if boss_value != null and is_instance_valid(boss_value):
			boss = boss_value as Node
		if _is_valid_node(boss):
			return boss

	for boss in get_tree().get_nodes_in_group("bosses"):
		if _is_valid_node(boss):
			return boss
	return null

# ==================== SAFE UTILITIES ====================

func _set_row(key: StringName, value: String) -> void:
	var label_value: Variant = _rows.get(key, null)
	var label: Label = null
	if label_value != null and is_instance_valid(label_value):
		label = label_value as Label
	if label:
		label.text = _trim_value_text(value)

func _trim_value_text(value: String) -> String:
	if max_value_text_length <= 0 or value.length() <= max_value_text_length:
		return value
	return value.left(max_value_text_length - 3) + "..."

func _join_strings(parts: Array[String], separator: String) -> String:
	var joined := ""
	for i in range(parts.size()):
		if i > 0:
			joined += separator
		joined += parts[i]
	return joined

func _format_resource_pair(current: float, maximum: float) -> String:
	return "%d/%d" % [int(round(current)), int(round(maximum))]

func _count_valid_nodes(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	var count := 0
	for entry in value:
		if _is_valid_node(entry):
			count += 1
	return count

func _count_group(group_name: StringName) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(group_name):
		if _is_valid_node(node):
			count += 1
	return count

func _dictionary_size(value: Variant) -> int:
	return value.size() if typeof(value) == TYPE_DICTIONARY else 0

func _find_node_by_name(node_name: StringName) -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	if root.name == String(node_name):
		return root
	return root.find_child(String(node_name), true, false)

func _find_node_with_method(node: Node, method_name: StringName) -> Node:
	if node == null:
		return null
	if node != self and node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null

# Fixed version - prevents "Left operand of 'is' is a previously freed instance"
func _is_valid_node(node: Variant) -> bool:
	if node == null:
		return false
	if not is_instance_valid(node):
		return false
	if not (node is Node):
		return false
	return not (node as Node).is_queued_for_deletion()

func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	var t := typeof(value)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return float(value)
	return fallback

func _safe_bool(value: Variant, fallback: bool = false) -> bool:
	return bool(value) if typeof(value) == TYPE_BOOL else fallback

func _safe_vector2(value: Variant) -> Vector2:
	return value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO

func _clean_node_name(raw_name: String) -> String:
	var cleaned := raw_name.replace("@", "")
	return cleaned if cleaned.length() <= 20 else cleaned.left(20)
