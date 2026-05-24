extends Node
## Orchestrates rupture → music finale → credits after the authored wave arc.

const CREDITS_SCENE := "res://Nodes/credits_sequence.tscn"

var _wave_director: Node = null
var _rupture: Node = null
var _finale: Node = null
var _level_root: Node = null
var _banner_canvas: CanvasLayer = null
var _banner_label: Label = null
var _banner_tween: Tween = null


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
		var phase_cb := Callable(self, "_on_phase_changed")
		if not RunProgress.phase_changed.is_connected(phase_cb):
			RunProgress.phase_changed.connect(phase_cb)

	_build_phase_banner()
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
	_save_anchor_if_run_active()


func _on_boss_defeated(boss_scene_path: String) -> void:
	RunProgress.on_boss_defeated(boss_scene_path)
	RunProgress.capture_powerup_stacks(_get_powerup_inventory())
	_save_anchor_if_run_active()


func _on_phase_changed(_old: RunProgress.Phase, new_phase: RunProgress.Phase) -> void:
	match new_phase:
		RunProgress.Phase.RUPTURE:
			_show_phase_banner("LAWS CRACKING: WAVE GENERATOR OFFLINE", Color(1.0, 0.34, 0.16, 1.0))
			_start_rupture()
		RunProgress.Phase.MUSIC_FINALE:
			_show_phase_banner("RESONANCE SINGULARITY ONLINE", Color(0.72, 0.95, 1.0, 1.0))
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


func _save_anchor_if_run_active() -> void:
	if RunProgress.run_finished:
		RunProgress.clear_anchor()
		return
	RunProgress.save_anchor()


func _build_phase_banner() -> void:
	if _level_root == null or _banner_canvas != null:
		return

	_banner_canvas = CanvasLayer.new()
	_banner_canvas.name = "RunPhaseBannerCanvas"
	_banner_canvas.layer = 90
	_level_root.add_child(_banner_canvas)

	var panel := PanelContainer.new()
	panel.name = "RunPhaseBanner"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -500.0
	panel.offset_right = 500.0
	panel.offset_top = 82.0
	panel.offset_bottom = 142.0
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.02, 0.012, 0.018, 0.82), Color(1.0, 0.3, 0.14, 0.58)))
	_banner_canvas.add_child(panel)

	_banner_label = Label.new()
	_banner_label.name = "RunPhaseBannerLabel"
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.theme_type_variation = &"HeaderSmall"
	_banner_label.add_theme_font_size_override("font_size", 28)
	_banner_label.text = ""
	panel.add_child(_banner_label)


func _show_phase_banner(message: String, color: Color) -> void:
	if _banner_canvas == null:
		_build_phase_banner()
	if _banner_canvas == null or _banner_label == null:
		return

	var panel := _banner_label.get_parent() as Control
	if panel == null:
		return

	_banner_label.text = message
	_banner_label.modulate = color
	panel.modulate.a = 0.0

	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_interval(2.35)
	_banner_tween.tween_property(panel, "modulate:a", 0.0, 0.45)


func _make_banner_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
