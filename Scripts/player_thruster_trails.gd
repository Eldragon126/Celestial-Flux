extends Node2D

# Inspector-tunable thruster visuals. Script only drives emission from velocity.

@export var thruster_local_position: Vector2 = Vector2(32.0, 0.0)

var _flame: GPUParticles2D = null
var _glow: Polygon2D = null
var _player: Node = null


func _ready() -> void:
	_player = get_parent()
	_flame = get_node_or_null("ThrusterFlame") as GPUParticles2D
	_glow = get_node_or_null("ThrusterGlow") as Polygon2D
	if _flame != null:
		_flame.position = thruster_local_position
	if _glow != null:
		_glow.position = thruster_local_position


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _flame == null or _glow == null:
		return

	var velocity = _player.get("velocity")
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
	glow_color.a = lerpf(0.32, 0.68, juice)
	_glow.color = glow_color


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
