# VECTOR ANOMALY Asset And Audio Production List

This is the current production checklist for art, VFX, UI, music, and sound. It focuses on assets the game systems already need or will need soon, without requiring a redesign of the playable build.

## Priority Visual Assets

- Final Vector Anomaly logo, readable at Steam capsule size and in the title screen.
- Steam capsule set: small capsule, header capsule, main capsule, vertical capsule, library hero, and library logo.
- Key art showing the player slingshotting through a collapsing gravity field.
- CODEX Progress 2026-06-04: First-pass editable SVG logo, logo mark, Steam capsule set, library hero/logo, vector key-art layout, and generated no-text concept PNG are in `Assets/Brand/`.
- CODEX Completion 2026-06-06: The title screen now defaults to the generated Vector Anomaly logo texture while preserving a text fallback; capture-ready brand starter assets remain in `Assets/Brand/`.
- Press kit screenshots that clearly show player, gravity source, threat, trajectory, and recovery path.
- Trailer capture scenes for early clean vectors, mid-run resonance, late collapse, Rupture, and the music finale.
- CODEX Completion 2026-06-12: Clip Lab now includes number-key capture presets for early clean vectors, slingshot mastery, mid-run resonance, boss-rule mutation, late collapse, and music finale staging. Actual recording still requires a normal non-headless run.
- CODEX Completion 2026-06-13: Clip Lab now includes a seventh reduced-flash accessibility preset plus `F9` PNG capture and `F10` JSON capture-slate export to `user://marketing_captures`, so press stills and trailer slates can be produced from a normal run without headless Godot.
- Boss silhouette polish for Gravity Warden, Accretion Core, Null Vector Seraph, Magnetar Twins, Tidal Rift Weaver, The Polymorph, Centrifuge Marshal, and The Resonance Singularity.
- CODEX Completion 2026-06-12: Boss readability now has a shared silhouette-outline pass in `EnemyReadabilityDirector`, covering authored bosses and secret bosses without baking non-editable art into scenes.
- Resonance zone glyphs for compression, slipstream, inversion, temporal scar, and harmonic orbit.
- Edge indicator icons for gravity sources, enemies, bosses, rare events, and active co-op peers.
- Projectile ownership accents for player shots, enemy shots, boss shots, captured satellites, and resonance-bent projectiles.
- CODEX Progress 2026-06-06: In-game HUD indicators now include gravity/enemy/boss/rare-event arrows, and converted enemy projectiles switch to captured-player cyan ownership accents.

## Priority VFX Assets

- Swimming-through-spacetime overlay for high-speed slingshots, event horizon escapes, and finale collapse windows.
- Time dilation break effect with screen-edge refraction, stretched particles, and readable local pocket boundary.
- Glitch overlays for Rupture, law cracking, save-anchor reconstruction, and boss rule disruptions.
- Beam materials for future Positron/Plasma Beam, Gravity Wave Beam, Chronal Refraction Beam, and Relativistic Rail effects.
- Gravity scar visual set: curvature scar, compression tear, temporal wound, inversion rupture, and harmonic fracture.
- Permanent spacetime rip visual language for future persistent arena deformation.
- Planet type visuals for future differentiated gravity bodies.
- Space tear portal effect for future enemy emergence events.
- Reduced-flash variants for all high-energy bursts.
- CODEX Progress 2026-06-06: Time-dilation break and law-crack/Rupture glitch effects are hooked through capped director visuals.
- CODEX Completion 2026-06-13: Production visual upgrade pass added phase-aware player aura/contrails, sharper projectile wakes, pooled VFX burst rings, enemy profile halos, boss silhouette reinforcement, planet gravity/fracture rings, black-hole horizon/shear rings, and a low-alpha animated title lattice. All new bright world visuals route through existing `Settings` alpha/radius caps.

## UI And Menu Assets

- Final title-screen background loop.
- Multiplayer status UI polish for host/join, LAN address/port, peer roster, host-controlled restart, disconnect messages, and future Steam lobby state.
- Pause menu section accents for settings, modding, multiplayer prep, and future weapons.
- Game over glitch treatment for death vector readouts.
- HUD icons for energy, shield, slingshot grade, local field rule, chaos tier, and run arc phase.
- Weapon HUD slots for future gravity-energy weapons.
- Mod manifest status icons: loaded, failed, disabled, and future dependency warning.
- Modding editor/status visuals for law weaves, anomaly recipes, challenge cards, hook triggers, condition gates, effect actions, network categories, playable weapon profiles, local-only palettes, and locked script packs.
- CODEX Progress 2026-06-04: Simple SVG status icons created in `Assets/UI/Modding/`.
- CODEX Progress 2026-06-06: Game-over death vector text now has a subtle glitch treatment, and live HULL/SHIELD/ENERGY bars are integrated in OrbitalHUD.
- CODEX Completion 2026-06-06: Pause sections now receive runtime color/outline accents for settings, weapons, modding, and multiplayer, matching the production menu checklist without needing scene rewrites.
- CODEX Progress 2026-06-07: Modding docs and registry now define distinct visual/UI concepts for safe hookable mod content and playable weapon profiles; final editor art remains a future UI pass.
- CODEX Progress 2026-06-07: Safe hook runtime activation, LAN replay for player-triggered mod hooks, and the expanded weapon-pattern catalog are code-backed; final mod editor cards should now show live/recorded effect status, network category, and projectile pattern previews.

## Music Needed

- Title theme: cold, inviting, and precise.
- Early run layer: sterile vector drift with low rhythmic pressure.
- Mid run layer: orbital pulse and controlled tension.
- Late run layer: unstable calculations, higher density, readable rhythmic anchors.
- Rupture cue: law-cracking transition that feels dangerous but not random.
- Music finale composition: fixed structure where pulses, bursts, and collapse beats can drive The Resonance Singularity.
- Credits track: "Neon Starlight" as a calm non-hostile decompression state.
- Boss motifs for each authored boss rule, especially polarity, tide, null lanes, compression, and resonance.
- CODEX Completion 2026-06-06: Title, wave, boss, Rupture, music-finale, and credits music hooks are wired in code. Final mix/master approval remains a creative pass.

## Sound Effects Needed

- Player thrust, counter-thrust, dash, drift correction, and energy exhaustion.
- Slingshot grades: good, great, perfect, apex, and Apex Vector Core release.
- Kinetic impact, boss contact rebound, shield absorb, shield break, and near-miss charge.
- Resonance zone created, intensified, decayed, and merged.
- Zone-specific cues for compression, slipstream, inversion, temporal scar, and harmonic orbit.
- Time dilation started, ended, local pocket entered, pocket exited, and instability changed.
- Gravity scar created, intensified, applied to a body, and decayed.
- Arena event cues for tide pockets, volatile moons, nebula shear, wormholes, rare events, late-game overfolds, and collapse lanes.
- Boss rule telegraphs and attack releases for each boss.
- UI cues for pause open/close, settings changed, seed copied, mod rescan, game over, restart, and title return.
- CODEX Progress 2026-06-06: Existing mechanic audio hooks cover most listed events; selected raw thrust and low-energy assets were renamed to `sfx_thrust_vector_surge.mp3` and `sfx_energy_exhausted_low.mp3` and connected to thrust, shield pressure, energy depletion, and weapon energy failure.

## Marketing Capture Needs

- Three-second hook clip: player barely survives a high-speed gravity collapse.
- Slingshot mastery clip: visible trajectory, danger, perfect/apex recovery, and payoff.
- Boss-rule clip: one boss clearly mutating physics instead of spamming bullets.
- Rupture clip: waves offline, laws cracking, controlled instability.
- Finale clip: music beat causing a readable reality pulse.
- Accessibility/readability capture: late-game spectacle that still shows where the player and threats are.
- CODEX Prepared 2026-06-06: Shot and clip requirements are formalized in `Debug and Development Files/MARKETING_CAPTURE_MANIFEST.md`; actual media capture requires a normal non-headless run.
- CODEX Completion 2026-06-13: The Clip Lab preset map now covers the hook, mastery, resonance, boss-rule, Rupture, finale, and reduced-flash accessibility capture needs, with clean still capture and metadata export available during normal play.

## Implementation Notes

- Prefer editable scene nodes for recurring VFX: `Polygon2D`, `Line2D`, `GPUParticles2D`, `CanvasLayer`, and material resources.
- Every bright effect needs a reduced-flash path through `Settings.flash_alpha()` or equivalent alpha caps.
- Audio should bind to existing gameplay hooks instead of requiring a large global audio manager.
- Marketing assets should show real gameplay state, not abstract neon decoration.
