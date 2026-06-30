extends StaticBody2D
class_name CampaignMotherPlanet

signal health_changed(current_health: float, max_health: float)
signal shield_changed(current_shield: float, max_shield: float)
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
@export_group("Defense Shield")
@export var shield_max: float = 520.0
@export var starting_shield: float = -1.0
@export var shield_recharge_per_second: float = 18.0
@export var shield_recharge_delay: float = 3.2
@export_range(0.0, 1.0, 0.01) var shield_damage_absorb_ratio: float = 0.82
@export_range(0.0, 1.0, 0.01) var repair_restores_shield_ratio: float = 0.28
@export var armor_upgrade_shield_bonus: float = 90.0
@export var defense_pulse_visual_duration: float = 0.72
@export var defense_pulse_visual_radius_bonus: float = 96.0
@export var defense_pulse_visual_color: Color = Color(0.54, 1.0, 0.82, 0.32)
@export_group("Visual Polish")
@export var core_radius: float = 78.0
@export var latitude_ring_count: int = 5
@export var fracture_line_count: int = 12
@export var pulse_speed: float = 0.85
@export_range(0.0, 1.0, 0.01) var core_alpha: float = 0.82
@export_range(0.0, 1.0, 0.01) var lattice_alpha: float = 0.24
@export_range(0.0, 1.0, 0.01) var fracture_alpha: float = 0.26
@export_range(0.0, 1.0, 0.01) var pulse_ring_alpha: float = 0.18
@export var core_color: Color = Color(0.72, 1.0, 0.9, 0.82)
@export var lattice_color: Color = Color(0.35, 0.98, 1.0, 0.24)
@export var fracture_color: Color = Color(1.0, 0.24, 0.14, 0.26)

var current_health: float = 1600.0
var current_shield: float = 520.0
var mass: float = 420000.0

@onready var hull: Polygon2D = _find_polygon_child("HomePlanetHull", "MotherPlanetHull")
@onready var core: Polygon2D = _find_polygon_child("HomePlanetCore", "MotherPlanetCore")
@onready var gravity_ring: Line2D = get_node_or_null("GravityShieldRing") as Line2D
@onready var health_ring: Line2D = get_node_or_null("HealthRing") as Line2D
@onready var pulse_ring: Line2D = get_node_or_null("DefensePulseRing") as Line2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var _latitude_rings: Array[Line2D] = []
var _fracture_lines: Array[Line2D] = []
var _elapsed: float = 0.0
var _shield_recharge_delay_remaining: float = 0.0
var _defense_pulse_visual_remaining: float = 0.0


func _ready() -> void:
	add_to_group("campaign_mother_planet")
	add_to_group("player_allies")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	mass = base_mass
	current_health = max_health if starting_health < 0.0 else clampf(starting_health, 0.0, max_health)
	current_shield = shield_max if starting_shield < 0.0 else clampf(starting_shield, 0.0, shield_max)
	_ensure_scene_children()
	_update_geometry()
	_update_visuals()
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")
		RuntimeRegistry.register_node(self, &"player_allies")
		RuntimeRegistry.register_node(self, &"campaign_mother_planet")


func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")
		RuntimeRegistry.unregister_node(self, &"player_allies")
		RuntimeRegistry.unregister_node(self, &"campaign_mother_planet")


func _process(delta: float) -> void:
	_elapsed += delta
	_update_shield_recharge(delta)
	var ratio := get_health_ratio()
	var shield_ratio := get_shield_ratio()
	var pulse := sin(_elapsed * pulse_speed) * 0.5 + 0.5
	if gravity_ring != null:
		gravity_ring.rotation += delta * 0.055
	if pulse_ring != null:
		pulse_ring.rotation -= delta * 0.04
		var pulse_visual := clampf(_defense_pulse_visual_remaining / maxf(defense_pulse_visual_duration, 0.01), 0.0, 1.0)
		_defense_pulse_visual_remaining = maxf(_defense_pulse_visual_remaining - delta, 0.0)
		var pulse_radius_scale := defense_pulse_visual_radius_bonus / maxf(shield_radius + 36.0, 1.0)
		pulse_ring.scale = Vector2.ONE * (1.0 + pulse * 0.045 + pulse_visual * pulse_radius_scale)
		pulse_ring.width = 1.5 + pulse_visual * 3.2
		var ring_color := shield_color.lerp(defense_pulse_visual_color, pulse_visual)
		pulse_ring.default_color = _safe_color(Color(ring_color.r, ring_color.g, ring_color.b, _safe_alpha(pulse_ring_alpha * (0.45 + pulse * 0.55) * maxf(ratio, shield_ratio), 0.34)))
	if core != null:
		core.scale = Vector2.ONE * (0.96 + pulse * 0.08)
		core.color = _safe_color(Color(core_color.r, core_color.g, core_color.b, _safe_alpha(core_alpha * (0.72 + pulse * 0.18), 0.86)))
	for index in range(_latitude_rings.size()):
		var line := _latitude_rings[index]
		if line == null:
			continue
		line.rotation += delta * (0.012 + float(index) * 0.004) * (-1.0 if index % 2 == 0 else 1.0)
		line.default_color = _safe_color(Color(lattice_color.r, lattice_color.g, lattice_color.b, _safe_alpha(lattice_alpha * (0.55 + ratio * 0.45), 0.28)))
	for index in range(_fracture_lines.size()):
		var fracture := _fracture_lines[index]
		if fracture == null:
			continue
		var damage_ratio := 1.0 - ratio
		var flicker := 0.75 + sin(_elapsed * 3.2 + float(index) * 1.7) * 0.25
		fracture.visible = damage_ratio > 0.04
		fracture.default_color = _safe_color(Color(fracture_color.r, fracture_color.g, fracture_color.b, _safe_alpha(fracture_alpha * damage_ratio * flicker, 0.32)))


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var hull_damage := _absorb_damage_with_shield(amount)
	current_health = maxf(current_health - hull_damage, 0.0)
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
	if repair_restores_shield_ratio > 0.0 and shield_max > 0.0:
		var previous_shield := current_shield
		current_shield = minf(current_shield + amount * repair_restores_shield_ratio, shield_max)
		if current_shield > previous_shield:
			shield_changed.emit(current_shield, shield_max)
	if repaired > 0.0:
		health_changed.emit(current_health, max_health)
		_update_visuals()
	return repaired


func upgrade_armor(levels: int = 1) -> void:
	var bonus := armor_upgrade_health_bonus * float(maxi(levels, 1))
	max_health += bonus
	current_health += bonus
	shield_max += armor_upgrade_shield_bonus * float(maxi(levels, 1))
	current_shield = minf(current_shield + armor_upgrade_shield_bonus * float(maxi(levels, 1)), shield_max)
	radius += 8.0 * float(maxi(levels, 1))
	shield_radius += 12.0 * float(maxi(levels, 1))
	mass = base_mass * (radius / 220.0)
	_update_geometry()
	_update_visuals()
	health_changed.emit(current_health, max_health)
	shield_changed.emit(current_shield, shield_max)


func get_health_ratio() -> float:
	return clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)


func get_shield_ratio() -> float:
	return clampf(current_shield / maxf(shield_max, 1.0), 0.0, 1.0)


func release_defense_pulse_visual() -> void:
	_defense_pulse_visual_remaining = maxf(defense_pulse_visual_duration, 0.05)


func _find_polygon_child(primary_name: String, fallback_name: String) -> Polygon2D:
	var polygon := get_node_or_null(primary_name) as Polygon2D
	if polygon != null:
		return polygon
	return get_node_or_null(fallback_name) as Polygon2D


func _ensure_scene_children() -> void:
	if hull == null:
		hull = Polygon2D.new()
		hull.name = "HomePlanetHull"
		add_child(hull)
	if core == null:
		core = Polygon2D.new()
		core.name = "HomePlanetCore"
		add_child(core)
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
	if pulse_ring == null:
		pulse_ring = Line2D.new()
		pulse_ring.name = "DefensePulseRing"
		pulse_ring.closed = true
		pulse_ring.antialiased = true
		add_child(pulse_ring)
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	if collision_shape.shape == null:
		collision_shape.shape = CircleShape2D.new()
	_latitude_rings.clear()
	for index in range(maxi(latitude_ring_count, 0)):
		var latitude := get_node_or_null("LatitudeRing%d" % index) as Line2D
		if latitude == null:
			latitude = Line2D.new()
			latitude.name = "LatitudeRing%d" % index
			add_child(latitude)
		latitude.antialiased = true
		latitude.closed = true
		_latitude_rings.append(latitude)
	_fracture_lines.clear()
	for index in range(maxi(fracture_line_count, 0)):
		var fracture := get_node_or_null("DamageFracture%d" % index) as Line2D
		if fracture == null:
			fracture = Line2D.new()
			fracture.name = "DamageFracture%d" % index
			add_child(fracture)
		fracture.antialiased = true
		fracture.closed = false
		_fracture_lines.append(fracture)


func _update_geometry() -> void:
	if hull != null:
		hull.polygon = _circle_points(radius, 96)
		hull.z_index = 0
	if core != null:
		core.polygon = _circle_points(core_radius, 24)
		core.z_index = 3
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius
	if gravity_ring != null:
		gravity_ring.points = _circle_points(shield_radius, 112)
		gravity_ring.width = 3.0
		gravity_ring.z_index = 4
	if health_ring != null:
		health_ring.width = 6.0
		health_ring.z_index = 6
	if pulse_ring != null:
		pulse_ring.points = _circle_points(shield_radius + 36.0, 112)
		pulse_ring.width = 1.5
		pulse_ring.z_index = 2
	for index in range(_latitude_rings.size()):
		var line := _latitude_rings[index]
		if line == null:
			continue
		var t := (float(index) + 1.0) / (float(_latitude_rings.size()) + 1.0)
		var y := lerpf(-radius * 0.62, radius * 0.62, t)
		var x_radius := maxf(radius * sqrt(maxf(1.0 - pow(y / maxf(radius, 1.0), 2.0), 0.0)), 28.0)
		line.position = Vector2(0.0, y)
		line.points = _ellipse_points(x_radius, maxf(x_radius * 0.18, 12.0), 72)
		line.width = 1.1
		line.z_index = 2
	for index in range(_fracture_lines.size()):
		var fracture := _fracture_lines[index]
		if fracture == null:
			continue
		var angle := TAU * float(index) / maxf(float(maxi(_fracture_lines.size(), 1)), 1.0) + sin(float(index) * 12.9898) * 0.22
		var direction := Vector2(cos(angle), sin(angle))
		var side := -1.0 if index % 2 == 0 else 1.0
		fracture.points = PackedVector2Array([
			direction * radius * 0.34,
			direction.rotated(0.11 * side) * radius * 0.62,
			direction.rotated(-0.08 * side) * radius * 0.91,
		])
		fracture.width = 1.2 + float(index % 3) * 0.35
		fracture.visible = false
		fracture.z_index = 5


func _update_visuals() -> void:
	var ratio := get_health_ratio()
	var shield_ratio := get_shield_ratio()
	if hull != null:
		hull.color = _safe_color(damaged_hull_color.lerp(healthy_hull_color, ratio))
	if core != null:
		core.color = _safe_color(Color(core_color.r, core_color.g, core_color.b, _safe_alpha(core_alpha, 0.86)))
	if gravity_ring != null:
		gravity_ring.width = 2.0 + shield_ratio * 2.4
		gravity_ring.default_color = _safe_color(Color(shield_color.r, shield_color.g, shield_color.b, _safe_alpha(gravity_ring_alpha * (0.35 + shield_ratio * 0.65), 0.28)))
	if health_ring != null:
		var points := PackedVector2Array()
		var count := maxi(int(112.0 * ratio), 2)
		for index in range(count):
			var angle := -PI * 0.5 + TAU * ratio * float(index) / float(maxi(count - 1, 1))
			points.append(Vector2(cos(angle), sin(angle)) * (shield_radius + 18.0))
		health_ring.points = points
		health_ring.default_color = _safe_color(health_low_color.lerp(health_high_color, ratio))
	if pulse_ring != null:
		pulse_ring.default_color = _safe_color(Color(shield_color.r, shield_color.g, shield_color.b, _safe_alpha(pulse_ring_alpha * maxf(ratio, shield_ratio), 0.22)))
	for line in _latitude_rings:
		if line != null:
			line.default_color = _safe_color(Color(lattice_color.r, lattice_color.g, lattice_color.b, _safe_alpha(lattice_alpha * (0.55 + ratio * 0.45), 0.28)))
	for line in _fracture_lines:
		if line != null:
			line.default_color = _safe_color(Color(fracture_color.r, fracture_color.g, fracture_color.b, _safe_alpha(fracture_alpha * (1.0 - ratio), 0.32)))


func _safe_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), cap)
	return minf(alpha, cap)


func _absorb_damage_with_shield(amount: float) -> float:
	if shield_max <= 0.0 or current_shield <= 0.0:
		return amount
	var shieldable := amount * clampf(shield_damage_absorb_ratio, 0.0, 1.0)
	var absorbed := minf(current_shield, shieldable)
	current_shield = maxf(current_shield - absorbed, 0.0)
	_shield_recharge_delay_remaining = maxf(shield_recharge_delay, 0.0)
	shield_changed.emit(current_shield, shield_max)
	return maxf(amount - absorbed, 0.0)


func _update_shield_recharge(delta: float) -> void:
	if shield_recharge_per_second <= 0.0 or current_shield >= shield_max:
		return
	if _shield_recharge_delay_remaining > 0.0:
		_shield_recharge_delay_remaining = maxf(_shield_recharge_delay_remaining - delta, 0.0)
		return
	var previous := current_shield
	current_shield = minf(current_shield + shield_recharge_per_second * delta, shield_max)
	if int(previous) != int(current_shield):
		shield_changed.emit(current_shield, shield_max)
		_update_visuals()


func _safe_color(color: Color) -> Color:
	if Settings != null and Settings.has_method("apply_readability_color"):
		return Settings.apply_readability_color(color)
	return color


func _circle_points(circle_radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points


func _ellipse_points(x_radius: float, y_radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(count, 8)):
		var angle := TAU * float(index) / float(maxi(count, 8))
		points.append(Vector2(cos(angle) * x_radius, sin(angle) * y_radius))
	return points
