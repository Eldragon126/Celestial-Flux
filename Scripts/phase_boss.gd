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

	player = get_tree().get_first_node_in_group("Player") as Node2D
	_build_health()
	_build_attack_timer()
	call_deferred("enter_phase", 1)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node2D
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
	_run_attack_pattern()

func on_damage_taken(_amount: float) -> void:
	pass

func _boss_physics(_delta: float) -> void:
	pass

func _run_attack_pattern() -> void:
	pass

func _on_enter_phase(_phase: int) -> void:
	pass

func _on_exit_phase(_phase: int) -> void:
	pass

func _build_health() -> void:
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_health
	add_child(health)
	health.health_changed.connect(_on_health_changed)
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
	boss_defeated.emit()
	queue_free()
