from pathlib import Path

p = Path(r"C:\Users\elden\Desktop\Gravity Ideas\VECTOR ANOMALY\Scripts\wave_director.gd")
c = p.read_text(encoding="utf-8")

if "wave_cleared" not in c:
    c = c.replace(
        "signal boss_wave\nsignal regular_wave",
        "signal boss_wave\nsignal regular_wave\n"
        "signal wave_cleared(wave: int)\n"
        "signal boss_defeated_anchor(boss_scene_path: String)",
    )

if "_waves_halted" not in c:
    c = c.replace(
        "var _boss_bar: ProgressBar\n\nfunc _ready",
        "var _boss_bar: ProgressBar\n"
        "var _waves_halted: bool = false\n"
        'var _last_boss_scene_path: String = ""\n\n'
        "func _ready",
    )

halt = """
func halt_waves() -> void:
\t_waves_halted = true
\t_wave_running = false
\t_spawning = false


func restore_wave_index(wave: int) -> void:
\t_wave = maxi(wave, 0)
\tif _wave > 0:
\t\t_banner_label.text = "ANCHOR WAVE %d" % _wave


func get_current_wave() -> int:
\treturn _wave


"""

if "func halt_waves" not in c:
    c = c.replace(
        "func _begin_next_wave() -> void:\n\tif _player == null",
        halt
        + "func _begin_next_wave() -> void:\n"
        "\tif _waves_halted or not _waves_enabled():\n"
        '\t\t_banner_label.text = "WAVE DIRECTOR STANDBY"\n'
        "\t\treturn\n"
        "\tif _player == null",
    )

if "RunProgress.sync_phase_from_wave" not in c:
    c = c.replace(
        "\t_wave += 1\n\t_wave_running",
        "\t_wave += 1\n\tif RunProgress:\n\t\tRunProgress.sync_phase_from_wave(_wave)\n\t_wave_running",
    )

if "_build_late_game_roster" not in c:
    c = c.replace(
        "func _spawn_regular_wave() -> void:\n\n\tregular_wave",
        "func _spawn_regular_wave() -> void:\n\tregular_wave",
    )
    c = c.replace(
        "var roster = _build_wave_roster()\n\tfor i in range(roster.size()):",
        "var roster = _build_wave_roster()\n"
        "\tvar delay := spawn_delay\n"
        "\tif _is_late_game_wave():\n"
        "\t\tdelay = maxf(spawn_delay * 0.62, 0.22)\n"
        "\tfor i in range(roster.size()):",
    )
    c = c.replace(
        "await get_tree().create_timer(spawn_delay).timeout\n\nfunc _spawn_boss_wave",
        "await get_tree().create_timer(delay).timeout\n\nfunc _spawn_boss_wave",
    )
    c = c.replace(
        "var boss_scene = _choose_boss_scene()\n\tvar boss = boss_scene",
        "var boss_scene = _choose_boss_scene()\n"
        "\t_last_boss_scene_path = boss_scene.resource_path\n"
        "\tvar boss = boss_scene",
    )
    c = c.replace(
        "func _build_wave_roster() -> Array:\n\tvar roster",
        "func _build_wave_roster() -> Array:\n"
        "\tif _is_late_game_wave():\n"
        "\t\treturn _build_late_game_roster()\n\n"
        "\tvar roster",
    )
    late = """
func _build_late_game_roster() -> Array:
\tvar elite: Array = [
\t\tCHAOS_WISP_SCENE, SHIELD_BREAKER_SCENE, SNIPER_SCENE, HARASSER_SCENE,
\t\tPARAMETRIC_4_SCENE, PARAMETRIC_5_SCENE, SEEKER_FRAGMENT_SCENE, GRAVITY_LEECH_SCENE,
\t]
\tvar roster: Array = []
\tvar count := mini(8 + int((_wave - RunProgress.LATE_GAME_START_WAVE) * 0.5), max_regular_enemies + 4)
\tfor i in range(count):
\t\troster.append(elite[i % elite.size()])
\treturn roster

"""
    c = c.replace(
        "\treturn roster\n\nfunc _spawn_enemy(scene: PackedScene, node_name: String) -> void:",
        late + "\treturn roster\n\nfunc _spawn_enemy(scene: PackedScene, node_name: String) -> Node:",
    )
    c = c.replace(
        'func _complete_wave() -> void:\n\t_wave_running = false\n\t_banner_label.text = "WAVE %d CLEARED" % _wave\n\t_boss_panel.visible = false\n\n\tawait',
        'func _complete_wave() -> void:\n\t_wave_running = false\n\t_banner_label.text = "WAVE %d CLEARED" % _wave\n\t_boss_panel.visible = false\n\twave_cleared.emit(_wave)\n\n\tif _waves_halted or not _waves_enabled():\n\t\treturn\n\n\tawait',
    )
    c = c.replace(
        "func _is_boss_wave() -> bool:\n\treturn boss_every_waves",
        "func _is_boss_wave() -> bool:\n\tif RunProgress and not RunProgress.challenge_mode:\n\t\treturn RunProgress.is_boss_milestone_wave(_wave)\n\treturn boss_every_waves",
    )
    helpers = """
func _is_late_game_wave() -> bool:
\treturn RunProgress and _wave >= RunProgress.LATE_GAME_START_WAVE and _wave <= RunProgress.LATE_GAME_END_WAVE


func _waves_enabled() -> bool:
\tif RunProgress == null:
\t\treturn true
\treturn RunProgress.waves_enabled()


"""
    c = c.replace("func _refresh_player_planet_cache() -> void:", helpers + "func _refresh_player_planet_cache() -> void:")
    c = c.replace(
        "func _choose_boss_scene() -> PackedScene:\n\tvar boss_number",
        "func _choose_boss_scene() -> PackedScene:\n\tif RunProgress and not RunProgress.challenge_mode:\n\t\treturn _boss_scene_from_path(RunProgress.get_scheduled_boss_scene_path(_wave))\n\n\tvar boss_number",
    )
    boss_from = """
func _boss_scene_from_path(path: String) -> PackedScene:
\tmatch path:
\t\t"res://Nodes/accretion_core_boss.tscn":
\t\t\treturn ACCRETION_CORE_SCENE
\t\t"res://Nodes/null_vector_seraph_boss.tscn":
\t\t\treturn NULL_SERAPH_SCENE
\t\t"res://Nodes/magnetar_twins_boss.tscn":
\t\t\treturn MAGNETAR_TWINS_SCENE
\t\t"res://Nodes/rift_weaver_boss.tscn":
\t\t\treturn RIFT_WEAVER_SCENE
\t\t"res://Nodes/ParametricEquationEnemies/polymorph_boss.tscn":
\t\t\treturn POLYMORPH_BOSS_SCENE
\t\t_:
\t\t\treturn GRAVITY_WARDEN_SCENE

"""
    c = c.replace("\treturn GRAVITY_WARDEN_SCENE\n\nfunc _boss_display_name", boss_from + "func _boss_display_name")
    c = c.replace(
        "func _on_boss_defeated() -> void:\n\t_clear_remaining",
        "func _on_boss_defeated() -> void:\n\tif not _last_boss_scene_path.is_empty():\n\t\tboss_defeated_anchor.emit(_last_boss_scene_path)\n\t_clear_remaining",
    )

p.write_text(c, encoding="utf-8")
print("patched ok")
