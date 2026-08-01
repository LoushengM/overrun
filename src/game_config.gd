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

const WEAPON_DAMAGE := 10.0
const WEAPON_COOLDOWN := 0.60
const WEAPON_PROJECTILES := 1
const WEAPON_SPEED := 900.0
const WEAPON_LIFETIME := 1.5
const WEAPON_RANGE := 1200.0
const WEAPON_RADIUS := 6.0
const WEAPON_PIERCE := 0
const DAMAGE_PITY_SHOTS_TO_KILL := 1.50

const ENEMY_CAP := 1450
const PROJECTILE_CAP := 16384
const PICKUP_CAP := 40
const BOSS_CAP := 10
const GRID_CELL_SIZE := 96.0
const MAX_SPAWNS_PER_TICK := 12
const MAX_SPAWN_DEBT_SECONDS := 0.50

const NORMAL_ENEMY_HEALTH := 10.0
const NORMAL_ENEMY_SPEED := 85.0
const NORMAL_ENEMY_DAMAGE := 10.0
const NORMAL_ENEMY_RADIUS := 14.0
const NORMAL_ENEMY_XP := 1

const BOSS_HEALTH := 550.0
const BOSS_SPEED := 58.0
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
const NEARBY_THREAT_RADIUS := 2100.0

const UPGRADE_IDS := [
    "damage",
    "fire_rate",
    "projectile_count",
    "pierce",
    "move_speed",
    "max_health",
    "armor",
    "regen",
    "pickup_radius",
]

const UPGRADE_NAMES := {
    "damage": "Sharpened Rounds",
    "fire_rate": "Faster Cycling",
    "projectile_count": "Split Shot",
    "pierce": "Piercing Rounds",
    "move_speed": "Light Footing",
    "max_health": "Reinforced Core",
    "armor": "Plating",
    "regen": "Recovery",
    "pickup_radius": "Field Magnet",
}

const UPGRADE_DESCRIPTIONS := {
    "damage": "+20% weapon damage",
    "fire_rate": "-12% weapon cooldown",
    "projectile_count": "+1 projectile per attack",
    "pierce": "Adds one full projectile damage budget",
    "move_speed": "+10% movement speed",
    "max_health": "+15% max health and heal the gain",
    "armor": "+10 armor",
    "regen": "+0.5% max health regeneration per second",
    "pickup_radius": "+25% pickup radius",
}
