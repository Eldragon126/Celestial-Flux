# VECTOR ANOMALY Asset And Audio Production List

This is the current production checklist for art, VFX, UI, music, and sound. It focuses on assets the game systems already need or will need soon, without requiring a redesign of the playable build.

## Priority Visual Assets

- Final Vector Anomaly logo, readable at Steam capsule size and in the title screen.
- Steam capsule set: small capsule, header capsule, main capsule, vertical capsule, library hero, and library logo.
- Key art showing the player slingshotting through a collapsing gravity field.
- Press kit screenshots that clearly show player, gravity source, threat, trajectory, and recovery path.
- Trailer capture scenes for early clean vectors, mid-run resonance, late collapse, Rupture, and the music finale.
- Boss silhouette polish for Gravity Warden, Accretion Core, Null Vector Seraph, Magnetar Twins, Tidal Rift Weaver, The Polymorph, Centrifuge Marshal, and The Resonance Singularity.
- Resonance zone glyphs for compression, slipstream, inversion, temporal scar, and harmonic orbit.
- Edge indicator icons for gravity sources, enemies, bosses, rare events, and future co-op peers.
- Projectile ownership accents for player shots, enemy shots, boss shots, captured satellites, and resonance-bent projectiles.

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

## UI And Menu Assets

- Final title-screen background loop.
- Pause menu section accents for settings, modding, multiplayer prep, and future weapons.
- Game over glitch treatment for death vector readouts.
- HUD icons for energy, shield, slingshot grade, local field rule, chaos tier, and run arc phase.
- Weapon HUD slots for future gravity-energy weapons.
- Mod manifest status icons: loaded, failed, disabled, and future dependency warning.

## Music Needed

- Title theme: cold, inviting, and precise.
- Early run layer: sterile vector drift with low rhythmic pressure.
- Mid run layer: orbital pulse and controlled tension.
- Late run layer: unstable calculations, higher density, readable rhythmic anchors.
- Rupture cue: law-cracking transition that feels dangerous but not random.
- Music finale composition: fixed structure where pulses, bursts, and collapse beats can drive The Resonance Singularity.
- Credits track: "Neon Starlight" as a calm non-hostile decompression state.
- Boss motifs for each authored boss rule, especially polarity, tide, null lanes, compression, and resonance.

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

## Marketing Capture Needs

- Three-second hook clip: player barely survives a high-speed gravity collapse.
- Slingshot mastery clip: visible trajectory, danger, perfect/apex recovery, and payoff.
- Boss-rule clip: one boss clearly mutating physics instead of spamming bullets.
- Rupture clip: waves offline, laws cracking, controlled instability.
- Finale clip: music beat causing a readable reality pulse.
- Accessibility/readability capture: late-game spectacle that still shows where the player and threats are.

## Implementation Notes

- Prefer editable scene nodes for recurring VFX: `Polygon2D`, `Line2D`, `GPUParticles2D`, `CanvasLayer`, and material resources.
- Every bright effect needs a reduced-flash path through `Settings.flash_alpha()` or equivalent alpha caps.
- Audio should bind to existing gameplay hooks instead of requiring a large global audio manager.
- Marketing assets should show real gameplay state, not abstract neon decoration.
