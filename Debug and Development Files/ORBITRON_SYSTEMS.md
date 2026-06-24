# VECTOR ANOMALY Systems Notes

## Runtime Install Flow

`OrbitalJuiceManager` installs modular gameplay layers into the active level:

- `RuntimeRegistry` is the autoload cache for gravity sources, projectile groups, enemy groups, boss groups, and player targets. Hot systems use it instead of rescanning scene groups during physics ticks.
- `OrbitalHUD` owns player-facing readouts, gravity arrows, and offscreen threat arrows.
- `DebugBalanceOverlay` is restored as development telemetry by default and remains toggleable with F3.
- `GravityResonanceManager` samples gravity-source overlap and emits zone dictionaries for gameplay, VFX, HUD, and audio.
- `TimeDilationManager` applies player-safe dilation plus localized time pockets through metadata and lightweight signals.
- `OrbitalVFXDirector` listens to gameplay signals and spawns capped burst particles from inspector-editable templates.
- `ParticleFocusCuller` focus-gates long-lived particle nodes by screen/player distance.
- `PerformanceBudgetDirector` adjusts particle and VFX budgets for quality tiers.
- `RunVariationDirector` applies seed-named run laws, pacing states, and deterministic rare events.
- `SecretBossDirector` listens for hidden mastery conditions and registers optional bosses with the wave UI.
- `MultiplayerSyncFoundation` emits passive deterministic sync snapshots and co-op readability budgets.
- `CoopComboDirector` turns sync-safe vector events into deterministic shared resonance/time payoffs.
- `ModContentRegistry` discovers data-driven mod manifests without executing arbitrary code.
- `ModHookDirector` consumes safe hookable mod entries, evaluates conditions, applies bounded whitelisted effects, records deferred director requests, and replays player-triggered hook effects through `NetworkSession`.
- `RunScoreTracker` emits score snapshots and shareable challenge codes.
- `GravityGhostRecorder` keeps a bounded local-player movement ring and exports the final route plus mastery highlights for game-over reconstruction.
- `PhysicsDropSystem` spawns physics-based enemy rewards from death signals.
- `ArenaRuleDirector` applies seeded arena law profiles for alternate arena physics.
- `ArenaInstabilityDirector` schedules data-driven battlefield mutations.
- `LateGameInstabilityDirector` injects capped impossible-physics events in late game.
- `RecoveryOpportunityDirector` creates rare deterministic near-death recovery windows.
- `CelestialBodyDirector` spawns active orbiting/merging/splitting celestial bodies.
- `RealityCollapseDirector` escalates high-instability reality failure events.
- `AdaptiveMusicStateDirector` emits music intensity layers and beat hints from gameplay pressure.
- `RunTransitionDirector` provides scene-authored visual punctuation for major state changes.
- `FairPacingDirector` adjusts recovery windows from player condition/mastery without changing physics depth.
- `DeathFairnessDirector` appends concrete death context to game-over lessons.
- `SkillSignatureDirector` stamps capped orbit glyphs and vector echoes from high-skill play.
- `SpacetimeSwimDirector` adds capped swim ribbons, temporal overlay, and glitch slices for spacetime events.
- `SpacetimeTearDirector` opens capped enemy-spawning rifts from strong scar/time-tear activity.
- `StressTestDirector` remains opt-in and is used by `production_simulation_runner.gd` for headless extreme-load validation.

## Particle Rules

One-shot detached bursts should use reusable scenes, set their final transform before emission, and free themselves after their visible lifetime.

`CollisionSparks` defers emission by one idle step so callers can add it to the tree and set `global_position` safely. Long-lived gameplay particles should remain child nodes of the entity they visualize. Detached trails must call a cleanup path such as `fade_and_free()`.

`OrbitalVFXDirector` prewarms burst pools per template and reuses those `GPUParticles2D` nodes for time dilation, kinetic impact, resonance, slingshot, and ambient feedback. New burst templates must be added to the pool path rather than duplicated at signal time.

Powerup and law-fusion feedback rings are pooled `Line2D` nodes. Upgrade pickup flashes, slingshot law convergence, Apex Vector releases, Barycentric/Frame-Dragging pickup feedback, and fusion feedback must reuse the inventory ring pools and respect `Settings.flash_alpha()`.

Long-lived pickup/debris particles must be focus-gated. `PowerupPickup`, `EnergyDroplet`, and `GravityDebris` keep their gameplay visuals active but disable `GPUParticles2D.visible` and `emitting` outside player focus range. `ParticleFocusCuller` is the global fallback for any remaining long-lived `GPUParticles2D` or `CPUParticles2D` node; it scans at an interval, caches tracked particles, and gates rendering/emission only near the screen or player.

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

HUD discovery is registry-backed. Gravity readouts sample the same capped nearest-source model as the player at 20 Hz, field text refreshes at a readable 8 Hz, planet-arrow membership refreshes at 5 Hz, and screen projection remains smooth between membership refreshes. Layout recomputation now occurs only when viewport size or UI scale changes. Rare-event and tide groups are tracked by `RuntimeRegistry`, so the HUD no longer performs live scene-tree group scans during its normal frame loop.

The readout panels now use code-native vector glyphs rather than placeholder bitmap assets. Hull, shield, energy, speed, gravity, field, time, horizon, chaos, slingshot, weapon, and run-phase glyphs are drawn from live HUD state, inherit `Settings` readability colors, and expose separate activity/severity channels so warning states remain scannable under colorblind palettes.

## Resonance Architecture

`GravityResonanceManager` supports these zone types:

- `compression`
- `slipstream`
- `inversion`
- `temporal_scar`
- `harmonic_orbit`

Every zone dictionary includes type, color, rule label, intensity, instability, decay, and decay state. Signals are intentionally lightweight so VFX, HUD, audio, and future gameplay systems can bind without creating a monolithic manager.

Current visual readability rules:

- In-world labels use action language, not system jargon: `PULL IN`, `PUSH OUT`, `FLOW ARC`, `SLOW SHOTS`, and `ORBIT BEND`.
- Manual slingshot-created resonance zones merge with nearby matching zones and cap their active count to avoid unreadable ring stacks.
- Resonance visual alpha is intentionally subdued; gameplay meaning should come from shape, direction, and label before brightness.
- Automatic resonance is capped to the strongest local zones, decays aggressively, and only renders when it is intense enough and close enough to the player to matter.
- Harmonic orbit fields require stronger source overlap than compression/slipstream fields and slingshot-created harmonic zones only appear on apex-quality orbital play.
- Mechanic audio ignores low-intensity automatic zone churn so resonance sound is reserved for meaningful field events.

## Weapon Field Rules

`WeaponSystem` owns beam weapons. Gravity Wave Beam is a field-control beam, not just a damage line:

- it applies damage to hostile targets each beam tick
- it pulls enemies and enemy projectiles toward the beam axis
- it can push destructible planets, adding fracture pressure and visible displacement metadata
- it stamps a short compression resonance zone instead of long-lived slipstream clutter
- it stops immediately when gameplay is paused or the player enters death flow

Chronal Refraction Beam is the time-fantasy beam. It applies local slow, draws capped timeline echo traces, stores desync impulse metadata, and fires a delayed lateral impulse/damage chain that can create a short temporal echo zone. Echoes are capped per beam tick so the effect stays readable instead of becoming the pink/purple slowdown wall.

## Time Dilation Architecture

`TimeDilationManager` avoids global slowdown by default. A smoothed activation blend immediately drives the reported field scale, local enemy/boss/projectile multipliers, HUD, and screen shader while `Engine.time_scale` stays at 1. The player-authored field is spatial: registry-backed radius queries select nearby threats, and slow strength falls off toward the boundary. This makes dilation reward entering danger and controlling distance rather than freezing the entire arena. Local fields use their own expiry metadata channel, so `CombatStatus` can combine them with weapon/status slows without either system deleting the other. Velocity is no longer repeatedly multiplied and restored; targets consume scaled simulation time instead. Target counts, minimum multipliers, and group quotas remain bounded. Existing signals remain, and aliases are provided for broader system hooks:

- `dilation_started`
- `dilation_ended`
- `pocket_entered`
- `pocket_exited`
- `instability_changed`

Targets read status and time-field metadata through `CombatStatus` or manager helpers. This keeps future deterministic sync work easier than serializing live physics state.

## Boss Framework

`PhaseBoss` provides shared health, phase, and attack timer behavior. Individual bosses own their readable physics mutation. Async telegraphs should always bail if the boss has been queued for deletion before firing the attack.

Projectile attacks should use `enemy_bullet.configure_launch(direction, speed, source)` so source collision exceptions and spawn safety are deterministic.

`WaveDirector` applies production boss pressure after scene `_ready()` so authored boss scripts keep their editable setup while still receiving wave-appropriate difficulty. The tuning scales health floors, attack timers, projectile pressure, contact damage, movement pressure, and Polymorph's phase pressure.

`ExtradimensionalBreacherBoss` is the wave 40 capstone. It extends `PhaseBoss`, physically moves outside the viewport before slamming back into the arena, and uses deterministic attacks built from existing systems: moving singularities, orbiting moon fragments, slipstream corridors, unstable wormholes, outside-space breaches, timeline slams, gravity scars, resonance zones, camera trauma, and reality-collapse hooks. The boss can look like the simulation is failing, but every attack path still creates telegraph geometry before damage/pressure.

## Secret Bosses

`SecretBossDirector` adds optional hidden boss routes without changing authored campaign milestones:

- `Vector Shade` awakens after chained apex-quality slingshots once the run is deep enough.
- `Chronal Mirror` awakens from repeated temporal-scar interaction later in the run.
- `Gravity Maw` awakens after repeated gravity-scar formation and consumes gravity sources as its core rule.

When a hidden boss appears, the director calls `WaveDirector.register_secret_boss()`. The wave director shows the boss panel, pauses regular wave completion around the secret boss, and does not emit a campaign boss anchor when the secret boss dies.

`SecretLawBoss` extends `PhaseBoss` and keeps its visuals scene-authored: hull/core polygons, rule rings, particles, and collision children remain editable in the inspector. Its variants mutate motion rules through vector shear or temporal gates, then drop guaranteed powerup rewards.

`GravityMawBoss` also extends `PhaseBoss`. It pulls bodies inward, damages/fractures planets through `apply_spacetime_damage()`, drains gravity debris, grows its mass from consumed gravity, stamps gravity scars, and periodically creates compression resonance zones. It is a boss encounter about losing the arena's gravitational structure, not a normal projectile duel.

## Run Variation And Pacing

`RunVariationDirector` makes run seeds visible in play through named modifiers instead of hidden stat drift:

- `Comet Wake`: stronger slingshot and gravity-charge feel.
- `Dense Stars`: denser enemy/resonance pressure.
- `Temporal Draft`: faster time-dilation charge and arena events.
- `Quiet Recovery`: longer recovery windows and shorter hazard tails.
- `Volatile Lattice`: higher arena instability and easier resonance formation.

The same director cycles wave pacing through `calm`, `tension`, `overload`, and `recovery` by tuning wave spawn delay and rest windows. Rare events are deterministic from seed/wave/modifier, so shareable moments can be reproduced by seed code.

`ArenaDestabilizationManager` now exposes readable chaos tiers 0-5: calibration, distortion, contamination, collapse, event horizon, and rupture. The tiers are derived from instability, shown on the HUD, emitted through `chaos_tier_changed`, and used to tune event cadence/content plus tide-pocket visual density. This gives late-run chaos a named ladder instead of an unreadable meter.

## Arena Rule Profiles

`ArenaRuleDirector` is the first alternate-arena foundation. It does not swap the whole level yet; instead it applies a seeded physics profile to existing directors:

- `Clean Vector Lattice`: readable baseline with slower instability.
- `Mirror Well`: inversion and rebound emphasis.
- `Tidal Skein`: more frequent tide pockets.
- `Chronal Shoal`: stronger short time-pocket play.
- `Harmonic Boneyard`: stronger projectile bending and manual resonance capacity.

This keeps the separation blueprint intact: the difference between arenas is physical law and movement decision space, not just background art.

## Late-Game Impossible Physics

`LateGameInstabilityDirector` begins after the run reaches late pressure. It creates capped, deterministic law events:

- `resonance_overfold`: layered harmonic/inversion/temporal resonance.
- `temporal_splinter`: local slow on nearby threats.
- `gravity_braid`: paired slipstream and inversion tide pockets.
- `collapse_lane`: compression zones laid across the player's movement line.

The director uses existing resonance, arena, and time APIs, so events remain readable, inspectable, and bounded.

## Arena Instability Director

`ArenaInstabilityDirector` is a data-driven battlefield mutation layer. Event definitions specify id, telegraph time, duration, radius, color, weight, and minimum wave. The active set currently includes gravity tides, resonance storms, slipstream surges, momentum inversions, collapsing orbit lanes, and spacetime fractures.

The director emits telegraph/start/end signals and creates short HUD notices. Gameplay effects are routed through `GravityTidePocket`, `GravityResonanceManager`, `GravityScarManager`, `TimeDilationManager`, and `CombatStatus`, so arena mutations remain part of the core physics language instead of isolated hazard scripts.

## Recovery Opportunities

`RecoveryOpportunityDirector` samples player health/shield, nearby threat density, speed, and near-miss telemetry at a capped interval. When the player is critically pressured and the deterministic cooldown allows it, the director creates one rare recovery opportunity:

- slingshot escape corridor
- emergency wormhole exit
- resonance rebound
- momentum conservation chain
- time-dilation dodge window

Near misses are stored in `RunProgress.arena_flags` as counts/recent records, emitted through `near_miss_recorded`, and recovery windows emit start/resolved signals for HUD, score, and transition listeners. These windows should feel earned, not charitable: they create a route, but the player still has to read and execute the physics.

## Dynamic Celestial Bodies

`CelestialBodyDirector` and `DynamicCelestialBody` make celestial bodies active run participants. Bodies can orbit anchors, drift, register as capped gravity sources, collide, merge, destabilize, split, and apply bounded field pressure to players, enemies, and projectiles. Current seeded events include binary systems, rogue planets, wandering singularities, and orbital structures.

This keeps runs feeling like changing orbital puzzles while respecting the existing 3-4 gravity-source sampling caps.

## Reality Collapse

`RealityCollapseDirector` activates from late-game/high-instability pressure. It opens deterministic screen-edge breaches, corrupted spacetime regions, overlapping timeline echoes, and boundary fractures. It can drift player-local gravity/drag constants temporarily, sends camera trauma through `DamageCameraShake.add_trauma()`, and uses resonance/scar APIs for gameplay effects.

Reality collapse is escalation, not unreadable randomness: events have cooldowns, caps, HUD notices, and predictable geometry.

## Transition Juice

`RunTransitionDirector` is a `CanvasLayer` with editable child nodes:

- `Wash`
- `VectorLine`
- `TransitionLabel`

It listens to wave, boss, arena-law, arena-instability, recovery-opportunity, celestial-event, reality-breach, impossible-event, co-op combo, Rupture, and finale signals. The effect is deliberately brief and non-blocking so it adds juice without hiding the player or pausing the simulation.

## Skill Signatures And Spacetime Swim

`SkillSignatureDirector` turns mastery into persistent but capped world marks:

- perfect/apex slingshots stamp orbit glyphs and vector echoes
- kinetic shockwaves stamp impact signatures
- Apex Vector releases stamp larger harmonic vector marks
- event-horizon escapes stamp survival signatures

These signatures fade and self-clean, so they communicate player mastery without becoming permanent clutter.

`SpacetimeSwimDirector` owns the first explicit swimming-through-spacetime effect. It listens to time dilation, time-tear intensity, local time pockets, slingshot mastery, beam weapons, and event-horizon signals. It now renders compact phase-shell strokes around the player rather than long attached curves, with throttled beam triggers, lower lifetime, lower counts, subtle screen wash, and capped glitch slices. Low-performance mode reduces ribbon/slice counts and overlay alpha through `OrbitalJuiceManager`.

## Spacetime Tears

`SpacetimeTearDirector` listens to `GravityScarManager` and `TimeDilationManager`. Strong temporal rips, harmonic fractures, intense inversion wakes, or very high scar intensity can open a short-lived rift after the run is far enough along. Each rift has capped visuals, capped spawn count, a global cooldown, and a minimum distance from the player so tears feel dangerous without becoming unfair point-blank ambushes.

Enemies that emerge from tears are registered through `WaveDirector.register_external_enemy()`, so wave completion still accounts for them. Low-performance mode reduces active tear count, alive tear enemies, and ring segment density.

## Fair Pacing And Death Readouts

`FairPacingDirector` preserves difficulty through physics but adjusts recovery time after wave clears:

- low health: longer recovery
- broken shield: modestly longer recovery
- recent mastery: slightly shorter recovery

The broken-shield check accepts both exported player references and scene-authored `Shield`/`ShieldComponent` nodes, so the recovery window survives prefab or scene organization changes.

`DeathFairnessDirector` samples readable context and updates `RunProgress.last_death_message` after the player emits a death lesson. The game-over scene then shows both the lesson and the concrete run readout.

Player death flow is intentionally short and locked. `player.gd`, `HealthComponent`, and `WeaponSystem` stop repeat death signals, held fire, beam fire, input, and movement acceleration as soon as death begins, while preserving a brief collapse watch before game over.

Player hit flow now includes a short configurable post-hit invulnerability window in `player.gd`. The window applies to shield/hull damage, emits telemetry signals for started/ignored damage, and flashes hull/shield visuals so burst hits feel fair without removing danger.

## Gravity Ghost Replay

`GravityGhostRecorder` samples only the locally owned player at 10 Hz into a fixed-size ring covering the final 14 seconds. Samples contain position, speed, and bounded danger pressure; they never retain scene-object references. Great/perfect/apex slingshots, near misses, successful recovery windows, and event-horizon escapes are recorded as capped highlight markers.

When the player emits the death lesson, the recorder writes packed presentation arrays to transient `RunProgress.last_gravity_ghost_replay` state that is deliberately excluded from the run-anchor save. `GravityGhostReplayPanel` reads that snapshot on the game-over screen, fits the trajectory into a compact cyan/orange vector map, loops an animated ship ghost, graphs speed/danger pressure along the bottom lane, and calls out mastery marks as the playhead reaches them. The recorder also stores component pressure bands for projectiles, hostile density, hull state, and gravity load, then promotes threshold crossings into capped incident markers. This is deliberately not a deterministic world replay: no enemy, projectile, damage, audio, or physics event is re-executed.

## Freed Object Safety

Hot systems that cache scene nodes must validate before casting. `RuntimeRegistry`, resonance/scar visual dictionaries, beam hit queries, powerup projectile instance IDs, pooled swim/lens/debris effects, enemy AI scans, and gravity source refreshes now check `is_instance_valid()` before assigning typed nodes.

## Multiplayer Session Architecture

2026-06-05 milestone: Vector Anomaly now has first-pass LAN multiplayer instead of only passive sync scaffolding.

`NetworkSession` is the transport/session autoload. It owns LAN hosting, LAN joining by IP/port, peer roster records, player scene configuration, run seed/config replication, hosted restart, leave-session cleanup, projectile spawn broadcast, vector-event broadcast, and future Steam transport entry points.

Current supported flow:

- title screen calls `host_and_play()` for local hosting plus play
- title screen calls `join_lan_game(address, port, callsign)` for IP joins
- the host starts/restarts network runs and broadcasts the deterministic run config
- clients receive the run config, apply the same seed/phase state, and change to the run scene
- `configure_arena_players()` maps the scene player plus spawned peer players to roster records
- local players process input, camera, HUD, pause UI, predictors, projectile/vector broadcasts, and state submission
- remote players are visual/gameplay proxies that interpolate submitted state and do not own local controls

`MultiplayerTargeting` is the compatibility layer for gameplay scripts. Enemy AI, projectiles, HUD helpers, and co-op hooks should ask it for the local player or nearest valid player instead of assuming the first node in the `Player` group is authoritative.

`MultiplayerSyncFoundation` remains useful, but its role has shifted from future-only placeholder to runtime readability/sync budget layer:

- sync snapshots are quantized and deterministic rather than live simulation saves
- gravity sources, wave enemies, bosses, and hostile projectiles are hashed within explicit budgets
- desync risk signals fire when active gravity or projectile counts exceed those budgets
- peer readability budgets expose limits for arrows and warnings as player count grows
- co-op combo hooks accept player vector events and emit a combo-window signal without changing solo mechanics

`CoopComboDirector` builds on that foundation. It registers local mastery slingshots and receives remote vector events through `NetworkSession.broadcast_vector_event()`. When two distinct player vector events land inside the combo window, it creates a shared resonance payoff, locally slows nearby threats, emits `coop_combo_triggered`, and gives the score tracker a combo event.

Steam support is intentionally a transport roadmap, not a gameplay fork. When a GodotSteam/Steam `MultiplayerPeer` plugin is installed, add the Steam host/join/lobby adapter behind `NetworkSession` and keep player state, targeting, projectile events, vector events, run config, and pause/session cleanup unchanged.

### Multiplayer Continuity Roadmap

- Add a two-instance LAN smoke runner that starts host/client, confirms shared seed, roster count, remote player spawn, projectile broadcast, and hosted restart.
- Add a gameplay-change checklist: every new player-owned ability must decide whether it is local-only visual, state-exported, reliable event-broadcast, or deterministic seed-driven.
- Add transport abstraction tests before Steam integration so ENet LAN and Steam peers share the same session contract.
- Add late-join reconciliation for active wave state, boss state, player health/energy, and important world hazards before advertising public drop-in co-op.
- Add disconnect recovery rules: client returns to title with a clear message, host removes peer player/proxies, and run state remains valid.
- Add version/compatibility handshake so mismatched builds or mod manifests fail cleanly before spawning players.

## Adaptive Music State

`AdaptiveMusicStateDirector` is a music-control hook, not a music manager. It samples:

- arena chaos
- resonance pressure
- time-tear pressure
- boss presence

It emits intensity layers (`silence`, `drift`, `tension`, `overload`, `collapse`) and beat hints (`pulse`, `burst`, `collapse`) so final audio implementation can bind stems, transitions, and reactive composition later.

## Mod Content Registry

`ModContentRegistry` scans `res://Mods`, `user://mods`, and export-adjacent desktop `mods`/`Mods` folders for `vector_anomaly_mod.json` or legacy `mod.json`. Roots are recursive, the user mod folder is created automatically, and manifest-relative asset paths are resolved at runtime so a mod folder can move between packaged builds without rewriting local paths. A manifest may declare:

- arenas, waves, upgrades, rules, powerups, weapons
- enemies, bosses, arena events, celestial bodies, physics drops
- materials, prefabs, entities, gamemodes, maps
- sfx, music, HUD badges, mod palettes, creator notes
- `law_weaves`, `anomaly_recipes`, and `challenge_cards`
- tools, NPC behaviors, script packs, and workshop tags

The registry stores manifest metadata, source/install context, namespaced content dictionaries, a local-id index, a hook index, scan-root diagnostics, and a capability snapshot for future menus/editors. It does not instantiate scenes, run scripts, or grant permissions. This keeps the modding layer deterministic and safe while still exposing a large creative surface.

Hookable content is the unique modding spine. `law_weaves`, `anomaly_recipes`, and `challenge_cards` declare safe hooks such as `wave_start`, `slingshot_apex`, `resonance_created`, `rare_event_started`, `music_beat`, and `coop_combo_triggered`. They combine normalized conditions (`min_wave`, `chaos_tier_at_least`, `has_weapon`, `slingshot_grade_at_least`, etc.) with declarative effects (`create_resonance_zone`, `offer_weapon`, `spawn_celestial_body`, `request_music_layer`, `tag_score_event`, etc.). Trusted directors can consume those entries through `get_hook_entries()` without giving mods script execution.

Playable weapon mods now flow through the same registry. `WeaponSystem` reads `get_playable_weapon_entries()`, adds safe projectile entries to its weapon catalog, and supports mod patterns such as single, spread, parallel, braid, helix, ring, converge, scissor, and pinwheel. Weapon payload overrides are normalized so mod packs can create distinct projectile identities while still using the normal HUD, prediction, energy, projectile, and network event path.

Manifest validation rejects malformed roots, missing ids, invalid versions, non-array content buckets, non-object entries, parent-traversal paths, unsupported URI schemes, absolute machine paths, invalid weapon payloads, unknown hooks, unknown condition/effect actions, and script references inside hookable entries. Failed manifests are stored in the registry snapshot and surfaced by the pause-menu Modding section. Script-like buckets are cataloged but locked unless script pack registration is explicitly enabled.

`get_compatibility_signature()` now includes normalized gameplay-affecting mod content, including playable weapon profiles and hookable entries, while excluding entries marked `local_visual`. `NetworkSession` uses that signature for the mod/version handshake boundary so mismatched co-op gameplay packs can fail cleanly before spawning players.

`ModHookDirector` is the runtime bridge for the safe hook spine. It listens to wave, boss, slingshot, weapon, projectile-hit, resonance, scar, rare-event, death, and co-op combo signals, then consumes entries from `get_hook_entries()`. Live effects are capped to resonance zones, gravity scars, powerup grants, weapon offers, HUD badges, and SFX. Higher-level requests such as arena events, celestial bodies, physics drops, music layers, run pressure, score tags, and challenge cards are recorded in `RunProgress.arena_flags["mod_hook_events"]` for trusted directors instead of spawning arbitrary content immediately.

Player-triggered hook events are replicated through `NetworkSession.broadcast_mod_hook_event()` with a narrow payload so matching peers replay the same registry entry by id. Pre-run fallback mod signatures now filter to gameplay-affecting content, keeping local-only palettes, music, HUD badges, and creator notes out of LAN compatibility checks.

The built-in weapon catalog now has a deeper production matrix without leaving the safe projectile path: Phase Suture, Null Rebounder, Graviton Bloom, Causal Anchor, Vector Prism, Mass Driver, Tidal Skein, Scar Carver, Chronal Needleloom, Singularity Kite, Inertia Maul, and Harmonic Bloom join the previous projectile and beam families. New safe projectile patterns `converge`, `scissor`, and `pinwheel` are available to mods alongside `single`, `spread`, `parallel`, `braid`, `helix`, and `ring`.

## Scores And Community Challenges

`RunScoreTracker` listens to existing gameplay signals instead of polling:

- `WaveDirector.wave_cleared`
- `WaveDirector.boss_defeated_anchor`
- `SecretBossDirector.secret_boss_defeated`
- `RunVariationDirector.rare_event_started`
- `MomentumCombatComponent.kinetic_impact_dealt`
- `MomentumCombatComponent.near_miss_velocity_gained`
- `GravityResonanceManager.fracture_applied`
- `GravityScarManager.gravity_scar_applied`
- `EventHorizonDirector.horizon_escape_scored`
- `EventHorizonDirector.event_horizon_started`
- `EventHorizonDirector.event_horizon_ended`
- `CoopComboDirector.coop_combo_triggered`
- player `slingshot_mastery_scored`

It emits a score snapshot, writes the latest snapshot/challenge code into `RunProgress.arena_flags`, emits `physics_anomaly_achieved`, and publishes a challenge code. The code format is `mode:seed:wave:score_checksum`, so players can share repeatable seed challenges before a full leaderboard exists.

The anomaly score path is fully signal-driven. Kinetic multipliers capture the player's current velocity when the enemy death signal fires, then quantize an exponential reward. Vector shears are awarded from counter-opposing gravitational-zone impulses. Event-horizon grazes require proximity to an `Objects_With_Gravity` source while shield/hull remain undamaged; the tracker listens to player health and shield hit signals during the horizon window so later shield regeneration cannot hide damage. Apex slingshots score from tangential exit velocity signatures. The checksum is a stable SHA-256-derived digest of the unified score snapshot.

## Physics Drop Ecosystem

`PhysicsDropSystem` listens through `WaveDirector` death tracking and spawns readable physics rewards:

- Fragments: upgrade/run currency stored on player metadata and `RunProgress.arena_flags`.
- Momentum Orbs: velocity amplification for advanced slingshot routing.
- Gravity Residue: temporary compression fields and gravity-source residue.
- Temporal Charges: time-dilation capacity fuel.
- Instability Shards: optional reward/escalation tradeoff.
- Anomaly Seeds: deterministic arena/resonance event triggers.
- Celestial Cores: boss-grade rule-changing powerup drops.

Drops are arena entities with decay, readable glyphs, gravity interaction where appropriate, and no generic gold/ammo/health-spam behavior. `PhysicsDropSystem` emits collection/expiry telemetry and records per-type counts in `RunProgress.arena_flags`; Anomaly Seeds and Celestial Cores can route into `ArenaInstabilityDirector`, `CelestialBodyDirector`, and `RealityCollapseDirector` when those systems are present.

## Production Simulation Runner

`production_simulation_runner.gd` boots `the_abyss.tscn`, disables default developer UI, enables the stress harness, samples warmup and production frames, and validates explicit budgets. For normal project autoloads and the Steam demo profile, run it through `res://Nodes/production_simulation_runner.tscn` instead of a headless script launch:

- average frame time
- max frame time
- projectile count
- VFX burst cap
- stress harness budget report
- Steam demo budget report when launched with `-- --demo-profile`

The runner is a progress/performance validator, not a live-state save or deterministic replay. It proves the production systems remain bounded under late-wave-style projectile and gravity pressure while keeping validation separated from player-facing run state.

## Apex Vector Core

`Apex Vector Core` is the first dedicated slingshot-defining powerup. It boosts mastery slingshot capacity and turns repeated high-grade slingshots into an Apex Vector release: nearby enemies and hostile projectiles are flung along the player's tangent, enemies take modest damage, and a harmonic-orbit resonance zone is created for follow-up play.

## Launch Upgrade Fields

`Barycentric Tether` and `Frame-Dragging Anchor` complete the Version 1.0 launch matrix as data-driven `PowerupDefinition` resources registered through `PowerupLibrary`.

`Barycentric Tether` runs on a throttled field tick, pairs nearby hostile bodies inside capped registry-backed radius queries, and applies center-of-mass orbital pressure plus light damage through `CombatStatus`. It writes only pressure metadata and emits a lightweight signal payload for reactive systems.

`Frame-Dragging Anchor` runs on a throttled field tick around the player, applies rotational distortion to capped hostile/projectile targets, and grants a small forward slingshot boost only when the player already has high momentum. It uses no per-tick scene creation and reuses the inventory target buffer.

## Endgame Flow

`RunProgress.on_boss_defeated()` treats the wave 40 capstone boss as authoritative. When `res://Nodes/extradimensional_breacher_boss.tscn` is defeated, the run enters `RUPTURE` even if the wave director has not finished advancing its own wave-cleared state yet.

`RunDirector` then halts waves, shows the rupture banner, starts `RuptureDirector`, and moves into `MusicFinaleDirector` after the rupture countdown. `MusicFinaleDirector` spawns `res://Nodes/music_resonance_boss.tscn`; music beat events call the boss pulse, burst, and finale methods directly. The credits transition occurs when that boss is defeated.

## Pause And Game Over

`PauseMenu` runs in `PROCESS_MODE_ALWAYS`, fades the simulation into a true paused state, and exposes scene-authored sections for settings/readability, seed sharing, modding status, multiplayer prep, weapon status, and run controls. Resume, restart, and abort-to-title remain real buttons rather than generated UI. Section labels receive runtime color/outline accents so settings, weapon, modding, and multiplayer information stay scannable under the pause shader. The current pause pass also wraps the menu content in a runtime scroll shell, smooths panel scale/fade entry, and uses context labels for the normal run, tutorial, Steam demo, and Clip Lab.

Pause restart/exit routing is context aware. Tutorial restart returns to `res://Nodes/playable_tutorial.tscn`, Steam demo retry returns to `res://Nodes/demo_game.tscn`, Clip Lab reset returns to `res://Nodes/clip_lab_scene.tscn`, and the normal campaign still routes through `res://Nodes/run_loading_screen.tscn`. Network clients continue to see host-only restart while hosts keep the existing hosted restart path.

Player death stores `RunProgress.last_death_message`, then changes to `res://Nodes/game_over_scene.tscn`. The game-over scene clears the progress anchor and displays the exact death vector lesson before allowing a retry or title return.

## Accessibility And Challenge Modes

`Settings` now exposes UI scale, screen shake scale, reduced flash, and colorblind readability modes. The pause menu writes these values directly, while HUD colors, HUD scale, camera shake, and mastery flash alpha read from the same singleton. Values persist through `user://settings.cfg` and reload when the autoload enters the tree.

`RunProgress.begin_boss_rush()` starts a boss-only challenge profile. `WaveDirector` treats every boss-rush wave as a boss wave, cycles the authored boss list deterministically, reduces rest windows, and applies the boss health modifier from `challenge_modifiers`.

Boss Rush now stays wave-enabled even though it uses challenge state, and it completes after the authored boss list has been defeated once. Completion marks the run finished and stops the wave director instead of looping forever.

The pause menu displays `RunProgress.get_run_seed_code()` and can copy it to the clipboard. The current format is `mode:seed:wave`.

Pause and HUD scaling are separated: the pause panel scales around its center and clamps to the viewport, while offscreen HUD arrows live outside the scaled HUD root so larger UI settings do not push arrows offscreen. The run loading screen now displays an eased progress ratio instead of raw threaded-loader jumps, so cached loads do not visibly snap from 0 to 50 to 100.

## Projectile Prediction And Flash Safety

`OrbitalTrajectoryPredictor` is a player-facing movement forecast and visual identity feature. It draws in world space, resolves the local multiplayer player, and should remain visibly readable: orange immediate/danger segments, cyan future path, soft glow, alpha fade, and a compact origin marker. It throttles recalculation and caps draw segments/projectile pressure, but must not be muted into faint debug telemetry. If player gravity sampling, slingshot behavior, or multiplayer ownership changes, update the predictor simulation and `Nodes/player.tscn` overrides together.

The player projectile predictor now mirrors the projectile's capped gravity-source sampling, launch speed inheritance from momentum, and planet-hit behavior. If a shot would hit a planet, the predictor stops at impact because the actual projectile is destroyed there.

Vector Bolt tuning is now larger/faster than the original baseline. `projectile.gd`, `projectile.tscn`, `ProjectileAimPredictor`, and `ProjectileTrajectoryVisualizer` must stay in lockstep: launch speed is 1080, collision preview radius is 14.0 around planets to match the live `CollisionShape2D`, source sampling is capped, and player/player-projectile gravity sources are excluded so baseline shots do not orbit the player. Orbital projectile behavior is intentional only when `PowerupInventory` captures hostile shots through Orbital Tether; those shots carry `intentional_orbital_capture` metadata and join `orbital_satellite_projectiles` until released.

Flash-heavy success feedback should use `Settings.flash_alpha()` or an explicit low alpha cap. Slingshot mastery, law fusion rings, powerup bursts, and VFX bursts all follow this rule so perfect movement can feel rewarding without becoming a full-screen flash.

## Current Technical Tuning Targets

Latest feedback pass completed:

- Drag ON is now the `Precision` style: tactical braking, slingshot tangent blending, cleaner recovery routing, and small energy recovery inside gravity windows.
- Gravity Wave Beam now moves/fractures destructible planets while keeping enemy/projectile beam-axis displacement.
- Chronal Refraction Beam now creates capped timeline echoes and delayed desync payoff.
- WaveDirector seeds far-orbit planets and validates stationary shooter spawns against planet clearances.
- WormholePair validates endpoints against planet radius plus safety margin.
- The pink/purple slowdown path is capped through lower visual alpha/radius budgets, lower VFX burst budgets, glitch cooldowns, local slow budgets, and a safe global time-scale floor.

## Vector Anomaly Director

`VectorAnomalyDirector` orchestrates space-time and gravitational anomalies triggered by player upgrades, projectiles, and high-speed impacts.

Production behavior:

- Radius queries use `RuntimeRegistry.fill_targets_in_radius()` instead of direct group scans.
- Gravity anchors use cached nearest-source selection capped by explicit budgets.
- RuntimeRegistry reuses nearest-source and target-query scratch buffers for hot queries.
- Micro-lens visuals are pooled.
- Transient anomaly rings are pooled and reused instead of created and freed per event.
- Vacuum collapse, relativistic impact, time-debt zones, orbital debris, orbital memory, and resonance cascades all resolve on fixed intervals.
- Dynamic gravity debris and compression/inversion tide pockets register directly with the runtime cache when they enter gravity groups and unregister on exit.
- `PowerupInventory` uses reusable query buffers for orbital projectile capture, singularity death hooks, debris bending, Apex Vector targeting, Barycentric Tether pairing, Frame-Dragging Anchor distortion, and slingshot time-lens pulses.
- `GravityResonanceManager` uses registry-backed nearest-source and radius queries for resonance detection, projectile acceleration, and body field effects.
- `MomentumCombatComponent` uses capped target buffers for near-miss mastery and kinetic shockwaves.
- Event Horizon Warden, Gravity Maw, Gravimetric Echo Drone, and Resonance Paralytic Construct use bounded registry queries for collapse, absorption, replay, and paralysis fields.
- Readability, death diagnostics, adaptive music, stress reporting, and multiplayer sync risk read cached projectile/boss/gravity counts before falling back to direct scans.

This keeps high-chaos combat deterministic-feeling, readable, and bounded under late-wave projectile/enemy load.

## 2026-06-18 Stability, Opening, And Creator Pass

- Reduced Flash now distinguishes transient flashes from persistent readability geometry. Player projectiles use a projectile-specific alpha floor, while gravity/resonance circles keep a persistent alpha floor.
- Black-hole spaghettification no longer non-uniformly scales live collision bodies. Consumption avoids mutating the player's collision tree inside the black-hole physics callback, and the decorative core no longer owns a blocking physics shape.
- Orbiting celestial events default on in `Settings`. Binary/structure orbit radius and angular direction are captured from the player's position and velocity at spawn rather than continuously chasing the player; LAN runs replicate the host's choice in protocol 6 run config.
- Player auto-orbit assistance is a separate, off-by-default pause setting. It gates continuous proximity/tangent correction while preserving manual gravity and the core one-shot slingshot reward.
- Waves 1-4 now use explicit tutorial-readable rosters. Procedural gravity spawners move to wave 6 and gravity-wave makers to wave 8, preventing the old wave-4 overlap of new AI families and authored gravity fields.
- `ModContentRegistry` can validate manifest text/files and export a creator diagnostics report. The Mods screen exposes that report, and `website/modding/` is the dedicated public Creator Lab.

## 2026-06-18 Mod Contract Expansion

- Manifest schema 4 adds bounded creator options, dependency min/max versions, explicit conflicts, and deterministic `load_before` / `load_after` ordering.
- Creator options persist beside mod toggles, render as native controls in the Mods screen, and can gate safe hooks through typed `mod_option` comparisons.
- Gameplay-affecting option values participate in LAN compatibility signatures; local visual choices remain signature-exempt.
- Creator diagnostics now include conflict state and resolved option values, while the public Creator Lab can forge, import, validate, and export schema 4 starter contracts.

## 2026-06-20 Controls, Time, And Creator Completion

- The Mods screen includes a live Creator Sandbox that validates pasted schema 4 JSON and safely installs new manifests into an isolated `user://mods/<id>` folder without overwriting an existing pack.
- Registry snapshots and reports expose the resolved dependency graph, and required dependencies are re-evaluated after conflict blocking.
- Creator Lab preserves imported contracts during edits, validates dependency version ranges, and renders a live required/optional/conflict pack graph.
- Local time dilation now has immediate mechanical payoff without global time scale, plus smooth shader ingress/egress instead of start/end flashes.

## 2026-06-21 Chronal Bubble Update

- Player time dilation is now a spatial field with an editable radius and radial falloff rather than an arena-wide slow.
- The player field uses a separate status channel, so targets can move between the core and boundary without weakening stronger temporal scars, weapons, or authored event slows.
- A scene-editable cyan boundary communicates field reach, and the HUD reports the number of unique enemies, bosses, and hostile projectiles currently affected.
- RuntimeRegistry supplies bounded radius queries, while a reusable group buffer and cross-group instance filter avoid per-tick allocations and double-counting bosses.

## 2026-06-21 Gravity Ghost Update

- Game over now includes a looping reconstruction of the local player's final 14 seconds, turning failure into an inspectable movement lesson and a clip-friendly recap.
- The recorder uses a fixed-size sample ring, packed snapshot arrays, capped mastery markers, and cached registry pressure counts; it never snapshots the live physics world.
- Multiplayer records only the locally owned ship, so remote proxies cannot overwrite the player's death vector.

## 2026-06-21 HUD Performance Boundary Update

- OrbitalHUD gravity strength now mirrors the player's capped nearest-source, pull-radius, and acceleration-limit rules instead of summing every planet discovered from the scene tree.
- Gravity text, field-rule inspection, and planet-arrow membership have separate inspector-editable refresh budgets; arrow positions still project smoothly every frame.
- HUD panel layout is recalculated only after viewport/UI-scale changes, and threat/tide/rare-event discovery uses reusable registry buffers rather than frame-loop group scans.

## 2026-06-23 Vector Diagnostic UI Update

- `VectorHudGlyph` provides inspector-editable, code-native icons for the HUD's diagnostic language, covering resources, movement, local fields, time, horizons, chaos, slingshot mastery, weapons, and run phase without adding external asset dependencies.
- OrbitalHUD binds glyph activity and severity to live values: low hull/energy, broken shield, high gravity, active horizons, weapon readiness, score pulses, and phase progression all change shape intensity as well as text color.
- Gravity Ghost Replay now renders a speed/pressure lane, component pressure bands, incident markers, and event-specific timeline markers, so the player can read not only where the ship went, but when danger, speed, and exceptional recoveries changed.
- The game-over summary now includes a `BLACK BOX` row sourced from the Gravity Ghost snapshot's incident summary, keeping the quick retry screen informative without adding a separate report scene.

## 2026-06-24 Campaign And Failure-Readability Update

- Gravity Ghost player-facing text now presents the panel as `FINAL FLIGHT REPLAY`, adds an editable summary row, visible route start/impact/ship marker labels, and a legend for route, speed, projectile, hostile, hull, and gravity pressure. The underlying replay remains a bounded black-box reconstruction, not a world replay.
- Campaign mode is now a scene-editable mother-planet defense loop. `CampaignModeDirector` owns waves, energy credits, upgrades, hijack orders, alien encounters, and KOTH capture, while invaders, escorts, hostile planet turrets, and the mother planet live in editable scenes with exported tuning.
- `EnergyComponent` now has a currency channel in addition to thrust energy. Physics drops can award currency, and campaign upgrades spend it on speed, damage, armor, slingshot power, escorts, and hijacking.
- `Mods/space_oregon_trail` and `Mods/party_modes` add schema 4 catalogs for space-trail survival, space dysentery, hostile planet stops, gravity soccer, emotes, hijack variants, and battle-ship building without widening the script execution boundary.
