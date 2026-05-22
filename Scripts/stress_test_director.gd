extends Node2D
class_name StressTestDirector

## Disabled-by-default arena stress harness for projectile, gravity well, and
## velocity extremes. Enable from OrbitalJuiceManager or this node's inspector.

const PROJECTILE_SCENE := preload("res://Nodes/projectile.tscn")
const ENEMY_BULLET_SCENE := preload("res://Nodes/enemy_bullet.tscn")
const BLACK_HOLE_SCENE := preload("res://Nodes/black_hole.tscn")

@export var enabled: bool = false
@export var run_on_ready: bool = false
@export var projectile_count: int = 220
@export var gravity_well_count: int = 6
@export var spawn_radius: float = 980.0
@export var extreme_velocity: float = 1850.0
@export var max_spawned_nodes: int = 360

var _player: Node2D = null
var _spawned: Array[Node] = []


func _ready() -> void:
	add_to_group("stress_test_director")
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if enabled and run_on_ready:
		call_deferred("run_extreme_arena_stress")


func run_extreme_arena_stress() -> void:
	if not enabled:
		return
	_clear_spawned()
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	var origin := _player.global_position if _player != null else global_position
	_spawn_gravity_wells(origin)
	_spawn_projectile_storm(origin)
	call_deferred("validate_performance_budgets")


func clear_stress_test() -> void:
	_clear_spawned()


func _spawn_gravity_wells(origin: Vector2) -> void:
	var count := mini(gravity_well_count, max_spawned_nodes)
	for i in range(count):
		var well := BLACK_HOLE_SCENE.instantiate()
		well.name = "StressGravityWell%d" % i
		get_tree().current_scene.add_child(well)
		var well_2d := well as Node2D
		if well_2d != null:
			var angle := TAU * float(i) / float(maxi(count, 1))
			well_2d.global_position = origin + Vector2(cos(angle), sin(angle)) * spawn_radius * 0.72
		_spawned.append(well)


func _spawn_projectile_storm(origin: Vector2) -> void:
	var remaining_slots := maxi(max_spawned_nodes - _spawned.size(), 0)
	var count := mini(projectile_count, remaining_slots)
	for i in range(count):
		var scene := PROJECTILE_SCENE if i % 2 == 0 else ENEMY_BULLET_SCENE
		var projectile := scene.instantiate()
		projectile.name = "StressProjectile%d" % i
		get_tree().current_scene.add_child(projectile)

		var body := projectile as RigidBody2D
		if body != null:
			var angle := TAU * float(i) / float(maxi(count, 1))
			var radial := Vector2(cos(angle), sin(angle))
			body.global_position = origin + radial * spawn_radius
			body.linear_velocity = radial.orthogonal() * extreme_velocity + -radial * extreme_velocity * 0.28
			body.set_meta(&"stress_test_spawned", true)

		_spawned.append(projectile)


func validate_performance_budgets() -> Dictionary:
	var scene := get_tree().current_scene
	var report := {
		"fps": Engine.get_frames_per_second(),
		"projectiles": get_tree().get_nodes_in_group("Projectiles").size(),
		"enemy_projectiles": get_tree().get_nodes_in_group("enemy_projectiles").size(),
		"within_budget": true,
	}
	if scene == null:
		return report

	var budget := scene.find_child("PerformanceBudgetDirector", true, false)
	if budget != null and budget.has_method("apply_budgets"):
		budget.call("apply_budgets")
	if budget != null and budget.has_method("get_budget_debug_state"):
		report.merge(budget.call("get_budget_debug_state"), true)

	var vfx := scene.find_child("OrbitalVFXDirector", true, false)
	if vfx != null and vfx.has_method("get_vfx_debug_state"):
		var vfx_state: Dictionary = vfx.call("get_vfx_debug_state")
		report["vfx"] = vfx_state
		var burst_cap := int(vfx_state.get("burst_cap", 99))
		var active_bursts := int(vfx_state.get("active_bursts", 0))
		report["within_budget"] = active_bursts <= burst_cap

	var resonance := scene.find_child("GravityResonanceManager", true, false)
	if resonance != null:
		report["resonance_particle_cap"] = resonance.get("max_visual_particles_per_zone")

	return report


func _clear_spawned() -> void:
	for node in _spawned:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_spawned.clear()


func get_stress_debug_state() -> Dictionary:
	return {
		"enabled": enabled,
		"spawned": _spawned.size(),
		"projectile_count": projectile_count,
		"gravity_well_count": gravity_well_count,
	}
