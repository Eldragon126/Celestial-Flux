extends CharacterBody2D
class_name PhaseBoss

signal phase_entered(phase: int)
signal phase_exited(phase: int)
signal boss_health_changed(current_health: float, max_health: float)
signal boss_defeated

@export var max_health = 900.0
@export var mass = 380000.0
@export var phase_two_ratio = 0.66
@export var phase_three_ratio = 0.33
@export var attack_interval = 2.2
@export_group("Boss Readability")
@export var enable_presentation_rings: bool = true
@export var boss_aura_radius: float = 132.0
@export var boss_aura_color: Color = Color(1.0, 0.16, 0.44, 0.28)
@export var boss_phase_color: Color = Color(1.0, 0.72, 0.22, 0.32)

var current_phase = 0
var player: Node2D = null
var health: HealthComponent = null
var attack_timer: Timer = null
var _presentation_root: Node2D = null
var _aura_ring: Line2D = null
var _phase_ring: Line2D = null
var _presentation_time := 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wave_enemy")
	add_to_group("bosses")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")

	player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_health()
	_build_attack_timer()
	_build_presentation_visuals()
	call_deferred("enter_phase", 1)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return

	_update_phase_from_health()
	_update_presentation_visuals(delta)
	_boss_physics(delta * CombatStatus.get_time_scale(self))

func take_damage(amount: float) -> void:
	if health != null:
		health.take_damage(amount)
	on_damage_taken(amount)

func get_health_ratio() -> float:
	if health == null or health.max_health <= 0.0:
		return 0.0
	return clampf(health.current_health / health.max_health, 0.0, 1.0)

func enter_phase(phase: int) -> void:
	if current_phase == phase:
		return

	if current_phase > 0:
		exit_phase(current_phase)

	current_phase = phase
	phase_entered.emit(phase)
	_on_enter_phase(phase)

func exit_phase(phase: int) -> void:
	phase_exited.emit(phase)
	_on_exit_phase(phase)

func attack_pattern_loop() -> void:
	if is_queued_for_deletion() or current_phase <= 0:
		return
	_run_attack_pattern()

func on_damage_taken(_amount: float) -> void:
	set_meta(&"last_damage_taken", maxf(_amount, 0.0))

func _boss_physics(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 90.0 * _delta)
	move_and_slide()

func _run_attack_pattern() -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(attack_interval, 0.05)

func _on_enter_phase(_phase: int) -> void:
	if attack_timer != null:
		attack_timer.wait_time = maxf(attack_interval / maxf(float(_phase), 1.0), 0.08)
		attack_timer.start()
	if _phase_ring != null:
		_phase_ring.scale = Vector2.ONE * (1.18 + 0.1 * float(_phase))
		_phase_ring.modulate.a = 1.0

func _on_exit_phase(_phase: int) -> void:
	set_meta(&"last_phase_exited", _phase)

func _build_health() -> void:
	health = get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		health = HealthComponent.new()
		health.name = "HealthComponent"
		add_child(health)
	health.max_health = max_health
	if not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)
	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

func _build_attack_timer() -> void:
	attack_timer = Timer.new()
	attack_timer.name = "AttackPatternTimer"
	attack_timer.wait_time = attack_interval
	attack_timer.timeout.connect(attack_pattern_loop)
	add_child(attack_timer)
	attack_timer.start()


func _build_presentation_visuals() -> void:
	if not enable_presentation_rings:
		return
	_presentation_root = get_node_or_null("BossPresentationRoot") as Node2D
	if _presentation_root == null:
		_presentation_root = Node2D.new()
		_presentation_root.name = "BossPresentationRoot"
		_presentation_root.z_index = -1
		add_child(_presentation_root)

	_aura_ring = _make_boss_ring("BossAuraRing", boss_aura_radius, 3.0, boss_aura_color)
	_phase_ring = _make_boss_ring("BossPhaseRing", boss_aura_radius * 0.72, 2.0, boss_phase_color)


func _make_boss_ring(node_name: String, radius: float, width: float, color: Color) -> Line2D:
	var ring := Line2D.new()
	ring.name = node_name
	ring.antialiased = true
	ring.closed = true
	ring.width = width
	ring.points = _circle_points(radius, 72)
	ring.default_color = _safe_boss_color(color, color.a)
	ring.material = _make_boss_ring_material()
	_presentation_root.add_child(ring)
	return ring


func _update_presentation_visuals(delta: float) -> void:
	if _presentation_root == null:
		return
	_presentation_time += delta
	var phase_pressure := clampf(float(current_phase) / 3.0, 0.2, 1.0)
	_presentation_root.rotation += delta * (0.28 + phase_pressure * 0.18)
	var pulse := 0.5 + 0.5 * sin(_presentation_time * (2.8 + phase_pressure))
	if _aura_ring != null:
		_aura_ring.width = lerpf(2.0, 4.2, pulse)
		_aura_ring.default_color = _safe_boss_color(boss_aura_color, lerpf(0.16, boss_aura_color.a, pulse))
	if _phase_ring != null:
		_phase_ring.rotation -= delta * (0.52 + phase_pressure * 0.36)
		_phase_ring.scale = _phase_ring.scale.lerp(Vector2.ONE * (0.96 + phase_pressure * 0.08), clampf(delta * 4.0, 0.0, 1.0))
		_phase_ring.modulate.a = lerpf(_phase_ring.modulate.a, 0.74, clampf(delta * 3.0, 0.0, 1.0))
		_phase_ring.default_color = _safe_boss_color(boss_phase_color, lerpf(0.16, boss_phase_color.a, phase_pressure))


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(count, 8)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _safe_boss_color(color: Color, alpha: float) -> Color:
	var safe_alpha := alpha
	if Settings != null and Settings.has_method("world_visual_alpha"):
		safe_alpha = Settings.world_visual_alpha(alpha, 0.34)
	elif Settings != null and Settings.has_method("flash_alpha"):
		safe_alpha = minf(Settings.flash_alpha(alpha), 0.34)
	return Color(color.r, color.g, color.b, safe_alpha)


func _make_boss_ring_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	float scan = 0.5 + 0.5 * sin(TIME * 4.0 + UV.x * 18.0);
	vec4 base = COLOR;
	base.rgb += scan * 0.16;
	COLOR = base;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _update_phase_from_health() -> void:
	var ratio = get_health_ratio()
	if ratio <= phase_three_ratio:
		enter_phase(3)
	elif ratio <= phase_two_ratio:
		enter_phase(2)
	else:
		enter_phase(1)

func _on_health_changed(current_health: float, new_max_health: float) -> void:
	boss_health_changed.emit(current_health, new_max_health)

func _on_died() -> void:
	if attack_timer != null:
		attack_timer.stop()
	boss_defeated.emit()
	queue_free()
