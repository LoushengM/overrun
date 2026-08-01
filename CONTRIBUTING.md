# Contributing

Overrun is intentionally small during the MVP phase.

## Before changing code

- Read `docs/MVP_DESIGN.md`.
- Keep the current milestone runnable.
- Discuss additions that expand scope beyond the current milestone.

## Change shape

Prefer one focused change per pull request. Include:

- What behavior changed
- How to reproduce or test it
- Any new tuning values
- Profiling evidence when the change is primarily an optimization

## Code direction

- Keep simulation rules separate from visual effects and UI.
- Avoid per-enemy signals in hot paths.
- Reuse buffers and pooled objects during combat.
- Put shared tuning values in configuration or content definitions.
- Add abstractions only when two concrete features need the same behavior.
- Favor composition and data definitions over deep inheritance.

## Performance

Do not guess. Use a repeatable stress scene and compare frame time, allocations, and entity counts before and after performance work.
