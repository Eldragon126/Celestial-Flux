extends Node
class_name ArenaRuleDirector
## Seeded arena law profiles. These are alternate arenas as rule sets first,
## keeping the main scene stable while making each run's physics feel distinct.

signal arena_profile_applied(profile_id: StringName, display_name: String, profile: Dictionary)

@export var enabled: bool = true
@export var profile_index_override: int = -1
@export var show_profile_banner: bool = true

var _arena_manager: Node = null
var _resonance_manager: Node = null
var _time_manager: Node = null
var _wave_director: Node = null
var _banner_canvas: CanvasLayer = null
var _banner_label: Label = null


func _ready() -> void:
	add_to_group("arena_rule_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func get_current_profile_summary() -> Dictionary:
	var profile := _choose_profile()
	return {
		"id": profile.get("id", &"standard_lattice"),
		"display_name": profile.get("display_name", "Standard Lattice"),
		"rule": profile.get("rule", "Neutral gravity law"),
	}


func _bootstrap() -> void:
	if not enabled:
		return
	_resolve_sources()
	var profile := _choose_profile()
	_apply_profile(profile)
	if show_profile_banner:
		_show_banner("ARENA LAW: %s" % str(profile.get("display_name", "STANDARD")).to_upper())
	arena_profile_applied.emit(
		StringName(profile.get("id", &"standard_lattice")),
		str(profile.get("display_name", "Standard Lattice")),
		profile.duplicate(true)
	)


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_time_manager = root.find_child("TimeDilationManager", true, false)
	_wave_director = root.find_child("WaveDirector", true, false)


func _choose_profile() -> Dictionary:
	var profiles := _profiles()
	var index := profile_index_override
	if index < 0:
		var seed_value := int(RunProgress.run_seed if RunProgress != null else 0)
		index = absi(seed_value / 7) % profiles.size()
	return profiles[clampi(index, 0, profiles.size() - 1)]


func _apply_profile(profile: Dictionary) -> void:
	_apply_node_properties(_arena_manager, profile.get("arena", {}))
	_apply_node_properties(_resonance_manager, profile.get("resonance", {}))
	_apply_node_properties(_time_manager, profile.get("time", {}))
	_apply_node_properties(_wave_director, profile.get("wave", {}))


func _apply_node_properties(node: Node, properties: Variant) -> void:
	if node == null or not (properties is Dictionary):
		return
	var property_map := properties as Dictionary
	for property in property_map.keys():
		if node.get(property) == null:
			continue
		node.set(property, property_map[property])


func _profiles() -> Array[Dictionary]:
	return [
		{
			"id": &"clean_vector_lattice",
			"display_name": "Clean Vector Lattice",
			"rule": "Readable early vectors with slower law collapse",
			"arena": {"wave_instability_gain": 0.064, "min_event_interval": 12.0},
			"resonance": {"maximum_resonance_zones": 3, "minimum_resonance_strength": 0.52},
		},
		{
			"id": &"mirror_well",
			"display_name": "Mirror Well",
			"rule": "More inversion and rebound opportunities",
			"arena": {"starting_instability": 0.08, "hazard_lifetime_max": 12.0},
			"resonance": {"minimum_resonance_strength": 0.44, "maximum_manual_resonance_zones": 5},
		},
		{
			"id": &"tidal_skein",
			"display_name": "Tidal Skein",
			"rule": "Frequent tide pockets create orbit-routing choices",
			"arena": {"min_event_interval": 8.8, "max_event_interval": 14.0, "max_active_hazards": 8},
			"resonance": {"resonance_detection_radius": 430.0},
		},
		{
			"id": &"chronal_shoal",
			"display_name": "Chronal Shoal",
			"rule": "Time pockets are stronger but shorter",
			"arena": {"min_event_interval": 10.0, "hazard_lifetime_min": 5.8},
			"time": {"local_effect_duration": 0.22, "near_miss_charge_amount": 19.0},
		},
		{
			"id": &"harmonic_boneyard",
			"display_name": "Harmonic Boneyard",
			"rule": "Projectile arcs and manual resonance zones matter more",
			"resonance": {"projectile_acceleration_multiplier": 1.82, "maximum_manual_resonance_zones": 6},
			"wave": {"recovery_rest_bonus": 2.2},
		},
	]


func _show_banner(text: String) -> void:
	if _banner_label == null:
		_build_banner()
	if _banner_label == null:
		return
	_banner_label.text = text
	_banner_label.modulate = Color(0.52, 0.95, 1.0, 0.0)
	var tween := _banner_label.create_tween()
	tween.tween_property(_banner_label, "modulate:a", 0.9, 0.18)
	tween.tween_interval(2.15)
	tween.tween_property(_banner_label, "modulate:a", 0.0, 0.35)


func _build_banner() -> void:
	_banner_canvas = CanvasLayer.new()
	_banner_canvas.name = "ArenaRuleBannerCanvas"
	_banner_canvas.layer = 89
	add_child(_banner_canvas)
	_banner_label = Label.new()
	_banner_label.name = "ArenaRuleBanner"
	_banner_label.anchor_left = 0.5
	_banner_label.anchor_right = 0.5
	_banner_label.offset_left = -360.0
	_banner_label.offset_right = 360.0
	_banner_label.offset_top = 236.0
	_banner_label.offset_bottom = 274.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 20)
	_banner_label.modulate = Color.TRANSPARENT
	_banner_canvas.add_child(_banner_label)
