from pathlib import Path

PROJ = Path(r"C:\Users\elden\Desktop\Gravity Ideas\VECTOR ANOMALY")


def patch_project_godot() -> None:
    p = PROJ / "project.godot"
    text = p.read_text(encoding="utf-8")
    if "RunProgress=" not in text:
        text = text.replace(
            'Settings="*uid://cdqcblk11uskc"',
            'Settings="*uid://cdqcblk11uskc"\nRunProgress="*res://Scripts/run_progress.gd"',
        )
        p.write_text(text, encoding="utf-8")
        print("autoload RunProgress added")


def patch_powerup_inventory() -> None:
    pi = PROJ / "Scripts/powerup_inventory.gd"
    c = pi.read_text(encoding="utf-8")
    if "export_anchor_stacks" in c:
        return
    anchor = """

func export_anchor_stacks() -> Dictionary:
\tvar out: Dictionary = {}
\tfor id in _stacks.keys():
\t\tout[String(id)] = int(_stacks[id])
\treturn out


func import_anchor_stacks(data: Dictionary) -> void:
\t_stacks.clear()
\tfor key in data.keys():
\t\t_stacks[StringName(key)] = int(data[key])
"""
    pi.write_text(c.rstrip() + anchor + "\n", encoding="utf-8")
    print("powerup anchor methods added")


def patch_title_screen() -> None:
    ts = PROJ / "Scripts/title_screen.gd"
    ts.write_text(
        """extends Control


func _ready() -> void:
\tpass


func _on_audio_stream_player_finished() -> void:
\t$AnimationPlayer.pause()


func _process(_delta: float) -> void:
\tif not Input.is_action_just_pressed("Confirm"):
\t\treturn
\tif RunProgress.has_anchor and Input.is_key_pressed(KEY_SHIFT):
\t\t_begin_continue()
\telse:
\t\t_begin_new_run()


func _begin_new_run() -> void:
\tRunProgress.begin_new_run(false)
\tget_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")


func _begin_continue() -> void:
\tif RunProgress.load_anchor():
\t\tget_tree().change_scene_to_file("res://Nodes/the_abyss.tscn")
""",
        encoding="utf-8",
    )
    print("title_screen updated")


def patch_orbital_juice_manager() -> None:
    p = PROJ / "Scripts/orbital_juice_manager.gd"
    c = p.read_text(encoding="utf-8")
    if "RUN_DIRECTOR_SCENE" in c:
        return
    c = c.replace(
        "const WAVE_DIRECTOR_SCENE = preload(\"res://Nodes/wave_director.tscn\")",
        "const WAVE_DIRECTOR_SCENE = preload(\"res://Nodes/wave_director.tscn\")\n"
        "const RUN_DIRECTOR_SCENE = preload(\"res://Nodes/run_director.tscn\")\n"
        "const PLAYER_VISUAL_STATE_SCENE = preload(\"res://Nodes/player_visual_state.tscn\")",
    )
    insert = """
\tif enable_wave_game and player != null:
\t\t_add_child_scene_once(level_root, RUN_DIRECTOR_SCENE, "RunDirector")
"""
    c = c.replace(
        "\tif enable_wave_game and player != null:\n\t\t_add_child_scene_once(level_root, WAVE_DIRECTOR_SCENE, \"WaveDirector\")",
        insert + "\t\t_add_child_scene_once(level_root, WAVE_DIRECTOR_SCENE, \"WaveDirector\")",
    )
    c = c.replace(
        "\t\t\t_add_child_scene_once(player, ENGINE_HUM_SCENE, \"PlayerEngineHum\")",
        "\t\t\t_add_child_scene_once(player, ENGINE_HUM_SCENE, \"PlayerEngineHum\")\n"
        "\t\t\t_add_child_scene_once(player, PLAYER_VISUAL_STATE_SCENE, \"PlayerVisualState\")",
    )
    p.write_text(c, encoding="utf-8")
    print("orbital_juice_manager updated")


def patch_player() -> None:
    p = PROJ / "Scripts/player.gd"
    c = p.read_text(encoding="utf-8")
    c = c.replace(
        "\tif not menu_is_hidden or get_tree().paused:\n\t\treturn",
        "\tif _is_pause_blocking():\n\t\treturn",
    )
    if "func _is_pause_blocking" not in c:
        block_fn = """

func _is_pause_blocking() -> bool:
\tvar pause_menu := get_pause_menu()
\tif pause_menu != null and pause_menu.has_method(\"is_gameplay_blocked\"):
\t\treturn pause_menu.call(\"is_gameplay_blocked\")
\treturn not menu_is_hidden or get_tree().paused

"""
        c = c.replace("func update_ui():", block_fn + "func update_ui():")
    c = c.replace(
        "\t# Clean cinematic pause toggle loop\n# Clean cinematic pause toggle\n# Clean cinematic pause toggle\n# Clean cinematic pause toggle\n\tif Input.is_action_just_released(\"Menu\"):\n\t\tvar pause_menu = get_pause_menu()\n\t\tif pause_menu:\n\t\t\tpause_menu.toggle_pause()\n\t\t\tmenu_is_hidden = !pause_menu.active",
        "\tif Input.is_action_just_released(\"Menu\"):\n\t\tvar pause_menu = get_pause_menu()\n\t\tif pause_menu:\n\t\t\tpause_menu.toggle_pause()\n\t\t\tmenu_is_hidden = not pause_menu.is_gameplay_blocked() if pause_menu.has_method(\"is_gameplay_blocked\") else not pause_menu.active",
    )
    c = c.replace(
        "\t# Only compute camera tracking frames if the player isn't fully paused\n\tif menu_is_hidden:",
        "\tif not _is_pause_blocking():",
    )
    p.write_text(c, encoding="utf-8")
    print("player.gd updated")


if __name__ == "__main__":
    patch_project_godot()
    patch_powerup_inventory()
    patch_title_screen()
    patch_orbital_juice_manager()
    patch_player()
