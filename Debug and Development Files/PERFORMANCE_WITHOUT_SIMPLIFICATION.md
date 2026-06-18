# Vector Anomaly: Performance Without Losing the Game

The goal is to reduce how often expensive truth is recomputed, not reduce how much physics the player can create. A gravity source can remain mechanically real while its visuals, target discovery, and distant AI update at different rates.

## Highest-return ideas

1. **One shared pressure governor.** Give every expensive director the same CPU, GPU, projectile, gravity-source, and transparency budgets. Preserve player, boss telegraphs, lethal shots, and the nearest three gravity sources first; defer decorative trails and distant reactions.
2. **Temporal coherency for gravity.** Reuse the previous nearest-source set until the body moves far enough or a source enters/leaves the registry. Most frames do not require a new nearest-neighbor search.
3. **Event-driven field membership.** Zones should maintain enter/exit target sets through bounded area events or registry cells. Do not rediscover every target on every field tick.
4. **Multi-rate simulation.** Player, bosses, lethal projectiles, and close threats run at full rate. Distant enemies update intent at 10-20 Hz and interpolate motion. Visual-only systems can run at 8-15 Hz without changing collision truth.
5. **Shared analytic gravity fields.** A wave of many mass points should expose one analytic field sampler plus one draw call. Keep the visible complexity without registering dozens of independent sources.
6. **Projectile data path.** Move ordinary bullets toward pooled, data-oriented simulation with batched transforms. Reserve full `RigidBody2D` behavior for projectiles whose collisions or gravity interactions actually need it.
7. **Transparent-overdraw budget.** Count screen coverage, not just particle count. A few full-screen translucent rings can cost more than many tiny particles.
8. **Staggered births and deaths.** Prewarm scenes and materials before waves, then distribute spawn setup, shader warmup, and cleanup across frames. No wave transition should perform an unbounded batch.
9. **Deterministic degradation.** Quality fallback should change sampling cadence, trail density, and decorative layers. It must not change damage, gravity, enemy intent, seeds, or the player's trajectory.
10. **Release telemetry capture.** Keep a rolling buffer of long frames with wave, active systems, spawn/despawn counts, physics bodies, draw calls, and memory delta. Export the buffer after a crash or game over instead of formatting debug UI every frame.

## Implemented in this pass

- Orbiting celestial events now default off and only enter the event pool when enabled.
- Early waves delay layered procedural hazards; Gravity Wave Maker begins at wave 8 and Pulsating Gravity Spawner at wave 6.
- Waves 1-4 use explicit readable rosters rather than combining parametric, phase-slip, support, and authored-field systems immediately.
- Black-hole spaghettification no longer rebuilds live physics shapes through non-uniform body scaling.

## Profiler experiments for a normal run

- Compare wave 4 with and without the old hazard stack; record worst frame, physics time, and object count.
- Compare gravity-source cache hit rate against full nearest-source refreshes.
- Measure transparent pixels for resonance, scars, projectile trails, and fullscreen overlays separately.
- Record main-thread stalls when the first instance of every enemy, projectile, shader, and audio stream appears.
- Run the same seed at fixed camera positions across LOW, MEDIUM, and HIGH to ensure only presentation changes.

## Non-negotiable preservation order

1. Player input and movement physics.
2. Lethal collision and enemy intent.
3. Boss and hazard telegraphs.
4. Player projectile visibility and trajectory forecast.
5. The nearest meaningful gravity fields.
6. Audio timing cues.
7. Decorative particles, secondary rings, long trails, and distant ambience.

This is the useful kind of simplification: fewer redundant calculations, not a smaller universe.
