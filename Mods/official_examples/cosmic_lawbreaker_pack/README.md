# Cosmic Lawbreaker Pack

Official example mod for arena law creators.

This pack demonstrates:
- Declarative `rules` for gravity and risk/reward laws.
- A deterministic `arena_events` entry for wrong-vector weather.
- A safe `law_weaves` hook that requests bounded effects instead of executing scripts.
- Creator options that become part of the multiplayer gameplay signature.

Copy this folder when making a physics-law pack. Change IDs, display names, tuning fields, and hook effects. Keep telegraphs, cooldowns, and caps.

Do not add arbitrary scripts for normal public mods. Trusted directors should consume these entries through `ModContentRegistry`.
