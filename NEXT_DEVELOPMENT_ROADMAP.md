# ORBITRON: VECTORFALL - Next Development Roadmap

This roadmap starts after the debug overlay, momentum combat, arena destabilization,
resonance manager integration, and physics-aware enemy director are in place.

## Current Status - May 15, 2026

Runtime hardening and the first major "arena has a gravitational personality"
pass are now implemented.

Completed this pass:

- The native Godot crash was isolated to the Rapier/GDExtension startup path.
  The project now uses GodotPhysics2D, and the Rapier `.gdextension` manifest is
  disabled until a compatible build is intentionally restored.
- Godot 4.6.2 editor import/parsing completes without script parse errors.
- `res://Nodes/the_abyss.tscn` launches headless and survives the runtime smoke
  window without script errors.
- A longer wave stress run with the additive systems active exits cleanly. The
  only remaining log noise is forced-quit resource/ObjectDB cleanup from the
  headless timeout, not gameplay script failure.
- `GravityResonanceManager` now classifies zones as compression, slipstream,
  inversion, temporal scar, or harmonic orbit.
- Resonance zones now emit richer zone data for HUD, VFX, and audio binding:
  type, display name, intensity, radius, and color.
- Resonance zones now apply readable tactical field rules to projectiles,
  enemies, bosses, and the player with capped body counts for performance.
- Simple zone identity visuals are in place with quality controls and capped
  particles.
- Momentum near-misses now feed `TimeDilationManager` capacity through
  `OrbitalJuiceManager`.
- Time dilation now favors local enemy/projectile scaling while preserving
  player momentum by default.
- Temporal tide pockets can appear as arena events and emit local pocket/time
  tear hooks.
- Momentum, Orbital, Singularity, and Time Fracture upgrades now have first-pass
  law-modifying behavior: shockwaves, projectile satellites, gravity debris, and
  stored acceleration release.
- The first boss physics rule pass is in: resonance field control, debris
  compression, disruption lanes, polarity windows, and rift/tide interaction.
- Runtime safety fixes landed for velocity mutation, local slow metadata, freed
  target checks, and noisy momentum debug output.

Known follow-up:

- Re-enable Rapier only after installing or building a Godot 4.6.2-compatible
  GDExtension. Until then, keep GodotPhysics2D as the stable runtime backend.
- Manual desktop playtesting is still needed for exact fairness tuning: zone
  force strengths, shockwave radius, satellite capture rate, debris lifetime,
  boss readability, pickup economy, and late-wave FPS.

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

Run a real desktop playtest loop with the debug overlay visible and tune the new
rules until the arena feels dangerous, legible, and a little unfair in the fun
way instead of the cheap way.

Priority tuning order:

- Resonance readability: verify each zone type has a clear silhouette before
  particle density or distortion increases.
- Death fairness: every kill should point back to a visible vector rule, tide
  pocket, boss lane, projectile orbit, or resonance field.
- Upgrade feel: tune shockwave thresholds, satellite capture duration, gravity
  debris lifetime, and Time Fracture release caps so each law is obvious within
  one pickup.
- Boss identity: make each boss mutation readable before increasing projectile
  count.
- Performance: keep late-wave FPS stable by lowering visual quality caps before
  reducing gameplay pressure.

After this tuning pass, the next feature step should be upgrade fusion:

- Momentum + Singularity: shockwaves bend debris fields outward.
- Orbital + Time Fracture: released acceleration flings satellites in clean arcs.
- Singularity + Orbital: gravity debris can briefly catch converted projectiles.
- Resonance + Time: temporal scars strengthen local slow pockets.

## Other things

Make everything beautiful. Gradients are a good way to do this. Think shading to the max, cool colors, and make everything flashy. Don't be afraid to go all out on particle effects as longs as they don't bog down the CPU.

Make sure everything works correctly.

Debug and Optimize code.

Keep pushing toward gravitational personality first: readable rules, then beauty,
then escalation. The game gets most fun when players can see the law bending
before the spectacle blooms.
