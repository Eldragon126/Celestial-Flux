extends Control

@export var title_scene_path: String = "res://Nodes/title_screen.tscn"

var _registry: Node = null
var _summary_label: Label = null
var _details_label: Label = null
var _details_box: VBoxContainer = null


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
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(rows)

	var title := Label.new()
	title.text = "MOD MANAGER"
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.42, 1.0, 0.92, 1.0)
	rows.add_child(title)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 17)
	_summary_label.modulate = Color(0.78, 0.95, 1.0, 0.95)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var copy_all_button := _make_button("Copy All Mod Paths")
	copy_all_button.pressed.connect(_copy_all_mod_paths)
	button_row.add_child(copy_all_button)

	var back_button := _make_button("Title Screen")
	back_button.pressed.connect(_on_back_pressed)
	button_row.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rows.add_child(scroll)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 10)
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_details_box)

	_details_label = Label.new()
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_label.add_theme_font_size_override("font_size", 15)
	_details_label.modulate = Color(0.72, 0.9, 0.96, 0.92)
	_details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_label.custom_minimum_size = Vector2(860.0, 0.0)
	_details_box.add_child(_details_label)


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
	_render_registry()


func _render_registry(feedback_text: String = "") -> void:
	if _registry == null:
		return
	var summary: Dictionary = {}
	if _registry.has_method("get_registry_summary"):
		var summary_value: Variant = _registry.call("get_registry_summary")
		if summary_value is Dictionary:
			summary = summary_value
	var signature := String(_registry.call("get_compatibility_signature")) if _registry.has_method("get_compatibility_signature") else "unknown"
	var manifest_count := int(summary.get("manifest_count", 0))
	var content_total := int(summary.get("content_total", 0))
	var failed := int(summary.get("failed", 0))
	var disabled := int(summary.get("disabled", 0))
	var user_disabled := int(summary.get("user_disabled", 0))
	_summary_label.text = "Loaded %d manifests, %d content entries, %d failed, %d off (%d toggled). Gameplay signature: %s" % [
		manifest_count,
		content_total,
		failed,
		disabled,
		user_disabled,
		signature,
	]
	if not feedback_text.is_empty():
		_summary_label.text = "%s\n%s" % [feedback_text, _summary_label.text]
	_details_label.text = _build_details_text(summary)
	_populate_detail_cards(summary)


func _build_details_text(summary: Dictionary) -> String:
	var install_paths := _get_install_paths()
	var lines := PackedStringArray()
	lines.append("Drop folders:")
	lines.append("User mods: %s" % str(install_paths.get("user_mods", ProjectSettings.globalize_path("user://mods"))))
	var executable_mods := str(install_paths.get("executable_mods", "")).strip_edges()
	if not executable_mods.is_empty():
		lines.append("Export-adjacent mods: %s" % executable_mods)
	lines.append("Project bundled mods: %s" % str(install_paths.get("bundled_mods", "res://Mods")))
	lines.append("Manifest files: %s" % _join_array_text(install_paths.get("manifest_files", [])))
	lines.append("")
	lines.append("Compatibility:")
	lines.append("Only gameplay-affecting entries participate in the multiplayer signature. Local palettes, shader packs, texture packs, music, SFX, notes, thumbnails, and HUD badges are ignored.")
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


func _populate_detail_cards(summary: Dictionary) -> void:
	if _details_box == null:
		return
	for child in _details_box.get_children():
		if child == _details_label:
			continue
		child.queue_free()
	_details_label.text = ""
	var install_paths := _get_install_paths()
	var executable_mods := str(install_paths.get("executable_mods", "")).strip_edges()
	var drop_lines: Array[String] = [
		"User mods: %s" % str(install_paths.get("user_mods", ProjectSettings.globalize_path("user://mods"))),
		"Bundled mods: %s" % str(install_paths.get("bundled_mods", "res://Mods")),
		"Manifest files: %s" % _join_array_text(install_paths.get("manifest_files", [])),
	]
	if not executable_mods.is_empty():
		drop_lines.insert(1, "Export-adjacent mods: %s" % executable_mods)
	_details_box.add_child(_make_detail_section("Drop Folders", drop_lines))
	var scan_lines: Array[String] = []
	for root_value in _get_scan_roots():
		if not (root_value is Dictionary):
			continue
		var root: Dictionary = root_value
		var marker := "OK" if bool(root.get("exists", false)) else "Missing"
		scan_lines.append("[%s] %s: %s" % [
			marker,
			str(root.get("source_kind", "custom")).capitalize(),
			str(root.get("display_path", root.get("source_root", ""))),
		])
	if scan_lines.is_empty():
		scan_lines.append("No scan roots reported yet.")
	_details_box.add_child(_make_detail_section("Scanned Roots", scan_lines))
	_details_box.add_child(_make_detail_section("Compatibility", [
		"Gameplay entries affect multiplayer signatures.",
		"Palettes, shader packs, texture packs, music, SFX, notes, thumbnails, and HUD badges stay local-only.",
	]))
	var load_order: Array = summary.get("load_order", [])
	var snapshot := _get_registry_snapshot()
	var manifests_value: Variant = snapshot.get("manifests", {})
	var manifests: Dictionary = manifests_value if manifests_value is Dictionary else {}
	_details_box.add_child(_make_manifest_toggle_section(load_order, manifests))
	var manifest_lines: Array[String] = []
	if load_order.is_empty():
		manifest_lines.append("No manifests loaded.")
	else:
		for manifest_id in load_order:
			var manifest_value: Variant = manifests.get(String(manifest_id), {})
			var manifest: Dictionary = manifest_value if manifest_value is Dictionary else {}
			var source_kind := str(manifest.get("source_kind", "")).strip_edges()
			var source_path := str(manifest.get("source_display_path", manifest.get("source_path", ""))).strip_edges()
			var suffix := ""
			if not source_kind.is_empty():
				suffix += " | %s" % source_kind
			if not source_path.is_empty():
				suffix += " | %s" % source_path
			var status := "active" if bool(manifest.get("enabled", true)) else "off"
			var reason := str(manifest.get("disabled_reason", "")).strip_edges()
			if not reason.is_empty():
				suffix += " | %s" % reason
			manifest_lines.append("- %s [%s]%s" % [String(manifest_id), status, suffix])
	_details_box.add_child(_make_detail_section("Loaded Manifests", manifest_lines))
	var failed_value: Variant = snapshot.get("failed_manifests", {})
	var failed: Dictionary = failed_value if failed_value is Dictionary else {}
	if not failed.is_empty():
		var failed_lines: Array[String] = []
		for path in failed.keys():
			failed_lines.append("%s: %s" % [str(path), str(failed[path])])
		_details_box.add_child(_make_detail_section("Failed Manifests", failed_lines))
	var count_lines: Array[String] = []
	if _registry != null and _registry.has_method("get_content_buckets"):
		var buckets_value: Variant = _registry.call("get_content_buckets")
		var buckets: Array = buckets_value if buckets_value is Array else []
		for bucket in buckets:
			var count := int(summary.get(String(bucket), 0))
			if count > 0:
				count_lines.append("%s: %d" % [String(bucket).capitalize(), count])
	if count_lines.is_empty():
		count_lines.append("No content buckets active yet.")
	_details_box.add_child(_make_detail_section("Content Counts", count_lines))


func _make_manifest_toggle_section(load_order: Array, manifests: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "MOD TOGGLES"
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.46, 1.0, 0.92, 1.0)
	rows.add_child(title)

	var hint := Label.new()
	hint.text = "Turn discovered mods on or off without moving their folders. Changes are saved in user data and applied on the next registry refresh."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.72, 0.9, 0.96, 0.86)
	rows.add_child(hint)

	if load_order.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No installed manifests found in the scanned folders."
		empty_label.modulate = Color(0.78, 0.92, 0.98, 0.92)
		rows.add_child(empty_label)
		return panel

	for manifest_id in load_order:
		var manifest_key := String(manifest_id)
		var manifest_value: Variant = manifests.get(manifest_key, {})
		var manifest: Dictionary = manifest_value if manifest_value is Dictionary else {}
		var display_name := str(manifest.get("display_name", manifest_key)).strip_edges()
		if display_name.is_empty():
			display_name = manifest_key
		var user_disabled := bool(manifest.get("user_disabled", false))
		var active := bool(manifest.get("enabled", true))
		var reason := str(manifest.get("disabled_reason", "")).strip_edges()

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(row)

		var toggle := CheckBox.new()
		toggle.text = "%s  (%s)" % [display_name, manifest_key]
		toggle.button_pressed = not user_disabled
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.tooltip_text = "Enable or disable this mod manifest."
		toggle.toggled.connect(_on_manifest_toggled.bind(manifest_key))
		row.add_child(toggle)

		var status := Label.new()
		status.custom_minimum_size = Vector2(92.0, 0.0)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 13)
		if user_disabled:
			status.text = "OFF"
			status.modulate = Color(1.0, 0.58, 0.42, 0.95)
		elif active:
			status.text = "ACTIVE"
			status.modulate = Color(0.52, 1.0, 0.72, 0.95)
		else:
			status.text = "BLOCKED"
			status.modulate = Color(1.0, 0.82, 0.36, 0.95)
		row.add_child(status)

		var meta := Label.new()
		var source_path := str(manifest.get("source_display_path", manifest.get("source_path", ""))).strip_edges()
		var source_kind := str(manifest.get("source_kind", "mod")).capitalize()
		var source_suffix := " | %s" % source_path if not source_path.is_empty() else ""
		meta.text = "%s%s" % [source_kind, source_suffix]
		if not reason.is_empty():
			meta.text += " | %s" % reason
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.add_theme_font_size_override("font_size", 12)
		meta.modulate = Color(0.66, 0.82, 0.9, 0.82)
		rows.add_child(meta)
	return panel


func _on_manifest_toggled(enabled_state: bool, manifest_id: String) -> void:
	if _registry == null or not _registry.has_method("set_manifest_user_enabled"):
		_render_registry("Mod toggles are unavailable for this registry.")
		return
	_registry.call("set_manifest_user_enabled", StringName(manifest_id), enabled_state)
	var state_text := "Enabled" if enabled_state else "Disabled"
	_render_registry("%s mod: %s" % [state_text, manifest_id])


func _make_detail_section(title_text: String, body_lines: Array[String]) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	panel.add_child(rows)

	var title := Label.new()
	title.text = title_text.to_upper()
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.46, 1.0, 0.92, 1.0)
	rows.add_child(title)

	for line in body_lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		label.modulate = Color(0.78, 0.92, 0.98, 0.92)
		rows.add_child(label)
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.064, 0.82)
	style.border_color = Color(0.18, 0.84, 1.0, 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 12.0)
	style.set_content_margin(SIDE_TOP, 10.0)
	style.set_content_margin(SIDE_RIGHT, 12.0)
	style.set_content_margin(SIDE_BOTTOM, 10.0)
	return style


func _get_install_paths() -> Dictionary:
	if _registry != null and _registry.has_method("get_mod_install_paths"):
		var value: Variant = _registry.call("get_mod_install_paths")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {
		"platform": OS.get_name(),
		"user_mods": ProjectSettings.globalize_path("user://mods"),
		"bundled_mods": "res://Mods",
		"executable_mods": "",
		"manifest_files": ["vector_anomaly_mod.json", "mod.json"],
	}


func _get_scan_roots() -> Array:
	if _registry != null and _registry.has_method("get_scan_roots"):
		var value: Variant = _registry.call("get_scan_roots")
		if value is Array:
			return value as Array
	return []


func _get_registry_snapshot() -> Dictionary:
	if _registry != null and _registry.has_method("get_registry_snapshot"):
		var value: Variant = _registry.call("get_registry_snapshot")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _join_array_text(value: Variant) -> String:
	if not (value is Array):
		return str(value)
	var parts := PackedStringArray()
	for item in (value as Array):
		parts.append(str(item))
	return ", ".join(parts)


func _copy_user_mods_path() -> void:
	var install_paths := _get_install_paths()
	var user_path := str(install_paths.get("user_mods", ProjectSettings.globalize_path("user://mods")))
	DisplayServer.clipboard_set(user_path)
	if _summary_label != null:
		_summary_label.text = "Copied user mods path: %s" % user_path


func _copy_all_mod_paths() -> void:
	var install_paths := _get_install_paths()
	var lines := PackedStringArray()
	lines.append("User mods: %s" % str(install_paths.get("user_mods", "")))
	var executable_mods := str(install_paths.get("executable_mods", "")).strip_edges()
	if not executable_mods.is_empty():
		lines.append("Export-adjacent mods: %s" % executable_mods)
	lines.append("Bundled mods: %s" % str(install_paths.get("bundled_mods", "res://Mods")))
	lines.append("Manifest files: %s" % _join_array_text(install_paths.get("manifest_files", [])))
	for root_value in _get_scan_roots():
		if not (root_value is Dictionary):
			continue
		var root: Dictionary = root_value
		lines.append("Scanned %s: %s" % [
			str(root.get("source_kind", "custom")),
			str(root.get("display_path", root.get("source_root", ""))),
		])
	DisplayServer.clipboard_set("\n".join(lines))
	if _summary_label != null:
		_summary_label.text = "Copied mod install and scan paths."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(title_scene_path)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190.0, 42.0)
	button.add_theme_font_size_override("font_size", 16)
	return button
