extends CanvasLayer

const HUD_GLYPH_SCENE := preload("res://Nodes/vector_hud_glyph.tscn")

@export var max_arrow_count: int = 8
@export var max_threat_arrow_count: int = 8
@export var max_boss_arrow_count: int = 2
@export var max_rare_arrow_count: int = 3
@export var arrow_margin: float = 42.0
@export var threat_arrow_refresh_interval: float = 0.12
@export var g_warning_level: float = 850.0
@export var nearest_field_notice_radius: float = 760.0
@export var enable_player_orbit_telemetry: bool = false
@export var hud_safe_margin: float = 18.0
@export var left_panel_gap: float = 28.0
@export_group("Update Budgets")
@export_range(0.02, 0.2, 0.01) var gravity_meter_refresh_interval: float = 0.05
@export_range(0.05, 0.3, 0.01) var field_lens_refresh_interval: float = 0.12
@export_range(0.08, 0.5, 0.02) var navigation_target_refresh_interval: float = 0.2

var _player: Node2D
var _resonance_manager: Node
var _scar_manager: Node
var _time_dilation_manager: Node
var _event_horizon_manager: Node
var _arena_destabilization_manager: Node
var _powerup_inventory: Node
var _momentum_component: Node
var _weapon_system: Node
var _score_tracker: Node
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
var _health_resource_label: Label
var _health_resource_bar: ProgressBar
var _shield_resource_label: Label
var _shield_resource_bar: ProgressBar
var _energy_resource_label: Label
var _energy_resource_bar: ProgressBar
var _health_glyph: Control
var _shield_glyph: Control
var _energy_glyph: Control
var _speed_glyph: Control
var _gravity_glyph: Control
var _field_glyph: Control
var _time_glyph: Control
var _horizon_glyph: Control
var _chaos_glyph: Control
var _slingshot_glyph: Control
var _weapon_glyph: Control
var _phase_glyph: Control
var _hud_glyphs: Array[Control] = []
var _glyph_rows: Dictionary = {}
var _resource_panel: PanelContainer
var _readout_panel: PanelContainer
var _score_panel: PanelContainer
var _score_label: Label
var _score_detail_label: Label
var _anomaly_label: Label
var _challenge_label: Label
var _powerup_notice_label: Label
var _critical_vignette: ColorRect
var _vignette_material: ShaderMaterial
var _arrows: Array[Polygon2D] = []
var _threat_arrows: Array[Polygon2D] = []
var _boss_arrows: Array[Polygon2D] = []
var _rare_arrows: Array[Polygon2D] = []
var _arrow_layer: Node2D
var _orbit_layer: Node2D
var _health_arc: Line2D
var _energy_arc: Line2D
var _time_arc: Line2D
var _sling_arc: Line2D
var _threat_targets: Array[Node2D] = []
var _boss_targets: Array[Node2D] = []
var _rare_targets: Array[Node2D] = []
var _powerup_notice_time := 0.0
var _powerup_notice_color := Color(0.72, 1.0, 0.96, 1.0)
var _threat_refresh_elapsed := 999.0
var _score_pulse_time := 0.0
var _challenge_code := "--"
var _last_score_snapshot: Dictionary = {}
var _resource_previous_values: Dictionary = {}
var _resource_pulse_tweens: Dictionary = {}
var _last_weapon_notice_id: String = ""
var _last_weapon_pool_count: int = 0
var _gravity_sources: Array[Node2D] = []
var _planet_arrow_sources: Array[Node2D] = []
var _group_query_buffer: Array[Node2D] = []
var _hazard_seen_ids: Dictionary = {}
var _gravity_meter_elapsed: float = 999.0
var _field_lens_elapsed: float = 999.0
var _planet_arrow_refresh_elapsed: float = 999.0
var _last_layout_viewport_size := Vector2.ZERO

# Cache the current intensity to avoid repeated get_shader_parameter calls
var _current_vignette_intensity: float = 0.0
var _last_ui_scale: float = 1.0
var _hud_phase: float = 0.0

func _ready() -> void:
	layer = 40
	_build_hud()
	_player = MultiplayerTargeting.local_player(get_tree())
	_apply_accessibility_settings()
	if Settings != null and Settings.has_signal("accessibility_changed"):
		var callable := Callable(self, "_on_accessibility_changed")
		if not Settings.is_connected("accessibility_changed", callable):
			Settings.connect("accessibility_changed", callable)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.local_player(get_tree())
		return
	
	_update_speedometer()
	_update_resource_bars()
	_update_gravity_meter(delta)
	_resolve_rule_systems()
	_update_field_lens(delta)
	_update_time_lens()
	_update_horizon_lens()
	_update_chaos_lens()
	_update_slingshot_lens()
	_update_weapon_lens()
	_update_score_panel(delta)
	_update_powerup_notice(delta)
	_update_health_vignette(delta)
	_update_orbit_telemetry(delta)
	_update_nav_arrows(delta)
	_update_threat_arrows(delta)
	_apply_accessibility_settings()
	_layout_hud()


func _safe_viewport() -> Viewport:
	var viewport := get_viewport()
	if viewport != null:
		return viewport
	var tree := get_tree()
	if tree != null:
		return tree.root
	return null


func _safe_viewport_size() -> Vector2:
	var viewport := _safe_viewport()
	if viewport == null:
		return Vector2(1280.0, 720.0)
	var size := viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(1280.0, 720.0)
	return size


func _safe_canvas_transform() -> Transform2D:
	var viewport := _safe_viewport()
	return viewport.get_canvas_transform() if viewport != null else Transform2D.IDENTITY


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
	_build_resource_bars()
	_build_readout_panel()
	_build_score_panel()
	_build_powerup_notice()
	_build_nav_arrows()
	_build_orbit_telemetry()
	_layout_hud()


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


func _build_resource_bars() -> void:
	_resource_panel = PanelContainer.new()
	_resource_panel.name = "ResourceBarsPanel"
	_resource_panel.offset_left = 18.0
	_resource_panel.offset_top = 18.0
	_resource_panel.custom_minimum_size = Vector2(390.0, 148.0)
	_resource_panel.clip_contents = true
	_resource_panel.add_theme_stylebox_override(
		"panel",
		_make_hud_panel_style(Color(0.006, 0.012, 0.02, 0.86), Color(0.24, 0.92, 1.0, 0.58))
	)
	_hud_root.add_child(_resource_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	_resource_panel.add_child(rows)

	_health_resource_label = _make_resource_label("HULL 100/100")
	_health_resource_bar = _make_resource_bar(Color(1.0, 0.22, 0.14, 0.96), 20.0)
	_health_glyph = _add_glyph_label_row(rows, _health_resource_label, &"hull", Color(1.0, 0.22, 0.14, 0.96))
	rows.add_child(_health_resource_bar)

	_shield_resource_label = _make_resource_label("SHIELD 000/000")
	_shield_resource_bar = _make_resource_bar(Color(0.24, 0.72, 1.0, 0.94), 16.0)
	_shield_glyph = _add_glyph_label_row(rows, _shield_resource_label, &"shield", Color(0.24, 0.72, 1.0, 0.94))
	rows.add_child(_shield_resource_bar)

	_energy_resource_label = _make_resource_label("ENERGY 0000/0000")
	_energy_resource_bar = _make_resource_bar(Color(0.34, 1.0, 0.78, 0.94), 16.0)
	_energy_glyph = _add_glyph_label_row(rows, _energy_resource_label, &"energy", Color(0.34, 1.0, 0.78, 0.94))
	rows.add_child(_energy_resource_bar)


func _make_resource_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = _readability_color(Color(0.78, 0.96, 0.98, 1.0))
	return label


func _make_resource_bar(fill_color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(350.0, height)
	_style_progress_bar(bar, fill_color)
	return bar


func _add_glyph_label_row(parent: Container, label: Label, kind: StringName, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var glyph := HUD_GLYPH_SCENE.instantiate() as Control
	glyph.custom_minimum_size = Vector2(18.0, 18.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.call("configure", kind, color, Color(1.0, 0.84, 0.3, 1.0))
	row.add_child(glyph)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_hud_glyphs.append(glyph)
	_glyph_rows[label.get_instance_id()] = row
	return glyph


func _set_glyph_state(glyph: Control, value: float, color: Color = Color.TRANSPARENT) -> void:
	if glyph == null or not is_instance_valid(glyph):
		return
	if color.a > 0.0 and glyph.has_method("set_palette"):
		glyph.call("set_palette", color)
	if glyph.has_method("set_signal"):
		glyph.call("set_signal", value, 0.0)
	elif glyph.has_method("set_activity"):
		glyph.call("set_activity", value)


func _set_glyph_alert(glyph: Control, value: float, warning: float, color: Color = Color.TRANSPARENT) -> void:
	if glyph == null or not is_instance_valid(glyph):
		return
	if color.a > 0.0 and glyph.has_method("set_palette"):
		glyph.call("set_palette", color)
	if glyph.has_method("set_signal"):
		glyph.call("set_signal", value, warning)
	elif glyph.has_method("set_activity"):
		glyph.call("set_activity", maxf(value, warning))


func _build_readout_panel() -> void:
	_readout_panel = PanelContainer.new()
	_readout_panel.name = "VectorReadoutPanel"
	_readout_panel.offset_left = 18.0
	_readout_panel.offset_top = 138.0
	_readout_panel.custom_minimum_size = Vector2(330.0, 336.0)
	_readout_panel.clip_contents = true
	_hud_root.add_child(_readout_panel)
	
	_readout_panel.add_theme_stylebox_override(
		"panel",
		_make_hud_panel_style(Color(0.006, 0.012, 0.02, 0.82), Color(0.18, 0.88, 0.72, 0.58))
	)
	
	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	rows.clip_contents = true
	_readout_panel.add_child(rows)

	var header := Label.new()
	header.text = "VECTOR SUITE"
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = _readability_color(Color(0.58, 1.0, 0.92, 1.0))
	rows.add_child(header)
	
	_speed_label = Label.new()
	_speed_label.text = "SPD 0000"
	_style_hud_label(_speed_label, 12)
	_speed_glyph = _add_glyph_label_row(rows, _speed_label, &"speed", Color(0.2, 0.86, 1.0, 1.0))
	
	_speed_bar = ProgressBar.new()
	_speed_bar.show_percentage = false
	_speed_bar.custom_minimum_size = Vector2(228, 14)
	_style_progress_bar(_speed_bar, Color(0.2, 0.86, 1.0, 0.9))
	rows.add_child(_speed_bar)
	
	_g_label = Label.new()
	_g_label.text = "G 000"
	_style_hud_label(_g_label, 12)
	_gravity_glyph = _add_glyph_label_row(rows, _g_label, &"gravity", Color(1.0, 0.58, 0.18, 0.96))
	
	_g_bar = ProgressBar.new()
	_g_bar.show_percentage = false
	_g_bar.max_value = g_warning_level
	_g_bar.custom_minimum_size = Vector2(228, 14)
	_style_progress_bar(_g_bar, Color(1.0, 0.58, 0.18, 0.9))
	rows.add_child(_g_bar)

	_field_label = Label.new()
	_field_label.text = "FIELD CLEAR"
	_field_label.clip_text = true
	_style_hud_label(_field_label, 12)
	_field_glyph = _add_glyph_label_row(rows, _field_label, &"field", Color(0.34, 1.0, 0.86, 1.0))

	_time_label = Label.new()
	_time_label.text = "TIME READY"
	_time_label.clip_text = true
	_style_hud_label(_time_label, 12)
	_time_glyph = _add_glyph_label_row(rows, _time_label, &"time", Color(0.72, 0.38, 1.0, 1.0))

	_horizon_label = Label.new()
	_horizon_label.text = "HORIZON QUIET"
	_horizon_label.clip_text = true
	_style_hud_label(_horizon_label, 12)
	_horizon_glyph = _add_glyph_label_row(rows, _horizon_label, &"horizon", Color(1.0, 0.42, 0.22, 1.0))

	_chaos_label = Label.new()
	_chaos_label.text = "CHAOS T0 CALIBRATION"
	_chaos_label.clip_text = true
	_style_hud_label(_chaos_label, 12)
	_chaos_glyph = _add_glyph_label_row(rows, _chaos_label, &"chaos", Color(1.0, 0.58, 0.18, 1.0))

	_slingshot_label = Label.new()
	_slingshot_label.text = "SLING SEARCH"
	_slingshot_label.clip_text = true
	_style_hud_label(_slingshot_label, 12)
	_slingshot_glyph = _add_glyph_label_row(rows, _slingshot_label, &"slingshot", Color(0.34, 1.0, 0.82, 1.0))

	_slingshot_bar = ProgressBar.new()
	_slingshot_bar.show_percentage = false
	_slingshot_bar.max_value = 1.0
	_slingshot_bar.custom_minimum_size = Vector2(228, 12)
	_style_progress_bar(_slingshot_bar, Color(0.34, 1.0, 0.82, 0.9))
	rows.add_child(_slingshot_bar)

	_combo_label = Label.new()
	_combo_label.text = "VECTOR CHAIN --"
	_combo_label.clip_text = true
	_style_hud_label(_combo_label, 12)
	rows.add_child(_combo_label)

	_weapon_label = Label.new()
	_weapon_label.text = "WEAPON VECTOR BOLT"
	_weapon_label.clip_text = true
	_style_hud_label(_weapon_label, 12)
	_weapon_glyph = _add_glyph_label_row(rows, _weapon_label, &"weapon", Color(1.0, 0.72, 0.24, 0.92))

	_weapon_bar = ProgressBar.new()
	_weapon_bar.show_percentage = false
	_weapon_bar.max_value = 1.0
	_weapon_bar.custom_minimum_size = Vector2(228, 12)
	_style_progress_bar(_weapon_bar, Color(1.0, 0.72, 0.24, 0.92))
	rows.add_child(_weapon_bar)

func _build_score_panel() -> void:
	_score_panel = PanelContainer.new()
	_score_panel.name = "RunScorePanel"
	_score_panel.anchor_left = 1.0
	_score_panel.anchor_right = 1.0
	_score_panel.offset_left = -382.0
	_score_panel.offset_right = -18.0
	_score_panel.offset_top = 20.0
	_score_panel.offset_bottom = 146.0
	_score_panel.custom_minimum_size = Vector2(364.0, 126.0)
	_score_panel.add_theme_stylebox_override(
		"panel",
		_make_hud_panel_style(Color(0.012, 0.014, 0.024, 0.84), Color(1.0, 0.76, 0.28, 0.62))
	)
	_hud_root.add_child(_score_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	_score_panel.add_child(rows)

	var header := Label.new()
	header.text = "RUN SCORE"
	header.add_theme_font_size_override("font_size", 12)
	header.modulate = _readability_color(Color(1.0, 0.78, 0.3, 1.0))
	_phase_glyph = _add_glyph_label_row(rows, header, &"phase", Color(1.0, 0.78, 0.3, 1.0))

	_score_label = Label.new()
	_score_label.text = "000000"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_font_size_override("font_size", 28)
	_score_label.modulate = _readability_color(Color(1.0, 0.96, 0.72, 1.0))
	rows.add_child(_score_label)

	_score_detail_label = Label.new()
	_score_detail_label.text = "W0  B0  ANOM 0"
	_style_hud_label(_score_detail_label, 12)
	rows.add_child(_score_detail_label)

	_anomaly_label = Label.new()
	_anomaly_label.text = "LAST ANOMALY --"
	_anomaly_label.clip_text = true
	_style_hud_label(_anomaly_label, 11)
	rows.add_child(_anomaly_label)

	_challenge_label = Label.new()
	_challenge_label.text = "CODE --"
	_challenge_label.clip_text = true
	_style_hud_label(_challenge_label, 10)
	rows.add_child(_challenge_label)

func _make_hud_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 14.0)
	style.set_content_margin(SIDE_TOP, 12.0)
	style.set_content_margin(SIDE_RIGHT, 14.0)
	style.set_content_margin(SIDE_BOTTOM, 12.0)
	return style

func _style_hud_label(label: Label, font_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = _readability_color(Color(0.76, 0.94, 0.95, 1.0))

func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.032, 0.046, 0.82)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

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

	for i in range(max_rare_arrow_count):
		var arrow := _make_rare_screen_arrow("RareEventArrow%d" % i, Color(0.74, 0.5, 1.0, 0.9), 1.0, 4)
		_arrow_layer.add_child(arrow)
		_rare_arrows.append(arrow)


func _build_orbit_telemetry() -> void:
	_orbit_layer = Node2D.new()
	_orbit_layer.name = "PlayerOrbitTelemetry"
	_orbit_layer.z_index = 6
	_orbit_layer.visible = false
	add_child(_orbit_layer)

	if not enable_player_orbit_telemetry:
		return

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


func _make_rare_screen_arrow(node_name: String, color: Color, arrow_scale: float, z: int) -> Polygon2D:
	var arrow := Polygon2D.new()
	arrow.name = node_name
	arrow.polygon = PackedVector2Array([
		Vector2(0.0, -16.0),
		Vector2(16.0, 0.0),
		Vector2(0.0, 16.0),
		Vector2(-16.0, 0.0),
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
	var speed_ratio := clampf(speed / current_max_speed, 0.0, 1.0)
	var speed_color := Color(0.2, 0.86, 1.0, 1.0).lerp(Color(1.0, 0.9, 0.24, 1.0), clampf((speed_ratio - 0.68) / 0.32, 0.0, 1.0))
	_speed_label.modulate = _readability_color(speed_color)
	_set_glyph_state(_speed_glyph, speed_ratio, speed_color)


func _update_resource_bars() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var health := _resource_pair("HealthComponent", "current_health", "max_health")
	_apply_resource_bar(
		_health_resource_label,
		_health_resource_bar,
		"HULL",
		float(health.get("current", 0.0)),
		float(health.get("max", 1.0)),
		Color(1.0, 0.22, 0.14, 1.0)
	)
	var health_ratio := float(health.get("current", 0.0)) / maxf(float(health.get("max", 1.0)), 1.0)
	_set_glyph_alert(_health_glyph, 1.0 - health_ratio, clampf((0.32 - health_ratio) / 0.32, 0.0, 1.0), Color(1.0, 0.22, 0.14, 1.0))

	var shield := _resource_pair("Shield", "current_energy", "max_capacity")
	var shield_color := Color(0.24, 0.72, 1.0, 1.0)
	var shield_node := _player.get_node_or_null("Shield")
	var shield_broken_value: Variant = shield_node.get("is_broken") if shield_node != null else false
	if typeof(shield_broken_value) == TYPE_BOOL and bool(shield_broken_value):
		shield_color = Color(0.78, 0.42, 0.95, 1.0)
	_apply_resource_bar(
		_shield_resource_label,
		_shield_resource_bar,
		"SHIELD",
		float(shield.get("current", 0.0)),
		float(shield.get("max", 1.0)),
		shield_color
	)
	var shield_ratio := float(shield.get("current", 0.0)) / maxf(float(shield.get("max", 1.0)), 1.0)
	var shield_broken := typeof(shield_broken_value) == TYPE_BOOL and bool(shield_broken_value)
	_set_glyph_alert(_shield_glyph, 1.0 if shield_broken else shield_ratio, 1.0 if shield_broken else 0.0, shield_color)

	var energy := _resource_pair("EnergyComponent", "current_energy", "max_energy")
	_apply_resource_bar(
		_energy_resource_label,
		_energy_resource_bar,
		"ENERGY",
		float(energy.get("current", 0.0)),
		float(energy.get("max", 1.0)),
		Color(0.34, 1.0, 0.78, 1.0)
	)
	var energy_ratio := float(energy.get("current", 0.0)) / maxf(float(energy.get("max", 1.0)), 1.0)
	_set_glyph_alert(_energy_glyph, energy_ratio, clampf((0.2 - energy_ratio) / 0.2, 0.0, 1.0), Color(0.34, 1.0, 0.78, 1.0))


func _resource_pair(node_name: String, current_property: String, max_property: String) -> Dictionary:
	var component := _player.get_node_or_null(node_name) if _player != null else null
	if component == null:
		return {"current": 0.0, "max": 1.0}
	var current_value: Variant = component.get(current_property)
	var max_value: Variant = component.get(max_property)
	var current := float(current_value) if typeof(current_value) == TYPE_FLOAT or typeof(current_value) == TYPE_INT else 0.0
	var maximum := float(max_value) if typeof(max_value) == TYPE_FLOAT or typeof(max_value) == TYPE_INT else 1.0
	return {"current": current, "max": maxf(maximum, 1.0)}


func _apply_resource_bar(
	label: Label,
	bar: ProgressBar,
	resource_name: String,
	current: float,
	maximum: float,
	color: Color
) -> void:
	if label == null or bar == null:
		return
	bar.max_value = maxf(maximum, 1.0)
	_pulse_resource_bar(resource_name, bar, current, maximum, color)
	bar.value = clampf(current, 0.0, bar.max_value)
	label.text = "%s %d/%d" % [resource_name, int(round(current)), int(round(maximum))]
	label.modulate = _readability_color(color)
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = color


func _pulse_resource_bar(resource_name: String, bar: ProgressBar, current: float, maximum: float, color: Color) -> void:
	var previous_value: Variant = _resource_previous_values.get(resource_name, null)
	_resource_previous_values[resource_name] = current
	if not (previous_value is float or previous_value is int):
		return
	var previous := float(previous_value)
	var delta := current - previous
	var threshold := maxf(3.0, maxf(maximum, 1.0) * 0.025)
	if absf(delta) < threshold:
		return

	var old_tween_value: Variant = _resource_pulse_tweens.get(resource_name, null)
	var old_tween := old_tween_value as Tween
	if old_tween != null:
		old_tween.kill()

	var impact_color := Color(1.0, 0.18, 0.1, 1.0) if delta < 0.0 else Color(0.42, 1.0, 0.78, 1.0)
	var tween := create_tween()
	_resource_pulse_tweens[resource_name] = tween
	bar.pivot_offset = bar.size * 0.5
	bar.modulate = impact_color
	bar.scale = Vector2(1.03, 1.28)
	tween.tween_property(bar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bar, "modulate", _readability_color(color), 0.24)


# ============================
# GRAVITY METER
# ============================

func _update_gravity_meter(delta: float) -> void:
	_gravity_meter_elapsed += delta
	if _gravity_meter_elapsed < maxf(gravity_meter_refresh_interval, 0.02):
		return
	_gravity_meter_elapsed = 0.0
	var gravity: Vector2 = _calculate_gravity_at_player()
	var strength: float = gravity.length()
	
	_g_bar.value = clampf(strength, 0.0, g_warning_level)
	_g_label.text = "G %03d" % int(round(strength))
	var gravity_warning := clampf((strength - g_warning_level * 0.72) / maxf(g_warning_level * 0.28, 1.0), 0.0, 1.0)
	var gravity_color := Color(0.78, 1.0, 0.96, 1.0).lerp(Color(1.0, 0.16, 0.1, 1.0), gravity_warning)
	_g_label.modulate = _readability_color(gravity_color)
	_set_glyph_alert(_gravity_glyph, clampf(strength / maxf(g_warning_level, 1.0), 0.0, 1.0), gravity_warning, gravity_color)


func _calculate_gravity_at_player() -> Vector2:
	var gravity_constant: float = float(_player.get("gravity_constant") or 0.0)
	var min_grav_dist: float = maxf(float(_player.get("min_grav_dist") or 1.0), 1.0)
	var pull_radius := maxf(float(_player.get("gravity_pull_radius") or 0.0), 0.0)
	var max_sources := maxi(int(_player.get("max_gravity_sources") or 4), 1)
	var per_source_cap := maxf(float(_player.get("max_gravity_acceleration_per_source") or 3600.0), 1.0)
	var total_cap := maxf(float(_player.get("max_total_gravity_acceleration") or 7200.0), 1.0)

	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(
			_player.global_position,
			_gravity_sources,
			max_sources,
			pull_radius,
			_player
		)
	else:
		var cached_sources: Variant = _player.get("planets")
		if cached_sources is Array:
			for value in cached_sources:
				var source := value as Node2D
				if source != null and is_instance_valid(source) and not source.is_queued_for_deletion():
					_gravity_sources.append(source)
					if _gravity_sources.size() >= max_sources:
						break

	var total := Vector2.ZERO
	for source in _gravity_sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		var offset := source.global_position - _player.global_position
		var raw_distance := offset.length()
		if raw_distance <= 0.001 or (pull_radius > 0.0 and raw_distance > pull_radius):
			continue
		var mass_value: Variant = source.get("mass")
		var source_mass := float(mass_value) if mass_value is float or mass_value is int else 100.0
		var distance := maxf(raw_distance, min_grav_dist)
		var contribution := offset / raw_distance * gravity_constant * source_mass / (distance * distance)
		total = (total + contribution.limit_length(per_source_cap)).limit_length(total_cap)
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

	if _score_tracker == null or not is_instance_valid(_score_tracker):
		_score_tracker = get_tree().get_first_node_in_group("run_score_tracker")
		if _score_tracker == null:
			_score_tracker = root.find_child("RunScoreTracker", true, false)
		if _score_tracker != null:
			if _score_tracker.has_signal("score_changed"):
				var score_callable := Callable(self, "_on_score_changed")
				if not _score_tracker.is_connected("score_changed", score_callable):
					_score_tracker.connect("score_changed", score_callable)
			if _score_tracker.has_signal("challenge_code_changed"):
				var code_callable := Callable(self, "_on_challenge_code_changed")
				if not _score_tracker.is_connected("challenge_code_changed", code_callable):
					_score_tracker.connect("challenge_code_changed", code_callable)
			if _score_tracker.has_signal("physics_anomaly_achieved"):
				var anomaly_callable := Callable(self, "_on_physics_anomaly_achieved")
				if not _score_tracker.is_connected("physics_anomaly_achieved", anomaly_callable):
					_score_tracker.connect("physics_anomaly_achieved", anomaly_callable)
			if _score_tracker.has_method("get_score_snapshot"):
				var snapshot_value: Variant = _score_tracker.call("get_score_snapshot")
				if typeof(snapshot_value) == TYPE_DICTIONARY:
					_apply_score_snapshot(int(snapshot_value.get("score", 0)), snapshot_value)
			if _score_tracker.has_method("get_challenge_code"):
				_on_challenge_code_changed(String(_score_tracker.call("get_challenge_code")))

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
			_connect_weapon_system_signals(weapon_system)

func _update_field_lens(delta: float) -> void:
	if _field_label == null:
		return
	_field_lens_elapsed += delta
	if _field_lens_elapsed < maxf(field_lens_refresh_interval, 0.05):
		return
	_field_lens_elapsed = 0.0

	var tide_state := _local_tide_state()
	if not tide_state.is_empty():
		var tide_intensity := clampf(float(tide_state.get("local_intensity", 0.0)), 0.0, 1.0)
		_set_field_text(
			"TIDE %s  %s %d%%" % [
				String(tide_state.get("display_name", "Tide")).to_upper(),
				String(tide_state.get("rule_name", "FIELD")),
				int(round(float(tide_state.get("local_intensity", 0.0)) * 100.0)),
			],
			tide_state.get("color", Color(0.78, 1.0, 0.96, 1.0)),
			tide_intensity
		)
		return

	var scar_state := _local_scar_state()
	if not scar_state.is_empty():
		var scar_intensity := clampf(float(scar_state.get("local_intensity", 0.0)), 0.0, 1.0)
		_set_field_text(
			"SCAR %s  %s %d%%" % [
				String(scar_state.get("display_name", "Scar")).to_upper(),
				String(scar_state.get("rule_name", "BEND")),
				int(round(float(scar_state.get("local_intensity", 0.0)) * 100.0)),
			],
			scar_state.get("color", Color(0.78, 1.0, 0.96, 1.0)),
			scar_intensity
		)
		return

	if _resonance_manager != null and _resonance_manager.has_method("get_resonance_zone_at_position"):
		var zone_value: Variant = _resonance_manager.call("get_resonance_zone_at_position", _player.global_position)
		if typeof(zone_value) == TYPE_DICTIONARY:
			var zone: Dictionary = zone_value
			if not zone.is_empty():
				var zone_intensity := clampf(float(zone.get("local_intensity", 0.0)), 0.0, 1.0)
				_set_field_text(
					"FIELD %s  %s %d%%" % [
						String(zone.get("zone_display_name", "Zone")).to_upper(),
						String(zone.get("zone_rule_name", "FIELD")),
						int(round(float(zone.get("local_intensity", 0.0)) * 100.0)),
					],
					zone.get("zone_color", Color(0.78, 1.0, 0.96, 1.0)),
					zone_intensity
				)
				return

	var nearest_zone := _nearest_resonance_zone()
	if not nearest_zone.is_empty():
		_set_field_text(
			"NEAR %s  %s" % [
				String(nearest_zone.get("zone_display_name", "Zone")).to_upper(),
				String(nearest_zone.get("zone_rule_name", "FIELD")),
			],
			nearest_zone.get("zone_color", Color(0.48, 0.78, 0.84, 1.0)),
			0.28
		)
		return

	_set_field_text("FIELD CLEAR", Color(0.48, 0.78, 0.84, 1.0), 0.04)

func _update_time_lens() -> void:
	if _time_label == null:
		return

	if _time_dilation_manager == null or not is_instance_valid(_time_dilation_manager):
		_time_label.text = "TIME OFFLINE"
		_time_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		_set_glyph_state(_time_glyph, 0.0, Color(0.48, 0.78, 0.84, 1.0))
		return

	var capacity := float(_time_dilation_manager.get("current_dilation_capacity") or 0.0)
	var maximum := maxf(float(_time_dilation_manager.get("initial_dilation_capacity") or 1.0), 1.0)
	var dilating := bool(_time_dilation_manager.get("is_dilating")) if typeof(_time_dilation_manager.get("is_dilating")) == TYPE_BOOL else false
	var scale := float(_time_dilation_manager.get("current_time_scale") or Engine.time_scale)
	var state := "DILATING" if dilating else "READY"
	var field_targets := int(_time_dilation_manager.get("active_field_target_count") or 0)

	_time_label.text = "TIME %s  x%.2f %d%%" % [state, scale, int(round(capacity / maximum * 100.0))]
	if dilating:
		_time_label.text += "  // %d IN FIELD" % field_targets
	var time_color := Color(0.72, 0.38, 1.0, 1.0) if dilating else Color(0.72, 1.0, 0.96, 1.0)
	_time_label.modulate = _readability_color(time_color)
	_set_glyph_state(_time_glyph, clampf(1.0 - scale, 0.0, 1.0) if dilating else capacity / maximum * 0.18, time_color)

func _update_horizon_lens() -> void:
	if _horizon_label == null:
		return

	if _event_horizon_manager == null or not is_instance_valid(_event_horizon_manager):
		_horizon_label.text = "HORIZON QUIET"
		_horizon_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		_set_glyph_state(_horizon_glyph, 0.0, Color(0.48, 0.78, 0.84, 1.0))
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
		var horizon_color := Color(1.0, 0.22, 0.12, 1.0).lerp(Color(0.72, 0.36, 1.0, 1.0), intensity * 0.55)
		_horizon_label.text = "HORIZON ESCAPE  %03d%%" % int(round(intensity * 100.0))
		_horizon_label.modulate = _readability_color(horizon_color)
		_set_glyph_alert(_horizon_glyph, intensity, intensity, horizon_color)
	elif cooldown > 0.0:
		var cooldown_color := Color(0.78, 0.54, 1.0, 1.0)
		_horizon_label.text = "HORIZON RECOVER  %.0fs" % cooldown
		_horizon_label.modulate = _readability_color(cooldown_color)
		_set_glyph_state(_horizon_glyph, 0.24, cooldown_color)
	else:
		_horizon_label.text = "HORIZON QUIET"
		_horizon_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		_set_glyph_state(_horizon_glyph, 0.0, Color(0.48, 0.78, 0.84, 1.0))

func _update_chaos_lens() -> void:
	if _chaos_label == null:
		return

	if _arena_destabilization_manager == null or not is_instance_valid(_arena_destabilization_manager):
		_chaos_label.text = "CHAOS T0 CALIBRATION"
		_chaos_label.modulate = _readability_color(Color(0.48, 0.78, 0.84, 1.0))
		_set_glyph_state(_chaos_glyph, 0.0, Color(0.48, 0.78, 0.84, 1.0))
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
	var chaos_color := _chaos_tier_color(tier)
	_chaos_label.modulate = _readability_color(chaos_color)
	_set_glyph_state(_chaos_glyph, instability, chaos_color)

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
	var color := _slingshot_color(state, score)

	_slingshot_bar.value = score
	_slingshot_label.text = "SLING %s %03d%%  T%04d D%03d" % [
		state,
		int(round(score * 100.0)),
		int(round(tangential)),
		int(round(distance)),
	]
	_slingshot_label.modulate = _readability_color(color)
	_set_glyph_state(_slingshot_glyph, score, color)

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
		_set_glyph_state(_weapon_glyph, 0.0, Color(0.48, 0.78, 0.84, 1.0))
		return

	var state_value: Variant = _weapon_system.call("get_weapon_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return

	var state: Dictionary = state_value
	var display_name := String(state.get("display_name", "Vector Bolt")).to_upper()
	var active := bool(state.get("beam_active", false))
	var energy_percent := clampf(float(state.get("energy_percent", 0.0)), 0.0, 1.0)
	var fire_mode := StringName(state.get("fire_mode", &"projectile"))
	var mode_label := String(fire_mode).to_upper()
	var cost := float(state.get("cost_per_second", 0.0)) if fire_mode == &"beam" else float(state.get("cost_per_shot", 0.0))
	var cost_label := "/s" if fire_mode == &"beam" else "/shot"
	if fire_mode == &"field":
		cost = float(state.get("cost_per_use", 0.0))
		cost_label = "/use"
	var color: Color = state.get("color", Color(0.34, 1.0, 0.86, 1.0))
	var ready := bool(state.get("ready", energy_percent > 0.12))
	var state_label := "FIRING" if active else ("READY" if ready else "LOW ENERGY")
	var unlocked := int(state.get("unlocked_count", state.get("count", 1)))
	var total := maxi(int(state.get("total_weapon_count", unlocked)), unlocked)
	var next_wave := int(state.get("next_unlock_wave", -1))
	var pool_label := "ALL" if total <= unlocked else "%d/%d" % [unlocked, total]
	var next_label := " NEXT W%d" % next_wave if next_wave > 0 and total > unlocked else ""

	_weapon_label.text = "%s  %s %s  E%.0f%s  %s%s" % [display_name, mode_label, state_label, cost, cost_label, pool_label, next_label]
	_weapon_label.modulate = _readability_color(color)
	_weapon_bar.modulate = _readability_color(color.lerp(Color.WHITE, 0.16 if ready else 0.46))
	_weapon_bar.value = energy_percent
	_set_glyph_alert(_weapon_glyph, 1.0 if active else energy_percent, 0.0 if ready else 0.82, color)

func _update_score_panel(delta: float) -> void:
	if _score_label == null:
		return
	var run_phase := int(RunProgress.get("phase") or 0) if RunProgress != null else 0
	var phase_ratio := clampf(float(run_phase) / 6.0, 0.0, 1.0)
	_set_glyph_state(_phase_glyph, phase_ratio, Color(1.0, 0.78, 0.3, 1.0).lerp(Color(0.82, 0.38, 1.0, 1.0), phase_ratio))

	if _score_tracker != null and is_instance_valid(_score_tracker) and _score_tracker.has_method("get_score_snapshot"):
		var snapshot_value: Variant = _score_tracker.call("get_score_snapshot")
		if typeof(snapshot_value) == TYPE_DICTIONARY:
			_apply_score_snapshot(int(snapshot_value.get("score", 0)), snapshot_value)
	elif RunProgress != null:
		var flags_value: Variant = RunProgress.get("arena_flags")
		if typeof(flags_value) == TYPE_DICTIONARY:
			var flags: Dictionary = flags_value
			var snapshot_value: Variant = flags.get("score_snapshot", {})
			if typeof(snapshot_value) == TYPE_DICTIONARY:
				_apply_score_snapshot(int(snapshot_value.get("score", 0)), snapshot_value)
			var code_value := String(flags.get("challenge_code", _challenge_code))
			if code_value != _challenge_code and not code_value.is_empty():
				_on_challenge_code_changed(code_value)

	_score_pulse_time = maxf(_score_pulse_time - delta, 0.0)
	var glow := 0.0
	if _score_pulse_time > 0.0:
		glow = clampf(_score_pulse_time / 0.72, 0.0, 1.0)
	_score_label.modulate = _readability_color(Color(1.0, 0.94, 0.68, 1.0).lerp(Color(0.38, 1.0, 0.86, 1.0), glow))
	if _score_panel != null:
		_score_panel.modulate = Color(1.0, 1.0, 1.0, 0.9 + glow * 0.1)
	if _phase_glyph != null:
		_set_glyph_alert(_phase_glyph, phase_ratio, glow * 0.35, Color(1.0, 0.78, 0.3, 1.0).lerp(Color(0.82, 0.38, 1.0, 1.0), phase_ratio))

func _on_score_changed(score: int, snapshot: Dictionary) -> void:
	_apply_score_snapshot(score, snapshot)
	_score_pulse_time = 0.34

func _on_challenge_code_changed(code: String) -> void:
	_challenge_code = code if not code.is_empty() else "--"
	if _challenge_label != null:
		_challenge_label.text = "CODE %s" % _challenge_code

func _on_physics_anomaly_achieved(type: String, kinetic_factor: float, score_value: int, snapshot: Dictionary) -> void:
	var label := _readable_anomaly_name(type)
	if _anomaly_label != null:
		_anomaly_label.text = "LAST %s  x%.2f  +%d" % [label, kinetic_factor, score_value]
		_anomaly_label.modulate = _readability_color(Color(0.38, 1.0, 0.86, 1.0))
	_apply_score_snapshot(int(snapshot.get("score", 0)), snapshot)
	_score_pulse_time = 0.72

func _apply_score_snapshot(score: int, snapshot: Dictionary) -> void:
	_last_score_snapshot = snapshot.duplicate(true)
	if _score_label != null:
		_score_label.text = "%06d" % maxi(score, 0)
	if _score_detail_label != null:
		var chain_count := int(snapshot.get("run_chain_count", 0))
		var chain_timer := float(snapshot.get("run_chain_timer", 0.0))
		if chain_count > 0 and chain_timer > 0.0:
			_score_detail_label.text = "FLOW x%d  %.2fx  %.1fs" % [
				chain_count,
				float(snapshot.get("run_chain_multiplier", 1.0)),
				chain_timer,
			]
		else:
			_score_detail_label.text = "W%d  B%d  ANOM %d" % [
				int(snapshot.get("waves_cleared", snapshot.get("wave", 0))),
				int(snapshot.get("bosses_defeated", 0)) + int(snapshot.get("secret_bosses_defeated", 0)),
				int(snapshot.get("physics_anomaly_total", 0)),
			]
	if _anomaly_label != null:
		var last_value: Variant = snapshot.get("last_physics_anomaly", {})
		if typeof(last_value) == TYPE_DICTIONARY:
			var last: Dictionary = last_value
			if not last.is_empty():
				_anomaly_label.text = "LAST %s  +%d" % [
					_readable_anomaly_name(String(last.get("type", "--"))),
					int(last.get("score", 0)),
				]

func _readable_anomaly_name(type: String) -> String:
	var words := type.replace("_", " ").strip_edges().to_upper()
	return words if not words.is_empty() else "--"

func _update_orbit_telemetry(delta: float) -> void:
	if not enable_player_orbit_telemetry:
		if _orbit_layer != null:
			_orbit_layer.visible = false
		return
	if _orbit_layer == null or _player == null or not is_instance_valid(_player):
		return

	_hud_phase += delta
	var viewport_size: Vector2 = _safe_viewport_size()
	var canvas_transform: Transform2D = _safe_canvas_transform()
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

func _set_field_text(text: String, color: Color, intensity: float = 0.12) -> void:
	_field_label.text = text
	_field_label.modulate = _readability_color(Color(color.r, color.g, color.b, 1.0))
	_set_glyph_state(_field_glyph, intensity, Color(color.r, color.g, color.b, 1.0))

func _on_powerup_applied(definition: PowerupDefinition, stacks: int) -> void:
	if definition == null or _powerup_notice_label == null:
		return

	_powerup_notice_label.text = "LAW ONLINE: %s  x%d" % [definition.display_name.to_upper(), stacks]
	_powerup_notice_color = definition.color
	_powerup_notice_time = 2.2


func show_mod_notice(text: String, color: Color = Color(0.34, 1.0, 0.86, 1.0), duration: float = 1.6) -> void:
	if _powerup_notice_label == null:
		return
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return
	_powerup_notice_label.text = clean_text
	_powerup_notice_color = color
	_powerup_notice_time = maxf(_powerup_notice_time, duration)


func _connect_weapon_system_signals(weapon_system: Node) -> void:
	if weapon_system == null:
		return
	var changed_callable := Callable(self, "_on_weapon_changed")
	if weapon_system.has_signal("weapon_changed") and not weapon_system.is_connected("weapon_changed", changed_callable):
		weapon_system.connect("weapon_changed", changed_callable)
	var pool_callable := Callable(self, "_on_weapon_pool_changed")
	if weapon_system.has_signal("weapon_pool_changed") and not weapon_system.is_connected("weapon_pool_changed", pool_callable):
		weapon_system.connect("weapon_pool_changed", pool_callable)


func _on_weapon_changed(weapon_id: StringName, display_name: String, weapon_data: Dictionary) -> void:
	var weapon_key := String(weapon_id)
	if weapon_key == _last_weapon_notice_id:
		return
	_last_weapon_notice_id = weapon_key
	var mode := String(weapon_data.get("fire_mode", &"projectile")).to_upper()
	var color: Color = weapon_data.get("color", Color(0.34, 1.0, 0.86, 1.0))
	show_mod_notice("%s ONLINE: %s" % [mode, display_name.to_upper()], color, 1.05)


func _on_weapon_pool_changed(unlocked_count: int, total_count: int, newly_unlocked: Array[String]) -> void:
	_last_weapon_pool_count = unlocked_count
	if newly_unlocked.is_empty():
		return
	var first_name := newly_unlocked[0].to_upper()
	var text := "NEW WEAPON: %s" % first_name
	if newly_unlocked.size() > 1:
		text = "WEAPONS UNLOCKED: %s +%d" % [first_name, newly_unlocked.size() - 1]
	if total_count > unlocked_count:
		text += "  %d/%d" % [unlocked_count, total_count]
	else:
		text += "  FULL ARSENAL"
	show_mod_notice(text, Color(0.46, 1.0, 0.82, 1.0), 2.15)


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
	_hazard_seen_ids.clear()

	for group_name in [&"arena_hazard", &"arena_destabilization_hazard"]:
		_fill_group_nodes(group_name, _group_query_buffer)
		for node in _group_query_buffer:
			if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			var id := node.get_instance_id()
			if _hazard_seen_ids.has(id):
				continue
			_hazard_seen_ids[id] = true
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

func _update_nav_arrows(delta: float) -> void:
	_refresh_planet_arrow_sources(delta)
	var viewport_size: Vector2 = _safe_viewport_size()
	var center: Vector2 = viewport_size * 0.5
	var canvas_transform: Transform2D = _safe_canvas_transform()
	var arrow_index: int = 0
	
	for planet in _planet_arrow_sources:
		if arrow_index >= _arrows.size():
			break
		if planet == null or not is_instance_valid(planet):
			continue
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


func _refresh_planet_arrow_sources(delta: float) -> void:
	_planet_arrow_refresh_elapsed += delta
	if _planet_arrow_refresh_elapsed < maxf(navigation_target_refresh_interval, 0.08):
		return
	_planet_arrow_refresh_elapsed = 0.0
	_fill_group_nodes(&"planets", _planet_arrow_sources)


func _update_threat_arrows(delta: float) -> void:
	_threat_refresh_elapsed += delta
	if _threat_refresh_elapsed >= maxf(threat_arrow_refresh_interval, 0.05):
		_threat_refresh_elapsed = 0.0
		_refresh_threat_arrow_targets()

	_update_target_arrows(_boss_arrows, _boss_targets, Color(1.0, 0.16, 0.1, 0.96), true)
	_update_target_arrows(_threat_arrows, _threat_targets, Color(1.0, 0.72, 0.22, 0.88), false)
	_update_target_arrows(_rare_arrows, _rare_targets, Color(0.74, 0.5, 1.0, 0.9), false, 1.04)


func _refresh_threat_arrow_targets() -> void:
	_boss_targets = _collect_offscreen_targets(&"bosses", max_boss_arrow_count, false)
	_threat_targets = _collect_offscreen_targets(&"enemies", max_threat_arrow_count, true)
	_rare_targets = _collect_offscreen_targets_from_groups([
		&"spacetime_tear",
		&"arena_hazard",
		&"gravity_tide_pocket",
	], max_rare_arrow_count)


func _collect_offscreen_targets(group_name: StringName, limit: int, skip_bosses: bool) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if limit <= 0 or _player == null:
		return targets

	var viewport_size: Vector2 = _safe_viewport_size()
	var canvas_transform: Transform2D = _safe_canvas_transform()

	_fill_group_nodes(group_name, _group_query_buffer)
	for node in _group_query_buffer:
		if node == null or not is_instance_valid(node):
			continue
		var target := node as Node2D
		if target == null or target == _player or target.is_queued_for_deletion():
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


func _collect_offscreen_targets_from_groups(group_names: Array[StringName], limit: int) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if limit <= 0 or _player == null:
		return targets

	var viewport_size: Vector2 = _safe_viewport_size()
	var canvas_transform: Transform2D = _safe_canvas_transform()
	_hazard_seen_ids.clear()

	for group_name in group_names:
		_fill_group_nodes(group_name, _group_query_buffer)
		for node in _group_query_buffer:
			if node == null or not is_instance_valid(node):
				continue
			var target := node as Node2D
			if target == null or target == _player or target.is_queued_for_deletion():
				continue
			var id := target.get_instance_id()
			if _hazard_seen_ids.has(id):
				continue
			_hazard_seen_ids[id] = true
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


func _update_target_arrows(arrows: Array[Polygon2D], targets: Array[Node2D], base_color: Color, is_boss_arrow: bool, base_scale: float = 1.0) -> void:
	var viewport_size: Vector2 = _safe_viewport_size()
	var center: Vector2 = viewport_size * 0.5
	var canvas_transform: Transform2D = _safe_canvas_transform()
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
		arrow.scale = Vector2.ONE * (1.35 if is_boss_arrow else 0.82) * pulse * base_scale
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


func _fill_group_nodes(group_name: StringName, out_nodes: Array[Node2D], limit: int = -1) -> void:
	out_nodes.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(group_name, out_nodes, limit)
		return
	for value in get_tree().get_nodes_in_group(group_name):
		if limit >= 0 and out_nodes.size() >= limit:
			return
		var node := value as Node2D
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			out_nodes.append(node)


func _arc_points(radius: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(steps, 2)):
		var t := float(i) / float(maxi(steps - 1, 1))
		var angle := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _on_accessibility_changed(_settings: Dictionary) -> void:
	for glyph in _hud_glyphs:
		if glyph != null and is_instance_valid(glyph) and glyph.has_method("refresh_readability"):
			glyph.call("refresh_readability")
	_apply_accessibility_settings(true)


func _apply_accessibility_settings(force: bool = false) -> void:
	if _hud_root == null or Settings == null:
		return
	var scale_value := clampf(float(Settings.ui_scale), 0.75, 1.35)
	if not force and is_equal_approx(scale_value, _last_ui_scale):
		return
	_last_ui_scale = scale_value
	_hud_root.scale = Vector2.ONE * scale_value
	_layout_hud(true)


func _layout_hud(force: bool = false) -> void:
	if _hud_root == null:
		return
	var scale_value := maxf(_last_ui_scale, 0.75)
	var viewport_size := _safe_viewport_size() / scale_value
	if not force and viewport_size.is_equal_approx(_last_layout_viewport_size):
		return
	_last_layout_viewport_size = viewport_size
	var margin := maxf(hud_safe_margin, 10.0)
	var compact_width := viewport_size.x < 960.0
	var compact_height := viewport_size.y < 660.0
	var resource_width := clampf(viewport_size.x * (0.44 if compact_width else 0.29), 286.0, 382.0)
	var resource_height := 144.0 if compact_height else 148.0

	if _resource_panel != null:
		_resource_panel.custom_minimum_size = Vector2(resource_width, resource_height)
		_set_top_left_rect(_resource_panel, margin, margin, resource_width, resource_height)
		_resize_resource_bars(maxf(resource_width - 40.0, 220.0))

	if _readout_panel != null:
		var readout_top := margin + resource_height + left_panel_gap
		var readout_width := minf(resource_width, 318.0)
		var readout_height := 344.0
		if compact_height:
			readout_height = clampf(viewport_size.y - readout_top - 150.0, 168.0, 260.0)
		else:
			readout_height = minf(readout_height, maxf(viewport_size.y - readout_top - margin, 220.0))
		_readout_panel.custom_minimum_size = Vector2(readout_width, readout_height)
		_set_top_left_rect(_readout_panel, margin, readout_top, readout_width, readout_height)
		_resize_readout_bars(maxf(readout_width - 42.0, 190.0))
		_set_readout_compact(compact_height or compact_width)

	if _score_panel != null:
		var score_width := clampf(viewport_size.x * (0.45 if compact_width else 0.28), 300.0, 364.0)
		var score_height := 126.0
		if compact_width:
			_set_center_bottom_rect(_score_panel, minf(viewport_size.x - margin * 2.0, 364.0), 18.0, score_height)
		else:
			_set_top_right_rect(_score_panel, margin, margin + (142.0 if compact_width else 2.0), score_width, score_height)

	if _powerup_notice_label != null:
		var notice_width := minf(520.0, viewport_size.x - margin * 2.0)
		if compact_width:
			_set_center_bottom_rect(_powerup_notice_label, notice_width, 156.0, 38.0)
		else:
			_set_center_top_rect(_powerup_notice_label, notice_width, 72.0, 38.0)


func _set_readout_compact(compact: bool) -> void:
	var font_size := 10 if compact else 12
	for label in [_speed_label, _g_label, _field_label, _time_label, _horizon_label, _chaos_label, _slingshot_label, _combo_label, _weapon_label]:
		if label != null:
			label.add_theme_font_size_override("font_size", font_size)
	for label in [_time_label, _horizon_label]:
		if label != null:
			_set_label_row_visible(label, not compact)
	if _chaos_label != null:
		_set_label_row_visible(_chaos_label, not compact)


func _set_label_row_visible(label: Label, visible: bool) -> void:
	if label == null:
		return
	var row_value: Variant = _glyph_rows.get(label.get_instance_id(), null)
	var row := row_value as Control
	if row != null:
		row.visible = visible
	else:
		label.visible = visible


func _resize_readout_bars(width: float) -> void:
	for bar in [_speed_bar, _g_bar, _slingshot_bar, _weapon_bar]:
		if bar != null:
			bar.custom_minimum_size.x = width


func _resize_resource_bars(width: float) -> void:
	for bar in [_health_resource_bar, _shield_resource_bar, _energy_resource_bar]:
		if bar != null:
			bar.custom_minimum_size.x = width


func _set_top_left_rect(control: Control, left: float, top: float, width: float, height: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = left + width
	control.offset_bottom = top + height


func _set_top_right_rect(control: Control, right: float, top: float, width: float, height: float) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = -right - width
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = top + height


func _set_center_top_rect(control: Control, width: float, top: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.0
	control.anchor_right = 0.5
	control.anchor_bottom = 0.0
	control.offset_left = -width * 0.5
	control.offset_top = top
	control.offset_right = width * 0.5
	control.offset_bottom = top + height


func _set_center_bottom_rect(control: Control, width: float, bottom: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 1.0
	control.anchor_right = 0.5
	control.anchor_bottom = 1.0
	control.offset_left = -width * 0.5
	control.offset_top = -bottom - height
	control.offset_right = width * 0.5
	control.offset_bottom = -bottom


func _readability_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color
