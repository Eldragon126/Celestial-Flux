# VECTOR ANOMALY - Enemy Drop System (Physics Residue Economy)

This document defines the implemented enemy drop economy for Vector Anomaly. Drops are not generic loot. They are readable fragments of broken physics that create movement, gravity, time, momentum, or reality-collapse decisions inside the arena.

## Core Design Philosophy

- Drops are not gold, ammo, crafting filler, or health spam.
- Drops should alter movement, gravity, time, orbit behavior, instability, or rule state.
- Drops should be physically represented in the arena when possible.
- Drops must respect the same gravity-source performance language as the rest of the game.
- Drops should create mastery opportunities, not menu interruptions.

## Runtime Owner

`PhysicsDropSystem` is installed by `OrbitalJuiceManager` as `PhysicsDropSystem`.

`WaveDirector` already tracks spawned enemies through their `HealthComponent.died` signal for wave completion and energy droplets. That same death path calls:

`PhysicsDropSystem.try_spawn_for_enemy(enemy, death_position, is_boss)`

This keeps drops signal-driven and avoids polling enemy state.

## Implemented Drop Types

### Fragments

Baseline upgrade/run currency represented as physical shards.

- Common from standard enemies.
- Stored on player metadata as `vector_fragments`.
- Mirrored into `RunProgress.arena_flags["vector_fragments"]`.
- Intended for future upgrade/shop routing, not immediate stat spam.

### Momentum Orbs

Temporary velocity amplifiers for slingshot play.

- Occasional common/uncommon drop.
- Adds capped velocity through `CombatStatus.add_velocity()`.
- Uses the player's current velocity direction when possible.
- Creates routing opportunities for apex slingshots, escapes, and kinetic kills.

### Gravity Residue

Temporary field residue left by destroyed enemies.

- Uncommon drop after early waves.
- Registers as `Objects_With_Gravity` / `planets` while active when configured as residue.
- On pickup creates a compression resonance zone through `GravityResonanceManager`.
- Designed to bend movement and enemy/projectile paths rather than act as a passive stat.

### Temporal Charges

Crystallized time-dilation fuel.

- Uncommon drop after early waves.
- Calls `TimeDilationManager.add_near_miss_charge()` when available.
- Supports skill windows without relying on global time slowdown as a reward.

### Instability Shards

High-risk escalation rewards.

- Rare drop in later waves or from elite pressure.
- Raises `ArenaDestabilizationManager.instability`.
- High-rarity shards can force a contained `RealityCollapseDirector` breach when that director is active.
- Records `RunProgress.arena_flags["instability_shards"]`.
- The player trades more reality-collapse pressure for greater reward potential.

### Anomaly Seeds

Compressed emergent event triggers.

- Rare drop in later waves and guaranteed as a boss bonus.
- Can route into `ArenaInstabilityDirector`, `CelestialBodyDirector`, or `RealityCollapseDirector` when those directors are active.
- Falls back to `ArenaDestabilizationManager.force_arena_event()` for deterministic arena events.
- Falls back to a manual slipstream resonance zone if the arena event API is unavailable.
- Can spawn wormhole/resonance/slipstream-style opportunities through existing systems.

### Celestial Cores

Boss-grade rule-changing drops.

- Bosses drop a unique core payload.
- Applies a `PowerupDefinition` through `PowerupInventory`.
- Triggers a celestial event when `CelestialBodyDirector` is available.
- Current boss core routing chooses from existing law-defining powers such as Apex Vector Core, Barycentric Tether, Frame-Dragging Anchor, or Singularity Amplifier.
- These should change how the run plays, not provide small percentage stat bumps.

## Energy Droplets

Energy droplets remain a separate combat sustain layer:

- Spawned through `PowerupLibrary.try_spawn_energy_droplets()`.
- Called from `WaveDirector` enemy death tracking.
- Restore `EnergyComponent` on pickup.
- Magnetize only near the player.
- Disable long-lived particles outside focus range.

Energy droplets are intentionally simple because they support basic combat rhythm. The physics drop ecosystem is where mastery and rule-change decisions live.

## Drop Generation Rules

- Standard enemies: Fragments, occasional Momentum Orbs.
- Uncommon/deeper wave enemies: Gravity Residue and Temporal Charges.
- Rare/elite pressure: Instability Shards and Anomaly Seeds.
- Bosses: guaranteed Celestial Core plus Anomaly Seed.
- Elite enemies bias optional drop chances upward by health/difficulty metadata.
- Active drops are capped by `PhysicsDropSystem.max_active_drops`.

## Pickup Behavior Rules

- Player contact absorbs the drop.
- No pickup UI interrupts combat.
- Drops move with launch impulse, mild drag, gravity sampling, and close-range magnetism.
- Gravity sampling uses a capped source list and interval refresh to avoid allocation churn.
- Visuals use readable glyph/ring/color language rather than inventory icons.

## Integration Checklist

### Gravity

- Gravity Residue can register as `Objects_With_Gravity`.
- Drops sample capped nearby gravity sources.
- Celestial body and arena directors remain responsible for heavy gravitational changes.

### Momentum

- Momentum Orbs amplify player velocity without breaking speed caps.
- Fragments are reserved for future vector/momentum upgrade routing.

### Time

- Temporal Charges feed time-dilation capacity.
- Recovery windows and time pockets use `TimeDilationManager` local slow APIs.

### Instability And Reality Collapse

- Instability Shards raise arena instability.
- Anomaly Seeds trigger deterministic physics events.
- These can push late runs toward `RealityCollapseDirector` pressure.

### Boss Rewards

- Celestial Cores apply rule-defining powerups.
- Boss rewards should feel like the simulation handing the player a dangerous new law.

## Performance Rules

- No per-frame enemy polling.
- Drops self-expire.
- Active drop count is capped and trimmed.
- Collection and expiry emit system-level telemetry and per-type counters in `RunProgress.arena_flags`.
- Gravity source sampling is interval-based and capped.
- Long-lived particle visuals are focus-gated by local pickup logic and the global `ParticleFocusCuller`.

## Future Expansion

- Combo reactions between active drops, such as Gravity Residue plus Temporal Charge becoming a Temporal Sink.
- Enemy identity drops that encode behavior signatures.
- Player-facing fragment spend paths that alter momentum routing rather than flat stats.
- Celestial Core variants that temporarily make the player a mobile gravity source, convert velocity to weapon damage, create persistent orbit fields, or rewrite local spacetime behavior.

END OF FILE
