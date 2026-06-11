extends Control

@export var title_scene_path: String = "res://Nodes/title_screen.tscn"

var _registry: Node = null
var _summary_label: Label = null
var _details_label: Label = null


func _ready() -> void:
	_build_ui()
	_ensure_registry()
	_refresh_registry()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.006, 0.012, 0.024, 1.0)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "MOD MANAGER"
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.42, 1.0, 0.92, 1.0)
	rows.add_child(title)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 17)
	_summary_label.modulate = Color(0.78, 0.95, 1.0, 0.95)
	rows.add_child(_summary_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	rows.add_child(button_row)

	var rescan_button := _make_button("Rescan")
	rescan_button.pressed.connect(_refresh_registry)
	button_row.add_child(rescan_button)

	var copy_button := _make_button("Copy User Mods Path")
	copy_button.pressed.connect(_copy_user_mods_path)
	button_row.add_child(copy_button)

	var back_button := _make_button("Title Screen")
	back_button.pressed.connect(_on_back_pressed)
	button_row.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)

	_details_label = Label.new()
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_label.add_theme_font_size_override("font_size", 15)
	_details_label.modulate = Color(0.72, 0.9, 0.96, 0.92)
	scroll.add_child(_details_label)


func _ensure_registry() -> void:
	_registry = get_node_or_null("ModContentRegistry")
	if _registry != null:
		return
	_registry = ModContentRegistry.new()
	_registry.name = "ModContentRegistry"
	add_child(_registry)


func _refresh_registry() -> void:
	if _registry == null:
		return
	if _registry.has_method("reload_registry"):
		_registry.call("reload_registry")
	var summary: Dictionary = {}
	if _registry.has_method("get_registry_summary"):
		var summary_value: Variant = _registry.call("get_registry_summary")
		if summary_value is Dictionary:
			summary = summary_value
	var signature := String(_registry.call("get_compatibility_signature")) if _registry.has_method("get_compatibility_signature") else "unknown"
	var manifest_count := int(summary.get("manifest_count", 0))
	var content_total := int(summary.get("content_total", 0))
	var failed := int(summary.get("failed", 0))
	_summary_label.text = "Loaded %d manifests, %d content entries, %d failed. Gameplay signature: %s" % [manifest_count, content_total, failed, signature]
	_details_label.text = _build_details_text(summary)


func _build_details_text(summary: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Drop folders:")
	lines.append("Windows/macOS/Linux user mods: %s" % ProjectSettings.globalize_path("user://mods"))
	lines.append("Project bundled mods: res://Mods")
	lines.append("")
	lines.append("Compatibility:")
	lines.append("Only gameplay-affecting entries participate in the multiplayer signature. Local palettes, music, SFX, notes, thumbnails, and HUD badges are ignored.")
	lines.append("")
	lines.append("Loaded manifests:")
	var load_order: Array = summary.get("load_order", [])
	if load_order.is_empty():
		lines.append("- none")
	else:
		for manifest_id in load_order:
			lines.append("- %s" % String(manifest_id))
	lines.append("")
	lines.append("Content counts:")
	if _registry != null and _registry.has_method("get_content_buckets"):
		var buckets_value: Variant = _registry.call("get_content_buckets")
		var buckets: Array = buckets_value if buckets_value is Array else []
		for bucket in buckets:
			lines.append("- %s: %d" % [String(bucket), int(summary.get(String(bucket), 0))])
	return "\n".join(lines)


func _copy_user_mods_path() -> void:
	DisplayServer.clipboard_set(ProjectSettings.globalize_path("user://mods"))
	if _summary_label != null:
		_summary_label.text = "Copied user mods path: %s" % ProjectSettings.globalize_path("user://mods")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(title_scene_path)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190.0, 42.0)
	button.add_theme_font_size_override("font_size", 16)
	return button
