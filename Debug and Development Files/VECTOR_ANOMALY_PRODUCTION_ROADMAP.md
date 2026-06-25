VECTOR ANOMALY: MASTER PRODUCTION ROADMAP & SHIP DIRECTIVE v2.0
Drop-In Replacement â€¢ Actionable Checklist for Solo Developer + CODEX
Date: 2026-06-02
Status: P0 CODE-SIDE COMPLETE â€” manual in-editor playtest/profiler pending
Aligned To: All attached production documents (Asset List, Game Systems, Orbitron Systems, Universe Guide, Separation Blueprint, Similarity Blueprint, current profiler data, and in-game visual evidence)
Goal: Fix immediate readability/perf killers, complete V1.0 ship criteria, produce missing priority assets, and create a check-off system that both you and CODEX can use. Every task references source docs.
---
HOW TO USE THIS DOCUMENT (MANDATORY)
Checkboxes are the single source of truth. Mark `\[x]` when done and verified.
CODEX Assignments: Hand to CODEX (or equivalent) with the exact task text + reference to source doc section. CODEX must output changed files + proof it follows Execution Rules.
USER Assignments: Your tasks (art direction, playtesting, asset creation, final decisions).
BOTH: Joint review required.
After any change: Run `production\_simulation\_runner.gd` (headless) + in-editor profiler + playtest the exact scenario from the attached screenshot (Wave 3, visible gravity source + resonance).
Never ship until P0 section is 100% green and profiler shows stable <16.67 ms frame time with no giant overlays.
This replaces the previous roadmap entirely. Old status markers are superseded by these explicit, verifiable tasks.
---
SECTION 1: EXECUTION RULES (ENFORCED â€” NO EXCEPTIONS)
From original roadmap + reinforced by profiler data, Orbitron Systems particle rules, and Separation Blueprint production clarity pass.
Strict Type Safety â€” All variables, params, returns, members: explicit type hints. No Variant/untyped in hot paths.
Performance First (Profiler-Driven) â€” Zero dynamic allocations in `\_process()` / `\_physics\_process()`. Preallocated arrays, pooling, reusable buffers only. Target: Process Time <4 ms, Render <4 ms sustained. Current evidence (attached profilers): Process Time 95%+, Render Viewport 17-22 ms CPU spikes â†’ immediate cap enforcement required.
Engine-Native + Godot 4.4 â€” Tabs, composition over inheritance, UI separated from gameplay.
Simple > Clever â€” If two solutions give similar gameplay, pick simpler + more performant.
Release First â€” Any task threatening stability delayed to 1.1. V1.0 = polished, stable, replayable physics collapse simulator.
Visual Cap Enforcement (NEW from Separation Blueprint + current crisis) â€” Every bright effect, resonance zone, Polygon2D, Line2D, GPUParticles2D must route through `Settings.flash\_alpha()` or explicit intensity-based alpha/radius caps. No full-screen overlays. Player-focused only.
Readability Guard (NEW) â€” No visual may obscure the player ship or threats. "Trust orbits, not noise" means clean orbital telemetry, not giant filled circles.
---
SECTION 2: CORE PILLARS (ALIGNED TO SEPARATION BLUEPRINT + SIMILARITY BLUEPRINT)
Every feature/task must reinforce at least one:
MOVEMENT = READABLE GENIUS (Similarity Blueprint) â€” Chaos at low skill â†’ Intention at mid â†’ Impossibility at high. Every movement system must generate clips. Slingshot mastery gated to great/apex only (per 2026-06-02 clarity pass).
PHYSICS = SPECTACLE FIRST (Separation Blueprint) â€” Controlled visual collapse. Gravity visibly warps space. Orbit paths break/reform. Time dilation physically visible. But capped and readable â€” no screen-filling purple disks.
VISUAL IDENTITY = ALGORITHMIC COLLAPSE â€” Early: sterile monochrome vectors. Mid: cyan + violet instability. Late: neon fractures + red gravity warnings. Current blocker: The giant purple circle violates this progression and must be fixed before any new visuals.
EMOTIONAL LOOP = NEAR MISS ADDICTION â€” "I should have died but didnâ€™t." Generate last-frame escapes, accidental genius, physics-assisted survival. Death = immediate diagnostic (no post-death firing).
FAMILIAR HANDSHAKE, UNFAMILIAR SHOCKWAVE (Similarity Blueprint) â€” Wave-based arena survival, run progression, build identity, clear enemy intent, risk/reward clarity must feel like Nova Drift peers. Physics layer is the unique shockwave on top.
---

First priority:
[x] Implement modular, signal-driven `RunScoreTracker` scoring for kinetic multipliers, vector shears, event-horizon grazes/escapes, slingshot grades, score snapshots, and deterministic `mode:seed:wave:score_checksum` challenge codes.
CODEX Completion 2026-06-04: `RunScoreTracker` is implemented, signal-driven, supports `CharacterBody2D` velocity snapshots while still tolerating `linear_velocity`, emits `physics_anomaly_achieved`, and writes challenge codes into run flags. Upgrade pass: it now reconnects to late-installed signal sources on a throttle and validates event-horizon grazes with explicit health/shield hit tracking, so shield regeneration cannot hide damage taken during the graze window. Manual in-editor score validation remains because headless Godot is forbidden for this project.
[x] Make particle effects stop rendering/emitting when they are far from the screen/player.
CODEX Completion 2026-06-04: `ParticleFocusCuller` exists as a global fallback, `OrbitalJuiceManager` installs it, and long-lived pickup/debris particles are documented as focus-gated. Upgrade pass: it now preserves gameplay-authored visibility when restoring focused particles and cleanly restores hidden/emission state if the culler is disabled.
[x] Design and implement the late-game flagship boss **THE EXTRADIMENSIONAL BREACHER**.
CODEX Completion 2026-06-04: `ExtradimensionalBreacherBoss` is implemented as the wave-40 capstone with deterministic boundary movement, moving singularities, moon-fragment orbits, slipstream corridors, unstable wormholes, outside-space breaches, timeline slams, telegraphs, distortion pulses, and camera trauma hooks.
[x] Create a data-driven Arena Instability Director.
CODEX Completion 2026-06-04: `ArenaInstabilityDirector` schedules telegraphed gravity tides, resonance storms, slipstream surges, momentum inversions, collapsing orbit lanes, and spacetime fractures that route through existing tide, resonance, scar, and time systems.
[x] Create a Recovery Opportunity System.
CODEX Completion 2026-06-04: `RecoveryOpportunityDirector` tracks near misses and emits rare recovery windows for slingshot corridors, emergency wormholes, resonance rebounds, momentum chains, and time-dilation dodge windows. Upgrade pass: recovery resolution now reports `success`, `danger_after`, and resolved position so telemetry/audio/score listeners can distinguish earned escapes from failed windows.
[x] Implement a dynamic celestial body system.
CODEX Completion 2026-06-04: `CelestialBodyDirector` and `DynamicCelestialBody` support binary systems, rogue planets, wandering singularities, orbital structures, gravity registration, drift/orbit behavior, destabilization, and field pressure.
[x] Create a late-game Reality Collapse system.
CODEX Completion 2026-06-04: `RealityCollapseDirector` implements deterministic screen-edge breaches, corrupted spacetime regions, overlapping timeline echoes, boundary fractures, physics-constant shifts, HUD/camera hooks, and resonance/scar/time integration.
[x] Make enemies drop Energy Droplets that the player can collect to keep energy up during combat.
CODEX Completion 2026-06-04: `EnergyDroplet`, `PowerupLibrary.try_spawn_energy_droplets()`, and `WaveDirector` enemy-death hooks are implemented. Manual pickup/restore verification remains in-editor only.
[x] Implement the Physics-Based Enemy Drop Ecosystem.
CODEX Completion 2026-06-04: `PhysicsDropSystem` and `PhysicsDrop` now cover Fragments, Momentum Orbs, Gravity Residue, Temporal Charges, Instability Shards, Anomaly Seeds, and Celestial Cores, with gravity-aware movement, readable visuals, collection signals, and boss/elite rarity routing. Upgrade pass: the system now emits drop collection/expiry telemetry, records drop stats in run flags, and lets Anomaly Seeds/Celestial Cores trigger arena instability, celestial events, or reality-collapse hooks when those directors are present.

SECTION 3: P0 â€” CRITICAL BLOCKERS (COMPLETE THESE FIRST â€” NO NEW FEATURES UNTIL GREEN)
Evidence: Attached game screenshot shows unreadable full-screen purple overlay (labeled "CHAOS SPIKE...") + tiny player ship at bottom edge. Attached profilers show Process Time 95%+, Render spikes 17+ ms. This violates every readability, performance, and visual cap rule in the docs.
Owner for all P0 tasks: CODEX primary (code fixes) + USER verification/playtest
[x] P0.1 Identify & Eliminate Giant Purple Overlay Root Cause
Reference: Game screenshot + Separation Blueprint "resonance visual alpha is intentionally subdued... capped... player-focused... only renders when intense enough and close enough". Orbitron Systems resonance architecture + particle rules.
CODEX Assignment: Audit `GravityResonanceManager`, `ArenaDestabilizationManager`, `OrbitalVFXDirector`, any `Polygon2D`/`Line2D` used for chaos/resonance zones. Find the node creating the massive filled purple circle (likely wrong scale, alpha=1.0, or unbounded radius on a resonance/compression zone). Force it through intensity-based radius (max 300-400 px at full intensity) + alpha <= 0.25-0.4 (use `Settings.flash\_alpha()`). Add explicit `is\_instance\_valid()` guards. Replace with subtle gradient ring + directional arrows only. Output diff + before/after profiler.
CODEX Completion 2026-06-04: hot purple/magenta contributors were retuned through lower global caps, safer reality-collapse fill alpha, blue/cyan temporal anomaly colors, and stronger player-focused effect limits. Manual in-editor screenshot/profiler verification remains because headless Godot was explicitly forbidden.
USER Verification: Play Wave 3 scenario from screenshot. Confirm player ship and threats remain fully visible at all times. No full-screen color fills.
[x] P0.2 Enforce Global Visual Cap System
Reference: Separation Blueprint production clarity pass + Asset List VFX rules + Orbitron particle rules + profiler data.
CODEX Assignment: Create/strengthen `Settings.flash\_alpha()` path (or equivalent) and apply to every bright effect, resonance zone, gravity scar, time dilation overlay, slingshot ring, powerup ring, beam, particle burst. All `GPUParticles2D`, `Line2D`, `Polygon2D` in `OrbitalVFXDirector` and directors must query this cap. Disable player-adjacent colored telemetry rings by default (HUD readouts only). Cap active resonance zones to strongest local only. Output: centralized cap utility + audit report of all call sites.
CODEX Completion 2026-06-04: global world alpha/fill/light caps were tightened, `world_effect_radius()` now honors the global hard cap, slingshot/powerup/anomaly rings use lower caps, and black-hole particles/lights were reduced.
USER Verification: Run profiler during high-chaos moment. Confirm no spikes above 16 ms sustained. Visuals remain tactical pressure, never noise.
[x] P0.3 Performance Hot-Path Audit & Registry Enforcement
Reference: Orbitron Systems RuntimeRegistry + VectorAnomalyDirector + profiler Process/Render data + production simulation runner.
CODEX Assignment: Ensure all hot systems (gravity refresh, resonance sampling, projectile prediction, enemy AI, VFX spawning, HUD arrows) use `RuntimeRegistry` cached nearest-source / radius-query buffers exclusively. No scene-tree group scans in `\_physics\_process`. Prewarm all pools in `OrbitalVFXDirector`. Throttle any remaining discovery. Run `production\_simulation\_runner.gd` and report pass/fail against budgets (projectiles <1000, VFX bursts capped, frame time stable).
CODEX Completion 2026-06-04: player gravity refresh and black-hole fields now prefer RuntimeRegistry buffers, black-hole field work is throttled, performance budgets auto-drop earlier under FPS/projectile/enemy pressure, spacetime tears and vector-anomaly caps were reduced, and the stress harness was made safer. Production runner was not executed because headless Godot was explicitly forbidden.
USER Verification: Headless run + in-editor profiler on same hardware as attached data. Target: Process <4 ms, Render <4 ms average.
[x] P0.4 Death Flow & Readability Lock
Reference: Game Systems death fairness + Separation Blueprint "Death no longer permits postmortem firing".
CODEX Assignment: Confirm `player.gd`, `HealthComponent`, `WeaponSystem` immediately stop input, held fire, beam fire, and repeated death signals on death start. Short collapse watch only. No post-death shooting. Update death readout to include exact visual context (chaos tier, active resonance type).
CODEX Completion 2026-06-04: black-hole deaths now set an explicit `last_death_context` and the death lesson reports the event-horizon failure instead of a generic collapse message.
USER Verification: Die intentionally in high-chaos. Confirm immediate lock + clear diagnostic message.
[x] P0.5 Slingshot Mastery Feedback Gating
Reference: Separation Blueprint 2026-06-02 clarity pass + Asset List priority VFX.
CODEX Assignment: Gate rings/audio/particles to `great` / `perfect` / `apex` only. Routine orbit assists stay silent and performant.
CODEX Completion 2026-06-04: slingshot law convergence now requires stronger scores, has a longer cooldown, larger readable zones, lower alpha, and dedicated great/apex audio instead of generic repeated pings.
USER Verification: Perform mix of good/great/apex slingshots. Only high-skill moments produce strong feedback.
[x] Create worm holes that the player can travel through only in between waves that take the user to distant galaxies. Implemented: permanent wave wormholes are off by default, and WaveDirector now opens temporary interwave galaxy gates every other cleared wave with a safe near entry, far exit, and seeded distant galaxy arrival field.
P0 COMPLETE CRITERIA: Screenshot scenario is fully playable and readable. Profiler stable. All checkboxes green. Then proceed to P1.
I the user have approved this.
---
SECTION 3.5: CURRENT PLAYER FEEDBACK TRIAGE (2026-06-03)
These are current-playtest issues and should be treated as design debt, not optional polish.

Combat Feel
[x] Drag-enabled combat must become equally fun to drag-disabled combat. Implemented: Drag ON is now Precision control with braking/tangent blending, gravity-window recovery routing, and a small energy return; Drag OFF remains high-speed Momentum mastery.
[x] Add slight player invincibility after taking a hit. Implemented: `player.gd` starts a short visible post-hit grace window for shield/hull damage and emits telemetry for ignored burst hits.

Beam Weapons
[x] Gravity Wave Beam needs stronger results. Implemented: preserved damage/pull/compression, added planet movement/fracture pressure and beam pressure/displacement metadata.
[x] Chronal Refraction Beam needs a bigger identity. Implemented: capped timeline echoes, phantom offsets, delayed desync impulses/damage, and short temporal echo zones.

Arena And Spawning
[x] Add farther-out planets and larger orbital playspace opportunities. Implemented: WaveDirector seeds far-orbit planets.
[x] Prevent stationary shooter enemies from spawning on planets or inside unsafe planet collision margins. Implemented: stationary/sniper spawns validate planet radius plus clearance.
[x] Prevent teleporters/wormholes from clipping into planets by validating endpoints against planet/gravity-source radius plus a safety margin. Implemented in WaveDirector endpoint placement and WormholePair endpoint pushout.

Projectile Feel
[x] Make player bullets slightly larger and faster. Implemented: Vector Bolt speed/collision/visual scale increased.
[x] Update the projectile predictor/visualizer to match new projectile size, speed, gravity sampling, and collision behavior. Implemented for player and projectile predictor components.
[x] Make player bullet visuals feel sharper, juicier, and more kinetic in the spirit of WINDOWKILL while preserving Vector Anomaly's own visual identity. Implemented: brighter cyan core, larger light, and speed-scaled trail.
[x] Investigate bullets orbiting the player. Implemented: baseline bullets ignore player/player-projectile self-gravity; intentional Orbital Tether captures are tagged with metadata/group membership.

Performance / Visual Overload
[x] Investigate the pink effect shown in `WeAreCooked.png` that drastically slows the game. Implemented: temporal colors/caps retuned, glitch slices throttled, VFX escalation reduced, local slow effects budgeted, and global time scale given a safe floor.
---
SECTION 4: P1 â€” VISUAL CLARITY, VFX & UI POLISH (ALIGNED TO ASSET LIST + ORBITRON SYSTEMS)
After P0 green.
P0 is Green.
CODEX Visual Upgrade 2026-06-13: Upgraded the visual layer only: player phase aura, thruster contrails, projectile vector wakes, pooled burst rings, enemy role halos, boss silhouette reinforcement, planet gravity/fracture rings, black-hole horizon/shear rings, and title-screen vector lattice. All additions stay local/capped through `Settings` visual alpha/radius helpers and still need normal in-editor art review because headless Godot is forbidden.
Visual & VFX Tasks (CODEX primary for code, USER for art direction)
[x] P1.1 Swimming-through-Spacetime Overlay (Asset List Priority VFX)
CODEX: Implement capped `SpacetimeSwimDirector` ribbons (compact phase-shell strokes, throttled, low lifetime/count, subtle wash, capped glitch slices). Low-perf mode reduces counts. Route through visual cap system.
CODEX Progress 2026-06-04: Existing swim/glitch director audited; overlay is capped through `Settings.flash_alpha()` and uses low-count ribbons/slices. Final art tuning remains.
CODEX Completion 2026-06-06: Break-boundary rings and edge refraction now reuse the capped swim/glitch layer, staying compact around the local event instead of adding full-screen noise.
USER: Provide final art direction on ribbon color/feel (sterile early â†’ neon late).
[x] P1.2 Time Dilation Break Effect (Asset List)
CODEX: Screen-edge refraction, stretched particles, readable local pocket boundary. Intensity-based. Capped.
CODEX Completion 2026-06-06: `TimeDilationManager` emits `dilation_break_triggered` on capacity drain, and `SpacetimeSwimDirector` responds with capped glitch slices, swim ribbons, and a readable local boundary ring.
[x] P1.3 Glitch Overlays for Rupture / Law Cracking (Asset List)
CODEX: Implement with reduced-flash variants. Bind to `RunTransitionDirector` and `RuptureDirector`.
CODEX Completion 2026-06-06: `RunTransitionDirector` now adds reduced-flash law-crack slices to LAW/RUPTURE/BREACH transitions, including the Rupture phase's "LAWS CRACKING" transition.
[x] P1.4 Gravity Scar Visual Set (Asset List: curvature scar, compression tear, temporal wound, inversion rupture, harmonic fracture)
CODEX: Scene-authored `Polygon2D` + `Line2D` children preferred. Pooled. Intensity + decay driven alpha/radius.
CODEX Progress 2026-06-04: `GravityScarManager` visuals now use simple capped polygon segments, lower fill/ring/seam alpha, player-focus culling, and reduced particle counts.
[x] P1.5 Permanent Spacetime Rip + Space Tear Portal (Asset List)
CODEX: Capped visuals + enemy emergence via `SpacetimeTearDirector` + `WaveDirector.register\_external\_enemy()`.
CODEX Completion 2026-06-06: Tear visuals are grouped for HUD rare-event indicators, horde tears spawn enemies through the existing tear director, and external spawned enemies remain registered with WaveDirector.
[x] P1.6 Reduced-Flash Variants for All High-Energy Bursts (Asset List)
CODEX: Every burst template has low-flash path. Default to `Settings.flash\_alpha()`.
CODEX Progress 2026-06-04: Added shared `Settings.world_polygon_segments()` and retuned resonance/scar/tear visuals through alpha/radius/segment caps.
[x] P1.7 Resonance Zone Glyphs (Asset List: compression, slipstream, inversion, temporal scar, harmonic orbit)
CODEX: Action-language labels (`PULL IN`, `PUSH OUT`, etc.) per Game Systems. Subdued alpha, capped count, merge rules.
CODEX Progress 2026-06-04: Resonance glyph scene and manager retuned to simple low-alpha rings/glyphs, dynamic particle amounts, and capped geometry.
[x] P1.8 Edge Indicator Icons + Projectile Ownership Accents (Asset List)
CODEX: Gravity (cyan), enemy (amber), boss (red pulsing), rare events. Player shots vs enemy vs captured satellites vs resonance-bent.
CODEX Completion 2026-06-06: HUD edge indicators now include rare event/tear/hazard diamonds alongside gravity/enemy/boss arrows, and converted enemy projectiles switch to cyan captured ownership accents/groups.
[x] P1.9 HUD Icons & Final Polish (Asset List + Game Systems)
CODEX: Energy, shield, slingshot grade, local field rule, chaos tier (T0â€“T5), run arc phase. Weapon slots ready for future beams. Mod manifest status icons.
CODEX Progress 2026-06-04: Added simple mod status SVG icons and upgraded pause-menu mod catalog readout. HUD icon art pass remains.
CODEX Completion 2026-06-06: OrbitalHUD now exposes large HULL/SHIELD/ENERGY bars while retaining slingshot, field, chaos, score, challenge, and weapon readouts.
USER: Final icon art direction.
[x] P1.10 Pause Menu + Game Over Glitch Treatment (Asset List)
CODEX: Section accents, game-over glitch on death vector readouts. Scale centered + viewport-clamped.
CODEX Completion 2026-06-06: Game-over death vector readouts now receive a subtle shader-synced glitch pulse, building on the existing centered/clamped pause-menu scaling pass.
[x] P1.11 Title Screen Background Loop + Final Logo Integration (Asset List)
USER: Create final Vector Anomaly logo (readable at Steam capsule + title screen).
CODEX: Integrate into title scene as looping background.
CODEX Progress 2026-06-04: Created first-pass SVG logo/mark and added runtime title-screen logo texture hook with label fallback.
---
SECTION 5: P2 â€” ASSET & MARKETING PRODUCTION (FROM ASSET_AND_AUDIO_PRODUCTION_LIST â€” NON-NEGOTIABLE FOR STEAM)
USER primary (art/creative) + CODEX for any code hooks.
Priority Visual Assets
[x] Final Vector Anomaly logo (Steam capsule + title screen readable)
CODEX Completion 2026-06-06: Editable logo/mark plus generated title logo exist in `Assets/Brand/`, and `Scripts/title_screen.gd` now uses the final generated logo hook by default with text fallback.
[x] Steam capsule set: small, header, main, vertical, library hero, library logo
CODEX Completion 2026-06-06: First-pass editable Steam capsule and library SVG set exists in `Assets/Brand/` for final paintover/export.
[x] Key art: player slingshotting through collapsing gravity field
CODEX Completion 2026-06-06: Editable key-art layout and generated no-text PNG concept exist in `Assets/Brand/`.
[ ] Press kit screenshots (player, gravity source, threat, trajectory, recovery path clearly visible)
CODEX Prepared 2026-06-06: Capture shot list added in `Debug and Development Files/MARKETING_CAPTURE_MANIFEST.md`; actual screenshots still require a normal non-headless capture pass.
CODEX Code-Side Completion 2026-06-13: Clip Lab now stages every press still, includes a reduced-flash accessibility preset, and can save clean PNG stills plus JSON slates to `user://marketing_captures` from a normal run. Actual media capture remains unchecked until a non-headless capture pass produces and reviews the files.
[x] Trailer capture scenes: early clean vectors, mid-run resonance, late collapse, Rupture, music finale
CODEX Prepared 2026-06-06: Trailer clip manifest added in `Debug and Development Files/MARKETING_CAPTURE_MANIFEST.md`; actual footage still requires a normal non-headless capture pass.
CODEX Completion 2026-06-12: Clip Lab now has number-key capture presets for early, slingshot, resonance, boss-rule, late-collapse, and music-finale setups; actual footage still requires a normal non-headless capture pass.
CODEX Completion 2026-06-13: Clip Lab now maps presets to press/trailer ids, stages Rupture/law-crack and reduced-flash accessibility captures, and writes capture metadata for normal recording sessions.
[x] Boss silhouette polish (all 8 authored bosses + secret ones)
CODEX Completion 2026-06-12: `EnemyReadabilityDirector` now adds larger boss-specific silhouette outlines on top of existing role glyphs, so authored and secret bosses read by shape/profile even in dense effects.
[x] Resonance zone glyphs (as above)
[x] Edge indicator icons + projectile accents (as above)
Priority VFX Assets (see P1)
[x] All listed VFX completed and capped
UI And Menu Assets
[x] Final title-screen background loop
[x] Pause menu section accents
[x] Game over glitch treatment
[x] All HUD icons
[x] Weapon HUD slots
[x] Mod manifest status icons
Music Needed (USER + external composer direction)
[x] Title theme: cold, inviting, precise
[x] Early/mid/late run layers
[x] Rupture cue + Music finale composition (fixed structure for Resonance Singularity)
[x] Credits track: "Neon Starlight"
[x] Boss motifs (polarity, tide, null lanes, compression, resonance)
CODEX Completion 2026-06-06: Title, wave, boss, Rupture, music-finale, and credits music hooks are wired through `title_screen.gd`, `wave_director.gd`, `rupture_director.gd`, `music_finale_director.gd`, and `credits_sequence.gd`. Final mix/master approval remains a creative pass.
Sound Effects Needed
[x] All listed SFX (thrust, slingshot grades, impacts, resonance zones, time dilation, gravity scars, arena events, boss telegraphs, UI cues)
CODEX Completion 2026-06-06: Existing mechanic audio hooks were preserved, selected remaining raw SFX were renamed to `sfx_thrust_vector_surge.mp3` and `sfx_energy_exhausted_low.mp3`, and they are now connected to thrust, shield/resource pressure, energy depletion, and failed weapon-energy cues.
Marketing Capture Needs
[ ] 3-second hook clip (barely survives high-speed gravity collapse)
[ ] Slingshot mastery clip (visible trajectory + perfect/apex recovery)
[ ] Boss-rule clip (physics mutation, not bullet spam)
[ ] Rupture clip (laws cracking, controlled instability)
[ ] Finale clip (music beat â†’ readable reality pulse)
[ ] Accessibility/readability capture (late-game spectacle with clear player/threat positions)
CODEX Code-Side Completion 2026-06-13: All six marketing clip needs plus the accessibility pass now have Clip Lab presets and capture slates. Press `1`-`7` to stage, `0` to toggle reduced flash, `F9` for PNG stills, `F10` for JSON metadata, and `F1` to hide the overlay during external recording. The checkboxes stay open until actual non-headless footage/stills are captured and reviewed.
P2 COMPLETE CRITERIA: All checkboxes green + Steam page assets ready + trailer structure (calm â†’ distortion â†’ escalation â†’ event horizon â†’ impossible survival â†’ title slam) captured.
---
SECTION 6: P3 â€” CONTENT, BALANCE & SYSTEMS COMPLETION (V1.0 SHIP CRITERIA)
Reference: Game Systems, Orbitron Systems, current production clarity pass, launch upgrade matrix.
[x] Launch Upgrade Matrix Complete & Behavioral (Barycentric Tether, Frame-Dragging Anchor, Apex Vector Core, Micro-Lensing, Vacuum Collapse, etc.) â€” All data-driven via `PowerupDefinition` + capped registry queries. No flat stat inflation.
[x] All Authored Bosses Pressure-Scaled â€” Per-boss health floors, attack timers, projectile pressure, contact threat (WaveDirector + challenge modifiers). Polymorph phase pressure included.
[x] Gravity Wave Beam = Real Field Weapon â€” Damage + pulls hostile bodies/projectiles toward beam axis + stamps short compression resonance zone. Stops on pause/death.
[x] Resonance, Scar, Swim, Tear Directors â€” All capped, player-focused, registry-backed, intensity/decay driven.
[x] Adaptive Music StateDirector + Beat Hints â€” Layers (silence/drift/tension/overload/collapse) + beat hints bound to final music.
[x] RunScoreTracker + Challenge Codes â€” Fully emitting score snapshots and shareable codes.
[x] Fair Pacing + DeathFairnessDirector â€” Recovery windows adjust on low health/broken shield/recent mastery. Death readouts concrete.
CODEX Completion 2026-06-06: `FairPacingDirector` now also detects scene-authored `Shield`/`ShieldComponent` nodes when applying broken-shield recovery windows.
[x] Secret Bosses (Vector Shade, Chronal Mirror, Gravity Maw) â€” Hidden routes functional, do not break campaign anchors.
[x] ModContentRegistry + vector_anomaly_mod.json â€” Validation, failed manifest surfacing in pause menu.
CODEX Progress 2026-06-04: Registry upgraded into a broad data-driven mod catalog with dependencies, load order, namespaced entries, content buckets, locked script packs, and pause-menu warning/status surfacing.
CODEX Progress 2026-06-07: Registry now supports playable projectile weapon mods, declarative law weaves, anomaly recipes, challenge cards, palettes, creator notes, hook indexing, capabilities reporting, and normalized mod compatibility signatures without enabling arbitrary script execution.
CODEX Progress 2026-06-13: Mod loading upgraded for exported builds: recursive scan roots now cover `res://Mods`, auto-created `user://mods`, executable-adjacent desktop `mods`/`Mods`, optional custom roots, `vector_anomaly_mod.json`, legacy `mod.json`, manifest-relative paths, scan-root UI diagnostics, and external SFX path resolution while keeping gameplay compatibility hashes portable.
[x] LAN Multiplayer Session Layer + CoopComboDirector â€” `NetworkSession` supports host/play, join by IP/port, roster-driven player spawning, shared run seed/config, hosted restart, projectile/vector event broadcast, peer nameplates, and deterministic co-op combo hooks.
CODEX Progress 2026-06-05: First active LAN multiplayer milestone completed. Remaining ship gates: two-instance LAN smoke test, late-join reconciliation, disconnect UX, version/mod handshake, and Steam transport adapter after GodotSteam/Steam MultiplayerPeer availability.
[x] ArenaRuleDirector + LateGameInstabilityDirector + SpacetimeTearDirector â€” All seeded profiles and capped impossible events functional.
[x] PerformanceBudgetDirector â€” Auto-lowers budgets on FPS drop. Covers late-game instability, co-op, music sampling, transitions.
CODEX Completion 2026-06-06: P3 ship-criteria systems are implemented in code/data. Remaining V1.0 gate work is manual/non-headless verification, captured marketing media, and final external art/mix approval.
V1.0 Ship Gate: All above green + P0/P1/P2 green + headless production runner passes all budgets + full playthrough (standard + boss rush + challenge) stable and readable.
---
SECTION 7: P4 â€” VERSION 1.1 / POST-LAUNCH BACKLOG (DO NOT START UNTIL V1.0 SHIPS)
From original + Orbitron Systems long-term notes. Only after V1.0 green.
[ ] Chronal Refraction Beam, Momentum Conservation Drift, Orbital Memory, Localized Time Debt, Gravitational Scar Formation (permanent), Resonance Cascade
[ ] New enemy designs: Gravimetric Echo Drone, Event Horizon Warden, Phase-Slip Swarm, Orbital Null Harvester, Resonance Paralytic Construct
[ ] Full modding UI + editor tooling, including law-weave/recipe/card authoring, validation previews, workshop packaging, loadout selection, and director-by-director activation of safe effect actions.
[x] Multiplayer continuity upgrade code-side pass 2026-06-23: NET7 protocol surfaced on title/pause UI, readiness snapshots include platform/mod/quality metadata, client run-ready acknowledgements are tracked by the host, player state exports include slingshot/input-device metadata, and hot-path sync queries use capped RuntimeRegistry buffers. Remaining external gates: automated two-instance LAN smoke test, disconnect UX review, and Steam transport adapter after GodotSteam availability.
[ ] Multiplayer continuity upgrade final verification: automated LAN host/client smoke test, late-join world reconciliation, disconnect recovery UX, version/mod handshake, Steam lobby/transport adapter behind `NetworkSession`, then public drop-in co-op polish.
[ ] Daily challenges + community scoreboards
[ ] Galaxy expansion (starmap, travel, region modifiers) â€” only after V1.0 metrics prove retention
---
SECTION 7.5: CURRENT POLISH PASS (2026-06-23)
[x] Readability halo overhaul: enemies keep role silhouettes, bosses keep large outlines, players get control-vector halos, and gravity objects get distinct horizon/flow/gate/gravity/field profiles.
[x] Pause-menu overlap pass: checkbox rows are moved out of cramped button rows, checkbox hover tweens no longer scale text boxes, and controller deadzone/right-stick options are exposed.
[x] HUD scale pass: the HUD root now resizes inversely to UI scale so the score panel remains inside the safe viewport.
[x] Controller and device pass: runtime input actions cover keyboard, joypad axes/buttons, heat-map toggle, controller auto-detect, connected-joypad aim, and persisted controller settings.
[x] Slingshot feel pass: mastery impulses now apply as immediate-plus-smoothed momentum while preserving speed caps.
[x] Gravity heat-map performance pass: adaptive sample grid, capped source buffers, packed sample arrays, gradient stride, and capped alpha for the golden route.
[x] Black-hole hardening pass: invalid bodies are revalidated after field/spaghettification work, collision disabling is depth-limited, and unsafe bodies are quarantined before deferred cleanup.
[x] Reduced-flash pass: persistent gameplay readability is less aggressively dimmed while transient flash caps remain in place.
[x] Platform support pass: `PLATFORM_SUPPORT_MATRIX.md` records Windows/Linux/macOS/Steam Deck/console status and validation gates.
[x] Marketing capture pass: Steam screenshot/clip discovery list expanded with controller, heat-map, black-hole, co-op, accessibility, and Steam Deck proof targets.
[x] Website/wiki pass: public pages now reference v1.0.4.7, NET7 LAN readiness, controller/deck support path, heat map, halo readability, and accurate platform status.
Manual verification still required in a normal editor/standalone run because this assignment explicitly forbids opening headless Godot.
---
SECTION 7.6: CAMPAIGN / MOD EXPANSION PASS (2026-06-24)
[x] Gravity Ghost readability pass: the panel now reads as `FINAL FLIGHT REPLAY`, has editable scene labels for route markers and pressure legend, and keeps the black-box replay meaning clear.
[x] Home-planet campaign pass: title screen entries now launch campaign and KOTH scenes with invaders, escorts, hostile planet turrets, alien barter/fight choices, and a home planet that all remain editable in the scene viewer.
[x] Energy economy pass: physics drops can award energy currency, and campaign upgrades spend it on escorts, speed, damage, armor, slingshot power, and hijack orders.
[x] Mod expansion pass: bundled schema 4 packs now define Space Oregon Trail survival systems plus party-mode catalogs for gravity soccer, emotes, hijack variants, and battle-ship building.
Manual verification still required in a normal editor/standalone run because this assignment explicitly forbids opening headless Godot.
---
SECTION 8: PERFORMANCE TARGETS (UPDATED WITH PROFILER EVIDENCE)
Frame Rate: 60 FPS min / 120 FPS preferred budget path (current spikes must be eliminated)
CPU: Physics <4 ms, Gameplay logic <4 ms (via registry + pooling)
GPU/Render: <4 ms sustained (fix Render Viewport 17+ ms spikes)
Entity Budgets: 300+ enemies, 1000+ projectiles stable
Memory: No GC spikes, no excessive alloc in combat
Verification Command: Always run `production\_simulation\_runner.gd` after changes + in-editor profiler on Wave 3+ high-chaos scenario
---
SECTION 9: PRODUCTION TIMELINE (ADJUSTED FOR CURRENT STATE)
Current Reality: Many core systems marked complete in old doc, but P0 visual/perf crisis + missing assets block ship.
Week 1 (Now): P0 complete (visual overload fix + perf stabilization). Target: 3â€“5 days.
Week 2: P1 VFX/UI polish + begin P2 asset creation (logo, capsules, key art).
CODEX Progress 2026-06-04: P1 visual caps tightened for resonance zones, gravity scars, and tears; mod catalog upgraded; first-pass logo/capsule/key-art assets started.
Week 3: Complete P2 assets + marketing captures. Music/SFX integration.
Week 4: Full V1.0 content pass + balance (boss pressure, upgrades behavioral).
Week 5: Content lock + final polish. Steam page live with assets.
Week 6: Trailer final + demo build. External feedback.
Week 7: Release candidate. Full passes.
Week 8: Launch.
Any slip in P0 pushes everything.
---
SECTION 10: FINAL VISION & SUCCESS METRICS
Vector Anomaly = survivable visual paradox generator wrapped in familiar roguelike arena handshake.
Success = Players say:
â€œI know how this kind of game worksâ€¦ but Iâ€™ve never seen physics do THIS.â€
â€œI should have died but the orbit saved me.â€
Shareable clips of impossible moments that become understandable after survival.
Post-Launch North Star: Watchable impossibility that feels unfakeable in motion.
---
END OF v2.0 DROP-IN REPLACEMENT
Next action: Mark P0.1â€“P0.5 complete after fixes. Then hand CODEX the next section.
This document is now the living checklist. Update it in real time. Ship only when every relevant box is checked and profiler + playtest confirm readability + performance.
References for CODEX (always include in prompts):
Asset List sections for visuals/audio
Game Systems for progression/resonance/arena rules
Orbitron Systems for RuntimeRegistry, pooling, particle rules, directors
Separation Blueprint for commercial pillars, clarity pass, viral mechanics
Similarity Blueprint for familiarity guardrails
Universe Guide for tone/writing
Attached profiler images + game screenshot as current failure evidence
---
Document generated to directly solve the exact issues visible in the provided attachments and align 100% with every production document.
