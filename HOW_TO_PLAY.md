# VECTOR ANOMALY How To Play

## Core Fantasy

You survive by mastering momentum inside collapsing gravity rules. Movement is the main weapon: slingshot around mass, preserve velocity, read field direction, and escape before the arena folds around you.

## Movement

- `thrust` accelerates along the ship vector and spends energy.
- `rotate_ccw` / `rotate_cw` steer the ship orientation.
- `Toggle` changes drag mode, letting advanced players preserve speed at the cost of control.
- Double-tap thrust release to dash when available.
- Good movement keeps a clean tangent around gravity wells instead of fighting directly against them.
- `PLAYER AUTO-ORBIT` in the pause settings enables continuous tangent/proximity assistance. It defaults off; the one-shot slingshot reward remains available in either mode.
- `ORBITING CELESTIAL EVENTS` controls binary systems and orbiting structures, not the ship. Those arena events default on.

## Slingshot Mastery

Slingshot assists trigger when you pass near a gravity source with enough tangential speed. Better slingshots come from:

- entering the sweet-distance band instead of scraping the core
- carrying strong tangential speed
- diving inward enough to build pressure
- exiting with a recoverable orbit angle

Grades are `good`, `great`, `perfect`, and `apex`. Higher grades grant stronger momentum bonuses and can seed resonance effects through upgrade synergies.

## Momentum Combat

High-speed collisions can damage enemies. Bosses resist most kinetic impact damage and punish direct crashes with contact damage plus a rebound, so boss fights should be won through controlled passes, field reading, projectile pressure, and timing rather than sticking to the boss.

## Resonance Zones

Resonance zones are tactical arena rules created by overlapping gravity sources and mastered slingshots.

- `Compression / PULL`: bodies fall toward the zone core. Use it to bunch enemies, bend projectiles, or slingshot through a dangerous center.
- `Inversion / PUSH`: bodies are pushed outward. Treat it like a repulsion field for emergency escape routes or projectile denial.
- `Slipstream / FLOW`: bodies slide along the zone tangent. Use it to gain lateral speed and convert panic into an orbit.
- `Temporal Scar / SLOW`: enemies and shots lose time inside the zone. Use it to thread dense projectile fields without globally slowing the player.
- `Harmonic Orbit / ORBIT`: bodies curve into stable arcs. Use it for controlled trickshots, recovery loops, and orbit setup.

Zone visuals use color, label, and glyph direction to show the rule. If a zone becomes intense, assume it can alter both movement and projectile paths.

## Time Dilation

Hold `time_dilation` to smoothly deepen a local time field around the ship. The thin cyan boundary marks its reach. Slow is strongest near the player and falls off toward that boundary, turning dilation into a positioning tool instead of a global panic button. The player keeps momentum responsiveness while nearby enemies, bosses, and hostile projectiles consume scaled simulation time. The HUD reports both field strength and how many threats are inside it even though `Engine.time_scale` stays at 1 by default. Releasing the key fades the field and shader overlay instead of flashing them off.

## Upgrades And Synergies

Upgrades should change behavior, not only numbers. Current/future law examples:

- Momentum impacts can create shockwaves.
- Orbital mastery can turn captured projectiles into satellites.
- Singularity effects can leave short-lived gravity debris.
- Time fracture effects can store acceleration during slow time and release it afterward.

Synergies are strongest when they create new movement decisions instead of raw damage inflation.

## Boss Rules

Every boss mutates one readable physics rule:

- Gravity Warden: resonance field control.
- Accretion Core: debris compression and collision pressure.
- Null Vector Seraph: local ability and time disruption lanes.
- Magnetar Twins: synchronized push/pull polarity windows.
- Tidal Rift Weaver: rotating rift lanes and tide pockets.
- Centrifuge Marshal: shear halos that bend crossed trajectories.
- The Resonance Singularity: music-timed pulses, sweeps, and local gravity collapse.

## Progression

Waves build toward fixed boss milestones at 5, 10, 15, 20, 25, 30, and 35. After the wave 35 capstone boss, waves shut down and the run enters Rupture. Rupture lasts 75 seconds, then the music finale spawns The Resonance Singularity. Defeating it transitions to credits.

Boss Rush is a challenge mode that runs the boss sequence back to back with shorter rest windows and no authored rupture/finale transition.

## Arena Laws

Each standard run can apply a seeded arena law profile. These are alternate arena rules before they are separate maps:

- `Clean Vector Lattice`: clearer vectors and slower collapse.
- `Mirror Well`: more inversion/rebound play.
- `Tidal Skein`: tide pockets appear more often.
- `Chronal Shoal`: short time-pocket decisions matter more.
- `Harmonic Boneyard`: projectile bending and resonance capacity matter more.

Late game can also trigger impossible-physics events such as resonance overfolds, temporal splinters, gravity braids, and collapse lanes. They are dangerous, but capped and rule-driven.

## Readable Chaos Tiers

Arena instability is shown as a named chaos tier in the HUD:

- `T0 Calibration`: baseline rules, clean vector reading.
- `T1 Distortion`: early law stress and light event pressure.
- `T2 Contamination`: more overlapping field rules.
- `T3 Collapse`: faster hazard cadence and stronger visual pressure.
- `T4 Event Horizon`: inversion, temporal pockets, storms, and wormhole shear become more likely.
- `T5 Rupture`: maximum controlled instability.

The tiers do not replace physics. They label the current instability state so escalating chaos remains learnable.

## Difficulty And Death Readouts

The game should stay hard without hiding why you failed. Recovery windows can flex slightly after waves based on player condition and mastery, but enemies, bosses, gravity, and resonance rules are not silently weakened.

On death, the game over screen shows a death vector lesson plus a concrete readout: wave, speed, nearby field rule, chaos level, projectile density, and whether a boss law was active.

## Co-op Foundation

LAN co-op is now live as the first multiplayer implementation. From the title screen, one player can host and play, while other players join by IP address and port. The host owns the run seed, scene start/restart, and shared run configuration; clients control their own local ship and receive remote player proxies.

Shared vector events can combine into a co-op resonance payoff that bends local space and slows nearby threats. Projectile spawns, player movement state, peer colors, and peer nameplates are network-aware, while solo mechanics remain unchanged.

Steam co-op is still a transport roadmap item. The current session layer is designed so Steam lobby/peer support can be added behind `NetworkSession` without rewriting gameplay logic.

## Adaptive Music Hooks

The music foundation now tracks gameplay pressure as layers: `silence`, `drift`, `tension`, `overload`, and `collapse`. Final music mixing is still a sound-design pass, but the game already emits clean hooks from chaos, resonance, time tears, and boss pressure.

## Seeds, Scores, And Challenges

The pause menu shows the current seed code for sharing a run. `RunScoreTracker` also tracks wave clears, bosses, secret bosses, mastery slingshots, rare events, and event-horizon escapes for future community challenges.

Challenge codes are seed-based score summaries. They are meant for friendly competitions and reproducible challenge runs, not as a final online leaderboard yet.

## Gravity Ghost

After a run ends, the game-over screen reconstructs the local player's final movement path. Cyan marks the controlled route, orange marks rising danger, and timeline markers show great slingshots, near misses, successful recovery windows, or event-horizon escapes. A bottom lane graphs speed, overall pressure, and pressure components such as projectiles, hostile density, hull danger, and gravity load, so the replay reads like a compact black box. It loops automatically and never delays the retry buttons.

## Mods

The first modding foundation is data-driven. `ModContentRegistry` can discover `vector_anomaly_mod.json` manifests from `res://Mods` and `user://mods` with entries for arenas, waves, upgrades, and gameplay rules. The registry does not automatically run mod code.

The pause menu has a Modding section that shows loaded manifest counts, failed manifest reasons, and a `RESCAN MODS` button. An example manifest lives at `res://Mods/example_vector_laws/vector_anomaly_mod.json`.

See `MODDING_GUIDE.md` for the current manifest shape and validation rules.

## Accessibility

The pause menu exposes readability controls:

- UI scale
- screen shake intensity
- reduced flash
- colorblind modes for common readability palettes

It also exposes the current run seed, mod registry status, active multiplayer status, and co-op readability budget so debugging and sharing stay inside the game UI instead of requiring console inspection.

Pause now works in the tutorial, Steam demo, Clip Lab, and normal campaign. The restart/exit buttons rename themselves for that context: tutorial restart returns to the playable tutorial, Steam demo retry returns to the demo scene, Clip Lab reset returns to the capture lab, and a normal run restart still routes through the run loading screen.

The HUD uses compact vector glyphs beside the major readouts. These icons react to hull, shield, energy, speed, gravity, field, time, horizon, chaos, slingshot, weapon, and run-phase state while respecting the same readability colors as the text.

## Developer Notes

- Main playable scene: `res://Nodes/the_abyss.tscn`
- Progress anchor: `RunProgress` autoload, stored at `user://run_anchor.save`
- Pause must freeze gameplay and keep UI responsive, including tutorial/demo/lab contexts.
- LAN multiplayer entry point: `NetworkSession` autoload. Keep transport/session behavior there instead of spreading networking through gameplay scripts.
- Host controls network run start/restart; clients leave cleanly to title if the session ends.
- Remote players are proxies. They should not process local input, HUD, camera, pause UI, or local trajectory/aim predictors.
- New player-owned abilities must be categorized as local-only visuals, exported state, reliable network events, or deterministic seed-driven behavior.
- Save data reconstructs progression only; never serialize live physics state.
- Use inspector-authored child nodes for important polygons, trails, telegraphs, particles, and hit shapes.
- Debug hotkeys live on `OrbitalJuiceManager` when `enable_dev_hotkeys` is enabled.
- `MultiplayerSyncFoundation` provides deterministic snapshot/readability budgets that now support active LAN sessions and future Steam transport work.
- `ArenaRuleDirector`, `LateGameInstabilityDirector`, `CoopComboDirector`, and `AdaptiveMusicStateDirector` are modular child systems installed by `OrbitalJuiceManager`.
- `RunTransitionDirector`, `FairPacingDirector`, and `DeathFairnessDirector` add polish, beatable pacing, and fair failure context without owning combat logic.
