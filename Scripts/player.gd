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
@export var gravity_pull_radius: float = 1800.0
@export var max_gravity_sources: int = 4
@export var gravity_source_refresh_interval: float = 0.35

@export var slingshot_factor: float = 1.5
@export var recoil_instability: float = 0.0
@export var max_gravity_anchors: int = 1
@export var orbit_control_bonus: float = 0.0

@export var energy_cost_per_work: float = 0.00002
@export var minimum_thrust_energy_cost_per_second: float = 5.0
@export var gravity_charge_per_work: float = 0.0001

# ========================
# == STATE VARIABLES ==
# ========================

var current_max_speed: float = 800.0
var planets: Array = []

var DRAG_enabled = true
var can_dash = true
var last_thrust_release = 0.0

var shields_on = false
var shield_health = 10
var shield_component: Node = null
var powerup_inventory: PowerupInventory = null
var _gravity_refresh_elapsed = 0.0

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
	_refresh_gravity_sources(true)
	_bind_shield()
	_ensure_powerup_inventory()

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
	_gravity_refresh_elapsed += delta
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
	_refresh_gravity_sources(false)

	# Iterate backwards to safely remove nulls
	for i in range(planets.size() - 1, -1, -1):
		var p = planets[i]

		if not is_instance_valid(p):
			planets.remove_at(i)
			continue

		var offset = p.global_position - global_position
		var raw_dist = offset.length()
		var dist = max(raw_dist, min_grav_dist)
		if gravity_pull_radius > 0.0 and raw_dist > gravity_pull_radius:
			continue

		if raw_dist < closest_dist:
			closest_dist = raw_dist
			closest_planet = p

		if raw_dist > 0.001:
			var dir = offset / raw_dist
			var mass_value: Variant = p.get("mass")
			var mass_type = typeof(mass_value)
			var source_mass = float(mass_value) if mass_type == TYPE_FLOAT or mass_type == TYPE_INT else 100.0
			var strength = gravity_constant * source_mass / (dist * dist)
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
		velocity += tangent * accel_tangent * (slingshot_factor + orbit_control_bonus) * delta
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

	var scale = 0.0

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
	if powerup_inventory != null:
		powerup_inventory.trigger_player_action()
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
	var p = projectile_scene.instantiate() as RigidBody2D
	if not p:
		return
	var spawn_dir = -transform.x.normalized()
	p.global_position = global_position + spawn_dir * 70
	p.global_rotation = rotation
	
	# Add to current scene root to avoid local transform issues
	get_tree().current_scene.call_deferred("add_child", p)
	$BulletBlastSoundEffect.play()
	if p.has_method("launch"):
		p.call_deferred("launch", spawn_dir)
	else:
		p.call_deferred("apply_central_impulse", spawn_dir * 900)
	if recoil_instability > 0.0:
		velocity -= spawn_dir.rotated(randf_range(-0.22, 0.22)) * recoil_instability
	if powerup_inventory != null:
		powerup_inventory.trigger_player_action()


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
		var shield_text = ""
		if shield_component != null and shield_component.get("max_capacity") != null:
			shield_text = " | Shield: %d/%d" % [
				int(round(float(shield_component.get("current_energy")))),
				int(round(float(shield_component.get("max_capacity"))))
			]
		health_label.text = "Health: %s%s" % [health_component.current_health, shield_text]

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
		var target = (get_global_mouse_position() - global_position).normalized() * 180
		camera.offset = lerp(camera.offset, target, 0.05)


# ========================
# == SHIELDS ==
# ========================

func shield_process():
	if not is_instance_valid(shield_node):
		return

	if shield_component != null and shield_component.has_method("is_shield_active"):
		shields_on = bool(shield_component.call("is_shield_active"))

	shield_node.visible = shields_on

	# Using node variable directly if possible, or simple lookups
	var poly = shield_node.get_node_or_null("Polygon2D")
	var coll = shield_node.get_node_or_null("CollisionPolygon2D")

	if poly: poly.visible = shields_on
	if coll: coll.visible = shields_on


func take_damage(amount: float):
	var remaining = amount
	if shield_component != null and shield_component.has_method("take_shield_damage"):
		remaining = float(shield_component.call("take_shield_damage", amount))

	if remaining > 0.0 and health_component:
		health_component.take_damage(remaining)

func take_shield_damage(amount: float) -> float:
	if shield_component != null and shield_component.has_method("take_shield_damage"):
		return float(shield_component.call("take_shield_damage", amount))
	return amount

func restore_shield(amount: float) -> float:
	if shield_component != null and shield_component.has_method("restore_shield"):
		return float(shield_component.call("restore_shield", amount))
	return 0.0

func apply_shield_disruption(strength: float, duration: float) -> void:
	if shield_component != null and shield_component.has_method("apply_gravity_distortion"):
		shield_component.call("apply_gravity_distortion", strength, duration)

func is_shield_active() -> bool:
	if shield_component != null and shield_component.has_method("is_shield_active"):
		return bool(shield_component.call("is_shield_active"))
	return false

func _bind_shield() -> void:
	shield_component = shield_node
	if shield_component == null:
		return

	if shield_component.has_signal("shield_broken") and not shield_component.is_connected("shield_broken", Callable(self, "_on_shield_broken")):
		shield_component.connect("shield_broken", Callable(self, "_on_shield_broken"))
	if shield_component.has_signal("shield_hit") and not shield_component.is_connected("shield_hit", Callable(self, "_on_shield_hit")):
		shield_component.connect("shield_hit", Callable(self, "_on_shield_hit"))
	if shield_component.has_signal("shield_restored") and not shield_component.is_connected("shield_restored", Callable(self, "_on_shield_restored")):
		shield_component.connect("shield_restored", Callable(self, "_on_shield_restored"))

func _ensure_powerup_inventory() -> void:
	powerup_inventory = get_node_or_null("PowerupInventory") as PowerupInventory
	if powerup_inventory != null:
		return

	powerup_inventory = PowerupInventory.new()
	powerup_inventory.name = "PowerupInventory"
	add_child(powerup_inventory)

func _refresh_gravity_sources(force: bool) -> void:
	if not force and _gravity_refresh_elapsed < gravity_source_refresh_interval:
		return

	_gravity_refresh_elapsed = 0.0
	var seen = {}
	var sources: Array[Node] = []

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == self:
				continue
			var source_2d = source as Node2D
			if source_2d == null:
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			sources.append(source_2d)

	sources.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)

	if max_gravity_sources > 0 and sources.size() > max_gravity_sources:
		sources.resize(max_gravity_sources)

	planets = sources


# ========================
# == SIGNAL CALLBACKS ==
# ========================

func _on_health_component_died():
	call_deferred("_go_to_title")


func _go_to_title():
	get_tree().change_scene_to_file("res://Nodes/title_screen.tscn")


func _on_health_component_health_changed(current, _max):
	health_label.text = "Health: " + str(current)

func _on_shield_broken() -> void:
	shields_on = false

func _on_shield_hit(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	shields_on = is_shield_active()

func _on_shield_restored(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	shields_on = is_shield_active()
