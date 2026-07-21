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

var _last_layout_position := Vector2.ZERO
var _glitch_offset := Vector2.ZERO

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
	
	# Ensures long text strings push elements vertically rather than overlapping horizontally
	death_vector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
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
	_restart_run_for_retry_scene(next_scene)
	if next_scene == "res://Nodes/the_abyss.tscn":
		get_tree().change_scene_to_file(run_loading_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene)


func _restart_run_for_retry_scene(next_scene: String) -> void:
	if RunProgress == null:
		return
	var was_boss_rush := RunProgress.boss_rush_mode
	var was_challenge := RunProgress.challenge_mode
	var previous_profile := String(RunProgress.arena_flags.get("run_profile", "")).strip_edges().to_lower()
	if was_boss_rush:
		RunProgress.begin_boss_rush()
	else:
		RunProgress.begin_new_run(was_challenge)
	RunProgress.arena_flags["retry_scene_path"] = next_scene
	RunProgress.arena_flags["title_scene_path"] = _resolved_title_scene_path
	if next_scene.ends_with("campaign_mode.tscn"):
		RunProgress.arena_flags["campaign_mode"] = true
		RunProgress.arena_flags["run_profile"] = "campaign"
	elif next_scene.ends_with("king_of_the_hill_mode.tscn"):
		RunProgress.arena_flags["campaign_mode"] = true
		RunProgress.arena_flags["king_of_hill_mode"] = true
		RunProgress.arena_flags["run_profile"] = "king_of_the_hill"
	elif next_scene.ends_with("demo_game.tscn"):
		RunProgress.arena_flags["run_profile"] = "steam_demo"
	elif next_scene.ends_with("playable_tutorial.tscn"):
		RunProgress.arena_flags["run_profile"] = "tutorial"
	elif next_scene.ends_with("clip_lab_scene.tscn"):
		RunProgress.arena_flags["run_profile"] = "clip_lab"
	elif not previous_profile.is_empty() and previous_profile != "standard":
		RunProgress.arena_flags["run_profile"] = previous_profile


func _on_title_pressed() -> void:
	RunProgress.clear_anchor()
	get_tree().change_scene_to_file(_resolved_title_scene_path)


func _update_death_label_glitch(now: float) -> void:
	if death_vector_label == null:
		return
		
	# If the layout engine recalculates and moves the label (e.g. from the VBoxContainer 
	# responding to the new summary grid or a window resize), we capture the new base position.
	if death_vector_label.position.distance_to(_last_layout_position + _glitch_offset) > 0.1:
		_last_layout_position = death_vector_label.position
		
	var flicker := 0.5 + 0.5 * sin(now * 19.0)
	var sharp := 1.0 if sin(now * 37.0) > 0.86 else 0.0
	var strength := death_label_glitch_strength * sharp
	
	_glitch_offset = Vector2(strength, -strength * 0.35)
	death_vector_label.position = _last_layout_position + _glitch_offset
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
