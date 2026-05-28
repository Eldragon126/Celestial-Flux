# VECTOR ANOMALY — Enemy Drop System (Physics Residue Economy)

This document defines the enemy drop system inspired by “Window-like” systemic chaos, but adapted to Vector Anomaly’s grounded gravitational simulation.

Instead of traditional loot, enemies release **residual physical laws** when destroyed. These drops are temporary, interactable, and modify the physics sandbox of the arena.

---

# Core Design Philosophy

- Drops are not currency
- Drops are not items
- Drops are **broken fragments of local physics**
- Everything dropped should:
  - Alter movement, gravity, time, or orbit behavior
  - Be physically represented in the arena when possible
  - Interact with existing gravity systems

---

# DROP TYPES

## ☐ Vector Fragments
Directional momentum crystallized into physical shards.

- Stores a directional impulse when collected
- Can be consumed to:
  - Modify dash angle mid-execution
  - Redirect orbital tether trajectory
  - Inject burst velocity into orbit paths

Implementation notes:
- Represent as floating particles with velocity vectors
- Absorbed on contact with player hitbox
- Stackable “momentum charge” system

---

## ☐ Gravity Residue
Localized instability pockets left behind by destroyed entities.

- Creates small temporary gravity wells
- Can be placed or auto-triggered on pickup
- Variants:
  - ☐ Attraction Residue (pulls inward)
  - ☐ Repulsion Residue (pushes outward)
  - ☐ Orbit Residue (forces circular motion)

Implementation notes:
- Uses same system as gravity sources group: `Objects_With_Gravity`
- Has decay curve over time
- Radius scales with enemy difficulty tier

---

## ☐ Time Shards
Crystallized fragments of local temporal distortion.

- Creates localized slow/fast zones
- Can be:
  - Activated on demand
  - Automatically triggered on damage threshold

Use cases:
- Escape tool during swarm pressure
- Precision aiming windows
- Combo extension during orbital chains

Implementation notes:
- Prefer local velocity scaling over global time scaling
- Must respect existing Time Fracture upgrade family

---

## ☐ Orbit Cores
Rotational physics stabilizers and corruptors.

- Modifies orbital behavior around:
  - Player
  - Gravity sources
  - Enemy clusters

Effects:
- Invert orbit direction
- Lock orbit radius
- Introduce elliptical drift
- Create multi-orbit layering

Implementation notes:
- Interacts with Orbital upgrade family
- Can override current orbital constraints temporarily

---

## ☐ Fracture Dust
Unstable simulation residue from high-chaos entities.

- Increases “reality instability” meter
- Used to unlock:
  - Hidden enemy behaviors
  - Chaos modifiers
  - Stage fracture events

Effects at thresholds:
- Visual distortion increases
- Enemy AI becomes less predictable
- Gravity fields become partially recursive

Implementation notes:
- Acts as meta-progression currency for run escalation
- Tied to Option B Fracture Wave system

---

## ☐ Singularity Seeds (Rare Drop)
Compressed potential gravity collapse points.

- Can be deployed as micro black holes
- Pulls in:
  - Enemies
  - Projectiles
  - Some environmental particles

Advanced interactions:
- Can merge with Gravity Residue
- Can be upgraded into permanent field modifiers

Implementation notes:
- Must obey cap: max 1–2 active per arena
- Heavy performance constraint awareness required

---

# DROP SYSTEM RULES

## ☐ Drop Generation Rules
- Drops scale with enemy complexity tier
- Elite enemies guarantee at least one physics-altering drop
- Bosses may drop multi-type “composite residues”

---

## ☐ Pickup Behavior Rules
- Player contact = absorption (no UI interruption)
- Optional: magnetic pull scaling with Momentum upgrades
- Drops may interact before pickup (important for emergent chaos)

---

## ☐ Persistence Rules
- Most drops decay over time (soft urgency system)
- Some high-tier drops persist longer under Time Fracture effects
- Fracture Dust is permanent within a run

---

# SYSTEM INTEGRATION CHECKLIST

## ☐ Integration with Gravity System
- Drops must register as valid gravity sources when active
- Must obey `Objects_With_Gravity` constraints
- Cap influence per object respected (3–4 sources max)

## ☐ Integration with Upgrade Families
- Singularity: interacts with Gravity Residue + Seeds
- Momentum: interacts with Vector Fragments
- Repulsion: modifies Gravity Residue behavior
- Time Fracture: enhances Time Shards
- Orbital: modifies Orbit Cores behavior

## ☐ Performance Budgeting
- Limit active drop entities per frame
- Use pooling for all drop types
- Decay inactive drops aggressively during high chaos waves

---

# FUTURE EXPANSION (NOT IMPLEMENTED YET)

## ☐ Combo Drop Reactions
- Combining different drops creates emergent physics events
  - Example: Gravity Residue + Time Shard = “Temporal Sink”
  - Example: Orbit Core + Vector Fragment = “Helical Dash State”

## ☐ Enemy Identity Drops
- Certain enemies drop unique “behavior signatures”
- Unlocks adaptive counterplay mechanics

---

END OF FILE