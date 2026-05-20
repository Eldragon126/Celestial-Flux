extends Control


func _ready() -> void:
	pass


func _on_audio_stream_player_finished() -> void:
	$AnimationPlayer.pause()


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("Confirm"):
		return
	if RunProgress.has_anchor and Input.is_key_pressed(KEY_SHIFT):
		_begin_continue()
	else:
		_begin_new_run()


func _begin_new_run() -> void:
	RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_continue() -> void:
	if RunProgress.load_anchor():
		get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _on_new_run_button_pressed() -> void:
	pass # Replace with function body.


func _on_continue_button_pressed() -> void:
	pass # Replace with function body.


func _on_challenge_button_pressed() -> void:
	pass # Replace with function body.
#These functions are connected from the buttons but they need to be made to actually work.
# The buttons also need to be a lot more visually appealing. I changed to fonts that look good.
