# Overrun

**Overrun** is a working title for a fast, endless bullet-heaven game built for short sessions. Move, auto-fire, gain XP, choose upgrades, and survive until the run collapses.

The current repository is intentionally small. The first goal is a playable combat loop, not a content framework, online service, or generalized engine.

## MVP target

- One playable character
- One basic enemy that chases the player
- One weapon that fires a straight projectile at the nearest target
- XP and three-choice level-ups
- Damage, projectile count, pierce, fire-rate, movement, and defensive upgrades
- Health, armor, capped regeneration, and percentage-based health pickups
- Endless spawning with anti-lull acceleration and a hard entity cap
- One optional persistent boss and a minimap boss marker
- Death, run summary, and immediate restart

The detailed design is in [`docs/MVP_DESIGN.md`](docs/MVP_DESIGN.md).

## Technical direction

- Godot 4
- GDScript for the first playable build
- Fixed-step, data-oriented combat simulation
- Batched rendering for large enemy and projectile counts
- No online backend for the MVP
- Multiplayer is a later host-authoritative experiment, not an MVP dependency

## Repository principles

1. Prefer the smallest implementation that proves the game feels good.
2. Keep simulation, content data, and presentation separate.
3. Profile before replacing simple code with specialized code.
4. Avoid per-entity signals and deep inheritance in combat hot paths.
5. Make one focused change per pull request.

## Status

Design and scaffolding only.
