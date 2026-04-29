extends CharacterBody2D

# ========================
# == EXPORT VARIABLES ==
# ========================

@export var thrust_power: float = 4000.0
@export var rotation_speed: float = 10.0
@export var max_speed: float = 1000.0
@export var drag: float = 0.98

@export var gravity_constant: float = 300.0
@export var min_grav_dist: float = 50.0

@export var slingshot_factor: float = 1.5

# ========================
# == STATE VARIABLES ==
# ========================

var current_max_speed: float = 800.0
var planets: Array = []

var DRAG_enabled := true
var can_dash := true

var last_thrust_release := 0.0

# Shield
var shields_on := false
var shield_health := 10

# Cached per-frame
var closest_planet: Node = null
var closest_dist: float = INF

# ========================
# == NODE REFERENCES ==
# ========================

@onready var camera = $Camera2D
@onready var drag_label = $CanvasLayer/Drag
@onready var health_label = $CanvasLayer/Health
@onready var shield_node = $Shield
@onready var dash_timer = $Dash

@onready var projectile_scene = preload("res://Nodes/projectile.tscn")

# ========================
# == READY ==
# ========================

func _ready():
	planets = get_tree().get_nodes_in_group("planets")

	if Settings.input_type == false:
		camera.ignore_rotation = true
		camera.rotation_degrees = 0
	else:
		camera.ignore_rotation = false
		camera.rotation_degrees = 270

# ========================
# == PHYSICS LOOP ==
# ========================

func _physics_process(delta: float):
	var grav_accel = calculate_gravity()

	handle_rotation(delta)
	apply_slingshot(delta, grav_accel)

	apply_thrust(delta)
	apply_gravity(grav_accel, delta)
	apply_drag(delta)

	clamp_velocity()
	move_and_slide()

	handle_input()
	update_ui()

# ========================
# == GRAVITY SYSTEM ==
# ========================

func calculate_gravity() -> Vector2:
	var grav_accel = Vector2.ZERO
	closest_dist = INF
	closest_planet = null

	for planet in planets:
		var offset = planet.global_position - global_position
		var dist = max(offset.length(), min_grav_dist)

		if dist < closest_dist:
			closest_dist = dist
			closest_planet = planet

		var dir = offset / dist
		var strength = gravity_constant * planet.mass / (dist * dist)

		grav_accel += dir * strength

	return grav_accel

# ========================
# == ROTATION ==
# ========================

func handle_rotation(delta):
	var rot_input = Input.get_axis("rotate_ccw", "rotate_cw")

	if Settings.input_type:
		rotation += rot_input * rotation_speed * delta
	else:
		rotation = (global_position - get_global_mouse_position()).angle()

	# Auto-align to orbit tangent
	if closest_planet != null and Settings.input_type:
		var radial = (global_position - closest_planet.global_position).normalized()
		var tangent = Vector2(-radial.y, radial.x)

		if velocity.dot(tangent) < 0:
			tangent = -tangent

		var target_angle = tangent.angle()
		rotation = lerp_angle(rotation, target_angle, 0.1)

# ========================
# == SLINGSHOT SYSTEM ==
# ========================

func apply_slingshot(delta, grav_accel):
	if closest_planet == null:
		return
	if velocity.length() == 0:
		return
	if closest_dist > 500 or closest_dist < 50:
		return

	var grav_dir = grav_accel.normalized()
	var tangent = grav_dir.orthogonal()

	if tangent.dot(velocity) < 0:
		tangent = -tangent

	var a_t = grav_accel.dot(velocity.normalized())

	if a_t > 0 and DRAG_enabled:
		velocity += tangent * (a_t * slingshot_factor) * delta
		current_max_speed = lerp(current_max_speed, max_speed + a_t, 0.1)
	else:
		current_max_speed = lerp(current_max_speed, max_speed, 0.05)

# ========================
# == MOVEMENT ==
# ========================

func apply_thrust(delta):
	if Input.is_action_pressed("thrust"):
		var thrust_dir = -transform.x.normalized()
		velocity += thrust_dir * thrust_power * delta

	if Input.is_action_just_released("thrust"):
		var now = Time.get_ticks_msec() / 1000.0

		if now - last_thrust_release < 0.5 and can_dash:
			boost(-transform.x.normalized())

		last_thrust_release = now

func apply_gravity(grav_accel, delta):
	velocity += grav_accel * delta

func apply_drag(delta):
	if DRAG_enabled:
		velocity *= pow(drag, delta * 60.0)

func clamp_velocity():
	velocity = velocity.limit_length(current_max_speed)

# ========================
# == DASH ==
# ========================

func boost(direction):
	velocity += direction * 100000
	DRAG_enabled = false
	current_max_speed = 3000.0
	can_dash = false

	await get_tree().create_timer(0.3).timeout

	dash_timer.start()
	DRAG_enabled = true
	current_max_speed = 800.0

func _on_dash_timeout():
	can_dash = true

# ========================
# == SHOOTING ==
# ========================

func shoot():
	if Input.is_action_just_pressed("shoot"):
		var projectile = projectile_scene.instantiate()

		projectile.global_position = global_position + -transform.x.normalized() * 70
		projectile.apply_impulse(-transform.x.normalized() * 900)

		get_parent().add_child(projectile)

# ========================
# == INPUT / UI ==
# ========================

func handle_input():
	shoot()

	if Input.is_action_just_released("Toggle"):
		DRAG_enabled = !DRAG_enabled

func update_ui():
	drag_label.text = "Drag: Enabled" if DRAG_enabled else "Drag: Disabled"
	health_label.text = "Health: " + str($HealthComponent.current_health)

# ========================
# == PROCESS LOOP ==
# ========================

func _process(delta):
	update_camera()
	shield_process()

func update_camera():
	if Settings.input_type == false:
		var mouse_offset = (get_global_mouse_position() - global_position).normalized() * 200
		camera.offset = lerp(camera.offset, mouse_offset, 0.01)

# ========================
# == SHIELDS ==
# ========================

func shield_process():
	shield_node.visible = shields_on
	shield_node.get_node("Polygon2D").visible = shields_on
	shield_node.get_node("CollisionPolygon2D").visible = shields_on

func take_damage(amount: float):
	if shields_on and shield_health > 0:
		shield_health -= 1

		if has_node("Shield"):
			shield_node.hit()

		if shield_health <= 0:
			shields_on = false
			print("Shields depleted!")
	else:
		if has_node("HealthComponent"):
			$HealthComponent.take_damage(amount)

# ========================
# == HEALTH SIGNALS ==
# ========================

func _on_health_component_died():
	print("Player Died!")
	call_deferred("_go_to_title")
func _go_to_title():
	get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")
	
func _on_health_component_health_changed(current_health, max_health):
	health_label.text = "Health: " + str(current_health)
