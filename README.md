# Overrun

**Overrun** is a working title for a fast, endless bullet-heaven game built for short sessions. Move, auto-fire, gain XP, choose upgrades, and survive until the run collapses.

The repository intentionally favors a small playable loop over a content framework or generalized engine.

## Current demo

- One playable character, Runner
- A four-slot weapon roster: Needle, Longshot, Aura Pulse, and Mire Field
- An array-based enemy and projectile simulation with batched rendering
- A 2× compressed progression clock: doubled XP rewards and spawn throughput, half-time bosses, and twice-as-fast enemy scaling
- XP with three-choice paused level-ups and level-30 DPS-tracking offense pity
- Infinite global damage scaling plus distinct capped upgrade pools, weighted utility rolls, and strongly scaling Longshot projectile size
- Armor with diminishing returns, brief post-hit invulnerability frames, and lethal-hit protection above 50% HP
- Regeneration only below 50% health after a damage delay
- Persistent percentage-based health pickups
- Endless health, damage, and uncapped movement scaling with anti-lull surges and a live-population logarithmic spawn throttle
- Proportional camera zoom-out whenever player movement speed increases
- Fast-scaling persistent bosses with telegraphed attacks, burst protection, and weapon-only rewards that can unlock open weapon slots
- A minimap that always marks bosses
- A generated robot-themed sound system for weapons, enemies, bosses, pickups, UI navigation, upgrades, targeting, restart, and death
- Death summary and one-input restart
- A full-cap 715-normal-enemy stress mode with ten boss slots reserved

The detailed design remains in [`docs/MVP_DESIGN.md`](docs/MVP_DESIGN.md).

## Controls

- Move: `WASD` or arrow keys
- Toggle targeting between Closest and Strongest: `T`
- Toggle the performance diagnostics panel: `F3`
- Choose upgrades: mouse, number keys `1`–`3`, arrows plus `Enter`, or arrows plus `Space`
- Restart after death with the same operator: `R`, `Enter`, `Space`, or the restart button
- Choose a different operator after death: `Escape`
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

The test command imports the project, checks the XP and population-based spawn curves, verifies pause and projectile collision behavior, and runs full-cap headless and real-render benchmarks.

The crowd benchmark fills all 715 normal-enemy slots, while the rendered cap test adds the ten reserved bosses for 725 total live enemies.

## Package Windows build

Install the matching Godot export templates, then run:

```bash
GODOT_BIN=/path/to/godot ./scripts/package.sh
```

The packaged executable is written to `dist/Overrun.exe` with its resource pack embedded. The checksum file uses the portable filename `Overrun.exe`, so both files can be verified from the same directory with `sha256sum -c Overrun.exe.sha256`.

## Publish rolling test build

With GitHub CLI authenticated, publish the current clean commit to the rolling `dev` prerelease:

```bash
./scripts/publish.sh
```

The publisher rebuilds the executable, verifies the local checksum and PE format, replaces both release assets, moves the `dev` tag to the published commit, downloads the assets again, and verifies the remote checksum. It refuses a dirty worktree unless `ALLOW_DIRTY=1` is set intentionally.

The executable keeps a stable public download URL:

```text
https://github.com/LoushengM/overrun/releases/download/dev/Overrun.exe
```

The repository is public, so the release assets can be downloaded without GitHub authentication. The matching `Overrun.exe.sha256` asset is published beside the executable.

## Code map

```text
src/game.gd                 run coordination and pause/restart flow
src/game_config.gd          tuning and upgrade text
src/simulation_world.gd     simulation, combat, spawning, health, XP
src/hud.gd                  HUD and modal interfaces
src/minimap.gd              boss and emergency pickup radar
src/sound_manager.gd        pooled, throttled, priority-aware sound playback
assets/audio/                generated robot-themed sound pack and documentation
scenes/main.tscn            minimal scene composition
```

The simulation uses no node per enemy and no signal per hit. Large populations live in compact parallel arrays, collision uses a uniform spatial grid with reused buckets, and normal enemies and projectiles render through `MultiMesh` batches. Needle and Longshot require targets in their own ranges, Aura Pulse schedules delayed echo pulses that recheck nearby enemies, and Mire Field persists and slows nearby enemies without requiring a target.

## Generated audio

The sound pack is synthesized deterministically by `tools/generate_robot_audio.py` using only Python's standard library. It requires no external samples. See `assets/audio/README.md` for the palette, regeneration command, and mix notes.

## Contribution rules

- Keep the project runnable after each change.
- Add abstractions only when a second concrete use exists.
- Keep tuning in `game_config.gd` when practical.
- Avoid per-entity nodes, signals, and allocation-heavy hot loops.
- Run `scripts/test.sh` before committing.
