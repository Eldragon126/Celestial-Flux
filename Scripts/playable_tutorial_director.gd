extends Node2D
class_name PlayableTutorialDirector

const TITLE_SCENE := "res://Nodes/title_screen.tscn"

@export_node_path("CharacterBody2D") var player_path: NodePath = ^"Player"
@export var tutorial_target_group: StringName = &"tutorial_target"
@export var objective_minimum_time: float = 3.0
@export var completion_delay: float = 2.5

var _player: CharacterBody2D = null
var _weapon_system: Node = null
var _objective_index: int = 0
var _objective_elapsed: float = 0.0
var _shots_fired: int = 0
var _beam_ticks: int = 0
var _completed: bool = false

var _objectives: Array[String] = [
	"THRUST INTO THE WELL",
	"HOLD DRAG FOR A CLEAN TANGENT",
	"FIRE VECTOR BOLTS THROUGH GRAVITY",
	"TRY GRAVITY WAVE AND CHRONAL BEAMS",
	"EXIT THE FIELD WITH SPEED",
]

@onready var _objective_label: Label = get_node_or_null("TutorialCanvas/Panel/ObjectiveLabel") as Label
@onready var _detail_label: Label = get_node_or_null("TutorialCanvas/Panel/DetailLabel") as Label


func _ready() -> void:
	_resolve_player()
	_configure_tutorial_targets()
	_connect_player_signals()
	_update_objective_text()
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_objective_elapsed += delta
	_resolve_player()
	_update_objective_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu"):
		# FIX: Handle the input BEFORE changing the scene to ensure the viewport is still valid.
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(TITLE_SCENE)


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if _player != null:
		_weapon_system = _player.get_node_or_null("WeaponSystem")


func _connect_player_signals() -> void:
	if _player == null:
		return
	var shot_callable := Callable(self, "_on_player_shot")
	if _player.has_signal("momentum_projectile_spawned") and not _player.is_connected("momentum_projectile_spawned", shot_callable):
		_player.connect("momentum_projectile_spawned", shot_callable)
	if _weapon_system != null:
		var beam_callable := Callable(self, "_on_weapon_fired")
		if _weapon_system.has_signal("weapon_fired") and not _weapon_system.is_connected("weapon_fired", beam_callable):
			_weapon_system.connect("weapon_fired", beam_callable)


func _configure_tutorial_targets() -> void:
	for node in get_tree().get_nodes_in_group(tutorial_target_group):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("thrust_power") != null:
			node.set("thrust_power", 0.0)
		if node.get("max_speed") != null:
			node.set("max_speed", 0.0)
		if node.get("fire_interval") != null:
			node.set("fire_interval", 999.0)
		var health := node.get_node_or_null("HealthComponent")
		if health != null:
			if health.get("max_health") != null:
				health.set("max_health", 120.0)
			if health.get("current_health") != null:
				health.set("current_health", 120.0)


func _update_objective_progress() -> void:
	if _completed or _player == null or _objective_elapsed < objective_minimum_time:
		return

	match _objective_index:
		0:
			if _player.velocity.length() > 320.0:
				_advance_objective()
		1:
			if _is_in_slingshot_window():
				_advance_objective()
		2:
			if _shots_fired >= 3:
				_advance_objective()
		3:
			if _beam_ticks >= 8:
				_advance_objective()
		4:
			if _player.velocity.length() > 760.0 and _player.global_position.length() > 720.0:
				_complete_tutorial()


func _is_in_slingshot_window() -> bool:
	if _player == null:
		return false
	var value: Variant = _player.call("get_slingshot_debug_state") if _player.has_method("get_slingshot_debug_state") else {}
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = value
	var score := clampf(float(state.get("score", 0.0)), 0.0, 1.0)
	var speed := float(state.get("tangential_speed", 0.0))
	return score >= 0.38 and speed >= 260.0


func _advance_objective() -> void:
	_objective_index = mini(_objective_index + 1, _objectives.size() - 1)
	_objective_elapsed = 0.0
	_update_objective_text()


func _complete_tutorial() -> void:
	_completed = true
	_set_label_text("CALIBRATION COMPLETE", "Return to the title with Menu, or keep practicing in the arena.")
	await get_tree().create_timer(completion_delay).timeout


func _update_objective_text() -> void:
	var detail := ""
	match _objective_index:
		0:
			detail = "Build speed before the first curve."
		1:
			detail = "Drag ON is precision control; Drag OFF preserves momentum."
		2:
			detail = "The predictor now follows the same larger, faster bolt."
		3:
			detail = "Gravity Wave moves bodies; Chronal leaves delayed echoes."
		4:
			detail = "Leave the orbit with a readable escape vector."
	_set_label_text(_objectives[_objective_index], detail)


func _set_label_text(title: String, detail: String) -> void:
	if _objective_label != null:
		_objective_label.text = title
	if _detail_label != null:
		_detail_label.text = detail


func _on_player_shot(_projectile: Node, _direction: Vector2) -> void:
	_shots_fired += 1


func _on_weapon_fired(weapon_id: StringName, _weapon_data: Dictionary) -> void:
	if weapon_id != &"vector_bolt":
		_beam_ticks += 1
