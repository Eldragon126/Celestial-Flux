extends StaticBody2D
class_name CampaignMotherPlanet

signal health_changed(current_health: float, max_health: float)
signal mother_planet_destroyed

@export var max_health: float = 1600.0
@export var starting_health: float = -1.0
@export var base_mass: float = 420000.0
@export var radius: float = 220.0
@export var shield_radius: float = 310.0
@export_range(0.0, 1.0, 0.01) var gravity_ring_alpha: float = 0.18
@export var armor_upgrade_health_bonus: float = 240.0
@export var repair_per_credit: float = 5.0
@export var damaged_hull_color: Color = Color(0.12, 0.26, 0.9, 0.92)
@export var healthy_hull_color: Color = Color(0.12, 0.74, 0.9, 0.92)
@export var shield_color: Color = Color(0.24, 0.94, 1.0, 0.18)
@export var health_low_color: Color = Color(1.0, 0.22, 0.34, 0.88)
@export var health_high_color: Color = Color(0.22, 1.0, 0.34, 0.88)

var current_health: float = 1600.0
var mass: float = 420000.0

@onready var hull: Polygon2D = get_node_or_null("MotherPlanetHull") as Polygon2D
@onready var gravity_ring: Line2D = get_node_or_null("GravityShieldRing") as Line2D
@onready var health_ring: Line2D = get_node_or_null("HealthRing") as Line2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	add_to_group("campaign_mother_planet")
	add_to_group("player_allies")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	mass = base_mass
	current_health = max_health if starting_health < 0.0 else clampf(starting_health, 0.0, max_health)
	_ensure_scene_children()
	_update_geometry()
	_update_visuals()
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	_update_visuals()
	if current_health <= 0.0:
		mother_planet_destroyed.emit()


func repair(amount: float) -> float:
	if amount <= 0.0 or current_health <= 0.0:
		return 0.0
	var previous := current_health
	current_health = minf(current_health + amount, max_health)
	var repaired := current_health - previous
	if repaired > 0.0:
		health_changed.emit(current_health, max_health)
		_update_visuals()
	return repaired


func upgrade_armor(levels: int = 1) -> void:
	var bonus := armor_upgrade_health_bonus * float(maxi(levels, 1))
	max_health += bonus
	current_health += bonus
	radius += 8.0 * float(maxi(levels, 1))
	shield_radius += 12.0 * float(maxi(levels, 1))
	mass = base_mass * (radius / 220.0)
	_update_geometry()
	_update_visuals()
	health_changed.emit(current_health, max_health)


func get_health_ratio() -> float:
	return clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)


func _ensure_scene_children() -> void:
	if hull == null:
		hull = Polygon2D.new()
		hull.name = "MotherPlanetHull"
		add_child(hull)
	if gravity_ring == null:
		gravity_ring = Line2D.new()
		gravity_ring.name = "GravityShieldRing"
		gravity_ring.closed = true
		gravity_ring.antialiased = true
		add_child(gravity_ring)
	if health_ring == null:
		health_ring = Line2D.new()
		health_ring.name = "HealthRing"
		health_ring.closed = false
		health_ring.antialiased = true
		add_child(health_ring)
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	if collision_shape.shape == null:
		collision_shape.shape = CircleShape2D.new()


func _update_geometry() -> void:
	if hull != null:
		hull.polygon = _circle_points(radius, 72)
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius
	if gravity_ring != null:
		gravity_ring.points = _circle_points(shield_radius, 72)
		gravity_ring.width = 3.0
	if health_ring != null:
		health_ring.width = 5.0


func _update_visuals() -> void:
	var ratio := get_health_ratio()
	if hull != null:
		hull.color = damaged_hull_color.lerp(healthy_hull_color, ratio)
	if gravity_ring != null:
		gravity_ring.default_color = Color(shield_color.r, shield_color.g, shield_color.b, _safe_alpha(gravity_ring_alpha, 0.24))
	if health_ring != null:
		var points := PackedVector2Array()
		var count := maxi(int(72.0 * ratio), 2)
		for index in range(count):
			var angle := -PI * 0.5 + TAU * ratio * float(index) / float(maxi(count - 1, 1))
			points.append(Vector2(cos(angle), sin(angle)) * (shield_radius + 18.0))
		health_ring.points = points
		health_ring.default_color = health_low_color.lerp(health_high_color, ratio)


func _safe_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)


func _circle_points(circle_radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
