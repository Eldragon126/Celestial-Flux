extends Control

const SECRET_ENEMY_GROUPS: Array[StringName] = [&"wave_enemy", &"enemies", &"ParametricEnemies"]
const TITLE_TRACK_ORBITAL_DRIFT := preload("res://Assets/Songs/Orbital Drift.mp3")
const TITLE_TRACK_DARK_PULSE := preload("res://Assets/Songs/Title Screen New.mp3")

@export var version_string: String = "v1.0.4.6"
@export var secret_completion_check_interval: float = 0.25
@export var alternate_title_music: bool = true
@export var use_brand_logo_texture: bool = false
@export var logo_texture_path: String = "res://Assets/Brand/vector_anomaly_epic_logo_generated.png"

@export_group("Multiplayer")
@export var multiplayer_default_port: int = 28942
@export var multiplayer_max_peers: int = 4

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var _starfield_backdrop: ColorRect = get_node_or_null("StarfieldBackdrop") as ColorRect
@onready var _version_label: Label = get_node_or_null("VersionLabel") as Label
@onready var _title_label: Label = get_node_or_null("CenterContainer/Label") as Label
@onready var _title_logo: TextureRect = get_node_or_null("CenterContainer/TitleLogo") as TextureRect

var _secret_mode_active := false
var _secret_completion_announced := false
var _secret_completion_elapsed := 0.0
var _dark_title_variant := false
var _multiplayer_button: Button = null
var _mp_panel: PanelContainer = null
var _mp_status_label: Label = null
var _mp_name_edit: LineEdit = null
var _mp_address_edit: LineEdit = null
var _mp_port_spin: SpinBox = null
var _mp_host_button: Button = null
var _mp_join_button: Button = null
var _mp_stop_button: Button = null
var _mp_steam_button: Button = null


func _ready() -> void:
	$Menu/NewRunButton.grab_focus()
	if not RunProgress:
		push_error("RunProgress autoload not found!")
		return

	if audio_player:
		_configure_title_music()
		var finished_callable := Callable(self, "_on_audio_stream_player_finished")
		if not audio_player.finished.is_connected(finished_callable):
			audio_player.finished.connect(finished_callable, CONNECT_ONE_SHOT)

	_update_button_visibility()
	_update_version_label()
	_apply_title_brand()
	_build_multiplayer_ui()
	_connect_network_session()
	_update_multiplayer_ui()


func _physics_process(delta: float) -> void:
	if not _secret_mode_active or _secret_completion_announced:
		return

	_secret_completion_elapsed += delta
	if _secret_completion_elapsed < secret_completion_check_interval:
		return
	_secret_completion_elapsed = 0.0

	if _secret_enemy_groups_empty():
		_announce_secret_completed()


func _on_audio_stream_player_finished() -> void:
	if animation_player:
		animation_player.pause()


func _process(_delta: float) -> void:
	if _starfield_backdrop != null and _starfield_backdrop.material != null:
		_starfield_backdrop.material.set_shader_parameter("real_time", Time.get_ticks_msec() / 1000.0)
	_update_dark_title_pulse()
	if Input.is_action_just_pressed("Confirm") and Input.is_key_pressed(KEY_SHIFT):
		if RunProgress.has_anchor:
			_begin_continue()


func _configure_title_music() -> void:
	_dark_title_variant = alternate_title_music and (int(Time.get_ticks_msec() / 1000) % 2 == 1)
	audio_player.stop()
	audio_player.stream = TITLE_TRACK_DARK_PULSE if _dark_title_variant else TITLE_TRACK_ORBITAL_DRIFT
	audio_player.play()
	if animation_player == null:
		return
	if _dark_title_variant:
		animation_player.stop()
		if _title_label != null:
			_title_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 0.74))
	else:
		animation_player.play("ColorShift")


func _update_dark_title_pulse() -> void:
	if not _dark_title_variant:
		return
	var pulse := 0.62 + 0.18 * sin(Time.get_ticks_msec() / 1000.0 * 1.35)
	if _title_label != null and _title_label.visible:
		_title_label.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0, pulse))
	if _title_logo != null and _title_logo.visible:
		_title_logo.modulate = Color(0.72, 0.94, 1.0, pulse + 0.12)


func _on_new_run_button_pressed() -> void:
	if NetworkSession != null:
		NetworkSession.leave_session()
	_begin_new_run(false)


func _on_tutorial_button_pressed() -> void:
	if NetworkSession != null:
		NetworkSession.leave_session()
	RunProgress.begin_new_run(false)
	get_tree().change_scene_to_file("res://Nodes/playable_tutorial.tscn")


func _on_continue_button_pressed() -> void:
	if NetworkSession != null:
		NetworkSession.leave_session()
	_begin_continue()


func _on_challenge_button_pressed() -> void:
	if NetworkSession != null:
		NetworkSession.leave_session()
	_begin_new_run(true)


func _on_boss_rush_button_pressed() -> void:
	if NetworkSession != null:
		NetworkSession.leave_session()
	RunProgress.begin_boss_rush()
	get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_new_run(use_challenge: bool = false) -> void:
	RunProgress.begin_new_run(use_challenge)
	get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_continue() -> void:
	if RunProgress.has_anchor and RunProgress.load_anchor():
		get_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")
	else:
		_begin_new_run(false)


func _update_button_visibility() -> void:
	var continue_btn := get_node_or_null("Menu/ContinueButton") as Button
	if continue_btn:
		continue_btn.visible = RunProgress.has_anchor
		continue_btn.disabled = not RunProgress.has_anchor


func _update_version_label() -> void:
	if _version_label == null:
		return
	var project_version := String(ProjectSettings.get_setting("application/config/version", ""))
	_version_label.text = project_version if not project_version.is_empty() else version_string


func _apply_title_brand() -> void:
	if not use_brand_logo_texture:
		return
	var texture := _load_title_texture(logo_texture_path)
	if texture == null:
		return
	if _title_logo == null:
		var parent := get_node_or_null("CenterContainer")
		if parent == null:
			return
		_title_logo = TextureRect.new()
		_title_logo.name = "TitleLogo"
		_title_logo.custom_minimum_size = Vector2(860.0, 270.0)
		_title_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(_title_logo)
	_title_logo.texture = texture
	_title_logo.visible = true
	if _title_label != null:
		_title_label.visible = false


func _build_multiplayer_ui() -> void:
	_ensure_multiplayer_button()
	_ensure_multiplayer_panel()


func _ensure_multiplayer_button() -> void:
	var menu := get_node_or_null("Menu") as VBoxContainer
	if menu == null:
		return
	_multiplayer_button = menu.get_node_or_null("MultiplayerButton") as Button
	if _multiplayer_button == null:
		_multiplayer_button = Button.new()
		_multiplayer_button.name = "MultiplayerButton"
		_multiplayer_button.text = "Multiplayer"
		_multiplayer_button.custom_minimum_size = Vector2(420.0, 0.0)
		menu.add_child(_multiplayer_button)
		menu.move_child(_multiplayer_button, mini(2, menu.get_child_count() - 1))
	_copy_button_font(_multiplayer_button, get_node_or_null("Menu/NewRunButton") as Button)
	if not _multiplayer_button.pressed.is_connected(_on_multiplayer_button_pressed):
		_multiplayer_button.pressed.connect(_on_multiplayer_button_pressed)


func _ensure_multiplayer_panel() -> void:
	_mp_panel = get_node_or_null("MultiplayerPanel") as PanelContainer
	if _mp_panel != null:
		return

	_mp_panel = PanelContainer.new()
	_mp_panel.name = "MultiplayerPanel"
	_mp_panel.visible = false
	_mp_panel.anchor_left = 1.0
	_mp_panel.anchor_right = 1.0
	_mp_panel.anchor_top = 0.5
	_mp_panel.anchor_bottom = 0.5
	_mp_panel.offset_left = -650.0
	_mp_panel.offset_right = -44.0
	_mp_panel.offset_top = -290.0
	_mp_panel.offset_bottom = 290.0
	_mp_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.01, 0.018, 0.035, 0.92), Color(0.0, 0.86, 1.0, 0.5))
	)
	add_child(_mp_panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 12)
	_mp_panel.add_child(rows)

	var title := _make_label("NETWORK VECTOR", 28, Color(0.62, 1.0, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	rows.add_child(title)

	_mp_status_label = _make_label("OFFLINE", 15, Color(0.68, 0.9, 1.0, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	_mp_status_label.custom_minimum_size = Vector2(540.0, 44.0)
	_mp_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_mp_status_label)

	_mp_name_edit = _make_line_edit("VECTOR", "CALLSIGN")
	rows.add_child(_make_field_row("CALLSIGN", _mp_name_edit))

	_mp_address_edit = _make_line_edit("127.0.0.1", "HOST IP")
	rows.add_child(_make_field_row("HOST IP", _mp_address_edit))

	_mp_port_spin = SpinBox.new()
	_mp_port_spin.min_value = 1.0
	_mp_port_spin.max_value = 65535.0
	_mp_port_spin.step = 1.0
	_mp_port_spin.value = multiplayer_default_port
	_mp_port_spin.custom_minimum_size = Vector2(260.0, 42.0)
	rows.add_child(_make_field_row("PORT", _mp_port_spin))

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.add_theme_constant_override("separation", 10)
	rows.add_child(action_row)

	_mp_host_button = _make_action_button("HOST + PLAY")
	_mp_join_button = _make_action_button("JOIN IP")
	action_row.add_child(_mp_host_button)
	action_row.add_child(_mp_join_button)

	var secondary_row := HBoxContainer.new()
	secondary_row.name = "SecondaryRow"
	secondary_row.add_theme_constant_override("separation", 10)
	rows.add_child(secondary_row)

	_mp_stop_button = _make_action_button("DROP LINK")
	_mp_steam_button = _make_action_button("STEAM")
	secondary_row.add_child(_mp_stop_button)
	secondary_row.add_child(_mp_steam_button)

	var close_button := _make_action_button("CLOSE")
	rows.add_child(close_button)

	_mp_host_button.pressed.connect(_on_multiplayer_host_pressed)
	_mp_join_button.pressed.connect(_on_multiplayer_join_pressed)
	_mp_stop_button.pressed.connect(_on_multiplayer_stop_pressed)
	_mp_steam_button.pressed.connect(_on_multiplayer_steam_pressed)
	close_button.pressed.connect(_on_multiplayer_close_pressed)


func _connect_network_session() -> void:
	if NetworkSession == null:
		return
	if not NetworkSession.session_status_changed.is_connected(_on_network_status_changed):
		NetworkSession.session_status_changed.connect(_on_network_status_changed)
	if not NetworkSession.peer_roster_changed.is_connected(_on_network_roster_changed):
		NetworkSession.peer_roster_changed.connect(_on_network_roster_changed)
	if not NetworkSession.session_error.is_connected(_on_network_error):
		NetworkSession.session_error.connect(_on_network_error)


func _update_multiplayer_ui() -> void:
	if _mp_status_label == null or NetworkSession == null:
		return
	var status: Dictionary = NetworkSession.get_status_snapshot()
	var mode_label := String(status.get("mode_label", "OFFLINE"))
	var peer_count := int(status.get("peer_count", 1))
	var port := int(status.get("port", multiplayer_default_port))
	var hint := String(status.get("lan_hint", "127.0.0.1"))
	var error := String(status.get("error", ""))
	var steam_message := String(status.get("steam_message", "STEAM NEEDS PLUGIN"))
	if _mp_address_edit != null and _mp_address_edit.text.strip_edges().is_empty():
		_mp_address_edit.text = hint
	var status_text := "%s | P%d | %s:%d" % [mode_label, peer_count, hint, port]
	if not error.is_empty() and mode_label == "OFFLINE":
		status_text = error
	_mp_status_label.text = "%s\n%s" % [status_text, steam_message]

	var active := bool(status.get("active", false))
	if _mp_host_button != null:
		_mp_host_button.disabled = active
	if _mp_join_button != null:
		_mp_join_button.disabled = active
	if _mp_stop_button != null:
		_mp_stop_button.disabled = not active
	if _mp_steam_button != null:
		_mp_steam_button.text = "STEAM READY" if bool(status.get("steam_available", false)) else "STEAM NEEDS PLUGIN"


func _on_multiplayer_button_pressed() -> void:
	if _mp_panel == null:
		return
	_mp_panel.visible = not _mp_panel.visible
	if _mp_panel.visible:
		if _mp_address_edit != null and NetworkSession != null:
			_mp_address_edit.text = NetworkSession.get_lan_address_hint()
		if _mp_name_edit != null:
			_mp_name_edit.grab_focus()
	_update_multiplayer_ui()


func _on_multiplayer_host_pressed() -> void:
	if NetworkSession == null:
		return
	var player_name := _mp_name_edit.text if _mp_name_edit != null else "VECTOR"
	var port := int(_mp_port_spin.value) if _mp_port_spin != null else multiplayer_default_port
	NetworkSession.host_and_play(player_name, port, multiplayer_max_peers)
	_update_multiplayer_ui()


func _on_multiplayer_join_pressed() -> void:
	if NetworkSession == null:
		return
	var player_name := _mp_name_edit.text if _mp_name_edit != null else "VECTOR"
	var address := _mp_address_edit.text if _mp_address_edit != null else "127.0.0.1"
	var port := int(_mp_port_spin.value) if _mp_port_spin != null else multiplayer_default_port
	NetworkSession.join_lan_game(address, port, player_name)
	_update_multiplayer_ui()


func _on_multiplayer_stop_pressed() -> void:
	if NetworkSession != null:
		NetworkSession.leave_session()
	_update_multiplayer_ui()


func _on_multiplayer_steam_pressed() -> void:
	if _mp_status_label == null or NetworkSession == null:
		return
	_mp_status_label.text = NetworkSession.get_steam_support_message()


func _on_multiplayer_close_pressed() -> void:
	if _mp_panel != null:
		_mp_panel.visible = false


func _on_network_status_changed(_status: Dictionary) -> void:
	_update_multiplayer_ui()


func _on_network_roster_changed(_roster: Array) -> void:
	_update_multiplayer_ui()


func _on_network_error(message: String) -> void:
	if _mp_panel != null:
		_mp_panel.visible = true
	if _mp_status_label != null:
		_mp_status_label.text = message
	_update_multiplayer_ui()


func _make_field_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sRow" % label_text.capitalize().replace(" ", "")
	row.add_theme_constant_override("separation", 10)
	var label := _make_label(label_text, 14, Color(0.56, 0.88, 0.96, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(130.0, 42.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _make_label(text: String, size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	label.horizontal_alignment = alignment
	return label


func _make_line_edit(text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(360.0, 42.0)
	edit.add_theme_font_size_override("font_size", 17)
	return edit


func _make_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.015, 0.08, 0.12, 0.88), Color(0.0, 0.78, 1.0, 0.44)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.02, 0.13, 0.19, 0.94), Color(0.32, 1.0, 0.96, 0.72)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.0, 0.2, 0.26, 1.0), Color(0.78, 1.0, 0.38, 0.88)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.025, 0.03, 0.045, 0.7), Color(0.26, 0.34, 0.38, 0.36)))
	return button


func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style


func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _copy_button_font(target: Button, source: Button) -> void:
	if target == null or source == null:
		return
	var font := source.get_theme_font("font")
	if font != null:
		target.add_theme_font_override("font", font)
	target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))


func _load_title_texture(path: String) -> Texture2D:
	var imported_texture := load(path) as Texture2D
	if imported_texture != null:
		return imported_texture
	if not path.begins_with("res://"):
		return null
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _on_secret_button_pressed() -> void:
	if get_tree().get_first_node_in_group("Player") != null:
		_secret_mode_active = true
		return

	var player := preload("res://Nodes/player.tscn")
	var instance := player.instantiate() as Node2D
	if instance == null:
		return

	instance.global_position = $CenterContainer/Label.global_position
	get_tree().current_scene.call_deferred("add_child", instance)
	RunProgress.begin_new_run(false)
	_secret_mode_active = true
	_secret_completion_announced = false
	_secret_completion_elapsed = 0.0


func _secret_enemy_groups_empty() -> bool:
	for group_name in SECRET_ENEMY_GROUPS:
		if get_tree().get_first_node_in_group(group_name) != null:
			return false
	return true


func _announce_secret_completed() -> void:
	_secret_completion_announced = true
	_secret_mode_active = false
	if audio_player != null:
		audio_player.stop()
	var secret_player := get_node_or_null("SecretCompleted") as AudioStreamPlayer
	if secret_player != null and not secret_player.playing:
		secret_player.play()
	var title_label := get_node_or_null("CenterContainer/Label") as Label
	if title_label != null:
		if _title_logo != null:
			_title_logo.visible = false
		title_label.visible = true
		title_label.text = "SECRET COMPLETED"
