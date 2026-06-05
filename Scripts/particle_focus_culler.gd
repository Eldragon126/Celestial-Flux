extends Node
class_name ParticleFocusCuller

## Throttled particle visibility gate. Gameplay nodes stay alive, but expensive
## particle rendering is disabled while the effect is far from the screen/player.

@export var enabled: bool = true
@export var scan_interval: float = 1.0
@export var focus_refresh_interval: float = 0.18
@export var player_focus_radius: float = 1700.0
@export var screen_margin: float = 340.0
@export var include_player_children: bool = true

var _player: Node2D = null
var _scan_elapsed: float = 999.0
var _focus_elapsed: float = 999.0
var _particle_nodes: Array[Node2D] = []
var _desired_visible: Dictionary = {}
var _desired_emitting: Dictionary = {}
var _was_enabled: bool = true


func _ready() -> void:
	add_to_group("particle_focus_culler")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)
	call_deferred("_scan_particles")


func _process(delta: float) -> void:
	if not enabled:
		if _was_enabled:
			_restore_tracked_particles()
		_was_enabled = false
		return
	if not _was_enabled:
		_was_enabled = true
		_scan_elapsed = 999.0
		_focus_elapsed = 999.0
	_scan_elapsed += delta
	_focus_elapsed += delta
	if _scan_elapsed >= maxf(scan_interval, 0.2):
		_scan_elapsed = 0.0
		_scan_particles()
	if _focus_elapsed >= maxf(focus_refresh_interval, 0.05):
		_focus_elapsed = 0.0
		_update_focus()


func _scan_particles() -> void:
	_particle_nodes.clear()
	_resolve_player()
	var root := get_tree().current_scene
	if root == null:
		return
	_collect_particles(root)
	var active_ids := {}
	for particle in _particle_nodes:
		active_ids[particle.get_instance_id()] = true
	for id in _desired_emitting.keys():
		if not active_ids.has(id):
			_desired_emitting.erase(id)
	for id in _desired_visible.keys():
		if not active_ids.has(id):
			_desired_visible.erase(id)


func _collect_particles(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node is GPUParticles2D or node is CPUParticles2D:
		var particle := node as Node2D
		if particle != null and _should_track_particle(particle):
			_particle_nodes.append(particle)
	for child in node.get_children():
		_collect_particles(child)


func _should_track_particle(particle: Node2D) -> bool:
	if particle.is_in_group("particle_focus_exempt"):
		return false
	if include_player_children:
		return true
	return _player == null or not _player.is_ancestor_of(particle)


func _update_focus() -> void:
	_resolve_player()
	for index in range(_particle_nodes.size() - 1, -1, -1):
		var particle := _particle_nodes[index]
		if particle == null or not is_instance_valid(particle) or particle.is_queued_for_deletion():
			_particle_nodes.remove_at(index)
			continue
		_apply_focus_state(particle, _is_particle_in_focus(particle))


func _apply_focus_state(particle: Node2D, in_focus: bool) -> void:
	var id := particle.get_instance_id()
	if not in_focus:
		if not _desired_visible.has(id):
			_desired_visible[id] = particle.visible
		particle.visible = false
	else:
		if _desired_visible.has(id):
			particle.visible = bool(_desired_visible[id])
			_desired_visible.erase(id)
	if particle is GPUParticles2D:
		_apply_gpu_focus(particle as GPUParticles2D, in_focus)
	elif particle is CPUParticles2D:
		_apply_cpu_focus(particle as CPUParticles2D, in_focus)


func _apply_gpu_focus(particles: GPUParticles2D, in_focus: bool) -> void:
	if particles.one_shot:
		return
	var id := particles.get_instance_id()
	if not in_focus:
		_desired_emitting[id] = bool(_desired_emitting.get(id, false)) or particles.emitting
		particles.emitting = false
		return
	if bool(_desired_emitting.get(id, particles.emitting)):
		particles.emitting = true
	_desired_emitting.erase(id)


func _apply_cpu_focus(particles: CPUParticles2D, in_focus: bool) -> void:
	if particles.one_shot:
		return
	var id := particles.get_instance_id()
	if not in_focus:
		_desired_emitting[id] = bool(_desired_emitting.get(id, false)) or particles.emitting
		particles.emitting = false
		return
	if bool(_desired_emitting.get(id, particles.emitting)):
		particles.emitting = true
	_desired_emitting.erase(id)


func _is_particle_in_focus(particle: Node2D) -> bool:
	if _player != null and is_instance_valid(_player):
		var focus_radius := maxf(player_focus_radius, 1.0)
		if particle.global_position.distance_squared_to(_player.global_position) <= focus_radius * focus_radius:
			return true
	return _is_on_or_near_screen(particle.global_position)


func _is_on_or_near_screen(world_position: Vector2) -> bool:
	var viewport_rect := get_viewport().get_visible_rect()
	var viewport_size := viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return true
	var screen_position := get_viewport().get_canvas_transform() * world_position
	return (
		screen_position.x >= -screen_margin
		and screen_position.y >= -screen_margin
		and screen_position.x <= viewport_size.x + screen_margin
		and screen_position.y <= viewport_size.y + screen_margin
	)


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("Player") as Node2D


func _restore_tracked_particles() -> void:
	for particle in _particle_nodes:
		if particle == null or not is_instance_valid(particle) or particle.is_queued_for_deletion():
			continue
		var id := particle.get_instance_id()
		particle.visible = bool(_desired_visible.get(id, particle.visible))
		if particle is GPUParticles2D:
			var gpu := particle as GPUParticles2D
			if not gpu.one_shot and bool(_desired_emitting.get(id, gpu.emitting)):
				gpu.emitting = true
		elif particle is CPUParticles2D:
			var cpu := particle as CPUParticles2D
			if not cpu.one_shot and bool(_desired_emitting.get(id, cpu.emitting)):
				cpu.emitting = true
	_desired_visible.clear()
	_desired_emitting.clear()
