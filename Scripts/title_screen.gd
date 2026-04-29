extends Control


func _on_audio_stream_player_finished() -> void:
	$AnimationPlayer.pause()
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Confirm"):
		get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")
