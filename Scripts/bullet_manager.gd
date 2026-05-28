extends Node

## Global manager for capping enemy bullet count to prevent performance issues
## and bullet spam. Enemies should check can_spawn_bullet() before instantiating.

signal bullet_count_changed(count: int, cap: int)

@export var max_enemy_bullets: int = 50
@export var enable_debug_logging: bool = false

var _bullet_count: int = 0
var _refresh_interval: float = 0.5
var _refresh_elapsed: float = 0.0


func _ready() -> void:
	add_to_group("bullet_manager")
	set_process(true)


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= _refresh_interval:
		_refresh_elapsed = 0.0
		_refresh_bullet_count()


func _refresh_bullet_count() -> void:
	var previous_count := _bullet_count
	_bullet_count = get_tree().get_nodes_in_group("enemy_projectiles").size()
	
	if _bullet_count != previous_count:
		bullet_count_changed.emit(_bullet_count, max_enemy_bullets)
		if enable_debug_logging:
			print("BulletManager: Count updated from ", previous_count, " to ", _bullet_count, "/", max_enemy_bullets)


func can_spawn_bullet() -> bool:
	_refresh_bullet_count()
	var can_spawn := _bullet_count < max_enemy_bullets
	
	if enable_debug_logging and not can_spawn:
		print("BulletManager: Spawn blocked - at cap ", _bullet_count, "/", max_enemy_bullets)
	
	return can_spawn


func get_bullet_count() -> int:
	_refresh_bullet_count()
	return _bullet_count


func get_bullet_cap() -> int:
	return max_enemy_bullets


func get_bullet_usage_ratio() -> float:
	_refresh_bullet_count()
	return float(_bullet_count) / float(maxi(max_enemy_bullets, 1))
