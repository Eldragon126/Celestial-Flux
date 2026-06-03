extends CanvasLayer
class_name RunTransitionDirector
## Scene-authored transition polish for waves, bosses, arena laws, and collapse events.

@export var enabled: bool = true
@export var message_hold_time: float = 1.15
@export var wash_alpha: float = 0.28
@export var line_alpha: float = 0.82

@onready var _root: Control = $Root
@onready var _wash: ColorRect = $Root/Wash
@onready var _line: ColorRect = $Root/VectorLine
@onready var _label: Label = $Root/TransitionLabel

var _tween: Tween = null


func _ready() -> void:
	add_to_group("run_transition_director")
	layer = 94
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_wash, "color:a", wash_alpha, 0.12)
	_tween.tween_property(_line, "color:a", line_alpha, 0.12)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.12)
	_tween.set_parallel(false)
	_tween.tween_interval(message_hold_time)
	_tween.set_parallel(true)
	_tween.tween_property(_wash, "color:a", 0.0, 0.32)
	_tween.tween_property(_line, "color:a", 0.0, 0.28)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.28)
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
