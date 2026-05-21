extends Node2D
class_name OrbitalVFXDirector

## Signal-driven spectacle layer. The child particle nodes are editable
## templates, so art tuning can happen in the inspector without touching code.

@export_group("Signal Sources")
@export var player_path: NodePath
@export var time_dilation_manager_path: NodePath
@export var gravity_resonance_manager_path: NodePath

@export_group("Quality")
@export var effects_enabled: bool = true
@export_enum("Off", "Low", "High") var visual_quality: int = 2
@export var low_performance_mode: bool = false
@export var max_active_bursts: int = 18
@export var max_particles_per_burst: int = 72
@export var chaos_clutter_threshold: float = 0.74

@export_group("Templates")
@export var time_afterimage_template_path: NodePath = ^"Templates/TimeAfterimageBurst"
@export var shockwave_template_path: NodePath = ^"Templates/KineticImpactBurst"
@export var resonance_template_path: NodePath = ^"Templates/ResonanceLawBurst"
@export var slingshot_template_path: NodePath = ^"Templates/SlingshotSparkleBurst"

var _player: Node = null
var _time_manager: Node = null
var _resonance_manager: Node = null
var _momentum: Node = null
var _active_bursts: Array[GPUParticles2D] = []
var _chaos_intensity: float = 0.0

@onready var _burst_root: Node2D = $Bursts
@onready var _time_template: GPUParticles2D = get_node_or_null(time_afterimage_template_path) as GPUParticles2D
@onready var _shockwave_template: GPUParticles2D = get_node_or_null(shockwave_template_path) as GPUParticles2D
@onready var _resonance_template: GPUParticles2D = get_node_or_null(resonance_template_path) as GPUParticles2D
@onready var _slingshot_template: GPUParticles2D = get_node_or_null(slingshot_template_path) as GPUParticles2D


func _ready() -> void:
	add_to_group("orbital_vfx_director")
	_resolve_sources()
	_configure_templates()
	_connect_sources()


func _process(_delta: float) -> void:
	_prune_finished_bursts()
	_update_chaos_intensity()


func _resolve_sources() -> void:
	var scene := get_tree().current_scene
	_player = get_node_or_null(player_path) if not player_path.is_empty() else get_tree().get_first_node_in_group("Player")
	_time_manager = get_node_or_null(time_dilation_manager_path) if not time_dilation_manager_path.is_empty() else null
	_resonance_manager = get_node_or_null(gravity_resonance_manager_path) if not gravity_resonance_manager_path.is_empty() else null
	if scene != null:
		if _time_manager == null:
			_time_manager = scene.find_child("TimeDilationManager", true, false)
		if _resonance_manager == null:
			_resonance_manager = scene.find_child("GravityResonanceManager", true, false)
	if _player != null:
		_momentum = _player.get_node_or_null("MomentumCombatComponent")


func _configure_templates() -> void:
	for template in [_time_template, _shockwave_template, _resonance_template, _slingshot_template]:
		if template == null:
			continue
		template.visible = false
		template.emitting = false
		template.one_shot = true


func _connect_sources() -> void:
	_connect_signal(_time_manager, &"dilation_started", Callable(self, "_on_dilation_started"))
	_connect_signal(_time_manager, &"local_time_pocket_entered", Callable(self, "_on_local_time_pocket_entered"))
	_connect_signal(_time_manager, &"afterimage_spawned", Callable(self, "_on_afterimage_spawned"))
	_connect_signal(_resonance_manager, &"resonance_zone_created", Callable(self, "_on_resonance_zone_pulsed"))
	_connect_signal(_resonance_manager, &"resonance_field_pulsed", Callable(self, "_on_resonance_zone_pulsed"))
	_connect_signal(_momentum, &"kinetic_shockwave_created", Callable(self, "_on_kinetic_shockwave_created"))
	_connect_signal(_momentum, &"slingshot_mastery_triggered", Callable(self, "_on_slingshot_mastery_triggered"))


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_dilation_started() -> void:
	var player_2d := _player as Node2D
	if player_2d != null:
		_spawn_burst(_time_template, player_2d.global_position, 0.72, Color(0.45, 0.9, 1.0, 1.0))


func _on_local_time_pocket_entered(target: Node, multiplier: float, _duration: float) -> void:
	var target_2d := target as Node2D
	if target_2d == null:
		return
	var intensity := clampf(1.0 - multiplier, 0.18, 0.85)
	_spawn_burst(_time_template, target_2d.global_position, intensity, Color(0.78, 0.48, 1.0, 1.0))


func _on_afterimage_spawned(position: Vector2, velocity: Vector2) -> void:
	var speed_intensity := clampf(velocity.length() / 1600.0, 0.15, 0.72)
	_spawn_burst(_slingshot_template, position, speed_intensity, Color(0.32, 1.0, 0.92, 1.0))


func _on_resonance_zone_pulsed(zone_data: Dictionary) -> void:
	var position: Vector2 = zone_data.get("midpoint", Vector2.ZERO)
	var intensity := clampf(float(zone_data.get("intensity", 0.35)), 0.12, 1.0)
	var color: Color = zone_data.get("zone_color", Color(0.2, 0.75, 1.0, 1.0))
	_spawn_burst(_resonance_template, position, intensity, color)


func _on_kinetic_shockwave_created(shockwave_data: Dictionary) -> void:
	var position: Vector2 = shockwave_data.get("position", Vector2.ZERO)
	var speed := float(shockwave_data.get("speed", 900.0))
	var intensity := clampf(speed / 2400.0, 0.25, 0.86)
	_spawn_burst(_shockwave_template, position, intensity, Color(1.0, 0.68, 0.28, 1.0))


func _on_slingshot_mastery_triggered(data: Dictionary) -> void:
	var player_2d := _player as Node2D
	var fallback := player_2d.global_position if player_2d != null else global_position
	var position: Vector2 = data.get("position", fallback)
	var score := clampf(float(data.get("score", 0.45)), 0.0, 1.0)
	var color := Color(0.28, 1.0, 0.88, 1.0)
	if StringName(data.get("tier", &"idle")) == &"god_vector":
		color = Color(1.0, 0.86, 0.28, 1.0)
	_spawn_burst(_slingshot_template, position, score, color)


func _spawn_burst(template: GPUParticles2D, position: Vector2, intensity: float, color: Color) -> void:
	if not _can_spawn_burst(template, intensity):
		return

	var burst := template.duplicate() as GPUParticles2D
	if burst == null:
		return

	burst.visible = true
	burst.amount = _particle_amount(template.amount, intensity)
	burst.modulate = _burst_modulate(color, intensity)
	_burst_root.add_child(burst)
	burst.global_position = position
	burst.restart()
	burst.emitting = true
	_active_bursts.append(burst)


func _can_spawn_burst(template: GPUParticles2D, intensity: float) -> bool:
	if not effects_enabled or visual_quality <= 0 or template == null:
		return false
	if _chaos_intensity > chaos_clutter_threshold and intensity < 0.55:
		return false
	return _active_bursts.size() < _active_burst_cap()


func _particle_amount(base_amount: int, intensity: float) -> int:
	var quality_scale := 0.45 if visual_quality == 1 else 1.0
	if low_performance_mode:
		quality_scale *= 0.5
	var chaos_scale := lerpf(1.0, 0.55, _chaos_intensity)
	var amount := float(base_amount) * lerpf(0.35, 1.0, intensity) * quality_scale * chaos_scale
	return clampi(int(amount), 4, max_particles_per_burst)


func _active_burst_cap() -> int:
	if low_performance_mode:
		return maxi(4, int(max_active_bursts * 0.45))
	if visual_quality == 1:
		return maxi(6, int(max_active_bursts * 0.65))
	return max_active_bursts


func _burst_modulate(color: Color, intensity: float) -> Color:
	var alpha := lerpf(0.44, 1.0, clampf(intensity, 0.0, 1.0))
	return Color(color.r, color.g, color.b, alpha)


func _prune_finished_bursts() -> void:
	for idx in range(_active_bursts.size() - 1, -1, -1):
		var burst := _active_bursts[idx]
		if burst == null or not is_instance_valid(burst):
			_active_bursts.remove_at(idx)
			continue
		if not burst.emitting:
			burst.queue_free()
			_active_bursts.remove_at(idx)


func _update_chaos_intensity() -> void:
	var projectile_count := get_tree().get_nodes_in_group("Projectiles").size()
	projectile_count += get_tree().get_nodes_in_group("enemy_projectiles").size()
	var target_chaos := clampf(float(projectile_count) / 180.0, 0.0, 1.0)
	_chaos_intensity = lerpf(_chaos_intensity, target_chaos, 0.08)


func get_vfx_debug_state() -> Dictionary:
	return {
		"active_bursts": _active_bursts.size(),
		"burst_cap": _active_burst_cap(),
		"chaos": _chaos_intensity,
		"quality": visual_quality,
		"low_performance": low_performance_mode,
	}
