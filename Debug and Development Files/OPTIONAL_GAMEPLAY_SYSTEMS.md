# Optional Gameplay Systems

These systems support the Vector Anomaly optional challenge layer without changing the default global gravity contract.

## Rifts

`OptionalChallengeDirector` manages rift entry, retry, clear, failure, style-contract selection, shard collection, blackbox collection, and progress lookup. Default rifts include:

- `no_thrust_rift`
- `one_dash_rift`
- `inverted_orbit_rift`
- `personal_gravity_flip_rift`
- `time_scar_rift`

## Player Rule Hooks

`player.gd` emits `dash_used` and `thrust_used` and honors these metadata flags:

- `anomaly_no_thrust`
- `anomaly_one_dash_only`
- `anomaly_dash_used`
- `anomaly_rift_active`

## Components

- `PersonalGravityFlipComponent` adds per-player polarity/orbit/anchor/axis gravity manipulation.
- `StyleContractTracker` validates optional contracts such as no dash, no thrust, glass, speed, perfect orbit, pacifist, and clean vector.
- `AnomalyGhostEcho` records time-scar and blackbox ghost routes.
- `AnomalyShard` and `BlackboxTape` persist optional collectibles.
- `AnomalyRiftPortal` launches or enters configured rifts.
- `MomentumDoor` opens only when the player enters with the configured speed and direction.
- `VectorTunnel` applies a local directional acceleration field to overlapping players.
- `SecretMovementTechDetector` records high-skill discoveries such as needle orbit, velocity scream, and silent slingshot.
