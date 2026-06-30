extends Node2D
class_name OrbitalVFXDirector

## Signal-driven spectacle layer. The child particle nodes are editable
## templates, so art tuning can happen in the inspector without touching code.

const PLAYER_TRIGGERED_SCAR_SOURCES := {
	&"mastered_vector": true,
	&"slingshot_resonance": true,
}
const WEAPON_SCAR_SOURCE_NAMES := {
	&"apex_vector_spear": true,
	&"barycentric_splitter": true,
	&"causal_anchor": true,
	&"chronal_mirror_shot": true,
	&"chronal_refraction_beam": true,
	&"event_horizon_shard": true,
	&"event_horizon_veil": true,
	&"gravity_lance": true,
	&"gravity_loom": true,
	&"gravity_wave_beam": true,
	&"graviton_bloom": true,
	&"inertia_maul": true,
	&"inversion_chime": true,
	&"inversion_disc": true,
	&"kinetic_ram": true,
	&"mass_driver": true,
	&"mass_siphon": true,
	&"null_rebounder": true,
	&"orbital_lasso": true,
	&"phase_guillotine": true,
	&"phase_suture": true,
	&"polarity_javelin": true,
	&"positron_beam": true,
	&"resonance_anvil": true,
	&"rift_anchor": true,
	&"scar_carver": true,
	&"shear_comet": true,
	&"singularity_bell": true,
	&"singularity_kite": true,
	&"singularity_pin": true,
	&"temporal_bloom": true,
	&"temporal_splinter": true,
	&"tidal_mortar": true,
	&"vector_prism": true,
	&"vacuum_collapse_seed": true,
}

@export_group("Signal Sources")
@export var player_path: NodePath
@export var time_dilation_manager_path: NodePath
@export var gravity_resonance_manager_path: NodePath

@export_group("Quality")
@export var effects_enabled: bool = true
@export_enum("Off", "Low", "High") var visual_quality: int = 2
@export var low_performance_mode: bool = false
@export var max_active_bursts: int = 14
@export var max_particles_per_burst: int = 48
@export var min_burst_alpha: float = 0.18
@export var max_burst_alpha: float = 0.34
@export var chaos_clutter_threshold: float = 0.58
@export var chaos_sample_interval: float = 0.2
@export var prewarm_bursts_per_template: int = 4
@export var max_pooled_bursts_per_template: int = 8
@export var burst_player_focus_radius: float = 1320.0
@export var player_centered_burst_cooldown: float = 0.18
@export_group("Burst Rings")
@export var enable_burst_rings: bool = true
@export var burst_ring_min_intensity: float = 0.28
@export var max_active_burst_rings: int = 12
@export var max_pooled_burst_rings: int = 18
@export var burst_ring_lifetime: float = 0.34
@export var burst_ring_radius: float = 58.0
@export var burst_ring_width: float = 2.6
@export_range(0.0, 1.0, 0.01) var burst_ring_alpha_cap: float = 0.26
@export_group("Scar Burst Readability")
@export var suppress_player_scar_bursts: bool = true
@export_range(0.0, 1.0, 0.01) var ambient_scar_burst_visual_scale: float = 0.78

@export_group("Templates")
@export var time_afterimage_template_path: NodePath = ^"Templates/TimeAfterimageBurst"
@export var shockwave_template_path: NodePath = ^"Templates/KineticImpactBurst"
@export var resonance_template_path: NodePath = ^"Templates/ResonanceLawBurst"
@export var slingshot_template_path: NodePath = ^"Templates/SlingshotSparkleBurst"
@export var ambient_template_path: NodePath = ^"Templates/AmbientSparkBurst"

var _player: Node = null
var _time_manager: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _event_horizon: Node = null
var _momentum: Node = null
var _active_bursts: Array[GPUParticles2D] = []
var _burst_pools: Dictionary = {}
var _active_rings: Array[Dictionary] = []
var _ring_pool: Array[Line2D] = []
var _chaos_intensity: float = 0.0
var _chaos_sample_elapsed: float = 999.0
var _next_player_centered_burst_time: float = 0.0

@onready var _burst_root: Node2D = $Bursts
@onready var _time_template: GPUParticles2D = get_node_or_null(time_afterimage_template_path) as GPUParticles2D
@onready var _shockwave_template: GPUParticles2D = get_node_or_null(shockwave_template_path) as GPUParticles2D
@onready var _resonance_template: GPUParticles2D = get_node_or_null(resonance_template_path) as GPUParticles2D
@onready var _slingshot_template: GPUParticles2D = get_node_or_null(slingshot_template_path) as GPUParticles2D
@onready var _ambient_template: GPUParticles2D = get_node_or_null(ambient_template_path) as GPUParticles2D


func _ready() -> void:
	add_to_group("orbital_vfx_director")
	_resolve_sources()
	_configure_templates()
	_prewarm_burst_pools()
	_connect_sources()


func _process(delta: float) -> void:
	_prune_finished_bursts()
	_update_burst_rings(delta)
	_update_chaos_intensity(delta)


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
		if _scar_manager == null:
			_scar_manager = scene.find_child("GravityScarManager", true, false)
		if _event_horizon == null:
			_event_horizon = scene.find_child("EventHorizonDirector", true, false)
	if _player != null:
		_momentum = _player.get_node_or_null("MomentumCombatComponent")


func _configure_templates() -> void:
	for template in [_time_template, _shockwave_template, _resonance_template, _slingshot_template, _ambient_template]:
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
	_connect_signal(_scar_manager, &"gravity_scar_created", Callable(self, "_on_gravity_scar_created"))
	_connect_signal(_scar_manager, &"gravity_scar_intensified", Callable(self, "_on_gravity_scar_intensified"))
	_connect_signal(_event_horizon, &"event_horizon_started", Callable(self, "_on_event_horizon_started"))
	_connect_signal(_event_horizon, &"horizon_escape_scored", Callable(self, "_on_horizon_escape_scored"))
	_connect_signal(_momentum, &"kinetic_shockwave_created", Callable(self, "_on_kinetic_shockwave_created"))
	_connect_signal(_momentum, &"slingshot_mastery_triggered", Callable(self, "_on_slingshot_mastery_triggered"))
	_connect_signal(_momentum, &"near_miss_velocity_gained", Callable(self, "_on_near_miss_velocity_gained"))
	_connect_signal(_resonance_manager, &"resonance_zone_entered", Callable(self, "_on_resonance_zone_entered"))
	call_deferred("_connect_ambient_sources")


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
	if target == null or not is_instance_valid(target):
		return
	var target_2d := target as Node2D
	if target_2d == null:
		return
	var intensity := clampf(1.0 - multiplier, 0.18, 0.85)
	_spawn_burst(_time_template, target_2d.global_position, intensity, Color(0.78, 0.48, 1.0, 1.0))


func _on_afterimage_spawned(position: Vector2, velocity: Vector2) -> void:
	var speed_intensity := clampf(velocity.length() / 1600.0, 0.15, 0.72)
	_spawn_burst(_time_template, position, speed_intensity, Color(0.32, 1.0, 0.92, 1.0))


func _on_resonance_zone_pulsed(zone_data: Dictionary) -> void:
	var position: Vector2 = zone_data.get("midpoint", Vector2.ZERO)
	var intensity := clampf(float(zone_data.get("intensity", 0.35)), 0.12, 1.0)
	var color: Color = zone_data.get("zone_color", Color(0.2, 0.75, 1.0, 1.0))
	_spawn_burst(_resonance_template, position, intensity, color)


func _on_gravity_scar_created(scar_data: Dictionary) -> void:
	if _should_suppress_scar_burst(scar_data):
		return
	var position: Vector2 = scar_data.get("position", Vector2.ZERO)
	var intensity := clampf(float(scar_data.get("visual_intensity", scar_data.get("intensity", 0.4))) * ambient_scar_burst_visual_scale, 0.08, 0.74)
	var color: Color = scar_data.get("color", Color(0.1, 0.82, 1.0, 1.0))
	_spawn_burst(_resonance_template, position, intensity, color)


func _on_gravity_scar_intensified(scar_data: Dictionary) -> void:
	if _should_suppress_scar_burst(scar_data):
		return
	var position: Vector2 = scar_data.get("position", Vector2.ZERO)
	var intensity := clampf(float(scar_data.get("visual_intensity", scar_data.get("intensity", 0.4))) * 0.52, 0.08, 0.52)
	var color: Color = scar_data.get("color", Color(0.1, 0.82, 1.0, 1.0))
	_spawn_burst(_ambient_template, position, intensity, color)


func _should_suppress_scar_burst(scar_data: Dictionary) -> bool:
	if not suppress_player_scar_bursts:
		return false
	var source := StringName(scar_data.get("source", &"manual"))
	return PLAYER_TRIGGERED_SCAR_SOURCES.has(source) or WEAPON_SCAR_SOURCE_NAMES.has(source)


func _on_event_horizon_started(data: Dictionary) -> void:
	var position: Vector2 = data.get("position", Vector2.ZERO)
	var intensity := clampf(float(data.get("intensity", 0.8)), 0.35, 1.0)
	_spawn_burst(_time_template, position, intensity, Color(0.86, 0.38, 1.0, 1.0))
	_spawn_burst(_shockwave_template, position, intensity, Color(1.0, 0.16, 0.08, 1.0))


func _on_horizon_escape_scored(data: Dictionary) -> void:
	var player_2d := _player as Node2D
	var fallback: Vector2 = player_2d.global_position if player_2d != null else data.get("position", Vector2.ZERO)
	var intensity := clampf(float(data.get("intensity", 0.8)), 0.35, 1.0)
	_spawn_burst(_slingshot_template, fallback, intensity, Color(0.35, 1.0, 0.86, 1.0))


func _on_kinetic_shockwave_created(shockwave_data: Dictionary) -> void:
	var position: Vector2 = shockwave_data.get("position", Vector2.ZERO)
	var speed := float(shockwave_data.get("speed", 900.0))
	var intensity := clampf(speed / 2400.0, 0.25, 0.86)
	_spawn_burst(_shockwave_template, position, intensity, Color(1.0, 0.68, 0.28, 1.0))


func _connect_ambient_sources() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var wave_director := scene.find_child("WaveDirector", true, false)
	_connect_signal(wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	if _player != null:
		var inventory := _player.get_node_or_null("PowerupInventory")
		_connect_signal(inventory, &"powerup_applied", Callable(self, "_on_powerup_applied"))
		_connect_signal(inventory, &"orbital_satellite_captured", Callable(self, "_on_orbital_satellite_captured"))


func _on_near_miss_velocity_gained(_target: Node, _amount: float) -> void:
	var player_2d := _player as Node2D
	if player_2d == null:
		return
	_spawn_burst(_ambient_template, player_2d.global_position, 0.28, Color(0.55, 1.0, 0.92, 1.0))


func _on_resonance_zone_entered(zone_data: Dictionary) -> void:
	var position: Vector2 = zone_data.get("midpoint", Vector2.ZERO)
	var intensity := clampf(float(zone_data.get("intensity", 0.35)), 0.12, 0.55)
	var color: Color = zone_data.get("zone_color", Color(0.2, 0.75, 1.0, 1.0))
	_spawn_burst(_ambient_template, position, intensity, color)


func _on_wave_cleared(_wave: int) -> void:
	var player_2d := _player as Node2D
	if player_2d == null:
		return
	_spawn_burst(_ambient_template, player_2d.global_position, 0.42, Color(0.35, 1.0, 0.88, 1.0))


func spawn_enemy_death_burst(position: Vector2, velocity: Vector2 = Vector2.ZERO, is_boss: bool = false, rarity: float = 0.0) -> void:
	var speed_intensity := clampf(velocity.length() / 1400.0, 0.0, 0.55)
	var intensity := clampf(0.34 + speed_intensity + rarity * 0.2 + (0.28 if is_boss else 0.0), 0.24, 0.92)
	var core_color := Color(0.34, 1.0, 0.86, 1.0)
	var accent_color := Color(1.0, 0.68, 0.22, 1.0)
	if is_boss:
		core_color = Color(1.0, 0.28, 0.16, 1.0)
		accent_color = Color(0.55, 0.9, 1.0, 1.0)
	_spawn_burst(_shockwave_template, position, intensity, core_color)
	var offset := velocity.normalized() * 22.0 if velocity.length_squared() > 1.0 else Vector2.ZERO
	_spawn_burst(_ambient_template, position + offset, intensity * 0.72, accent_color)
	if is_boss or rarity > 0.45:
		_spawn_burst(_resonance_template, position - offset * 0.5, intensity * 0.8, Color(1.0, 0.9, 0.32, 1.0))


func _on_powerup_applied(_definition: PowerupDefinition, _stacks: int) -> void:
	var player_2d := _player as Node2D
	if player_2d == null:
		return
	_spawn_burst(_resonance_template, player_2d.global_position, 0.48, Color(1.0, 0.82, 0.28, 1.0))


func _on_orbital_satellite_captured(projectile: Node, _stacks: int) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	var projectile_2d := projectile as Node2D
	if projectile_2d == null:
		return
	_spawn_burst(_ambient_template, projectile_2d.global_position, 0.36, Color(1.0, 0.86, 0.32, 1.0))


func _on_slingshot_mastery_triggered(data: Dictionary) -> void:
	var coordinator := JuiceCoordinator.find_coordinator(get_tree())
	if coordinator != null and not coordinator.should_spawn_slingshot_vfx(data):
		return
	var player_2d := _player as Node2D
	var fallback := player_2d.global_position if player_2d != null else global_position
	var position: Vector2 = data.get("position", fallback)
	var score := clampf(float(data.get("score", 0.45)), 0.0, 1.0)
	var color: Color = Color(0.28, 1.0, 0.88, 1.0)
	if StringName(data.get("tier", &"idle")) == &"god_vector":
		color = Color(1.0, 0.86, 0.28, 1.0)
	_spawn_burst(_slingshot_template, position, minf(score, 0.76), color)


func _spawn_burst(template: GPUParticles2D, position: Vector2, intensity: float, color: Color) -> void:
	if not _can_spawn_burst(template, intensity, position):
		return

	var burst := _acquire_burst(template)
	if burst == null:
		return

	burst.visible = true
	burst.amount = _particle_amount(template.amount, intensity)
	burst.modulate = _burst_modulate(color, intensity)
	if burst.get_parent() == null:
		_burst_root.add_child(burst)
	elif burst.get_parent() != _burst_root:
		burst.reparent(_burst_root)
	burst.global_position = position
	burst.restart()
	burst.emitting = true
	_active_bursts.append(burst)
	_spawn_burst_ring(position, intensity, color)


func _can_spawn_burst(template: GPUParticles2D, intensity: float, position: Vector2) -> bool:
	if not effects_enabled or visual_quality <= 0 or template == null:
		return false
	if _chaos_intensity > chaos_clutter_threshold and intensity < 0.55:
		return false
	if not _burst_in_player_focus(position, intensity):
		return false
	if _is_player_centered_burst(position, intensity):
		var now := Time.get_ticks_msec() / 1000.0
		if now < _next_player_centered_burst_time:
			return false
		_next_player_centered_burst_time = now + maxf(player_centered_burst_cooldown, 0.02)
	return _active_bursts.size() < _active_burst_cap()


func _burst_in_player_focus(position: Vector2, intensity: float) -> bool:
	if burst_player_focus_radius <= 0.0:
		return true
	if _player == null or not is_instance_valid(_player):
		return true
	var player_2d := _player as Node2D
	if player_2d == null or player_2d.is_queued_for_deletion():
		return true
	var focus_radius: float = burst_player_focus_radius * lerpf(0.78, 1.15, clampf(intensity, 0.0, 1.0))
	return player_2d.global_position.distance_squared_to(position) <= focus_radius * focus_radius


func _is_player_centered_burst(position: Vector2, intensity: float) -> bool:
	if intensity >= 0.72 or _player == null or not is_instance_valid(_player):
		return false
	var player_2d := _player as Node2D
	if player_2d == null or player_2d.is_queued_for_deletion():
		return false
	return player_2d.global_position.distance_squared_to(position) <= 90.0 * 90.0


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
	var alpha: float = lerpf(min_burst_alpha, max_burst_alpha, clampf(intensity, 0.0, 1.0))
	if Settings != null and Settings.has_method("flash_alpha"):
		alpha = Settings.flash_alpha(alpha)
	return Color(color.r, color.g, color.b, alpha)


func _spawn_burst_ring(position: Vector2, intensity: float, color: Color) -> void:
	if not enable_burst_rings or intensity < burst_ring_min_intensity:
		return
	if visual_quality <= 0 or (low_performance_mode and intensity < 0.62):
		return
	if _active_rings.size() >= max_active_burst_rings:
		return
	var ring := _acquire_burst_ring()
	if ring == null:
		return
	var clamped := clampf(intensity, 0.0, 1.0)
	var radius := burst_ring_radius * lerpf(0.68, 1.65, clamped)
	if Settings != null and Settings.has_method("world_effect_radius"):
		radius = Settings.world_effect_radius(radius, 180.0)
	ring.global_position = position
	ring.scale = Vector2.ONE
	ring.points = _ring_points(radius, 36 if visual_quality >= 2 else 22)
	ring.width = burst_ring_width * lerpf(0.72, 1.42, clamped)
	ring.default_color = Color(color.r, color.g, color.b, _safe_ring_alpha(burst_ring_alpha_cap * clamped, burst_ring_alpha_cap))
	ring.visible = true
	_active_rings.append({
		"node": ring,
		"age": 0.0,
		"lifetime": burst_ring_lifetime * lerpf(0.78, 1.32, clamped),
		"base_width": ring.width,
		"color": color,
		"alpha": burst_ring_alpha_cap * clamped,
	})


func _update_burst_rings(delta: float) -> void:
	for idx in range(_active_rings.size() - 1, -1, -1):
		var entry := _active_rings[idx]
		var ring_value: Variant = entry.get("node")
		if ring_value == null or not is_instance_valid(ring_value):
			_active_rings.remove_at(idx)
			continue
		var ring := ring_value as Line2D
		if ring == null:
			_active_rings.remove_at(idx)
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var lifetime := maxf(float(entry.get("lifetime", burst_ring_lifetime)), 0.04)
		var t := clampf(age / lifetime, 0.0, 1.0)
		var color_value: Variant = entry.get("color", Color.WHITE)
		var color := Color.WHITE
		if color_value is Color:
			color = color_value
		var base_alpha := float(entry.get("alpha", burst_ring_alpha_cap))
		ring.scale = Vector2.ONE * lerpf(1.0, 1.72, t)
		ring.width = float(entry.get("base_width", burst_ring_width)) * lerpf(1.0, 0.18, t)
		ring.default_color = Color(color.r, color.g, color.b, _safe_ring_alpha(base_alpha * pow(1.0 - t, 1.4), burst_ring_alpha_cap))
		entry["age"] = age
		_active_rings[idx] = entry
		if age >= lifetime:
			_release_burst_ring(ring)
			_active_rings.remove_at(idx)


func _acquire_burst_ring() -> Line2D:
	for ring in _ring_pool:
		if ring != null and is_instance_valid(ring) and not ring.visible:
			return ring
	if _ring_pool.size() >= max_pooled_burst_rings:
		return null
	var ring := Line2D.new()
	ring.name = "PooledBurstRing"
	ring.closed = true
	ring.antialiased = true
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	ring.z_index = 41
	ring.visible = false
	_burst_root.add_child(ring)
	_ring_pool.append(ring)
	return ring


func _release_burst_ring(ring: Line2D) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	ring.visible = false
	ring.scale = Vector2.ONE
	if ring.get_parent() == null:
		_burst_root.add_child(ring)
	elif ring.get_parent() != _burst_root:
		ring.reparent(_burst_root)


func _ring_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(segments, 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _safe_ring_alpha(alpha: float, hard_cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, hard_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), hard_cap)
	return minf(alpha, hard_cap)


func _prune_finished_bursts() -> void:
	for idx in range(_active_bursts.size() - 1, -1, -1):
		var burst := _active_bursts[idx]
		if burst == null or not is_instance_valid(burst):
			_active_bursts.remove_at(idx)
			continue
		if not burst.emitting:
			_release_burst(burst)
			_active_bursts.remove_at(idx)


func _update_chaos_intensity(delta: float) -> void:
	_chaos_sample_elapsed += delta
	if _chaos_sample_elapsed < maxf(chaos_sample_interval, 0.05):
		return
	_chaos_sample_elapsed = 0.0
	var projectile_count := 0
	if RuntimeRegistry != null:
		projectile_count = RuntimeRegistry.get_count(&"Projectiles")
		projectile_count += RuntimeRegistry.get_count(&"enemy_projectiles")
	else:
		projectile_count = get_tree().get_nodes_in_group("Projectiles").size()
		projectile_count += get_tree().get_nodes_in_group("enemy_projectiles").size()
	var target_chaos := clampf(float(projectile_count) / 180.0, 0.0, 1.0)
	_chaos_intensity = lerpf(_chaos_intensity, target_chaos, 0.08)


func get_vfx_debug_state() -> Dictionary:
	return {
		"active_bursts": _active_bursts.size(),
		"burst_cap": _active_burst_cap(),
		"pooled_bursts": _count_pooled_bursts(),
		"chaos": _chaos_intensity,
		"quality": visual_quality,
		"low_performance": low_performance_mode,
	}


func _prewarm_burst_pools() -> void:
	for template in [_time_template, _shockwave_template, _resonance_template, _slingshot_template, _ambient_template]:
		if template == null:
			continue
		var key := _template_key(template)
		if not _burst_pools.has(key):
			_burst_pools[key] = []
		var pool: Array = _burst_pools[key]
		while pool.size() < prewarm_bursts_per_template:
			var burst := _create_burst_instance(template, key)
			if burst == null:
				break
			pool.append(burst)
		_burst_pools[key] = pool


func _acquire_burst(template: GPUParticles2D) -> GPUParticles2D:
	var key := _template_key(template)
	if not _burst_pools.has(key):
		_burst_pools[key] = []

	var pool: Array = _burst_pools[key]
	for value in pool:
		var burst := value as GPUParticles2D
		if burst != null and is_instance_valid(burst) and not burst.visible and not burst.emitting:
			return burst

	if pool.size() >= max_pooled_bursts_per_template:
		return null

	var created := _create_burst_instance(template, key)
	if created == null:
		return null
	pool.append(created)
	_burst_pools[key] = pool
	return created


func _create_burst_instance(template: GPUParticles2D, key: StringName) -> GPUParticles2D:
	var burst := template.duplicate() as GPUParticles2D
	if burst == null:
		return null
	burst.name = "%sPooled" % String(key)
	burst.visible = false
	burst.emitting = false
	burst.one_shot = true
	burst.set_meta(&"vfx_pool_key", key)
	_burst_root.add_child(burst)
	return burst


func _release_burst(burst: GPUParticles2D) -> void:
	burst.emitting = false
	burst.visible = false
	burst.modulate = Color.WHITE
	if burst.get_parent() == null:
		_burst_root.add_child(burst)
	elif burst.get_parent() != _burst_root:
		burst.reparent(_burst_root)


func _template_key(template: GPUParticles2D) -> StringName:
	return StringName(template.name)


func _count_pooled_bursts() -> int:
	var count := 0
	for value in _burst_pools.values():
		var pool := value as Array
		count += pool.size()
	return count
