extends Control

@export var run_scene_path: String = "res://Nodes/the_abyss.tscn"
@export var title_scene_path: String = "res://Nodes/title_screen.tscn"

@onready var death_vector_label: Label = $CenterPanel/Rows/DeathVectorLabel
@onready var try_again_button: Button = $CenterPanel/Rows/Buttons/TryAgainButton
@onready var title_button: Button = $CenterPanel/Rows/Buttons/TitleButton
@onready var backdrop: ColorRect = $FailureBackdrop


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	get_tree().paused = false
	RunProgress.clear_anchor()

	var message := RunProgress.last_death_message
	if message.is_empty():
		message = "DEATH VECTOR: the simulation collapsed before the lesson could stabilize."
	death_vector_label.text = message

	try_again_button.pressed.connect(_on_try_again_pressed)
	title_button.pressed.connect(_on_title_pressed)


func _process(_delta: float) -> void:
	if backdrop.material is ShaderMaterial:
		backdrop.material.set_shader_parameter("real_time", Time.get_ticks_msec() / 1000.0)


func _on_try_again_pressed() -> void:
	RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file(run_scene_path)


func _on_title_pressed() -> void:
	RunProgress.clear_anchor()
	get_tree().change_scene_to_file(title_scene_path)
