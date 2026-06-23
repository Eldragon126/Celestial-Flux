extends Control

@export var title_scene_path: String = "res://Nodes/title_screen.tscn"

var _registry: Node = null
var _summary_label: Label = null
var _details_label: Label = null
var _details_box: VBoxContainer = null
var _creator_sandbox: PanelContainer = null
var _creator_manifest_editor: TextEdit = null
var _creator_validation_label: Label = null


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

	var button_row := HFlowContainer.new()
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

	var report_button := _make_button("Export Creator Report")
	report_button.pressed.connect(_export_creator_report)
	button_row.add_child(report_button)

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
	_creator_sandbox = _build_creator_sandbox()
	_details_box.add_child(_creator_sandbox)


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
	var dependency_warnings := int(summary.get("dependency_warnings", 0))
	var conflicts := int(summary.get("conflict_warnings", 0))
	var disabled := int(summary.get("disabled", 0))
	var user_disabled := int(summary.get("user_disabled", 0))
	_summary_label.text = "Loaded %d manifests, %d content entries, %d failed, %d dependency warnings, %d conflicts, %d off (%d toggled). Gameplay signature: %s" % [
		manifest_count,
		content_total,
		failed,
		dependency_warnings,
		conflicts,
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
		if child == _details_label or child == _creator_sandbox:
			continue
		if child != null and is_instance_valid(child) and not child.is_queued_for_deletion():
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
	var dependency_value: Variant = snapshot.get("dependency_warnings", {})
	var dependency_warnings: Dictionary = dependency_value if dependency_value is Dictionary else {}
	if not dependency_warnings.is_empty():
		var dependency_lines: Array[String] = []
		for warning_value in dependency_warnings.values():
			if not (warning_value is Dictionary):
				continue
			var warning := warning_value as Dictionary
			dependency_lines.append("%s -> %s: %s" % [
				str(warning.get("manifest_id", "unknown")),
				str(warning.get("dependency_id", "unknown")),
				str(warning.get("reason", "dependency warning")),
			])
		_details_box.add_child(_make_detail_section("Dependency Diagnostics", dependency_lines))
	var conflicts_value: Variant = snapshot.get("conflict_warnings", {})
	var conflicts: Dictionary = conflicts_value if conflicts_value is Dictionary else {}
	if not conflicts.is_empty():
		var conflict_lines: Array[String] = []
		for warning_value in conflicts.values():
			if not (warning_value is Dictionary):
				continue
			var warning := warning_value as Dictionary
			conflict_lines.append("%s conflicts with %s: %s" % [
				str(warning.get("manifest_id", "unknown")),
				str(warning.get("conflicting_id", "unknown")),
				str(warning.get("reason", "declared incompatible")),
			])
		_details_box.add_child(_make_detail_section("Conflict Diagnostics", conflict_lines))
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


func _build_creator_sandbox() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "CREATOR SANDBOX"
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1.0, 0.82, 0.42, 1.0)
	rows.add_child(title)

	var hint := Label.new()
	hint.text = "Paste a schema 4 manifest to validate it with the live registry, then install the validated contract into user://mods/<id>. Existing packs are never overwritten."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.72, 0.9, 0.96, 0.9)
	rows.add_child(hint)

	_creator_manifest_editor = TextEdit.new()
	_creator_manifest_editor.custom_minimum_size = Vector2(760.0, 150.0)
	_creator_manifest_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creator_manifest_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_creator_manifest_editor.placeholder_text = "Paste vector_anomaly_mod.json here"
	_creator_manifest_editor.text = JSON.stringify({
		"id": "my_vector_pack",
		"display_name": "My Vector Pack",
		"version": "1.0.0",
		"schema_version": 4,
		"content": {"creator_notes": [{"id": "first_note", "network_category": "local_visual"}]},
	}, "\t")
	rows.add_child(_creator_manifest_editor)

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("separation", 8)
	rows.add_child(actions)
	var validate_button := _make_button("Validate Draft")
	validate_button.pressed.connect(_validate_creator_draft)
	actions.add_child(validate_button)
	var install_button := _make_button("Install Valid Draft")
	install_button.pressed.connect(_install_creator_draft)
	actions.add_child(install_button)

	_creator_validation_label = Label.new()
	_creator_validation_label.text = "Draft has not been validated yet."
	_creator_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creator_validation_label.modulate = Color(0.68, 0.86, 0.94, 0.92)
	rows.add_child(_creator_validation_label)
	return panel


func _validate_creator_draft() -> bool:
	if _registry == null or _creator_manifest_editor == null or not _registry.has_method("validate_manifest_text"):
		return false
	var result_value: Variant = _registry.call("validate_manifest_text", _creator_manifest_editor.text)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	var valid := bool(result.get("valid", false))
	var errors_value: Variant = result.get("errors", [])
	var errors: Array = errors_value if errors_value is Array else []
	if _creator_validation_label != null:
		_creator_validation_label.text = "VALID // %s" % str(result.get("manifest_id", "unnamed")) if valid else "BLOCKED // %s" % _join_array_text(errors)
		_creator_validation_label.modulate = Color(0.52, 1.0, 0.72, 0.95) if valid else Color(1.0, 0.58, 0.42, 0.95)
	return valid


func _install_creator_draft() -> void:
	if not _validate_creator_draft() or _registry == null or not _registry.has_method("install_manifest_text"):
		return
	var result_value: Variant = _registry.call("install_manifest_text", _creator_manifest_editor.text, false)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	if bool(result.get("installed", false)):
		_render_registry("Installed %s to %s" % [str(result.get("manifest_id", "mod")), str(result.get("path", "user mods"))])
		return
	var errors_value: Variant = result.get("errors", [])
	var errors: Array = errors_value if errors_value is Array else []
	if _creator_validation_label != null:
		_creator_validation_label.text = "INSTALL BLOCKED // %s" % _join_array_text(errors)
		_creator_validation_label.modulate = Color(1.0, 0.58, 0.42, 0.95)


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

		if _registry != null and _registry.has_method("get_manifest_options"):
			var options_value: Variant = _registry.call("get_manifest_options", StringName(manifest_key))
			if options_value is Array and not (options_value as Array).is_empty():
				var options_header := HBoxContainer.new()
				options_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rows.add_child(options_header)
				var options_title := Label.new()
				options_title.text = "CREATOR OPTIONS"
				options_title.add_theme_font_size_override("font_size", 12)
				options_title.modulate = Color(1.0, 0.82, 0.42, 0.94)
				options_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				options_header.add_child(options_title)
				var reset_options := Button.new()
				reset_options.text = "Reset"
				reset_options.tooltip_text = "Restore this pack's creator options to manifest defaults."
				reset_options.pressed.connect(_on_reset_manifest_options.bind(manifest_key))
				options_header.add_child(reset_options)
				for option_value in options_value as Array:
					if option_value is Dictionary:
						rows.add_child(_make_mod_option_control(manifest_key, option_value as Dictionary))
	return panel


func _make_mod_option_control(manifest_id: String, option: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var option_id := str(option.get("id", "option"))
	var option_type := str(option.get("type", "bool"))
	var value: Variant = option.get("value", option.get("default"))

	var label := Label.new()
	label.text = str(option.get("display_name", option_id)).capitalize()
	label.tooltip_text = str(option.get("description", ""))
	label.custom_minimum_size = Vector2(260.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	match option_type:
		"bool":
			var toggle := CheckBox.new()
			toggle.button_pressed = bool(value)
			toggle.toggled.connect(_on_mod_option_changed.bind(manifest_id, option_id))
			row.add_child(toggle)
		"int", "float":
			var spinner := SpinBox.new()
			spinner.custom_minimum_size = Vector2(150.0, 0.0)
			spinner.min_value = float(option.get("min", -1000000.0))
			spinner.max_value = float(option.get("max", 1000000.0))
			spinner.step = 1.0 if option_type == "int" else float(option.get("step", 0.1))
			spinner.value = float(value)
			spinner.value_changed.connect(_on_numeric_mod_option_changed.bind(manifest_id, option_id, option_type))
			row.add_child(spinner)
		"choice":
			var choices := OptionButton.new()
			choices.custom_minimum_size = Vector2(190.0, 0.0)
			var choice_values: Array = option.get("choices", [])
			for choice_index in range(choice_values.size()):
				choices.add_item(str(choice_values[choice_index]))
				if choice_values[choice_index] == value:
					choices.select(choice_index)
			choices.item_selected.connect(_on_choice_mod_option_changed.bind(manifest_id, option_id, choice_values))
			row.add_child(choices)
		"color":
			var color_picker := ColorPickerButton.new()
			color_picker.custom_minimum_size = Vector2(150.0, 34.0)
			color_picker.color = Color.from_string(str(value), Color.WHITE)
			color_picker.color_changed.connect(_on_color_mod_option_changed.bind(manifest_id, option_id))
			row.add_child(color_picker)
		_:
			var text_input := LineEdit.new()
			text_input.custom_minimum_size = Vector2(240.0, 0.0)
			text_input.text = str(value)
			text_input.text_submitted.connect(_on_mod_option_changed.bind(manifest_id, option_id))
			row.add_child(text_input)
	return row


func _on_mod_option_changed(value: Variant, manifest_id: String, option_id: String) -> void:
	if _registry == null or not _registry.has_method("set_mod_option"):
		return
	if bool(_registry.call("set_mod_option", StringName(manifest_id), StringName(option_id), value)):
		var signature := str(_registry.call("get_compatibility_signature")) if _registry.has_method("get_compatibility_signature") else "unknown"
		_summary_label.text = "Updated %s.%s. Gameplay signature: %s" % [manifest_id, option_id, signature]


func _on_numeric_mod_option_changed(value: float, manifest_id: String, option_id: String, option_type: String) -> void:
	_on_mod_option_changed(int(value) if option_type == "int" else value, manifest_id, option_id)


func _on_choice_mod_option_changed(index: int, manifest_id: String, option_id: String, choices: Array) -> void:
	if index >= 0 and index < choices.size():
		_on_mod_option_changed(choices[index], manifest_id, option_id)


func _on_color_mod_option_changed(value: Color, manifest_id: String, option_id: String) -> void:
	_on_mod_option_changed(value.to_html(true), manifest_id, option_id)


func _on_reset_manifest_options(manifest_id: String) -> void:
	if _registry == null or not _registry.has_method("reset_manifest_options"):
		return
	if bool(_registry.call("reset_manifest_options", StringName(manifest_id))):
		call_deferred("_render_registry", "Reset creator options for %s" % manifest_id)


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


func _export_creator_report() -> void:
	if _registry == null or not _registry.has_method("export_creator_report"):
		_render_registry("Creator diagnostics are unavailable for this registry.")
		return
	var report_path := str(_registry.call("export_creator_report"))
	if report_path.is_empty():
		_render_registry("Could not write the creator diagnostics report.")
		return
	DisplayServer.clipboard_set(report_path)
	_render_registry("Exported creator report and copied its path: %s" % report_path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(title_scene_path)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190.0, 42.0)
	button.add_theme_font_size_override("font_size", 16)
	return button
