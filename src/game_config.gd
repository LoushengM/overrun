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
const PLAYER_ONE_SHOT_PROTECTION_THRESHOLD := 0.50
const PLAYER_ONE_SHOT_PROTECTION_HEALTH := 1.0
const PLAYER_ONE_SHOT_PROTECTION_VISUAL_DURATION := 0.80

const WEAPON_SLOT_CAP := 4
const WEAPON_IDS := ["needle", "sniper", "aura", "field"]
const WEAPON_NAMES := {
    "needle": "Needle",
    "sniper": "Longshot",
    "aura": "Aura Pulse",
    "field": "Mire Field",
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

const GAME_PACE_MULTIPLIER := 2.0

const OFFENSE_PITY_MAX_LEVEL := 30
const OFFENSE_PITY_TARGET_TTK := 0.90
const OFFENSE_PITY_SEVERE_RATIO := 0.65
const NEEDLE_EXTRA_PROJECTILE_DPS_FACTOR := 0.50
const AURA_DPS_UPTIME_FACTOR := 0.75
const FIELD_DPS_OVERLAP_FACTOR := 0.35
const FIELD_DPS_MAX_EQUIVALENTS := 2.0

const ENEMY_CAP := 1450
const PROJECTILE_CAP := 16384
const PICKUP_CAP := 40
const BOSS_CAP := 10
const GRID_CELL_SIZE := 96.0
const MAX_SPAWNS_PER_TICK := 24
const MAX_SPAWN_DEBT_SECONDS := 0.50

const NORMAL_ENEMY_HEALTH := 10.0
const NORMAL_ENEMY_SPEED := 85.0
const NORMAL_ENEMY_SPEED_SCALE_PER_MINUTE := 0.05
const NORMAL_ENEMY_SPEED_SCALE_QUADRATIC := 0.003
const NORMAL_ENEMY_DAMAGE := 10.0
const NORMAL_ENEMY_RADIUS := 14.0
const NORMAL_ENEMY_XP := 1

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

const HEALTH_PICKUP_HEAL := 0.20
const HEALTH_PICKUP_DROP_CHANCE := 0.006
const CONTACT_DAMAGE_COOLDOWN := 0.20

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
    "move_speed",
    "max_health",
    "armor",
    "regen",
]

const LOW_FREQUENCY_UPGRADE_WEIGHT := 0.20
const DPS_UPGRADE_IDS := [
    "damage",
    "needle_fire_rate",
    "needle_projectile_count",
    "sniper_fire_rate",
    "aura_fire_rate",
    "aura_echoes",
    "field_fire_rate",
    "field_duration",
]
const UPGRADE_ROLL_WEIGHTS := {
    "max_health": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "armor": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "regen": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "needle_range": LOW_FREQUENCY_UPGRADE_WEIGHT,
    "sniper_range": LOW_FREQUENCY_UPGRADE_WEIGHT,
}

const NEEDLE_UPGRADE_IDS := [
    "needle_fire_rate",
    "needle_projectile_count",
    "needle_pierce",
    "needle_range",
]

const SNIPER_UPGRADE_IDS := [
    "sniper_fire_rate",
    "sniper_pierce",
    "sniper_range",
    "sniper_size",
]

const AURA_UPGRADE_IDS := [
    "aura_fire_rate",
    "aura_radius",
    "aura_echoes",
]

const FIELD_UPGRADE_IDS := [
    "field_fire_rate",
    "field_radius",
    "field_duration",
]

const WEAPON_UPGRADE_IDS := {
    "needle": NEEDLE_UPGRADE_IDS,
    "sniper": SNIPER_UPGRADE_IDS,
    "aura": AURA_UPGRADE_IDS,
    "field": FIELD_UPGRADE_IDS,
}

const WEAPON_UPGRADE_CAPS := {
    "needle_fire_rate": 10,
    "needle_projectile_count": 10,
    "needle_pierce": 10,
    "needle_range": 5,
    "sniper_fire_rate": 8,
    "sniper_pierce": 6,
    "sniper_range": 5,
    "sniper_size": 6,
    "aura_fire_rate": 8,
    "aura_radius": 6,
    "aura_echoes": 6,
    "field_fire_rate": 8,
    "field_radius": 6,
    "field_duration": 6,
}

const WEAPON_UNLOCK_IDS := {
    "unlock_sniper": "sniper",
    "unlock_aura": "aura",
    "unlock_field": "field",
}

const UPGRADE_NAMES := {
    "damage": "Base Damage",
    "move_speed": "Light Footing",
    "max_health": "Reinforced Core",
    "armor": "Plating",
    "regen": "Recovery",
    "unlock_sniper": "New Weapon — Longshot",
    "unlock_aura": "New Weapon — Aura Pulse",
    "unlock_field": "New Weapon — Mire Field",
    "needle_fire_rate": "Needle — Faster Cycling",
    "needle_projectile_count": "Needle — Split Shot",
    "needle_pierce": "Needle — Piercing Rounds",
    "needle_range": "Needle — Extended Barrel",
    "sniper_fire_rate": "Longshot — Bolt Cycling",
    "sniper_pierce": "Longshot — Penetrator",
    "sniper_range": "Longshot — High-Power Optics",
    "sniper_size": "Longshot — Heavy Caliber",
    "aura_fire_rate": "Aura Pulse — Quicker Pulse",
    "aura_radius": "Aura Pulse — Wider Wave",
    "aura_echoes": "Aura Pulse — Echoing Strike",
    "field_fire_rate": "Mire Field — Faster Deployment",
    "field_radius": "Mire Field — Wider Pool",
    "field_duration": "Mire Field — Lingering Mire",
}

const UPGRADE_DESCRIPTIONS := {
    "damage": "+20% damage for all weapons",
    "move_speed": "+10% movement speed and proportional camera zoom-out",
    "max_health": "+15% max health and heal the gain",
    "armor": "+10 armor",
    "regen": "+0.5% max health regeneration per second",
    "unlock_sniper": "Equip a slow, powerful long-range projectile weapon",
    "unlock_aura": "Equip a melee pulse that hits every nearby enemy",
    "unlock_field": "Equip persistent slowing damage zones",
    "needle_fire_rate": "-12% Needle cooldown",
    "needle_projectile_count": "+1 Needle projectile per attack",
    "needle_pierce": "+1 full Needle damage budget",
    "needle_range": "+12% Needle targeting and travel range",
    "sniper_fire_rate": "-10% Longshot cooldown",
    "sniper_pierce": "+1 full Longshot damage budget",
    "sniper_range": "+12% Longshot targeting and travel range",
    "sniper_size": "+45% Longshot projectile size",
    "aura_fire_rate": "-10% Aura Pulse cooldown",
    "aura_radius": "+12% Aura Pulse radius",
    "aura_echoes": "+1 delayed pulse that rechecks enemies in range",
    "field_fire_rate": "-10% Mire Field deployment cooldown",
    "field_radius": "+12% Mire Field radius",
    "field_duration": "+0.5 seconds Mire Field duration",
}
