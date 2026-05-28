extends CanvasLayer
class_name RunStoryArcDirector
## Names the run's cinematic arc without owning wave, boss, or physics logic.

signal run_arc_changed(arc_id: StringName, display_name: String, arc_data: Dictionary)

@export var enabled: bool = true
@export var update_interval: float = 0.3
@export var distortion_wave: int = 5
@export var contamination_wave: int = 12
@export var collapse_wave: int = 22
@export var event_horizon_wave: int = 31
@export var banner_hold_time: float = 1.65

@onready var _root: Control = get_node_or_null("Root") as Control
@onready var _wash: ColorRect = get_node_or_null("Root/Wash") as ColorRect
@onready var _line: ColorRect = get_node_or_null("Root/VectorLine") as ColorRect
@onready var _label: Label = get_node_or_null("Root/ArcLabel") as Label
@onready var _sub_label: Label = get_node_or_null("Root/ArcSubLabel") as Label

var _wave_director: Node = null
var _arc_id: StringName = &"calibration"
var _elapsed: float = 999.0
var _tween: Tween = null


func _ready() -> void:
	add_to_group("run_story_arc_director")
	layer = 93
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_visuals()
	call_deferred("_connect_sources")
	set_process(true)


func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	_update_arc_state(false)


func get_run_arc_state() -> Dictionary:
	var data := _arc_data(_arc_id)
	data["arc_id"] = _arc_id
	data["wave"] = _current_wave()
	return data


func _connect_sources() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_wave_director = root.find_child("WaveDirector", true, false)
	_connect_once(_wave_director, &"regular_wave", Callable(self, "_on_wave_signal"))
	_connect_once(_wave_director, &"boss_wave", Callable(self, "_on_wave_signal"))
	_connect_once(_wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	if RunProgress != null:
		var phase_cb := Callable(self, "_on_run_phase_changed")
		if not RunProgress.phase_changed.is_connected(phase_cb):
			RunProgress.phase_changed.connect(phase_cb)
	_update_arc_state(true)


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_wave_signal() -> void:
	_update_arc_state(false)


func _on_wave_cleared(_wave: int) -> void:
	_update_arc_state(false)


func _on_run_phase_changed(_old_phase: int, _new_phase: int) -> void:
	_update_arc_state(false)


func _update_arc_state(force: bool) -> void:
	var next_arc := _arc_for_current_state()
	if not force and next_arc == _arc_id:
		return
	_arc_id = next_arc
	var data := _arc_data(_arc_id)
	data["arc_id"] = _arc_id
	data["wave"] = _current_wave()
	run_arc_changed.emit(_arc_id, String(data.get("display_name", "Calibration")), data.duplicate(true))
	_show_arc_banner(data)


func _arc_for_current_state() -> StringName:
	if RunProgress != null and not RunProgress.challenge_mode:
		if RunProgress.phase == RunProgress.Phase.RUPTURE:
			return &"rupture"
		if RunProgress.phase == RunProgress.Phase.MUSIC_FINALE:
			return &"rupture"
		if RunProgress.phase == RunProgress.Phase.CREDITS:
			return &"rupture"

	var wave := _current_wave()
	if wave >= event_horizon_wave:
		return &"event_horizon"
	if wave >= collapse_wave:
		return &"collapse"
	if wave >= contamination_wave:
		return &"contamination"
	if wave >= distortion_wave:
		return &"distortion"
	return &"calibration"


func _arc_data(arc: StringName) -> Dictionary:
	match arc:
		&"distortion":
			return {
				"display_name": "Distortion",
				"rule": "LAW STRESS RISING",
				"color": Color(0.42, 0.9, 1.0, 1.0),
				"pressure": 0.28,
			}
		&"contamination":
			return {
				"display_name": "Contamination",
				"rule": "FIELDS BEGIN TO OVERLAP",
				"color": Color(0.68, 1.0, 0.62, 1.0),
				"pressure": 0.48,
			}
		&"collapse":
			return {
				"display_name": "Collapse",
				"rule": "STABLE ORBITS NO LONGER GUARANTEED",
				"color": Color(1.0, 0.82, 0.28, 1.0),
				"pressure": 0.68,
			}
		&"event_horizon":
			return {
				"display_name": "Event Horizon",
				"rule": "ESCAPE REQUIRES MOMENTUM MASTERY",
				"color": Color(1.0, 0.34, 0.16, 1.0),
				"pressure": 0.86,
			}
		&"rupture":
			return {
				"display_name": "Rupture",
				"rule": "WAVE GENERATOR OFFLINE",
				"color": Color(0.9, 0.36, 1.0, 1.0),
				"pressure": 1.0,
			}
	return {
		"display_name": "Calibration",
		"rule": "VECTOR FIELD ONLINE",
		"color": Color(0.48, 0.78, 0.84, 1.0),
		"pressure": 0.08,
	}


func _show_arc_banner(data: Dictionary) -> void:
	if _root == null or _label == null or _sub_label == null or _wash == null or _line == null:
		return
	var color: Color = data.get("color", Color(0.48, 0.78, 0.84, 1.0))
	var display_name := String(data.get("display_name", "Calibration")).to_upper()
	var rule := String(data.get("rule", "VECTOR FIELD ONLINE"))
	_label.text = "RUN ARC: %s" % display_name
	_sub_label.text = rule
	_label.modulate = Color(color.r, color.g, color.b, 0.0)
	_sub_label.modulate = Color(color.r, color.g, color.b, 0.0)
	_wash.color = Color(color.r, color.g, color.b, 0.0)
	_line.color = Color(color.r, color.g, color.b, 0.0)
	_root.visible = true

	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_wash, "color:a", 0.12, 0.16)
	_tween.tween_property(_line, "color:a", 0.9, 0.16)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_sub_label, "modulate:a", 0.84, 0.16)
	_tween.set_parallel(false)
	_tween.tween_interval(banner_hold_time)
	_tween.set_parallel(true)
	_tween.tween_property(_wash, "color:a", 0.0, 0.34)
	_tween.tween_property(_line, "color:a", 0.0, 0.28)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.28)
	_tween.tween_property(_sub_label, "modulate:a", 0.0, 0.28)
	_tween.finished.connect(_reset_visuals)


func _reset_visuals() -> void:
	if _root != null:
		_root.visible = false
	if _wash != null:
		_wash.color.a = 0.0
	if _line != null:
		_line.color.a = 0.0
	if _label != null:
		_label.modulate.a = 0.0
	if _sub_label != null:
		_sub_label.modulate.a = 0.0


func _current_wave() -> int:
	if RunProgress != null and RunProgress.wave_index > 0:
		return RunProgress.wave_index
	if _wave_director != null and is_instance_valid(_wave_director):
		if _wave_director.has_method("get_current_wave"):
			return int(_wave_director.call("get_current_wave"))
		var wave_value: Variant = _wave_director.get("_wave")
		if typeof(wave_value) == TYPE_INT or typeof(wave_value) == TYPE_FLOAT:
			return int(wave_value)
	return 1
