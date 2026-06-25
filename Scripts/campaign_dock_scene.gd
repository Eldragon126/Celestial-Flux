extends Control
class_name CampaignDockScene

signal undock_requested

@export var panel_width: float = 760.0
@export var panel_height: float = 560.0
@export var backdrop_color: Color = Color(0.0, 0.0, 0.0, 0.74)
@export var panel_bg_color: Color = Color(0.006, 0.014, 0.028, 0.97)
@export var panel_border_color: Color = Color(0.36, 1.0, 0.78, 0.68)
@export var primary_text_color: Color = Color(0.66, 1.0, 0.92, 1.0)
@export var secondary_text_color: Color = Color(0.72, 0.9, 1.0, 0.92)
@export var warning_text_color: Color = Color(1.0, 0.72, 0.32, 1.0)
@export var affordable_button_color: Color = Color(0.02, 0.09, 0.09, 0.94)
@export var unaffordable_button_color: Color = Color(0.025, 0.03, 0.045, 0.82)
@export var button_border_color: Color = Color(0.32, 1.0, 0.86, 0.48)
@export var trade_button_font_size: int = 16
@export var trade_button_min_height: float = 48.0
@export var undock_button_min_height: float = 50.0
@export var fallback_home_planet_name: String = "HOME PLANET"

var campaign_director: Node = null
var mothership: Node = null

@onready var _backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
@onready var _panel: PanelContainer = get_node_or_null("Panel") as PanelContainer
@onready var _title_label: Label = find_child("DockTitleLabel", true, false) as Label
@onready var _status_label: Label = find_child("DockStatusLabel", true, false) as Label
@onready var _mother_label: Label = _find_home_planet_status_label()
@onready var _escort_label: Label = find_child("EscortStatusLabel", true, false) as Label
@onready var _buy_escort_button: Button = find_child("BuyEscortButton", true, false) as Button
@onready var _speed_button: Button = find_child("UpgradeSpeedButton", true, false) as Button
@onready var _damage_button: Button = find_child("UpgradeDamageButton", true, false) as Button
@onready var _armor_button: Button = find_child("UpgradeArmorButton", true, false) as Button
@onready var _slingshot_button: Button = find_child("UpgradeSlingshotButton", true, false) as Button
@onready var _hijack_button: Button = find_child("HijackButton", true, false) as Button
@onready var _undock_button: Button = find_child("UndockButton", true, false) as Button


func configure(director: Node, ship: Node) -> void:
	campaign_director = director
	mothership = ship
	refresh()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style_scene()
	_connect_buttons()
	refresh()
	if _buy_escort_button != null:
		_buy_escort_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu") or event.is_action_pressed("ui_cancel"):
		_request_undock()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if campaign_director == null or not is_instance_valid(campaign_director):
		return
	if not campaign_director.has_method("get_trade_snapshot"):
		return
	var snapshot_value: Variant = campaign_director.call("get_trade_snapshot", mothership)
	var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
	var costs_value: Variant = snapshot.get("costs", {})
	var costs: Dictionary = costs_value if costs_value is Dictionary else {}
	var credits := int(snapshot.get("credits", 0))
	if _title_label != null:
		_title_label.text = str(snapshot.get("dock_name", "MOTHERSHIP DOCK"))
	if _status_label != null:
		_status_label.text = "%s // ENERGY %d // WAVE %d/%d // RATE x%.2f" % [
			str(snapshot.get("directive_label", "SIMULATION HELD")),
			credits,
			int(snapshot.get("wave", 0)),
			int(snapshot.get("final_wave", 0)),
			float(snapshot.get("trade_multiplier", 1.0)),
		]
	if _mother_label != null:
		_mother_label.text = "%s %d%% // SHIELD %d%% // ROUTE %d%%" % [
			_home_planet_name(snapshot),
			int(round(float(snapshot.get("home_planet_health", snapshot.get("mother_health", 0.0))) * 100.0)),
			int(round(float(snapshot.get("home_planet_shield", snapshot.get("mother_shield", 0.0))) * 100.0)),
			int(round(float(snapshot.get("route_progress", 0.0)) / maxf(float(snapshot.get("route_goal", 1.0)), 1.0) * 100.0)),
		]
	if _escort_label != null:
		_escort_label.text = "ESCORTS %d/%d // DAMAGE x%.2f // FREEHOLD %.0f" % [
			int(snapshot.get("escorts", 0)),
			int(snapshot.get("max_escorts", 0)),
			float(snapshot.get("damage_multiplier", 1.0)),
			float(snapshot.get("freehold_reputation", 0.0)),
		]
	_configure_trade_button(_buy_escort_button, "BUY ESCORT", int(costs.get("escort", 0)), credits, bool(snapshot.get("can_buy_escort", true)))
	_configure_trade_button(_speed_button, "UPGRADE SPEED L%d" % (int(snapshot.get("speed_level", 0)) + 1), int(costs.get("speed", 0)), credits, true)
	_configure_trade_button(_damage_button, "UPGRADE DAMAGE L%d" % (int(snapshot.get("damage_level", 0)) + 1), int(costs.get("damage", 0)), credits, true)
	_configure_trade_button(_armor_button, "REPAIR + ARMOR L%d" % (int(snapshot.get("armor_level", 0)) + 1), int(costs.get("armor", 0)), credits, true)
	_configure_trade_button(_slingshot_button, "UPGRADE SLINGSHOT L%d" % (int(snapshot.get("slingshot_level", 0)) + 1), int(costs.get("slingshot", 0)), credits, true)
	_configure_trade_button(_hijack_button, "HIJACK BEACON", int(costs.get("hijack", 0)), credits, not bool(snapshot.get("pending_hijack", false)))


func _connect_buttons() -> void:
	_connect_button(_buy_escort_button, Callable(self, "_on_buy_escort_pressed"))
	_connect_button(_speed_button, Callable(self, "_on_speed_pressed"))
	_connect_button(_damage_button, Callable(self, "_on_damage_pressed"))
	_connect_button(_armor_button, Callable(self, "_on_armor_pressed"))
	_connect_button(_slingshot_button, Callable(self, "_on_slingshot_pressed"))
	_connect_button(_hijack_button, Callable(self, "_on_hijack_pressed"))
	_connect_button(_undock_button, Callable(self, "_request_undock"))


func _find_home_planet_status_label() -> Label:
	var label := find_child("HomePlanetStatusLabel", true, false) as Label
	if label != null:
		return label
	return find_child("MotherStatusLabel", true, false) as Label


func _home_planet_name(snapshot: Dictionary) -> String:
	var display_name := str(snapshot.get("home_planet_name", fallback_home_planet_name)).strip_edges().to_upper()
	return display_name if not display_name.is_empty() else "HOME PLANET"


func _connect_button(button: Button, callback: Callable) -> void:
	if button != null and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _configure_trade_button(button: Button, label: String, cost: int, credits: int, available: bool) -> void:
	if button == null:
		return
	button.text = "%s // %d EC" % [label, cost]
	button.disabled = not available or credits < cost
	var border := button_border_color if not button.disabled else Color(0.28, 0.34, 0.4, 0.36)
	var bg := affordable_button_color if not button.disabled else unaffordable_button_color
	button.add_theme_stylebox_override("normal", _make_style(bg, border, 1))
	button.add_theme_stylebox_override("disabled", _make_style(unaffordable_button_color, border, 1))


func _on_buy_escort_pressed() -> void:
	_call_trade_method("trade_buy_escort")


func _on_speed_pressed() -> void:
	_call_trade_method("trade_upgrade_speed")


func _on_damage_pressed() -> void:
	_call_trade_method("trade_upgrade_damage")


func _on_armor_pressed() -> void:
	_call_trade_method("trade_upgrade_armor")


func _on_slingshot_pressed() -> void:
	_call_trade_method("trade_upgrade_slingshot")


func _on_hijack_pressed() -> void:
	_call_trade_method("trade_prepare_hijack")


func _call_trade_method(method_name: String) -> void:
	if campaign_director == null or not is_instance_valid(campaign_director) or not campaign_director.has_method(method_name):
		return
	campaign_director.call(method_name)
	refresh()


func _request_undock() -> void:
	undock_requested.emit()
	if campaign_director != null and is_instance_valid(campaign_director) and campaign_director.has_method("request_dock_scene_close"):
		campaign_director.call("request_dock_scene_close")
	else:
		queue_free()


func _style_scene() -> void:
	if _backdrop != null:
		_backdrop.color = backdrop_color
	if _panel != null:
		_panel.custom_minimum_size = Vector2(panel_width, panel_height)
		_panel.add_theme_stylebox_override("panel", _make_style(panel_bg_color, panel_border_color, 2))
	for label in find_children("*", "Label", true, false):
		var typed_label := label as Label
		if typed_label != null:
			typed_label.modulate = secondary_text_color
			typed_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
			typed_label.add_theme_constant_override("outline_size", 4)
	if _title_label != null:
		_title_label.modulate = primary_text_color
	if _status_label != null:
		_status_label.modulate = warning_text_color
	for button in find_children("*", "Button", true, false):
		var typed_button := button as Button
		if typed_button != null:
			var button_size := typed_button.custom_minimum_size
			button_size.y = undock_button_min_height if typed_button == _undock_button else trade_button_min_height
			typed_button.custom_minimum_size = button_size
			typed_button.add_theme_font_size_override("font_size", trade_button_font_size)
			typed_button.add_theme_color_override("font_color", primary_text_color)
			typed_button.add_theme_color_override("font_disabled_color", Color(0.52, 0.64, 0.72, 0.7))
			typed_button.add_theme_stylebox_override("hover", _make_style(Color(0.02, 0.14, 0.13, 0.96), Color(0.62, 1.0, 0.9, 0.78), 1))
			typed_button.add_theme_stylebox_override("pressed", _make_style(Color(0.42, 1.0, 0.82, 0.96), Color(1.0, 0.92, 0.42, 0.9), 1))


func _make_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
