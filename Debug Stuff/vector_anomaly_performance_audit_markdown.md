# Vector Anomaly Performance Audit

## Current State

Telemetry indicates:

- FPS baseline around 24 FPS
- Massive worst-frame spike (~13941ms)
- Performance budget fallback mode activating
- Arena systems already entering LOW mode early
- Multiple real-time simulation systems running simultaneously:
  - Gravity
  - Orbit AI
  - Time dilation
  - Projectile systems
  - VFX systems
  - Telemetry/debug systems

---

# Primary Issues

## 1. Catastrophic Frame Spikes

### Symptoms
- Multi-second freezes
- Simulation hitching
- Worst frame recorded at ~13.9 seconds

### Things To Investigate
- Wave transition logic
- Scene loading/reloading
- Physics state rebuilding
- GDExtension stalls (Rapier)
- Massive allocation spikes
- Array resizing during combat
- Enemy spawn bursts
- Debug logging spam
- Expensive string formatting every frame
- Resource loading during gameplay
- Shader compilation hitching

### Potential Fixes
- Preload all combat assets
- Use object pooling everywhere possible
- Cache expensive calculations
- Disable runtime loading during waves
- Log long frames (>100ms)
- Convert burst operations into staggered operations
- Move noncritical systems to timers instead of `_process`

---

# Budgeting & Optimization Targets

## FPS Targets

| State | Target |
|---|---|
| Empty arena | 120+ FPS |
| Normal gameplay | 60 FPS |
| Heavy chaos moments | 45+ FPS |
| Worst case | Never below 30 FPS |

---

# System-by-System Performance Review

## 2. Gravity System

### Risks
- Full world scans every frame
- Too many gravity interactions
- Expensive vector math loops
- Recalculating nearest sources continuously

### Things To Look Into
- Limit gravity influences to 3-4 nearest sources
- Cache nearby gravity bodies
- Use spatial partitioning
- Avoid repeated `get_nodes_in_group()` calls
- Update influence lists less frequently
- Reduce force recalculations

### Budget Goals
- Gravity calculations under 1ms/frame
- No per-frame global scans

---

## 3. Enemy AI

### Risks
- AI updating every frame
- Orbit calculations running continuously
- Too many steering calculations
- Pathfinding spikes

### Things To Look Into
- Lower AI tick rate
- Update AI every 0.1-0.25 seconds
- Cache orbit solutions
- Simplify distant enemy behavior
- Disable unnecessary calculations offscreen
- Reduce prediction complexity

### Budget Goals
- AI under 2ms/frame
- Stable scaling with enemy count

---

## 4. Projectile Systems

### Risks
- Too many active bullets/projectiles
- Per-projectile allocations
- Collision overload
- Trail rendering cost

### Things To Look Into
- Object pooling
- Projectile caps
- Simplified collision checks
- Reduced trail update frequency
- Shared projectile resources
- Culling inactive projectiles

### Budget Goals
- Projectile simulation under 1.5ms/frame

---

## 5. VFX Systems

### Risks
- Particle spam
- Too many glow/trail effects
- Expensive shaders
- Overdraw
- Chaos effects scaling too aggressively

### Things To Look Into
- Particle pooling
- Max active particle limits
- VFX LOD system
- Reduce transparency overlap
- Simplify fullscreen effects
- Lower trail precision
- Disable hidden effects

### Budget Goals
- VFX under 2ms/frame
- Stable performance during chaos states

---

## 6. Physics Simulation

### Risks
- Too many active rigid bodies
- Time dilation instability
- Rapier sync overhead
- Continuous collision detection overload

### Things To Look Into
- Reduce unnecessary rigid bodies
- Sleep inactive physics bodies
- Clamp delta values
- Separate gameplay time scaling from physics timing
- Simplify collision layers/masks
- Profile Rapier extension behavior

### Budget Goals
- Physics under 3ms/frame
- No unstable frame spikes

---

## 7. Telemetry & Debug Systems

### Risks
- Updating UI every frame
- Constant string creation
- Excessive monitoring overhead

### Things To Look Into
- Update telemetry at lower frequency
- Cache formatted text
- Disable debug systems in release builds
- Reduce graph/history sampling frequency

### Budget Goals
- Debug overhead near zero in release builds

---

# Rendering Optimization

## Things To Investigate
- Draw call counts
- Overlapping transparent effects
- Dynamic lighting cost
- Fullscreen shader usage
- Large particle counts
- Excessive bloom/glow
- High-resolution render targets
- Expensive post-processing

## Possible Fixes
- Use lower resolution effects
- Merge draw operations
- Reduce shader complexity
- Lower particle density
- Use visibility culling
- Reduce update frequency for cosmetic systems

---

# Wave & Arena Scaling

## Risks
- Spawn bursts
- Difficulty scaling too quickly
- Too many simultaneous systems
- Arena instability compounding exponentially

## Things To Look Into
- Stagger enemy spawning
- Limit simultaneous hazards
- Dynamic difficulty scaling based on FPS
- Cap active arena anomalies
- Reduce effect intensity during stress states

---

# Performance Tooling To Build

## Essential Tools

### Real-Time Profiler Overlay
Track:
- FPS
- Frame time
- Physics time
- Render time
- AI time
- Gravity time
- Projectile count
- Particle count
- Active enemies
- Active gravity sources

---

### Spike Logger
Automatically log:
- Frame spikes >100ms
- Current wave
- Enemy count
- Gravity source count
- Current active effects
- Recently spawned entities

---

### Stress Test Arena
Create a dedicated test scene for:
- Maximum enemies
- Maximum projectiles
- Maximum VFX
- Maximum gravity interactions
- Long-duration stability testing

---

# Optimization Philosophy

The goal is NOT to remove chaos.

The goal is to:
- Preserve the game's gravitational identity
- Preserve orbit combat
- Preserve emergent interactions
- Preserve time manipulation
- Preserve high-intensity moments

While making the simulation:
- Stable
- Predictable
- Efficient
- Scalable
- Streamer-safe
- Smooth at high chaos levels

---

# Highest Priority Action Order

1. Find source of catastrophic frame spikes
2. Raise baseline FPS above 60
3. Optimize gravity system
4. Optimize AI update frequency
5. Pool projectiles and VFX
6. Reduce rendering overhead
7. Build stress-testing tools
8. Tune scaling systems
9. Optimize release build
10. Final polish and chaos balancing

