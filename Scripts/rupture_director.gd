extends Node
## Endgame rupture: exaggerated arena chaos, loosened player tuning, no wave spawns.

signal rupture_complete

const CHAOS_WISP_SCENE := preload("res://Nodes/chaos_wisp.tscn")
const RUPTURE_TRACK := preload("res://Assets/Songs/[Err -502] RUPTURE.mp3")

@export var duration_sec: float = 75.0
@export var instability_floor: float = 0.82
@export var event_interval_multiplier: float = 0.45
@export var rupture_spawn_interval: float = 8.0
@export var max_rupture_drifters: int = 5

var _elapsed: float = 0.0
var _spawn_elapsed: float = 0.0
var _arena: Node = null
var _player: Node2D = null
var _player_tuning_saved: Dictionary = {}
var _banner_canvas: CanvasLayer = null
var _banner_label: Label = null
var _spawned_drifters: Array[Node] = []
var _music: AudioStreamPlayer = null


func _ready() -> void:
	_elapsed = 0.0
	call_deferred("_begin_rupture")


func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_elapsed += delta
	if _spawn_elapsed >= rupture_spawn_interval:
		_spawn_elapsed = 0.0
		_spawn_rupture_drifter()
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

	_start_rupture_music()
	_build_rupture_prompt(level)
	for i in range(3):
		_spawn_rupture_drifter()


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
	if _music != null and is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
	if _banner_canvas != null and is_instance_valid(_banner_canvas):
		_banner_canvas.queue_free()
	for drifter in _spawned_drifters:
		if drifter != null and is_instance_valid(drifter):
			drifter.queue_free()
	_spawned_drifters.clear()


func _start_rupture_music() -> void:
	if _music != null and is_instance_valid(_music):
		return
	_music = AudioStreamPlayer.new()
	_music.name = "RuptureMusic"
	_music.stream = RUPTURE_TRACK
	_music.volume_db = -1.5
	add_child(_music)
	_music.play()


func _build_rupture_prompt(level: Node) -> void:
	if _banner_canvas != null:
		return

	_banner_canvas = CanvasLayer.new()
	_banner_canvas.name = "RuptureSignalCanvas"
	_banner_canvas.layer = 92
	level.add_child(_banner_canvas)

	var panel := PanelContainer.new()
	panel.name = "RuptureSignalPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -430.0
	panel.offset_right = 430.0
	panel.offset_top = 154.0
	panel.offset_bottom = 204.0
	panel.add_theme_stylebox_override("panel", _make_prompt_style())
	_banner_canvas.add_child(panel)

	_banner_label = Label.new()
	_banner_label.name = "RuptureSignalLabel"
	_banner_label.text = "LAWS CRACKING: WAVE GENERATOR OFFLINE"
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 24)
	_banner_label.modulate = Color(1.0, 0.42, 0.18, 0.95)
	panel.add_child(_banner_label)


func _spawn_rupture_drifter() -> void:
	var level := get_tree().current_scene
	if level == null or _player == null or not is_instance_valid(_player):
		return

	_cleanup_drifter_refs()
	if _spawned_drifters.size() >= max_rupture_drifters:
		return

	var drifter := CHAOS_WISP_SCENE.instantiate()
	drifter.name = "RuptureDrifter_%d" % Time.get_ticks_msec()
	drifter.add_to_group("wave_enemy")
	level.add_child(drifter)

	var drifter_2d := drifter as Node2D
	if drifter_2d != null:
		var angle := randf() * TAU
		drifter_2d.global_position = _player.global_position + Vector2.from_angle(angle) * randf_range(680.0, 1180.0)
	if drifter.get("max_speed") != null:
		drifter.set("max_speed", float(drifter.get("max_speed")) * 1.35)
	if drifter.get("random_acceleration") != null:
		drifter.set("random_acceleration", float(drifter.get("random_acceleration")) * 1.45)

	_spawned_drifters.append(drifter)


func _cleanup_drifter_refs() -> void:
	var kept: Array[Node] = []
	for drifter in _spawned_drifters:
		if drifter != null and is_instance_valid(drifter) and not drifter.is_queued_for_deletion():
			kept.append(drifter)
	_spawned_drifters = kept


func _make_prompt_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.012, 0.018, 0.78)
	style.border_color = Color(1.0, 0.25, 0.1, 0.62)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
