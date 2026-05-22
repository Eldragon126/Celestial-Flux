extends Control
## Non-interactive closure: Neon Starlight, no gameplay pressure.

const TITLE_SCENE := "res://Nodes/title_screen.tscn"
const CREDITS_TRACK := "res://Assets/Songs/Neon Starlight.mp3"

@onready var _music: AudioStreamPlayer = $CreditsMusic
@onready var _label: Label = $CenterContainer/CreditsLabel


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

	var stream := load(CREDITS_TRACK) as AudioStream
	if stream != null:
		_music.stream = stream
		_music.play()
		_music.finished.connect(_on_music_finished)
	else:
		push_warning("CreditsSequence: missing Neon Starlight.mp3")

	if _label != null:
		_label.text = "VECTORFALL RESOLVED"


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Confirm") or Input.is_action_just_pressed("Menu"):
		_skip_to_title()


func _on_music_finished() -> void:
	_skip_to_title()


func _skip_to_title() -> void:
	set_process(false)
	get_tree().change_scene_to_file(TITLE_SCENE)
