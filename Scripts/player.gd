# Player Controller with Improved Slingshot Mechanics
extends CharacterBody2D

signal slingshot_assist_applied(source: Node, gravity: Vector2, impulse: Vector2, assist_strength: float, speed: float)
signal slingshot_mastery_scored(data: Dictionary)
signal slingshot_window_changed(data: Dictionary)
signal momentum_projectile_spawned(projectile: Node, direction: Vector2)
signal death_lesson_generated(lesson: String)

# ========================
# == EXPORT VARIABLES ==
# ========================

@export var thrust_power: float = 4000.0
@export var rotation_speed: float = 9.0
@export var orbit_alignment_assist_strength: float = 0.08
@export var max_speed: float = 1000.0
@export var drag: float = 0.97
@export var idle_drag: float = 0.9
@export var drag_disabled_speed_multiplier: float = 1.34
@export var dash_speed_cap: float = 2300.0
@export var absolute_velocity_cap: float = 2800.0
@export var high_speed_thrust_falloff_start: float = 0.86
@export var counter_thrust_control_bonus: float = 0.32
@export var lateral_thrust_control_bonus: float = 0.18

@export var gravity_constant: float = 400.0
@export var min_grav_dist: float = 50.0
@export var gravity_pull_radius: float = 1800.0
@export var max_gravity_sources: int = 4
@export var gravity_source_refresh_interval: float = 0.35

@export var slingshot_factor: float = 1.5
@export var slingshot_max_impulse: float = 800.0
@export var slingshot_speed_cap: float = 2500.0
@export var slingshot_cooldown: float = 0.1
@export var slingshot_min_tangential_speed: float = 210.0
@export var slingshot_gravity_boost_scale: float = 2.8
@export var slingshot_sweet_spot_distance: float = 265.0
@export var slingshot_sweet_spot_width: float = 150.0
@export var slingshot_perfect_score: float = 0.82
@export var slingshot_apex_score: float = 0.94
@export var slingshot_mastery_cap_bonus: float = 270.0
@export var slingshot_camera_kick: float = 20.0
@export var slingshot_camera_roll: float = 0.035
@export var recoil_instability: float = 0.0
@export var max_gravity_anchors: int = 1
@export var orbit_control_bonus: float = 0.0

@export var energy_cost_per_work: float = 0.00001
@export var minimum_thrust_energy_cost_per_second: float = 5.0
@export var gravity_charge_per_work: float = 0.0001

# ========================
# == STATE VARIABLES ==
# ========================

var current_max_speed: float = 800.0
var planets: Array = []

var DRAG_enabled = true
var drag_enabled_by_player = true
var _dash_drag_suppressed = false
var can_dash = true

var last_thrust_release = 0.0

var shields_on = false
var shield_health = 10

var shield_component: Node = null
var powerup_inventory: PowerupInventory = null

var _gravity_refresh_elapsed = 0.0

var closest_planet: Node = null
var closest_dist: float = INF

var last_slingshot_strength: float = 0.0
var last_slingshot_source: Node = null
var last_slingshot_time: float = -999.0
var last_slingshot_score: float = 0.0
var last_slingshot_grade: StringName = &"none"
var last_slingshot_window: Dictionary = {}

var slingshot_ready: bool = true
var _last_slingshot_window_state: StringName = &"offline"
var _camera_base_rotation: float = 0.0
var _camera_feedback_offset: Vector2 = Vector2.ZERO
var _camera_feedback_roll: float = 0.0

var menu_is_hidden := true
var time_tween: Tween
var _last_damage_amount: float = 0.0
var _last_damage_time: float = -999.0
var _death_in_progress: bool = false
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

@onready var health_component = get_node_or_null("HealthComponent")
@onready var projectile_scene = preload("res://Nodes/projectile.tscn")

# ========================
# == READY ==
# ========================

func _ready():
	_refresh_gravity_sources(true)
	_bind_shield()
	_ensure_powerup_inventory()
	_connect_pause_menu_state()

	if Settings.input_type == false:
		camera.ignore_rotation = true
		camera.rotation_degrees = 0
	else:
		camera.ignore_rotation = false
		camera.rotation_degrees = 270

	_camera_base_rotation = camera.rotation

func _connect_pause_menu_state() -> void:
	var pause_menu := get_pause_menu()
	if pause_menu == null or not pause_menu.has_signal("pause_state_changed"):
		return

	var callable := Callable(self, "_on_pause_menu_state_changed")
	if not pause_menu.is_connected("pause_state_changed", callable):
		pause_menu.connect("pause_state_changed", callable)
	_sync_pause_menu_state(pause_menu)

func _on_pause_menu_state_changed(blocked: bool) -> void:
	menu_is_hidden = not blocked

# ========================
# == PHYSICS LOOP ==
# ========================

func _physics_process(delta: float):
	# 1. ALWAYS process inputs first so state updates map cleanly to forces
	handle_input()
	
	# 2. Safety Lock: If the cinematic pause menu is actively dropping time scale down,
	# completely halt space movement processing to prevent calculation stutter.
	if _is_pause_blocking():
		return

	_gravity_refresh_elapsed += delta

	var gravity = calculate_gravity()
	_update_slingshot_window(gravity)

	handle_rotation(delta)

	# Apply forces
	apply_thrust(delta)
	apply_slingshot(gravity, delta)
	apply_gravity(gravity, delta)

	# Movement & resistance
	apply_drag(gravity, delta)
	update_max_speed(delta)

	# Constraints
	clamp_velocity()
	move_and_slide()

	# Energy reactions
	apply_gravity_recharge(gravity, delta)
	update_ui()

# ========================
# == GRAVITY SYSTEM ==
# ========================

func calculate_gravity() -> Vector2:
	var total = Vector2.ZERO

	closest_dist = INF
	closest_planet = null

	_refresh_gravity_sources(false)

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
		rotation = lerp_angle(rotation, target, clampf(orbit_alignment_assist_strength, 0.0, 1.0))

# ========================
# == SLINGSHOT SYSTEM ==
# ========================

func apply_slingshot(gravity: Vector2, delta: float):
	if get_tree().get_first_node_in_group("Orbital_Juice_Manager") == null:
		apply_regular_slingshot(gravity, delta)
		return
	last_slingshot_strength = maxf(last_slingshot_strength - delta * 2.0, 0.0)

	if not slingshot_ready:
		return

	if not is_instance_valid(closest_planet):
		return
	if velocity.length() < 1.0:
		return
	if closest_dist > 500.0 or closest_dist < 70.0:
		return
	if gravity.length_squared() <= 0.001:
		return

	var impulse := Vector2.ZERO
	var radial = global_position - closest_planet.global_position
	if radial.length_squared() <= 0.001:
		return

	var radial_dir = radial.normalized()
	var tangent = radial_dir.orthogonal()

	if tangent.dot(velocity) < 0:
		tangent = -tangent

	var tangential_speed = maxf(velocity.dot(tangent), 0.0)
	if tangential_speed < slingshot_min_tangential_speed:
		return

	var inward_speed = maxf(velocity.dot(-radial_dir), 0.0)
	var speed_before := velocity.length()
	var quality_data := _score_slingshot_window(gravity, radial_dir, tangent, tangential_speed, inward_speed)
	var slingshot_score := float(quality_data.get("score", 0.0))
	var quality_bonus := lerpf(0.9, 1.34, slingshot_score)
	var speed_factor = clampf(tangential_speed / maxf(slingshot_speed_cap, 1.0), 0.28, 1.35)
	var dive_bonus = clampf(inward_speed / 620.0, 0.0, 0.55)
	var assist_strength = gravity.length() * (speed_factor + dive_bonus) * slingshot_gravity_boost_scale
	if assist_strength > 0:
		impulse = tangent * assist_strength * (slingshot_factor + orbit_control_bonus) * quality_bonus * delta

		var impulse_cap := slingshot_max_impulse * lerpf(0.88, 1.24, slingshot_score)
		if impulse.length() > impulse_cap:
			impulse = impulse.normalized() * impulse_cap

		var momentum_comp = get_node_or_null("MomentumCombatComponent")
		if momentum_comp != null and momentum_comp.has_method("modify_slingshot_impulse"):
			impulse = momentum_comp.modify_slingshot_impulse(impulse, gravity, delta)

		var proposed = velocity + impulse
		var mastery_speed_cap := slingshot_speed_cap + slingshot_mastery_cap_bonus * slingshot_score
		if proposed.length() > mastery_speed_cap:
			var allowed = max(0, mastery_speed_cap - velocity.length())
			if allowed > 0:
				impulse = impulse.normalized() * min(impulse.length(), allowed)
			else:
				impulse = Vector2.ZERO

		velocity += impulse

		last_slingshot_strength = maxf(last_slingshot_strength, assist_strength)
		last_slingshot_source = closest_planet
		last_slingshot_time = Time.get_ticks_msec() / 1000.0
		last_slingshot_score = slingshot_score
		last_slingshot_grade = _slingshot_grade_for_score(slingshot_score)
		slingshot_ready = false

		var mastery_data := quality_data.duplicate()
		mastery_data["source"] = closest_planet
		mastery_data["gravity"] = gravity
		mastery_data["impulse"] = impulse
		mastery_data["assist_strength"] = assist_strength
		mastery_data["speed_before"] = speed_before
		mastery_data["speed_after"] = velocity.length()
		mastery_data["grade"] = last_slingshot_grade
		mastery_data["position"] = global_position
		mastery_data["source_position"] = closest_planet.global_position
		mastery_data["time"] = last_slingshot_time
		last_slingshot_window = mastery_data
		_apply_slingshot_camera_feedback(mastery_data)

		slingshot_assist_applied.emit(
			closest_planet,
			gravity,
			impulse,
			assist_strength,
			velocity.length()
		)
		slingshot_mastery_scored.emit(mastery_data)
		if is_inside_tree():
			get_tree().create_timer(slingshot_cooldown).connect("timeout", Callable(self, "_on_slingshot_cooldown"))

func apply_regular_slingshot(gravity: Vector2, delta: float):
	last_slingshot_strength = maxf(last_slingshot_strength - delta * 2.0, 0.0)
	
	if not is_instance_valid(closest_planet):
		return
	
	if velocity.length() < 1.0:
		return
	
	if closest_dist > 500.0 or closest_dist < 70.0:
		current_max_speed = lerp(current_max_speed, max_speed, delta * 0.5)
		return
	else:
		current_max_speed = maxf(current_max_speed, slingshot_speed_cap)
	
	var grav_dir = gravity.normalized()
	var tangent = grav_dir.orthogonal()
	
	if tangent.dot(velocity) < 0:
		tangent = -tangent
	
	var accel_tangent = gravity.dot(velocity.normalized())

	if accel_tangent > 0 and DRAG_enabled:
		var impulse = tangent * accel_tangent * (slingshot_factor + orbit_control_bonus) * delta
		velocity += impulse
		
		last_slingshot_strength = maxf(last_slingshot_strength, accel_tangent)
		last_slingshot_source = closest_planet
		last_slingshot_time = Time.get_ticks_msec() / 1000.0
		
		slingshot_assist_applied.emit(
			closest_planet,
			gravity,
			impulse,
			accel_tangent,
			velocity.length()
		)
		
func _on_slingshot_cooldown():
	slingshot_ready = true

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

	var energy_cost = max(
		work * energy_cost_per_work,
		minimum_thrust_energy_cost_per_second * delta
	)

	var scale = 0.0

	if energy_component:
		var spent = energy_component.spend(energy_cost)
		scale = clamp(spent / energy_cost, 0.0, 1.0)

	if scale > 0.0:
		var hard_cap := _get_current_hard_speed_cap()
		var speed := velocity.length()
		var forward_speed := velocity.dot(dir)
		if speed > 1.0:
			var thrust_alignment := forward_speed / speed
			if thrust_alignment < -0.2:
				scale *= 1.0 + counter_thrust_control_bonus * absf(thrust_alignment)
			elif absf(thrust_alignment) < 0.45:
				var lateral_control := 1.0 - absf(thrust_alignment) / 0.45
				scale *= 1.0 + lateral_thrust_control_bonus * lateral_control
		var falloff_start := hard_cap * high_speed_thrust_falloff_start
		if forward_speed > 0.0 and speed > falloff_start:
			var remaining := maxf(hard_cap - speed, 0.0)
			var falloff_band := maxf(hard_cap - falloff_start, 1.0)
			scale *= clampf(remaining / falloff_band, 0.0, 1.0)

		velocity += force * scale * delta

func apply_gravity(gravity: Vector2, delta: float):
	velocity += gravity * delta

# ========================
# == ENERGY REGEN ==
# ========================

func apply_gravity_recharge(gravity: Vector2, delta: float):
	if energy_component == null:
		return

	energy_component.restore(0.8 * delta)

	var displacement = velocity * delta
	var work = gravity.dot(displacement)

	if work > 0.0:
		energy_component.restore(work * gravity_charge_per_work)

# ========================
# == DRAG ==
# ========================

func apply_drag(gravity, delta: float):
	if not DRAG_enabled or velocity.length() < 1:
		return

	var coeff = drag if Input.is_action_pressed("thrust") else idle_drag
	var old_v = velocity

	velocity *= pow(coeff, delta * 60.0)

	var energy_loss = 0.0

	if coeff < 0.95:
		if velocity.length() > gravity.length() + 20:
			energy_loss = (old_v.length() - velocity.length()) * 0.01

	if energy_component and energy_loss > 0.0001:
		energy_component.spend(energy_loss)

# ========================
# == CONSTRAINTS ==
# ========================

func clamp_velocity():
	velocity = velocity.limit_length(_get_current_hard_speed_cap())

# ========================
# == DASH ==
# ========================

func boost(dir):
	velocity += dir * 2000.0

	_dash_drag_suppressed = true
	_update_drag_state()
	current_max_speed = maxf(current_max_speed, dash_speed_cap)
	can_dash = false

	if energy_component:
		energy_component.spend(10)

	if powerup_inventory != null:
		powerup_inventory.trigger_player_action()

	if is_inside_tree():
		await get_tree().create_timer(0.3).timeout

	if is_instance_valid(dash_timer):
		dash_timer.start()

	_dash_drag_suppressed = false
	_update_drag_state()

func _on_dash_timeout():
	can_dash = true

# ========================
# == SHOOTING ==
# ========================

func shoot():
	var weapon_system := get_node_or_null("WeaponSystem")
	if weapon_system != null and weapon_system.has_method("try_primary_fire"):
		if bool(weapon_system.call("try_primary_fire")):
			return

	if not is_inside_tree() or get_tree().current_scene == null:
		return

	var p = projectile_scene.instantiate() as RigidBody2D

	if not p:
		return

	var spawn_dir = -transform.x.normalized()

	p.global_position = global_position + spawn_dir * 70
	p.global_rotation = rotation

	var momentum_component = get_node_or_null("MomentumCombatComponent")

	if momentum_component != null and momentum_component.has_method("prepare_projectile"):
		momentum_component.call("prepare_projectile", p, spawn_dir)

	momentum_projectile_spawned.emit(p, spawn_dir)
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
		drag_enabled_by_player = !drag_enabled_by_player
		_update_drag_state()

	if Input.is_action_just_released("thrust"):
		var now = Time.get_ticks_msec() / 1000.0

		if now - last_thrust_release < 0.35 and can_dash:
			boost(-transform.x.normalized())

		last_thrust_release = now

	if Input.is_action_just_released("Menu"):
		var pause_menu = get_pause_menu()
		if pause_menu:
			pause_menu.toggle_pause()
			_sync_pause_menu_state(pause_menu)


func _sync_pause_menu_state(pause_menu: Node) -> void:
	if pause_menu != null and pause_menu.has_method("is_gameplay_blocked"):
		menu_is_hidden = not bool(pause_menu.call("is_gameplay_blocked"))
	else:
		menu_is_hidden = not bool(pause_menu.get("active"))


func _is_pause_blocking() -> bool:
	var pause_menu := get_pause_menu()
	if pause_menu != null and pause_menu.has_method("is_gameplay_blocked"):
		return bool(pause_menu.call("is_gameplay_blocked"))
	return not menu_is_hidden or get_tree().paused

func update_ui():
	drag_label.text = "Drag: " + ("Enabled" if DRAG_enabled else "Disabled")

	if health_component:
		var shield_text = ""

		if shield_component != null and shield_component.get("max_capacity") != null:
			shield_text = " | Shield: %d/%d" % [
				int(round(float(shield_component.get("current_energy")))),
				int(round(float(shield_component.get("max_capacity"))))
			]

		health_label.text = "Health: %s%s" % [
			health_component.current_health,
			shield_text
		]

	if energy_component:
		energy_label.text = "Energy: %d/%d" % [
			int(round(energy_component.current_energy)),
			int(round(energy_component.max_energy))
		]

# ========================
# == PROCESS ==
# ========================

func _process(delta):
	if not _is_pause_blocking():
		update_camera(delta)
		shield_process()

func update_camera(delta: float):
	_camera_feedback_offset = _camera_feedback_offset.lerp(
		Vector2.ZERO,
		clampf(delta * 7.5, 0.0, 1.0)
	)
	_camera_feedback_roll = lerpf(
		_camera_feedback_roll,
		0.0,
		clampf(delta * 8.5, 0.0, 1.0)
	)

	if Settings.input_type == false:
		var target = (get_global_mouse_position() - global_position).normalized() * 180
		var base_offset = camera.offset - _camera_feedback_offset
		camera.offset = lerp(base_offset, target, 0.05) + _camera_feedback_offset
	else:
		camera.offset = camera.offset.lerp(_camera_feedback_offset, clampf(delta * 8.0, 0.0, 1.0))

	camera.rotation = _camera_base_rotation + _camera_feedback_roll

# ========================
# == SHIELDS ==
# ========================

func shield_process():
	if not is_instance_valid(shield_node):
		return

	if shield_component != null and shield_component.has_method("is_shield_active"):
		shields_on = bool(shield_component.call("is_shield_active"))

	shield_node.visible = shields_on

	var poly = shield_node.get_node_or_null("Polygon2D")
	var coll = shield_node.get_node_or_null("CollisionPolygon2D")

	if poly:
		poly.visible = shields_on

	if coll:
		coll.visible = shields_on

func take_damage(amount: float):
	_last_damage_amount = amount
	_last_damage_time = Time.get_ticks_msec() / 1000.0
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

# ========================
# == FIXED GRAVITY REFRESH ==
# ========================

func _refresh_gravity_sources(force: bool) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return

	var tree := get_tree()

	if tree == null:
		return

	if not force and _gravity_refresh_elapsed < gravity_source_refresh_interval:
		return

	_gravity_refresh_elapsed = 0.0

	var seen := {}
	var sources: Array[Node2D] = []

	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in tree.get_nodes_in_group(group_name):
			if source == self:
				continue
			var source_2d := source as Node2D
			if source_2d == null:
				continue
			if not is_instance_valid(source_2d):
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
	if _death_in_progress:
		return

	_death_in_progress = true
	var lesson := _build_death_lesson()
	RunProgress.set_last_death_message(lesson)
	death_lesson_generated.emit(lesson)
	call_deferred("_go_to_game_over_after_lesson")

func _go_to_game_over_after_lesson() -> void:
	await get_tree().create_timer(1.05).timeout
	_go_to_game_over()

func _go_to_game_over() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Nodes/game_over_scene.tscn")

func _build_death_lesson() -> String:
	var speed := velocity.length()
	var gravity := calculate_gravity()
	if gravity.length() > gravity_constant * 1.7:
		return "DEATH VECTOR: gravity stacked faster than your exit angle. Cross the field edge before it folds."
	if speed < max_speed * 0.32 and _last_damage_amount > 0.0:
		return "DEATH VECTOR: low momentum left you pinned. Build speed before trading hits."
	if speed > max_speed * 1.18:
		return "DEATH VECTOR: high velocity needs a recovery orbit. Aim for a wide slingshot, then brake."
	if shield_component != null and shield_component.get("is_broken") == true:
		return "DEATH VECTOR: shield break is a retreat signal. Drift wide until the bubble reforms."
	return "DEATH VECTOR: read the nearest field rule first, then move. The arena always telegraphs the law."

func _on_health_component_health_changed(current, _max):
	health_label.text = "Health: " + str(current)

func _on_shield_broken() -> void:
	shields_on = false

func _on_shield_hit(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	shields_on = is_shield_active()

func _on_shield_restored(_amount: float, _current_energy: float, _max_capacity: float) -> void:
	shields_on = is_shield_active()

# ========================
# == SPEED CAP ==
# ========================

func update_max_speed(delta: float):
	var target_max = max_speed
	var momentum_bonus := _get_momentum_speed_cap_bonus()

	target_max += momentum_bonus

	if not drag_enabled_by_player:
		target_max = maxf(target_max, max_speed * drag_disabled_speed_multiplier + momentum_bonus)

	if _dash_drag_suppressed:
		target_max = maxf(target_max, dash_speed_cap + momentum_bonus * 0.45)

	target_max = minf(target_max, absolute_velocity_cap)
	var lerp_rate := 5.8 if current_max_speed > target_max else 3.2
	current_max_speed = lerp(current_max_speed, target_max, clampf(lerp_rate * delta, 0.0, 1.0))

func _get_momentum_speed_cap_bonus() -> float:
	var momentum_comp = get_node_or_null("MomentumCombatComponent")

	if momentum_comp == null:
		return 0.0

	if momentum_comp.has_method("_get_current_speed_cap_bonus"):
		return float(momentum_comp.call("_get_current_speed_cap_bonus"))

	var bonus_value: Variant = momentum_comp.get("_speed_cap_bonus")
	if typeof(bonus_value) == TYPE_FLOAT or typeof(bonus_value) == TYPE_INT:
		return float(bonus_value)

	return 0.0

func _get_current_hard_speed_cap() -> float:
	var cap := minf(maxf(current_max_speed, max_speed), absolute_velocity_cap)

	if not drag_enabled_by_player and not _dash_drag_suppressed:
		cap = minf(cap, max_speed * drag_disabled_speed_multiplier + _get_momentum_speed_cap_bonus())

	return maxf(cap, 1.0)

func _update_drag_state() -> void:
	DRAG_enabled = drag_enabled_by_player and not _dash_drag_suppressed

func _update_slingshot_window(gravity: Vector2) -> void:
	var state := &"offline"
	var window_data := {
		"state": state,
		"score": 0.0,
		"grade": &"none",
		"ready": slingshot_ready,
		"distance": closest_dist,
		"sweet_distance": slingshot_sweet_spot_distance,
		"sweet_width": slingshot_sweet_spot_width,
		"tangential_speed": 0.0,
		"inward_speed": 0.0,
		"source": closest_planet,
		"position": global_position,
	}

	if not slingshot_ready:
		state = &"cooldown"
	elif not is_instance_valid(closest_planet):
		state = &"search"
	elif velocity.length() < 1.0 or gravity.length_squared() <= 0.001:
		state = &"align"
	elif closest_dist > 500.0:
		state = &"approach"
	elif closest_dist < 70.0:
		state = &"danger"
	else:
		var radial = global_position - closest_planet.global_position
		if radial.length_squared() > 0.001:
			var radial_dir = radial.normalized()
			var tangent = radial_dir.orthogonal()
			if tangent.dot(velocity) < 0.0:
				tangent = -tangent
			var tangential_speed := maxf(velocity.dot(tangent), 0.0)
			var inward_speed := maxf(velocity.dot(-radial_dir), 0.0)
			var score_data := _score_slingshot_window(
				gravity,
				radial_dir,
				tangent,
				tangential_speed,
				inward_speed
			)
			window_data.merge(score_data, true)
			var score := float(score_data.get("score", 0.0))
			if tangential_speed < slingshot_min_tangential_speed:
				state = &"align"
			elif score >= slingshot_apex_score:
				state = &"apex"
			elif score >= slingshot_perfect_score:
				state = &"perfect"
			elif float(score_data.get("distance_score", 0.0)) > 0.5:
				state = &"sweet"
			else:
				state = &"ready"

	window_data["state"] = state
	window_data["grade"] = _slingshot_grade_for_score(float(window_data.get("score", 0.0)))
	window_data["ready"] = slingshot_ready
	last_slingshot_window = window_data

	if state != _last_slingshot_window_state:
		_last_slingshot_window_state = state
		slingshot_window_changed.emit(window_data)

func _score_slingshot_window(
	gravity: Vector2,
	radial_dir: Vector2,
	tangent: Vector2,
	tangential_speed: float,
	inward_speed: float
) -> Dictionary:
	var distance_score := 0.0
	if slingshot_sweet_spot_width > 0.001:
		distance_score = 1.0 - absf(closest_dist - slingshot_sweet_spot_distance) / slingshot_sweet_spot_width
	distance_score = clampf(distance_score, 0.0, 1.0)

	var full_tangent_speed := maxf(slingshot_speed_cap * 0.82, slingshot_min_tangential_speed + 1.0)
	var tangent_score := clampf(
		(tangential_speed - slingshot_min_tangential_speed)
		/ maxf(full_tangent_speed - slingshot_min_tangential_speed, 1.0),
		0.0,
		1.0
	)
	var dive_score := clampf(inward_speed / 620.0, 0.0, 1.0)
	var speed_score := clampf(velocity.length() / maxf(current_max_speed, 1.0), 0.0, 1.0)
	var gravity_score := clampf(gravity.length() / 420.0, 0.0, 1.0)
	var score := clampf(
		distance_score * 0.44
		+ tangent_score * 0.34
		+ dive_score * 0.14
		+ speed_score * 0.05
		+ gravity_score * 0.03,
		0.0,
		1.0
	)

	return {
		"score": score,
		"distance_score": distance_score,
		"tangent_score": tangent_score,
		"dive_score": dive_score,
		"speed_score": speed_score,
		"gravity_score": gravity_score,
		"tangential_speed": tangential_speed,
		"inward_speed": inward_speed,
		"distance": closest_dist,
		"sweet_distance": slingshot_sweet_spot_distance,
		"sweet_width": slingshot_sweet_spot_width,
		"radial_dir": radial_dir,
		"tangent": tangent,
		"position": global_position,
	}

func _slingshot_grade_for_score(score: float) -> StringName:
	if score >= slingshot_apex_score:
		return &"apex"
	if score >= slingshot_perfect_score:
		return &"perfect"
	if score >= 0.64:
		return &"great"
	if score >= 0.38:
		return &"good"
	return &"assist"

func _apply_slingshot_camera_feedback(data: Dictionary) -> void:
	if camera == null:
		return

	var coordinator := JuiceCoordinator.find_coordinator(get_tree())
	if coordinator != null and not coordinator.should_apply_slingshot_camera(data):
		return

	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	score = min(score, 0.95)
	var kick_scale := 1.0
	if coordinator != null:
		kick_scale = coordinator.camera_kick_scale_for_tier(coordinator.slingshot_tier_from_data(data))
	
	var tangent: Vector2 = data.get("tangent", Vector2.RIGHT)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT

	var grade := StringName(data.get("grade", &"assist"))
	var grade_boost := 1.0
	if grade == &"perfect":
		grade_boost = 1.25
	elif grade == &"apex":
		grade_boost = 1.55

	_camera_feedback_offset += -tangent.normalized() * slingshot_camera_kick * (0.25 + score) * grade_boost * kick_scale
	_camera_feedback_offset = _camera_feedback_offset.limit_length(slingshot_camera_kick * 2.2)
	var roll_axis := tangent.x if absf(tangent.x) > 0.05 else tangent.y
	_camera_feedback_roll += slingshot_camera_roll * (0.25 + score) * grade_boost * kick_scale * signf(roll_axis)
	_camera_feedback_roll = clampf(_camera_feedback_roll, -slingshot_camera_roll * 2.1, slingshot_camera_roll * 2.1)

func get_slingshot_debug_state() -> Dictionary:
	var state := last_slingshot_window.duplicate()
	state["last_score"] = last_slingshot_score
	state["last_grade"] = last_slingshot_grade
	state["last_age"] = Time.get_ticks_msec() / 1000.0 - last_slingshot_time
	state["cooldown_ready"] = slingshot_ready
	return state
	
func get_pause_menu() -> Node:
	# First try direct path (works in player scene)
	var direct = $CanvasLayer/PauseMenu
	if is_instance_valid(direct):
		return direct
	
	# Fallback: Search the tree (works when player is instanced in main scene)
	var menu = get_tree().get_first_node_in_group("PauseMenu")
	if is_instance_valid(menu):
		return menu
	
	# Last resort
	return get_tree().current_scene.find_child("PauseMenu", true, false)
