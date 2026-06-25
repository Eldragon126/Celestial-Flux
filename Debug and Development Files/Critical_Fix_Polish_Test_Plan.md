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

Test:

- Hit small enemies with normal shots and confirm readable numbers.
- Land a high-speed momentum impact and confirm KINETIC/APEX-style feedback appears when appropriate.
- Toggle Damage Numbers Off/Minimal/Full and Hit Flashes Reduced/Normal from title and pause.

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
