from pathlib import Path

p = Path(r"C:\Users\elden\Desktop\Gravity Ideas\VECTOR ANOMALY\Scripts\wave_director.gd")
c = p.read_text(encoding="utf-8")

c = c.replace("var delay := spawn_delay", "var delay: float = spawn_delay")

if "func _build_late_game_roster" not in c:
    late = """
func _build_late_game_roster() -> Array:
\tvar elite: Array = [
\t\tCHAOS_WISP_SCENE, SHIELD_BREAKER_SCENE, SNIPER_SCENE, HARASSER_SCENE,
\t\tPARAMETRIC_4_SCENE, PARAMETRIC_5_SCENE, SEEKER_FRAGMENT_SCENE, GRAVITY_LEECH_SCENE,
\t]
\tvar roster: Array = []
\tvar count: int = mini(8 + int((_wave - RunProgress.LATE_GAME_START_WAVE) * 0.5), max_regular_enemies + 4)
\tfor i in range(count):
\t\troster.append(elite[i % elite.size()])
\treturn roster

"""
    c = c.replace("\treturn roster\n\nfunc _spawn_enemy(scene: PackedScene", late + "\treturn roster\n\nfunc _spawn_enemy(scene: PackedScene")

# Ensure _spawn_enemy always returns
if "return enemy\n" not in c and "return enemy\r\n" not in c:
    c = c.replace(
        "\tenemy_2d.global_position = _spawn_position_for_index(_active_enemies.size())\n\n\treturn enemy",
        "\tenemy_2d.global_position = _spawn_position_for_index(_active_enemies.size())\n\n\treturn enemy",
    )

p.write_text(c, encoding="utf-8")
print("fixed")
