# ORBITRON: VECTORFALL Game Systems And Progression

This document is the current developer-facing map of what the game does, how a run progresses, and where the major systems live.

## Current Game Loop

ORBITRON is a physics-driven arena survival game. The player survives by building velocity, reading gravity fields, slingshotting around mass, and using momentum as a weapon. Waves spawn enemies, hazards, and bosses; gravity, resonance, time dilation, and arena instability increasingly alter the rules.

The game is not a live-state save simulation. `RunProgress` stores stable progression anchors such as wave, boss count, seed, challenge flags, arena flags, and powerup stacks. Loading reconstructs the encounter instead of restoring active projectile or gravity state.

## Run Progression

Standard progression:

1. Waves 1-4 introduce baseline enemies, shooters, orbiters, seekers, and early gravity pressure.
2. Wave 5 spawns Gravity Warden.
3. Wave 10 spawns Accretion Core.
4. Wave 15 spawns Null Vector Seraph.
5. Wave 20 spawns Magnetar Twins.
6. Wave 25 spawns Tidal Rift Weaver.
7. Wave 30 spawns The Polymorph.
8. Wave 35 spawns Centrifuge Marshal.
9. Defeating the wave 35 capstone enters Rupture.
10. Rupture halts waves, pushes the arena into unstable law recombination, and spawns chaotic drifters for 75 seconds.
11. Music Finale begins and spawns The Resonance Singularity.
12. Defeating The Resonance Singularity transitions to credits.

Challenge progression:

- `Challenge Mode` starts the normal scene with challenge flags and skips authored endgame transitions.
- `Boss Rush` starts a deterministic boss-only sequence using the same boss order as standard progression, shorter rest windows, and slightly increased boss health. It ends after the authored boss list has been cleared once.

Optional hidden progression:

- `Vector Shade` can awaken from chained apex slingshot mastery after the run has reached mid-game pressure.
- `Chronal Mirror` can awaken from repeated temporal-scar interaction later in the run.
- Secret bosses use the wave boss UI, but they do not count as authored campaign boss anchors.

## Player Systems

- Thrust spends energy and accelerates along the ship vector.
- Drag toggle lets players choose control or momentum preservation.
- Dash gives a burst of emergency velocity.
- Counter-thrust and lateral thrust have extra control authority, making braking, orbit exits, and course corrections feel responsive even outside combat.
- Gravity pulls from capped nearby gravity sources for performance and deterministic readability.
- Slingshot assists reward tangential movement around gravity sources.
- Slingshot mastery grades are `good`, `great`, `perfect`, and `apex`.
- Momentum combat rewards high-speed impacts, near misses, flow state, overload, and law fusions.
- Bosses resist kinetic impact cheese and punish direct contact with damage plus rebound.

## Resonance And Arena Rules

`GravityResonanceManager` samples overlapping gravity sources and creates tactical zones:

- `Compression / PULL`: pulls bodies toward the zone center.
- `Inversion / PUSH`: pushes bodies outward.
- `Slipstream / FLOW`: slides bodies along the tangent.
- `Temporal Scar / SLOW`: locally slows enemies and projectiles.
- `Harmonic Orbit / ORBIT`: bends bodies into curved arcs.

Each zone emits type, display name, rule name, color, intensity, instability, and decay state. HUD, VFX, audio hooks, and future gameplay systems all read these dictionaries.

Arena instability is handled by `ArenaDestabilizationManager`. It raises chaos from waves, enemies, resonance count, boss presence, and endgame state. It spawns tide pockets, unstable moons, nebula shears, wormhole shear, and finale storm events.

`RunVariationDirector` applies one named seeded run law per run, then cycles combat pacing through calm, tension, overload, and recovery. It can also fire deterministic rare events from the active seed, wave, and run modifier so shareable moments can be reproduced from the pause-menu seed code.

## Time Dilation

`TimeDilationManager` keeps player momentum responsive while slowing enemies and projectiles. It supports global player-triggered dilation, local time pockets, near-miss charge, time tear intensity, and alias signals for future audio/VFX bindings.

Temporal scars and time fracture upgrades can feed into localized slow effects without relying entirely on global engine slowdown.

## Powerups And Law Upgrades

Current powerup definitions:

- `Singularity Amplifier`: increases gravity strength and radius, adds recoil instability, and enables gravity debris on enemy death.
- `Time Fracture Pulse`: slows nearby enemies on player action, stores acceleration during dilation, and releases stored velocity afterward.
- `Shield Overcharge`: restores shield energy and temporarily raises shield capacity.
- `Orbital Tether Upgrade`: increases gravity anchor/control capacity and captures enemy projectiles as temporary satellites.
- `Momentum Shockwave Law`: enables high-speed impact shockwaves.
- `Apex Vector Core`: boosts mastery slingshot capacity and charges high-grade slingshots into a tangent release that flings threats, damages enemies, and creates a harmonic-orbit resonance zone.

Current law fusions:

- Momentum + Singularity bends gravity debris with shockwaves.
- Singularity + Orbital lets satellites anchor around gravity debris.
- Orbital + Time releases satellites with time-fracture velocity.
- Slingshot Law Convergence converts high-skill slingshots into resonance, projectile capture, debris bends, or local slow depending on active stacks.
- Apex Vector Core emits its own law-fusion event for HUD/VFX/audio hooks when the charged release fires.

## Enemies

Current wave enemies and roles:

- Base Enemy: direct pressure and baseline pursuit.
- Base Shooter: standard projectile pressure.
- Orbiter Drone: burst windows and orbiting attack rhythm.
- Gravity Leech: gravitational drain and close pressure.
- Leech Parasite: attachment threat.
- Seeker Fragment: predictive pursuit projectile/body pressure.
- Shield Breaker Unit: telegraphed disruption pressure.
- Chaos Wisp: erratic drifter used in waves and Rupture.
- Splitting Asteroid Bot: split/debris pressure.
- Gravity Harasser: field manipulation pressure.
- Sniper Turret: readable long-range charge shots.
- Shielder Support: protects or supports other enemies.
- Parametric enemies 1-5: movement-language enemies driven by readable mathematical paths.

## Bosses

Bosses mutate physics rules instead of acting as raw bullet spawners:

- Gravity Warden: controls resonance fields.
- Accretion Core: compresses debris and creates collision pressure.
- Null Vector Seraph: creates disruption lanes that interfere with abilities/time.
- Magnetar Twins: uses synchronized push/pull polarity windows.
- Tidal Rift Weaver: rotates rift lanes and moves tide pockets.
- The Polymorph: parametric phase boss with shape/state changes.
- Centrifuge Marshal: wave 35 capstone with shear halos that bend crossed trajectories.
- The Resonance Singularity: final music-driven boss with beat-synced pulses, projectile sweeps, and local gravity collapse.
- Vector Shade: hidden vector-shear boss triggered by chained apex slingshots.
- Chronal Mirror: hidden temporal-gate boss triggered by temporal-scar mastery.

## HUD, Readability, And Accessibility

`OrbitalHUD` shows:

- speed and speed cap
- local gravity strength
- current/nearby field rule
- time dilation state
- event horizon state
- slingshot score and grade
- vector combo/flow state
- offscreen gravity, enemy, and boss arrows

Accessibility settings currently include:

- UI scale
- screen shake scale
- reduced flash alpha
- colorblind readability modes: standard, deuteranopia, protanopia, tritanopia

These settings live on the existing `Settings` autoload and are exposed in the pause menu.

## Menus And State Flow

- Title Screen: starts standard run, continues an anchor, starts challenge mode, starts boss rush, and displays version.
- Pause Menu: freezes gameplay simulation, keeps UI responsive, and offers resume, restart, title abort, accessibility settings, and a copyable run seed code. Its scale is centered and viewport-clamped.
- Game Over: displays `RunProgress.last_death_message`, clears the progress anchor, and offers retry/title.
- Credits: separate non-hostile end state after the final boss.

## Performance Architecture

The game uses capped sampling and modular directors instead of full scene scans everywhere:

- Player gravity sources refresh on an interval and cap source count.
- Resonance caps gravity sources, zones, body targets, and projectile targets.
- Time dilation caps affected targets per tick.
- VFX directors pool/cap active bursts and reduce quality in low-performance mode.
- PerformanceBudgetDirector can auto-lower budgets when FPS drops.

## Current Known Runtime Caveat

Resource/link sweeps pass for the edited files, but runtime validation is blocked until Godot can be launched from the local environment. Do not treat unlaunched systems as playtested until the engine starts cleanly.
