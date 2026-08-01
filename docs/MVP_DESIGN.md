# Overrun: MVP Design Spec

Status: preliminary  
Working title: **Overrun**  
Engine: **Godot 4**  
Primary platform: desktop  
Session target: **roughly 8–15 minutes**, with no hard ending

## 1. Product statement

Overrun is an endless, low-friction bullet-heaven game for filling a short break. The player moves; weapons fire automatically. Enemies continuously enter the map, XP produces frequent upgrade choices, and both player power and enemy pressure scale until the player dies.

The game does not need a campaign, run victory, dialogue, inventory management, or strategic map layer. A run should begin within seconds and restart with one input.

## 2. Core goals

### Immediate

- The first enemy appears immediately.
- The first level-up happens within the opening moments.
- Every upgrade creates an obvious visible or numerical change.
- There is almost always something nearby to shoot.

### Endless

- There is no final wave or forced boss encounter.
- Enemies and bosses do not despawn because the player leaves.
- The world can eventually overwhelm any build.

### Legible

- Movement, damage, healing, and upgrade effects should be understandable without reading a guide.
- Normal enemies remain simple enough to read in large groups.
- Bosses are optional persistent threats, not interruptions.

### Maintainable

- Simulation rules are independent of visuals and UI.
- Weapons and characters use data definitions where that removes duplication.
- Systems remain small and concrete; abstractions are added only after a second real use case appears.
- The first build should be easy for a new contributor to run and understand.

## 3. Explicit non-goals for the MVP

- Multiplayer or networking
- Accounts, cloud saves, matchmaking, analytics services, or any other backend
- Meta-progression
- Multiple maps
- Procedural terrain generation
- Complex enemy pathfinding
- Elemental damage types, resistances, or status-effect frameworks
- Large character or weapon rosters
- Mod support
- Perfect deterministic lockstep
- A custom ECS framework

The code should not block these ideas unnecessarily, but it should not implement them in advance.

## 4. Core run loop

1. Start a run immediately.
2. Move with directional input.
3. The equipped weapon automatically targets and fires.
4. Killed enemies award XP globally; no XP gems are required.
5. Reaching the XP threshold pauses the single-player run.
6. Choose one of three random upgrades.
7. Resume with the upgrade applied immediately.
8. Spawn pressure and enemy strength increase over time.
9. Die, view a compact run summary, and restart.

## 5. First playable slice

The first playable slice should answer one question: **Is moving through a growing crowd while a basic weapon scales fun for ten minutes?**

It contains only:

- One arena
- One character
- One normal enemy
- One straight-line projectile weapon
- XP, level-ups, and six basic upgrades
- Player health and death
- Endless spawning
- Restart

Do not build bosses, a minimap, multiple weapons, elaborate particles, or permanent progression before this slice is playable and profiled.

## 6. Initial player

Working character name: **Runner**

| Stat | Initial value |
|---|---:|
| Maximum health | 100 |
| Armor | 0 |
| Move speed | 240 px/s |
| Regeneration | 1% max health/s |
| Regen ceiling | 50% max health |
| Regen delay after damage | 3 s |
| Pickup radius | 72 px |

Regeneration begins only after the damage delay and stops at 50% maximum health. Health pickups are required to recover above that point.

Future characters may vary these baseline values, starting weapon, movement behavior, range preferences, or passive rule. The MVP uses one character and no character-select screen.

## 7. Initial weapon

Working weapon name: **Needle**

Behavior:

- Find the nearest valid enemy within targeting range.
- Fire one projectile in a straight line toward its position at fire time.
- Do not home after firing.
- The projectile dies after its lifetime expires or its available hits are consumed.

Suggested starting values:

| Stat | Initial value |
|---|---:|
| Damage | 10 |
| Cooldown | 0.60 s |
| Projectile count | 1 |
| Projectile speed | 900 px/s |
| Projectile lifetime | 1.5 s |
| Targeting range | 1,200 px |
| Projectile radius | 6 px |
| Pierce | 0 |

Projectile pierce is a consumable damage budget:

`total damage budget = projectile damage × (pierce + 1)`

A projectile applies only enough damage to consume the target's remaining health, then carries any overkill budget into later enemies. For example, a 10-damage projectile with 0 pierce can kill two 5-health enemies. If a target survives the hit, it consumes the projectile's entire remaining budget and stops it.

A projectile can damage each target only once during its lifetime. Repeat-hit behavior belongs to persistent attacks such as orbiting or melee weapons and must be configured separately from pierce.

## 8. Initial enemy

Working enemy name: **Drifter**

| Stat | Initial value |
|---|---:|
| Health | 10 |
| Move speed | 85 px/s |
| Contact damage | 10 |
| XP reward | 1 |
| Collision radius | 14 px |

Behavior:

- Move directly toward the player.
- Use no navigation mesh or pathfinding.
- Increase movement speed continuously with elapsed run time, including enemies already alive.
- During an anti-lull surge, apply an additional ramping movement multiplier to distant normal enemies; fade that multiplier out near the player.
- Apply contact damage through the shared damage pipeline.
- Respect a short contact-hit interval so overlap does not deal damage every frame.

Suggested contact-hit interval: **0.5 seconds per source**. This can be simplified to a short player global contact cooldown in the first slice if that implementation is clearer.

After any successful hit, grant the player **0.35 seconds of global invulnerability**. Contact and boss attacks both respect this window. Flash the player sprite during the window so blocked follow-up hits are readable.

## 9. XP and level curve

Rewards:

| Source | XP |
|---|---:|
| Normal enemy | 1 |
| Elite | 5 |
| Boss | 20 |

For level `L`, beginning at `L = 1`, use:

`xp_required(L) = ceil(5L + 0.8L² + 2G(L)²)`

`G(L)` is the Golomb sequence:

`1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5, ...`

The formula deliberately has no flat `+10`, so the first upgrade requires 8 XP. XP overflow carries into the next level.

The formula is a tuning starting point, not a sacred rule. Record time-to-level during tests. The desired experience is several rapid opening upgrades followed by steadily wider gaps that are offset by rising kill rates.

## 10. Upgrade selection

On level-up:

- Pause the single-player simulation.
- Show three choices.
- Draw without duplicate choices when possible.
- Apply the selected upgrade immediately.
- Preserve XP overflow.
- Guarantee a Damage choice whenever current normal-enemy health exceeds 1.5 times the weapon's base projectile damage. This prevents utility-heavy RNG from allowing enemy health scaling to strand the build.

First-slice upgrade pool:

| Upgrade | Effect |
|---|---|
| Damage | +20% weapon damage |
| Fire rate | -12% weapon cooldown |
| Projectile | +1 projectile per attack |
| Pierce | +1 pierce |
| Move speed | +10% movement speed |
| Maximum health | +15% max health and heal the amount gained |

MVP additions after the first slice:

| Upgrade | Effect |
|---|---|
| Armor | +10 armor |
| Regeneration | +0.5% max health/s |
| Pickup radius | +25% pickup radius |

New weapons will eventually be rarer choices. Do not build a general rarity framework for the first weapon. When a second weapon exists, introduce a small weighted pool and a pity rule that raises the chance of seeing a new weapon after several levels without one.

## 11. Health, armor, regeneration, and healing

### Damage reduction

Use diminishing-return armor:

`final_damage = raw_damage × 100 / (100 + armor)`

Armor never reaches full immunity. The UI should display both armor and the resulting percentage reduction.

### Regeneration

- Base rate: 1% maximum health per second
- Delay: 3 seconds after taking damage
- Ceiling: 50% maximum health
- Regeneration scales with maximum health

### Health pickups

- Normal pickup: heal 20% maximum health
- Healing clamps at maximum health
- Pickups use their own pool and cap
- Pickups do not despawn in the MVP

A mild pity system may be added after ordinary random drops are tested. Do not tune drops dynamically until actual playtests show that unlucky streaks are a problem.

## 12. Spawning and anti-lull behavior

Enemies spawn just outside the visible camera region. The base spawn rate rises over elapsed time until the simulation reaches its entity budget.

Track **nearby threat**, not only the total world population. Bosses abandoned across the map should not prevent nearby normal enemies from spawning.

Initial anti-lull rule:

- Enter surge when five or fewer normal enemies are within roughly 2.5 screen widths of the player.
- Ramp the spawn multiplier from 1× to 4× over about 3 seconds.
- Hold the surge for up to 7 seconds.
- End early when nearby normal population reaches 25.
- Add a short cooldown to prevent rapid toggling.
- Spawn mainly just outside the viewport, with some bias toward the player's direction of travel.

Use hysteresis: enter at 5, exit at 25. Do not maintain large spawn debt; at most a few seconds of attempted spawns should be remembered.

When a very strong build kills enemies as they appear, the surge may remain active much of the time. That is intended.

## 13. Entity budgets

Initial target budgets, subject to profiling:

| Category | Capacity |
|---|---:|
| Normal enemies | 1,450 |
| Elites | 140 |
| Bosses | 10 |
| Visible projectiles | 16,384 |
| Health pickups | 40 |

The first performance milestone is stable play with at least **1,000 active enemies** and several thousand visible projectiles on a representative development machine.

Cap categories separately so normal enemies cannot block boss or elite spawns. Pools should reuse slots instead of repeatedly allocating and freeing objects during combat.

## 14. Boss behavior for the MVP demo

Bosses are added only after the first playable slice works.

The first boss should:

- Spawn without pausing or moving the camera.
- Appear one to two screens away.
- Persist if ignored.
- Patrol or pursue within a broad region rather than following forever at any distance.
- Award 20 XP and drop a health pickup.
- Use one clearly telegraphed attack.
- Remain marked on the minimap.

If the boss cap is reached, do not spawn another entity. Strengthen an existing boss or skip the event. The exact empowerment rule can wait until multiple simultaneous bosses are tested.

## 15. Minimap

The MVP demo minimap shows:

- Player
- Map bounds or a simple local frame
- All active bosses
- Nearby elites, if useful after testing
- Health pickups only while the player is below 50% health, if this remains readable

Normal enemies are not shown. Boss markers remain visible regardless of distance and communicate active pursuit with a pulse or other simple state change.

## 16. Scaling

Time increases pressure through a small number of tunable curves:

- Spawn attempts per second
- Enemy health
- Enemy damage
- Enemy movement speed, with a conservative cap
- Elite frequency
- Boss interval

Do not add a generic modifier framework first. Put these values in one run-scaling definition and tune them directly.

Scaling should change enemy behavior later, but the MVP may use only numerical scaling. The purpose of the MVP is to validate the loop and performance, not solve infinite content variety.

## 17. Combat architecture

The combat flow is:

1. Weapons create attacks.
2. Attacks move or query for targets.
3. Collision creates hit requests.
4. The damage system resolves hit requests.
5. Damage results update health and mark deaths.
6. The death system awards XP, creates drops, and frees slots.
7. Presentation consumes coarse results for sound, particles, and UI.

### Ownership rules

- Projectile system: movement, lifetime, pierce, previous-hit protection
- Collision system: what touched what
- Damage system: final damage amount
- Health system: current health and death marking
- Death system: XP, drops, secondary effects, slot release
- Presentation: animation, particles, audio, floating numbers

Do not emit a Godot signal for every hit, enemy movement, or projectile collision. Use preallocated buffers for high-frequency events. Signals are appropriate for low-frequency events such as level-up, boss spawn, run end, and menu actions.

Do not remove an enemy in the middle of damage resolution. Mark it dead, process deaths once after all hits for the simulation step, then return its slot to the pool.

## 18. Technical structure

Use Godot nodes for the small number of high-level objects: run controller, player presentation, camera, UI, minimap, and menus.

Use compact arrays or pooled records for large populations: enemies, projectiles, pickups, hit requests, damage results, and deaths.

Suggested initial layout:

```text
project.godot
src/
  game/
    run_controller.gd
    run_config.gd
  simulation/
    world.gd
    enemy_system.gd
    projectile_system.gd
    spatial_grid.gd
    damage_system.gd
    spawn_system.gd
  content/
    character_definition.gd
    weapon_definition.gd
    enemy_definition.gd
    upgrade_definition.gd
  presentation/
    world_view.gd
    hud.gd
    minimap.gd
scenes/
  main.tscn
  game.tscn
  ui/
assets/
tests/
```

This is a direction, not a requirement to create every file before it has code. Begin with fewer files and split a file when it has more than one clear responsibility or becomes difficult to test.

### Language

Start in GDScript for speed of iteration. Keep simulation code free of scene-tree assumptions so a proven hot loop can later move to C# or a native extension without rewriting the game rules. Do not switch languages before profiling identifies a real bottleneck.

### Spatial queries

Use a uniform spatial grid for enemy lookup, targeting, and projectile collision. Avoid pairwise checks and avoid giving every enemy a physics body. The first implementation may use simple circle collision and swept segments for fast projectiles.

### Rendering

Start with ordinary sprites only long enough to verify behavior. Move bulk enemies and projectiles to MultiMesh or direct batched drawing before the stress-test milestone. Bosses and the player may remain normal scene nodes.

## 19. Contribution rules

- Every change should preserve a runnable main branch.
- Prefer small pull requests with one observable purpose.
- Put tuning values in data or config rather than scattering literals through systems.
- Do not add an abstraction without a current second use case.
- Avoid inheritance trees for enemies and weapons; prefer definitions plus small behavior strategies when variation actually exists.
- Document non-obvious performance decisions near the code.
- Add a small regression test or reproducible debug scene for bugs in formulas, pooling, collision, XP, or damage.
- Profile first; optimize the measured bottleneck.

## 20. Implementation order

### Milestone 0: repository and boot

- Godot project opens.
- Main scene runs.
- Basic debug overlay displays frame time and entity counts.

### Milestone 1: one-minute combat loop

- Player movement
- Drifter spawn and pursuit
- Needle fires one straight projectile
- Shared hit, damage, death, and XP pipeline
- Player can take damage and die
- Immediate restart

### Milestone 2: level-up loop

- XP curve and overflow
- Pause on level-up
- Three random choices
- Damage, fire-rate, projectile-count, pierce, movement, and max-health upgrades
- No duplicate choices in the same offer

### Milestone 3: sustained run

- Armor and regeneration
- Percentage health pickups
- Time-based enemy scaling
- Anti-lull spawning
- Entity caps and pools
- Run summary

### Milestone 4: scale test

- Uniform spatial grid
- Batched enemy and projectile rendering
- 1,000+ active-enemy stress scene
- No routine combat-loop allocations
- Profiling overlay or reproducible benchmark notes

### Milestone 5: MVP demo identity

- One persistent optional boss
- Boss minimap marker
- Basic sound and hit feedback
- Minimal visual polish
- Balance pass targeting 8–15 minute ordinary runs

Do not begin a roster, second map, networking, or backend before Milestone 5 is playable.

## 21. Future roster and weapons

After the MVP demo, add a character roster through small data definitions:

- Base health
- Armor
- Movement speed
- Regen rate and ceiling
- Pickup radius
- Starting weapon
- One passive rule

Potential character differences should be felt immediately, such as a short-range durable character, a fragile long-range character, or a fast character with weaker damage. Avoid minor percentage-only variants.

Add the second weapon before designing a universal weapon framework. That second weapon should challenge the first implementation, such as a short-range aura or slow piercing line shot. Refactor only the shared behavior that becomes obvious from those two concrete weapons.

## 22. Multiplayer boundary

Multiplayer is intentionally deferred. To avoid an unnecessary rewrite later:

- Advance gameplay through a fixed simulation step.
- Keep UI, sound, and visuals outside authoritative game rules.
- Use explicit player input data rather than reading input throughout systems.
- Use separate random streams for gameplay and presentation.
- Give entities stable IDs with generation counters if pooled slots are externally referenced.

A later prototype can use a host-authoritative model for two to four players. The single-player level-up pause will need a separate multiplayer rule, but that rule should not influence the MVP implementation yet.

## 23. MVP success criteria

The MVP demo succeeds when:

- A new player can start and understand the game without instructions.
- The first level-up arrives quickly and visibly changes play.
- A typical run has no obvious empty stretches.
- Defensive choices produce different survival behavior.
- Ignored bosses remain meaningful map threats without forcing engagement.
- The game sustains at least 1,000 active enemies at the target frame rate on the chosen baseline machine.
- A contributor can locate spawning, damage, projectiles, upgrades, and tuning without tracing a deep object hierarchy.
- Restarting after death takes one input and only a few seconds.
