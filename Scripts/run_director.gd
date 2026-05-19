extends Node
## Orchestrates rupture → music finale → credits after the authored wave arc.

const CREDITS_SCENE := "res://Nodes/credits_sequence.tscn"

var _wave_director: Node = null
var _rupture: Node = null
var _finale: Node = null
var _level_root: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	_level_root = get_tree().current_scene
	if _level_root == null:
		return

	_wave_director = _level_root.find_child("WaveDirector", true, false)
	if _wave_director != null:
		if _wave_director.has_signal("wave_cleared"):
			var wave_cb := Callable(self, "_on_wave_cleared")
			if not _wave_director.is_connected("wave_cleared", wave_cb):
				_wave_director.connect("wave_cleared", wave_cb)
		if _wave_director.has_signal("boss_defeated_anchor"):
			var boss_cb := Callable(self, "_on_boss_defeated")
			if not _wave_director.is_connected("boss_defeated_anchor", boss_cb):
				_wave_director.connect("boss_defeated_anchor", boss_cb)

	if not RunProgress.challenge_mode:
		RunProgress.phase_changed.connect(_on_phase_changed)

	_apply_loaded_anchor()
	_on_phase_changed(RunProgress.Phase.PHYSICS_WAVES, RunProgress.phase)


func _apply_loaded_anchor() -> void:
	if RunProgress.wave_index <= 0:
		return
	if _wave_director != null and _wave_director.has_method("restore_wave_index"):
		_wave_director.call("restore_wave_index", RunProgress.wave_index)
	var player := get_tree().get_first_node_in_group("Player")
	if player != null:
		RunProgress.apply_powerup_stacks(player.get_node_or_null("PowerupInventory"))


func _on_wave_cleared(wave: int) -> void:
	RunProgress.on_wave_cleared(wave)
	RunProgress.capture_powerup_stacks(_get_powerup_inventory())
	RunProgress.save_anchor()


func _on_boss_defeated(boss_scene_path: String) -> void:
	RunProgress.on_boss_defeated(boss_scene_path)
	RunProgress.capture_powerup_stacks(_get_powerup_inventory())
	RunProgress.save_anchor()


func _on_phase_changed(_old: RunProgress.Phase, new_phase: RunProgress.Phase) -> void:
	match new_phase:
		RunProgress.Phase.RUPTURE:
			_start_rupture()
		RunProgress.Phase.MUSIC_FINALE:
			_start_music_finale()
		RunProgress.Phase.CREDITS:
			_go_to_credits()


func _start_rupture() -> void:
	if _wave_director != null and _wave_director.has_method("halt_waves"):
		_wave_director.call("halt_waves")
	if _rupture != null and is_instance_valid(_rupture):
		return

	var scene: PackedScene = load("res://Nodes/rupture_director.tscn") as PackedScene
	if scene == null:
		RunProgress.enter_music_finale()
		return

	_rupture = scene.instantiate()
	_rupture.name = "RuptureDirector"
	_level_root.add_child(_rupture)
	if _rupture.has_signal("rupture_complete"):
		_rupture.connect("rupture_complete", Callable(self, "_on_rupture_complete"))


func _on_rupture_complete() -> void:
	if _rupture != null and is_instance_valid(_rupture):
		_rupture.queue_free()
		_rupture = null
	RunProgress.enter_music_finale()


func _start_music_finale() -> void:
	if _finale != null and is_instance_valid(_finale):
		return

	var scene: PackedScene = load("res://Nodes/music_finale_director.tscn") as PackedScene
	if scene == null:
		RunProgress.enter_credits()
		return

	_finale = scene.instantiate()
	_finale.name = "MusicFinaleDirector"
	_level_root.add_child(_finale)
	if _finale.has_signal("finale_complete"):
		_finale.connect("finale_complete", Callable(self, "_on_finale_complete"))


func _on_finale_complete() -> void:
	if _finale != null and is_instance_valid(_finale):
		_finale.queue_free()
		_finale = null
	RunProgress.enter_credits()


func _go_to_credits() -> void:
	if _wave_director != null and _wave_director.has_method("halt_waves"):
		_wave_director.call("halt_waves")
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _get_powerup_inventory() -> Node:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return null
	return player.get_node_or_null("PowerupInventory")
