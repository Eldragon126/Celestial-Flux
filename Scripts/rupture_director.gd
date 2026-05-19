extends Node
## Endgame rupture: exaggerated arena chaos, loosened player tuning, no wave spawns.

signal rupture_complete

@export var duration_sec: float = 75.0
@export var instability_floor: float = 0.82
@export var event_interval_multiplier: float = 0.45

var _elapsed: float = 0.0
var _arena: Node = null
var _player: Node2D = null
var _player_tuning_saved: Dictionary = {}


func _ready() -> void:
	_elapsed = 0.0
	call_deferred("_begin_rupture")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration_sec:
		rupture_complete.emit()
		set_process(false)


func _begin_rupture() -> void:
	var level := get_tree().current_scene
	if level == null:
		rupture_complete.emit()
		return

	_arena = level.find_child("ArenaDestabilizationManager", true, false)
	if _arena != null:
		if _arena.get("instability") != null:
			_arena.set("instability", instability_floor)
		if _arena.get("chaos_level") != null:
			_arena.set("chaos_level", instability_floor)
		if _arena.get("min_event_interval") != null:
			var min_iv: float = float(_arena.get("min_event_interval"))
			_arena.set("min_event_interval", min_iv * event_interval_multiplier)
		if _arena.has_method("force_arena_event"):
			_arena.call("force_arena_event", &"rupture_pulse")

	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _player != null:
		_save_player_tuning()
		_apply_rupture_player_tuning()

	var wave := level.find_child("WaveDirector", true, false)
	if wave != null and wave.has_method("halt_waves"):
		wave.call("halt_waves")


func _save_player_tuning() -> void:
	_player_tuning_saved.clear()
	for key in ["max_speed", "drag", "idle_drag", "gravity_constant", "slingshot_factor"]:
		if _player.get(key) != null:
			_player_tuning_saved[key] = _player.get(key)


func _apply_rupture_player_tuning() -> void:
	if _player.get("max_speed") != null:
		_player.set("max_speed", float(_player.get("max_speed")) * 1.22)
	if _player.get("drag") != null:
		_player.set("drag", clampf(float(_player.get("drag")) * 1.04, 0.9, 0.995))
	if _player.get("gravity_constant") != null:
		_player.set("gravity_constant", float(_player.get("gravity_constant")) * 1.35)
	if _player.get("slingshot_factor") != null:
		_player.set("slingshot_factor", float(_player.get("slingshot_factor")) * 1.28)


func _restore_player_tuning() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for key in _player_tuning_saved.keys():
		_player.set(key, _player_tuning_saved[key])


func _exit_tree() -> void:
	_restore_player_tuning()
