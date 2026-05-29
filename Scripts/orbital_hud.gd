extends CanvasLayer

@export var max_arrow_count: int = 8
@export var max_threat_arrow_count: int = 8
@export var max_boss_arrow_count: int = 2
@export var arrow_margin: float = 42.0
@export var threat_arrow_refresh_interval: float = 0.12
@export var g_warning_level: float = 850.0
@export var nearest_field_notice_radius: float = 760.0

var _player: Node2D
var _resonance_manager: Node
var _scar_manager: Node
var _time_dilation_manager: Node
var _event_horizon_manager: Node
var _arena_destabilization_manager: Node
var _powerup_inventory: Node
var _momentum_component: Node
var _weapon_system: Node
var _hud_root: Control
var _speed_label: Label
var _speed_bar: ProgressBar
var _g_label: Label
var _g_bar: ProgressBar
var _field_label: Label
var _time_label: Label
var _horizon_label: Label
var _chaos_label: Label
var _slingshot_label: Label
var _slingshot_bar: ProgressBar
var _combo_label: Label
var _weapon_label: Label
var _weapon_bar: ProgressBar
var _powerup_notice_label: Label
var _critical_vignette: ColorRect
var _vignette_material: ShaderMaterial
var _arrows: Array[Polygon2D] = []
var _threat_arrows: Array[Polygon2D] = []
var _boss_arrows: Array[Polygon2D] = []
var _arrow_layer: Node2D
var _orbit_layer: Node2D
var _health_arc: Line2D
var _energy_arc: Line2D
var _time_arc: Line2D
var _sling_arc: Line2D
var _threat_targets: Array[Node2D] = []
var _boss_targets: Array[Node2D] = []
var _powerup_notice_time := 0.0
var _powerup_notice_color := Color(0.72, 1.0, 0.96, 1.0)
var _threat_refresh_elapsed := 999.0

# Cache the current intensity to avoid repeated get_shader_parameter calls
var _current_vignette_intensity: float = 0.0
var _last_ui_scale: float = 1.0
var _hud_phase: float = 0.0

func _ready() -> void:
	layer = 40
	_build_hud()
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	_apply_accessibility_settings()
	if Settings != null and Settings.has_signal("accessibility_changed"):
		var callable := Callable(self, "_on_accessibility_changed")
		if not Settings.is_connected("accessibility_changed", callable):
			Settings.connect("accessibility_changed", callable)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return
	
	_update_speedometer()
	var gravity_strength: float = _update_gravity_meter()
	_resolve_rule_systems()
	_update_field_lens()
	_update_time_lens()
	_update_horizon_lens()
	_update_chaos_lens()
	_update_slingshot_lens()
	_update_weapon_lens()
	_update_powerup_notice(delta)
	_update_health_vignette(delta)
	_update_orbit_telemetry(delta)
	_update_nav_arrows(gravity_strength)
	_update_threat_arrows(delta)
	_apply_accessibility_settings()


# ============================
# BUILD HUD
# ============================

func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud_root)
	
	_build_vignette()
	_build_readout_panel()
	_build_powerup_notice()
	_build_nav_arrows()
	_build_orbit_telemetry()


func _build_vignette() -> void:
	_critical_vignette = ColorRect.new()
	_critical_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_critical_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_critical_vignette.color = Color.TRANSPARENT
	
	var shader = Shader.new()
	shader.code = """
    shader_type canvas_item;
    
    uniform vec4 critical_color : source_color = vec4(1.0, 0.05, 0.02, 1.0);
    uniform float intensity = 0.0;
    
    void fragment() {
        vec2 centered = UV * 2.0 - vec2(1.0);
        float rim = smoothstep(0.35, 1.15, length(centered));
        COLOR = vec4(critical_color.rgb, critical_color.a * intensity * rim);
    }
	"""
	
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_critical_vignette.material = _vignette_material
	_hud_root.add_child(_critical_vignette)


func _build_readout_panel() -> void:
	var panel = PanelContainer.new()
	panel.offset_left = 18.0
	panel.offset_top = 96.0
	panel.custom_minimum_size = Vector2(314.0, 302.0)
	_hud_root.add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.68)
	style.border_color = Color(0.1, 0.95, 0.85, 0.48)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	
	_speed_label = Label.new()
	_speed_label.text = "SPD 0000"
	rows.add_child(_speed_label)
	
	_speed_bar = ProgressBar.new()
	_speed_bar.show_percentage = false
	_speed_bar.custom_minimum_size = Vector2(228, 14)
	rows.add_child(_speed_bar)
	
	_g_label = Label.new()
	_g_label.text = "G 000"
	rows.add_child(_g_label)
	
	_g_bar = ProgressBar.new()
	_g_bar.show_percentage = false
	_g_bar.max_value = g_warning_level
	_g_bar.custom_minimum_size = Vector2(228, 14)
	rows.add_child(_g_bar)

	_field_label = Label.new()
	_field_label.text = "FIELD CLEAR"
	_field_label.clip_text = true
	_field_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_field_label)

	_time_label = Label.new()
	_time_label.text = "TIME READY"
	_time_label.clip_text = true
	_time_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_time_label)

	_horizon_label = Label.new()
	_horizon_label.text = "HORIZON QUIET"
	_horizon_label.clip_text = true
	_horizon_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_horizon_label)

	_chaos_label = Label.new()
	_chaos_label.text = "CHAOS T0 CALIBRATION"
	_chaos_label.clip_text = true
	_chaos_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_chaos_label)

	_slingshot_label = Label.new()
	_slingshot_label.text = "SLING SEARCH"
	_slingshot_label.clip_text = true
	_slingshot_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_slingshot_label)

	_slingshot_bar = ProgressBar.new()
	_slingshot_bar.show_percentage = false
	_slingshot_bar.max_value = 1.0
	_slingshot_bar.custom_minimum_size = Vector2(228, 12)
	rows.add_child(_slingshot_bar)

	_combo_label = Label.new()
	_combo_label.text = "VECTOR CHAIN --"
	_combo_label.clip_text = true
	_combo_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_combo_label)

	_weapon_label = Label.new()
	_weapon_label.text = "WEAPON VECTOR BOLT"
	_weapon_label.clip_text = true
	_weapon_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_weapon_label)

	_weapon_bar = ProgressBar.new()
	_weapon_bar.show_percentage = false
	_weapon_bar.max_value = 1.0
	_weapon_bar.custom_minimum_size = Vector2(228, 12)
	rows.add_child(_weapon_bar)

func _build_powerup_notice() -> void:
	_powerup_notice_label = Label.new()
	_powerup_notice_label.name = "PowerupNotice"
	_powerup_notice_label.anchor_left = 0.5
	_powerup_notice_label.anchor_right = 0.5
	_powerup_notice_label.anchor_top = 0.0
	_powerup_notice_label.anchor_bottom = 0.0
	_powerup_notice_label.offset_left = -260.0
	_powerup_notice_label.offset_right = 260.0
	_powerup_notice_label.offset_top = 72.0
	_powerup_notice_label.offset_bottom = 110.0
	_powerup_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_powerup_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_powerup_notice_label.add_theme_font_size_override("font_size", 18)
	_powerup_notice_label.text = ""
	_powerup_notice_label.modulate = Color.TRANSPARENT
	_hud_root.add_child(_powerup_notice_label)


func _build_nav_arrows() -> void:
	_arrow_layer = Node2D.new()
	_arrow_layer.name = "NavigationArrowLayer"
	add_child(_arrow_layer)
	
	for i in range(max_arrow_count):
		var arrow := _make_screen_arrow("GravityArrow%d" % i, Color(0.1, 0.95, 0.9, 0.86), 1.0, 1)
		_arrow_layer.add_child(arrow)
		_arrows.append(arrow)

	for i in range(max_threat_arrow_count):
		var arrow := _make_screen_arrow("EnemyThreatArrow%d" % i, Color(1.0, 0.72, 0.22, 0.88), 0.82, 2)
		_arrow_layer.add_child(arrow)
		_threat_arrows.append(arrow)

	for i in range(max_boss_arrow_count):
		var arrow := _make_screen_arrow("BossThreatArrow%d" % i, Color(1.0, 0.16, 0.1, 0.95), 1.35, 3)
		_arrow_layer.add_child(arrow)
		_boss_arrows.append(arrow)


func _build_orbit_telemetry() -> void:
	_orbit_layer = Node2D.new()
	_orbit_layer.name = "PlayerOrbitTelemetry"
	_orbit_layer.z_index = 6
	_orbit_layer.visible = true
	add_child(_orbit_layer)

	_health_arc = _make_orbit_arc("HealthOrbitArc", Color(1.0, 0.24, 0.18, 0.82), 3.6)
	_energy_arc = _make_orbit_arc("EnergyOrbitArc", Color(0.22, 0.84, 1.0, 0.78), 3.0)
	_time_arc = _make_orbit_arc("TimeOrbitArc", Color(0.72, 0.36, 1.0, 0.68), 2.2)
	_sling_arc = _make_orbit_arc("SlingshotOrbitArc", Color(0.34, 1.0, 0.82, 0.68), 2.4)


func _make_orbit_arc(node_name: String, color: Color, width: float) -> Line2D:
	var arc := Line2D.new()
	arc.name = node_name
	arc.antialiased = true
	arc.width = width
	arc.default_color = _readability_color(color)
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	_orbit_layer.add_child(arc)
	return arc


func _make_screen_arrow(node_name: String, color: Color, arrow_scale: float, z: int) -> Polygon2D:
	var arrow := Polygon2D.new()
	arrow.name = node_name
	arrow.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(13.0, 12.0),
		Vector2(0.0, 6.0),
		Vector2(-13.0, 12.0),
	])
	arrow.color = _readability_color(color)
	arrow.scale = Vector2.ONE * arrow_scale
	arrow.z_index = z
	arrow.visible = false
	return arrow


# ============================
# SPEEDOMETER
# ============================

func _update_speedometer() -> void:
	var velocity = _player.get("velocity") if _player.has_method("get") else Vector2.ZERO
	if velocity == null:
		velocity = Vector2.ZERO
	
	var max_speed = _player.get("current_max_speed")
	if max_speed == null:
		max_speed = 1.0
	
	var current_max_speed: float = maxf(float(max_speed), 1.0)
	var speed: float = velocity.length()
	
	_speed_bar.max_value = current_max_speed
	_speed_bar.value = clampf(speed, 0.0, current_max_speed)
	_speed_label.text = "SPD %04d / %04d" % [int(round(speed)), int(round(current_max_speed))]


# ============================
# GRAVITY METER
# ============================

func _update_gravity_meter() -> float:
	var gravity: Vector2 = _calculate_gravity_at_player()
	var strength: float = gravity.length()
	
	_g_bar.value = clampf(strength, 0.0, g_warning_level)
	_g_label.text = "G %03d" % int(round(strength))
	_g_label.modulate = _readability_color(Color(1, 0.16, 0.1) if strength >= g_warning_level * 0.72 else Color(0.78, 1, 0.96))
	
	return strength


func _calculate_gravity_at_player() -> Vector2:
	var gravity_constant: float = float(_player.get("gravity_constant") or 0.0)
	var min_grav_dist: float = maxf(float(_player.get("min_grav_dist") or 1.0), 1.0)
	
	var total = Vector2.ZERO
	for planet in get_tree().get_nodes_in_group("planets"):
		if not (planet is Node2D):
			continue
		var p: Node2D = planet
		var mass = p.get("mass")
		if mass == null:
			continue
		
		var offset: Vector2 = p.global_position - _player.global_position
		var dist: float = maxf(offset.length(), min_grav_dist)
		if dist <= 0.0:
			continue
		total += offset.normalized() * gravity_constant * float(mass) / (dist * dist)
	
	return total


# ============================
# FIELD RULE LENS
# ============================

func _resolve_rule_systems() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)

	if _scar_manager == null or not is_instance_valid(_scar_manager):
		_scar_manager = root.find_child("GravityScarManager", true, false)

	if _time_dilation_manager == null or not is_instance_valid(_time_dilation_manager):
		_time_dilation_manager = root.find_child("TimeDilationManager", true, false)

	if _event_horizon_manager == null or not is_instance_valid(_event_horizon_manager):
		_event_horizon_manager = root.find_child("EventHorizonDirector", true, false)
		if _event_horizon_manager != null:
			if _event_horizon_manager.has_signal("event_horizon_started"):
				var started_callable := Callable(self, "_on_event_horizon_started")
				if not _event_horizon_manager.is_connected("event_horizon_started", started_callable):
					_event_horizon_manager.connect("event_horizon_started", started_callable)
			if _event_horizon_manager.has_signal("horizon_escape_scored"):
				var escape_callable := Callable(self, "_on_horizon_escape_scored")
				if not _event_horizon_manager.is_connected("horizon_escape_scored", escape_callable):
					_event_horizon_manager.connect("horizon_escape_scored", escape_callable)

	if _arena_destabilization_manager == null or not is_instance_valid(_arena_destabilization_manager):
		_arena_destabilization_manager = root.find_child("ArenaDestabilizationManager", true, false)

	if _player != null and is_instance_valid(_player):
		var inventory := _player.get_node_or_null("PowerupInventory")
		if inventory != null and inventory != _powerup_inventory:
			_powerup_inventory = inventory
			if inventory.has_signal("powerup_applied"):
				var callable := Callable(self, "_on_powerup_applied")
				if not inventory.is_connected("powerup_applied", callable):
					inventory.connect("powerup_applied", callable)

		var momentum := _player.get_node_or_null("MomentumCombatComponent")
		if momentum != null and momentum != _momentum_component:
			_momentum_component = momentum
			if momentum.has_signal("slingshot_mastery_triggered"):
				var mastery_callable := Callable(self, "_on_slingshot_mastery_triggered")
				if not momentum.is_connected("slingshot_mastery_triggered", mastery_callable):
					momentum.connect("slingshot_mastery_triggered", mastery_callable)

		var weapon_system := _player.get_node_or_null("WeaponSystem")
		if weapon_system != null and weapon_system != _weapon_system:
			_weapon_system = weapon_system

func _update_field_lens() -> void:
	if _field_label == null:
		return

	var tide_state := _local_tide_state()
	if not tide_state.is_empty():
		_set_field_text(
			"TIDE %s  %s %d%%" % [
				String(tide_state.get("display_name", "Tide")).to_upper(),
				String(tide_state.get("rule_name", "FIELD")),
				int(round(float(tide_state.get("local_intensity", 0.0)) * 100.0)),
			],
			tide_state.get("color", Color(0.78, 1.0, 0.96, 1.0))
		)
		return

	var scar_state := _local_scar_state()
	if not scar_state.is_empty():
		_set_field_text(
			"SCAR %s  %s %d%%" % [
				String(scar_state.get("display_name", "Scar")).to_upper(),
				String(scar_state.get("rule_name", "BEND")),
				int(round(float(scar_state.get("local_intensity", 0.0)) * 100.0)),
			],
			scar_state.get("color", Color(0.78, 1.0, 0.96, 1.0))
		)
		return

	if _resonance_manager != null and _resonance_manager.has_method("get_resonance_zone_at_position"):
		var zone_value: Variant = _resonance_manager.call("get_resonance_zone_at_position", _player.global_position)
		if typeof(zone_value) == TYPE_DICTIONARY:
			var zone: Dictionary = zone_value
			if not zone.is_empty():
				_set_field_text(
					"FIELD %s  %s %d%%" % [
						String(zone.get("zone_display_name", "Zone")).to_upper(),
						String(zone.get("zone_rule_name", "FIELD")),
						int(round(float(zone.get("local_intensity", 0.0)) * 100.0)),
					],
					zone.get("zone_color", Color(0.78, 1.0, 0.96, 1.0))
				)
				return

	var nearest_zone := _nearest_resonance_zone()
	if not nearest_zone.is_empty():
		_set_field_text(
			"NEAR %s  %s" % [
				String(nearest_zone.get("zone_display_name", "Zone")).to_upper(),
				String(nearest_zone.get("zone_rule_name", "FIELD")),
			],
			nearest_zone.get("zone_color", Color(0.48, 0.78, 0.84, 1.0))
		)
		return

	_set_field_text("FIELD CLEAR", Color(0.48, 0.78, 0.84, 1.0))

func _update_time_lens() -> void:
	if _time_label == null:
		return

	if _time_dilation_manager == null or not is_instance_valid(_time_dilation_manager):
		_time_label.text = "TIME OFFLINE"
		_time_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		return

	var capacity := float(_time_dilation_manager.get("current_dilation_capacity") or 0.0)
	var maximum := maxf(float(_time_dilation_manager.get("initial_dilation_capacity") or 1.0), 1.0)
	var dilating := bool(_time_dilation_manager.get("is_dilating")) if typeof(_time_dilation_manager.get("is_dilating")) == TYPE_BOOL else false
	var scale := float(_time_dilation_manager.get("current_time_scale") or Engine.time_scale)
	var state := "DILATING" if dilating else "READY"

	_time_label.text = "TIME %s  x%.2f %d%%" % [state, scale, int(round(capacity / maximum * 100.0))]
	_time_label.modulate = _readability_color(Color(0.72, 0.38, 1.0, 1.0) if dilating else Color(0.72, 1.0, 0.96, 1.0))

func _update_horizon_lens() -> void:
	if _horizon_label == null:
		return

	if _event_horizon_manager == null or not is_instance_valid(_event_horizon_manager):
		_horizon_label.text = "HORIZON QUIET"
		_horizon_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		return

	var state := {}
	if _event_horizon_manager.has_method("get_event_horizon_debug_state"):
		var state_value: Variant = _event_horizon_manager.call("get_event_horizon_debug_state")
		if typeof(state_value) == TYPE_DICTIONARY:
			state = state_value

	var active := bool(state.get("active", false))
	var intensity := clampf(float(state.get("intensity", 0.0)), 0.0, 1.0)
	var cooldown := float(state.get("cooldown", 0.0))

	if active:
		_horizon_label.text = "HORIZON ESCAPE  %03d%%" % int(round(intensity * 100.0))
		_horizon_label.modulate = _readability_color(Color(1.0, 0.22, 0.12, 1.0).lerp(Color(0.72, 0.36, 1.0, 1.0), intensity * 0.55))
	elif cooldown > 0.0:
		_horizon_label.text = "HORIZON RECOVER  %.0fs" % cooldown
		_horizon_label.modulate = _readability_color(Color(0.78, 0.54, 1.0, 1.0))
	else:
		_horizon_label.text = "HORIZON QUIET"
		_horizon_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))

func _update_chaos_lens() -> void:
	if _chaos_label == null:
		return

	if _arena_destabilization_manager == null or not is_instance_valid(_arena_destabilization_manager):
		_chaos_label.text = "CHAOS T0 CALIBRATION"
		_chaos_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		return

	var state := {}
	if _arena_destabilization_manager.has_method("get_readable_chaos_state"):
		var state_value: Variant = _arena_destabilization_manager.call("get_readable_chaos_state")
		if typeof(state_value) == TYPE_DICTIONARY:
			state = state_value
	elif _arena_destabilization_manager.has_method("get_instability_debug_state"):
		var fallback_value: Variant = _arena_destabilization_manager.call("get_instability_debug_state")
		if typeof(fallback_value) == TYPE_DICTIONARY:
			state = fallback_value

	var tier := int(state.get("tier", state.get("chaos_tier", 0)))
	var tier_name := String(state.get("tier_name", state.get("chaos_tier_name", "calibration"))).to_upper()
	var instability := clampf(float(state.get("instability", 0.0)), 0.0, 1.0)
	_chaos_label.text = "CHAOS T%d %s  %03d%%" % [tier, tier_name, int(round(instability * 100.0))]
	_chaos_label.modulate = _readability_color(_chaos_tier_color(tier))

func _update_slingshot_lens() -> void:
	if _slingshot_label == null or _slingshot_bar == null:
		return

	var sling_state := {}
	if _player != null and is_instance_valid(_player) and _player.has_method("get_slingshot_debug_state"):
		var value: Variant = _player.call("get_slingshot_debug_state")
		if typeof(value) == TYPE_DICTIONARY:
			sling_state = value

	var state := String(sling_state.get("state", "search")).to_upper()
	var score := clampf(float(sling_state.get("score", 0.0)), 0.0, 1.0)
	var tangential := float(sling_state.get("tangential_speed", 0.0))
	var distance := float(sling_state.get("distance", 0.0))
	var grade := String(sling_state.get("grade", "none")).to_upper()
	var color := _slingshot_color(state, score)

	_slingshot_bar.value = score
	_slingshot_label.text = "SLING %s  %s %03d%%  T%04d D%03d" % [
		state,
		grade,
		int(round(score * 100.0)),
		int(round(tangential)),
		int(round(distance)),
	]
	_slingshot_label.modulate = _readability_color(color)

	if _combo_label == null:
		return

	var combo := 0
	var timer := 0.0
	var flow_active := false
	var flow_intensity := 0.0
	var tier := "IDLE"

	if _momentum_component != null and is_instance_valid(_momentum_component) and _momentum_component.has_method("get_momentum_debug_state"):
		var momentum_value: Variant = _momentum_component.call("get_momentum_debug_state")
		if typeof(momentum_value) == TYPE_DICTIONARY:
			var momentum_state: Dictionary = momentum_value
			combo = int(momentum_state.get("mastery_combo", 0))
			timer = float(momentum_state.get("mastery_timer", 0.0))
			flow_active = bool(momentum_state.get("flow_active", false))
			flow_intensity = float(momentum_state.get("flow_intensity", 0.0))
			tier = String(momentum_state.get("mastery_tier", "idle")).to_upper()

	if combo > 0:
		_combo_label.text = "VECTOR CHAIN x%d  %s %.1fs" % [combo, tier, timer]
		_combo_label.modulate = _readability_color(Color(1.0, 0.9, 0.28, 1.0) if tier == "GOD_VECTOR" else Color(0.34, 1.0, 0.86, 1.0))
	elif flow_active:
		_combo_label.text = "FLOW ONLINE  %03d%%" % int(round(flow_intensity * 100.0))
		_combo_label.modulate = _readability_color(Color(0.28, 0.9, 1.0, 1.0))
	else:
		_combo_label.text = "VECTOR CHAIN --"
		_combo_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))

func _update_weapon_lens() -> void:
	if _weapon_label == null or _weapon_bar == null:
		return

	if _weapon_system == null or not is_instance_valid(_weapon_system) or not _weapon_system.has_method("get_weapon_debug_state"):
		_weapon_label.text = "WEAPON VECTOR BOLT"
		_weapon_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		_weapon_bar.value = 0.0
		return

	var state_value: Variant = _weapon_system.call("get_weapon_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return

	var state: Dictionary = state_value
	var display_name := String(state.get("display_name", "Vector Bolt")).to_upper()
	var active := bool(state.get("beam_active", false))
	var energy_percent := clampf(float(state.get("energy_percent", 0.0)), 0.0, 1.0)
	var cost := float(state.get("cost_per_second", 0.0))
	var color: Color = state.get("color", Color(0.34, 1.0, 0.86, 1.0))
	var state_label := "FIRING" if active else ("READY" if energy_percent > 0.12 else "LOW ENERGY")

	_weapon_label.text = "WEAPON %s  %s %.0f/s" % [display_name, state_label, cost]
	_weapon_label.modulate = _readability_color(color)
	_weapon_bar.value = energy_percent


func _update_orbit_telemetry(delta: float) -> void:
	if _orbit_layer == null or _player == null or not is_instance_valid(_player):
		return

	_hud_phase += delta
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * _player.global_position
	var margin := 86.0
	var visible := screen_pos.x > margin and screen_pos.y > margin and screen_pos.x < viewport_size.x - margin and screen_pos.y < viewport_size.y - margin
	_orbit_layer.visible = visible
	if not visible:
		return

	var chaos := 0.0
	if _arena_destabilization_manager != null and is_instance_valid(_arena_destabilization_manager):
		var value: Variant = _arena_destabilization_manager.get("instability")
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			chaos = clampf(float(value), 0.0, 1.0)
	var smear := 0.0
	if _time_dilation_manager != null and is_instance_valid(_time_dilation_manager):
		var scale_value: Variant = _time_dilation_manager.get("current_time_scale")
		if typeof(scale_value) == TYPE_FLOAT or typeof(scale_value) == TYPE_INT:
			smear = clampf(1.0 - float(scale_value), 0.0, 1.0)

	_orbit_layer.position = screen_pos + Vector2(sin(_hud_phase * 2.1), cos(_hud_phase * 1.7)) * (2.0 + chaos * 5.0)
	_orbit_layer.rotation += delta * (0.22 + chaos * 0.42 - smear * 0.18)
	var base_radius := 54.0 + chaos * 10.0

	var health_percent := _component_ratio("HealthComponent", "current_health", "max_health")
	var energy_percent := _component_ratio("EnergyComponent", "current_energy", "max_energy")
	var time_percent := 0.0
	if _time_dilation_manager != null and is_instance_valid(_time_dilation_manager):
		var current := float(_time_dilation_manager.get("current_dilation_capacity") or 0.0)
		var maximum := maxf(float(_time_dilation_manager.get("initial_dilation_capacity") or 1.0), 1.0)
		time_percent = clampf(current / maximum, 0.0, 1.0)
	var sling_state := {}
	if _player.has_method("get_slingshot_debug_state"):
		var sling_value: Variant = _player.call("get_slingshot_debug_state")
		if typeof(sling_value) == TYPE_DICTIONARY:
			sling_state = sling_value
	var sling_percent := clampf(float(sling_state.get("score", 0.0)), 0.0, 1.0)

	_set_orbit_arc(_health_arc, base_radius + 0.0, -PI * 0.72, health_percent, Color(1.0, 0.24, 0.18, 0.82), 0.0)
	_set_orbit_arc(_energy_arc, base_radius + 8.0, PI * 0.18, energy_percent, Color(0.22, 0.84, 1.0, 0.78), PI)
	_set_orbit_arc(_time_arc, base_radius + 16.0 + smear * 8.0, PI * 0.88, time_percent, Color(0.72, 0.36, 1.0, 0.68 + smear * 0.16), -PI * 0.4)
	_set_orbit_arc(_sling_arc, base_radius + 24.0, -PI * 0.04, sling_percent, _slingshot_color("READY", sling_percent), PI * 0.5)


func _set_orbit_arc(arc: Line2D, radius: float, start_angle: float, percent: float, color: Color, spin_offset: float) -> void:
	if arc == null:
		return
	var clamped := clampf(percent, 0.02, 1.0)
	var sweep := TAU * 0.82 * clamped
	arc.points = _arc_points(radius, start_angle + spin_offset, start_angle + spin_offset + sweep, 28)
	arc.default_color = _readability_color(color)
	arc.visible = percent > 0.01


func _component_ratio(component_name: String, current_property: String, max_property: String) -> float:
	if _player == null:
		return 0.0
	var component := _player.get_node_or_null(component_name)
	if component == null:
		return 0.0
	var current := float(component.get(current_property) or 0.0)
	var maximum := maxf(float(component.get(max_property) or 1.0), 1.0)
	return clampf(current / maximum, 0.0, 1.0)

func _chaos_tier_color(tier: int) -> Color:
	match clampi(tier, 0, 5):
		0:
			return Color(0.48, 0.78, 0.84, 1.0)
		1:
			return Color(0.42, 0.9, 1.0, 1.0)
		2:
			return Color(0.68, 1.0, 0.62, 1.0)
		3:
			return Color(1.0, 0.86, 0.32, 1.0)
		4:
			return Color(1.0, 0.38, 0.18, 1.0)
		_:
			return Color(0.9, 0.36, 1.0, 1.0)

func _slingshot_color(state: String, score: float) -> Color:
	match state:
		"APEX":
			return Color(1.0, 0.9, 0.24, 1.0)
		"PERFECT":
			return Color(0.3, 1.0, 0.86, 1.0)
		"SWEET":
			return Color(0.42, 0.86, 1.0, 1.0)
		"DANGER":
			return Color(1.0, 0.28, 0.18, 1.0)
		"COOLDOWN":
			return Color(0.55, 0.62, 0.75, 1.0)
	return Color(0.48 + score * 0.22, 0.78 + score * 0.18, 0.84 + score * 0.12, 1.0)

func _set_field_text(text: String, color: Color) -> void:
	_field_label.text = text
	_field_label.modulate = _readability_color(Color(color.r, color.g, color.b, 1.0))

func _on_powerup_applied(definition: PowerupDefinition, stacks: int) -> void:
	if definition == null or _powerup_notice_label == null:
		return

	_powerup_notice_label.text = "LAW ONLINE: %s  x%d" % [definition.display_name.to_upper(), stacks]
	_powerup_notice_color = definition.color
	_powerup_notice_time = 2.2

func _on_slingshot_mastery_triggered(data: Dictionary) -> void:
	if _powerup_notice_label == null:
		return

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var combo := int(data.get("combo", 1))
	var grade := String(data.get("grade", "good")).to_upper()
	if score < 0.58:
		return

	_powerup_notice_label.text = "%s SLINGSHOT  x%d" % [grade, combo]
	_powerup_notice_color = Color(1.0, 0.9, 0.28, 1.0) if grade == "APEX" else Color(0.34, 1.0, 0.86, 1.0)
	_powerup_notice_time = maxf(_powerup_notice_time, 1.15 + score * 0.45)

func _update_powerup_notice(delta: float) -> void:
	if _powerup_notice_label == null:
		return

	if _powerup_notice_time <= 0.0:
		_powerup_notice_label.modulate = _powerup_notice_label.modulate.lerp(Color.TRANSPARENT, clampf(delta * 7.0, 0.0, 1.0))
		return

	_powerup_notice_time -= delta
	var pulse := 0.72 + 0.28 * sin(Time.get_ticks_msec() / 70.0)
	_powerup_notice_label.modulate = Color(_powerup_notice_color.r, _powerup_notice_color.g, _powerup_notice_color.b, pulse)

func _on_event_horizon_started(data: Dictionary) -> void:
	if _powerup_notice_label == null:
		return

	_powerup_notice_label.text = "EVENT HORIZON"
	_powerup_notice_color = Color(1.0, 0.22, 0.12, 1.0).lerp(Color(0.72, 0.36, 1.0, 1.0), clampf(float(data.get("intensity", 0.8)), 0.0, 1.0))
	_powerup_notice_time = 1.35


func _on_horizon_escape_scored(data: Dictionary) -> void:
	if _powerup_notice_label == null:
		return

	_powerup_notice_label.text = "IMPOSSIBLE RECOVERY  %04d" % int(round(float(data.get("remaining_speed", 0.0))))
	_powerup_notice_color = Color(0.35, 1.0, 0.86, 1.0)
	_powerup_notice_time = 1.8

func _nearest_resonance_zone() -> Dictionary:
	if _resonance_manager == null or not _resonance_manager.has_method("get_active_resonance_zones"):
		return {}

	var zones_value: Variant = _resonance_manager.call("get_active_resonance_zones")
	if typeof(zones_value) != TYPE_ARRAY:
		return {}

	var best: Dictionary = {}
	var best_distance := INF
	for zone_value in zones_value:
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone: Dictionary = zone_value
		var center: Vector2 = zone.get("midpoint", Vector2.ZERO)
		var distance := center.distance_to(_player.global_position)
		if distance > nearest_field_notice_radius or distance >= best_distance:
			continue
		best = zone
		best_distance = distance

	return best

func _local_tide_state() -> Dictionary:
	var best: Dictionary = {}
	var best_intensity := 0.0
	var seen := {}

	for group_name in [&"arena_hazard", &"arena_destabilization_hazard"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			var id := node.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if not node.has_method("get_tide_debug_state"):
				continue

			var state_value: Variant = node.call("get_tide_debug_state", _player.global_position)
			if typeof(state_value) != TYPE_DICTIONARY:
				continue
			var state: Dictionary = state_value
			var intensity := float(state.get("local_intensity", 0.0))
			if intensity > best_intensity:
				best = state
				best_intensity = intensity

	return best


func _local_scar_state() -> Dictionary:
	if _scar_manager == null or not is_instance_valid(_scar_manager) or not _scar_manager.has_method("get_scar_debug_state"):
		return {}

	var state_value: Variant = _scar_manager.call("get_scar_debug_state", _player.global_position)
	if typeof(state_value) != TYPE_DICTIONARY:
		return {}

	var state: Dictionary = state_value
	var strongest_value: Variant = state.get("strongest", {})
	if typeof(strongest_value) != TYPE_DICTIONARY:
		return {}

	var strongest: Dictionary = strongest_value
	if strongest.is_empty():
		return {}

	return strongest


# ============================
# HEALTH VIGNETTE (NOW FIXED)
# ============================

func _update_health_vignette(delta: float) -> void:
	var health_component = _player.get_node_or_null("HealthComponent")
	var target_intensity: float = 0.0
	
	if health_component != null:
		var max_health: float = maxf(float(health_component.get("max_health") or 1.0), 1.0)
		var current_health: float = float(health_component.get("current_health") or 0.0)
		var health_percent: float = current_health / max_health
		
		if health_percent < 0.2:
			var pulse: float = 0.5 + sin(Time.get_ticks_msec() / 130.0) * 0.5
			target_intensity = lerpf(0.18, 0.52, pulse) * (1.0 - health_percent / 0.2)
	
	# Smoothly interpolate
	_current_vignette_intensity = lerpf(
		_current_vignette_intensity,
		target_intensity,
		clampf(delta * 8.0, 0.0, 1.0)
	)
	
	_vignette_material.set_shader_parameter("intensity", _current_vignette_intensity)


# ============================
# NAVIGATION ARROWS
# ============================

func _update_nav_arrows(_gravity_strength: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = viewport_size * 0.5
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var arrow_index: int = 0
	
	for planet in get_tree().get_nodes_in_group("planets"):
		if arrow_index >= _arrows.size():
			break
		if not (planet is Node2D):
			continue
			
		var p: Node2D = planet
		var screen_pos: Vector2 = canvas_transform * p.global_position
		
		var offscreen: bool = (
			screen_pos.x < 0 or screen_pos.y < 0 or
			screen_pos.x > viewport_size.x or screen_pos.y > viewport_size.y
		)
		
		var arrow: Polygon2D = _arrows[arrow_index]
		
		if offscreen:
			var direction: Vector2 = (screen_pos - center).normalized()
			if direction == Vector2.ZERO:
				direction = Vector2.UP
				
			var edge_pos: Vector2 = _project_to_screen_edge(center, direction, viewport_size)
			arrow.position = edge_pos
			arrow.rotation = direction.angle() + PI * 0.5
			arrow.visible = true
			arrow_index += 1
		else:
			arrow.visible = false
	
	# Hide remaining arrows
	for i in range(arrow_index, _arrows.size()):
		_arrows[i].visible = false


func _update_threat_arrows(delta: float) -> void:
	_threat_refresh_elapsed += delta
	if _threat_refresh_elapsed >= maxf(threat_arrow_refresh_interval, 0.05):
		_threat_refresh_elapsed = 0.0
		_refresh_threat_arrow_targets()

	_update_target_arrows(_boss_arrows, _boss_targets, Color(1.0, 0.16, 0.1, 0.96), true)
	_update_target_arrows(_threat_arrows, _threat_targets, Color(1.0, 0.72, 0.22, 0.88), false)


func _refresh_threat_arrow_targets() -> void:
	_boss_targets = _collect_offscreen_targets(&"bosses", max_boss_arrow_count, false)
	_threat_targets = _collect_offscreen_targets(&"enemies", max_threat_arrow_count, true)


func _collect_offscreen_targets(group_name: StringName, limit: int, skip_bosses: bool) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if limit <= 0 or _player == null:
		return targets

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()

	for node in get_tree().get_nodes_in_group(group_name):
		var target := node as Node2D
		if target == null or target == _player or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if skip_bosses and target.is_in_group("bosses"):
			continue

		var screen_pos: Vector2 = canvas_transform * target.global_position
		if not _is_screen_position_offscreen(screen_pos, viewport_size, 18.0):
			continue

		targets.append(target)

	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
	)

	if targets.size() > limit:
		targets.resize(limit)
	return targets


func _update_target_arrows(arrows: Array[Polygon2D], targets: Array[Node2D], base_color: Color, is_boss_arrow: bool) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = viewport_size * 0.5
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var arrow_index := 0

	for target in targets:
		if arrow_index >= arrows.size():
			break
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue

		var screen_pos: Vector2 = canvas_transform * target.global_position
		if not _is_screen_position_offscreen(screen_pos, viewport_size, 8.0):
			continue

		var direction: Vector2 = (screen_pos - center).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.UP

		var arrow := arrows[arrow_index]
		var distance := _player.global_position.distance_to(target.global_position)
		var proximity := 1.0 - clampf(distance / 2600.0, 0.0, 1.0)
		var pulse := 1.0
		if is_boss_arrow:
			pulse = 1.0 + 0.08 * sin(Time.get_ticks_msec() / 120.0)

		arrow.position = _project_to_screen_edge(center, direction, viewport_size)
		arrow.rotation = direction.angle() + PI * 0.5
		arrow.scale = Vector2.ONE * (1.35 if is_boss_arrow else 0.82) * pulse
		var adjusted_color := _readability_color(base_color)
		arrow.color = Color(adjusted_color.r, adjusted_color.g, adjusted_color.b, lerpf(0.62, adjusted_color.a, proximity))
		arrow.visible = true
		arrow_index += 1

	for i in range(arrow_index, arrows.size()):
		arrows[i].visible = false


func _is_screen_position_offscreen(screen_pos: Vector2, viewport_size: Vector2, padding: float) -> bool:
	return (
		screen_pos.x < -padding or screen_pos.y < -padding or
		screen_pos.x > viewport_size.x + padding or screen_pos.y > viewport_size.y + padding
	)


func _project_to_screen_edge(center: Vector2, direction: Vector2, viewport_size: Vector2) -> Vector2:
	var safe_half: Vector2 = viewport_size * 0.5 - Vector2.ONE * arrow_margin
	var scale_x: float = safe_half.x / maxf(absf(direction.x), 0.001)
	var scale_y: float = safe_half.y / maxf(absf(direction.y), 0.001)
	return center + direction * minf(scale_x, scale_y)


func _arc_points(radius: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(steps, 2)):
		var t := float(i) / float(maxi(steps - 1, 1))
		var angle := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _on_accessibility_changed(_settings: Dictionary) -> void:
	_apply_accessibility_settings(true)


func _apply_accessibility_settings(force: bool = false) -> void:
	if _hud_root == null or Settings == null:
		return
	var scale_value := clampf(float(Settings.ui_scale), 0.75, 1.35)
	if not force and is_equal_approx(scale_value, _last_ui_scale):
		return
	_last_ui_scale = scale_value
	_hud_root.scale = Vector2.ONE * scale_value


func _readability_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color
