extends CanvasLayer

@export var max_arrow_count: int = 8
@export var arrow_margin: float = 42.0
@export var g_warning_level: float = 850.0
@export var nearest_field_notice_radius: float = 760.0

var _player: Node2D
var _resonance_manager: Node
var _time_dilation_manager: Node
var _hud_root: Control
var _speed_label: Label
var _speed_bar: ProgressBar
var _g_label: Label
var _g_bar: ProgressBar
var _field_label: Label
var _time_label: Label
var _critical_vignette: ColorRect
var _vignette_material: ShaderMaterial
var _arrows: Array[Polygon2D] = []

# Cache the current intensity to avoid repeated get_shader_parameter calls
var _current_vignette_intensity: float = 0.0

func _ready() -> void:
	layer = 40
	_build_hud()
	_player = get_tree().get_first_node_in_group("Player") as Node2D


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		return
	
	_update_speedometer()
	var gravity_strength: float = _update_gravity_meter()
	_resolve_rule_systems()
	_update_field_lens()
	_update_time_lens()
	_update_health_vignette(delta)
	_update_nav_arrows(gravity_strength)


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
	_build_nav_arrows()


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
	panel.custom_minimum_size = Vector2(292.0, 154.0)
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


func _build_nav_arrows() -> void:
	var arrow_layer = Node2D.new()
	_hud_root.add_child(arrow_layer)
	
	for i in range(max_arrow_count):
		var arrow = Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(0, -18),
			Vector2(13, 12),
			Vector2(0, 6),
			Vector2(-13, 12),
		])
		arrow.color = Color(0.1, 0.95, 0.9, 0.86)
		arrow.visible = false
		arrow_layer.add_child(arrow)
		_arrows.append(arrow)


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
	_g_label.modulate = Color(1, 0.16, 0.1) if strength >= g_warning_level * 0.72 else Color(0.78, 1, 0.96)
	
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

	if _time_dilation_manager == null or not is_instance_valid(_time_dilation_manager):
		_time_dilation_manager = root.find_child("TimeDilationManager", true, false)

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
		_time_label.modulate = Color(0.48, 0.78, 0.84, 1.0)
		return

	var capacity := float(_time_dilation_manager.get("current_dilation_capacity") or 0.0)
	var maximum := maxf(float(_time_dilation_manager.get("initial_dilation_capacity") or 1.0), 1.0)
	var dilating := bool(_time_dilation_manager.get("is_dilating")) if typeof(_time_dilation_manager.get("is_dilating")) == TYPE_BOOL else false
	var scale := float(_time_dilation_manager.get("current_time_scale") or Engine.time_scale)
	var state := "DILATING" if dilating else "READY"

	_time_label.text = "TIME %s  x%.2f %d%%" % [state, scale, int(round(capacity / maximum * 100.0))]
	_time_label.modulate = Color(0.72, 0.38, 1.0, 1.0) if dilating else Color(0.72, 1.0, 0.96, 1.0)

func _set_field_text(text: String, color: Color) -> void:
	_field_label.text = text
	_field_label.modulate = Color(color.r, color.g, color.b, 1.0)

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


func _project_to_screen_edge(center: Vector2, direction: Vector2, viewport_size: Vector2) -> Vector2:
	var safe_half: Vector2 = viewport_size * 0.5 - Vector2.ONE * arrow_margin
	var scale_x: float = safe_half.x / maxf(absf(direction.x), 0.001)
	var scale_y: float = safe_half.y / maxf(absf(direction.y), 0.001)
	return center + direction * minf(scale_x, scale_y)
