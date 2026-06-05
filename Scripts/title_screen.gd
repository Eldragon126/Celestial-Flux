extends Control

const SECRET_ENEMY_GROUPS: Array[StringName] = [&"wave_enemy", &"enemies", &"ParametricEnemies"]
const TITLE_TRACK_ORBITAL_DRIFT := preload("res://Assets/Songs/Orbital Drift.mp3")
const TITLE_TRACK_DARK_PULSE := preload("res://Assets/Songs/Title Screen New.mp3")

@export var version_string: String = "v1.0.4.6"
@export var secret_completion_check_interval: float = 0.25
@export var alternate_title_music: bool = true
@export var use_brand_logo_texture: bool = false
@export var logo_texture_path: String = "res://Assets/Brand/vector_anomaly_logo.svg"

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var _starfield_backdrop: ColorRect = get_node_or_null("StarfieldBackdrop") as ColorRect
@onready var _version_label: Label = get_node_or_null("VersionLabel") as Label
@onready var _title_label: Label = get_node_or_null("CenterContainer/Label") as Label
@onready var _title_logo: TextureRect = get_node_or_null("CenterContainer/TitleLogo") as TextureRect

var _secret_mode_active := false
var _secret_completion_announced := false
var _secret_completion_elapsed := 0.0
var _dark_title_variant := false


func _ready() -> void:
	$Menu/NewRunButton.grab_focus()
	if not RunProgress:
		push_error("RunProgress autoload not found!")
		return

	if audio_player:
		_configure_title_music()
		var finished_callable := Callable(self, "_on_audio_stream_player_finished")
		if not audio_player.finished.is_connected(finished_callable):
			audio_player.finished.connect(finished_callable, CONNECT_ONE_SHOT)

	_update_button_visibility()
	_update_version_label()
	_apply_title_brand()


func _physics_process(delta: float) -> void:
	if not _secret_mode_active or _secret_completion_announced:
		return

	_secret_completion_elapsed += delta
	if _secret_completion_elapsed < secret_completion_check_interval:
		return
	_secret_completion_elapsed = 0.0

	if _secret_enemy_groups_empty():
		_announce_secret_completed()


func _on_audio_stream_player_finished() -> void:
	if animation_player:
		animation_player.pause()


func _process(_delta: float) -> void:
	if _starfield_backdrop != null and _starfield_backdrop.material != null:
		_starfield_backdrop.material.set_shader_parameter("real_time", Time.get_ticks_msec() / 1000.0)
	_update_dark_title_pulse()
	if Input.is_action_just_pressed("Confirm") and Input.is_key_pressed(KEY_SHIFT):
		if RunProgress.has_anchor:
			_begin_continue()


func _configure_title_music() -> void:
	_dark_title_variant = alternate_title_music and (int(Time.get_ticks_msec() / 1000) % 2 == 1)
	audio_player.stop()
	audio_player.stream = TITLE_TRACK_DARK_PULSE if _dark_title_variant else TITLE_TRACK_ORBITAL_DRIFT
	audio_player.play()
	if animation_player == null:
		return
	if _dark_title_variant:
		animation_player.stop()
		if _title_label != null:
			_title_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 0.74))
	else:
		animation_player.play("ColorShift")


func _update_dark_title_pulse() -> void:
	if not _dark_title_variant:
		return
	var pulse := 0.62 + 0.18 * sin(Time.get_ticks_msec() / 1000.0 * 1.35)
	if _title_label != null and _title_label.visible:
		_title_label.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0, pulse))
	if _title_logo != null and _title_logo.visible:
		_title_logo.modulate = Color(0.72, 0.94, 1.0, pulse + 0.12)


func _on_new_run_button_pressed() -> void:
	_begin_new_run(false)


func _on_tutorial_button_pressed() -> void:
	RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file("res://Nodes/playable_tutorial.tscn")


func _on_continue_button_pressed() -> void:
	_begin_continue()


func _on_challenge_button_pressed() -> void:
	_begin_new_run(true)


func _on_boss_rush_button_pressed() -> void:
	RunProgress.begin_boss_rush()
	get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_new_run(use_challenge: bool = false) -> void:
	RunProgress.begin_new_run(use_challenge)
	get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_continue() -> void:
	if RunProgress.has_anchor and RunProgress.load_anchor():
		get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")
	else:
		_begin_new_run(false)


func _update_button_visibility() -> void:
	var continue_btn := get_node_or_null("Menu/ContinueButton") as Button
	if continue_btn:
		continue_btn.visible = RunProgress.has_anchor
		continue_btn.disabled = not RunProgress.has_anchor


func _update_version_label() -> void:
	if _version_label == null:
		return
	var project_version := String(ProjectSettings.get_setting("application/config/version", ""))
	_version_label.text = project_version if not project_version.is_empty() else version_string


func _apply_title_brand() -> void:
	if not use_brand_logo_texture:
		return
	var texture := load(logo_texture_path) as Texture2D
	if texture == null:
		return
	if _title_logo == null:
		var parent := get_node_or_null("CenterContainer")
		if parent == null:
			return
		_title_logo = TextureRect.new()
		_title_logo.name = "TitleLogo"
		_title_logo.custom_minimum_size = Vector2(860.0, 270.0)
		_title_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(_title_logo)
	_title_logo.texture = texture
	_title_logo.visible = true
	if _title_label != null:
		_title_label.visible = false


func _on_secret_button_pressed() -> void:
	if get_tree().get_first_node_in_group("Player") != null:
		_secret_mode_active = true
		return

	var player := preload("res://Nodes/player.tscn")
	var instance := player.instantiate() as Node2D
	if instance == null:
		return

	instance.global_position = $CenterContainer/Label.global_position
	get_tree().current_scene.call_deferred("add_child", instance)
	RunProgress.begin_new_run(false)
	_secret_mode_active = true
	_secret_completion_announced = false
	_secret_completion_elapsed = 0.0


func _secret_enemy_groups_empty() -> bool:
	for group_name in SECRET_ENEMY_GROUPS:
		if get_tree().get_first_node_in_group(group_name) != null:
			return false
	return true


func _announce_secret_completed() -> void:
	_secret_completion_announced = true
	_secret_mode_active = false
	if audio_player != null:
		audio_player.stop()
	var secret_player := get_node_or_null("SecretCompleted") as AudioStreamPlayer
	if secret_player != null and not secret_player.playing:
		secret_player.play()
	var title_label := get_node_or_null("CenterContainer/Label") as Label
	if title_label != null:
		if _title_logo != null:
			_title_logo.visible = false
		title_label.visible = true
		title_label.text = "SECRET COMPLETED"
