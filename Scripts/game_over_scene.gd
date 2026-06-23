extends Control

@export var run_scene_path: String = "res://Nodes/the_abyss.tscn"
@export var run_loading_scene_path: String = "res://Nodes/run_loading_screen.tscn"
@export var title_scene_path: String = "res://Nodes/title_screen.tscn"
@export var death_label_glitch_strength: float = 4.0

@onready var death_vector_label: Label = $CenterPanel/Rows/DeathVectorLabel
@onready var rows: VBoxContainer = $CenterPanel/Rows
@onready var buttons: HBoxContainer = $CenterPanel/Rows/Buttons
@onready var try_again_button: Button = $CenterPanel/Rows/Buttons/TryAgainButton
@onready var title_button: Button = $CenterPanel/Rows/Buttons/TitleButton
@onready var backdrop: ColorRect = $FailureBackdrop

var _death_label_base_position := Vector2.ZERO
var _resolved_retry_scene_path: String = ""
var _resolved_title_scene_path: String = ""
var _challenge_code: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	get_tree().paused = false
	_resolved_retry_scene_path = _run_scene_from_progress()
	_resolved_title_scene_path = _title_scene_from_progress()
	_challenge_code = _challenge_code_from_progress()
	RunProgress.clear_anchor()

	var message := RunProgress.last_death_message
	if message.is_empty():
		message = "DEATH VECTOR: the simulation collapsed before the lesson could stabilize."
	death_vector_label.text = message
	_death_label_base_position = death_vector_label.position
	_build_score_summary()

	try_again_button.pressed.connect(_on_try_again_pressed)
	title_button.pressed.connect(_on_title_pressed)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if backdrop.material is ShaderMaterial:
		backdrop.material.set_shader_parameter("real_time", now)
	_update_death_label_glitch(now)


func _on_try_again_pressed() -> void:
	var next_scene := _resolved_retry_scene_path
	RunProgress.begin_new_run(false)
	if next_scene == "res://Nodes/the_abyss.tscn":
		get_tree().change_scene_to_file(run_loading_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene)


func _on_title_pressed() -> void:
	RunProgress.clear_anchor()
	get_tree().change_scene_to_file(_resolved_title_scene_path)


func _update_death_label_glitch(now: float) -> void:
	if death_vector_label == null:
		return
	var flicker := 0.5 + 0.5 * sin(now * 19.0)
	var sharp := 1.0 if sin(now * 37.0) > 0.86 else 0.0
	var strength := death_label_glitch_strength * sharp
	death_vector_label.position = _death_label_base_position + Vector2(strength, -strength * 0.35)
	death_vector_label.modulate = Color(0.72 + flicker * 0.18, 0.96, 1.0, 1.0)


func _build_score_summary() -> void:
	if rows == null or buttons == null:
		return
	var snapshot := _score_snapshot_from_progress()
	var summary := GridContainer.new()
	summary.name = "RunSummaryGrid"
	summary.columns = 2
	summary.add_theme_constant_override("h_separation", 26)
	summary.add_theme_constant_override("v_separation", 8)
	rows.add_child(summary)
	rows.move_child(summary, buttons.get_index())

	_add_summary_row(summary, "SCORE", str(int(snapshot.get("score", 0))))
	_add_summary_row(summary, "WAVE", str(int(snapshot.get("wave", RunProgress.wave_index if RunProgress != null else 0))))
	_add_summary_row(summary, "MASTERED", _mastery_summary(snapshot))
	_add_summary_row(summary, "BLACK BOX", _gravity_ghost_summary())
	_add_summary_row(summary, "KILLS", str(int(snapshot.get("weapon_kills", 0))))
	_add_summary_row(summary, "BEST CHAIN", "x%d" % int(snapshot.get("best_run_chain", 0)))
	_add_summary_row(summary, "SEED", String(snapshot.get("seed_code", RunProgress.get_run_seed_code() if RunProgress != null else "unknown")))
	_add_summary_row(summary, "CHALLENGE", _challenge_code if not _challenge_code.is_empty() else "stabilizing")

	if not _challenge_code.is_empty():
		var copy_button := Button.new()
		copy_button.text = "COPY CODE"
		copy_button.custom_minimum_size = Vector2(180.0, 52.0)
		copy_button.add_theme_font_size_override("font_size", 18)
		copy_button.pressed.connect(_on_copy_code_pressed)
		buttons.add_child(copy_button)


func _add_summary_row(parent: GridContainer, key: String, value: String) -> void:
	var key_label := Label.new()
	key_label.text = key
	key_label.custom_minimum_size = Vector2(180.0, 24.0)
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.modulate = Color(1.0, 0.55, 0.28, 0.9)
	parent.add_child(key_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.custom_minimum_size = Vector2(680.0, 24.0)
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.clip_text = true
	value_label.modulate = Color(0.78, 0.96, 1.0, 0.94)
	parent.add_child(value_label)


func _mastery_summary(snapshot: Dictionary) -> String:
	var perfect := int(snapshot.get("perfect_slingshots", 0))
	var apex := int(snapshot.get("apex_slingshots", 0))
	var skims := int(snapshot.get("surface_skims", 0))
	var shears := int(snapshot.get("vector_shears", 0))
	return "%d perfect / %d apex / %d skims / %d shears" % [perfect, apex, skims, shears]


func _gravity_ghost_summary() -> String:
	var snapshot := _gravity_ghost_snapshot()
	if snapshot.is_empty():
		return "signal lost"
	var summary := String(snapshot.get("incident_summary", "")).strip_edges()
	if not summary.is_empty():
		return summary
	var highlights_value: Variant = snapshot.get("highlights", [])
	var highlight_count := 0
	if highlights_value is Array:
		highlight_count = (highlights_value as Array).size()
	return "peak %d%% @ %.1fs / %d marks" % [
		int(round(float(snapshot.get("peak_danger", 0.0)) * 100.0)),
		float(snapshot.get("peak_danger_time", 0.0)),
		highlight_count,
	]


func _gravity_ghost_snapshot() -> Dictionary:
	if RunProgress == null:
		return {}
	if RunProgress.has_method("get_last_gravity_ghost_replay"):
		var value: Variant = RunProgress.call("get_last_gravity_ghost_replay")
		if value is Dictionary:
			return value as Dictionary
	var fallback_value: Variant = RunProgress.arena_flags.get("gravity_ghost_replay", {})
	if fallback_value is Dictionary:
		return fallback_value as Dictionary
	return {}


func _score_snapshot_from_progress() -> Dictionary:
	if RunProgress == null:
		return {}
	var value: Variant = RunProgress.arena_flags.get("score_snapshot", {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _challenge_code_from_progress() -> String:
	if RunProgress == null:
		return ""
	return String(RunProgress.arena_flags.get("challenge_code", ""))


func _run_scene_from_progress() -> String:
	if RunProgress == null:
		return run_scene_path
	var value := String(RunProgress.arena_flags.get("retry_scene_path", run_scene_path))
	return value if not value.strip_edges().is_empty() else run_scene_path


func _title_scene_from_progress() -> String:
	if RunProgress == null:
		return title_scene_path
	var value := String(RunProgress.arena_flags.get("title_scene_path", title_scene_path))
	return value if not value.strip_edges().is_empty() else title_scene_path


func _on_copy_code_pressed() -> void:
	if not _challenge_code.is_empty():
		DisplayServer.clipboard_set(_challenge_code)
