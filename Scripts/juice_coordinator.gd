extends Node
class_name JuiceCoordinator

## Tiered juice budgets: readable law first, spectacle second.
## Other systems query this node instead of stacking every feedback layer.

signal slingshot_tier_resolved(tier: StringName, score: float)

@export_group("Slingshot Tiers")
@export var assist_max_score: float = 0.38
@export var good_max_score: float = 0.7
@export var great_ring_min_score: float = 0.7

@export_group("Slingshot Gates")
@export var assist_thruster_only: bool = true
@export var good_vfx_or_ring_not_both: bool = true
@export var good_camera_kick_scale: float = 0.35
@export var great_camera_kick_scale: float = 1.0
@export var god_vector_camera_kick_scale: float = 1.15

@export_group("Impact Gates")
@export var skip_impact_ring_when_shockwave: bool = true
@export var impact_ring_chaos_threshold: float = 0.62

@export_group("Performance")
@export var low_performance_mode: bool = false
@export var disable_mastery_line2d: bool = false


func _ready() -> void:
	add_to_group("juice_coordinator")


static func find_coordinator(tree: SceneTree) -> JuiceCoordinator:
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("juice_coordinator")
	for node in nodes:
		if node is JuiceCoordinator:
			return node as JuiceCoordinator
	return null


func resolve_slingshot_tier(score: float, tier_name: StringName = &"") -> StringName:
	if tier_name == &"god_vector":
		return &"god_vector"
	if score >= mastery_apex_equiv():
		return &"great"
	if score >= good_max_score:
		return &"great"
	if score >= assist_max_score:
		return &"good"
	return &"assist"


func mastery_apex_equiv() -> float:
	return 0.94


func slingshot_tier_from_data(data: Dictionary) -> StringName:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	var tier := StringName(data.get("tier", &""))
	return resolve_slingshot_tier(score, tier)


func emit_slingshot_tier(data: Dictionary) -> StringName:
	var tier := slingshot_tier_from_data(data)
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	slingshot_tier_resolved.emit(tier, score)
	return tier


func should_spawn_slingshot_vfx(data: Dictionary) -> bool:
	if low_performance_mode:
		return false
	var tier := slingshot_tier_from_data(data)
	if tier == &"assist":
		return false
	if tier == &"good" and good_vfx_or_ring_not_both and should_spawn_slingshot_ring(data):
		return false
	return true


func should_spawn_slingshot_ring(data: Dictionary) -> bool:
	if low_performance_mode or disable_mastery_line2d:
		return false
	var tier := slingshot_tier_from_data(data)
	if tier == &"assist":
		return false
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if tier == &"good" and good_vfx_or_ring_not_both:
		return true
	return score >= great_ring_min_score


func should_apply_slingshot_camera(data: Dictionary) -> bool:
	var tier := slingshot_tier_from_data(data)
	if tier == &"assist":
		return false
	return camera_kick_scale_for_tier(tier) > 0.01


func camera_kick_scale_for_tier(tier: StringName) -> float:
	match tier:
		&"god_vector":
			return god_vector_camera_kick_scale
		&"great":
			return great_camera_kick_scale
		&"good":
			return good_camera_kick_scale
		_:
			return 0.0


func should_boost_thrusters_for_slingshot(data: Dictionary) -> bool:
	return slingshot_tier_from_data(data) != &"assist"


func should_play_slingshot_audio(data: Dictionary) -> bool:
	return slingshot_tier_from_data(data) != &"assist"


func should_spawn_impact_mastery_ring(chaos_intensity: float, shockwave_spawned: bool) -> bool:
	if low_performance_mode:
		return false
	if skip_impact_ring_when_shockwave and shockwave_spawned:
		return false
	if chaos_intensity >= impact_ring_chaos_threshold and shockwave_spawned:
		return false
	return true


func get_chaos_intensity(tree: SceneTree) -> float:
	if tree == null:
		return 0.0
	if RuntimeRegistry != null:
		var cached_count := RuntimeRegistry.get_count(&"Projectiles")
		cached_count += RuntimeRegistry.get_count(&"enemy_projectiles")
		return clampf(float(cached_count) / 180.0, 0.0, 1.0)
	var count := tree.get_nodes_in_group("Projectiles").size()
	count += tree.get_nodes_in_group("enemy_projectiles").size()
	return clampf(float(count) / 180.0, 0.0, 1.0)
