# VECTOR ANOMALY Systems Notes

## Runtime Install Flow

`OrbitalJuiceManager` installs modular gameplay layers into the active level:

- `RuntimeRegistry` is the autoload cache for gravity sources, projectile groups, enemy groups, boss groups, and player targets. Hot systems use it instead of rescanning scene groups during physics ticks.
- `OrbitalHUD` owns player-facing readouts, gravity arrows, and offscreen threat arrows.
- `GravityResonanceManager` samples gravity-source overlap and emits zone dictionaries for gameplay, VFX, HUD, and audio.
- `TimeDilationManager` applies player-safe dilation plus localized time pockets through metadata and lightweight signals.
- `OrbitalVFXDirector` listens to gameplay signals and spawns capped burst particles from inspector-editable templates.
- `PerformanceBudgetDirector` adjusts particle and VFX budgets for quality tiers.
- `RunVariationDirector` applies seed-named run laws, pacing states, and deterministic rare events.
- `SecretBossDirector` listens for hidden mastery conditions and registers optional bosses with the wave UI.
- `MultiplayerSyncFoundation` emits passive deterministic sync snapshots and co-op readability budgets.
- `CoopComboDirector` turns sync-safe vector events into deterministic shared resonance/time payoffs.
- `ModContentRegistry` discovers data-driven mod manifests without executing arbitrary code.
- `RunScoreTracker` emits score snapshots and shareable challenge codes.
- `ArenaRuleDirector` applies seeded arena law profiles for alternate arena physics.
- `LateGameInstabilityDirector` injects capped impossible-physics events in late game.
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

Powerup and law-fusion feedback rings are pooled `Line2D` nodes. Upgrade pickup flashes, slingshot law convergence, Apex Vector releases, and fusion feedback must reuse the inventory ring pools and respect `Settings.flash_alpha()`.

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

Current visual readability rules:

- In-world labels use action language, not system jargon: `PULL IN`, `PUSH OUT`, `FLOW ARC`, `SLOW SHOTS`, and `ORBIT BEND`.
- Manual slingshot-created resonance zones merge with nearby matching zones and cap their active count to avoid unreadable ring stacks.
- Resonance visual alpha is intentionally subdued; gameplay meaning should come from shape, direction, and label before brightness.

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

## Transition Juice

`RunTransitionDirector` is a `CanvasLayer` with editable child nodes:

- `Wash`
- `VectorLine`
- `TransitionLabel`

It listens to wave, boss, arena-law, impossible-event, co-op combo, Rupture, and finale signals. The effect is deliberately brief and non-blocking so it adds juice without hiding the player or pausing the simulation.

## Skill Signatures And Spacetime Swim

`SkillSignatureDirector` turns mastery into persistent but capped world marks:

- perfect/apex slingshots stamp orbit glyphs and vector echoes
- kinetic shockwaves stamp impact signatures
- Apex Vector releases stamp larger harmonic vector marks
- event-horizon escapes stamp survival signatures

These signatures fade and self-clean, so they communicate player mastery without becoming permanent clutter.

`SpacetimeSwimDirector` owns the first explicit swimming-through-spacetime effect. It listens to time dilation, time-tear intensity, local time pockets, slingshot mastery, beam weapons, and event-horizon signals. It adds world ribbons behind the player plus a subtle screen wash and capped glitch slices. Low-performance mode reduces ribbon/slice counts and overlay alpha through `OrbitalJuiceManager`.

## Spacetime Tears

`SpacetimeTearDirector` listens to `GravityScarManager` and `TimeDilationManager`. Strong temporal rips, harmonic fractures, intense inversion wakes, or very high scar intensity can open a short-lived rift after the run is far enough along. Each rift has capped visuals, capped spawn count, a global cooldown, and a minimum distance from the player so tears feel dangerous without becoming unfair point-blank ambushes.

Enemies that emerge from tears are registered through `WaveDirector.register_external_enemy()`, so wave completion still accounts for them. Low-performance mode reduces active tear count, alive tear enemies, and ring segment density.

## Fair Pacing And Death Readouts

`FairPacingDirector` preserves difficulty through physics but adjusts recovery time after wave clears:

- low health: longer recovery
- broken shield: modestly longer recovery
- recent mastery: slightly shorter recovery

`DeathFairnessDirector` samples readable context and updates `RunProgress.last_death_message` after the player emits a death lesson. The game-over scene then shows both the lesson and the concrete run readout.

## Multiplayer Sync Foundation

Full drop-in/drop-out online co-op is still future work. The current foundation keeps that future from fighting the physics architecture:

- sync snapshots are quantized and deterministic rather than live simulation saves
- gravity sources, wave enemies, bosses, and hostile projectiles are hashed within explicit budgets
- desync risk signals fire when active gravity or projectile counts exceed those budgets
- peer readability budgets expose limits for arrows and warnings as player count grows
- co-op combo hooks accept player vector events and emit a combo-window signal without changing solo mechanics

The foundation is passive and does not network anything yet.

`CoopComboDirector` builds on that foundation. It registers local mastery slingshots and exposes `register_remote_vector_event()` for future network peers. When two distinct player vector events land inside the combo window, it creates a shared resonance payoff, locally slows nearby threats, emits `coop_combo_triggered`, and gives the score tracker a combo event.

## Adaptive Music State

`AdaptiveMusicStateDirector` is a music-control hook, not a music manager. It samples:

- arena chaos
- resonance pressure
- time-tear pressure
- boss presence

It emits intensity layers (`silence`, `drift`, `tension`, `overload`, `collapse`) and beat hints (`pulse`, `burst`, `collapse`) so final audio implementation can bind stems, transitions, and reactive composition later.

## Mod Content Registry

`ModContentRegistry` scans `res://Mods` and `user://mods` for `vector_anomaly_mod.json`. A manifest may declare:

- `arenas`
- `waves`
- `upgrades`
- `rules`

The registry stores manifest metadata and content dictionaries for future menus/loaders. It does not instantiate scenes, run scripts, or grant permissions; this keeps the first modding layer deterministic and safe enough to expand.

Manifest validation now rejects malformed roots, missing ids, invalid versions, non-array content buckets, non-object entries, and entries without ids. Failed manifests are stored in the registry snapshot and surfaced by the pause-menu Modding section.

## Scores And Community Challenges

`RunScoreTracker` listens to existing gameplay signals instead of polling:

- `WaveDirector.wave_cleared`
- `WaveDirector.boss_defeated_anchor`
- `SecretBossDirector.secret_boss_defeated`
- `RunVariationDirector.rare_event_started`
- `EventHorizonDirector.horizon_escape_scored`
- `CoopComboDirector.coop_combo_triggered`
- player `slingshot_mastery_scored`

It emits a score snapshot and challenge code. The code combines `RunProgress.get_run_seed_code()`, score, and a checksum so players can share repeatable seed challenges before a full leaderboard exists.

## Production Simulation Runner

`production_simulation_runner.gd` boots `the_abyss.tscn`, disables default developer UI, enables the stress harness, samples warmup and production frames, and validates explicit budgets:

- average frame time
- max frame time
- projectile count
- VFX burst cap
- stress harness budget report

The runner is a progress/performance validator, not a live-state save or deterministic replay. It proves the production systems remain bounded under late-wave-style projectile and gravity pressure.

## Apex Vector Core

`Apex Vector Core` is the first dedicated slingshot-defining powerup. It boosts mastery slingshot capacity and turns repeated high-grade slingshots into an Apex Vector release: nearby enemies and hostile projectiles are flung along the player's tangent, enemies take modest damage, and a harmonic-orbit resonance zone is created for follow-up play.

## Endgame Flow

`RunProgress.on_boss_defeated()` treats the wave 35 capstone boss as authoritative. When `res://Nodes/centrifuge_marshal_boss.tscn` is defeated, the run enters `RUPTURE` even if the wave director has not finished advancing its own wave-cleared state yet.

`RunDirector` then halts waves, shows the rupture banner, starts `RuptureDirector`, and moves into `MusicFinaleDirector` after the rupture countdown. `MusicFinaleDirector` spawns `res://Nodes/music_resonance_boss.tscn`; music beat events call the boss pulse, burst, and finale methods directly. The credits transition occurs when that boss is defeated.

## Pause And Game Over

`PauseMenu` runs in `PROCESS_MODE_ALWAYS`, fades the simulation into a true paused state, and exposes scene-authored sections for settings/readability, seed sharing, modding status, multiplayer prep, and run controls. Resume, restart, and abort-to-title remain real buttons rather than generated UI.

Player death stores `RunProgress.last_death_message`, then changes to `res://Nodes/game_over_scene.tscn`. The game-over scene clears the progress anchor and displays the exact death vector lesson before allowing a retry or title return.

## Accessibility And Challenge Modes

`Settings` now exposes UI scale, screen shake scale, reduced flash, and colorblind readability modes. The pause menu writes these values directly, while HUD colors, HUD scale, camera shake, and mastery flash alpha read from the same singleton.

`RunProgress.begin_boss_rush()` starts a boss-only challenge profile. `WaveDirector` treats every boss-rush wave as a boss wave, cycles the authored boss list deterministically, reduces rest windows, and applies the boss health modifier from `challenge_modifiers`.

Boss Rush now stays wave-enabled even though it uses challenge state, and it completes after the authored boss list has been defeated once. Completion marks the run finished and stops the wave director instead of looping forever.

The pause menu displays `RunProgress.get_run_seed_code()` and can copy it to the clipboard. The current format is `mode:seed:wave`.

Pause and HUD scaling are separated: the pause panel scales around its center and clamps to the viewport, while offscreen HUD arrows live outside the scaled HUD root so larger UI settings do not push arrows offscreen.

## Projectile Prediction And Flash Safety

The player projectile predictor now mirrors the projectile's capped gravity-source sampling, launch speed inheritance from momentum, and planet-hit behavior. If a shot would hit a planet, the predictor stops at impact because the actual projectile is destroyed there.

Flash-heavy success feedback should use `Settings.flash_alpha()` or an explicit low alpha cap. Slingshot mastery, law fusion rings, powerup bursts, and VFX bursts all follow this rule so perfect movement can feel rewarding without becoming a full-screen flash.

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
- `PowerupInventory` uses reusable query buffers for orbital projectile capture, singularity death hooks, debris bending, Apex Vector targeting, and slingshot time-lens pulses.
- `GravityResonanceManager` uses registry-backed nearest-source and radius queries for resonance detection, projectile acceleration, and body field effects.
- `MomentumCombatComponent` uses capped target buffers for near-miss mastery and kinetic shockwaves.
- Event Horizon Warden, Gravity Maw, Gravimetric Echo Drone, and Resonance Paralytic Construct use bounded registry queries for collapse, absorption, replay, and paralysis fields.
- Readability, death diagnostics, adaptive music, stress reporting, and multiplayer sync risk read cached projectile/boss/gravity counts before falling back to direct scans.

This keeps high-chaos combat deterministic-feeling, readable, and bounded under late-wave projectile/enemy load.
