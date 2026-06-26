extends Area2D
class_name AnomalyRiftPortal

signal portal_activated(rift_id: StringName, contract_id: StringName)

@export var rift_id: StringName = &"no_thrust_rift"
@export var contract_id: StringName = &""
@export var director_group_name: StringName = &"optional_challenge_director"
@export var player_group_name: StringName = &"Player"
@export var portal_radius: float = 72.0
@export var launch_scene_on_touch: bool = false
@export var require_confirm_action: bool = true
@export var confirm_action: StringName = &"Confirm"
@export var fallback_confirm_key: Key = KEY_E
@export var portal_color: Color = Color(0.42, 1.0, 0.9, 0.58)

var _player_inside: bool = false
var _ring: Line2D = null
var _label: Label = null


func _ready() -> void:
	add_to_group("anomaly_rift_portal")
	_build_collision()
	_build_visuals()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation += delta * (1.6 if _player_inside else 0.45)
	if _label != null:
		_label.visible = _player_inside
	if _player_inside and (not require_confirm_action or _confirm_pressed()):
		_activate()


func _activate() -> void:
	portal_activated.emit(rift_id, contract_id)
	var director := get_tree().get_first_node_in_group(director_group_name)
	if director != null:
		if launch_scene_on_touch and director.has_method("launch_rift_scene"):
			director.call("launch_rift_scene", rift_id, contract_id)
		elif director.has_method("enter_rift"):
			director.call("enter_rift", rift_id)


func _confirm_pressed() -> bool:
	if InputMap.has_action(confirm_action) and Input.is_action_just_pressed(confirm_action):
		return true
	return Input.is_key_pressed(fallback_confirm_key)


func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(player_group_name):
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if body != null and body.is_in_group(player_group_name):
		_player_inside = false


func _build_collision() -> void:
	var collision := get_node_or_null("AnomalyRiftPortalCollision") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "AnomalyRiftPortalCollision"
		add_child(collision)
	var circle := collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision.shape = circle
	circle.radius = portal_radius


func _build_visuals() -> void:
	if _ring == null:
		_ring = Line2D.new()
		_ring.name = "AnomalyRiftPortalRing"
		_ring.closed = true
		_ring.antialiased = true
		_ring.width = 3.0
		_ring.points = _circle_points(portal_radius, 64)
		add_child(_ring)
	_ring.default_color = portal_color
	_ring.z_index = 21
	if _label == null:
		_label = Label.new()
		_label.name = "AnomalyRiftPrompt"
		_label.text = "ENTER RIFT"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.position = Vector2(-96.0, -portal_radius - 34.0)
		_label.size = Vector2(192.0, 24.0)
		_label.add_theme_font_size_override("font_size", 14)
		add_child(_label)
	_label.modulate = Color(portal_color.r, portal_color.g, portal_color.b, 0.86)
	_label.visible = false


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
