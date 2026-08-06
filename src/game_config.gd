class_name GameConfig
extends RefCounted

const TITLE := "Overrun"
const VIEW_SIZE := Vector2(1280.0, 720.0)

const PLAYER_RADIUS := 18.0
const PLAYER_MAX_HEALTH := 100.0
const PLAYER_ARMOR := 0.0
const PLAYER_MOVE_SPEED := 240.0
const PLAYER_REGEN_RATE := 0.01
const PLAYER_REGEN_CEILING := 0.50
const PLAYER_REGEN_DELAY := 3.0
const PLAYER_PICKUP_RADIUS := 72.0
const PLAYER_HIT_INVULNERABILITY := 0.35
const PLAYER_LEVEL_UP_INVULNERABILITY := 0.50
const PLAYER_HIT_STREAK_WINDOW := 2.0
const PLAYER_HIT_INVULNERABILITY_STREAK_INCREASE := 0.50
const PLAYER_HIT_INVULNERABILITY_MAX_MULTIPLIER := 3.0
const PLAYER_ONE_SHOT_PROTECTION_THRESHOLD := 0.50
const PLAYER_ONE_SHOT_PROTECTION_HEALTH := 1.0
const PLAYER_ONE_SHOT_PROTECTION_VISUAL_DURATION := 0.80

# Playable roster. Every operator keeps the Needle as its permanent base weapon;
# a non-empty `weapon` is an extra weapon the operator starts with, and it
# consumes one of the four weapon slots. Stat entries are multipliers on the
# PLAYER_* baselines so tuning stays in one place. `armor_bonus` is flat because
# armor already has its own diminishing-returns curve. Passives are data keys
# read by _apply_character, so a new operator needs no simulation changes.
const DEFAULT_CHARACTER_ID := "runner"
const CHARACTER_IDS := ["runner", "bulwark", "scout", "gunner", "warden", "reaper"]
const CHARACTERS := {
    "runner": {
        "name": "Runner",
        "weapon": "",
        "health": 1.00,
        "speed": 1.00,
        "damage": 1.00,
        "regen": 1.00,
        "armor_bonus": 0.0,
        "pickup_radius": 1.25,
        "xp_gain": 1.00,
        "passive": "Salvager - 25% wider pickup reach",
        "blurb": "Balanced baseline with a free weapon slot.",
    },
    "bulwark": {
        "name": "Bulwark",
        "weapon": "aura",
        "health": 1.60,
        "speed": 0.85,
        "damage": 1.00,
        "regen": 1.00,
        "armor_bonus": 25.0,
        "pickup_radius": 1.00,
        "xp_gain": 1.00,
        "passive": "Bastion - opens with 25 armor",
        "blurb": "Slow, heavily plated, fights at melee range.",
    },
    "scout": {
        "name": "Scout",
        "weapon": "",
        "health": 0.75,
        "speed": 1.25,
        "damage": 1.00,
        "regen": 1.00,
        "armor_bonus": 0.0,
        "pickup_radius": 1.10,
        "xp_gain": 1.15,
        "passive": "Fast Learner - 15% more XP",
        "blurb": "Fragile and quick; levels fastest.",
    },
    "gunner": {
        "name": "Gunner",
        "weapon": "sniper",
        "health": 0.90,
        "speed": 0.95,
        "damage": 1.00,
        "regen": 1.00,
        "armor_bonus": 0.0,
        "pickup_radius": 1.00,
        "xp_gain": 1.00,
        "sniper_pierce_bonus": 1,
        "passive": "Penetrator - Longshot +1 pierce",
        "blurb": "Opens with the Longshot already equipped.",
    },
    "warden": {
        "name": "Warden",
        "weapon": "field",
        "health": 1.20,
        "speed": 0.95,
        "damage": 1.00,
        "regen": 1.00,
        "armor_bonus": 0.0,
        "pickup_radius": 1.00,
        "xp_gain": 1.00,
        "field_duration_scale": 1.25,
        "passive": "Lingering Mire - fields last 25% longer",
        "blurb": "Area denial from the first second.",
    },
    "reaper": {
        "name": "Reaper",
        "weapon": "",
        "health": 0.70,
        "speed": 1.05,
        "damage": 1.30,
        "regen": 0.00,
        "armor_bonus": 0.0,
        "pickup_radius": 1.00,
        "xp_gain": 1.00,
        "passive": "No Recovery - +30% damage, never regenerates",
        "blurb": "Highest opening damage. One mistake kills.",
    },
}

# Eight weapons against four slots. The cap deliberately stays at 4 while the
# pool grows: exclusivity is what makes the loadout a decision. Operators that
# start with a weapon spend one of those four slots on it.
const WEAPON_SLOT_CAP := 4
const WEAPON_IDS := [
    "needle",
    "sniper",
    "aura",
    "field",
    "chain",
    "flak",
    "orbital",
    "detonator",
]
const TARGETABLE_WEAPON_IDS := [
    "needle",
    "sniper",
    "chain",
    "flak",
    "detonator",
]
const WEAPON_NAMES := {
    "needle": "Needle",
    "sniper": "Longshot",
    "aura": "Aura Pulse",
    "field": "Mire Field",
    "chain": "Arc Chain",
    "flak": "Flak Burst",
    "orbital": "Orbital",
    "detonator": "Detonator",
}

# Needle: short-range generalist projectile.
const NEEDLE_DAMAGE := 10.0
const NEEDLE_COOLDOWN := 0.60
const NEEDLE_PROJECTILES := 1
const NEEDLE_SPEED := 900.0
const NEEDLE_LIFETIME := 0.90
const NEEDLE_RANGE := 700.0
const NEEDLE_RADIUS := 6.0
const NEEDLE_PIERCE := 0
const NEEDLE_HOMING_PER_RANK := 0.10
const NEEDLE_HOMING_MAX := 0.40
const NEEDLE_HOMING_MAX_TURN_RATE := TAU * 2.0
const NEEDLE_HOMING_ACQUISITION_RANGE := 560.0
const NEEDLE_HOMING_REFRESH_INTERVAL := 0.10

# Compatibility names used by the current simulation and benchmark helpers.
const WEAPON_DAMAGE := NEEDLE_DAMAGE
const WEAPON_COOLDOWN := NEEDLE_COOLDOWN
const WEAPON_PROJECTILES := NEEDLE_PROJECTILES
const WEAPON_SPEED := NEEDLE_SPEED
const WEAPON_LIFETIME := NEEDLE_LIFETIME
const WEAPON_RANGE := NEEDLE_RANGE
const WEAPON_RADIUS := NEEDLE_RADIUS
const WEAPON_PIERCE := NEEDLE_PIERCE

# Longshot: slow, high-damage, long-range standard projectile.
const SNIPER_DAMAGE := 55.0
const SNIPER_COOLDOWN := 2.40
const SNIPER_SPEED := 1600.0
const SNIPER_LIFETIME := 1.80
const SNIPER_RANGE := 2200.0
const SNIPER_RADIUS := 8.0
const SNIPER_PIERCE := 0
const SNIPER_SIZE_UPGRADE_MULTIPLIER := 1.45

# Aura Pulse: fires only when something is in melee range. Echo upgrades add
# delayed pulses that recheck which enemies are currently inside the radius.
const AURA_DAMAGE := 12.0
const AURA_COOLDOWN := 3.20
const AURA_RADIUS := 180.0
const AURA_ECHOES := 0
const AURA_ECHO_INTERVAL := 0.22
const AURA_VISUAL_DURATION := 0.18

# Mire Field: places persistent slowing damage zones around the player without
# requiring a target.
const FIELD_DAMAGE := 4.0
const FIELD_COOLDOWN := 2.80
const FIELD_PLACEMENT_RADIUS := 260.0
const FIELD_RADIUS := 130.0
const FIELD_DURATION := 4.0
const FIELD_TICK_INTERVAL := 0.50
const FIELD_SLOW_MULTIPLIER := 0.65
const FIELD_CAP := 48

# Arc Chain: hits a target then jumps to nearby enemies with per-jump falloff.
# Damage goes through the fixed-damage queue rather than spawning projectiles,
# so chain length costs a neighbour scan and nothing in the projectile sweep.
const CHAIN_DAMAGE := 16.0
const CHAIN_COOLDOWN := 1.30
const CHAIN_RANGE := 620.0
const CHAIN_JUMPS := 2
const CHAIN_JUMP_RADIUS := 240.0
const CHAIN_FALLOFF := 0.72
const CHAIN_VISUAL_DURATION := 0.16
const CHAIN_MAX_JUMPS := 10

# Flak Burst: a wide cone of short-lived pellets. Close-range shred that falls
# off hard with distance because the pellets expire quickly.
const FLAK_DAMAGE := 7.0
const FLAK_COOLDOWN := 1.05
const FLAK_PELLETS := 5
const FLAK_SPREAD_DEGREES := 52.0
const FLAK_SPEED := 720.0
const FLAK_LIFETIME := 0.42
const FLAK_RANGE := 520.0
const FLAK_RADIUS := 5.0
const FLAK_VISUAL_DURATION := 0.14

# Orbital: satellites that circle the player. These live in their own arrays
# because the shared projectile sweep advances entries by velocity and treats
# them as line segments; an angular orbit would read as a teleport across the
# arena and corrupt the segment-vs-circle test.
# Orbital costs the player nothing to use -- no aiming, no positioning, no
# window to miss -- so its base output sits just under Needle rather than at
# the top of the table. At 9.0/0.35 it was the strongest weapon in the game.
const ORBITAL_DAMAGE := 5.0
const ORBITAL_COUNT := 2
const ORBITAL_RADIUS := 150.0
const ORBITAL_ANGULAR_SPEED := 2.60
const ORBITAL_HIT_RADIUS := 16.0
const ORBITAL_HIT_INTERVAL := 0.40
const ORBITAL_CAP := 24

# Detonator: slow lobbed shell that deals area damage where it lands. Reuses the
# radial damage sweep from fields, but resolves once instead of persisting.
# The shell travels slowly and can miss entirely, which the 34.0/2.60 opening
# never paid for -- it was the weakest unlock in the pool by a wide margin.
const DETONATOR_DAMAGE := 46.0
const DETONATOR_COOLDOWN := 2.20
const DETONATOR_RANGE := 900.0
const DETONATOR_SPEED := 430.0
const DETONATOR_LIFETIME := 2.20
const DETONATOR_RADIUS := 9.0
const DETONATOR_BLAST_RADIUS := 165.0
const DETONATOR_VISUAL_DURATION := 0.22
const DETONATOR_BLAST_CAP := 32

const GAME_PACE_MULTIPLIER := 2.0

const OFFENSE_PITY_MAX_LEVEL := 30
const OFFENSE_PITY_TARGET_TTK := 0.90
const OFFENSE_PITY_SEVERE_RATIO := 0.65
const NEEDLE_EXTRA_PROJECTILE_DPS_FACTOR := 0.50
const AURA_DPS_UPTIME_FACTOR := 0.75
const FIELD_DPS_OVERLAP_FACTOR := 0.35
const FIELD_DPS_MAX_EQUIVALENTS := 2.0
# Offense-pity uptime factors for the expanded roster. Each discounts a weapon's
# theoretical damage to what it realistically lands in a crowd, so pity does not
# over-credit an unreliable weapon and starve the player of guaranteed DPS picks.
const CHAIN_DPS_UPTIME_FACTOR := 0.80
const FLAK_DPS_UPTIME_FACTOR := 0.55
const ORBITAL_DPS_UPTIME_FACTOR := 0.60
const DETONATOR_DPS_UPTIME_FACTOR := 0.70

# Reserve boss capacity inside the total population budget so late waves cannot
# crowd out scheduled bosses. Normal enemies stop at 715; up to ten bosses bring
# the absolute live-enemy ceiling to 725.
const ENEMY_CAP := 725
const BOSS_CAP := 10
const NORMAL_ENEMY_CAP := ENEMY_CAP - BOSS_CAP

# Population-based spawn throttling. The multiplier is a normalized logarithm
# of remaining capacity: 1.0 in an empty arena, then progressively lower as the
# live population approaches ENEMY_CAP. A strength of 31 gives approximately
# 0.82 at half capacity and 0.41 at 90% capacity.
const SPAWN_POPULATION_LOG_STRENGTH := 31.0

const PROJECTILE_CAP := 16384
const PICKUP_CAP := 40
const GRID_CELL_SIZE := 96.0

# The arena is a torus: leaving one edge re-enters the opposite edge. WORLD_SIZE
# must stay a whole multiple of GRID_CELL_SIZE so wrapped cell indexing is exact.
# 6144 / 96 = 64 cells per axis.
const WORLD_SIZE := 6144.0
const WORLD_HALF_SIZE := WORLD_SIZE * 0.5
const GRID_CELL_COUNT := 64

# Wrapped rendering resolves each entity to its nearest image around the player,
# which is only unambiguous while the visible half-extent stays under half the
# world. VIEW_SIZE * 0.70 * 2.4 = 2150 < 3072, so this cap holds with margin.
const CAMERA_VIEW_SCALE_MAX := 2.4
const MAX_SPAWNS_PER_TICK := 24
const MAX_SPAWN_DEBT_SECONDS := 0.50

const NORMAL_ENEMY_HEALTH := 10.0
const NORMAL_ENEMY_SPEED := 85.0
const NORMAL_ENEMY_SPEED_SCALE_PER_MINUTE := 0.05
const NORMAL_ENEMY_SPEED_SCALE_QUADRATIC := 0.003
const NORMAL_ENEMY_DAMAGE := 10.0
const NORMAL_ENEMY_RADIUS := 14.0
const NORMAL_ENEMY_XP := 1

# Archetype variants of the NORMAL enemy kind. These are multipliers on the
# NORMAL_ENEMY_* base stats so tuning stays in one place. Unlock times are in
# paced minutes; an archetype is only eligible to spawn once its time passes.
const ARCHETYPE_SWARMER_HEALTH := 0.55
const ARCHETYPE_SWARMER_SPEED := 1.45
const ARCHETYPE_SWARMER_DAMAGE := 0.70
const ARCHETYPE_SWARMER_RADIUS := 0.75
const ARCHETYPE_SWARMER_XP := 1
const ARCHETYPE_SWARMER_UNLOCK_MINUTES := 0.0
const ARCHETYPE_SWARMER_WEIGHT := 3.0

const ARCHETYPE_SHIELDED_HEALTH := 3.20
const ARCHETYPE_SHIELDED_SPEED := 0.72
const ARCHETYPE_SHIELDED_DAMAGE := 1.30
const ARCHETYPE_SHIELDED_RADIUS := 1.20
const ARCHETYPE_SHIELDED_XP := 3
const ARCHETYPE_SHIELDED_UNLOCK_MINUTES := 1.5
const ARCHETYPE_SHIELDED_WEIGHT := 1.4

const ARCHETYPE_RANGED_HEALTH := 0.85
const ARCHETYPE_RANGED_SPEED := 0.80
const ARCHETYPE_RANGED_DAMAGE := 1.00
const ARCHETYPE_RANGED_RADIUS := 0.95
const ARCHETYPE_RANGED_XP := 3
const ARCHETYPE_RANGED_UNLOCK_MINUTES := 2.5
const ARCHETYPE_RANGED_WEIGHT := 1.2
const ARCHETYPE_RANGED_STANDOFF := 420.0
const ARCHETYPE_RANGED_FIRE_INTERVAL := 2.6
const ARCHETYPE_RANGED_FIRE_INTERVAL_JITTER := 0.9
const ARCHETYPE_RANGED_SHOT_SPEED := 260.0
const ARCHETYPE_RANGED_SHOT_LIFETIME := 3.2
const ARCHETYPE_RANGED_SHOT_RADIUS := 7.0

const ARCHETYPE_SPLITTER_HEALTH := 1.80
const ARCHETYPE_SPLITTER_SPEED := 0.90
const ARCHETYPE_SPLITTER_DAMAGE := 1.10
const ARCHETYPE_SPLITTER_RADIUS := 1.15
const ARCHETYPE_SPLITTER_XP := 2
const ARCHETYPE_SPLITTER_UNLOCK_MINUTES := 3.5
const ARCHETYPE_SPLITTER_WEIGHT := 1.0
const ARCHETYPE_SPLITTER_CHILD_COUNT := 2
const ARCHETYPE_SPLITTER_CHILD_SCATTER := 26.0

const ARCHETYPE_ELITE_HEALTH := 5.50
const ARCHETYPE_ELITE_SPEED := 1.05
const ARCHETYPE_ELITE_DAMAGE := 1.60
const ARCHETYPE_ELITE_RADIUS := 1.35
const ARCHETYPE_ELITE_XP := 8
const ARCHETYPE_ELITE_UNLOCK_MINUTES := 5.0
const ARCHETYPE_ELITE_WEIGHT := 0.45

const ARCHETYPE_GRUNT_UNLOCK_MINUTES := 0.0
const ARCHETYPE_GRUNT_WEIGHT := 4.0

# Enemy shots live in their own small arrays rather than the shared projectile
# arrays: they only ever test against the player, so keeping them separate
# leaves the player-projectile grid sweep (the hottest loop) untouched.
const ENEMY_SHOT_CAP := 512

const BOSS_HEALTH := 550.0
const BOSS_HEALTH_SCALE_LINEAR := 1.0
const BOSS_HEALTH_SCALE_QUADRATIC := 0.20
const BOSS_HIT_PROTECTION_DURATION := 0.35
const BOSS_HIT_PROTECTION_DAMAGE_MULTIPLIER := 0.20
const BOSS_SPEED := 58.0
const BOSS_SPEED_SCALE_PER_MINUTE := 0.025
const BOSS_DAMAGE := 28.0
const BOSS_RADIUS := 42.0
const BOSS_XP := 20
const FIRST_BOSS_TIME := 45.0
const BOSS_INTERVAL := 90.0

# Multi-phase bosses. Phase is a pure function of the boss's current health
# fraction, so it needs no extra per-entity array: as the fight wears on the
# telegraph shortens, the slam widens, and the boss closes faster. Thresholds
# are upper bounds -- above BOSS_PHASE_TWO_HEALTH the boss is in phase one.
const BOSS_PHASE_TWO_HEALTH := 0.66
const BOSS_PHASE_THREE_HEALTH := 0.33
# Index 0/1/2 = phase one/two/three.
const BOSS_PHASE_TELEGRAPH := [1.10, 0.85, 0.62]
const BOSS_PHASE_ATTACK_INTERVAL := [4.50, 3.40, 2.60]
const BOSS_PHASE_SLAM_RADIUS := [220.0, 252.0, 288.0]
const BOSS_PHASE_SPEED_MULTIPLIER := [1.0, 1.12, 1.26]
const BOSS_ENGAGE_RANGE := 650.0

const HEALTH_PICKUP_HEAL := 0.20
const HEALTH_PICKUP_DROP_CHANCE := 0.006
const CONTACT_DAMAGE_COOLDOWN := 0.20

# Spawn pressure cycles instead of climbing monotonically: a long ramp, a short
# spike, then a collapse that gives the player room to reposition and collect.
# The cycle multiplies the minute-based base rate, so later cycles are harder in
# absolute terms even though the shape repeats. Fractions are points along one
# period and must stay ordered: 0 < RAMP < SPIKE < 1.
const PHASE_PERIOD_SECONDS := 55.0
const PHASE_RAMP_FRACTION := 0.55
const PHASE_SPIKE_FRACTION := 0.80
# The ramp starts at exactly 1.0 so the opening seconds of a run still deliver
# the documented baseline throughput (regression_test.gd guards 16 enemies/sec
# at t=0). Breathing room comes from the collapse window, not from a soft open.
const PHASE_RAMP_START_MULTIPLIER := 1.00
const PHASE_RAMP_END_MULTIPLIER := 1.30
const PHASE_SPIKE_MULTIPLIER := 2.10
const PHASE_COLLAPSE_MULTIPLIER := 0.35

const SURGE_ENTER_COUNT := 5
const SURGE_EXIT_COUNT := 25
const SURGE_MAX_DURATION := 7.0
const SURGE_RAMP_TIME := 3.0
const SURGE_COOLDOWN := 3.0
const SURGE_MAX_SPEED_MULTIPLIER := 2.0
const SURGE_SPEED_FADE_START := 480.0
const SURGE_SPEED_FULL_DISTANCE := 1600.0
const NEARBY_THREAT_RADIUS := 2100.0

const GLOBAL_UPGRADE_IDS := [
    "damage",
    "attack_speed",
    "move_speed",
    "max_health",
    "armor",
    "regen",
]
const GLOBAL_UPGRADE_CAPS := {
    "attack_speed": 8,
}
const ATTACK_SPEED_PER_RANK := 0.08

const LOW_FREQUENCY_UPGRADE_WEIGHT := 0.20
const DPS_UPGRADE_IDS := [
    "damage",
    "attack_speed",
    "needle_homing",
    "needle_projectile_count",
    "aura_echoes",
    "field_duration",
    "chain_jumps",
    "flak_pellets",
    "orbital_count",
    "detonator_blast",
]
const UPGRADE_ROLL_WEIGHTS := {
    "max_health": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "armor": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "regen": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "sniper_range": LOW_FREQUENCY_UPGRADE_WEIGHT,
}

const NEEDLE_UPGRADE_IDS := [
    "needle_homing",
    "needle_projectile_count",
    "needle_pierce",
]

const SNIPER_UPGRADE_IDS := [
    "sniper_pierce",
    "sniper_range",
    "sniper_size",
]

const AURA_UPGRADE_IDS := [
    "aura_radius",
    "aura_echoes",
]

const FIELD_UPGRADE_IDS := [
    "field_radius",
    "field_duration",
]

const CHAIN_UPGRADE_IDS := [
    "chain_jumps",
    "chain_falloff",
    "chain_range",
]

const FLAK_UPGRADE_IDS := [
    "flak_pellets",
    "flak_spread",
    "flak_range",
]

const ORBITAL_UPGRADE_IDS := [
    "orbital_count",
    "orbital_radius",
    "orbital_size",
]

const DETONATOR_UPGRADE_IDS := [
    "detonator_blast",
    "detonator_range",
]

const WEAPON_UPGRADE_IDS := {
    "needle": NEEDLE_UPGRADE_IDS,
    "sniper": SNIPER_UPGRADE_IDS,
    "aura": AURA_UPGRADE_IDS,
    "field": FIELD_UPGRADE_IDS,
    "chain": CHAIN_UPGRADE_IDS,
    "flak": FLAK_UPGRADE_IDS,
    "orbital": ORBITAL_UPGRADE_IDS,
    "detonator": DETONATOR_UPGRADE_IDS,
}

const WEAPON_UPGRADE_CAPS := {
    "needle_homing": 4,
    "needle_projectile_count": 10,
    "needle_pierce": 4,
    "sniper_pierce": 4,
    "sniper_range": 5,
    "sniper_size": 6,
    "aura_radius": 6,
    "aura_echoes": 6,
    "field_radius": 6,
    "field_duration": 6,
    "chain_jumps": 6,
    "chain_falloff": 5,
    "chain_range": 5,
    "flak_pellets": 8,
    "flak_spread": 5,
    "flak_range": 5,
    "orbital_count": 8,
    "orbital_radius": 5,
    "orbital_size": 5,
    "detonator_blast": 6,
    "detonator_range": 5,
}

const WEAPON_UNLOCK_IDS := {
    "unlock_sniper": "sniper",
    "unlock_aura": "aura",
    "unlock_field": "field",
    "unlock_chain": "chain",
    "unlock_flak": "flak",
    "unlock_orbital": "orbital",
    "unlock_detonator": "detonator",
}

const UPGRADE_NAMES := {
    "damage": "Base Damage",
    "attack_speed": "Base Attack Speed",
    "move_speed": "Light Footing",
    "max_health": "Reinforced Core",
    "armor": "Plating",
    "regen": "Recovery",
    "unlock_sniper": "New Weapon — Longshot",
    "unlock_aura": "New Weapon — Aura Pulse",
    "unlock_field": "New Weapon — Mire Field",
    "needle_homing": "Needle — Guidance",
    "needle_projectile_count": "Needle — Split Shot",
    "needle_pierce": "Needle — Piercing Rounds",
    "sniper_pierce": "Longshot — Penetrator",
    "sniper_range": "Longshot — High-Power Optics",
    "sniper_size": "Longshot — Heavy Caliber",
    "aura_radius": "Aura Pulse — Wider Wave",
    "aura_echoes": "Aura Pulse — Echoing Strike",
    "field_radius": "Mire Field — Wider Pool",
    "field_duration": "Mire Field — Lingering Mire",
    "unlock_chain": "New Weapon — Arc Chain",
    "unlock_flak": "New Weapon — Flak Burst",
    "unlock_orbital": "New Weapon — Orbital",
    "unlock_detonator": "New Weapon — Detonator",
    "chain_jumps": "Arc Chain — Extra Arc",
    "chain_falloff": "Arc Chain — Stable Current",
    "chain_range": "Arc Chain — Longer Reach",
    "flak_pellets": "Flak Burst — Dense Payload",
    "flak_spread": "Flak Burst — Tightened Choke",
    "flak_range": "Flak Burst — Longer Pellets",
    "orbital_count": "Orbital — Extra Satellite",
    "orbital_radius": "Orbital — Wider Orbit",
    "orbital_size": "Orbital — Heavier Satellites",
    "detonator_blast": "Detonator — Larger Blast",
    "detonator_range": "Detonator — Longer Throw",
}

const UPGRADE_DESCRIPTIONS := {
    "damage": "+20% damage for all weapons",
    "attack_speed": "+8% all-weapon attack speed; normal cap 8, bosses can overcap",
    "move_speed": "+10% movement speed and proportional camera zoom-out",
    "max_health": "+15% max health and heal the gain",
    "armor": "+10 armor",
    "regen": "+0.5% max health regeneration per second",
    "unlock_sniper": "Equip a slow, powerful long-range projectile weapon",
    "unlock_aura": "Equip a melee pulse that hits every nearby enemy",
    "unlock_field": "Equip persistent slowing damage zones",
    "needle_homing": "+10% Needle homing strength (10/20/30/40%)",
    "needle_projectile_count": "+1 Needle projectile per attack",
    "needle_pierce": "+1 Needle hit budget; bosses consume exactly one (max 4)",
    "sniper_pierce": "+1 Longshot hit budget; bosses consume exactly one (max 4)",
    "sniper_range": "+12% Longshot targeting and travel range",
    "sniper_size": "+45% Longshot collision radius; the projectile visibly grows",
    "aura_radius": "+12% Aura Pulse radius",
    "aura_echoes": "+1 delayed pulse that rechecks enemies in range",
    "field_radius": "+12% Mire Field radius",
    "field_duration": "+0.5 seconds Mire Field duration",
    "unlock_chain": "Equip lightning that jumps between nearby enemies",
    "unlock_flak": "Equip a wide close-range burst of pellets",
    "unlock_orbital": "Equip satellites that circle you and grind contact damage",
    "unlock_detonator": "Equip a shell that explodes on first impact or at its aim point",
    "chain_jumps": "+1 Arc Chain jump",
    "chain_falloff": "+8% damage retained per Arc Chain jump",
    "chain_range": "+12% Arc Chain targeting and jump radius",
    "flak_pellets": "+1 Flak Burst pellet",
    "flak_spread": "-12% Flak Burst cone angle; the firing cone visibly narrows",
    "flak_range": "+15% Flak Burst pellet travel and range",
    "orbital_count": "+1 orbiting satellite",
    "orbital_radius": "+12% Orbital orbit radius",
    "orbital_size": "+20% Orbital satellite size",
    "detonator_blast": "+12% Detonator blast radius",
    "detonator_range": "+12% Detonator throw range"
}
