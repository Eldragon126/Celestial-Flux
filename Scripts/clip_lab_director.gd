extends Node2D

const BASE_ENEMY_SCENE := preload("res://Nodes/base_enemy.tscn")
const SHOOTER_ENEMY_SCENE := preload("res://Nodes/base_shooter_enemy.tscn")
const GRAVITY_WARDEN_SCENE := preload("res://Nodes/gravity_warden_boss.tscn")

var _overlay: PanelContainer = null
var _instruction_label: Label = null
var _spawned: Array[Node] = []


func _ready() -> void:
	add_to_group("clip_lab_scene")
	if RunProgress != null:
		RunProgress.begin_new_run(false)
	call_deferred("_configure_lab")


func _configure_lab() -> void:
	_grant_showcase_upgrades()
	_build_overlay()
	_spawn_enemy_ring()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			if _overlay != null:
				_overlay.visible = not _overlay.visible
		KEY_F2:
			_spawn_enemy_ring()
		KEY_F3:
			_spawn_mini_boss()
		KEY_F4:
			_spawn_resonance_showcase()
		KEY_F5:
			_grant_showcase_upgrades()
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F8:
			_clear_spawned()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")


func _build_overlay() -> void:
	if _overlay != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ClipLabHUD"
	layer.layer = 70
	add_child(layer)

	_overlay = PanelContainer.new()
	_overlay.name = "ClipLabControls"
	_overlay.anchor_left = 1.0
	_overlay.anchor_right = 1.0
	_overlay.offset_left = -456.0
	_overlay.offset_right = -18.0
	_overlay.offset_top = 18.0
	_overlay.offset_bottom = 214.0
	_overlay.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.016, 0.03, 0.88), Color(0.32, 1.0, 0.9, 0.6)))
	layer.add_child(_overlay)

	_instruction_label = Label.new()
	_instruction_label.text = "CLIP LAB\nF2 enemy ring  F3 mini boss  F4 field rings\nF5 upgrades  F6 reset  F8 clear  Esc title"
	_instruction_label.add_theme_font_size_override("font_size", 16)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.modulate = Color(0.78, 1.0, 0.96, 1.0)
	_overlay.add_child(_instruction_label)


func _spawn_enemy_ring() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var center := player.global_position if player != null else Vector2.ZERO
	for i in range(8):
		var scene := BASE_ENEMY_SCENE if i % 2 == 0 else SHOOTER_ENEMY_SCENE
		var enemy := scene.instantiate() as Node2D
		if enemy == null:
			continue
		var angle := TAU * float(i) / 8.0
		enemy.global_position = center + Vector2(cos(angle), sin(angle)) * 680.0
		add_child(enemy)
		_spawned.append(enemy)


func _spawn_mini_boss() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var boss := GRAVITY_WARDEN_SCENE.instantiate() as Node2D
	if boss == null:
		return
	boss.global_position = (player.global_position if player != null else Vector2.ZERO) + Vector2(820.0, -260.0)
	if boss.get("max_health") != null:
		boss.set("max_health", 1200.0)
	add_child(boss)
	_spawned.append(boss)


func _spawn_resonance_showcase() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var center := player.global_position if player != null else Vector2.ZERO
	var manager := find_child("GravityResonanceManager", true, false)
	if manager == null or not manager.has_method("create_manual_resonance_zone"):
		return
	manager.call("create_manual_resonance_zone", center + Vector2(360.0, 0.0), 210.0, 4, 0.86, 4.0)
	manager.call("create_manual_resonance_zone", center + Vector2(-320.0, -120.0), 190.0, 1, 0.76, 4.0)
	manager.call("create_manual_resonance_zone", center + Vector2(0.0, 340.0), 180.0, 3, 0.68, 4.0)


func _grant_showcase_upgrades() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var inventory := player.get_node_or_null("PowerupInventory")
	if inventory == null:
		inventory = PowerupInventory.new()
		inventory.name = "PowerupInventory"
		player.add_child(inventory)
	for powerup_id in [&"barycentric_tether", &"frame_dragging_anchor", &"apex_vector_core", &"relativistic_rail"]:
		var definition := PowerupLibrary.get_definition(powerup_id)
		if definition != null and inventory.has_method("apply_powerup"):
			inventory.call("apply_powerup", definition)


func _clear_spawned() -> void:
	for node in _spawned:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_spawned.clear()


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
