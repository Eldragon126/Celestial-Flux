extends Node2D

# Inspector-tunable thruster visuals. Script only drives emission from velocity.

@export var thruster_local_position: Vector2 = Vector2(32.0, 0.0)
@export_group("Vector Contrail")
@export var enable_vector_contrail: bool = true
@export var contrail_length: float = 92.0
@export var contrail_width: float = 3.6
@export_range(0.0, 1.0, 0.01) var contrail_alpha_cap: float = 0.32

var _flame: GPUParticles2D = null
var _glow: Polygon2D = null
var _contrail: Line2D = null
var _inner_contrail: Line2D = null
var _player: Node = null
var _pulse_time: float = 0.0


func _ready() -> void:
	_player = get_parent()
	_flame = get_node_or_null("ThrusterFlame") as GPUParticles2D
	_glow = get_node_or_null("ThrusterGlow") as Polygon2D
	_ensure_contrail()
	if _flame != null:
		_flame.position = thruster_local_position
	if _glow != null:
		_glow.position = thruster_local_position


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _flame == null or _glow == null:
		return
	_pulse_time += delta

	var velocity_value: Variant = _player.get("velocity")
	var velocity := Vector2.ZERO
	if velocity_value is Vector2:
		velocity = velocity_value
	var max_speed = maxf(float(_player.get("max_speed")), 1.0)
	var speed_ratio = clampf(velocity.length() / max_speed, 0.0, 1.8)
	var thrusting = Input.is_action_pressed("thrust")
	var flow_intensity := _get_flow_intensity()
	var slingshot_heat := _get_recent_slingshot_heat()
	var juice := clampf(maxf(flow_intensity, slingshot_heat), 0.0, 1.0)
	var coordinator := JuiceCoordinator.find_coordinator(get_tree())
	if coordinator != null and slingshot_heat > 0.0:
		var slingshot_data := {
			"score": _player.get("last_slingshot_score") if _player != null else 0.0,
			"tier": &"",
		}
		if not coordinator.should_boost_thrusters_for_slingshot(slingshot_data):
			slingshot_heat = 0.0
			juice = clampf(flow_intensity, 0.0, 1.0)

	_flame.emitting = thrusting or juice > 0.08
	_flame.speed_scale = lerpf(0.55, 1.65, clampf(speed_ratio, 0.0, 1.0)) + juice * 0.62
	_flame.lifetime = lerpf(0.28, 0.62, clampf(speed_ratio, 0.0, 1.0)) + juice * 0.18
	_flame.amount = int(lerpf(72.0, 138.0, juice))

	_glow.visible = thrusting or juice > 0.08
	_glow.scale = Vector2.ONE * (lerpf(0.82, 1.35, clampf(speed_ratio, 0.0, 1.0)) + juice * 0.35)
	var glow_color := _glow.color
	var glow_alpha := _safe_alpha(lerpf(0.18, 0.68, maxf(juice, 0.2 if thrusting else 0.0)), 0.42)
	glow_color = glow_color.lerp(_thruster_color(speed_ratio, juice), clampf(juice + speed_ratio * 0.2, 0.0, 0.72))
	glow_color.a = glow_alpha
	_glow.color = glow_color
	_update_contrail(speed_ratio, juice, thrusting)


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


func _ensure_contrail() -> void:
	if not enable_vector_contrail:
		return
	if _contrail == null:
		_contrail = Line2D.new()
		_contrail.name = "VectorContrail"
		_contrail.antialiased = true
		_contrail.width = contrail_width
		_contrail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_contrail.end_cap_mode = Line2D.LINE_CAP_ROUND
		_contrail.z_index = -3
		add_child(_contrail)
	if _inner_contrail == null:
		_inner_contrail = Line2D.new()
		_inner_contrail.name = "VectorContrailCore"
		_inner_contrail.antialiased = true
		_inner_contrail.width = maxf(1.0, contrail_width * 0.42)
		_inner_contrail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_inner_contrail.end_cap_mode = Line2D.LINE_CAP_ROUND
		_inner_contrail.z_index = -2
		add_child(_inner_contrail)


func _update_contrail(speed_ratio: float, juice: float, thrusting: bool) -> void:
	if not enable_vector_contrail:
		if _contrail != null:
			_contrail.visible = false
		if _inner_contrail != null:
			_inner_contrail.visible = false
		return
	_ensure_contrail()
	if _contrail == null or _inner_contrail == null:
		return
	var heat := clampf(maxf(maxf(juice, speed_ratio * 0.48), 0.18 if thrusting else 0.0), 0.0, 1.0)
	var visible := heat > 0.04
	_contrail.visible = visible
	_inner_contrail.visible = visible
	if not visible:
		return

	var wave := sin(_pulse_time * 16.0) * 0.08 * heat
	var length := contrail_length * lerpf(0.58, 1.42, heat)
	var flare := lerpf(5.0, 18.0, heat)
	var points := PackedVector2Array([
		thruster_local_position + Vector2(4.0, 0.0),
		thruster_local_position + Vector2(length * 0.38, flare * wave),
		thruster_local_position + Vector2(length, -flare * 0.22),
	])
	_contrail.points = points
	_inner_contrail.points = PackedVector2Array([
		thruster_local_position + Vector2(2.0, 0.0),
		thruster_local_position + Vector2(length * 0.52, flare * wave * 0.42),
	])

	var color := _thruster_color(speed_ratio, juice)
	_contrail.width = contrail_width * lerpf(0.72, 1.55, heat)
	_inner_contrail.width = maxf(1.0, contrail_width * lerpf(0.28, 0.62, heat))
	_contrail.default_color = Color(color.r, color.g, color.b, _safe_alpha(contrail_alpha_cap * heat, contrail_alpha_cap))
	_inner_contrail.default_color = Color(1.0, 1.0, 1.0, _safe_alpha(0.2 + heat * 0.22, 0.34))


func _thruster_color(speed_ratio: float, juice: float) -> Color:
	var cyan := Color(0.14, 0.88, 1.0, 1.0)
	var apex := Color(1.0, 0.84, 0.26, 1.0)
	var phase := Color(0.55, 0.34, 1.0, 1.0)
	var speed_mix := clampf((speed_ratio - 0.8) / 0.8, 0.0, 1.0)
	return cyan.lerp(apex, clampf(juice * 0.55, 0.0, 1.0)).lerp(phase, speed_mix * 0.24)


func _safe_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)
