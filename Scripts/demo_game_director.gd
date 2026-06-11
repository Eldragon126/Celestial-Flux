extends Node2D

@export var demo_last_wave: int = 5
@export var steam_wishlist_url: String = "https://store.steampowered.com/"
@export var starting_upgrade_ids: Array[StringName] = [
	&"barycentric_tether",
	&"frame_dragging_anchor",
	&"relativistic_rail",
]

var _configure_attempts := 0
var _wave_director: Node = null
var _objective_label: Label = null
var _end_panel: PanelContainer = null
var _completed := false


func _ready() -> void:
	add_to_group("steam_demo_scene")
	if RunProgress != null:
		RunProgress.begin_new_run(false)
	call_deferred("_configure_demo")


func _configure_demo() -> void:
	_wave_director = find_child("WaveDirector", true, false)
	if _wave_director == null and _configure_attempts < 12:
		_configure_attempts += 1
		call_deferred("_configure_demo")
		return

	_apply_demo_wave_tuning()
	_apply_starting_upgrades()
	_build_demo_overlay()
	_update_objective("Waves 1-5: slingshot, bend shots, break the boss.")


func _apply_demo_wave_tuning() -> void:
	if _wave_director == null:
		return
	_set_if_present(_wave_director, &"boss_every_waves", demo_last_wave)
	_set_if_present(_wave_director, &"max_regular_enemies", 8)
	_set_if_present(_wave_director, &"minimum_regular_wave_duration", 92.0)
	_set_if_present(_wave_director, &"wave_soft_timeout", 168.0)
	_set_if_present(_wave_director, &"rest_between_waves", 4.0)
	_connect_signal(_wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_signal(_wave_director, &"boss_wave", Callable(self, "_on_boss_wave"))


func _apply_starting_upgrades() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var inventory := player.get_node_or_null("PowerupInventory")
	if inventory == null:
		inventory = PowerupInventory.new()
		inventory.name = "PowerupInventory"
		player.add_child(inventory)
	for powerup_id in starting_upgrade_ids:
		var definition := PowerupLibrary.get_definition(powerup_id)
		if definition != null and inventory.has_method("apply_powerup"):
			inventory.call("apply_powerup", definition)


func _build_demo_overlay() -> void:
	if _objective_label != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "DemoHUDLayer"
	layer.layer = 60
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "DemoObjectivePanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = 16.0
	panel.offset_bottom = 76.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.018, 0.032, 0.86), Color(0.2, 0.95, 1.0, 0.58)))
	layer.add_child(panel)

	_objective_label = Label.new()
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.modulate = Color(0.78, 1.0, 0.96, 1.0)
	panel.add_child(_objective_label)

	_end_panel = PanelContainer.new()
	_end_panel.name = "DemoEndPanel"
	_end_panel.visible = false
	_end_panel.anchor_left = 0.5
	_end_panel.anchor_top = 0.5
	_end_panel.anchor_right = 0.5
	_end_panel.anchor_bottom = 0.5
	_end_panel.offset_left = -300.0
	_end_panel.offset_right = 300.0
	_end_panel.offset_top = -150.0
	_end_panel.offset_bottom = 150.0
	_end_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.02, 0.04, 0.94), Color(1.0, 0.75, 0.25, 0.72)))
	layer.add_child(_end_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	_end_panel.add_child(rows)

	var title := Label.new()
	title.text = "DEMO COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(1.0, 0.86, 0.36, 1.0)
	rows.add_child(title)

	var body := Label.new()
	body.text = "You cleared the vertical slice. Wishlist Vector Anomaly to catch the full run."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.modulate = Color(0.78, 0.95, 1.0, 0.92)
	rows.add_child(body)

	var wishlist := _make_button("Wishlist")
	wishlist.pressed.connect(_on_wishlist_pressed)
	rows.add_child(wishlist)

	var title_button := _make_button("Title Screen")
	title_button.pressed.connect(_on_title_pressed)
	rows.add_child(title_button)


func _on_boss_wave() -> void:
	_update_objective("Boss wave: stay in orbit, bend the field, burn the core.")


func _on_wave_cleared(wave: int) -> void:
	if _completed:
		return
	if wave >= demo_last_wave:
		_completed = true
		_update_objective("Demo complete. Wishlist button unlocked.")
		if _end_panel != null:
			_end_panel.visible = true
	else:
		_update_objective("Wave %d cleared. Next: build speed through gravity." % wave)


func _update_objective(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = text


func _on_wishlist_pressed() -> void:
	if not steam_wishlist_url.strip_edges().is_empty():
		OS.shell_open(steam_wishlist_url)


func _on_title_pressed() -> void:
	get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _set_if_present(target: Node, property_name: StringName, value: Variant) -> void:
	if target != null and target.get(property_name) != null:
		target.set(property_name, value)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
