# VECTOR ANOMALY
## The Commercial Separation Blueprint (Million-Dollar Revision)

---

# Core Truth (Reframed for Money)

Most arena roguelikes fail commercially for one reason:

They are fun to play, but not impossible to describe in 5 seconds.

VECTOR ANOMALY must be:

> a physics collapse simulator where survival is a skill expression of gravity manipulation

More importantly:

> a game that looks unfakeable in motion

If someone cannot explain it instantly but cannot forget it after seeing it once, it wins.

---

# The Market Hook (Optimized for Conversion)

## Elevator Pitch (Steam Page Ready)

A physics roguelike where you don’t just dodge bullets, you survive collapsing gravity, unstable spacetime, and orbital combat that rewrites itself mid-fight.

---

## Secondary Hook (Streamer Hook)

“I didn’t lose because I died. I lost because physics changed.”

---

# The Real Money Layer

The product is not mechanics.

The product is:

> watchable impossibility

Indie games win when they are:

- instantly visually confusing
- clearly skill-based underneath
- endlessly clip-worthy

---

# THE FOUR PILLARS

---

# 1. MOVEMENT = READABLE GENIUS

Movement must behave like:

- chaos at low skill
- intention at mid skill
- impossibility at high skill

## Design Rule

Every movement system must generate clips.

---

# 2. PHYSICS = SPECTACLE FIRST

Physics is not simulation accuracy.

Physics is:

> controlled visual collapse

## Required Feel

- gravity visibly warps space
- orbit paths break and reform
- time dilation is physically visible
- enemies drift in non-Euclidean motion

---

# 3. VISUAL IDENTITY = ALGORITHMIC COLLAPSE

The game must look:

> like a GPU hallucinating a dying universe

## Visual Progression

Early:
- sterile monochrome vectors

Mid:
- cyan + violet instability

Late:
- neon fractures + red gravity warnings

---

# 4. EMOTIONAL LOOP = NEAR MISS ADDICTION

Core emotional state:

> I should have died but didn’t

The game must constantly generate:

- last-frame escapes
- accidental genius plays
- physics-assisted survival

---

# VIRAL MECHANICS (CORE MONEY DRIVERS)

---

## 1. Gravity Ghost Replay System

After death:

- replay last 10–20 seconds
- show survival trajectory
- highlight “impossible saves”

Purpose:
> players generate their own marketing clips

Production update (2026-06-21): the local player's final 14 seconds are now retained in a fixed-size sample ring and reconstructed on the game-over screen as a looping Gravity Ghost. Great/apex slingshots, near misses, successful recovery windows, and event-horizon escapes become mastery marks along the route. The 2026-06-23 pass adds a speed/pressure lane, component pressure bands, incident markers, and event-specific timeline markers so the replay explains both motion and danger timing. This is a presentation replay, not a live physics rewind, so it stays bounded and cannot re-trigger combat state.

---

## 2. “WHAT JUST HAPPENED?” EVENTS

- gravity inversion storms
- orbit collapse pulses
- spacetime fractures

Rule:

Events must be confusing in real-time but understandable after.

---

## 3. RESONANCE COMBO SYSTEM

- matching frequencies create chain reactions
- chain reactions escalate visuals
- escalation increases score and spectacle

Purpose:
> streamer dopamine + clip escalation ladder

---

## 4. EVENT HORIZON MODE

Late-game collapse state:

- UI distortion
- orbit instability maxed
- music warping
- visual tearing

Purpose:
> automatic trailer generator inside gameplay

---

# WHAT TO REMOVE

Do NOT build:

- weapon spam systems
- RPG stat inflation
- filler upgrades
- HP sponge enemies
- non-clip-generating mechanics

Rule:

If it does not create a shareable moment, it is debt.

Modding rule:

Player-made content should extend the physics language, not bypass it. The production modding path is declarative: safe weapon profiles, law weaves, anomaly recipes, challenge cards, palettes, and creator notes are cataloged by `ModContentRegistry`, indexed by hooks/effects, and consumed only by trusted directors. No default arbitrary script execution, no unbounded spawn spam, and no mod feature should break the promise that movement plus collapsing physics is the star.

---

# PRODUCTION CLARITY PASS - 2026-06-02

The current build moves the hook closer to "watchable impossibility" by cutting visual noise that was masking skill expression.

- Slingshot mastery is now the premium moment: rings and audio are reserved for strong great/apex vectors, while routine orbit assists stay quiet and performant.
- Gravity Wave Beam now visibly edits enemy motion by pulling targets toward the beam line, making field control inspectable in motion.
- Gravity Wave Beam now also moves/fractures destructible planets, giving the beam visible world-editing results instead of only target drift.
- Chronal Refraction Beam now sells the time fantasy with capped echo traces, delayed lateral desync impulses, and short temporal echo zones.
- Drag ON is now the Precision style with braking/tangent control and recovery routing; Drag OFF remains the Momentum style for high-speed preservation.
- Resonance and scar fields are capped, player-focused, lower-alpha, and shorter-lived so collapse reads as tactical pressure instead of a screen full of identical circles.
- Player orbit telemetry rings are disabled by default; the HUD keeps the information in compact readouts and arrows.
- Player bolts are larger/faster with matching predictor constants and sharper speed trails. Baseline bullets ignore player self-gravity; orbiting bullets are intentional Orbital Tether capture behavior.
- Orbital trajectory prediction is restored as a bright, readable world-space future path: orange immediate danger, cyan continuation, glow, and fade. It should sell “watchable impossibility” while remaining useful for movement decisions.
- The playable tutorial is available from the title screen for movement, slingshot, bolt, Gravity Wave, and Chronal Beam practice.
- Death no longer permits postmortem firing or false recovery. It reads as immediate trajectory failure followed by a short collapse watch.
- Player hits now have a short visible invulnerability window so burst stacks are readable instead of instantly fatal.
- Boss pressure is no longer flat. Each authored boss receives wave-scaled health, attack cadence, projectile pressure, and contact threat without becoming a generic HP sponge.

---

# STEAM PAGE STRATEGY

## Screenshot Rule

Every screenshot must trigger:

“How is that movement possible?”

## Trailer Structure

1. calm baseline physics
2. first gravity distortion
3. escalating instability chain
4. event horizon collapse
5. impossible survival moment
6. title slam

---

# PRICING STRATEGY

Recommended:

$9.99 – $14.99

Reason:

You are selling intensity, not content hours.

---

# VIRAL LOOP DESIGN

Core loop:

PLAY → CHAOS MOMENT → CLIP → SHARE → WISHLIST

Every system must feed this loop.

---

# DEVELOPMENT PRIORITY

## Phase 1
Movement feel + gravity interaction clarity

## Phase 2
Physics instability systems

## Phase 3
Replay + event horizon systems

## Phase 4
Polish density + visual clarity

---

# FINAL VISION

VECTOR ANOMALY is not a shooter.

It is a:

> survivable visual paradox generator

Players do not just play to win.

They play to experience impossible moments that become understandable only after survival.

That gap between confusion and mastery is the engine that makes the game shareable, watchable, and commercially viable.

---

# Production Separation Update

Vector Anomaly now separates hot simulation state from scene-tree discovery through `RuntimeRegistry`.

- Combat systems ask the registry for cached projectile/enemy/gravity lists.
- Gravity systems request capped nearest sources instead of sorting all sources locally.
- VFX systems read cached projectile pressure and reuse pooled burst/ring nodes.
- Mod manifests use `vector_anomaly_mod.json`, keeping public naming aligned with the commercial identity.

The separation rule is now explicit: gameplay may create physics dread, but production systems must keep discovery, pooling, save anchoring, UI, and data-driven content isolated from each other.

## Production Boundary Update

Late-wave spectacle now has explicit technical boundaries:

- `RuntimeRegistry` owns hot discovery and reuses scratch buffers for nearest gravity and target-radius queries.
- Dynamic gravity debris and tide-pocket gravity sources register with the cache at group-entry time and unregister on exit.
- `OrbitalVFXDirector` owns pooled particle bursts; gameplay systems emit events instead of duplicating particles.
- `PowerupInventory` owns pooled law/powerup rings and reusable target buffers for upgrade effects.
- Barycentric Tether and Frame-Dragging Anchor remain inventory-owned field effects: definitions live in resources, target selection uses capped registry queries, and runtime work stays throttled without scene creation.
- `production_simulation_runner.gd` owns stress validation and reports frame/projectile/VFX budgets without becoming part of gameplay state; use the non-headless runner scene when project autoloads or the Steam demo profile must be present.
- Resonance, momentum, boss field, replay, paralysis, readability, death-readout, music-pressure, stress, and sync systems consume registry buffers/counts instead of owning separate scene-tree discovery.
- Opening prompts and credits now use the Vector Anomaly identity directly, keeping presentation labels separate from retired internal names.
- Settings persistence lives in the `Settings` autoload and is consumed by pause/HUD/VFX systems instead of each UI surface owning separate config state.
- Title secret completion is gated behind an explicit secret-mode state, keeping menu presentation separate from hidden encounter cleanup.
- LAN multiplayer now lives behind `NetworkSession`, keeping host/join transport, roster, run config, projectile/vector events, hosted restart, and leave-session cleanup separate from core gameplay scripts.
- Multiplayer gameplay compatibility is routed through `MultiplayerTargeting`, player state import/export, and deterministic vector events so enemies, projectiles, HUD, and co-op combo systems do not assume one hardcoded player.
- Safe mod hooks now resolve through `ModHookDirector`: manifests declare conditions/effects, the registry validates/indexes them, and a trusted director applies bounded resonance/scar/powerup/weapon/HUD/SFX effects or records higher-level requests. Player-triggered hook effects replay through `NetworkSession` by entry id instead of giving mods script execution or raw scene spawning.
- Weapon expansion stays catalog-driven. New built-in weapons and mod weapons share the same projectile payload, HUD, prediction, energy, and network projectile path, including the safe pattern vocabulary `converge`, `scissor`, and `pinwheel`.
- Death presentation now owns a bounded Gravity Ghost reconstruction. `GravityGhostRecorder` samples only the local player's rolling movement history and pressure components, then exports packed display data to `RunProgress`; the game-over panel animates that data without retaining enemies, projectiles, or live scene objects.
- HUD simulation and HUD presentation are now explicitly separated: `RuntimeRegistry` owns target membership, throttled HUD samplers own readable telemetry, and screen projection/layout work runs only at the cadence each visual actually needs.
- HUD iconography now lives in `VectorHudGlyph`, a code-native presentation component. OrbitalHUD owns value binding and severity decisions, while the glyph draws compact shapes with `Settings` readability colors, keeping UI art replacement separate from simulation telemetry.

The commercial rule remains unchanged: the player should see impossible physics, while the code keeps discovery, pooling, validation, UI, saves, and content manifests separated into inspectable systems.

## Multiplayer Continuity Roadmap

The LAN milestone should grow through adapters and validation, not gameplay rewrites:

- Keep ENet LAN and future Steam support behind the same `NetworkSession` contract.
- Add a two-instance smoke test before describing multiplayer as release-stable.
- Treat late joining as a reconciliation project: wave state, boss state, player health/energy, active hazards, and mod/version compatibility must all agree.
- Every new player-owned mechanic must declare whether it is local visual state, exported proxy state, reliable event, or deterministic seed-driven behavior.
- Every new hostile targeting path must use roster-aware helpers so solo, host, and client behavior stay aligned.
