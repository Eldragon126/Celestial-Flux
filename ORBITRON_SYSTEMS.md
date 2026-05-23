# ORBITRON: VECTORFALL Systems Notes

## Runtime Install Flow

`OrbitalJuiceManager` installs modular gameplay layers into the active level:

- `OrbitalHUD` owns player-facing readouts, gravity arrows, and offscreen threat arrows.
- `GravityResonanceManager` samples gravity-source overlap and emits zone dictionaries for gameplay, VFX, HUD, and audio.
- `TimeDilationManager` applies player-safe dilation plus localized time pockets through metadata and lightweight signals.
- `OrbitalVFXDirector` listens to gameplay signals and spawns capped burst particles from inspector-editable templates.
- `PerformanceBudgetDirector` adjusts particle and VFX budgets for quality tiers.

## Particle Rules

One-shot detached bursts should use reusable scenes, set their final transform before emission, and free themselves after their visible lifetime.

`CollisionSparks` defers emission by one idle step so callers can add it to the tree and set `global_position` safely. Long-lived gameplay particles should remain child nodes of the entity they visualize. Detached trails must call a cleanup path such as `fade_and_free()`.

## Enemy And Boss Visuals

Bosses and enemies should prefer scene-authored child nodes:

- `Polygon2D` for hulls, cores, shields, glows, and telegraphs.
- `Line2D` for rings, arcs, shear lanes, and readable orbit rules.
- `GPUParticles2D` for trails, fields, charge effects, and aura motion.
- `Area2D`/`CollisionShape2D` children for readable interaction zones.

Scripts may create fallback nodes when a scene is missing them, but should first look up named child nodes and only fill default geometry when the polygon is empty.

## Threat Indicators

`OrbitalHUD` keeps gravity arrows and threat arrows in the same screen-edge visual language:

- Gravity arrows are cyan and point to offscreen gravity sources.
- Enemy arrows are amber, smaller, and capped.
- Boss arrows are red, larger, and pulse subtly.

The system samples targets on a short interval and only draws arrows for offscreen targets to avoid UI clutter during late-run chaos.

## Resonance Architecture

`GravityResonanceManager` supports these zone types:

- `compression`
- `slipstream`
- `inversion`
- `temporal_scar`
- `harmonic_orbit`

Every zone dictionary includes type, color, rule label, intensity, instability, decay, and decay state. Signals are intentionally lightweight so VFX, HUD, audio, and future gameplay systems can bind without creating a monolithic manager.

## Time Dilation Architecture

`TimeDilationManager` avoids global slowdown by default. It keeps player motion responsive while applying local time pockets to enemies, bosses, and enemy projectiles. Existing signals remain, and aliases are provided for broader system hooks:

- `dilation_started`
- `dilation_ended`
- `pocket_entered`
- `pocket_exited`
- `instability_changed`

Targets read `local_time_scale` metadata through `CombatStatus` or manager helpers. This keeps future deterministic sync work easier than serializing live physics state.

## Boss Framework

`PhaseBoss` provides shared health, phase, and attack timer behavior. Individual bosses own their readable physics mutation. Async telegraphs should always bail if the boss has been queued for deletion before firing the attack.

Projectile attacks should use `enemy_bullet.configure_launch(direction, speed, source)` so source collision exceptions and spawn safety are deterministic.

## Endgame Flow

`RunProgress.on_boss_defeated()` treats the wave 35 capstone boss as authoritative. When `res://Nodes/centrifuge_marshal_boss.tscn` is defeated, the run enters `RUPTURE` even if the wave director has not finished advancing its own wave-cleared state yet.

`RunDirector` then halts waves, shows the rupture banner, starts `RuptureDirector`, and moves into `MusicFinaleDirector` after the rupture countdown. `MusicFinaleDirector` spawns `res://Nodes/music_resonance_boss.tscn`; music beat events call the boss pulse, burst, and finale methods directly. The credits transition occurs when that boss is defeated.

## Pause And Game Over

`PauseMenu` runs in `PROCESS_MODE_ALWAYS`, fades the simulation into a true paused state, and exposes three scene-authored buttons: resume, restart, and abort to title.

Player death stores `RunProgress.last_death_message`, then changes to `res://Nodes/game_over_scene.tscn`. The game-over scene clears the progress anchor and displays the exact death vector lesson before allowing a retry or title return.

## Accessibility And Challenge Modes

`Settings` now exposes UI scale, screen shake scale, reduced flash, and colorblind readability modes. The pause menu writes these values directly, while HUD colors, HUD scale, camera shake, and mastery flash alpha read from the same singleton.

`RunProgress.begin_boss_rush()` starts a boss-only challenge profile. `WaveDirector` treats every boss-rush wave as a boss wave, cycles the authored boss list deterministically, reduces rest windows, and applies the boss health modifier from `challenge_modifiers`.

The pause menu displays `RunProgress.get_run_seed_code()` and can copy it to the clipboard. The current format is `mode:seed:wave`.
