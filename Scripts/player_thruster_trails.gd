extends Node2D

# Player add-on: two particle flame cones that respond to thrust and speed.
# This sits under Player, so it can read velocity without editing player.gd.

var _flames: Array[GPUParticles2D] = []
var _glow_polygons: Array[Polygon2D] = []
var _player: Node = null

func _ready() -> void:
	_player = get_parent()
	_build_thruster(Vector2(32.0, 0), Color(0.15, 0.78, 1.0, 1.0), Color(0.0, 0.162, 0.811, 0.922))
	#_build_thruster(Vector2(32.0, 8.5), Color(0.2, 0.86, 1.0, 1.0), Color(0.0, 0.698, 0.813, 0.92))

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var velocity = _player.get("velocity")
	var max_speed = maxf(float(_player.get("max_speed")), 1.0)
	var speed_ratio = clampf(velocity.length() / max_speed, 0.0, 1.8)
	var thrusting = Input.is_action_pressed("thrust")
	var flow_intensity := _get_flow_intensity()
	var slingshot_heat := _get_recent_slingshot_heat()
	var juice := clampf(maxf(flow_intensity, slingshot_heat), 0.0, 1.0)

	for flame in _flames:
		flame.emitting = thrusting or juice > 0.08
		flame.speed_scale = lerpf(0.55, 1.65, clampf(speed_ratio, 0.0, 1.0)) + juice * 0.62
		flame.lifetime = lerpf(0.28, 0.62, clampf(speed_ratio, 0.0, 1.0)) + juice * 0.18
		flame.amount = int(lerpf(72.0, 138.0, juice))

	for glow in _glow_polygons:
		glow.visible = thrusting or juice > 0.08
		glow.scale = Vector2.ONE * (lerpf(0.82, 1.35, clampf(speed_ratio, 0.0, 1.0)) + juice * 0.35)
		var glow_color := glow.color
		glow_color.a = lerpf(0.32, 0.68, juice)
		glow.color = glow_color

func _build_thruster(local_pos: Vector2, core_color: Color, ember_color: Color) -> void:
	var glow = Polygon2D.new()
	glow.name = "ThrusterGlow"
	glow.position = local_pos
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -6.0),
		Vector2(50.0, 0.0),
		Vector2(0.0, 6.0),
	])
	glow.color = Color(ember_color.r, ember_color.g, ember_color.b, 0.42)
	glow.visible = false
	add_child(glow)
	_glow_polygons.append(glow)

	var flame = GPUParticles2D.new()
	flame.name = "ThrusterFlame"
	flame.position = local_pos
	flame.z_index = -2
	flame.amount = 96
	flame.lifetime = 0.42
	flame.randomness = 0.35
	flame.fixed_fps = 60
	flame.local_coords = true
	flame.emitting = false
	flame.process_material = _make_thruster_material(core_color, ember_color)
	add_child(flame)
	_flames.append(flame)

func _make_thruster_material(core_color: Color, ember_color: Color) -> ParticleProcessMaterial:
	var gradient = Gradient.new()
	gradient.set_color(0, core_color)
	gradient.set_color(1, Color(ember_color.r, ember_color.g, ember_color.b, 0.0))

	var texture = GradientTexture1D.new()
	texture.gradient = gradient

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 18.0
	material.initial_velocity_min = 70.0
	material.initial_velocity_max = 210.0
	material.gravity = Vector3.ZERO
	material.damping_min = 12.0
	material.damping_max = 36.0
	material.scale_min = 2.0
	material.scale_max = 8.0
	material.color_ramp = texture
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.45
	material.turbulence_noise_scale = 3.0
	return material

func _get_flow_intensity() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0

	var momentum := _player.get_node_or_null("MomentumCombatComponent")
	if momentum == null or not momentum.has_method("get_momentum_debug_state"):
		return 0.0

	var state_value: Variant = momentum.call("get_momentum_debug_state")
	if typeof(state_value) != TYPE_DICTIONARY:
		return 0.0

	return clampf(float(state_value.get("flow_intensity", 0.0)), 0.0, 1.0)

func _get_recent_slingshot_heat() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0

	var time_value: Variant = _player.get("last_slingshot_time")
	var score_value: Variant = _player.get("last_slingshot_score")
	if not (typeof(time_value) == TYPE_FLOAT or typeof(time_value) == TYPE_INT):
		return 0.0
	if not (typeof(score_value) == TYPE_FLOAT or typeof(score_value) == TYPE_INT):
		return 0.0

	var age := Time.get_ticks_msec() / 1000.0 - float(time_value)
	return clampf(1.0 - age / 0.85, 0.0, 1.0) * clampf(float(score_value), 0.0, 1.0)
