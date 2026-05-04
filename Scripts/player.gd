extends CharacterBody2D

# ========================
# == EXPORT VARIABLES ==
# ========================

@export var thrust_power: float = 4000.0
@export var rotation_speed: float = 9.0
@export var max_speed: float = 1000.0
@export var drag: float = 0.97
@export var idle_drag: float = 0.9

@export var gravity_constant: float = 400.0
@export var min_grav_dist: float = 50.0

@export var slingshot_factor: float = 1.5

@export var energy_cost_per_work: float = 0.00002
@export var minimum_thrust_energy_cost_per_second: float = 5.0
@export var gravity_charge_per_work: float = 0.00001

# ========================
# == STATE VARIABLES ==
# ========================

var current_max_speed: float = 800.0
var planets: Array = []

var DRAG_enabled := true
var can_dash := true
var last_thrust_release := 0.0

var shields_on := false
var shield_health := 10

var closest_planet: Node = null
var closest_dist: float = INF

# ========================
# == NODE REFERENCES ==
# ========================

@onready var camera = $Camera2D
@onready var drag_label = $CanvasLayer/Drag
@onready var health_label = $CanvasLayer/Health
@onready var energy_label = $CanvasLayer/Energy
@onready var shield_node = $Shield
@onready var dash_timer = $Dash
@onready var energy_component = $EnergyComponent
# Cached HealthComponent to save performance
@onready var health_component = get_node_or_null("HealthComponent")

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
	var gravity = calculate_gravity()

	handle_rotation(delta)

	# 1. Apply forces
	apply_thrust(delta)
	apply_slingshot(gravity, delta)
	apply_gravity(gravity, delta)

	# 2. Movement & resistance
	apply_drag(gravity, delta)

	# 3. Constraints
	clamp_velocity()
	move_and_slide()

	# 4. Energy reactions
	apply_gravity_recharge(gravity, delta)

	handle_input()
	update_ui()


# ========================
# == GRAVITY SYSTEM ==
# ========================

func calculate_gravity() -> Vector2:
	var total = Vector2.ZERO
	closest_dist = INF
	closest_planet = null

	# Iterate backwards to safely remove nulls
	for i in range(planets.size() - 1, -1, -1):
		var p = planets[i]

		if not is_instance_valid(p):
			planets.remove_at(i)
			continue

		var offset = p.global_position - global_position
		var raw_dist = offset.length()
		var dist = max(raw_dist, min_grav_dist)

		if raw_dist < closest_dist:
			closest_dist = raw_dist
			closest_planet = p

		if raw_dist > 0.001:
			var dir = offset / raw_dist
			var strength = gravity_constant * p.mass / (dist * dist)
			total += dir * strength

	return total


# ========================
# == ROTATION ==
# ========================

func handle_rotation(delta):
	var input = Input.get_axis("rotate_ccw", "rotate_cw")

	if Settings.input_type:
		rotation += input * rotation_speed * delta
	else:
		rotation = (global_position - get_global_mouse_position()).angle()

	# orbital alignment assist
	if is_instance_valid(closest_planet) and Settings.input_type:
		var radial = (global_position - closest_planet.global_position).normalized()
		var tangent = Vector2(-radial.y, radial.x)

		if velocity.dot(tangent) < 0:
			tangent = -tangent

		var target = tangent.angle()
		rotation = lerp_angle(rotation, target, 0.08)


# ========================
# == SLINGSHOT SYSTEM ==
# ========================

func apply_slingshot(gravity: Vector2, delta: float):
	if not is_instance_valid(closest_planet):
		return
	if velocity.length() < 1.0:
		return
	if closest_dist > 500.0 or closest_dist < 70.0:
		return

	var grav_dir = gravity.normalized()
	var tangent = grav_dir.orthogonal()

	if tangent.dot(velocity) < 0:
		tangent = -tangent

	var accel_tangent = gravity.dot(velocity.normalized())

	if accel_tangent > 0 and DRAG_enabled:
		velocity += tangent * accel_tangent * slingshot_factor * delta
		current_max_speed = lerp(current_max_speed, max_speed + accel_tangent, 0.1)
	else:
		current_max_speed = lerp(current_max_speed, max_speed, 0.05)


# ========================
# == MOVEMENT ==
# ========================

func apply_thrust(delta):
	if not Input.is_action_pressed("thrust"):
		return

	var dir = -transform.x.normalized()
	var force = dir * thrust_power

	var predicted_velocity = velocity + force * delta
	var displacement = ((velocity + predicted_velocity) * 0.5) * delta

	var work = absf(force.dot(displacement))
	var energy_cost = max(work * energy_cost_per_work,
		minimum_thrust_energy_cost_per_second * delta)

	var scale := 0.0

	if energy_component:
		var spent = energy_component.spend(energy_cost)
		scale = clamp(spent / energy_cost, 0.0, 1.0)

	if scale > 0.0:
		velocity += force * scale * delta


func apply_gravity(gravity: Vector2, delta: float):
	velocity += gravity * delta


# ========================
# == ENERGY REGEN ==
# ========================

func apply_gravity_recharge(gravity: Vector2, delta: float):
	if energy_component == null:
		return

	var displacement = velocity * delta
	var work = gravity.dot(displacement)

	if work > 0.0:
		energy_component.restore(work * gravity_charge_per_work)


# ========================
# == DRAG ==
# ========================

func apply_drag(gravity, delta: float):
	if not DRAG_enabled or velocity.length() < 1: # Added a movement threshold
		return

	var coeff = drag if Input.is_action_pressed("thrust") else idle_drag
	
	var old_v = velocity
	velocity *= pow(coeff, delta * 60.0)
	
	var energy_loss = 0.0
	# Only drain energy if the drag coefficient is active and we are moving
	if coeff < 0.95:
	# Only calculate loss if we are moving significantly faster than the local gravity pull
		if velocity.length() > gravity.length() + 20:
			energy_loss = (old_v.length() - velocity.length()) * 0.01
	
	if energy_component and energy_loss > 0.0001: # Added a tiny buffer
		energy_component.spend(energy_loss)


# ========================
# == CONSTRAINTS ==
# ========================

func clamp_velocity():
	velocity = velocity.limit_length(current_max_speed)


# ========================
# == DASH ==
# ========================

func boost(dir):
	velocity += dir * 2000.0 # Adjusted for safer physics
	DRAG_enabled = false
	current_max_speed = 3000.0
	can_dash = false
	energy_component.spend(10)
	await get_tree().create_timer(0.3).timeout
	
	if is_instance_valid(dash_timer):
		dash_timer.start()
	
	DRAG_enabled = true
	current_max_speed = 800.0


func _on_dash_timeout():
	can_dash = true


# ========================
# == SHOOTING ==
# ========================

func shoot():
	var p = projectile_scene.instantiate()
	var spawn_dir = -transform.x.normalized()
	p.global_position = global_position + spawn_dir * 70
	
	# Add to current scene root to avoid local transform issues
	get_tree().current_scene.add_child(p)
	$BulletBlastSoundEffect.play()
	if p.has_method("apply_impulse"):
		p.apply_impulse(spawn_dir * 900)


# ========================
# == INPUT / UI ==
# ========================

func handle_input():
	if Input.is_action_just_pressed("shoot"):
		shoot()

	if Input.is_action_just_released("Toggle"):
		DRAG_enabled = !DRAG_enabled
		
	# Dash logic decoupled from thrust function
	if Input.is_action_just_released("thrust"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_thrust_release < 0.35 and can_dash:
			boost(-transform.x.normalized())
		last_thrust_release = now


func update_ui():
	drag_label.text = "Drag: " + ("Enabled" if DRAG_enabled else "Disabled")

	if health_component:
		health_label.text = "Health: %s" % health_component.current_health

	if energy_component:
		energy_label.text = "Energy: %d/%d" % [
			int(round(energy_component.current_energy)),
			int(round(energy_component.max_energy))
		]


# ========================
# == PROCESS ==
# ========================

func _process(delta):
	update_camera()
	shield_process()


func update_camera():
	if Settings.input_type == false:
		var target = (get_global_mouse_position() - global_position).normalized() * 200
		camera.offset = lerp(camera.offset, target, 0.05)


# ========================
# == SHIELDS ==
# ========================

func shield_process():
	if not is_instance_valid(shield_node):
		return

	shield_node.visible = shields_on

	# Using node variable directly if possible, or simple lookups
	var poly = shield_node.get_node_or_null("Polygon2D")
	var coll = shield_node.get_node_or_null("CollisionPolygon2D")

	if poly: poly.visible = shields_on
	if coll: coll.visible = shields_on


func take_damage(amount: float):
	if shields_on and shield_health > 0:
		shield_health -= 1

		if shield_node and shield_node.has_method("hit"):
			shield_node.hit()

		if shield_health <= 0:
			shields_on = false
	else:
		if health_component:
			health_component.take_damage(amount)


# ========================
# == SIGNAL CALLBACKS ==
# ========================

func _on_health_component_died():
	call_deferred("_go_to_title")


func _go_to_title():
	get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")


func _on_health_component_health_changed(current, _max):
	health_label.text = "Health: " + str(current)
