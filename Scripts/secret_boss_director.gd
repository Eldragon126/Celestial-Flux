extends Node
class_name SecretBossDirector

signal secret_progress_changed(secret_id: StringName, progress: int, required: int)
signal secret_boss_awakened(secret_id: StringName, boss: Node)
signal secret_boss_defeated(secret_id: StringName)

const SECRET_BOSS_SCENE := preload("res://Nodes/secret_law_boss.tscn")
const GRAVITY_MAW_SCENE := preload("res://Nodes/gravity_maw_boss.tscn")

@export var enabled: bool = true
@export var min_vector_wave: int = 7
@export var vector_apex_required: int = 3
@export var vector_chain_window: float = 10.0
@export var min_chronal_wave: int = 12
@export var temporal_entry_required: int = 2
@export var min_maw_wave: int = 16
@export var gravity_scar_required: int = 5
@export var spawn_distance: float = 920.0

var _player: Node = null
var _wave_director: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _active_boss: Node = null
var _current_wave := 0
var _vector_chain := 0
var _vector_chain_expires := 0.0
var _temporal_entries := 0
var _gravity_scar_entries := 0
var _spawned: Dictionary = {}
var _banner_canvas: CanvasLayer = null
var _banner_label: Label = null


func _ready() -> void:
	add_to_group("secret_boss_director")
	call_deferred("_bootstrap")


func _process(_delta: float) -> void:
	if _active_boss != null and not is_instance_valid(_active_boss):
		_active_boss = null
	if _vector_chain > 0 and _now_seconds() > _vector_chain_expires:
		_vector_chain = 0


func _bootstrap() -> void:
	_resolve_sources()
	_connect_sources()
	_build_banner()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player")
	if root != null:
		_wave_director = root.find_child("WaveDirector", true, false)
		_resonance_manager = root.find_child("GravityResonanceManager", true, false)
		_scar_manager = root.find_child("GravityScarManager", true, false)
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		_current_wave = int(_wave_director.call("get_current_wave"))


func _connect_sources() -> void:
	if _player != null and _player.has_signal("slingshot_mastery_scored"):
		var sling_cb := Callable(self, "_on_slingshot_mastery_scored")
		if not _player.is_connected("slingshot_mastery_scored", sling_cb):
			_player.connect("slingshot_mastery_scored", sling_cb)
	if _wave_director != null and _wave_director.has_signal("wave_cleared"):
		var wave_cb := Callable(self, "_on_wave_cleared")
		if not _wave_director.is_connected("wave_cleared", wave_cb):
			_wave_director.connect("wave_cleared", wave_cb)
	if _wave_director != null and _wave_director.has_signal("regular_wave"):
		var regular_cb := Callable(self, "_on_wave_started")
		if not _wave_director.is_connected("regular_wave", regular_cb):
			_wave_director.connect("regular_wave", regular_cb)
	if _wave_director != null and _wave_director.has_signal("boss_wave"):
		var boss_cb := Callable(self, "_on_wave_started")
		if not _wave_director.is_connected("boss_wave", boss_cb):
			_wave_director.connect("boss_wave", boss_cb)
	if _resonance_manager != null and _resonance_manager.has_signal("resonance_zone_entered"):
		var zone_cb := Callable(self, "_on_resonance_zone_entered")
		if not _resonance_manager.is_connected("resonance_zone_entered", zone_cb):
			_resonance_manager.connect("resonance_zone_entered", zone_cb)
	if _scar_manager != null and _scar_manager.has_signal("gravity_scar_created"):
		var scar_cb := Callable(self, "_on_gravity_scar_created")
		if not _scar_manager.is_connected("gravity_scar_created", scar_cb):
			_scar_manager.connect("gravity_scar_created", scar_cb)


func _on_wave_cleared(wave: int) -> void:
	_current_wave = wave


func _on_wave_started() -> void:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		_current_wave = int(_wave_director.call("get_current_wave"))


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	if not _secrets_allowed():
		return
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score < 0.94:
		return
	if _active_boss != null and is_instance_valid(_active_boss):
		return
	_vector_chain += 1
	_vector_chain_expires = _now_seconds() + vector_chain_window
	secret_progress_changed.emit(&"vector_shade", _vector_chain, vector_apex_required)
	if _current_wave >= min_vector_wave and _vector_chain >= vector_apex_required:
		_spawn_secret_boss(&"vector_shade", 0)


func _on_resonance_zone_entered(zone_data: Dictionary) -> void:
	if not _secrets_allowed():
		return
	if _active_boss != null and is_instance_valid(_active_boss):
		return
	var zone_type := StringName(zone_data.get("zone_type_name", &""))
	if zone_type != &"temporal_scar":
		return
	_temporal_entries += 1
	secret_progress_changed.emit(&"chronal_mirror", _temporal_entries, temporal_entry_required)
	if _current_wave >= min_chronal_wave and _temporal_entries >= temporal_entry_required:
		_spawn_secret_boss(&"chronal_mirror", 1)


func _on_gravity_scar_created(scar_data: Dictionary) -> void:
	if not _secrets_allowed():
		return
	if _active_boss != null and is_instance_valid(_active_boss):
		return
	var intensity := clampf(float(scar_data.get("intensity", 0.0)), 0.0, 1.0)
	if intensity < 0.34:
		return
	_gravity_scar_entries += 1
	secret_progress_changed.emit(&"gravity_maw", _gravity_scar_entries, gravity_scar_required)
	if _current_wave >= min_maw_wave and _gravity_scar_entries >= gravity_scar_required:
		_spawn_secret_boss(&"gravity_maw", 0)


func _spawn_secret_boss(secret_id: StringName, variant: int) -> void:
	if not _secrets_allowed():
		return
	if _spawned.has(secret_id):
		return
	if _boss_present():
		return
	var root := get_tree().current_scene
	var player_2d := _player as Node2D
	if root == null or player_2d == null:
		return

	var boss_scene := GRAVITY_MAW_SCENE if secret_id == &"gravity_maw" else SECRET_BOSS_SCENE
	var boss := boss_scene.instantiate()
	boss.name = "Secret%s" % String(secret_id).capitalize().replace(" ", "").replace("_", "")
	var display := _display_name_for_secret(secret_id, variant)
	if boss.get("secret_variant") != null:
		boss.set("secret_variant", variant)
	if boss.get("display_name") != null:
		boss.set("display_name", display)
	root.add_child(boss)

	var angle := TAU * _seeded_fraction(secret_id)
	var boss_2d := boss as Node2D
	if boss_2d != null:
		boss_2d.global_position = player_2d.global_position + Vector2.from_angle(angle) * spawn_distance

	if _wave_director != null and _wave_director.has_method("register_secret_boss"):
		_wave_director.call("register_secret_boss", boss, display)
	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", Callable(self, "_on_secret_boss_defeated").bind(secret_id))

	_spawned[secret_id] = true
	_active_boss = boss
	_show_banner("SECRET VECTOR: %s" % display)
	secret_boss_awakened.emit(secret_id, boss)


func _on_secret_boss_defeated(secret_id: StringName) -> void:
	_active_boss = null
	_show_banner("SECRET VECTOR SEALED")
	secret_boss_defeated.emit(secret_id)


func _boss_present() -> bool:
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss != _active_boss and is_instance_valid(boss) and not boss.is_queued_for_deletion():
			return true
	return false


func _secrets_allowed() -> bool:
	if not enabled:
		return false
	if RunProgress == null:
		return true
	if RunProgress.run_finished or RunProgress.boss_rush_mode:
		return false
	return true


func _display_name_for_secret(secret_id: StringName, variant: int) -> String:
	if secret_id == &"gravity_maw":
		return "GRAVITY MAW"
	return "CHRONAL MIRROR" if variant == 1 else "VECTOR SHADE"


func _build_banner() -> void:
	if _banner_canvas != null:
		return
	_banner_canvas = CanvasLayer.new()
	_banner_canvas.name = "SecretBossBannerCanvas"
	_banner_canvas.layer = 92
	add_child(_banner_canvas)
	_banner_label = Label.new()
	_banner_label.name = "SecretBossBanner"
	_banner_label.anchor_left = 0.5
	_banner_label.anchor_right = 0.5
	_banner_label.offset_left = -360.0
	_banner_label.offset_right = 360.0
	_banner_label.offset_top = 148.0
	_banner_label.offset_bottom = 190.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 24)
	_banner_label.modulate = Color.TRANSPARENT
	_banner_canvas.add_child(_banner_label)


func _show_banner(text: String) -> void:
	if _banner_label == null:
		_build_banner()
	if _banner_label == null:
		return
	_banner_label.text = text
	_banner_label.modulate = Color(0.86, 0.42, 1.0, 0.0)
	var tween := _banner_label.create_tween()
	tween.tween_property(_banner_label, "modulate:a", 0.95, 0.18)
	tween.tween_interval(2.2)
	tween.tween_property(_banner_label, "modulate:a", 0.0, 0.42)


func _seeded_fraction(secret_id: StringName) -> float:
	var seed_value := int(RunProgress.run_seed if RunProgress != null else 0)
	var value := absi(int(hash("%s:%d" % [String(secret_id), seed_value])))
	return float(value % 10000) / 10000.0


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
