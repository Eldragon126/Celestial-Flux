extends Control

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not RunProgress:
		push_error("RunProgress autoload not found!")
		return
	
	if audio_player:
		audio_player.finished.connect(_on_audio_stream_player_finished, CONNECT_ONE_SHOT)
	
	_update_button_visibility()
	print("✅ Title Screen ready | Has anchor: ", RunProgress.has_anchor)


func _on_audio_stream_player_finished() -> void:
	if animation_player:
		animation_player.pause()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Confirm") and Input.is_key_pressed(KEY_SHIFT):
		if RunProgress.has_anchor:
			_begin_continue()


# Button Callbacks
func _on_new_run_button_pressed() -> void:
	_begin_new_run(false)


func _on_continue_button_pressed() -> void:
	_begin_continue()


func _on_challenge_button_pressed() -> void:
	_begin_new_run(true)


# Core Logic
func _begin_new_run(use_challenge: bool = false) -> void:
	RunProgress.begin_new_run(use_challenge)
	get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_continue() -> void:
	if RunProgress.has_anchor and RunProgress.load_anchor():
		get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")
	else:
		_begin_new_run(false)


# UI Helper
func _update_button_visibility() -> void:
	var continue_btn = $MenuRoot/ContinueButton
	if continue_btn:
		continue_btn.visible = RunProgress.has_anchor
		continue_btn.disabled = not RunProgress.has_anchor
