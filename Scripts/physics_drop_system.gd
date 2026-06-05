extends Node
class_name PhysicsDropSystem

signal drop_sequence_spawned(enemy: Node, drops: Array, data: Dictionary)
signal drop_collected(drop_type: int, data: Dictionary)
signal drop_expired(drop_type: int, data: Dictionary)

const PHYSICS_DROP_SCENE = preload("res://Nodes/physics_drop.tscn")

@export var enabled: bool = true
@export var max_active_drops: int = 38
@export var fragment_base_count: int = 1
@export var fragment_wave_bonus_interval: int = 7
@export var momentum_orb_chance: float = 0.22
@export var uncommon_drop_wave: int = 3
@export var gravity_residue_chance: float = 0.18
@export var temporal_charge_chance: float = 0.12
@export var rare_drop_wave: int = 8
@export var instability_shard_chance: float = 0.07
@export var anomaly_seed_chance: float = 0.045
@export var elite_health_threshold: float = 180.0
@export var elite_bonus_chance: float = 0.32
@export var drop_spread_radius: float = 66.0

var _active_drops: Array[Node] = []
var _wave_director: Node = null
var _sequence: int = 0
var _spawn_source_enemy_name: String = ""


func _ready() -> void:
	add_to_group("physics_drop_system")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_resolve_sources")


func _process(_delta: float) -> void:
	_cleanup_drops()


func register_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var health := enemy.get_node_or_null("HealthComponent")
	if health == null or not health.has_signal(&"died"):
		return
	var callback := Callable(self, "_on_registered_enemy_died").bind(enemy)
	if not health.is_connected(&"died", callback):
		health.connect(&"died", callback, CONNECT_ONE_SHOT)


func try_spawn_for_enemy(enemy: Node, position: Vector2, is_boss: bool = false) -> Array[Node]:
	var spawned: Array[Node] = []
	if not enabled or enemy == null:
		return spawned
	var parent := _spawn_parent(enemy)
	if parent == null:
		return spawned
	var rng := _rng_for_enemy(enemy)
	var wave := _current_wave()
	var rarity := _rarity_for_enemy(enemy, is_boss, wave)
	_spawn_source_enemy_name = String(enemy.name)

	_spawn_fragments(parent, position, rng, rarity, wave, spawned)
	_try_spawn_optional(parent, position, rng, rarity, wave, is_boss, spawned)

	if is_boss:
		_spawn_drop(parent, PhysicsDrop.DropType.CELESTIAL_CORE, 5, position, rng, 1.0, _boss_core_definition(enemy), spawned)
		_spawn_drop(parent, PhysicsDrop.DropType.ANOMALY_SEED, 4, position, rng, 2.0, null, spawned)

	_trim_to_budget()
	_spawn_source_enemy_name = ""
	drop_sequence_spawned.emit(enemy, spawned, {
		"wave": wave,
		"rarity": rarity,
		"is_boss": is_boss,
		"count": spawned.size(),
	})
	return spawned


func _on_registered_enemy_died(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_2d := enemy as Node2D
	if enemy_2d == null:
		return
	try_spawn_for_enemy(enemy, enemy_2d.global_position, _is_boss_enemy(enemy))


func _spawn_fragments(parent: Node, position: Vector2, rng: RandomNumberGenerator, rarity: int, wave: int, spawned: Array[Node]) -> void:
	var count := maxi(fragment_base_count, 0)
	if fragment_wave_bonus_interval > 0:
		count += int(float(maxi(wave, 1)) / float(fragment_wave_bonus_interval))
	count += mini(rarity, 2)
	for _i in range(clampi(count, 0, 6)):
		_spawn_drop(parent, PhysicsDrop.DropType.FRAGMENT, rarity, position, rng, 1.0, null, spawned)


func _try_spawn_optional(parent: Node, position: Vector2, rng: RandomNumberGenerator, rarity: int, wave: int, is_boss: bool, spawned: Array[Node]) -> void:
	var elite_bonus := elite_bonus_chance if rarity >= 3 else 0.0
	if rng.randf() <= momentum_orb_chance + elite_bonus * 0.35:
		_spawn_drop(parent, PhysicsDrop.DropType.MOMENTUM_ORB, rarity, position, rng, 1.0 + float(rarity), null, spawned)
	if wave >= uncommon_drop_wave:
		if rng.randf() <= gravity_residue_chance + elite_bonus:
			_spawn_drop(parent, PhysicsDrop.DropType.GRAVITY_RESIDUE, rarity, position, rng, 1.0 + float(rarity), null, spawned)
		if rng.randf() <= temporal_charge_chance + elite_bonus * 0.5:
			_spawn_drop(parent, PhysicsDrop.DropType.TEMPORAL_CHARGE, rarity, position, rng, 1.0 + float(rarity), null, spawned)
	if wave >= rare_drop_wave or is_boss:
		if rng.randf() <= instability_shard_chance + elite_bonus * 0.35:
			_spawn_drop(parent, PhysicsDrop.DropType.INSTABILITY_SHARD, rarity, position, rng, 1.0 + float(rarity), null, spawned)
		if rng.randf() <= anomaly_seed_chance + elite_bonus * 0.25:
			_spawn_drop(parent, PhysicsDrop.DropType.ANOMALY_SEED, rarity, position, rng, 1.0 + float(rarity), null, spawned)


func _spawn_drop(
	parent: Node,
	drop_type: int,
	rarity: int,
	position: Vector2,
	rng: RandomNumberGenerator,
	value: float,
	definition: PowerupDefinition,
	spawned: Array[Node]
) -> Node:
	if parent == null:
		return null
	var drop := PHYSICS_DROP_SCENE.instantiate() as PhysicsDrop
	if drop == null:
		return null
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(drop_spread_radius * 0.18, drop_spread_radius)
	var impulse := Vector2.RIGHT.rotated(angle) * rng.randf_range(110.0, 280.0)
	drop.configure(drop_type, rarity, impulse, value, definition)
	_sequence += 1
	drop.set_meta(&"source_enemy", _spawn_source_enemy_name)
	drop.set_meta(&"source_wave", _current_wave())
	drop.set_meta(&"drop_sequence", _sequence)
	drop.global_position = position + Vector2.RIGHT.rotated(angle) * distance
	drop.physics_drop_collected.connect(Callable(self, "_on_drop_collected"))
	drop.physics_drop_expired.connect(Callable(self, "_on_drop_expired"))
	parent.call_deferred("add_child", drop)
	_active_drops.append(drop)
	spawned.append(drop)
	return drop


func _rng_for_enemy(enemy: Node) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var seed_value := int(RunProgress.run_seed if RunProgress != null else 1)
	var wave := _current_wave()
	var enemy_position := Vector2.ZERO
	var enemy_2d := enemy as Node2D
	if enemy_2d != null:
		enemy_position = Vector2(round(enemy_2d.global_position.x), round(enemy_2d.global_position.y))
	rng.seed = absi(hash("%d:%d:%s:%d:%d" % [seed_value, wave, enemy.name, int(enemy_position.x), int(enemy_position.y)]))
	return rng


func _rarity_for_enemy(enemy: Node, is_boss: bool, wave: int) -> int:
	if is_boss:
		return 5
	var rarity := 0
	var health := enemy.get_node_or_null("HealthComponent")
	if health != null:
		var max_health_value: Variant = health.get("max_health")
		if max_health_value is float or max_health_value is int:
			if float(max_health_value) >= elite_health_threshold:
				rarity = 3
	if enemy.is_in_group("elite") or enemy.is_in_group("rare_enemy"):
		rarity = max(rarity, 3)
	if wave >= rare_drop_wave:
		rarity = max(rarity, 1)
	return clampi(rarity, 0, 5)


func _boss_core_definition(enemy: Node) -> PowerupDefinition:
	var index := absi(hash("%s:%d" % [enemy.name, _current_wave()])) % 5
	match index:
		0:
			return PowerupLibrary.APEX_VECTOR_CORE
		1:
			return PowerupLibrary.BARYCENTRIC_TETHER
		2:
			return PowerupLibrary.FRAME_DRAGGING_ANCHOR
		3:
			return PowerupLibrary.RELATIVISTIC_RAIL
	return PowerupLibrary.ORBITAL_DEBRIS_SEEDER


func _spawn_parent(enemy: Node) -> Node:
	var parent := enemy.get_parent()
	if parent != null:
		return parent
	return get_tree().current_scene


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	if root != null:
		_wave_director = root.find_child("WaveDirector", true, false)


func _current_wave() -> int:
	if _wave_director == null or not is_instance_valid(_wave_director):
		_resolve_sources()
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return int(RunProgress.wave_index if RunProgress != null else 1)


func _is_boss_enemy(enemy: Node) -> bool:
	return enemy.is_in_group("bosses") or enemy.has_signal("boss_defeated")


func _cleanup_drops() -> void:
	for i in range(_active_drops.size() - 1, -1, -1):
		var drop := _active_drops[i]
		if drop == null or not is_instance_valid(drop) or drop.is_queued_for_deletion():
			_active_drops.remove_at(i)


func _on_drop_collected(drop_type: int, data: Dictionary) -> void:
	_record_drop_stat(&"physics_drops_collected")
	_record_drop_type_stat(&"physics_drop_collected", drop_type)
	drop_collected.emit(drop_type, data)


func _on_drop_expired(drop_type: int, data: Dictionary) -> void:
	_record_drop_stat(&"physics_drops_expired")
	_record_drop_type_stat(&"physics_drop_expired", drop_type)
	drop_expired.emit(drop_type, data)


func _record_drop_stat(key: StringName) -> void:
	if RunProgress == null:
		return
	var stat_key := String(key)
	RunProgress.arena_flags[stat_key] = int(RunProgress.arena_flags.get(stat_key, 0)) + 1


func _record_drop_type_stat(prefix: StringName, drop_type: int) -> void:
	if RunProgress == null:
		return
	var type_name := String(PhysicsDrop.TYPE_NAMES.get(drop_type, &"unknown"))
	var key := "%s_%s" % [String(prefix), type_name]
	RunProgress.arena_flags[key] = int(RunProgress.arena_flags.get(key, 0)) + 1


func _trim_to_budget() -> void:
	_cleanup_drops()
	while _active_drops.size() > max_active_drops:
		var oldest = _active_drops.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()
