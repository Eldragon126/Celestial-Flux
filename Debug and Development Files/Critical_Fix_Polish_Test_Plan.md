# Vector Anomaly Critical Fix And Polish Pass

Date: 2026-06-24

This note documents the critical pass for loading stability, menu readability, campaign docking, projectile cleanup, mod visibility, and damage feedback. Godot was not launched during this pass because headless/editor startup is currently known to crash on this workspace.

## Loading And Scene Transition Stability

- `Scripts/run_loading_screen.gd` now has inspector-editable stall/timeout watchdog settings.
- Threaded loading can retry once, then safely falls back to `change_scene_to_file()` or returns to title with an error message instead of hanging forever.

Test:

- Start a normal run from title.
- Confirm progress no longer parks forever around 50%.
- Temporarily lower `loading_stall_timeout` in the inspector to verify the recovery message and fallback path.

## Title And Pause Menus

- `Scripts/title_screen.gd` moves alternate modes behind `Other Play Modes`, adds title settings, focuses a sensible first button, and reduces menu density to stop overlap with the Vector Anomaly title.
- `Nodes/title_screen.tscn` now includes scene-authored primary menu buttons for Mods, Other Play Modes, Settings, and Quit so layout can be adjusted in the editor.
- `Scripts/pause_menu.gd` and `Nodes/pause_menu.tscn` keep Resume, Restart, and Title actions near the top and focus Resume when pausing.
- Pause and title settings expose damage numbers, hit flashes, skill callouts, and combat particle settings through the existing `Settings` autoload.

Test:

- Open the title screen at desktop and Steam Deck-like resolutions and confirm no title/menu overlap.
- Use keyboard/controller to open Other Play Modes, back out, open Settings, and start Campaign.
- Pause during a run and confirm Resume is visible and focused immediately.

## Projectile Planet-Stacking Fix

- `Scripts/projectile.gd` and `Scripts/enemy_bullet.gd` now have inspector-editable projectile cleanup settings.
- Projectiles despawn on lifetime expiry, low-speed stalls, planet absorption, near-planet orbit decay, and excessive gravity deflections.
- Player projectile damage falls off after repeated major gravity direction changes, preserving gravity trick shots while stopping infinite planet stacks.

Test:

- In Campaign, fire repeatedly around the home planet and confirm bullets burn out or absorb instead of forming a permanent death ring.
- Verify normal gravity-influenced shots still curve and hit enemies.
- Watch projectile counts in the debug overlay during sustained firing.

## Damage Feedback And Combat Juice

- `Scripts/damage_indicator_manager.gd` and `Nodes/damage_indicator_manager.tscn` add pooled floating identifiers, impact rings, hit flashes, batching, and reduced-clutter modes.
- `Scripts/health_component.gd`, `Scripts/projectile.gd`, `Scripts/enemy_bullet.gd`, `Scripts/weapon_system.gd`, and `Scripts/momentum_combat_component.gd` stamp damage context so projectile, momentum, gravity, temporal, apex, slingshot, and final blows read differently.
- `Scripts/settings.gd` persists the new combat feedback accessibility controls.
- 2026-06-29 polish: damage feedback now exposes pool/frame/reaction/streak tuning in the inspector, clears consumed hit context after health application so stale weapon metadata cannot mislabel future hits, adds health-state transition callouts, directional impact streaks, bounded target flashes, and small optional recoil for major non-boss hits.

Test:

- Hit small enemies with normal shots and confirm readable numbers.
- Land a high-speed momentum impact and confirm KINETIC/APEX-style feedback appears when appropriate.
- Toggle Damage Numbers Off/Minimal/Full and Hit Flashes Reduced/Normal from title and pause.
- Repeatedly hit a mixed enemy pack and confirm feedback drops gracefully at budget caps instead of spawning unbounded labels/rings.

## Mod Visibility

- `Scripts/mod_content_registry.gd` now prints useful load/failure summaries behind an inspector `debug_logging` toggle.
- `Scripts/orbital_juice_manager.gd` installs `ModContentRegistry` before `OrbitalHUD` so the HUD can resolve mod state immediately.
- `Scripts/orbital_hud.gd` shows `VANILLA RUN` or `MODDED RUN // PACKS // HOOKS // CONTENT` and records modded run metadata in `RunProgress`.
- Official example manifests now include visible run-start hooks so Lawbreaker, Microverse, and Forge packs prove they are active.

Test:

- Open Mods, rescan, enable the official example packs, and start a run.
- Confirm the HUD reports a modded run and run-start badges/effects appear.
- Break a manifest JSON locally and confirm the Mods panel reports a useful failure.

## Campaign Mode And Trading

- `Scripts/campaign_mode_director.gd` moves campaign interactions into scene-authored HUD/trade panels and adds mothership spawning, docking prompts, trade actions, hostile alerts, and cleanup.
- `Scripts/campaign_mothership.gd` and `Nodes/campaign_mothership.tscn` provide inspector-editable friendly/trader/neutral/hostile motherships with dock rings, hull collision, health, faction colors, drift, and hostile projectile fire.
- `Nodes/campaign_mode.tscn` now includes editable `TradePanel` and `DockPromptLabel` nodes.
- `Scripts/campaign_invader.gd` adds tactical AI states, behavior profiles, ranged attacks, gravity slingshot repositioning, retreat behavior, and state-colored vectors.

Test:

- Start Campaign and verify HUD panels stay out of the combat center.
- Approach trader/friendly motherships and confirm the dock prompt appears.
- Dock, buy/upgrade, undock, and verify energy credits update.
- Approach hostile motherships and confirm they attack instead of opening trade.
- Fight several campaign invaders and verify pursuit, strafe/orbit, ranged fire, and retreat behaviors are visible.

## Website Updates

- `website/index.html`, `website/wiki/index.html`, and `website/modding/index.html` were updated to describe current campaign, modding, combat feedback, mothership/trade, and gravity roguelike identity.

Test:

- Open each static page in a browser and confirm the copy reflects Vector Anomaly, campaign freeholds, active mod proof, and Creator Lab language.

## Manual Polish Still Needed

- Final mothership, trade-interior, hostile faction, and campaign ship art should eventually replace the code-authored vector hulls.
- Combat feedback has pooled numbers/rings/flashes now, but dedicated SFX and shader/material variants for shield, armor, and boss section hits should be an art/audio pass.
- The loading watchdog should still be validated in a normal non-headless game run.

## 2026-07-01 Performance And AAA Polish Follow-Through

- `PerformanceBudgetDirector` now records bounded frame-spike black-box samples with wave, scene, projectile/enemy/gravity counts, active VFX bursts, quality tier, and trigger reason. Severe spikes can immediately force LOW presentation budgets without changing player movement, damage, seeds, or gravity truth.
- Budget application now reaches damage feedback, particle culling, mod hook connection passes, campaign UI cadence, heat-map contour/vector budgets, spacetime fabric cadence, and reality-collapse fabric cadence.
- `ParticleFocusCuller` no longer rescans the whole scene tree in one synchronous burst by default; scanning is incremental and capped by inspector-editable node/particle budgets.
- `GravityHeatMapOverlay` removes per-sample dictionary allocation, adds real contour/vector draw caps, and exposes the golden route sample count, contour width, and draw budgets in the inspector.
- `ModHookDirector` caps projectile signal connection work per reconnect pass so modded projectile-heavy runs do not create avoidable hitching.
- The debug balance overlay reports performance quality reason and spike count, making fallback behavior visible during normal tuning.

## 2026-07-02 Projectile Readability And Final Combat Polish

- Player and enemy projectiles now refresh cached nearest gravity sources on inspector-editable time/distance thresholds instead of using a single launch-time source list. This keeps gravity bending readable during long arcs without returning to per-frame group scans.
- Enemy projectiles now expose light, alpha-floor, focus-distance, pressure-cap, gravity-radius, and acceleration-cap tuning in the inspector. Their colors route through readability/reduced-flash settings while preserving a visible projectile alpha floor.
- `PerformanceBudgetDirector` now pushes projectile visual and gravity-refresh budgets into live projectile nodes, including projectile light caps under pressure.
- `parametric_enemy_3.gd` no longer has a placeholder health callback. It registers with `RuntimeRegistry`, exposes motion/visual/skill-ring tuning, and displays bounded health/dance feedback through readability-safe colors.

Test:

- Run a busy standard run and watch the debug overlay budget row; `S#` should increment only on meaningful hitches, and quality should fall to LOW during severe spikes.
- Toggle the gravity heat map with F10 and confirm it remains readable while contour/vector counts stay bounded.
- In a projectile-heavy or modded run, confirm frame spikes reduce instead of climbing as particles, projectile hooks, and damage feedback become dense.
- Fight parametric dance enemies and confirm the hit window, low-health state, skill-hit ring, and energy reward remain readable without flash spikes.
