extends CanvasLayer
class_name RunTransitionDirector
## Scene-authored transition polish for waves, bosses, arena laws, and collapse events.

@export var enabled: bool = true
@export var message_hold_time: float = 1.15
@export var wash_alpha: float = 0.28
@export var line_alpha: float = 0.82
@export var glitch_slice_count: int = 5
@export var glitch_slice_alpha: float = 0.22
@export var glitch_slice_height: float = 6.0

@onready var _root: Control = $Root
@onready var _wash: ColorRect = $Root/Wash
@onready var _line: ColorRect = $Root/VectorLine
@onready var _label: Label = $Root/TransitionLabel

var _tween: Tween = null
var _glitch_slices: Array[ColorRect] = []


func _ready() -> void:
	add_to_group("run_transition_director")
	layer = 94
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_glitch_slices()
	_reset_visuals()
	call_deferred("_connect_sources")


func play_transition(message: String, color: Color) -> void:
	if not enabled:
		return
	_label.text = message
	_label.modulate = Color(color.r, color.g, color.b, 0.0)
	_wash.color = Color(color.r, color.g, color.b, 0.0)
	_line.color = Color(color.r, color.g, color.b, 0.0)
	_root.visible = true
	var with_glitch := _transition_should_glitch(message)
	_configure_glitch_slices(color, with_glitch)

	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_wash, "color:a", wash_alpha, 0.12)
	_tween.tween_property(_line, "color:a", line_alpha, 0.12)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.12)
	for slice in _glitch_slices:
		if slice.visible:
			_tween.tween_property(slice, "color:a", _safe_transition_alpha(glitch_slice_alpha), 0.1)
	_tween.set_parallel(false)
	_tween.tween_interval(message_hold_time)
	_tween.set_parallel(true)
	_tween.tween_property(_wash, "color:a", 0.0, 0.32)
	_tween.tween_property(_line, "color:a", 0.0, 0.28)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.28)
	for slice in _glitch_slices:
		if slice.visible:
			_tween.tween_property(slice, "color:a", 0.0, 0.22)
	_tween.finished.connect(_reset_visuals)


func _connect_sources() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_connect_once(root.find_child("WaveDirector", true, false), &"regular_wave", Callable(self, "_on_regular_wave"))
	_connect_once(root.find_child("WaveDirector", true, false), &"boss_wave", Callable(self, "_on_boss_wave"))
	_connect_once(root.find_child("WaveDirector", true, false), &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_once(root.find_child("ArenaRuleDirector", true, false), &"arena_profile_applied", Callable(self, "_on_arena_profile_applied"))
	_connect_once(root.find_child("LateGameInstabilityDirector", true, false), &"impossible_event_started", Callable(self, "_on_impossible_event_started"))
	_connect_once(root.find_child("ArenaInstabilityDirector", true, false), &"arena_instability_event_telegraphed", Callable(self, "_on_arena_instability_event_telegraphed"))
	_connect_once(root.find_child("RealityCollapseDirector", true, false), &"reality_breach_opened", Callable(self, "_on_reality_breach_opened"))
	_connect_once(root.find_child("RecoveryOpportunityDirector", true, false), &"recovery_opportunity_started", Callable(self, "_on_recovery_opportunity_started"))
	_connect_once(root.find_child("CelestialBodyDirector", true, false), &"celestial_event_started", Callable(self, "_on_celestial_event_started"))
	_connect_once(root.find_child("CoopComboDirector", true, false), &"coop_combo_triggered", Callable(self, "_on_coop_combo_triggered"))

	if RunProgress != null:
		var phase_cb := Callable(self, "_on_phase_changed")
		if not RunProgress.phase_changed.is_connected(phase_cb):
			RunProgress.phase_changed.connect(phase_cb)


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _reset_visuals() -> void:
	if _root != null:
		_root.visible = false
	if _wash != null:
		_wash.color.a = 0.0
	if _line != null:
		_line.color.a = 0.0
	if _label != null:
		_label.modulate.a = 0.0
	for slice in _glitch_slices:
		if slice != null:
			slice.visible = false
			slice.color.a = 0.0


func _build_glitch_slices() -> void:
	if _root == null:
		return
	for i in range(maxi(glitch_slice_count, 0)):
		var slice := ColorRect.new()
		slice.name = "LawCrackGlitchSlice%d" % i
		slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slice.color = Color(1.0, 0.28, 0.14, 0.0)
		slice.visible = false
		_root.add_child(slice)
		_glitch_slices.append(slice)


func _configure_glitch_slices(color: Color, enabled_glitch: bool) -> void:
	if not enabled_glitch:
		for slice in _glitch_slices:
			slice.visible = false
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for i in range(_glitch_slices.size()):
		var slice := _glitch_slices[i]
		var width := viewport_size.x * lerpf(0.22, 0.72, float((i * 37) % 100) / 100.0)
		var y := viewport_size.y * lerpf(0.18, 0.78, float((i * 53 + 17) % 100) / 100.0)
		slice.position = Vector2(lerpf(24.0, maxf(viewport_size.x - width - 24.0, 24.0), float((i * 29 + 11) % 100) / 100.0), y)
		slice.size = Vector2(width, glitch_slice_height * lerpf(0.7, 1.5, float((i * 19 + 5) % 100) / 100.0))
		slice.color = Color(color.r, color.g, color.b, 0.0)
		slice.visible = true


func _transition_should_glitch(message: String) -> bool:
	var upper := message.to_upper()
	return upper.contains("LAW") or upper.contains("RUPTURE") or upper.contains("CRACK") or upper.contains("BREACH")


func _safe_transition_alpha(alpha: float) -> float:
	if Settings != null and Settings.has_method("flash_alpha"):
		return Settings.flash_alpha(alpha)
	return minf(alpha, 0.22)


func _on_regular_wave() -> void:
	play_transition("VECTOR FIELD ONLINE", Color(0.42, 1.0, 0.88, 1.0))


func _on_boss_wave() -> void:
	play_transition("PHYSICS MUTATION DETECTED", Color(1.0, 0.24, 0.12, 1.0))


func _on_wave_cleared(wave: int) -> void:
	play_transition("WAVE %d STABILIZED" % wave, Color(0.72, 0.95, 1.0, 1.0))


func _on_arena_profile_applied(_profile_id: StringName, display_name: String, _profile: Dictionary) -> void:
	play_transition("ARENA LAW: %s" % display_name.to_upper(), Color(0.52, 0.95, 1.0, 1.0))


func _on_impossible_event_started(event_id: StringName, _data: Dictionary) -> void:
	play_transition(String(event_id).replace("_", " ").to_upper(), Color(1.0, 0.54, 0.18, 1.0))


func _on_arena_instability_event_telegraphed(event_id: StringName, _data: Dictionary) -> void:
	play_transition(String(event_id).replace("_", " ").to_upper(), Color(0.42, 0.9, 1.0, 1.0))


func _on_reality_breach_opened(breach_id: StringName, _data: Dictionary) -> void:
	play_transition(String(breach_id).replace("_", " ").to_upper(), Color(1.0, 0.32, 0.16, 1.0))


func _on_recovery_opportunity_started(opportunity_id: StringName, _data: Dictionary) -> void:
	play_transition(String(opportunity_id).replace("_", " ").to_upper(), Color(0.36, 1.0, 0.74, 1.0))


func _on_celestial_event_started(event_id: StringName, _data: Dictionary) -> void:
	play_transition(String(event_id).replace("_", " ").to_upper(), Color(1.0, 0.82, 0.26, 1.0))


func _on_coop_combo_triggered(combo_id: StringName, _data: Dictionary) -> void:
	play_transition(String(combo_id).replace("_", " ").to_upper(), Color(0.7, 1.0, 0.5, 1.0))


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	if RunProgress == null:
		return
	if new_phase == RunProgress.Phase.RUPTURE:
		play_transition("LAWS CRACKING", Color(1.0, 0.28, 0.12, 1.0))
	elif new_phase == RunProgress.Phase.MUSIC_FINALE:
		play_transition("MUSIC DEFINES REALITY", Color(0.72, 0.95, 1.0, 1.0))
