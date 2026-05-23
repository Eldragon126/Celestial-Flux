# ORBITRON: VECTORFALL How To Play

## Core Fantasy

You survive by mastering momentum inside collapsing gravity rules. Movement is the main weapon: slingshot around mass, preserve velocity, read field direction, and escape before the arena folds around you.

## Movement

- `thrust` accelerates along the ship vector and spends energy.
- `rotate_ccw` / `rotate_cw` steer the ship orientation.
- `Toggle` changes drag mode, letting advanced players preserve speed at the cost of control.
- Double-tap thrust release to dash when available.
- Good movement keeps a clean tangent around gravity wells instead of fighting directly against them.

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

Time dilation is player-safe by design. The player keeps momentum responsiveness while enemies and projectiles can be locally slowed through time pockets, temporal scars, and near-miss charge.

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

## Accessibility

The pause menu exposes readability controls:

- UI scale
- screen shake intensity
- reduced flash
- colorblind modes for common readability palettes

## Developer Notes

- Main playable scene: `res://Nodes/the_abyss.tscn`
- Progress anchor: `RunProgress` autoload, stored at `user://run_anchor.save`
- Pause must freeze gameplay and keep UI responsive.
- Save data reconstructs progression only; never serialize live physics state.
- Use inspector-authored child nodes for important polygons, trails, telegraphs, particles, and hit shapes.
- Debug hotkeys live on `OrbitalJuiceManager` when `enable_dev_hotkeys` is enabled.
