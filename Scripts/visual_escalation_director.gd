extends Node
class_name VisualEscalationDirector

## Pushes run-phase visual presets without owning gameplay logic.

signal visual_phase_changed(phase: StringName, wave: int)

@export var enabled: bool = true
@export var update_interval: float = 0.35

@export_group("Early Run")
@export var early_glow_intensity: float = 0.55
@export var early_particle_scale: float = 0.72
@export var early_vfx_burst_cap: int = 10

@export_group("Mid Run")
@export var mid_glow_intensity: float = 0.85
@export var mid_particle_scale: float = 0.82
@export var mid_vfx_burst_cap: int = 12

@export_group("Late Run")
@export var late_glow_intensity: float = 0.95
@export var late_particle_scale: float = 0.9
@export var late_vfx_burst_cap: int = 14

@export_group("Rupture")
@export var rupture_glow_intensity: float = 1.08
@export var rupture_particle_scale: float = 0.96
@export var rupture_vfx_burst_cap: int = 16

var _elapsed := 0.0
var _current_phase: StringName = &"early"
var _run_progress: Node = null


func _ready() -> void:
	add_to_group("visual_escalation_director")
	call_deferred("_resolve_run_progress")


func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	_apply_phase_for_current_run()


func _resolve_run_progress() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_run_progress = scene.find_child("WaveDirector", true, false)
	if _run_progress == null:
		_run_progress = scene.find_child("RunDirector", true, false)


func _apply_phase_for_current_run() -> void:
	var wave := _current_wave()
	var phase := _phase_for_wave(wave)
	if phase == _current_phase and _elapsed > 0.0:
		return
	_current_phase = phase
	_apply_presets(phase, wave)
	visual_phase_changed.emit(phase, wave)


func _current_wave() -> int:
	if _run_progress != null and _run_progress.has_method("get_current_wave"):
		return int(_run_progress.call("get_current_wave"))
	var wave_director := get_tree().current_scene.find_child("WaveDirector", true, false)
	if wave_director != null and wave_director.has_method("get_current_wave"):
		return int(wave_director.call("get_current_wave"))
	return 1


func _phase_for_wave(wave: int) -> StringName:
	if wave >= 31:
		return &"rupture"
	if wave >= 18:
		return &"late"
	if wave >= 8:
		return &"mid"
	return &"early"


func _apply_presets(phase: StringName, wave: int) -> void:
	var glow := early_glow_intensity
	var particle_scale := early_particle_scale
	var burst_cap := early_vfx_burst_cap
	match phase:
		&"mid":
			glow = mid_glow_intensity
			particle_scale = mid_particle_scale
			burst_cap = mid_vfx_burst_cap
		&"late":
			glow = late_glow_intensity
			particle_scale = late_particle_scale
			burst_cap = late_vfx_burst_cap
		&"rupture":
			glow = rupture_glow_intensity
			particle_scale = rupture_particle_scale
			burst_cap = rupture_vfx_burst_cap

	var world_env := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		world_env.environment.glow_intensity = glow

	var vfx := get_tree().get_first_node_in_group("orbital_vfx_director")
	if vfx != null and vfx.get("max_active_bursts") != null:
		vfx.set("max_active_bursts", burst_cap)

	var resonance := get_tree().current_scene.find_child("GravityResonanceManager", true, false)
	if resonance != null and resonance.get("max_visual_particles_per_zone") != null:
		var base := 24 if phase == &"early" else 34
		if phase == &"late" or phase == &"rupture":
			base = 42
		resonance.set("max_visual_particles_per_zone", int(float(base) * particle_scale))

	var player := get_tree().get_first_node_in_group("Player")
	if player != null:
		var gravity_viz := player.get_node_or_null("GravityVisualizationComponent")
		if gravity_viz != null and gravity_viz.get("visible") != null:
			if phase == &"early" and wave <= 4:
				gravity_viz.set("visible", true)
			elif phase != &"early":
				gravity_viz.set("visible", true)
