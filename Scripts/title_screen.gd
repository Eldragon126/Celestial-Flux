extends Control

@export var version_string: String = "v1.0.4.6"

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var _starfield_backdrop: ColorRect = get_node_or_null("StarfieldBackdrop") as ColorRect
@onready var _version_label: Label = get_node_or_null("VersionLabel") as Label


func _ready() -> void:
	if not RunProgress:
		push_error("RunProgress autoload not found!")
		return

	if audio_player:
		audio_player.finished.connect(_on_audio_stream_player_finished, CONNECT_ONE_SHOT)

	_update_button_visibility()
	_update_version_label()

func _physics_process(delta: float) -> void:
	if get_tree().get_first_node_in_group("wave_enemy") == null:
		if get_tree().get_first_node_in_group("enemies") == null:
			if get_tree().get_first_node_in_group("ParametricEnemies") == null:
				$AudioStreamPlayer.stop()
				$SecretCompleted.play()
				$CenterContainer/Label.text = "SECRET COMPLETED"
				

func _on_audio_stream_player_finished() -> void:
	if animation_player:
		animation_player.pause()


func _process(_delta: float) -> void:
	if _starfield_backdrop != null and _starfield_backdrop.material != null:
		_starfield_backdrop.material.set_shader_parameter("real_time", Time.get_ticks_msec() / 1000.0)
	if Input.is_action_just_pressed("Confirm") and Input.is_key_pressed(KEY_SHIFT):
		if RunProgress.has_anchor:
			_begin_continue()


func _on_new_run_button_pressed() -> void:
	_begin_new_run(false)


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


func _on_secret_button_pressed() -> void:
	if get_tree().get_first_node_in_group("Player") == null:
		var player = preload("res://Nodes/player.tscn")
		var p = player.instantiate()
		p.global_position = $CenterContainer/Label.global_position
		get_tree().current_scene.call_deferred("add_child", p)
		RunProgress.begin_new_run(false)
	

	
