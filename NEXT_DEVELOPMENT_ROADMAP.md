# ORBITRON: VECTORFALL - Next Development Roadmap

This roadmap starts after the debug overlay, momentum combat, arena destabilization,
resonance manager integration, and physics-aware enemy director are in place.

## 1. Runtime Hardening

- Run the main scene and fix any parse/runtime errors from the new additive systems.
- Tune exported values while the debug overlay is visible: velocity, resonance zones, chaos level, enemy AI profiles, FPS.
- Stress-test waves with many projectiles, overlapping gravity sources, and active tide pockets.
- Verify that every death still feels geometry-readable rather than unfair.

## 2. Resonance Gameplay Expansion

- Promote resonance zones from telemetry into tactical arena rules.
- Add explicit zone types: compression, slipstream, inversion, temporal scar, harmonic orbit.
- Let `GravityResonanceManager` emit zone type/intensity data for VFX, HUD lensing, and audio hooks.
- Add simple visual language for zone identity before adding spectacle.

## 3. Advanced Time Dilation

- Connect near-miss charge from `MomentumCombatComponent` into `TimeDilationManager`.
- Add localized time pockets as arena events.
- Preserve player momentum during dilation while scaling enemies/projectiles differently.
- Emit clean audio/VFX signals: dilation started, dilation ended, local pocket entered, time tear intensity changed.

## 4. Law-Modifying Upgrades

- Replace generic upgrade tuning with rules that change combat geometry.
- First candidates:
  - Momentum: high-speed impacts create small shockwaves.
  - Orbital: captured projectiles become temporary satellites.
  - Singularity: dead enemies leave short-lived gravity debris.
  - Time Fracture: acceleration stores during slow time and releases afterward.
- Add upgrade fusion hooks only after each base law works alone.

## 5. Boss Physics Rule Pass

- Give each boss one readable physics rule mutation instead of raw attack spam.
- Gravity Warden: resonance field control.
- Accretion Core: debris compression and collision pressure.
- Null Vector Seraph: local ability/time disruption lanes.
- Magnetar Twins: synchronized push/pull polarity windows.
- Tidal Rift Weaver: rotating rift lanes that interact with tide pockets.

## 6. Visual Readability And Performance

- Add quality toggles for resonance visuals, tide particles, afterimages, and distortion overlays.
- Pool or cap any repeated VFX spawned during combat.
- Make late-game spectacle scale from readable vector minimalism into controlled neon collapse.
- Keep the overlay visible while tuning; FPS and local gravity intensity are the truth serum.

## 7. Audio Hook Handoff

- Do not build an invasive audio manager yet.
- Emit lightweight signals and intensity values from physics systems:
  - resonance zone created/intensified/decayed
  - chaos level changed
  - kinetic overload started/ended
  - tide pocket activated/expired
  - time dilation started/ended
- Let manual sound design bind to those hooks.

## Next Best Single Step

Start with `Runtime Hardening`, then turn resonance zones into typed gameplay spaces.
That is the cleanest bridge from "systems exist" to "the arena has a gravitational personality."
