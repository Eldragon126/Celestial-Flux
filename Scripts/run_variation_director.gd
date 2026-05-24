extends Node
class_name RunVariationDirector

signal run_modifier_applied(modifier_id: StringName, display_name: String)
signal pacing_state_changed(state: StringName, wave: int)
signal rare_event_started(event_id: StringName, wave: int)

@export var enabled: bool = true
@export var rare_event_chance: float = 0.18
@export var rare_event_min_wave: int = 4
@export var rare_event_cooldown_waves: int = 5

var _player: Node = null
var _wave_director: Node = null
var _arena_manager: Node = null
var _resonance_manager: Node = null
var _time_manager: Node = null
var _modifier_id: StringName = &"standard_vector"
var _modifier_name := "Standard Vector"
var _last_rare_wave := -999
var _base_spawn_delay := 0.48
var _base_rest := 4.0
var _banner_canvas: CanvasLayer = null
var _banner_label: Label = null


func _ready() -> void:
	add_to_group("run_variation_director")
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	_resolve_sources()
	_capture_bases()
	_apply_seeded_modifier()
	_connect_wave_director()
	_build_banner()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player")
	if root != null:
		_wave_director = root.find_child("WaveDirector", true, false)
		_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)
		_time_manager = root.find_child("TimeDilationManager", true, false)


func _capture_bases() -> void:
	if _wave_director != null:
		_base_spawn_delay = _safe_float(_wave_director.get("spawn_delay"), _base_spawn_delay)
		_base_rest = _safe_float(_wave_director.get("rest_between_waves"), _base_rest)


func _connect_wave_director() -> void:
	if _wave_director == null:
		return
	if _wave_director.has_signal("regular_wave"):
		var regular_cb := Callable(self, "_on_regular_wave")
		if not _wave_director.is_connected("regular_wave", regular_cb):
			_wave_director.connect("regular_wave", regular_cb)
	if _wave_director.has_signal("boss_wave"):
		var boss_cb := Callable(self, "_on_boss_wave")
		if not _wave_director.is_connected("boss_wave", boss_cb):
			_wave_director.connect("boss_wave", boss_cb)
	if _wave_director.has_signal("wave_cleared"):
		var cleared_cb := Callable(self, "_on_wave_cleared")
		if not _wave_director.is_connected("wave_cleared", cleared_cb):
			_wave_director.connect("wave_cleared", cleared_cb)


func _apply_seeded_modifier() -> void:
	if not enabled:
		return
	var seed_value := int(RunProgress.run_seed if RunProgress != null else 0)
	var index := absi(seed_value) % 5
	match index:
		0:
			_modifier_id = &"comet_wake"
			_modifier_name = "Comet Wake"
			_tune_player_float("slingshot_gravity_boost_scale", 0.18, true)
			_tune_player_float("gravity_charge_per_work", 0.000035, true)
		1:
			_modifier_id = &"dense_stars"
			_modifier_name = "Dense Stars"
			_tune_node_int(_wave_director, "max_regular_enemies", 2, true)
			_tune_node_int(_resonance_manager, "maximum_resonance_zones", 1, true)
		2:
			_modifier_id = &"temporal_draft"
			_modifier_name = "Temporal Draft"
			_tune_node_float(_time_manager, "near_miss_charge_amount", 3.0, true)
			_tune_node_float(_arena_manager, "min_event_interval", -1.5, true)
		3:
			_modifier_id = &"quiet_recovery"
			_modifier_name = "Quiet Recovery"
			_tune_node_float(_wave_director, "recovery_rest_bonus", 1.25, true)
			_tune_node_float(_arena_manager, "hazard_lifetime_max", -2.0, true)
		_:
			_modifier_id = &"volatile_lattice"
			_modifier_name = "Volatile Lattice"
			_tune_node_float(_arena_manager, "wave_instability_gain", 0.018, true)
			_tune_node_float(_resonance_manager, "minimum_resonance_strength", -0.08, true)
	run_modifier_applied.emit(_modifier_id, _modifier_name)
	_show_banner("RUN LAW: %s" % _modifier_name.to_upper())


func _on_regular_wave() -> void:
	_apply_pacing_state(_current_wave(), false)


func _on_boss_wave() -> void:
	_apply_pacing_state(_current_wave(), true)


func _on_wave_cleared(wave: int) -> void:
	if not enabled:
		return
	if wave < rare_event_min_wave:
		return
	if wave - _last_rare_wave < rare_event_cooldown_waves:
		return
	if _seeded_roll(wave) > rare_event_chance:
		return
	_last_rare_wave = wave
	_start_rare_event(wave)


func _apply_pacing_state(wave: int, is_boss_wave: bool) -> void:
	if _wave_director == null:
		return
	var state := &"tension"
	if is_boss_wave:
		state = &"overload"
	elif wave > 0 and wave % 4 == 0:
		state = &"recovery"
	elif wave > 0 and wave % 3 == 0:
		state = &"overload"
	elif wave <= 2:
		state = &"calm"

	match state:
		&"calm":
			_wave_director.set("spawn_delay", _base_spawn_delay * 1.12)
			_wave_director.set("rest_between_waves", _base_rest * 1.08)
		&"recovery":
			_wave_director.set("spawn_delay", _base_spawn_delay * 1.04)
			_wave_director.set("rest_between_waves", _base_rest * 1.45)
		&"overload":
			_wave_director.set("spawn_delay", maxf(_base_spawn_delay * 0.72, 0.2))
			_wave_director.set("rest_between_waves", _base_rest * 0.78)
		_:
			_wave_director.set("spawn_delay", _base_spawn_delay)
			_wave_director.set("rest_between_waves", _base_rest)
	pacing_state_changed.emit(state, wave)


func _start_rare_event(wave: int) -> void:
	var event_id := _rare_event_for_wave(wave)
	if _arena_manager != null and _arena_manager.has_method("force_arena_event"):
		match event_id:
			&"null_aurora":
				_arena_manager.call("force_arena_event", &"temporal_pocket")
			&"gravity_bloom":
				_arena_manager.call("force_arena_event", &"resonance_storm")
			_:
				_arena_manager.call("force_arena_event", &"tide_slipstream")
	_show_banner("RARE EVENT: %s" % String(event_id).replace("_", " ").to_upper())
	rare_event_started.emit(event_id, wave)


func _rare_event_for_wave(wave: int) -> StringName:
	var seed_value := int(RunProgress.run_seed if RunProgress != null else 0)
	var value := absi(int(hash("%d:%d:%s" % [seed_value, wave, String(_modifier_id)]))) % 3
	if value == 0:
		return &"comet_choir"
	if value == 1:
		return &"gravity_bloom"
	return &"null_aurora"


func _build_banner() -> void:
	if _banner_canvas != null:
		return
	_banner_canvas = CanvasLayer.new()
	_banner_canvas.name = "RunVariationBannerCanvas"
	_banner_canvas.layer = 91
	add_child(_banner_canvas)
	_banner_label = Label.new()
	_banner_label.name = "RunVariationBanner"
	_banner_label.anchor_left = 0.5
	_banner_label.anchor_right = 0.5
	_banner_label.offset_left = -330.0
	_banner_label.offset_right = 330.0
	_banner_label.offset_top = 194.0
	_banner_label.offset_bottom = 232.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 20)
	_banner_label.modulate = Color.TRANSPARENT
	_banner_canvas.add_child(_banner_label)


func _show_banner(text: String) -> void:
	if _banner_label == null:
		_build_banner()
	if _banner_label == null:
		return
	_banner_label.text = text
	_banner_label.modulate = Color(0.42, 1.0, 0.88, 0.0)
	var tween := _banner_label.create_tween()
	tween.tween_property(_banner_label, "modulate:a", 0.92, 0.18)
	tween.tween_interval(1.9)
	tween.tween_property(_banner_label, "modulate:a", 0.0, 0.36)


func _current_wave() -> int:
	if _wave_director == null:
		return 0
	if _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return int(_safe_float(_wave_director.get("_wave"), 0.0))


func _seeded_roll(wave: int) -> float:
	var seed_value := int(RunProgress.run_seed if RunProgress != null else 0)
	var value := absi(int(hash("%d:%d:%s" % [seed_value, wave, String(_modifier_id)])))
	return float(value % 10000) / 10000.0


func _tune_player_float(property: StringName, amount: float, additive: bool) -> void:
	_tune_node_float(_player, property, amount, additive)


func _tune_node_float(node: Node, property: StringName, amount: float, additive: bool) -> void:
	if node == null or node.get(property) == null:
		return
	var current := _safe_float(node.get(property), 0.0)
	node.set(property, current + amount if additive else amount)


func _tune_node_int(node: Node, property: StringName, amount: int, additive: bool) -> void:
	if node == null or node.get(property) == null:
		return
	var current := int(_safe_float(node.get(property), 0.0))
	node.set(property, current + amount if additive else amount)


func _safe_float(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback
