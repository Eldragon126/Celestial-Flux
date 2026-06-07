extends Control

@export var run_scene_path: String = "res://Nodes/the_abyss.tscn"
@export var title_scene_path: String = "res://Nodes/title_screen.tscn"
@export var death_label_glitch_strength: float = 4.0

@onready var death_vector_label: Label = $CenterPanel/Rows/DeathVectorLabel
@onready var try_again_button: Button = $CenterPanel/Rows/Buttons/TryAgainButton
@onready var title_button: Button = $CenterPanel/Rows/Buttons/TitleButton
@onready var backdrop: ColorRect = $FailureBackdrop

var _death_label_base_position := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	get_tree().paused = false
	RunProgress.clear_anchor()

	var message := RunProgress.last_death_message
	if message.is_empty():
		message = "DEATH VECTOR: the simulation collapsed before the lesson could stabilize."
	death_vector_label.text = message
	_death_label_base_position = death_vector_label.position

	try_again_button.pressed.connect(_on_try_again_pressed)
	title_button.pressed.connect(_on_title_pressed)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if backdrop.material is ShaderMaterial:
		backdrop.material.set_shader_parameter("real_time", now)
	_update_death_label_glitch(now)


func _on_try_again_pressed() -> void:
	RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file(run_scene_path)


func _on_title_pressed() -> void:
	RunProgress.clear_anchor()
	get_tree().change_scene_to_file(title_scene_path)


func _update_death_label_glitch(now: float) -> void:
	if death_vector_label == null:
		return
	var flicker := 0.5 + 0.5 * sin(now * 19.0)
	var sharp := 1.0 if sin(now * 37.0) > 0.86 else 0.0
	var strength := death_label_glitch_strength * sharp
	death_vector_label.position = _death_label_base_position + Vector2(strength, -strength * 0.35)
	death_vector_label.modulate = Color(0.72 + flicker * 0.18, 0.96, 1.0, 1.0)
