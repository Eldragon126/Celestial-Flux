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

var current_phase = 0
var player: Node2D = null
var health: HealthComponent = null
var attack_timer: Timer = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wave_enemy")
	add_to_group("bosses")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")

	player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_health()
	_build_attack_timer()
	call_deferred("enter_phase", 1)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return

	_update_phase_from_health()
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
