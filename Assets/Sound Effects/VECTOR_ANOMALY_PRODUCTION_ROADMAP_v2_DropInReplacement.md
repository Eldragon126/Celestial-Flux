# VECTOR ANOMALY: MASTER PRODUCTION ROADMAP & SHIP DIRECTIVE v2.0
**Drop-In Replacement • Actionable Checklist for Solo Developer + CODEX**  
**Date: 2026-06-02**  
**Status: P0 BLOCKERS ACTIVE — Visual Overload + Performance Crisis**  
**Aligned To:** All attached production documents (Asset List, Game Systems, Orbitron Systems, Universe Guide, Separation Blueprint, Similarity Blueprint, current profiler data, and in-game visual evidence)  
**Goal:** Fix immediate readability/perf killers, complete V1.0 ship criteria, produce missing priority assets, and create a check-off system that both you and CODEX can use. Every task references source docs.

---

## HOW TO USE THIS DOCUMENT (MANDATORY)
- **Checkboxes** are the single source of truth. Mark `[x]` when **done and verified**.
- **CODEX Assignments**: Hand to CODEX (or equivalent) with the exact task text + reference to source doc section. CODEX must output changed files + proof it follows Execution Rules.
- **USER Assignments**: Your tasks (art direction, playtesting, asset creation, final decisions).
- **BOTH**: Joint review required.
- After any change: Run `production_simulation_runner.gd` (headless) + in-editor profiler + playtest the exact scenario from the attached screenshot (Wave 3, visible gravity source + resonance).
- **Never ship** until P0 section is 100% green and profiler shows stable <16.67 ms frame time with no giant overlays.
- This replaces the previous roadmap entirely. Old status markers are superseded by these explicit, verifiable tasks.

---

## SECTION 1: EXECUTION RULES (ENFORCED — NO EXCEPTIONS)
From original roadmap + reinforced by profiler data, Orbitron Systems particle rules, and Separation Blueprint production clarity pass.

1. **Strict Type Safety** — All variables, params, returns, members: explicit type hints. No Variant/untyped in hot paths.
2. **Performance First (Profiler-Driven)** — Zero dynamic allocations in `_process()` / `_physics_process()`. Preallocated arrays, pooling, reusable buffers only. Target: Process Time <4 ms, Render <4 ms sustained. Current evidence (attached profilers): Process Time 95%+, Render Viewport 17-22 ms CPU spikes → immediate cap enforcement required.
3. **Engine-Native + Godot 4.4** — Tabs, composition over inheritance, UI separated from gameplay.
4. **Simple > Clever** — If two solutions give similar gameplay, pick simpler + more performant.
5. **Release First** — Any task threatening stability delayed to 1.1. V1.0 = polished, stable, replayable physics collapse simulator.
6. **Visual Cap Enforcement** (NEW from Separation Blueprint + current crisis) — Every bright effect, resonance zone, Polygon2D, Line2D, GPUParticles2D **must** route through `Settings.flash_alpha()` or explicit intensity-based alpha/radius caps. No full-screen overlays. Player-focused only.
7. **Readability Guard** (NEW) — No visual may obscure the player ship or threats. "Trust orbits, not noise" means clean orbital telemetry, **not** giant filled circles.

---

## SECTION 2: CORE PILLARS (ALIGNED TO SEPARATION BLUEPRINT + SIMILARITY BLUEPRINT)
Every feature/task must reinforce at least one:

1. **MOVEMENT = READABLE GENIUS** (Similarity Blueprint) — Chaos at low skill → Intention at mid → Impossibility at high. Every movement system must generate clips. Slingshot mastery gated to great/apex only (per 2026-06-02 clarity pass).
2. **PHYSICS = SPECTACLE FIRST** (Separation Blueprint) — Controlled visual collapse. Gravity visibly warps space. Orbit paths break/reform. Time dilation physically visible. **But capped and readable** — no screen-filling purple disks.
3. **VISUAL IDENTITY = ALGORITHMIC COLLAPSE** — Early: sterile monochrome vectors. Mid: cyan + violet instability. Late: neon fractures + red gravity warnings. **Current blocker**: The giant purple circle violates this progression and must be fixed before any new visuals.
4. **EMOTIONAL LOOP = NEAR MISS ADDICTION** — "I should have died but didn’t." Generate last-frame escapes, accidental genius, physics-assisted survival. Death = immediate diagnostic (no post-death firing).
5. **FAMILIAR HANDSHAKE, UNFAMILIAR SHOCKWAVE** (Similarity Blueprint) — Wave-based arena survival, run progression, build identity, clear enemy intent, risk/reward clarity must feel like Nova Drift peers. Physics layer is the unique shockwave on top.

---

## SECTION 3: P0 — CRITICAL BLOCKERS (COMPLETE THESE FIRST — NO NEW FEATURES UNTIL GREEN)
**Evidence**: Attached game screenshot shows unreadable full-screen purple overlay (labeled "CHAOS SPIKE...") + tiny player ship at bottom edge. Attached profilers show Process Time 95%+, Render spikes 17+ ms. This violates every readability, performance, and visual cap rule in the docs.

**Owner for all P0 tasks: CODEX primary (code fixes) + USER verification/playtest**

- [ ] **P0.1 Identify & Eliminate Giant Purple Overlay Root Cause**  
  Reference: Game screenshot + Separation Blueprint "resonance visual alpha is intentionally subdued... capped... player-focused... only renders when intense enough and close enough". Orbitron Systems resonance architecture + particle rules.  
  **CODEX Assignment**: Audit `GravityResonanceManager`, `ArenaDestabilizationManager`, `OrbitalVFXDirector`, any `Polygon2D`/`Line2D` used for chaos/resonance zones. Find the node creating the massive filled purple circle (likely wrong scale, alpha=1.0, or unbounded radius on a resonance/compression zone). Force it through intensity-based radius (max 300-400 px at full intensity) + alpha <= 0.25-0.4 (use `Settings.flash_alpha()`). Add explicit `is_instance_valid()` guards. Replace with subtle gradient ring + directional arrows only. Output diff + before/after profiler.  
  **USER Verification**: Play Wave 3 scenario from screenshot. Confirm player ship and threats remain fully visible at all times. No full-screen color fills.

- [ ] **P0.2 Enforce Global Visual Cap System**  
  Reference: Separation Blueprint production clarity pass + Asset List VFX rules + Orbitron particle rules + profiler data.  
  **CODEX Assignment**: Create/strengthen `Settings.flash_alpha()` path (or equivalent) and apply to **every** bright effect, resonance zone, gravity scar, time dilation overlay, slingshot ring, powerup ring, beam, particle burst. All `GPUParticles2D`, `Line2D`, `Polygon2D` in `OrbitalVFXDirector` and directors must query this cap. Disable player-adjacent colored telemetry rings by default (HUD readouts only). Cap active resonance zones to strongest local only. Output: centralized cap utility + audit report of all call sites.  
  **USER Verification**: Run profiler during high-chaos moment. Confirm no spikes above 16 ms sustained. Visuals remain tactical pressure, never noise.

- [ ] **P0.3 Performance Hot-Path Audit & Registry Enforcement**  
  Reference: Orbitron Systems RuntimeRegistry + VectorAnomalyDirector + profiler Process/Render data + production simulation runner.  
  **CODEX Assignment**: Ensure **all** hot systems (gravity refresh, resonance sampling, projectile prediction, enemy AI, VFX spawning, HUD arrows) use `RuntimeRegistry` cached nearest-source / radius-query buffers exclusively. No scene-tree group scans in `_physics_process`. Prewarm all pools in `OrbitalVFXDirector`. Throttle any remaining discovery. Run `production_simulation_runner.gd` and report pass/fail against budgets (projectiles <1000, VFX bursts capped, frame time stable).  
  **USER Verification**: Headless run + in-editor profiler on same hardware as attached data. Target: Process <4 ms, Render <4 ms average.

- [ ] **P0.4 Death Flow & Readability Lock**  
  Reference: Game Systems death fairness + Separation Blueprint "Death no longer permits postmortem firing".  
  **CODEX Assignment**: Confirm `player.gd`, `HealthComponent`, `WeaponSystem` immediately stop input, held fire, beam fire, and repeated death signals on death start. Short collapse watch only. No post-death shooting. Update death readout to include exact visual context (chaos tier, active resonance type).  
  **USER Verification**: Die intentionally in high-chaos. Confirm immediate lock + clear diagnostic message.

- [ ] **P0.5 Slingshot Mastery Feedback Gating**  
  Reference: Separation Blueprint 2026-06-02 clarity pass + Asset List priority VFX.  
  **CODEX Assignment**: Gate rings/audio/particles to `great` / `perfect` / `apex` only. Routine orbit assists stay silent and performant.  
  **USER Verification**: Perform mix of good/great/apex slingshots. Only high-skill moments produce strong feedback.

**P0 COMPLETE CRITERIA**: Screenshot scenario is fully playable and readable. Profiler stable. All checkboxes green. Then proceed to P1.

---

## SECTION 4: P1 — VISUAL CLARITY, VFX & UI POLISH (ALIGNED TO ASSET LIST + ORBITRON SYSTEMS)
After P0 green.

### Visual & VFX Tasks (CODEX primary for code, USER for art direction)
- [ ] **P1.1 Swimming-through-Spacetime Overlay** (Asset List Priority VFX)  
  CODEX: Implement capped `SpacetimeSwimDirector` ribbons (compact phase-shell strokes, throttled, low lifetime/count, subtle wash, capped glitch slices). Low-perf mode reduces counts. Route through visual cap system.  
  USER: Provide final art direction on ribbon color/feel (sterile early → neon late).

- [ ] **P1.2 Time Dilation Break Effect** (Asset List)  
  CODEX: Screen-edge refraction, stretched particles, readable local pocket boundary. Intensity-based. Capped.

- [ ] **P1.3 Glitch Overlays for Rupture / Law Cracking** (Asset List)  
  CODEX: Implement with reduced-flash variants. Bind to `RunTransitionDirector` and `RuptureDirector`.

- [ ] **P1.4 Gravity Scar Visual Set** (Asset List: curvature scar, compression tear, temporal wound, inversion rupture, harmonic fracture)  
  CODEX: Scene-authored `Polygon2D` + `Line2D` children preferred. Pooled. Intensity + decay driven alpha/radius.

- [ ] **P1.5 Permanent Spacetime Rip + Space Tear Portal** (Asset List)  
  CODEX: Capped visuals + enemy emergence via `SpacetimeTearDirector` + `WaveDirector.register_external_enemy()`.

- [ ] **P1.6 Reduced-Flash Variants for All High-Energy Bursts** (Asset List)  
  CODEX: Every burst template has low-flash path. Default to `Settings.flash_alpha()`.

- [ ] **P1.7 Resonance Zone Glyphs** (Asset List: compression, slipstream, inversion, temporal scar, harmonic orbit)  
  CODEX: Action-language labels (`PULL IN`, `PUSH OUT`, etc.) per Game Systems. Subdued alpha, capped count, merge rules.

- [ ] **P1.8 Edge Indicator Icons + Projectile Ownership Accents** (Asset List)  
  CODEX: Gravity (cyan), enemy (amber), boss (red pulsing), rare events. Player shots vs enemy vs captured satellites vs resonance-bent.

- [ ] **P1.9 HUD Icons & Final Polish** (Asset List + Game Systems)  
  CODEX: Energy, shield, slingshot grade, local field rule, chaos tier (T0–T5), run arc phase. Weapon slots ready for future beams. Mod manifest status icons.  
  USER: Final icon art direction.

- [ ] **P1.10 Pause Menu + Game Over Glitch Treatment** (Asset List)  
  CODEX: Section accents, game-over glitch on death vector readouts. Scale centered + viewport-clamped.

- [ ] **P1.11 Title Screen Background Loop + Final Logo Integration** (Asset List)  
  USER: Create final Vector Anomaly logo (readable at Steam capsule + title screen).  
  CODEX: Integrate into title scene as looping background.

---

## SECTION 5: P2 — ASSET & MARKETING PRODUCTION (FROM ASSET_AND_AUDIO_PRODUCTION_LIST — NON-NEGOTIABLE FOR STEAM)
**USER primary** (art/creative) + CODEX for any code hooks.

### Priority Visual Assets
- [ ] Final Vector Anomaly logo (Steam capsule + title screen readable)
- [ ] Steam capsule set: small, header, main, vertical, library hero, library logo
- [ ] Key art: player slingshotting through collapsing gravity field
- [ ] Press kit screenshots (player, gravity source, threat, trajectory, recovery path clearly visible)
- [ ] Trailer capture scenes: early clean vectors, mid-run resonance, late collapse, Rupture, music finale
- [ ] Boss silhouette polish (all 8 authored bosses + secret ones)
- [ ] Resonance zone glyphs (as above)
- [ ] Edge indicator icons + projectile accents (as above)

### Priority VFX Assets (see P1)
- [ ] All listed VFX completed and capped

### UI And Menu Assets
- [ ] Final title-screen background loop
- [ ] Pause menu section accents
- [ ] Game over glitch treatment
- [ ] All HUD icons
- [ ] Weapon HUD slots
- [ ] Mod manifest status icons

### Music Needed (USER + external composer direction)
- [ ] Title theme: cold, inviting, precise
- [ ] Early/mid/late run layers
- [ ] Rupture cue + Music finale composition (fixed structure for Resonance Singularity)
- [ ] Credits track: "Neon Starlight"
- [ ] Boss motifs (polarity, tide, null lanes, compression, resonance)

### Sound Effects Needed
- [ ] All listed SFX (thrust, slingshot grades, impacts, resonance zones, time dilation, gravity scars, arena events, boss telegraphs, UI cues)

### Marketing Capture Needs
- [ ] 3-second hook clip (barely survives high-speed gravity collapse)
- [ ] Slingshot mastery clip (visible trajectory + perfect/apex recovery)
- [ ] Boss-rule clip (physics mutation, not bullet spam)
- [ ] Rupture clip (laws cracking, controlled instability)
- [ ] Finale clip (music beat → readable reality pulse)
- [ ] Accessibility/readability capture (late-game spectacle with clear player/threat positions)

**P2 COMPLETE CRITERIA**: All checkboxes green + Steam page assets ready + trailer structure (calm → distortion → escalation → event horizon → impossible survival → title slam) captured.

---

## SECTION 6: P3 — CONTENT, BALANCE & SYSTEMS COMPLETION (V1.0 SHIP CRITERIA)
Reference: Game Systems, Orbitron Systems, current production clarity pass, launch upgrade matrix.

- [ ] **Launch Upgrade Matrix Complete & Behavioral** (Barycentric Tether, Frame-Dragging Anchor, Apex Vector Core, Micro-Lensing, Vacuum Collapse, etc.) — All data-driven via `PowerupDefinition` + capped registry queries. No flat stat inflation.
- [ ] **All Authored Bosses Pressure-Scaled** — Per-boss health floors, attack timers, projectile pressure, contact threat (WaveDirector + challenge modifiers). Polymorph phase pressure included.
- [ ] **Gravity Wave Beam = Real Field Weapon** — Damage + pulls hostile bodies/projectiles toward beam axis + stamps short compression resonance zone. Stops on pause/death.
- [ ] **Resonance, Scar, Swim, Tear Directors** — All capped, player-focused, registry-backed, intensity/decay driven.
- [ ] **Adaptive Music StateDirector + Beat Hints** — Layers (silence/drift/tension/overload/collapse) + beat hints bound to final music.
- [ ] **RunScoreTracker + Challenge Codes** — Fully emitting score snapshots and shareable codes.
- [ ] **Fair Pacing + DeathFairnessDirector** — Recovery windows adjust on low health/broken shield/recent mastery. Death readouts concrete.
- [ ] **Secret Bosses (Vector Shade, Chronal Mirror, Gravity Maw)** — Hidden routes functional, do not break campaign anchors.
- [ ] **ModContentRegistry + vector_anomaly_mod.json** — Validation, failed manifest surfacing in pause menu.
- [ ] **Multiplayer Sync Foundation + CoopComboDirector** — Passive deterministic snapshots + combo hooks ready (no networking yet).
- [ ] **ArenaRuleDirector + LateGameInstabilityDirector + SpacetimeTearDirector** — All seeded profiles and capped impossible events functional.
- [ ] **PerformanceBudgetDirector** — Auto-lowers budgets on FPS drop. Covers late-game instability, co-op, music sampling, transitions.

**V1.0 Ship Gate**: All above green + P0/P1/P2 green + headless production runner passes all budgets + full playthrough (standard + boss rush + challenge) stable and readable.

---

## SECTION 7: P4 — VERSION 1.1 / POST-LAUNCH BACKLOG (DO NOT START UNTIL V1.0 SHIPS)
From original + Orbitron Systems long-term notes. Only after V1.0 green.

- [ ] Chronal Refraction Beam, Momentum Conservation Drift, Orbital Memory, Localized Time Debt, Gravitational Scar Formation (permanent), Resonance Cascade
- [ ] New enemy designs: Gravimetric Echo Drone, Event Horizon Warden, Phase-Slip Swarm, Orbital Null Harvester, Resonance Paralytic Construct
- [ ] Full modding UI + editor tooling
- [ ] Online co-op drop-in
- [ ] Daily challenges + community scoreboards
- [ ] Galaxy expansion (starmap, travel, region modifiers) — only after V1.0 metrics prove retention

---

## SECTION 8: PERFORMANCE TARGETS (UPDATED WITH PROFILER EVIDENCE)
- Frame Rate: 60 FPS min / 120 FPS preferred budget path (current spikes must be eliminated)
- CPU: Physics <4 ms, Gameplay logic <4 ms (via registry + pooling)
- GPU/Render: <4 ms sustained (fix Render Viewport 17+ ms spikes)
- Entity Budgets: 300+ enemies, 1000+ projectiles stable
- Memory: No GC spikes, no excessive alloc in combat
- **Verification Command**: Always run `production_simulation_runner.gd` after changes + in-editor profiler on Wave 3+ high-chaos scenario

---

## SECTION 9: PRODUCTION TIMELINE (ADJUSTED FOR CURRENT STATE)
**Current Reality**: Many core systems marked complete in old doc, but P0 visual/perf crisis + missing assets block ship.

- **Week 1 (Now)**: P0 complete (visual overload fix + perf stabilization). Target: 3–5 days.
- **Week 2**: P1 VFX/UI polish + begin P2 asset creation (logo, capsules, key art).
- **Week 3**: Complete P2 assets + marketing captures. Music/SFX integration.
- **Week 4**: Full V1.0 content pass + balance (boss pressure, upgrades behavioral).
- **Week 5**: Content lock + final polish. Steam page live with assets.
- **Week 6**: Trailer final + demo build. External feedback.
- **Week 7**: Release candidate. Full passes.
- **Week 8**: Launch.

Any slip in P0 pushes everything.

---

## SECTION 10: FINAL VISION & SUCCESS METRICS
Vector Anomaly = **survivable visual paradox generator** wrapped in familiar roguelike arena handshake.

Success = Players say:
- “I know how this kind of game works… but I’ve never seen physics do THIS.”
- “I should have died but the orbit saved me.”
- Shareable clips of impossible moments that become understandable after survival.

**Post-Launch North Star**: Watchable impossibility that feels unfakeable in motion.

---

**END OF v2.0 DROP-IN REPLACEMENT**  
Next action: Mark P0.1–P0.5 complete after fixes. Then hand CODEX the next section.  
This document is now the living checklist. Update it in real time. Ship only when every relevant box is checked and profiler + playtest confirm readability + performance.

**References for CODEX (always include in prompts)**:  
- Asset List sections for visuals/audio  
- Game Systems for progression/resonance/arena rules  
- Orbitron Systems for RuntimeRegistry, pooling, particle rules, directors  
- Separation Blueprint for commercial pillars, clarity pass, viral mechanics  
- Similarity Blueprint for familiarity guardrails  
- Universe Guide for tone/writing  
- Attached profiler images + game screenshot as current failure evidence

---

*Document generated to directly solve the exact issues visible in the provided attachments and align 100% with every production document.*