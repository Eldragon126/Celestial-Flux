extends Control

const RUN_SCENE_PATH := "res://Nodes/the_abyss.tscn"
const TITLE_SCENE_PATH := "res://Nodes/title_screen.tscn"

const LOADING_TIPS: Array[String] = [
	"Keep your orbit shallow until the field tells you where it wants to throw you.",
	"Gravity sources are readable when the screen is allowed to breathe.",
	"Late waves are about clean exits as much as clean shots.",
	"Momentum is strongest when you spend it on purpose.",
]

const SHADER_CODE := """
shader_type canvas_item;

// Subdued for less "buzz" and more flow
uniform int lineas = 35; 
uniform float velocidad = 0.5;
uniform float ondulacion = 0.1;
uniform float frecuencia = 1.5;

uniform vec4 color_a : source_color = vec4(0.01, 0.04, 0.12, 1.0);  // Deep space
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.015, 1.0);   // Total void
uniform vec4 color_neon : source_color = vec4(0.0, 0.85, 1.0, 1.0); // Neon Cyan
uniform vec4 color_charged : source_color = vec4(0.8, 0.2, 1.0, 1.0); // Charged Magenta

uniform float gravity_strength = 0.0;
uniform vec2 gravity_center = vec2(0.5, 0.5); 
uniform float real_time; 

void fragment() {
	vec2 uv = UV;
	
	// Approximate 16:9 aspect ratio correction
	vec2 aspect = vec2(1.777, 1.0);
	vec2 center_uv = (uv - gravity_center) * aspect + gravity_center;
	
	float dist_to_center = distance(center_uv, gravity_center);
	vec2 pull_dir = normalize(gravity_center - center_uv);
	
	// --- THE PULSE ---
	// Heartbeat speeds up as the level finishes loading
	float pulse_rate = 2.0 + (gravity_strength * 6.0); 
	float pulse = sin(real_time * pulse_rate - dist_to_center * 4.0) * 0.5 + 0.5;
	
	// Smooth, throbbing pull
	float pull_strength = pow(1.0 - clamp(dist_to_center, 0.0, 1.0), 2.5) * (gravity_strength * 1.2) * (0.85 + 0.15 * pulse);
	vec2 warped_uv = uv + pull_dir * pull_strength;

	// Fluid Wave Grid Simulation (Smoother, no harsh lines)
	float wave_primary = sin(warped_uv.y * frecuencia + real_time * velocidad);
	float wave_secondary = cos(warped_uv.x * (frecuencia * 0.5) - real_time * (velocidad * 0.5));
	float desfaso_fluido = (wave_primary * 0.8 + wave_secondary * 0.2) * ondulacion;
	
	warped_uv.x += (real_time * velocidad * 0.1) + desfaso_fluido;
	
	// Soft bands instead of sharp steps to kill the "buzz"
	float patron = smoothstep(0.3, 0.7, sin(warped_uv.x * float(lineas)));
	
	// Dynamic Color Shifting
	vec4 active_neon = mix(color_neon, color_charged, gravity_strength * 1.2);
	vec3 color_final = mix(color_a.rgb, color_b.rgb, patron);
	
	// Pulsating grid glow
	float edge_glow = smoothstep(0.6, 1.0, sin(warped_uv.y * float(lineas)));
	float neon_blend = edge_glow * (0.3 + 0.7 * pulse) * smoothstep(1.0, 0.05, dist_to_center);
	color_final = mix(color_final, active_neon.rgb, neon_blend);
	
	// Center singularity (Physically throbs with the pulse)
	float eh_size = 0.03 + (gravity_strength * 0.06) + (pulse * 0.015 * gravity_strength);
	float singularity = smoothstep(eh_size, eh_size + 0.08, dist_to_center);
	color_final *= singularity;

	// Deep cinematic vignette
	color_final *= smoothstep(1.3, 0.35, distance(uv, vec2(0.5)));

	COLOR = vec4(color_final, 1.0);
}
"""

@export var minimum_display_time: float = 0.9
@export var fail_return_delay: float = 1.4
@export var displayed_progress_speed: float = 1.85
@export var loaded_settle_time: float = 0.18
@export var loaded_hold_progress: float = 0.985

var _elapsed: float = 0.0
var _failed_elapsed: float = 0.0
var _load_requested: bool = false
var _transitioning: bool = false
var _progress: Array = []
var _target_progress: float = 0.0
var _displayed_progress: float = 0.0
var _loaded_elapsed: float = 0.0
var _completion_display_elapsed: float = 0.0
var _status_label: Label = null
var _percent_label: Label = null
var _bar: ProgressBar = null
var _tip_label: Label = null
var _shader_material: ShaderMaterial = null
var _rings_root: Node2D = null
var _orbit_rings: Array[Line2D] = []
var _vector_ticks: Array[Line2D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	get_tree().paused = false
	_build_interface()
	_request_run_scene()

func _process(delta: float) -> void:
	_elapsed += delta
	
	if not _load_requested or _transitioning:
		return

	_progress.clear()
	var status := ResourceLoader.load_threaded_get_status(RUN_SCENE_PATH, _progress)
	var raw_ratio := _load_progress_ratio(status)
	_target_progress = _progress_target(raw_ratio, status)
	_displayed_progress = _approach_displayed_progress(delta, _target_progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loaded_elapsed += delta
		if _displayed_progress >= loaded_hold_progress:
			_displayed_progress = 1.0
			_completion_display_elapsed += delta
		else:
			_completion_display_elapsed = 0.0
	else:
		_loaded_elapsed = 0.0
		_completion_display_elapsed = 0.0

	_update_progress(_displayed_progress, status)
	
	if _shader_material != null:
		_shader_material.set_shader_parameter("real_time", _elapsed)
		var target_gravity = lerpf(0.0, 0.85, _displayed_progress)
		_shader_material.set_shader_parameter("gravity_strength", target_gravity)
	_update_orbit_glyphs(delta, _displayed_progress)

	if (
		status == ResourceLoader.THREAD_LOAD_LOADED
		and _elapsed >= minimum_display_time
		and _loaded_elapsed >= loaded_settle_time
		and _completion_display_elapsed >= loaded_settle_time
	):
		_enter_run_scene()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_failed_elapsed += delta
		if _status_label != null:
			_status_label.text = "CRITICAL FAILURE - ORBIT DECAYED"
			_status_label.modulate = Color(1.0, 0.15, 0.05, 1.0)
		if _failed_elapsed >= fail_return_delay:
			get_tree().change_scene_to_file(TITLE_SCENE_PATH)

func _request_run_scene() -> void:
	if _load_requested:
		return
	_load_requested = true
	var status := ResourceLoader.load_threaded_get_status(RUN_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(RUN_SCENE_PATH)

func _enter_run_scene() -> void:
	if _transitioning:
		return
	_transitioning = true
	var packed := ResourceLoader.load_threaded_get(RUN_SCENE_PATH) as PackedScene
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(RUN_SCENE_PATH)

func _load_progress_ratio(status: int) -> float:
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if not _progress.is_empty():
		return clampf(float(_progress[0]), 0.0, 1.0)
	return 0.08


func _progress_target(raw_ratio: float, status: int) -> float:
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return clampf(maxf(raw_ratio, 0.08), 0.08, 0.94)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return _displayed_progress
	return clampf(maxf(raw_ratio, 0.04), 0.04, 0.72)


func _approach_displayed_progress(delta: float, target: float) -> float:
	var clamped_target := clampf(maxf(target, _displayed_progress), 0.0, 1.0)
	var remaining := clamped_target - _displayed_progress
	if remaining <= 0.0001:
		return clamped_target
	var adaptive_step := remaining * displayed_progress_speed * delta
	var minimum_step := delta * 0.055
	return move_toward(_displayed_progress, clamped_target, maxf(adaptive_step, minimum_step))


func _update_progress(ratio: float, status: int) -> void:
	var safe_ratio := clampf(ratio, 0.0, 1.0)
	if _bar != null:
		_bar.value = safe_ratio * 100.0
	if _percent_label != null:
		_percent_label.text = "%d%%" % int(round(safe_ratio * 100.0))
	if _status_label == null:
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_status_label.text = "CRITICAL FAILURE - ORBIT DECAYED"
	elif safe_ratio >= 0.985:
		_status_label.text = "ANOMALY STABILIZED"
	elif safe_ratio >= 0.76:
		_status_label.text = "LOCKING GRAVITY SOURCES"
	elif safe_ratio >= 0.48:
		_status_label.text = "RESOLVING FIELD CACHE"
	elif safe_ratio >= 0.22:
		_status_label.text = "INDEXING VECTOR LAWS"
	else:
		_status_label.text = "CALCULATING TRAJECTORY"

func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.01, 1.0)
	add_child(backdrop)

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("gravity_strength", 0.0) 
	
	var shader_layer := ColorRect.new()
	shader_layer.name = "ShaderLayer"
	shader_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_layer.material = _shader_material
	add_child(shader_layer)

	_build_orbit_glyphs()

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.anchor_left = 0.5
	rows.anchor_right = 0.5
	rows.anchor_top = 0.5
	rows.anchor_bottom = 0.5
	rows.offset_left = -420.0
	rows.offset_right = 420.0
	rows.offset_top = -136.0
	rows.offset_bottom = 136.0
	rows.add_theme_constant_override("separation", 14)
	add_child(rows)

	var title := Label.new()
	title.name = "Title"
	title.text = "VECTOR ANOMALY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.9, 0.95, 1.0, 1.0) 
	_apply_text_shadow(title)
	rows.add_child(title)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "CALCULATING TRAJECTORY"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.modulate = Color(0.6, 0.85, 1.0, 0.9)
	_apply_text_shadow(_status_label)
	rows.add_child(_status_label)

	_bar = ProgressBar.new()
	_bar.name = "Progress"
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.custom_minimum_size = Vector2(760.0, 6.0) 
	_bar.show_percentage = false 
	_bar.add_theme_stylebox_override("background", _progress_bg_style())
	_bar.add_theme_stylebox_override("fill", _progress_fill_style())
	
	var bar_margin = MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_top", 10)
	bar_margin.add_theme_constant_override("margin_bottom", 10)
	bar_margin.add_child(_bar)
	rows.add_child(bar_margin)

	_percent_label = Label.new()
	_percent_label.name = "PercentLabel"
	_percent_label.text = "0%"
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent_label.add_theme_font_size_override("font_size", 16)
	_percent_label.modulate = Color(0.9, 0.95, 1.0, 0.9)
	_apply_text_shadow(_percent_label)
	rows.add_child(_percent_label)

	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.text = _choose_tip()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(760.0, 48.0)
	_tip_label.add_theme_font_size_override("font_size", 15)
	_tip_label.modulate = Color(0.6, 0.75, 0.9, 0.8)
	_apply_text_shadow(_tip_label)
	rows.add_child(_tip_label)

func _apply_text_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)

func _choose_tip() -> String:
	var seed_val := Time.get_ticks_msec()
	if Engine.has_singleton("RunProgress"):
		var rp = Engine.get_singleton("RunProgress")
		if "run_seed" in rp:
			seed_val = int(rp.run_seed)
			
	var index := absi(seed_val) % LOADING_TIPS.size()
	return "TIP: %s" % LOADING_TIPS[index]

func _progress_bg_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.set_corner_radius_all(3)
	return style

func _progress_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.85, 1.0, 0.9)
	style.set_corner_radius_all(3)
	style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style.border_width_right = 2
	style.border_blend = true
	return style


func _build_orbit_glyphs() -> void:
	_rings_root = Node2D.new()
	_rings_root.name = "OrbitGlyphs"
	add_child(_rings_root)
	for i in range(3):
		var ring := Line2D.new()
		ring.name = "LoadingOrbitRing%d" % i
		ring.closed = true
		ring.antialiased = true
		ring.width = 1.6 + float(i) * 0.45
		ring.default_color = Color(0.0, 0.86, 1.0, 0.16 + float(i) * 0.045)
		_rings_root.add_child(ring)
		_orbit_rings.append(ring)
	for i in range(8):
		var tick := Line2D.new()
		tick.name = "LoadingVectorTick%d" % i
		tick.antialiased = true
		tick.width = 2.0
		tick.default_color = Color(0.82, 0.32, 1.0, 0.28)
		_rings_root.add_child(tick)
		_vector_ticks.append(tick)


func _update_orbit_glyphs(delta: float, ratio: float) -> void:
	if _rings_root == null:
		return
	var viewport_size := get_viewport_rect().size
	_rings_root.position = viewport_size * 0.5
	_rings_root.rotation += delta * lerpf(0.12, 0.42, ratio)
	var base_radius := minf(viewport_size.x, viewport_size.y) * 0.33
	for i in range(_orbit_rings.size()):
		var ring := _orbit_rings[i]
		if ring == null:
			continue
		var ring_radius := base_radius * (0.72 + float(i) * 0.19)
		ring.points = _loading_ring_points(ring_radius, 96, float(i) * 0.7 + ratio)
		ring.width = lerpf(1.4, 3.1, ratio) + float(i) * 0.25
		ring.default_color = Color(
			lerpf(0.0, 0.74, float(i) / 3.0),
			lerpf(0.86, 0.34, float(i) / 3.0),
			1.0,
			lerpf(0.12, 0.34, ratio) * (1.0 - float(i) * 0.14)
		)
	for i in range(_vector_ticks.size()):
		var tick := _vector_ticks[i]
		if tick == null:
			continue
		var angle := TAU * float(i) / float(maxi(_vector_ticks.size(), 1)) + _elapsed * 0.18
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := radial.orthogonal()
		var inner := base_radius * lerpf(0.36, 0.62, ratio)
		var outer := base_radius * lerpf(0.48, 0.78, ratio)
		tick.points = PackedVector2Array([
			radial * inner - tangent * 10.0,
			radial * outer + tangent * 18.0,
		])
		tick.default_color = Color(0.82, 0.32, 1.0, lerpf(0.16, 0.38, ratio))


func _loading_ring_points(radius: float, count: int, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 12)):
		var angle := TAU * float(i) / float(maxi(count, 12))
		var wobble := sin(angle * 5.0 + _elapsed * 1.8 + phase * 2.0) * radius * 0.018
		points.append(Vector2(cos(angle), sin(angle)) * (radius + wobble))
	return points
