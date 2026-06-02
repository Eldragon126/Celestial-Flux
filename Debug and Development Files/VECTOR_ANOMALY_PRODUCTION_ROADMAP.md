# VECTOR ANOMALY: MASTER PRODUCTION ROADMAP & SHIP DIRECTIVE
*Document Status: VERSION 1.0 CRITICAL PATH (CONSOLIDATED)*
*Target Engine: Godot 4.4 Stable (GDScript 2.0)*
*Production Cycle: 8 Weeks*
*Development Model: Solo Developer*
*Primary Goal: Release A Polished, Stable, Highly Replayable Version 1.0*

---

# SECTION 1: EXECUTION RULES & ARCHITECTURAL SAFEGUARDS

When writing, refactoring, or evaluating code within this project, any AI Agent, Codex, Claude, Gemini, or automated development assistant must follow these rules:

1. **Strict Type Safety**
* All variables, parameters, return values, and class members must contain explicit type hints.
* Avoid Variant and untyped patterns whenever possible.

2. **Performance First**
* Dynamic allocations inside `_process()` and `_physics_process()` are prohibited.
* Use preallocated arrays, object pooling, and reusable buffers.
* Minimize garbage collection spikes.

3. **Engine-Native Workflow**
* Target Godot 4.4 Stable.
* Use modern Godot architecture.
* Use tabs for indentation.
* Keep UI systems separated from gameplay systems.
* Prefer composition over inheritance where practical.

4. **Simple Systems Beat Clever Systems**
* If two solutions produce similar gameplay results, choose the simpler implementation.
* Prioritize reliability, readability, maintainability, and performance.

5. **Release Takes Priority**
* Shipping the game is more important than adding new features.
* Any feature that threatens release stability may be delayed to Version 1.1.

---

# SECTION 2: CORE GAME PILLARS

Every feature must reinforce at least one of these pillars.

### Gravity Manipulation
Players alter movement, positioning, and combat through localized gravitational forces.

### Orbital Combat
Combat is built around trajectories, curves, momentum, and prediction rather than direct aiming alone.

### Time Dilation
Time manipulation creates opportunities for precision, survival, and advanced movement.

### Momentum Mastery
Skilled movement should consistently outperform raw statistics.

### Physics Spectacle
The game should generate memorable moments through emergent interactions.

---

# SECTION 3: VERSION 1.0 SHIP CRITICAL FEATURES

The game is considered launch-ready when these systems are complete.

### Core Gameplay
* [ ] Gravity combat functional
* [ ] Time dilation functional
* [ ] Endless survival mode functional
* [ ] Upgrade progression functional
* [ ] Difficulty scaling functional

### Content
* [ ] Minimum 10 enemy types
* [ ] Minimum 2 bosses
* [ ] Multiple gravity hazards
* [ ] Multiple upgrade paths

### Presentation
* [ ] Main menu complete
* [ ] HUD complete
* [ ] Death screen complete
* [ ] Audio complete
* [ ] Visual effects complete

### Technical
* [ ] Stable gameplay loop
* [ ] Major bugs resolved
* [ ] Acceptable performance achieved
* [ ] Settings menu complete

### Marketing
* [ ] Gameplay trailer
* [ ] Steam page assets
* [ ] Screenshots
* [ ] Demo build

Anything not listed above may be delayed without delaying release.

---

# SECTION 4: LAUNCH UPGRADE MATRIX

All upgrades should significantly alter gameplay behavior rather than simply increasing percentages.

### Micro-Lensing Emitter
[cite_start]Creates localized gravity lens points that bend trajectories in real time, allowing bullets, enemies, and debris to curve into controlled orbital paths shaped by player movement and positioning. [cite: 115]

### Vacuum Collapse Injector
[cite_start]Fires delayed space-defect charges that erase local momentum on impact, collapsing motion inward and reinitializing the area into unstable post-implosion orbit states. [cite: 116]

### Orbital Debris Seeder
[cite_start]Deploys persistent satellite fragments and wreckage that enter independent orbits around gravity sources, turning arenas into layered kinetic debris ecosystems that evolve over time. [cite: 118]

### Barycentric Tether
Links nearby enemies together through an artificial center of mass, forcing binary orbital motion.

### Frame-Dragging Anchor
Creates a rotational distortion field that drags nearby enemies into a spinning orbit.

### Relativistic Rail
[cite_start]Continuously accelerates fired masses toward relativistic velocity, causing visual time dilation effects like stretched trails, blue-shift distortion, and warped spatial impact zones. [cite: 117]

---

# SECTION 5: VERSION 1.1 / POST-LAUNCH BACKLOG

The following systems are approved but are not allowed to delay Version 1.0.

### Advanced Physics Upgrades
* [cite_start][ ] **Chronal Refraction Beam** — Offsets enemy and projectile timelines by fractional delays, creating desynchronized movement, phantom positions, and delayed collision chains that unfold after the fact. [cite: 119]
* [cite_start][ ] **Momentum Conservation Drift** — Breaks stable momentum rules so that impacts, slingshots, and collisions can partially amplify or mutate velocity instead of strictly conserving it, enabling high-skill momentum stacking. [cite: 120]
* [cite_start][ ] **Orbital Memory System** — Objects retain residual trajectory history, producing ghost-orbits that reappear and subtly influence future movement paths and projectile curvature. [cite: 121]
* [cite_start][ ] **Localized Time Debt** — Time manipulation becomes spatially linked. [cite: 122] [cite_start]Slowing one region accelerates another, forcing strategic creation of temporal pressure zones instead of global time control. [cite: 123]
* [cite_start][ ] **Gravitational Scar Formation** — High-energy movement permanently deforms local space, leaving persistent gravity distortions that reshape future trajectories and create evolving battlefield geometry. [cite: 124]
* [cite_start][ ] **Resonance Cascade System** — Matching frequency states across enemies, projectiles, and fields builds layered instability that can trigger chain-wide physical breakdowns when thresholds are exceeded. [cite: 125]
* [ ] Sling-Charged Singularity
* [ ] Tangential Vector Reversal

### Backlogged Enemy Designs
* [cite_start][ ] **Gravimetric Echo Drone** — A surveillance enemy that does not move independently but continuously replays recorded movement paths of nearby entities, creating dangerous afterimages of past runs that can collide with current physics and disrupt trajectory prediction systems. [cite: 126]
* [cite_start][ ] **Event Horizon Warden** — A slow, massive entity that anchors itself to a point in space and expands a localized collapse field over time, pulling all motion, projectiles, and gravity interactions toward its boundary where escape becomes increasingly momentum-dependent. [cite: 127]
* [cite_start][ ] **Phase-Slip Swarm** — A cluster-based enemy type that exists slightly out of sync with real space, causing it to intermittently appear in multiple positions along short time offsets, making interception require prediction of temporal jitter rather than raw aim. [cite: 128]
* [cite_start][ ] **Orbital Null Harvester** — An enemy that absorbs nearby orbital debris, gravity scars, and projectile curvature fields, converting environmental instability into adaptive shielding and temporarily cleaning chaotic battlefield structures around itself. [cite: 129]
* [cite_start][ ] **Resonance Paralytic Construct** — A geometric enemy that emits frequency fields disrupting player and projectile motion resonance. [cite: 130] [cite_start]Matching its frequency incorrectly causes temporary loss of control over momentum, while correct alignment can destabilize it into self-collapsing feedback loops. [cite: 131]

### Long-Term Systems
* [ ] Modding support
* [ ] Co-op support
* [ ] Daily challenges
* [ ] Community events
* [cite_start][ ] Score board that makes players come back for more every time. [cite: 164]

---

# SECTION 6: UI, VISUAL IDENTITY & ENDGAME VISION

[cite_start]The UI in Vector Anomaly should feel like an extension of the game’s physics rather than a traditional overlay sitting on top of the action. [cite: 98]

### Dynamic HUD & Visual Rules
* [cite_start][ ] Instead of static bars and rigid menus, the interface should orbit, drift, and subtly react to gravity, motion, and time dilation. [cite: 99]
* [cite_start][ ] Early in the game, the HUD can appear minimal and clinical: thin white vector lines, radial indicators, circular shield rings, and sparse typography against deep black space. [cite: 100]
* [cite_start][ ] Information should feel mathematically constructed, almost like a scientific instrument panel designed to monitor unstable spacetime rather than a standard arcade HUD. [cite: 101]
* [cite_start][ ] Health, energy, and cooldowns can be represented through rotating arcs, orbital rings, and waveform-like pulses that naturally reinforce the game’s core mechanics. [cite: 102]
* [cite_start][ ] As gameplay intensifies, the UI should evolve alongside the growing instability of the arena. [cite: 103]
* [cite_start][ ] Small glitches, temporal echoes, distorted cooldown rings, and fractured geometric overlays can emerge as chaos increases, making the player feel as though reality itself is becoming less stable. [cite: 104]
* [cite_start][ ] The gradual transition from monochrome visuals into neon cyan, magenta, and high-energy vector colors helps visually communicate the escalation of danger and dimensional collapse. [cite: 105]
* [cite_start][ ] Time dilation effects should also influence the interface directly, causing animations to smear, stretch, or desynchronize slightly whenever spacetime manipulation occurs. [cite: 106]
* [cite_start][ ] Menus and upgrade screens should resemble scientific anomaly maps, orbital schematics, or constellation-like networks rather than conventional menu grids. [cite: 108]
* [cite_start][ ] Upgrade paths can branch outward like gravitational systems, reinforcing the idea that the player is rewriting the rules of motion and physics instead of simply selecting perks. [cite: 109]
* [cite_start][ ] Death screens should present the player’s defeat as a diagnostic event or failed trajectory analysis, displaying fractured telemetry and “DEATH VECTOR” reports. [cite: 110]
* [cite_start][ ] Update the color palette of the game so that it follows a clear pattern. [cite: 162] [cite_start]Ensure yellow enemies and non-compliant colors are adjusted. [cite: 163]
* [cite_start][ ] Implement spaghettification visuals in certain cases between planets and entering black holes. [cite: 158]
* [cite_start][ ] Upgrade black hole visuals, make different planets and planet types. [cite: 159]

### The "Neon Starlight" Sequence & Endgame Design
* [cite_start]The game is intentionally designed so that success depends entirely on understanding physical relationships within the arena. [cite: 196]
* [cite_start]As progression continues, the structure shifts from loosely varied waves into a more deliberate arc of fixed boss encounters. [cite: 197]
* [cite_start]After the final boss sequence, the game transitions into a dedicated endgame rupture state, where normal wave structure and enemy progression cease. [cite: 205]
* [cite_start]The arena enters a highly unstable but controlled simulation mode where familiar rules begin to behave inconsistently. [cite: 206]
* [cite_start]At the peak of this rupture state, the game shifts into a final encounter where the underlying structure of the simulation is no longer purely physics-driven. [cite: 209]
* [cite_start]Combat becomes synchronized to a fixed composition, where discrete audio events correspond directly to major gameplay actions such as attacks, movement bursts, gravity pulses, and environmental shifts. [cite: 211]
* [cite_start]Following the completion of this final encounter, all gameplay systems fully disengage and the game transitions into a dedicated credits sequence. [cite: 213]
* [cite_start]Neon Starlight plays in full as the final emotional resolution, with no gameplay systems interacting with it. [cite: 215]

### Save States & Pause Architecture
* [cite_start]Saving and loading exists purely as a progress anchor, not a simulation snapshot. [cite: 220]
* [cite_start]The game does not attempt to preserve live physics states like active gravity fields, enemy positions, or in-progress interactions. [cite: 221]
* [cite_start]The pause menu exists as a complete interruption of gameplay processing, freezing simulation systems while preserving UI responsiveness. [cite: 224]
* [cite_start]Physics, enemy AI, and gravity calculations are halted during pause, while menu nodes remain active for navigation and configuration. [cite: 225]

---

# SECTION 7: FAR FUTURE GALAXY EXPANSION SYSTEM
*Do not begin work on this phase until post-launch milestones are complete.*

### Core Expansion Rules
* [cite_start][ ] Keep the primary gameplay loop focused on wave-based arena survival. [cite: 166]
* [cite_start][ ] Allow galaxy travel between wave runs or after survival milestones. [cite: 167]
* [cite_start][ ] Preserve short-to-medium run pacing (15–25 minutes). [cite: 168]

### Starmap Generation
* [cite_start][ ] Generate a procedural starmap containing distant galaxies. [cite: 169]
* [cite_start][ ] Create scalable travel distances where distant regions require survival preparation. [cite: 170]
* [cite_start][ ] Add travel routes with environmental hazards (gravitational storms, collapsing pathways). [cite: 171]

### Gameplay Mutation System
* [cite_start][ ] Implement galaxy-wide gameplay modifiers modifying combat, movement, time dilation, and gravity. [cite: 172]
* [cite_start][ ] Create escalating instability based on distance from origin space. [cite: 173]
* [cite_start][ ] Add galaxies that change arena combat structure (orbit-based combat, fragmented geometry, zero-friction). [cite: 174]

### Dynamic Enemy & Boss Scaling
* [cite_start][ ] Create galaxy-specific enemy variants driven by local physics laws. [cite: 176]
* [cite_start][ ] Modify wave generation based on galaxy state. [cite: 177]
* [cite_start][ ] Add region-exclusive bosses that utilize local reality distortions. [cite: 178]

### Reality-Altering Upgrades
* [cite_start][ ] Allow upgrades to mutate based on galaxy conditions. [cite: 182]
* [cite_start][ ] Add reality-altering upgrade interactions that become powerful in unstable zones. [cite: 183]

### Technical Considerations
* [cite_start][ ] Stream galaxy data efficiently without loading all systems simultaneously. [cite: 188]
* [cite_start][ ] Cache procedural generation results where possible. [cite: 190]
* [cite_start][ ] Limit active physics complexity to maintain performance during high-chaos deep-space encounters. [cite: 189]

---

# SECTION 8: PERFORMANCE TARGETS

These are mandatory targets.

### Frame Rate
* [ ] 60 FPS minimum
* [ ] 120 FPS preferred

### CPU Budget
* [ ] Physics under 4 ms
* [ ] Gameplay logic under 4 ms

### GPU Budget
* [ ] Rendering under 4 ms

### Entity Budgets
* [ ] 300+ active enemies
* [ ] 1000+ active projectiles
* [ ] Stable during maximum chaos moments

### Memory
* [ ] No excessive allocations during combat
* [ ] No noticeable GC spikes

---

# SECTION 9: PRODUCTION TIMELINE

### PHASE 1: STABILIZATION (WEEK 1-2)
* [ ] Profile CPU/GPU usage, eliminate excessive allocations, implement object pooling.
* [ ] Remove Orbitron and Vectorfall references, consolidate project branding.
* [ ] Setup headless simulation testing and performance monitoring tools.

### PHASE 2: GAMEPLAY POLISH (WEEK 3-4)
* [ ] Upgrade, enemy, and boss balance passes.
* [ ] Improve visual clarity, hit feedback, danger indicators, and combat readability.
* [ ] Improve onboarding, menu flow, and death flow.

### PHASE 3: CONTENT LOCK (WEEK 5)
* [ ] Finalize launch enemies, bosses, upgrades, and progression.
* [ ] Content Freeze: No new major mechanics may be added after this phase.

### PHASE 4: PRESENTATION (WEEK 6)
* [ ] Polish spacetime distortion shaders, time dilation effects, gravity field effects, and explosions.
* [ ] Polish HUD, upgrade menu, death screen, and telemetry.
* [ ] Integrate music, mix pass, and sound effects pass.

### PHASE 5: MARKETING (WEEK 7)
* [ ] Prepare Steam page, capsule art, screenshots, and description copy.
* [ ] Create trailer, gameplay clips, and promotional footage.
* [ ] Prepare Demo build and handle external feedback/bug reports.

### PHASE 6: RELEASE CANDIDATE (WEEK 8)
* [ ] Full game pass, stability testing, and performance testing.
* [ ] Fix critical/major bugs and launch blockers.
* [ ] Launch Vector Anomaly.

---

# SECTION 10: DEVELOPMENT PHILOSOPHY

Vector Anomaly succeeds by delivering a polished, performant, physics-driven experience built around gravity manipulation, orbital movement, and emergent interactions.

Version 1.0 is not intended to contain every planned feature.

Version 1.0 exists to establish the game's identity, build a player base, gather feedback, and create a foundation for future expansion.

Release is a milestone, not the end of development.