# Overrun

**Overrun** is a working title for a fast, endless bullet-heaven game built for short sessions. Move, auto-fire, gain XP, choose upgrades, and survive until the run collapses.

The repository intentionally favors a small playable loop over a content framework or generalized engine.

## Current demo

- One playable character, Runner
- A four-slot weapon roster: Needle, Longshot, Aura Pulse, and Mire Field
- An array-based enemy and projectile simulation with batched rendering
- XP with three-choice paused level-ups and damage-scaling pity
- Infinite global damage scaling plus distinct capped upgrade pools for every weapon, including Longshot projectile size
- Armor with diminishing returns, brief post-hit invulnerability frames, and lethal-hit protection above 50% HP
- Regeneration only below 50% health after a damage delay
- Persistent percentage-based health pickups
- Endless health, damage, and uncapped movement scaling with anti-lull spawn-and-speed surges
- Proportional camera zoom-out whenever player movement speed increases
- Fast-scaling persistent bosses with telegraphed attacks, burst protection, and weapon-only rewards that can unlock open weapon slots
- A minimap that always marks bosses
- Death summary and one-input restart
- A headless 1,200-enemy stress mode

The detailed design remains in [`docs/MVP_DESIGN.md`](docs/MVP_DESIGN.md).

## Controls

- Move: `WASD` or arrow keys
- Toggle targeting between Closest and Strongest: `T`
- Choose upgrades: mouse or number keys `1`, `2`, and `3`
- Restart after death: `R`, `Enter`, or the restart button
- Quit: `Escape`

## Run from the editor

Open the repository with Godot 4.7.1 and run the main scene.

From a terminal with Godot available:

```bash
godot --path .
```

The local development setup used for this build places Godot at:

```text
.tools/godot/Godot_v4.7.1-stable_linux.x86_64
```

That directory is ignored by Git.

## Test

Set `GODOT_BIN` when Godot is not on `PATH`:

```bash
GODOT_BIN=/path/to/godot ./scripts/test.sh
```

The test command imports the project, checks the XP curve, verifies pause and projectile collision behavior, and runs a ten-second 1,200-enemy headless benchmark.

A rendered benchmark that keeps 800 enemies visible is available at `tests/crowd_benchmark.gd`.

## Package Windows build

Install the matching Godot export templates, then run:

```bash
GODOT_BIN=/path/to/godot ./scripts/package.sh
```

The packaged executable is written to `dist/Overrun.exe` with its resource pack embedded.

## Code map

```text
src/game.gd                 run coordination and pause/restart flow
src/game_config.gd          tuning and upgrade text
src/simulation_world.gd     simulation, combat, spawning, health, XP
src/hud.gd                  HUD and modal interfaces
src/minimap.gd              boss and emergency pickup radar
scenes/main.tscn            minimal scene composition
```

The simulation uses no node per enemy and no signal per hit. Large populations live in compact parallel arrays, collision uses a uniform spatial grid with reused buckets, and normal enemies and projectiles render through `MultiMesh` batches. Needle and Longshot require targets in their own ranges, Aura Pulse schedules delayed echo pulses that recheck nearby enemies, and Mire Field persists and slows nearby enemies without requiring a target.

## Contribution rules

- Keep the project runnable after each change.
- Add abstractions only when a second concrete use exists.
- Keep tuning in `game_config.gd` when practical.
- Avoid per-entity nodes, signals, and allocation-heavy hot loops.
- Run `scripts/test.sh` before committing.
