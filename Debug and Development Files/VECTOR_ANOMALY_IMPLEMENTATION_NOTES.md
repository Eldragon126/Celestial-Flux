# Vector Anomaly Implementation Notes

This pass completes the Campaign Mode overhaul as an inspector-editable layer on top of the existing Orbitron/Celestial Flux systems.

## Campaign Mode

- `CampaignModeDirector` now tracks an explicit campaign state machine: `INIT`, `PRE_WAVE`, `WAVE_ACTIVE`, `DIRECTIVE_ACTIVE`, `DOCKING`, `TRADE`, `POST_WAVE`, `CRISIS_CHOICE`, `VICTORY`, and `DEFEAT`.
- The wave directive cycle is editable in the inspector and includes the new AAA directive beats: `carrier_assault`, `siege`, `gravity_storm`, and `trade_window`.
- Fleet command is now runtime and inspector configurable. The command panel exposes `DEFEND`, `FOLLOW`, `ATTACK`, `RECOVER`, `REPAIR`, `PROTECT`, and `HOLD`; keyboard defaults are exported as keys 1-6.
- Campaign debug output is available through the exported `show_campaign_debug_overlay` toggle. It reports state, directive, objective, fleet command, invaders, escorts, credits, reputation, route progress, and active storm data.
- `CampaignEscortShip` now has editable roles: fighter, defender, interceptor, repair drone, gravity tug, shield drone, and bomber. Roles affect anchor selection, attack range, repairs, damage, color, and fleet command response.
- `CampaignInvader` now has editable campaign roles: planet breacher, interceptor, siege bomber, hijacker, carrier drone, salvage thief, shield breaker, fleet hunter, and gravity diver. Roles affect target priority, state selection, breach damage, rewards, and visuals.

## Optional Vector Anomaly Systems

- Optional challenge persistence is stored in `RunProgress` under `user://optional_challenge_progress.save`.
- New resources define anomaly rifts and style contracts.
- New runtime components implement no-thrust/one-dash hooks, personal gravity flip, ghost echo/time scar recording, anomaly shards, blackbox tapes, rift portals, momentum doors, vector tunnels, and secret movement tech detection.

## Inspector Surface

All new gameplay tuning is exported on the relevant script:

- Campaign state/debug/fleet command settings live on `CampaignModeDirector`.
- Escort role tuning lives on `CampaignEscortShip`.
- Invader role tuning lives on `CampaignInvader`.
- Rift rules live on `AnomalyRiftConfig`.
- Style contract rules live on `StyleContractConfig`.
- Optional pickups/doors/tunnels/portals each expose their radii, rewards, colors, thresholds, and behavior toggles.
