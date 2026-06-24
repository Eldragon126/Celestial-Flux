# VECTOR ANOMALY Game Systems And Progression

This document is the current developer-facing map of what the game does, how a run progresses, and where the major systems live.

## Current Game Loop

Vector Anomaly is a physics-driven arena survival game. The player survives by building velocity, reading gravity fields, slingshotting around mass, and using momentum as a weapon. Waves spawn enemies, hazards, and bosses; gravity, resonance, time dilation, and arena instability increasingly alter the rules.

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
9. Wave 40 spawns THE EXTRADIMENSIONAL BREACHER.
10. Defeating the wave 40 capstone enters Rupture.
11. Rupture halts waves, pushes the arena into unstable law recombination, and spawns chaotic drifters for 75 seconds.
12. Music Finale begins and spawns The Resonance Singularity.
13. Defeating The Resonance Singularity transitions to credits.

Challenge progression:

- `Challenge Mode` starts the normal scene with challenge flags and skips authored endgame transitions.
- `Boss Rush` starts a deterministic boss-only sequence using the same boss order as standard progression, shorter rest windows, and slightly increased boss health. It ends after the authored boss list has been cleared once.

Optional hidden progression:

- `Vector Shade` can awaken from chained apex slingshot mastery after the run has reached mid-game pressure.
- `Chronal Mirror` can awaken from repeated temporal-scar interaction later in the run.
- Secret bosses use the wave boss UI, but they do not count as authored campaign boss anchors.

## Player Systems

- Thrust spends energy and accelerates along the ship vector.
- Drag toggle lets players choose `Precision` control or `Momentum` preservation. Precision mode blends high-speed motion toward aim/tangent during thrust and slingshot windows, softens harsh damping near gravity wells, and grants a small recovery-routing energy return.
- Dash gives a burst of emergency velocity.
- Counter-thrust and lateral thrust have extra control authority, making braking, orbit exits, and course corrections feel responsive even outside combat.
- Gravity pulls from capped nearby gravity sources for performance and deterministic readability.
- Slingshot assists reward tangential movement around gravity sources.
- Slingshot mastery grades are `good`, `great`, `perfect`, and `apex`.
- Vector Bolt projectiles fire immediately on every press and repeat at a fixed cadence while the shoot input is held. Bolts are larger/faster, use a built-in cyan speed trail, ignore baseline player/player-projectile self-gravity, and share constants with the player predictor.
- Player hits start a short readable invulnerability window so stacked burst damage does not erase shield/hull instantly.
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

`ArenaRuleDirector` applies one seeded arena law profile per run. These are alternate arenas as physics rules rather than separate art maps for now:

- `Clean Vector Lattice`: slower law collapse and highly readable resonance.
- `Mirror Well`: more inversion/rebound opportunities.
- `Tidal Skein`: more frequent tide pockets and routing pressure.
- `Chronal Shoal`: stronger short time-pocket play.
- `Harmonic Boneyard`: stronger projectile bending and manual resonance play.

`LateGameInstabilityDirector` starts after late-game pressure begins. It injects capped impossible-physics events without random spam:

- `Resonance Overfold`: overlapping harmonic, inversion, and temporal zones.
- `Temporal Splinter`: local slow applied to nearby threats.
- `Gravity Braid`: paired slipstream/inversion tide events.
- `Collapse Lane`: compression zones arranged across the player's movement line.

Readable chaos tiers label the current instability state from `T0 Calibration` through `T5 Rupture`. `ArenaDestabilizationManager` emits tier changes, the HUD displays the active tier, and high tiers bias arena events toward stronger temporal, inversion, resonance storm, and wormhole shear pressure while modestly increasing tide-pocket visual density.

`ArenaInstabilityDirector` is the data-driven arena mutation layer. It schedules deterministic, telegraphed events from event definitions instead of hard-coded one-off hazards:

- `gravity_tide`: moving tide pressure through existing tide pockets.
- `resonance_storm`: compression, inversion, temporal, and orbit resonance clusters.
- `slipstream_surge`: tangent corridors for high-speed routing.
- `momentum_inversion`: short windows that flip nearby hostile/projectile velocity through `CombatStatus`.
- `collapsing_orbit_lane`: paired orbit/compression lanes across the player's movement axis.
- `spacetime_fracture`: gravity scars that make the arena state persistent and readable.

`RecoveryOpportunityDirector` intentionally creates rare skill-recovery windows when the player is critically pressured. It records near misses, then can spawn slingshot escape corridors, emergency wormholes, resonance rebounds, momentum-conservation chains, or local time-dilation dodge windows. These are deterministic, telegraphed, and still require the player to execute the escape.

`CelestialBodyDirector` spawns active celestial bodies as gameplay objects: binary systems, rogue planets, wandering singularities, and orbital structures. Bodies register as capped gravity sources, orbit anchors, collide/merge, destabilize, split, and apply bounded field pressure to players, enemies, and projectiles.

`RealityCollapseDirector` starts under late/high-instability pressure. It adds deterministic screen-edge breaches, corrupted spacetime regions, overlapping timeline echoes, boundary fractures, physics-constant drift, HUD/camera distortion hooks, and readable reality-collapse notices. It uses existing resonance, scar, time, and camera-shake APIs rather than creating isolated hazards.

`SpacetimeTearDirector` turns strong scar/time-tear activity into short-lived rifts. After the early run, temporal rips, harmonic fractures, and intense scar events can open capped tears that spawn tracked enemies into the active wave, making ripped spacetime a direct battlefield threat instead of only a visual state.

`FairPacingDirector` adjusts only recovery windows, not enemy stats or physics rules. Low health and broken shields can slightly extend the next rest window, while recent mastery can tighten the cadence. This keeps runs difficult but beatable without silently simplifying mechanics.

## Replay, Scores, And Challenge Codes

`RunScoreTracker` is a signal-driven scoring foundation for future community challenges. It scores wave clears, authored boss kills, secret boss kills, perfect/apex slingshots, event-horizon escapes, event-horizon grazes, vector shears, kinetic enemy kills, rare events, and co-op combo payoffs without polling every frame.

The tracker emits:

- `score_changed(score, snapshot)`
- `challenge_code_changed(code)`
- `physics_anomaly_achieved(type, kinetic_factor, score_value, snapshot)`

It also mirrors the latest `score_snapshot` and `challenge_code` into `RunProgress.arena_flags` so other systems can read the unified score state without owning score logic.

Challenge codes use `mode:seed:wave:score_checksum`, where the checksum is a stable SHA-256-derived digest of the unified score snapshot. They are intended for seed-based community challenges and score competitions; they are not anti-cheat infrastructure. Kinetic multiplier scoring captures the player's current velocity at the exact enemy death signal before quantizing an exponential reward. Vector shears score from counter-opposing gravitational impulses, event-horizon grazes require proximity to an `Objects_With_Gravity` source while shield/hull remain undamaged, and apex slingshots score from the player's tangential exit velocity signature. Horizon-graze validation listens to health and shield-hit signals during the horizon window, so regenerated shield does not retroactively qualify a damaged graze.

## Time Dilation

`TimeDilationManager` keeps player momentum responsive while slowing enemies and projectiles. It supports global player-triggered dilation, local time pockets, near-miss charge, time tear intensity, and alias signals for future audio/VFX bindings. Global dilation has a safe minimum scale, and local slow effects are budgeted so temporal/pink effects cannot become a performance or readability wall.

Temporal scars and time fracture upgrades can feed into localized slow effects without relying entirely on global engine slowdown.

## Powerups And Law Upgrades

Current powerup definitions:

- `Singularity Amplifier`: increases gravity strength and radius, adds recoil instability, and enables gravity debris on enemy death.
- `Time Fracture Pulse`: slows nearby enemies on player action, stores acceleration during dilation, and releases stored velocity afterward.
- `Shield Overcharge`: restores shield energy and temporarily raises shield capacity.
- `Orbital Tether Upgrade`: increases gravity anchor/control capacity and captures enemy projectiles as temporary satellites. This is the intentional source of bullets orbiting the player; captured projectiles carry `intentional_orbital_capture` metadata until released.
- `Momentum Shockwave Law`: enables high-speed impact shockwaves.
- `Apex Vector Core`: boosts mastery slingshot capacity and charges high-grade slingshots into a tangent release that flings threats, damages enemies, and creates a harmonic-orbit resonance zone.

Energy droplets are lightweight combat recovery pickups spawned through `PowerupLibrary.try_spawn_energy_droplets()`. Wave-tracked enemies connect their `HealthComponent.died` signal to the wave director, which spawns a small readable cluster that restores `EnergyComponent` on pickup. Droplets magnetize to the player only at close range and disable their particles outside player focus distance.

`PhysicsDropSystem` expands enemy rewards into a physics-based drop ecosystem. Standard enemies drop Fragments and occasional Momentum Orbs. Uncommon enemies can drop Gravity Residue and Temporal Charges. Rare enemies can drop Instability Shards and Anomaly Seeds. Bosses can drop Celestial Cores that grant rule-changing powerup definitions. Drops are readable arena entities, can be bent by gravity where appropriate, decay if ignored, emit collection/expiry telemetry, and avoid generic gold/ammo/health-spam loops. Anomaly Seeds and Celestial Cores can trigger arena-instability, celestial-body, or reality-collapse hooks when those directors are active.

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
- Spacetime tear enemies: existing enemy types that emerge from scar-created rifts and are registered with wave tracking.

## Bosses

Bosses mutate physics rules instead of acting as raw bullet spawners:

- Gravity Warden: controls resonance fields.
- Accretion Core: compresses debris and creates collision pressure.
- Null Vector Seraph: creates disruption lanes that interfere with abilities/time.
- Magnetar Twins: uses synchronized push/pull polarity windows.
- Tidal Rift Weaver: rotates rift lanes and moves tide pockets.
- The Polymorph: parametric phase boss with shape/state changes.
- Centrifuge Marshal: wave 35 late-game boss with shear halos that bend crossed trajectories.
- THE EXTRADIMENSIONAL BREACHER: wave 40 capstone that exits arena bounds, tears through screen edges, opens moving singularities, moon-fragment orbits, slipstream corridors, unstable wormholes, outside-space limb breaches, timeline slams, camera trauma, HUD/reality distortion hooks, and deterministic survival telegraphs.
- The Resonance Singularity: final music-driven boss with beat-synced pulses, projectile sweeps, and local gravity collapse.
- Vector Shade: hidden vector-shear boss triggered by chained apex slingshots.
- Chronal Mirror: hidden temporal-gate boss triggered by temporal-scar mastery.
- Gravity Maw: hidden gravity-eating boss triggered by repeated scar formation; it consumes gravity sources, fractures planets, drains debris, and grows heavier during the fight.

## HUD, Readability, And Accessibility

`OrbitalHUD` shows:

- speed and speed cap
- local gravity strength
- current/nearby field rule
- time dilation state
- event horizon state
- slingshot score and grade
- vector combo/flow state
- readable chaos tier
- offscreen gravity, enemy, and boss arrows

Accessibility settings currently include:

- UI scale
- screen shake scale
- reduced flash alpha
- colorblind readability modes: standard, deuteranopia, protanopia, tritanopia

These settings live on the existing `Settings` autoload and are exposed in the pause menu.

`RunTransitionDirector` adds scene-authored transition polish for major state changes: regular waves, boss waves, wave clears, arena laws, impossible events, co-op combos, Rupture, and the music finale. It is visual punctuation only; it never pauses or drives gameplay.

`DeathFairnessDirector` samples recent run context and appends a readable death readout to the game-over lesson. The readout includes wave, speed, field rule, chaos, projectile density, and whether a boss law was active.

`SkillSignatureDirector` stamps high-skill play into the world with fading orbit glyphs and vector echoes. `SpacetimeSwimDirector` adds the first dedicated spacetime swim/time-glitch layer: ribbons around high-energy movement, a subtle temporal overlay, and capped glitch slices during dilation, time tears, beams, and event-horizon escapes. `SpacetimeTearDirector` makes severe spacetime damage spawn readable rifts and tracked enemy emergence.

`RunTransitionDirector` also listens to arena instability telegraphs, recovery opportunities, celestial events, and reality breaches so systemic events get the same brief readable punctuation as waves and bosses without pausing gameplay.

## Multiplayer Foundation

LAN co-op is implemented as the first active multiplayer layer. `NetworkSession` owns ENet LAN hosting/joining, peer roster records, deterministic run config broadcast, hosted restart, leave-session cleanup, projectile spawn replication, vector event replication, and future Steam transport entry points.

The implementation preserves solo gameplay by keeping transport logic out of combat systems. Player scripts expose state import/export and event hooks; enemies/projectiles use `MultiplayerTargeting` to select a local or nearest valid player; the host owns run seed and scene flow.

`MultiplayerSyncFoundation` now supports active multiplayer readability instead of acting only as passive preparation. It keeps the future from fighting the physics architecture by emitting quantized sync snapshots for:

- run seed, phase, and wave
- active gravity sources
- wave enemies
- bosses
- hostile projectiles

It also emits peer-based readability budgets so co-op UI can reduce clutter as players join.

`CoopComboDirector` is the first deterministic co-op reward layer. Local and remote players can register vector events. When two players hit the combo window, the director creates a shared resonance zone, applies a capped local slow to nearby threats, emits `coop_combo_triggered`, and gives `RunScoreTracker` a score event.

Current multiplayer limits:

- LAN/IP hosting and joining are the supported transport.
- Steam lobbies/relay are pending a GodotSteam/Steam `MultiplayerPeer` plugin.
- Late-join state reconciliation is basic and should not be treated as public drop-in support until wave, boss, hazard, health, and energy reconciliation are tested.
- The game still needs an automated two-instance host/client smoke test before multiplayer is considered release-stable.

Continued functionality roadmap:

- Every new player-owned mechanic must declare its network category: local visual, state export/import, reliable event, or deterministic seed-driven rule.
- Every new hostile targeting path must use `MultiplayerTargeting` or an equivalent roster-aware helper.
- Every new scene-flow button must leave or coordinate the network session explicitly.
- Add version/mod-manifest handshake before public multiplayer testing.
- Add Steam transport only behind `NetworkSession` so LAN and Steam share the same gameplay contract.

## Adaptive Music Foundation

`AdaptiveMusicStateDirector` listens to chaos, resonance intensity, time-tear pressure, and boss pressure. It emits:

- `music_intensity_changed(intensity, layer, reason)`
- `music_beat_hint(event_id, intensity)`

The current layers are `silence`, `drift`, `tension`, `overload`, and `collapse`. This is a hook layer only; final music stems, mixing, and composition binding remain sound-design work.

## Modding Foundation

`ModContentRegistry` discovers data manifests from bundled `res://Mods`, auto-created `user://mods`, export-adjacent desktop `mods`/`Mods`, and optional custom roots. It registers arenas, waves, upgrades, rules, enemies, bosses, arena events, celestial bodies, physics drops, audio/UI entries, weapons, palettes, creator notes, and hookable mod systems from JSON without executing arbitrary code or spawning content automatically.

The registry now exposes two production modding surfaces:

- Playable projectile weapon profiles. `WeaponSystem` reads safe entries from `get_playable_weapon_entries()` and adds mod weapons to the normal selectable weapon catalog, using existing energy, prediction, projectile, HUD, and network event paths.
- Declarative hookable systems. `law_weaves`, `anomaly_recipes`, and `challenge_cards` describe hooks, conditions, effects, weights, cooldowns, and trigger limits. The registry indexes them by hook through `get_hook_entries()` so trusted directors can opt in without letting mods execute scripts.

The registry validates manifests before registration, stores failed manifest reasons, exposes capability/snapshot/scan-root data for UI/debugging, resolves manifest-relative paths for export portability, and contributes a normalized compatibility signature for multiplayer handshakes. `Mods/example_vector_laws/vector_anomaly_mod.json` is the current reference manifest and now includes playable weapons, a law weave, an anomaly recipe, a challenge card, a palette, and creator notes.

Remaining modding work is activation breadth and authoring experience: runtime selection UI, editor tooling, workshop packaging, and director-by-director effect consumption. The code-side foundation is no longer just a catalog; it is a safe declarative modding contract.

## Campaign And Energy Economy Modes

`CampaignModeDirector` adds a scene-editable mother-planet campaign loop. Invader ships spawn in space-invader-style rows, sample gravity from the same bounded source architecture as the rest of the game, and choose between the player and the mother planet as pressure targets. Escort ships orbit the player/mother formation, attack nearby hostiles, and can be bought or hijacked into the fleet.

Energy fragments now also feed `EnergyComponent.energy_currency`, and campaign runs mirror that value into `energy_credits`. The upgrade panel spends those credits on escort ships, speed, damage, armor, slingshot strength, and a hijack-next-ship order. Alien encounter planets use scene-authored turrets that can be bargained down or made hostile, keeping the new campaign layer tied to physics, gravity, and player-readable choices instead of flat menus.

`Nodes/campaign_mode.tscn` and `Nodes/king_of_the_hill_mode.tscn` are playable entry points from the title screen. Both keep bosses/waves disabled in `OrbitalJuiceManager` so the campaign director owns pacing, while shared player, mother planet, escort, invader, and turret scenes remain editable in the Godot scene viewer.

Bundled mod catalogs now include `Mods/space_oregon_trail/vector_anomaly_mod.json` and `Mods/party_modes/vector_anomaly_mod.json`. These are declarative schema 4 packs for future route-day survival, space dysentery, gravity soccer, emote rounds, hijack variants, and battle-ship building without executing mod scripts.

## Menus And State Flow

- Title Screen: starts standard run, opens the playable tutorial, continues an anchor, starts challenge mode, starts boss rush, starts campaign/KOTH modes, hosts LAN play, joins LAN by IP/port, shows Steam transport status, and displays version.
- Pause Menu: freezes gameplay simulation, keeps UI responsive, and offers resume, host-controlled restart, leave/title abort, accessibility settings, a copyable run seed code, mod registry status/rescan, active multiplayer status, and readability budget. Its scale is centered and viewport-clamped.
- Game Over: displays `RunProgress.last_death_message`, clears the progress anchor, and offers retry/title.
- Credits: separate non-hostile end state after the final boss.

## Performance Architecture

The game uses capped sampling and modular directors instead of full scene scans everywhere:

- Player gravity sources refresh on an interval and cap source count.
- Resonance caps gravity sources, zones, body targets, and projectile targets.
- Time dilation caps affected targets per tick.
- VFX directors pool/cap active bursts and reduce quality in low-performance mode.
- `ParticleFocusCuller` focus-gates long-lived `GPUParticles2D` and `CPUParticles2D` nodes by screen/player distance so offscreen particles do not render or emit outside the readable area.
- PerformanceBudgetDirector can auto-lower budgets when FPS drops.
- PerformanceBudgetDirector now also budgets late-game instability events, co-op combo target counts, adaptive music sampling, transition wash alpha, and the new director caps for arena/celestial/reality pressure.

## Current Player Feedback Pass

The latest tuning pass prioritized feel and readability over adding more spectacle:

- Drag ON is now the precision/control style with tactical braking, tangent blending, recovery routing, and small gravity-window energy recovery; Drag OFF remains the high-speed momentum style.
- Gravity Wave Beam now has stronger outcomes: hostile displacement, projectile displacement, short compression zones, planet movement, and planet fracture pressure.
- Chronal Refraction Beam now has timeline echoes, phantom offsets, delayed desync impulses, and short echo zones.
- Player hits have a short readable invulnerability window.
- WaveDirector adds far-orbit planets and validates stationary shooter spawns; WormholePair validates endpoints against planets.
- Player bolts are larger/faster with matching predictor constants and a sharper cyan trail.
- Baseline player bullets now ignore self/player gravity. Bullet orbiting is documented as intentional Orbital Tether capture behavior.
- Pink/purple temporal slowdown has been capped through visual budgets, glitch throttles, slow-effect budgets, and a global time-scale safety floor.

## Universe And Tone

The universe guide defines the simulation fiction, system terms, progression-as-story, and writing rules. The game should talk like a failing physics system giving survival telemetry, not like a generic space shooter.

## Current Known Runtime Caveat

Resource/link sweeps pass for the edited files, but runtime validation is blocked until Godot can be launched from the local environment. Do not treat unlaunched systems as playtested until the engine starts cleanly.
