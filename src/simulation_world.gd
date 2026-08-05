class_name SimulationWorld
extends Node2D

signal stats_updated(stats: Dictionary)
signal level_up_requested(options: Array[String])
signal boss_upgrade_requested(options: Array[String])
signal run_ended(summary: Dictionary)
signal boss_spawned
signal sound_requested(cue: String)

const SPRITE_ATLAS_PATH := "res://assets/robots.png"
const SPRITE_ATLAS_COLUMNS := 4
const SPRITE_ATLAS_ROWS := 2
const SPRITE_FRAME_COUNT := SPRITE_ATLAS_COLUMNS * SPRITE_ATLAS_ROWS

enum EnemyKind { NORMAL, BOSS }
enum EnemyArchetype { GRUNT, SWARMER, SHIELDED, RANGED, SPLITTER, ELITE }
const ARCHETYPE_COUNT := 6
enum ProjectileKind { NEEDLE, SNIPER, FLAK }
enum TargetingMode { CLOSEST, STRONGEST }

@onready var camera: Camera2D = $Camera2D

var rng := RandomNumberGenerator.new()
var benchmark_mode := false
var is_running := false
var pending_upgrade := false
var pending_boss_rewards := 0
var targeting_mode: int = TargetingMode.CLOSEST

var elapsed_time := 0.0
var kills := 0
var level := 1
var xp := 0
var xp_required := 8

var player_position := Vector2.ZERO
var player_move_direction := Vector2.ZERO
var player_health := GameConfig.PLAYER_MAX_HEALTH
var player_max_health := GameConfig.PLAYER_MAX_HEALTH
var player_armor := GameConfig.PLAYER_ARMOR
var player_move_speed := GameConfig.PLAYER_MOVE_SPEED
var player_regen_rate := GameConfig.PLAYER_REGEN_RATE
var player_regen_ceiling := GameConfig.PLAYER_REGEN_CEILING
var player_regen_delay := GameConfig.PLAYER_REGEN_DELAY
var player_pickup_radius := GameConfig.PLAYER_PICKUP_RADIUS
var time_since_player_damage := 999.0
var player_contact_cooldown := 0.0
var player_invulnerability_timer := 0.0
var player_one_shot_protection_timer := 0.0

# Chosen on the select screen before a run starts. reset_run applies it after the
# baselines are written, so character multipliers always overwrite defaults
# rather than the other way around.
var selected_character := GameConfig.DEFAULT_CHARACTER_ID
var character_xp_gain := 1.0

# `weapon_damage` is the uncapped global damage stat expressed in Needle base
# damage units. Every weapon scales by weapon_damage / NEEDLE_DAMAGE.
var weapon_damage := GameConfig.WEAPON_DAMAGE
var owned_weapons: Array[String] = ["needle"]
var weapon_upgrade_levels: Dictionary = {}

var weapon_cooldown := GameConfig.NEEDLE_COOLDOWN
var weapon_projectile_count := GameConfig.NEEDLE_PROJECTILES
var weapon_speed := GameConfig.NEEDLE_SPEED
var weapon_lifetime := GameConfig.NEEDLE_LIFETIME
var weapon_range := GameConfig.NEEDLE_RANGE
var weapon_radius := GameConfig.NEEDLE_RADIUS
var weapon_pierce := GameConfig.NEEDLE_PIERCE
var needle_timer := 0.15

var sniper_cooldown := GameConfig.SNIPER_COOLDOWN
var sniper_range := GameConfig.SNIPER_RANGE
var sniper_lifetime := GameConfig.SNIPER_LIFETIME
var sniper_pierce := GameConfig.SNIPER_PIERCE
var sniper_radius := GameConfig.SNIPER_RADIUS
var sniper_timer := 0.35

var aura_cooldown := GameConfig.AURA_COOLDOWN
var aura_radius := GameConfig.AURA_RADIUS
var aura_echoes := GameConfig.AURA_ECHOES
var aura_timer := 0.50
var aura_echoes_remaining := 0
var aura_echo_timer := 0.0
var aura_visual_timer := 0.0

var field_cooldown := GameConfig.FIELD_COOLDOWN
var field_radius := GameConfig.FIELD_RADIUS
var field_duration := GameConfig.FIELD_DURATION
var field_timer := 0.70
var field_spawn_angle := 0.0

var chain_cooldown := GameConfig.CHAIN_COOLDOWN
var chain_range := GameConfig.CHAIN_RANGE
var chain_jumps := GameConfig.CHAIN_JUMPS
var chain_jump_radius := GameConfig.CHAIN_JUMP_RADIUS
var chain_falloff := GameConfig.CHAIN_FALLOFF
var chain_timer := 0.45
var chain_visual_timer := 0.0
# Reused across chain casts so a jump walk never allocates in the hot path.
var chain_visual_points: Array[Vector2] = []
var chain_hit_scratch: Array[int] = []

var flak_cooldown := GameConfig.FLAK_COOLDOWN
var flak_pellets := GameConfig.FLAK_PELLETS
var flak_spread := deg_to_rad(GameConfig.FLAK_SPREAD_DEGREES)
var flak_range := GameConfig.FLAK_RANGE
var flak_lifetime := GameConfig.FLAK_LIFETIME
var flak_timer := 0.25

var orbital_count := GameConfig.ORBITAL_COUNT
var orbital_radius := GameConfig.ORBITAL_RADIUS
var orbital_angular_speed := GameConfig.ORBITAL_ANGULAR_SPEED
var orbital_hit_radius := GameConfig.ORBITAL_HIT_RADIUS
var orbital_hit_interval := GameConfig.ORBITAL_HIT_INTERVAL
var orbital_angle := 0.0
# Orbitals keep their own arrays: the shared projectile sweep advances entries
# by velocity and tests them as line segments, which an angular orbit would
# read as a teleport across the torus.
var orbital_positions: Array[Vector2] = []
var orbital_hit_timers: Array[float] = []

var detonator_cooldown := GameConfig.DETONATOR_COOLDOWN
var detonator_range := GameConfig.DETONATOR_RANGE
var detonator_blast_radius := GameConfig.DETONATOR_BLAST_RADIUS
var detonator_timer := 0.90
# Shells fly on their own arrays and detonate on arrival rather than riding the
# shared projectile sweep, which resolves damage at the point of contact and
# would leave no place to hang an area blast.
var detonator_shell_positions: Array[Vector2] = []
var detonator_shell_velocities: Array[Vector2] = []
var detonator_shell_remaining: Array[float] = []
var detonator_shell_lifetimes: Array[float] = []
var detonator_blast_positions: Array[Vector2] = []
var detonator_blast_radii: Array[float] = []
var detonator_blast_timers: Array[float] = []

var next_attack_id := 1

var enemy_positions: Array[Vector2] = []
var enemy_health: Array[float] = []
var enemy_max_health: Array[float] = []
var enemy_speeds: Array[float] = []
var enemy_damage: Array[float] = []
var enemy_radii: Array[float] = []
var enemy_xp: Array[int] = []
var enemy_kinds: Array[int] = []
var enemy_archetypes: Array[int] = []
var enemy_fire_timers: Array[float] = []
var enemy_shot_positions: Array[Vector2] = []
var enemy_shot_velocities: Array[Vector2] = []
var enemy_shot_lifetimes: Array[float] = []
var enemy_shot_damage: Array[float] = []
var pending_split_positions: Array[Vector2] = []
var pending_split_health: Array[float] = []
var enemy_sprite_frames: Array[int] = []
var enemy_last_hit_attack: Array[int] = []
var enemy_reserved_damage: Array[float] = []
var enemy_anchors: Array[Vector2] = []
var enemy_boss_attack_timer: Array[float] = []
var enemy_boss_telegraph: Array[float] = []
var enemy_boss_hit_protection_timer: Array[float] = []

var projectile_positions: Array[Vector2] = []
var projectile_velocities: Array[Vector2] = []
var projectile_lifetimes: Array[float] = []
var projectile_remaining_damage: Array[float] = []
var projectile_attack_ids: Array[int] = []
var projectile_radii: Array[float] = []
var projectile_kinds: Array[int] = []

var field_positions: Array[Vector2] = []
var field_lifetimes: Array[float] = []
var field_tick_timers: Array[float] = []
var field_radii: Array[float] = []

var projectile_candidate_targets: Array[int] = []
var projectile_candidate_fractions: Array[float] = []

var pickup_positions: Array[Vector2] = []

var hit_targets: Array[int] = []
var hit_damage: Array[float] = []
var enemy_grid: Dictionary = {}
var grid_bucket_pool: Array = []

var normal_enemy_multimesh: MultiMesh
var projectile_multimesh: MultiMesh
var circle_texture: Texture2D
var sprite_atlas_texture: Texture2D
var enemy_sprite_material: ShaderMaterial

var spawn_accumulator := 0.0
var nearby_threat := 0
var threat_check_timer := 0.0
var surge_active := false
var surge_time := 0.0
var surge_cooldown := 0.0
var next_boss_time := GameConfig.FIRST_BOSS_TIME
var stats_timer := 0.0
var benchmark_reported := false

var golomb_cache: Array[int] = [0, 1]


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    rng.randomize()
    camera.enabled = true
    _setup_batched_rendering()


func reset_run() -> void:
    enemy_positions.clear()
    enemy_health.clear()
    enemy_max_health.clear()
    enemy_speeds.clear()
    enemy_damage.clear()
    enemy_radii.clear()
    enemy_xp.clear()
    enemy_kinds.clear()
    enemy_archetypes.clear()
    enemy_fire_timers.clear()
    enemy_shot_positions.clear()
    enemy_shot_velocities.clear()
    enemy_shot_lifetimes.clear()
    enemy_shot_damage.clear()
    pending_split_positions.clear()
    pending_split_health.clear()
    enemy_sprite_frames.clear()
    enemy_last_hit_attack.clear()
    enemy_reserved_damage.clear()
    enemy_anchors.clear()
    enemy_boss_attack_timer.clear()
    enemy_boss_telegraph.clear()
    enemy_boss_hit_protection_timer.clear()

    projectile_positions.clear()
    projectile_velocities.clear()
    projectile_lifetimes.clear()
    projectile_remaining_damage.clear()
    projectile_attack_ids.clear()
    projectile_radii.clear()
    projectile_kinds.clear()
    field_positions.clear()
    field_lifetimes.clear()
    field_tick_timers.clear()
    field_radii.clear()
    projectile_candidate_targets.clear()
    projectile_candidate_fractions.clear()
    pickup_positions.clear()
    hit_targets.clear()
    hit_damage.clear()
    _release_grid_buckets()
    enemy_grid.clear()

    benchmark_mode = false
    benchmark_reported = false
    is_running = true
    pending_upgrade = false
    pending_boss_rewards = 0
    targeting_mode = TargetingMode.CLOSEST
    elapsed_time = 0.0
    kills = 0
    level = 1
    xp = 0
    xp_required = xp_required_for(level)

    player_position = Vector2.ZERO
    player_move_direction = Vector2.ZERO
    player_health = GameConfig.PLAYER_MAX_HEALTH
    player_max_health = GameConfig.PLAYER_MAX_HEALTH
    player_armor = GameConfig.PLAYER_ARMOR
    player_move_speed = GameConfig.PLAYER_MOVE_SPEED
    player_regen_rate = GameConfig.PLAYER_REGEN_RATE
    player_regen_ceiling = GameConfig.PLAYER_REGEN_CEILING
    player_regen_delay = GameConfig.PLAYER_REGEN_DELAY
    player_pickup_radius = GameConfig.PLAYER_PICKUP_RADIUS
    time_since_player_damage = 999.0
    player_contact_cooldown = 0.0
    player_invulnerability_timer = 0.0
    player_one_shot_protection_timer = 0.0

    weapon_damage = GameConfig.NEEDLE_DAMAGE
    owned_weapons.assign(["needle"])
    weapon_upgrade_levels.clear()
    for weapon_id in GameConfig.WEAPON_IDS:
        var upgrade_ids: Array = GameConfig.WEAPON_UPGRADE_IDS.get(weapon_id, [])
        for upgrade_id in upgrade_ids:
            weapon_upgrade_levels[upgrade_id] = 0

    weapon_cooldown = GameConfig.NEEDLE_COOLDOWN
    weapon_projectile_count = GameConfig.NEEDLE_PROJECTILES
    weapon_speed = GameConfig.NEEDLE_SPEED
    weapon_lifetime = GameConfig.NEEDLE_LIFETIME
    weapon_range = GameConfig.NEEDLE_RANGE
    weapon_radius = GameConfig.NEEDLE_RADIUS
    weapon_pierce = GameConfig.NEEDLE_PIERCE
    needle_timer = 0.15

    sniper_cooldown = GameConfig.SNIPER_COOLDOWN
    sniper_range = GameConfig.SNIPER_RANGE
    sniper_lifetime = GameConfig.SNIPER_LIFETIME
    sniper_pierce = GameConfig.SNIPER_PIERCE
    sniper_radius = GameConfig.SNIPER_RADIUS
    sniper_timer = 0.35

    aura_cooldown = GameConfig.AURA_COOLDOWN
    aura_radius = GameConfig.AURA_RADIUS
    aura_echoes = GameConfig.AURA_ECHOES
    aura_timer = 0.50
    aura_echoes_remaining = 0
    aura_echo_timer = 0.0
    aura_visual_timer = 0.0

    field_cooldown = GameConfig.FIELD_COOLDOWN
    field_radius = GameConfig.FIELD_RADIUS
    field_duration = GameConfig.FIELD_DURATION
    field_timer = 0.70
    field_spawn_angle = 0.0

    chain_cooldown = GameConfig.CHAIN_COOLDOWN
    chain_range = GameConfig.CHAIN_RANGE
    chain_jumps = GameConfig.CHAIN_JUMPS
    chain_jump_radius = GameConfig.CHAIN_JUMP_RADIUS
    chain_falloff = GameConfig.CHAIN_FALLOFF
    chain_timer = 0.45
    chain_visual_timer = 0.0
    chain_visual_points.clear()
    chain_hit_scratch.clear()

    flak_cooldown = GameConfig.FLAK_COOLDOWN
    flak_pellets = GameConfig.FLAK_PELLETS
    flak_spread = deg_to_rad(GameConfig.FLAK_SPREAD_DEGREES)
    flak_range = GameConfig.FLAK_RANGE
    flak_lifetime = GameConfig.FLAK_LIFETIME
    flak_timer = 0.25

    orbital_count = GameConfig.ORBITAL_COUNT
    orbital_radius = GameConfig.ORBITAL_RADIUS
    orbital_angular_speed = GameConfig.ORBITAL_ANGULAR_SPEED
    orbital_hit_radius = GameConfig.ORBITAL_HIT_RADIUS
    orbital_hit_interval = GameConfig.ORBITAL_HIT_INTERVAL
    orbital_angle = 0.0
    orbital_positions.clear()
    orbital_hit_timers.clear()

    detonator_cooldown = GameConfig.DETONATOR_COOLDOWN
    detonator_range = GameConfig.DETONATOR_RANGE
    detonator_blast_radius = GameConfig.DETONATOR_BLAST_RADIUS
    detonator_timer = 0.90
    detonator_shell_positions.clear()
    detonator_shell_velocities.clear()
    detonator_shell_remaining.clear()
    detonator_shell_lifetimes.clear()
    detonator_blast_positions.clear()
    detonator_blast_radii.clear()
    detonator_blast_timers.clear()

    next_attack_id = 1

    _apply_character()

    spawn_accumulator = 0.0
    nearby_threat = 0
    threat_check_timer = 0.0
    surge_active = true
    surge_time = 0.0
    surge_cooldown = 0.0
    next_boss_time = GameConfig.FIRST_BOSS_TIME
    stats_timer = 0.0

    camera.position = player_position
    _update_camera_zoom()
    for i in range(16):
        _spawn_normal_enemy()

    _emit_stats()
    _update_render_batches()
    queue_redraw()


# Overlays the selected operator on top of the baselines written by reset_run.
# Everything is read from GameConfig.CHARACTERS, so adding an operator requires
# no change in this file.
func _apply_character() -> void:
    character_xp_gain = 1.0
    var data: Dictionary = GameConfig.CHARACTERS.get(selected_character, {})
    if data.is_empty():
        return

    player_max_health = GameConfig.PLAYER_MAX_HEALTH * float(data.get("health", 1.0))
    player_health = player_max_health
    player_move_speed = GameConfig.PLAYER_MOVE_SPEED * float(data.get("speed", 1.0))
    player_armor = GameConfig.PLAYER_ARMOR + float(data.get("armor_bonus", 0.0))
    player_regen_rate = GameConfig.PLAYER_REGEN_RATE * float(data.get("regen", 1.0))
    player_pickup_radius = GameConfig.PLAYER_PICKUP_RADIUS * float(data.get("pickup_radius", 1.0))
    weapon_damage = GameConfig.NEEDLE_DAMAGE * float(data.get("damage", 1.0))
    character_xp_gain = float(data.get("xp_gain", 1.0))

    sniper_pierce += int(data.get("sniper_pierce_bonus", 0))
    field_duration *= float(data.get("field_duration_scale", 1.0))

    var starting_weapon := str(data.get("weapon", ""))
    if not starting_weapon.is_empty() and not owned_weapons.has(starting_weapon):
        owned_weapons.append(starting_weapon)

    _update_camera_zoom()


func select_character(character_id: String) -> void:
    if GameConfig.CHARACTERS.has(character_id):
        selected_character = character_id


# The default loadout is the original four weapons, which keeps the headline
# benchmark number comparable across commits. Passing the expanded roster
# instead exercises the four newer weapons, whose cues fire far more often --
# Orbital in particular can contact once per satellite per interval.
func enable_benchmark(expanded_loadout: bool = false) -> void:
    benchmark_mode = true
    player_health = 1000000.0
    player_max_health = 1000000.0
    weapon_damage = 25.0
    if expanded_loadout:
        owned_weapons.assign(["chain", "flak", "orbital", "detonator"])
    else:
        owned_weapons.assign(["needle", "sniper", "aura", "field"])
    weapon_cooldown = 0.07
    weapon_projectile_count = 10
    weapon_pierce = 5
    sniper_cooldown = 0.55
    sniper_pierce = 3
    aura_cooldown = 0.85
    aura_echoes = 3
    field_cooldown = 0.75
    field_duration = 5.5
    # Push the new weapons to their upgraded ceilings so the run measures the
    # worst case: maximum fire rate, maximum satellite count, maximum shells.
    chain_cooldown = 0.18
    chain_jumps = 6
    flak_cooldown = 0.20
    flak_pellets = 12
    orbital_count = 8
    orbital_hit_interval = 0.25
    detonator_cooldown = 0.45
    enemy_positions.clear()
    enemy_health.clear()
    enemy_max_health.clear()
    enemy_speeds.clear()
    enemy_damage.clear()
    enemy_radii.clear()
    enemy_xp.clear()
    enemy_kinds.clear()
    enemy_archetypes.clear()
    enemy_fire_timers.clear()
    enemy_shot_positions.clear()
    enemy_shot_velocities.clear()
    enemy_shot_lifetimes.clear()
    enemy_shot_damage.clear()
    pending_split_positions.clear()
    pending_split_health.clear()
    enemy_sprite_frames.clear()
    enemy_last_hit_attack.clear()
    enemy_reserved_damage.clear()
    enemy_anchors.clear()
    enemy_boss_attack_timer.clear()
    enemy_boss_telegraph.clear()
    enemy_boss_hit_protection_timer.clear()
    for i in range(1200):
        var angle := rng.randf_range(0.0, TAU)
        var distance := rng.randf_range(380.0, 1800.0)
        _add_enemy(
            WorldSpace.wrap_position(player_position + Vector2.from_angle(angle) * distance),
            GameConfig.NORMAL_ENEMY_HEALTH * 8.0,
            GameConfig.NORMAL_ENEMY_SPEED,
            0.0,
            GameConfig.NORMAL_ENEMY_RADIUS,
            GameConfig.NORMAL_ENEMY_XP,
            EnemyKind.NORMAL,
            Vector2.ZERO
        )
    _emit_stats()
    _update_render_batches()


func _physics_process(delta: float) -> void:
    if not is_running:
        queue_redraw()
        return

    elapsed_time += delta
    time_since_player_damage += delta
    player_contact_cooldown = maxf(0.0, player_contact_cooldown - delta)
    player_invulnerability_timer = maxf(0.0, player_invulnerability_timer - delta)
    player_one_shot_protection_timer = maxf(0.0, player_one_shot_protection_timer - delta)
    surge_cooldown = maxf(0.0, surge_cooldown - delta)

    _update_player(delta)
    _update_enemies(delta)
    _update_enemy_shots(delta)
    if not is_running:
        _emit_stats()
        queue_redraw()
        return

    _rebuild_enemy_grid()
    hit_targets.clear()
    hit_damage.clear()
    _update_weapons(delta)
    _update_fields(delta)
    _update_projectiles(delta)
    _resolve_hits()
    _process_deaths()
    _update_pickups()
    _update_regeneration(delta)
    _update_spawning(delta)
    _update_boss_schedule()
    _check_boss_reward()
    _check_level_up()

    camera.position = player_position
    stats_timer += delta
    if stats_timer >= 0.10:
        stats_timer = 0.0
        _emit_stats()
    _update_render_batches()
    queue_redraw()


func _update_player(delta: float) -> void:
    if benchmark_mode:
        player_move_direction = Vector2.ZERO
        return

    var direction := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.y += 1.0
    player_move_direction = direction.normalized()
    player_position = WorldSpace.wrap_position(
        player_position + player_move_direction * player_move_speed * delta
    )


func _update_enemies(delta: float) -> void:
    var touched_player := false
    for i in range(enemy_positions.size()):
        var position := enemy_positions[i]
        var direction := Vector2.ZERO
        var to_player := WorldSpace.delta(position, player_position)
        var distance_squared_to_player := to_player.length_squared()
        var distance_to_player := sqrt(distance_squared_to_player)

        if enemy_kinds[i] == EnemyKind.BOSS:
            enemy_boss_hit_protection_timer[i] = maxf(0.0, enemy_boss_hit_protection_timer[i] - delta)
            var anchor := enemy_anchors[i]
            if WorldSpace.distance(player_position, anchor) > 1600.0:
                if WorldSpace.distance(position, anchor) > 24.0:
                    direction = WorldSpace.direction(position, anchor)
            else:
                direction = WorldSpace.direction(position, player_position)

            if enemy_boss_telegraph[i] > 0.0:
                var previous_telegraph := enemy_boss_telegraph[i]
                enemy_boss_telegraph[i] = maxf(0.0, previous_telegraph - delta)
                if previous_telegraph > 0.0 and enemy_boss_telegraph[i] <= 0.0:
                    if distance_to_player <= 220.0:
                        _apply_player_damage(enemy_damage[i], true)
            elif distance_to_player <= 650.0:
                enemy_boss_attack_timer[i] -= delta
                if enemy_boss_attack_timer[i] <= 0.0:
                    enemy_boss_telegraph[i] = 1.1
                    enemy_boss_attack_timer[i] = 4.5
                    _request_sound("boss_telegraph")
        else:
            if distance_to_player > 0.001:
                direction = to_player / distance_to_player
            if enemy_archetypes[i] == EnemyArchetype.RANGED:
                if distance_to_player < GameConfig.ARCHETYPE_RANGED_STANDOFF:
                    direction = -direction
                enemy_fire_timers[i] -= delta
                if enemy_fire_timers[i] <= 0.0:
                    enemy_fire_timers[i] = (
                        GameConfig.ARCHETYPE_RANGED_FIRE_INTERVAL
                        + rng.randf_range(0.0, GameConfig.ARCHETYPE_RANGED_FIRE_INTERVAL_JITTER)
                    )
                    if distance_to_player <= GameConfig.ARCHETYPE_RANGED_STANDOFF * 2.0 and distance_to_player > 0.001:
                        _spawn_enemy_shot(position, to_player / distance_to_player, enemy_damage[i])

        var movement_multiplier := _current_boss_speed_scale() if enemy_kinds[i] == EnemyKind.BOSS else _current_normal_speed_scale()
        if enemy_kinds[i] == EnemyKind.NORMAL:
            movement_multiplier *= _surge_speed_multiplier(distance_to_player)
        movement_multiplier *= _field_slow_multiplier_at(position)
        enemy_positions[i] = WorldSpace.wrap_position(
            position + direction * enemy_speeds[i] * movement_multiplier * delta
        )

        if not touched_player and player_contact_cooldown <= 0.0:
            var combined_radius := GameConfig.PLAYER_RADIUS + enemy_radii[i]
            if WorldSpace.distance_squared(enemy_positions[i], player_position) <= combined_radius * combined_radius:
                _apply_player_damage(enemy_damage[i], false)
                touched_player = true
                if not is_running:
                    return


func _update_weapons(delta: float) -> void:
    aura_visual_timer = maxf(0.0, aura_visual_timer - delta)
    _update_needle(delta)
    if _has_weapon("sniper"):
        _update_sniper(delta)
    if _has_weapon("aura"):
        _update_aura(delta)
    if _has_weapon("field"):
        _update_field_launcher(delta)
    if _has_weapon("chain"):
        _update_chain(delta)
    if _has_weapon("flak"):
        _update_flak(delta)
    if _has_weapon("orbital"):
        _update_orbitals(delta)
    if _has_weapon("detonator"):
        _update_detonator(delta)
    _update_detonator_shells(delta)
    _update_detonator_blasts(delta)


func _update_needle(delta: float) -> void:
    needle_timer -= delta
    if needle_timer > 0.0:
        return

    var target_index := _find_target_enemy(player_position, weapon_range)
    if target_index < 0:
        needle_timer = 0.08
        return

    var target_direction := WorldSpace.direction(player_position, enemy_positions[target_index])
    var count := maxi(1, weapon_projectile_count)
    var projectile_count_before := projectile_positions.size()
    var spread_step := deg_to_rad(8.0)
    var start_offset := -spread_step * float(count - 1) * 0.5
    for i in range(count):
        if projectile_positions.size() >= GameConfig.PROJECTILE_CAP:
            break
        _spawn_projectile(
            target_direction.rotated(start_offset + spread_step * float(i)),
            weapon_damage * float(weapon_pierce + 1),
            weapon_speed,
            weapon_lifetime,
            weapon_radius,
            ProjectileKind.NEEDLE
        )
    if projectile_positions.size() > projectile_count_before:
        _request_sound("needle_fire")
    needle_timer += maxf(0.05, weapon_cooldown)


func _update_sniper(delta: float) -> void:
    sniper_timer -= delta
    if sniper_timer > 0.0:
        return

    var target_index := _find_target_enemy(player_position, sniper_range)
    if target_index < 0:
        sniper_timer = 0.10
        return

    var damage_budget := _scaled_weapon_damage(GameConfig.SNIPER_DAMAGE) * float(sniper_pierce + 1)
    var projectile_count_before := projectile_positions.size()
    _spawn_projectile(
        WorldSpace.direction(player_position, enemy_positions[target_index]),
        damage_budget,
        GameConfig.SNIPER_SPEED,
        sniper_lifetime,
        sniper_radius,
        ProjectileKind.SNIPER
    )
    if projectile_positions.size() > projectile_count_before:
        _request_sound("longshot_fire")
    sniper_timer += maxf(0.15, sniper_cooldown)


func _update_aura(delta: float) -> void:
    aura_timer -= delta

    if aura_echoes_remaining > 0:
        aura_echo_timer -= delta
        while aura_echoes_remaining > 0 and aura_echo_timer <= 0.0:
            _emit_aura_pulse(false)
            aura_echoes_remaining -= 1
            aura_echo_timer += GameConfig.AURA_ECHO_INTERVAL
        if aura_echoes_remaining > 0:
            return

    if aura_timer > 0.0:
        return
    if _find_nearest_enemy(player_position, aura_radius) < 0:
        aura_timer = 0.08
        return

    _emit_aura_pulse()
    aura_echoes_remaining = aura_echoes
    aura_echo_timer = GameConfig.AURA_ECHO_INTERVAL
    aura_timer += maxf(0.20, aura_cooldown)


func _emit_aura_pulse(play_sound := true) -> void:
    var damage_instance := _scaled_weapon_damage(GameConfig.AURA_DAMAGE)
    for enemy_index in range(enemy_positions.size()):
        if enemy_health[enemy_index] - enemy_reserved_damage[enemy_index] <= 0.0:
            continue
        var combined_radius := aura_radius + enemy_radii[enemy_index]
        if WorldSpace.distance_squared(player_position, enemy_positions[enemy_index]) > combined_radius * combined_radius:
            continue
        _queue_fixed_damage(enemy_index, damage_instance)
    aura_visual_timer = GameConfig.AURA_VISUAL_DURATION
    if play_sound:
        _request_sound("aura_pulse")


func _update_field_launcher(delta: float) -> void:
    field_timer -= delta
    if field_timer > 0.0:
        return
    _spawn_field()
    field_timer += maxf(0.20, field_cooldown)


func _spawn_field() -> void:
    if field_positions.size() >= GameConfig.FIELD_CAP:
        _remove_field(0)
    var position := WorldSpace.wrap_position(
        player_position + Vector2.from_angle(field_spawn_angle) * GameConfig.FIELD_PLACEMENT_RADIUS
    )
    field_spawn_angle = fposmod(field_spawn_angle + 2.399963229728653, TAU)
    field_positions.append(position)
    field_lifetimes.append(field_duration)
    field_tick_timers.append(0.0)
    field_radii.append(field_radius)
    _request_sound("mire_deploy")


func _update_fields(delta: float) -> void:
    for field_index in range(field_positions.size() - 1, -1, -1):
        field_lifetimes[field_index] -= delta
        field_tick_timers[field_index] -= delta
        if field_lifetimes[field_index] <= 0.0:
            _remove_field(field_index)
            continue
        if field_tick_timers[field_index] > 0.0:
            continue

        field_tick_timers[field_index] += GameConfig.FIELD_TICK_INTERVAL
        var damage_instance := _scaled_weapon_damage(GameConfig.FIELD_DAMAGE)
        var radius := field_radii[field_index]
        for enemy_index in range(enemy_positions.size()):
            if enemy_health[enemy_index] - enemy_reserved_damage[enemy_index] <= 0.0:
                continue
            var combined_radius := radius + enemy_radii[enemy_index]
            if WorldSpace.distance_squared(field_positions[field_index], enemy_positions[enemy_index]) <= combined_radius * combined_radius:
                _queue_fixed_damage(enemy_index, damage_instance)


# Arc Chain resolves entirely through the fixed-damage queue: one cast walks a
# short chain of neighbours, so cost scales with jump count rather than with
# projectile population.
func _update_chain(delta: float) -> void:
    chain_visual_timer = maxf(0.0, chain_visual_timer - delta)
    chain_timer -= delta
    if chain_timer > 0.0:
        return

    var target_index := _find_target_enemy(player_position, chain_range)
    if target_index < 0:
        chain_timer = 0.10
        return

    chain_visual_points.clear()
    chain_hit_scratch.clear()
    chain_visual_points.append(player_position)

    var damage_instance := _scaled_weapon_damage(GameConfig.CHAIN_DAMAGE)
    var current_index := target_index
    var jump_budget := mini(chain_jumps, GameConfig.CHAIN_MAX_JUMPS)
    for jump in range(jump_budget + 1):
        if current_index < 0:
            break
        _queue_fixed_damage(current_index, damage_instance)
        chain_hit_scratch.append(current_index)
        chain_visual_points.append(enemy_positions[current_index])
        damage_instance *= chain_falloff
        current_index = _find_chain_jump_target(enemy_positions[current_index])

    chain_visual_timer = GameConfig.CHAIN_VISUAL_DURATION
    _request_sound("chain_arc")
    chain_timer += maxf(0.20, chain_cooldown)


func _find_chain_jump_target(origin: Vector2) -> int:
    var best_index := -1
    var best_distance_squared := chain_jump_radius * chain_jump_radius
    for i in range(enemy_positions.size()):
        if enemy_health[i] - enemy_reserved_damage[i] <= 0.0:
            continue
        if chain_hit_scratch.has(i):
            continue
        var distance_squared := WorldSpace.distance_squared(origin, enemy_positions[i])
        if distance_squared < best_distance_squared:
            best_distance_squared = distance_squared
            best_index = i
    return best_index


# Flak pellets are ordinary short-lived projectiles, so they ride the shared
# projectile arrays and cost nothing extra in the sweep.
func _update_flak(delta: float) -> void:
    flak_timer -= delta
    if flak_timer > 0.0:
        return

    var target_index := _find_target_enemy(player_position, flak_range)
    if target_index < 0:
        flak_timer = 0.10
        return

    var base_direction := WorldSpace.direction(player_position, enemy_positions[target_index])
    var pellet_count := maxi(1, flak_pellets)
    var damage_instance := _scaled_weapon_damage(GameConfig.FLAK_DAMAGE)
    var step := 0.0
    var start_offset := 0.0
    if pellet_count > 1:
        step = flak_spread / float(pellet_count - 1)
        start_offset = -flak_spread * 0.5
    var projectile_count_before := projectile_positions.size()
    for i in range(pellet_count):
        if projectile_positions.size() >= GameConfig.PROJECTILE_CAP:
            break
        _spawn_projectile(
            base_direction.rotated(start_offset + step * float(i)),
            damage_instance,
            GameConfig.FLAK_SPEED,
            flak_lifetime,
            GameConfig.FLAK_RADIUS,
            ProjectileKind.FLAK
        )
    if projectile_positions.size() > projectile_count_before:
        _request_sound("flak_fire")
    flak_timer += maxf(0.15, flak_cooldown)


# Satellites are repositioned from an angle each frame; the enemy scan only runs
# for a satellite whose contact timer has expired, so idle orbitals are free.
func _update_orbitals(delta: float) -> void:
    var desired := clampi(orbital_count, 0, GameConfig.ORBITAL_CAP)
    while orbital_positions.size() < desired:
        orbital_positions.append(player_position)
        orbital_hit_timers.append(0.0)
    while orbital_positions.size() > desired:
        orbital_positions.pop_back()
        orbital_hit_timers.pop_back()
    if desired <= 0:
        return

    orbital_angle = fposmod(orbital_angle + orbital_angular_speed * delta, TAU)
    var angle_step := TAU / float(desired)
    var damage_instance := _scaled_weapon_damage(GameConfig.ORBITAL_DAMAGE)
    for i in range(desired):
        orbital_positions[i] = WorldSpace.wrap_position(
            player_position + Vector2.from_angle(orbital_angle + angle_step * float(i)) * orbital_radius
        )
        orbital_hit_timers[i] -= delta
        if orbital_hit_timers[i] > 0.0:
            continue

        var struck := false
        for enemy_index in range(enemy_positions.size()):
            if enemy_health[enemy_index] - enemy_reserved_damage[enemy_index] <= 0.0:
                continue
            var combined_radius := orbital_hit_radius + enemy_radii[enemy_index]
            if WorldSpace.distance_squared(orbital_positions[i], enemy_positions[enemy_index]) > combined_radius * combined_radius:
                continue
            if _queue_fixed_damage(enemy_index, damage_instance) > 0.0:
                struck = true
        if struck:
            orbital_hit_timers[i] = orbital_hit_interval
            # Gated by the contact interval, and the cue's own cooldown collapses
            # simultaneous satellite hits into one voice.
            _request_sound("orbital_contact")


func _update_detonator(delta: float) -> void:
    detonator_timer -= delta
    if detonator_timer > 0.0:
        return

    var target_index := _find_target_enemy(player_position, detonator_range)
    if target_index < 0:
        detonator_timer = 0.12
        return

    _spawn_detonator_shell(enemy_positions[target_index])
    detonator_timer += maxf(0.30, detonator_cooldown)


func _spawn_detonator_shell(target_position: Vector2) -> void:
    if detonator_shell_positions.size() >= GameConfig.DETONATOR_BLAST_CAP:
        return
    # nearest_image keeps the throw pointed the short way around the torus
    # instead of across the full map width.
    var offset := WorldSpace.nearest_image(player_position, target_position) - player_position
    var travel := offset.length()
    var direction := Vector2.RIGHT
    if travel > 0.001:
        direction = offset / travel
    var muzzle_offset := GameConfig.PLAYER_RADIUS + GameConfig.DETONATOR_RADIUS + 2.0
    detonator_shell_positions.append(WorldSpace.wrap_position(player_position + direction * muzzle_offset))
    detonator_shell_velocities.append(direction * GameConfig.DETONATOR_SPEED)
    detonator_shell_remaining.append(maxf(0.0, travel - muzzle_offset))
    detonator_shell_lifetimes.append(GameConfig.DETONATOR_LIFETIME)
    _request_sound("detonator_launch")


func _update_detonator_shells(delta: float) -> void:
    for i in range(detonator_shell_positions.size() - 1, -1, -1):
        var step := detonator_shell_velocities[i] * delta
        detonator_shell_positions[i] = WorldSpace.wrap_position(detonator_shell_positions[i] + step)
        detonator_shell_remaining[i] -= step.length()
        detonator_shell_lifetimes[i] -= delta
        if detonator_shell_remaining[i] > 0.0 and detonator_shell_lifetimes[i] > 0.0:
            continue
        _detonate(detonator_shell_positions[i])
        _remove_detonator_shell(i)


func _detonate(position: Vector2) -> void:
    var damage_instance := _scaled_weapon_damage(GameConfig.DETONATOR_DAMAGE)
    for enemy_index in range(enemy_positions.size()):
        if enemy_health[enemy_index] - enemy_reserved_damage[enemy_index] <= 0.0:
            continue
        var combined_radius := detonator_blast_radius + enemy_radii[enemy_index]
        if WorldSpace.distance_squared(position, enemy_positions[enemy_index]) <= combined_radius * combined_radius:
            _queue_fixed_damage(enemy_index, damage_instance)

    if detonator_blast_positions.size() < GameConfig.DETONATOR_BLAST_CAP:
        detonator_blast_positions.append(position)
        detonator_blast_radii.append(detonator_blast_radius)
        detonator_blast_timers.append(GameConfig.DETONATOR_VISUAL_DURATION)
    _request_sound("detonator_blast")


func _update_detonator_blasts(delta: float) -> void:
    for i in range(detonator_blast_timers.size() - 1, -1, -1):
        detonator_blast_timers[i] -= delta
        if detonator_blast_timers[i] > 0.0:
            continue
        var last := detonator_blast_timers.size() - 1
        if i != last:
            detonator_blast_positions[i] = detonator_blast_positions[last]
            detonator_blast_radii[i] = detonator_blast_radii[last]
            detonator_blast_timers[i] = detonator_blast_timers[last]
        detonator_blast_positions.pop_back()
        detonator_blast_radii.pop_back()
        detonator_blast_timers.pop_back()


func _remove_detonator_shell(index: int) -> void:
    var last := detonator_shell_positions.size() - 1
    if index != last:
        detonator_shell_positions[index] = detonator_shell_positions[last]
        detonator_shell_velocities[index] = detonator_shell_velocities[last]
        detonator_shell_remaining[index] = detonator_shell_remaining[last]
        detonator_shell_lifetimes[index] = detonator_shell_lifetimes[last]
    detonator_shell_positions.pop_back()
    detonator_shell_velocities.pop_back()
    detonator_shell_remaining.pop_back()
    detonator_shell_lifetimes.pop_back()


func _spawn_projectile(
    direction: Vector2,
    damage_budget: float = -1.0,
    speed: float = -1.0,
    lifetime: float = -1.0,
    radius: float = -1.0,
    kind: int = ProjectileKind.NEEDLE
) -> void:
    if projectile_positions.size() >= GameConfig.PROJECTILE_CAP:
        return
    var resolved_damage := damage_budget
    if resolved_damage < 0.0:
        resolved_damage = weapon_damage * float(weapon_pierce + 1)
    var resolved_speed := weapon_speed if speed < 0.0 else speed
    var resolved_lifetime := weapon_lifetime if lifetime < 0.0 else lifetime
    var resolved_radius := weapon_radius if radius < 0.0 else radius

    projectile_positions.append(WorldSpace.wrap_position(
        player_position + direction * (GameConfig.PLAYER_RADIUS + resolved_radius + 2.0)
    ))
    projectile_velocities.append(direction * resolved_speed)
    projectile_lifetimes.append(resolved_lifetime)
    projectile_remaining_damage.append(resolved_damage)
    projectile_attack_ids.append(next_attack_id)
    projectile_radii.append(resolved_radius)
    projectile_kinds.append(kind)
    next_attack_id += 1
    if next_attack_id >= 2147483000:
        next_attack_id = 1
        for i in range(enemy_last_hit_attack.size()):
            enemy_last_hit_attack[i] = 0


func _scaled_weapon_damage(base_damage: float) -> float:
    return base_damage * weapon_damage / GameConfig.NEEDLE_DAMAGE


func _request_sound(cue: String) -> void:
    if not benchmark_mode:
        sound_requested.emit(cue)


func _has_weapon(weapon_id: String) -> bool:
    return owned_weapons.has(weapon_id)


func _update_projectiles(delta: float) -> void:
    for projectile_index in range(projectile_positions.size() - 1, -1, -1):
        var start := projectile_positions[projectile_index]
        var finish := start + projectile_velocities[projectile_index] * delta
        # The sweep below needs an unwrapped start->finish segment; only the
        # stored position folds back onto the torus.
        projectile_positions[projectile_index] = WorldSpace.wrap_position(finish)
        projectile_lifetimes[projectile_index] -= delta

        if projectile_lifetimes[projectile_index] <= 0.0:
            _remove_projectile(projectile_index)
            continue

        var radius := projectile_radii[projectile_index]
        var collision_padding := radius + GameConfig.BOSS_RADIUS
        var min_point := Vector2(minf(start.x, finish.x), minf(start.y, finish.y)) - Vector2.ONE * collision_padding
        var max_point := Vector2(maxf(start.x, finish.x), maxf(start.y, finish.y)) + Vector2.ONE * collision_padding
        # Unwrapped cell span; each visited cell is wrapped individually below.
        var min_cell := Vector2i(
            floori(min_point.x / GameConfig.GRID_CELL_SIZE),
            floori(min_point.y / GameConfig.GRID_CELL_SIZE)
        )
        var max_cell := Vector2i(
            floori(max_point.x / GameConfig.GRID_CELL_SIZE),
            floori(max_point.y / GameConfig.GRID_CELL_SIZE)
        )
        max_cell.x = mini(max_cell.x, min_cell.x + GameConfig.GRID_CELL_COUNT - 1)
        max_cell.y = mini(max_cell.y, min_cell.y + GameConfig.GRID_CELL_COUNT - 1)
        projectile_candidate_targets.clear()
        projectile_candidate_fractions.clear()

        for cell_x in range(min_cell.x, max_cell.x + 1):
            for cell_y in range(min_cell.y, max_cell.y + 1):
                var cell := Vector2i(
                    posmod(cell_x, GameConfig.GRID_CELL_COUNT),
                    posmod(cell_y, GameConfig.GRID_CELL_COUNT)
                )
                var bucket_value: Variant = enemy_grid.get(cell, null)
                if bucket_value == null:
                    continue
                var bucket: Array = bucket_value
                for enemy_index_variant in bucket:
                    var enemy_index: int = enemy_index_variant
                    if enemy_health[enemy_index] - enemy_reserved_damage[enemy_index] <= 0.0:
                        continue
                    if enemy_last_hit_attack[enemy_index] == projectile_attack_ids[projectile_index]:
                        continue
                    var collision_radius := radius + enemy_radii[enemy_index]
                    var hit_fraction := _segment_circle_hit_fraction(
                        start,
                        finish,
                        WorldSpace.nearest_image(start, enemy_positions[enemy_index]),
                        collision_radius
                    )
                    if hit_fraction >= 0.0:
                        projectile_candidate_targets.append(enemy_index)
                        projectile_candidate_fractions.append(hit_fraction)

        _sort_projectile_candidates()
        var exhausted := false
        for candidate_index in range(projectile_candidate_targets.size()):
            var enemy_index := projectile_candidate_targets[candidate_index]
            var target_remaining_health := enemy_health[enemy_index] - enemy_reserved_damage[enemy_index]
            if target_remaining_health <= 0.0:
                continue
            if enemy_last_hit_attack[enemy_index] == projectile_attack_ids[projectile_index]:
                continue

            var damage_multiplier := _damage_multiplier_for_enemy(enemy_index)
            var raw_damage_spent := minf(
                projectile_remaining_damage[projectile_index],
                target_remaining_health / damage_multiplier
            )
            var damage_value := raw_damage_spent * damage_multiplier
            if damage_value <= 0.0:
                continue

            enemy_last_hit_attack[enemy_index] = projectile_attack_ids[projectile_index]
            hit_targets.append(enemy_index)
            hit_damage.append(damage_value)
            enemy_reserved_damage[enemy_index] += damage_value
            projectile_remaining_damage[projectile_index] -= raw_damage_spent

            if projectile_remaining_damage[projectile_index] <= 0.0001:
                exhausted = true
                break

        if exhausted:
            _remove_projectile(projectile_index)


func _damage_multiplier_for_enemy(enemy_index: int) -> float:
    if enemy_kinds[enemy_index] != EnemyKind.BOSS:
        return 1.0
    if enemy_boss_hit_protection_timer[enemy_index] > 0.0:
        return GameConfig.BOSS_HIT_PROTECTION_DAMAGE_MULTIPLIER
    enemy_boss_hit_protection_timer[enemy_index] = GameConfig.BOSS_HIT_PROTECTION_DURATION
    return 1.0


func _queue_fixed_damage(enemy_index: int, raw_damage: float) -> float:
    if raw_damage <= 0.0:
        return 0.0
    var target_remaining_health := enemy_health[enemy_index] - enemy_reserved_damage[enemy_index]
    if target_remaining_health <= 0.0:
        return 0.0
    var damage_multiplier := _damage_multiplier_for_enemy(enemy_index)
    var damage_value := minf(raw_damage * damage_multiplier, target_remaining_health)
    if damage_value <= 0.0:
        return 0.0
    hit_targets.append(enemy_index)
    hit_damage.append(damage_value)
    enemy_reserved_damage[enemy_index] += damage_value
    return damage_value


func _field_slow_multiplier_at(position: Vector2) -> float:
    for field_index in range(field_positions.size()):
        if field_lifetimes[field_index] <= 0.0:
            continue
        if WorldSpace.distance_squared(position, field_positions[field_index]) <= field_radii[field_index] * field_radii[field_index]:
            return GameConfig.FIELD_SLOW_MULTIPLIER
    return 1.0


func _resolve_hits() -> void:
    var hit_normal := false
    var hit_boss := false
    for i in range(hit_targets.size()):
        var target := hit_targets[i]
        if target < 0 or target >= enemy_health.size():
            continue
        enemy_health[target] -= hit_damage[i]
        enemy_reserved_damage[target] = 0.0
        if enemy_kinds[target] == EnemyKind.BOSS:
            hit_boss = true
        else:
            hit_normal = true
    if hit_normal:
        _request_sound("enemy_hit")
    if hit_boss:
        _request_sound("boss_hit")


func _process_deaths() -> void:
    var boss_defeated := false
    for i in range(enemy_health.size() - 1, -1, -1):
        if enemy_health[i] > 0.0:
            continue

        kills += 1
        xp += maxi(1, int(round(float(enemy_xp[i]) * GameConfig.GAME_PACE_MULTIPLIER * character_xp_gain)))
        if enemy_kinds[i] == EnemyKind.BOSS:
            pending_boss_rewards += 1
            boss_defeated = true
        else:
            # Children are queued, not spawned inline: _remove_enemy swaps the
            # last element into slot i, so appending mid-loop would shuffle an
            # unvisited entity into an index the reverse walk has passed.
            if enemy_archetypes[i] == EnemyArchetype.SPLITTER:
                _queue_split(enemy_positions[i])
            if pickup_positions.size() < GameConfig.PICKUP_CAP and rng.randf() < GameConfig.HEALTH_PICKUP_DROP_CHANCE:
                _spawn_health_pickup(enemy_positions[i])
        _remove_enemy(i)
    _drain_pending_splits()
    if boss_defeated:
        _request_sound("boss_defeat")


func _queue_split(position: Vector2) -> void:
    for child in range(GameConfig.ARCHETYPE_SPLITTER_CHILD_COUNT):
        var offset := Vector2.from_angle(rng.randf_range(0.0, TAU)) * GameConfig.ARCHETYPE_SPLITTER_CHILD_SCATTER
        pending_split_positions.append(WorldSpace.wrap_position(position + offset))
        pending_split_health.append(1.0 / float(GameConfig.ARCHETYPE_SPLITTER_CHILD_COUNT))


func _drain_pending_splits() -> void:
    for i in range(pending_split_positions.size()):
        _spawn_archetype(pending_split_positions[i], EnemyArchetype.SWARMER, pending_split_health[i])
    pending_split_positions.clear()
    pending_split_health.clear()


func _spawn_enemy_shot(origin: Vector2, direction: Vector2, damage_value: float) -> void:
    if enemy_shot_positions.size() >= GameConfig.ENEMY_SHOT_CAP:
        return
    enemy_shot_positions.append(WorldSpace.wrap_position(origin + direction * 18.0))
    enemy_shot_velocities.append(direction * GameConfig.ARCHETYPE_RANGED_SHOT_SPEED)
    enemy_shot_lifetimes.append(GameConfig.ARCHETYPE_RANGED_SHOT_LIFETIME)
    enemy_shot_damage.append(damage_value)


# Enemy shots only ever test against the player, so they skip the enemy grid
# entirely: one distance check each, no spatial query.
func _update_enemy_shots(delta: float) -> void:
    var hit_radius := GameConfig.PLAYER_RADIUS + GameConfig.ARCHETYPE_RANGED_SHOT_RADIUS
    var hit_radius_squared := hit_radius * hit_radius
    for i in range(enemy_shot_positions.size() - 1, -1, -1):
        enemy_shot_lifetimes[i] -= delta
        if enemy_shot_lifetimes[i] <= 0.0:
            _remove_enemy_shot(i)
            continue
        enemy_shot_positions[i] = WorldSpace.wrap_position(
            enemy_shot_positions[i] + enemy_shot_velocities[i] * delta
        )
        if WorldSpace.distance_squared(enemy_shot_positions[i], player_position) <= hit_radius_squared:
            _apply_player_damage(enemy_shot_damage[i], true)
            _remove_enemy_shot(i)
            if not is_running:
                return


func _remove_enemy_shot(index: int) -> void:
    var last := enemy_shot_positions.size() - 1
    if index != last:
        enemy_shot_positions[index] = enemy_shot_positions[last]
        enemy_shot_velocities[index] = enemy_shot_velocities[last]
        enemy_shot_lifetimes[index] = enemy_shot_lifetimes[last]
        enemy_shot_damage[index] = enemy_shot_damage[last]
    enemy_shot_positions.pop_back()
    enemy_shot_velocities.pop_back()
    enemy_shot_lifetimes.pop_back()
    enemy_shot_damage.pop_back()


func _update_pickups() -> void:
    var collect_radius_squared := player_pickup_radius * player_pickup_radius
    for i in range(pickup_positions.size() - 1, -1, -1):
        if WorldSpace.distance_squared(pickup_positions[i], player_position) <= collect_radius_squared:
            player_health = minf(player_max_health, player_health + player_max_health * GameConfig.HEALTH_PICKUP_HEAL)
            _remove_pickup(i)
            _request_sound("health_pickup")


func _update_regeneration(delta: float) -> void:
    if time_since_player_damage < player_regen_delay:
        return
    var ceiling := player_max_health * player_regen_ceiling
    if player_health >= ceiling:
        return
    player_health = minf(ceiling, player_health + player_max_health * player_regen_rate * delta)


func _paced_elapsed_time() -> float:
    return elapsed_time * GameConfig.GAME_PACE_MULTIPLIER


func _paced_minutes() -> float:
    return _paced_elapsed_time() / 60.0


func _update_spawning(delta: float) -> void:
    if benchmark_mode:
        return

    threat_check_timer -= delta
    if threat_check_timer <= 0.0:
        threat_check_timer = 0.20
        nearby_threat = _count_nearby_normals(GameConfig.NEARBY_THREAT_RADIUS * _camera_view_scale())

    if surge_active:
        surge_time += delta
        if nearby_threat >= GameConfig.SURGE_EXIT_COUNT or surge_time >= GameConfig.SURGE_MAX_DURATION:
            surge_active = false
            surge_time = 0.0
            surge_cooldown = GameConfig.SURGE_COOLDOWN
    elif surge_cooldown <= 0.0 and nearby_threat <= GameConfig.SURGE_ENTER_COUNT:
        surge_active = true
        surge_time = 0.0

    var minutes := _paced_minutes()
    var base_rate := GameConfig.GAME_PACE_MULTIPLIER * minf(
        150.0,
        8.0 + 3.0 * minutes + 0.8 * minutes * minutes
    )
    var surge_multiplier := 1.0
    if surge_active:
        surge_multiplier = 1.0 + 3.0 * minf(1.0, surge_time / GameConfig.SURGE_RAMP_TIME)
    surge_multiplier *= _phase_spawn_multiplier()

    spawn_accumulator += base_rate * surge_multiplier * delta
    var spawned_this_tick := 0
    while spawn_accumulator >= 1.0 and enemy_positions.size() < GameConfig.ENEMY_CAP and spawned_this_tick < GameConfig.MAX_SPAWNS_PER_TICK:
        _spawn_normal_enemy()
        spawn_accumulator -= 1.0
        spawned_this_tick += 1

    var max_spawn_debt := base_rate * surge_multiplier * GameConfig.MAX_SPAWN_DEBT_SECONDS
    spawn_accumulator = minf(spawn_accumulator, max_spawn_debt)


# Ramp -> spike -> collapse, repeating. Returns a multiplier on the base spawn
# rate; phase position comes from paced time so it stays in step with the
# difficulty curve rather than wall-clock.
func _phase_spawn_multiplier() -> float:
    var phase := fposmod(_paced_elapsed_time(), GameConfig.PHASE_PERIOD_SECONDS) / GameConfig.PHASE_PERIOD_SECONDS
    if phase < GameConfig.PHASE_RAMP_FRACTION:
        return lerpf(
            GameConfig.PHASE_RAMP_START_MULTIPLIER,
            GameConfig.PHASE_RAMP_END_MULTIPLIER,
            phase / GameConfig.PHASE_RAMP_FRACTION
        )
    if phase < GameConfig.PHASE_SPIKE_FRACTION:
        return lerpf(
            GameConfig.PHASE_RAMP_END_MULTIPLIER,
            GameConfig.PHASE_SPIKE_MULTIPLIER,
            (phase - GameConfig.PHASE_RAMP_FRACTION)
            / (GameConfig.PHASE_SPIKE_FRACTION - GameConfig.PHASE_RAMP_FRACTION)
        )
    return GameConfig.PHASE_COLLAPSE_MULTIPLIER


func _update_boss_schedule() -> void:
    if benchmark_mode:
        return
    if _paced_elapsed_time() < next_boss_time:
        return
    next_boss_time += GameConfig.BOSS_INTERVAL
    if get_boss_count() >= GameConfig.BOSS_CAP:
        return
    _spawn_boss()
    boss_spawned.emit()
    _request_sound("boss_spawn")


func _spawn_normal_enemy() -> void:
    if enemy_positions.size() >= GameConfig.ENEMY_CAP:
        return
    var angle := rng.randf_range(0.0, TAU)
    if player_move_direction.length_squared() > 0.1 and rng.randf() < 0.20:
        angle = player_move_direction.angle() + rng.randf_range(-0.55, 0.55)
    var view_scale := _camera_view_scale()
    var distance := rng.randf_range(760.0 * view_scale, 1040.0 * view_scale)
    var spawn_position := WorldSpace.wrap_position(player_position + Vector2.from_angle(angle) * distance)
    _spawn_archetype(spawn_position, _pick_archetype(_paced_minutes()), 1.0)


# Stat scales packed into a Vector4 (health, speed, damage, radius) so archetype
# lookup stays allocation-free on the spawn path.
func _archetype_stat_scale(archetype: int) -> Vector4:
    match archetype:
        EnemyArchetype.SWARMER:
            return Vector4(
                GameConfig.ARCHETYPE_SWARMER_HEALTH,
                GameConfig.ARCHETYPE_SWARMER_SPEED,
                GameConfig.ARCHETYPE_SWARMER_DAMAGE,
                GameConfig.ARCHETYPE_SWARMER_RADIUS
            )
        EnemyArchetype.SHIELDED:
            return Vector4(
                GameConfig.ARCHETYPE_SHIELDED_HEALTH,
                GameConfig.ARCHETYPE_SHIELDED_SPEED,
                GameConfig.ARCHETYPE_SHIELDED_DAMAGE,
                GameConfig.ARCHETYPE_SHIELDED_RADIUS
            )
        EnemyArchetype.RANGED:
            return Vector4(
                GameConfig.ARCHETYPE_RANGED_HEALTH,
                GameConfig.ARCHETYPE_RANGED_SPEED,
                GameConfig.ARCHETYPE_RANGED_DAMAGE,
                GameConfig.ARCHETYPE_RANGED_RADIUS
            )
        EnemyArchetype.SPLITTER:
            return Vector4(
                GameConfig.ARCHETYPE_SPLITTER_HEALTH,
                GameConfig.ARCHETYPE_SPLITTER_SPEED,
                GameConfig.ARCHETYPE_SPLITTER_DAMAGE,
                GameConfig.ARCHETYPE_SPLITTER_RADIUS
            )
        EnemyArchetype.ELITE:
            return Vector4(
                GameConfig.ARCHETYPE_ELITE_HEALTH,
                GameConfig.ARCHETYPE_ELITE_SPEED,
                GameConfig.ARCHETYPE_ELITE_DAMAGE,
                GameConfig.ARCHETYPE_ELITE_RADIUS
            )
        _:
            return Vector4.ONE


func _archetype_xp(archetype: int) -> int:
    match archetype:
        EnemyArchetype.SWARMER:
            return GameConfig.ARCHETYPE_SWARMER_XP
        EnemyArchetype.SHIELDED:
            return GameConfig.ARCHETYPE_SHIELDED_XP
        EnemyArchetype.RANGED:
            return GameConfig.ARCHETYPE_RANGED_XP
        EnemyArchetype.SPLITTER:
            return GameConfig.ARCHETYPE_SPLITTER_XP
        EnemyArchetype.ELITE:
            return GameConfig.ARCHETYPE_ELITE_XP
        _:
            return GameConfig.NORMAL_ENEMY_XP


func _archetype_weight(archetype: int, minutes: float) -> float:
    match archetype:
        EnemyArchetype.SWARMER:
            return GameConfig.ARCHETYPE_SWARMER_WEIGHT if minutes >= GameConfig.ARCHETYPE_SWARMER_UNLOCK_MINUTES else 0.0
        EnemyArchetype.SHIELDED:
            return GameConfig.ARCHETYPE_SHIELDED_WEIGHT if minutes >= GameConfig.ARCHETYPE_SHIELDED_UNLOCK_MINUTES else 0.0
        EnemyArchetype.RANGED:
            return GameConfig.ARCHETYPE_RANGED_WEIGHT if minutes >= GameConfig.ARCHETYPE_RANGED_UNLOCK_MINUTES else 0.0
        EnemyArchetype.SPLITTER:
            return GameConfig.ARCHETYPE_SPLITTER_WEIGHT if minutes >= GameConfig.ARCHETYPE_SPLITTER_UNLOCK_MINUTES else 0.0
        EnemyArchetype.ELITE:
            return GameConfig.ARCHETYPE_ELITE_WEIGHT if minutes >= GameConfig.ARCHETYPE_ELITE_UNLOCK_MINUTES else 0.0
        _:
            return GameConfig.ARCHETYPE_GRUNT_WEIGHT


func _pick_archetype(minutes: float) -> int:
    var total := 0.0
    for archetype in range(ARCHETYPE_COUNT):
        total += _archetype_weight(archetype, minutes)
    if total <= 0.0:
        return EnemyArchetype.GRUNT
    var roll := rng.randf() * total
    for archetype in range(ARCHETYPE_COUNT):
        roll -= _archetype_weight(archetype, minutes)
        if roll <= 0.0:
            return archetype
    return EnemyArchetype.GRUNT


func _spawn_archetype(position: Vector2, archetype: int, health_multiplier: float) -> void:
    if enemy_positions.size() >= GameConfig.ENEMY_CAP:
        return
    var minutes := _paced_minutes()
    var damage_scale := 1.0 + 0.10 * minutes + 0.020 * minutes * minutes
    var scale := _archetype_stat_scale(archetype)
    _add_enemy(
        position,
        _current_normal_enemy_health() * scale.x * health_multiplier,
        GameConfig.NORMAL_ENEMY_SPEED * scale.y,
        GameConfig.NORMAL_ENEMY_DAMAGE * damage_scale * scale.z,
        GameConfig.NORMAL_ENEMY_RADIUS * scale.w,
        _archetype_xp(archetype),
        EnemyKind.NORMAL,
        Vector2.ZERO,
        archetype
    )


func _current_normal_speed_scale() -> float:
    var minutes := _paced_minutes()
    return (
        1.0
        + GameConfig.NORMAL_ENEMY_SPEED_SCALE_PER_MINUTE * minutes
        + GameConfig.NORMAL_ENEMY_SPEED_SCALE_QUADRATIC * minutes * minutes
    )


func _current_boss_speed_scale() -> float:
    var minutes := _paced_minutes()
    return 1.0 + GameConfig.BOSS_SPEED_SCALE_PER_MINUTE * minutes


func _surge_speed_multiplier(distance_to_player: float) -> float:
    if not surge_active:
        return 1.0
    var ramp := minf(1.0, surge_time / GameConfig.SURGE_RAMP_TIME)
    var view_scale := _camera_view_scale()
    var fade_start := GameConfig.SURGE_SPEED_FADE_START * view_scale
    var full_distance := GameConfig.SURGE_SPEED_FULL_DISTANCE * view_scale
    var fade_distance := maxf(1.0, full_distance - fade_start)
    var distance_factor := clampf(
        (distance_to_player - fade_start) / fade_distance,
        0.0,
        1.0
    )
    return 1.0 + (GameConfig.SURGE_MAX_SPEED_MULTIPLIER - 1.0) * ramp * distance_factor


func _spawn_boss() -> void:
    var angle := rng.randf_range(0.0, TAU)
    var view_scale := _camera_view_scale()
    var distance := rng.randf_range(1050.0 * view_scale, 1450.0 * view_scale)
    var position := WorldSpace.wrap_position(player_position + Vector2.from_angle(angle) * distance)
    var minutes := _paced_minutes()
    var damage_scale := 1.0 + 0.14 * minutes + 0.025 * minutes * minutes
    _add_enemy(
        position,
        _current_boss_health(),
        GameConfig.BOSS_SPEED,
        GameConfig.BOSS_DAMAGE * damage_scale,
        GameConfig.BOSS_RADIUS,
        GameConfig.BOSS_XP,
        EnemyKind.BOSS,
        position
    )


func _add_enemy(
    position: Vector2,
    health_value: float,
    speed_value: float,
    damage_value: float,
    radius_value: float,
    xp_value: int,
    kind_value: int,
    anchor_value: Vector2,
    archetype_value: int = EnemyArchetype.GRUNT
) -> void:
    enemy_positions.append(position)
    enemy_health.append(health_value)
    enemy_max_health.append(health_value)
    enemy_speeds.append(speed_value)
    enemy_damage.append(damage_value)
    enemy_radii.append(radius_value)
    enemy_xp.append(xp_value)
    enemy_kinds.append(kind_value)
    enemy_archetypes.append(archetype_value)
    enemy_fire_timers.append(_initial_fire_timer(archetype_value))
    enemy_sprite_frames.append(_sprite_frame_for(kind_value, archetype_value))
    enemy_last_hit_attack.append(0)
    enemy_reserved_damage.append(0.0)
    enemy_anchors.append(anchor_value)
    enemy_boss_attack_timer.append(rng.randf_range(1.5, 3.0) if kind_value == EnemyKind.BOSS else 0.0)
    enemy_boss_telegraph.append(0.0)
    enemy_boss_hit_protection_timer.append(0.0)


func _sprite_frame_for(kind_value: int, archetype_value: int) -> int:
    if kind_value == EnemyKind.BOSS:
        return SPRITE_FRAME_COUNT - 1
    match archetype_value:
        EnemyArchetype.SWARMER:
            return 1
        EnemyArchetype.SHIELDED:
            return 2
        EnemyArchetype.RANGED:
            return 3
        EnemyArchetype.SPLITTER:
            return 4
        EnemyArchetype.ELITE:
            # Frame 7 is the crowned elite chassis in tools/generate_sprite_atlas.gd.
            # Frames 5 (heavy) and 6 (skitter) are drawn but unclaimed by any
            # archetype yet.
            return 7
        _:
            return 0


func _initial_fire_timer(archetype_value: int) -> float:
    if archetype_value != EnemyArchetype.RANGED:
        return 0.0
    return GameConfig.ARCHETYPE_RANGED_FIRE_INTERVAL * rng.randf_range(0.35, 1.0)


func _spawn_health_pickup(position: Vector2) -> void:
    if pickup_positions.size() >= GameConfig.PICKUP_CAP:
        return
    pickup_positions.append(position)


func _apply_player_damage(raw_damage: float, ignores_contact_cooldown: bool) -> void:
    if not is_running or benchmark_mode:
        return
    if player_invulnerability_timer > 0.0:
        return
    if not ignores_contact_cooldown and player_contact_cooldown > 0.0:
        return
    var final_damage := raw_damage * 100.0 / (100.0 + player_armor)
    var health_fraction_before_hit := player_health / maxf(1.0, player_max_health)
    var lethal_hit := final_damage >= player_health
    var one_shot_protection_triggered := (
        lethal_hit
        and health_fraction_before_hit > GameConfig.PLAYER_ONE_SHOT_PROTECTION_THRESHOLD
    )
    if one_shot_protection_triggered:
        player_health = GameConfig.PLAYER_ONE_SHOT_PROTECTION_HEALTH
        player_one_shot_protection_timer = GameConfig.PLAYER_ONE_SHOT_PROTECTION_VISUAL_DURATION
        _request_sound("last_stand")
    else:
        player_health -= final_damage
        _request_sound("player_hit")
    time_since_player_damage = 0.0
    player_invulnerability_timer = GameConfig.PLAYER_HIT_INVULNERABILITY
    if not ignores_contact_cooldown:
        player_contact_cooldown = GameConfig.CONTACT_DAMAGE_COOLDOWN
    if player_health <= 0.0:
        player_health = 0.0
        _end_run()


func _end_run() -> void:
    if not is_running:
        return
    is_running = false
    pending_upgrade = false
    pending_boss_rewards = 0
    _emit_stats()
    run_ended.emit(get_stats_snapshot())


func _check_boss_reward() -> void:
    if pending_upgrade or not is_running or pending_boss_rewards <= 0:
        return
    var options := _roll_weapon_upgrade_options()
    if options.is_empty():
        pending_boss_rewards = 0
        return
    pending_boss_rewards -= 1
    pending_upgrade = true
    boss_upgrade_requested.emit(options)


func _check_level_up() -> void:
    if pending_upgrade or not is_running:
        return
    if xp < xp_required:
        return
    xp -= xp_required
    level += 1
    xp_required = xp_required_for(level)
    pending_upgrade = true
    level_up_requested.emit(_roll_upgrade_options())


func apply_upgrade(upgrade_id: String) -> void:
    if not pending_upgrade or not _is_upgrade_eligible(upgrade_id):
        return

    if GameConfig.WEAPON_UNLOCK_IDS.has(upgrade_id):
        owned_weapons.append(GameConfig.WEAPON_UNLOCK_IDS[upgrade_id])
    else:
        match upgrade_id:
            "damage":
                weapon_damage *= 1.20
            "move_speed":
                player_move_speed *= 1.10
                _update_camera_zoom()
            "max_health":
                var gained := player_max_health * 0.15
                player_max_health += gained
                player_health = minf(player_max_health, player_health + gained)
            "armor":
                player_armor += 10.0
            "regen":
                player_regen_rate += 0.005
            "needle_fire_rate":
                weapon_cooldown = maxf(0.05, weapon_cooldown * 0.88)
            "needle_projectile_count":
                weapon_projectile_count += 1
            "needle_pierce":
                weapon_pierce += 1
            "needle_range":
                weapon_range *= 1.12
                weapon_lifetime *= 1.12
            "sniper_fire_rate":
                sniper_cooldown = maxf(0.20, sniper_cooldown * 0.90)
            "sniper_pierce":
                sniper_pierce += 1
            "sniper_range":
                sniper_range *= 1.12
                sniper_lifetime *= 1.12
            "sniper_size":
                sniper_radius *= GameConfig.SNIPER_SIZE_UPGRADE_MULTIPLIER
            "aura_fire_rate":
                aura_cooldown = maxf(0.35, aura_cooldown * 0.90)
            "aura_radius":
                aura_radius *= 1.12
            "aura_echoes":
                aura_echoes += 1
            "field_fire_rate":
                field_cooldown = maxf(0.35, field_cooldown * 0.90)
            "field_radius":
                field_radius *= 1.12
            "field_duration":
                field_duration += 0.50
            "chain_fire_rate":
                chain_cooldown = maxf(0.20, chain_cooldown * 0.89)
            "chain_jumps":
                chain_jumps = mini(GameConfig.CHAIN_MAX_JUMPS, chain_jumps + 1)
            "chain_falloff":
                chain_falloff = minf(0.95, chain_falloff + 0.08)
            "chain_range":
                chain_range *= 1.12
                chain_jump_radius *= 1.12
            "flak_fire_rate":
                flak_cooldown = maxf(0.15, flak_cooldown * 0.90)
            "flak_pellets":
                flak_pellets += 1
            "flak_spread":
                flak_spread = maxf(deg_to_rad(12.0), flak_spread * 0.88)
            "flak_range":
                flak_range *= 1.15
                flak_lifetime *= 1.15
            "orbital_count":
                orbital_count = mini(GameConfig.ORBITAL_CAP, orbital_count + 1)
            "orbital_fire_rate":
                orbital_angular_speed *= 1.12
                orbital_hit_interval = maxf(0.12, orbital_hit_interval * 0.90)
            "orbital_radius":
                orbital_radius *= 1.12
            "orbital_size":
                orbital_hit_radius *= 1.20
            "detonator_fire_rate":
                detonator_cooldown = maxf(0.30, detonator_cooldown * 0.90)
            "detonator_blast":
                detonator_blast_radius *= 1.12
            "detonator_range":
                detonator_range *= 1.12
            _:
                return

        if weapon_upgrade_levels.has(upgrade_id):
            weapon_upgrade_levels[upgrade_id] += 1

    pending_upgrade = false
    _emit_stats()


func _weapon_for_upgrade(upgrade_id: String) -> String:
    for weapon_id in GameConfig.WEAPON_IDS:
        var upgrade_ids: Array = GameConfig.WEAPON_UPGRADE_IDS.get(weapon_id, [])
        if upgrade_ids.has(upgrade_id):
            return weapon_id
    return ""


func _is_upgrade_eligible(upgrade_id: String) -> bool:
    if GameConfig.GLOBAL_UPGRADE_IDS.has(upgrade_id):
        return true
    if GameConfig.WEAPON_UNLOCK_IDS.has(upgrade_id):
        var unlock_weapon_id: String = GameConfig.WEAPON_UNLOCK_IDS[upgrade_id]
        return owned_weapons.size() < GameConfig.WEAPON_SLOT_CAP and not owned_weapons.has(unlock_weapon_id)

    var owner_weapon_id := _weapon_for_upgrade(upgrade_id)
    if owner_weapon_id.is_empty() or not owned_weapons.has(owner_weapon_id):
        return false
    var current_level: int = weapon_upgrade_levels.get(upgrade_id, 0)
    var level_cap: int = GameConfig.WEAPON_UPGRADE_CAPS.get(upgrade_id, 0)
    return current_level < level_cap


func _eligible_owned_weapon_upgrades() -> Array[String]:
    var result: Array[String] = []
    for weapon_id in owned_weapons:
        var upgrade_ids: Array = GameConfig.WEAPON_UPGRADE_IDS.get(weapon_id, [])
        for upgrade_id in upgrade_ids:
            if _is_upgrade_eligible(upgrade_id):
                result.append(upgrade_id)
    return result


func _upgrade_roll_weight(upgrade_id: String) -> float:
    return float(GameConfig.UPGRADE_ROLL_WEIGHTS.get(upgrade_id, 1.0))


func _take_weighted_upgrade(pool: Array[String]) -> String:
    var total_weight := 0.0
    for upgrade_id in pool:
        total_weight += maxf(0.0, _upgrade_roll_weight(upgrade_id))

    if total_weight <= 0.0:
        return pool.pop_back()

    var roll := rng.randf() * total_weight
    for index in range(pool.size()):
        roll -= maxf(0.0, _upgrade_roll_weight(pool[index]))
        if roll <= 0.0:
            var selected := pool[index]
            pool.remove_at(index)
            return selected
    return pool.pop_back()


func _eligible_dps_upgrades() -> Array[String]:
    var result: Array[String] = []
    for upgrade_id in GameConfig.DPS_UPGRADE_IDS:
        if _is_upgrade_eligible(upgrade_id):
            result.append(upgrade_id)
    return result


func _roll_upgrade_options() -> Array[String]:
    var pool: Array[String] = []
    for upgrade_id in GameConfig.GLOBAL_UPGRADE_IDS:
        pool.append(upgrade_id)
    pool.append_array(_eligible_owned_weapon_upgrades())

    var options: Array[String] = []
    var offense_pool := _eligible_dps_upgrades()
    var guaranteed_offense_count := mini(_offense_pity_option_count(), offense_pool.size())
    while options.size() < guaranteed_offense_count and not offense_pool.is_empty():
        var offense_upgrade := _take_weighted_upgrade(offense_pool)
        options.append(offense_upgrade)
        pool.erase(offense_upgrade)

    while options.size() < 3 and not pool.is_empty():
        options.append(_take_weighted_upgrade(pool))
    return options


func _roll_weapon_upgrade_options() -> Array[String]:
    var unlock_pool: Array[String] = []
    for unlock_id in GameConfig.WEAPON_UNLOCK_IDS:
        if _is_upgrade_eligible(unlock_id):
            unlock_pool.append(unlock_id)

    # Unlocks stay out of the weighted pool: exactly one is offered per screen,
    # no matter how many weapons remain unowned. With seven unlockables, leaving
    # the rest in the pool turned reward screens into an all-unlock menu.
    var pool: Array[String] = _eligible_owned_weapon_upgrades()
    var options: Array[String] = []

    if not unlock_pool.is_empty():
        unlock_pool.shuffle()
        options.append(unlock_pool.pop_back())

    while options.size() < 3 and not pool.is_empty():
        options.append(_take_weighted_upgrade(pool))
    return options


func _current_normal_enemy_health() -> float:
    var minutes := _paced_minutes()
    var health_scale := 1.0 + 0.12 * minutes + 0.025 * minutes * minutes
    return GameConfig.NORMAL_ENEMY_HEALTH * health_scale


func _current_boss_health() -> float:
    var minutes := _paced_minutes()
    var health_scale := (
        1.0
        + GameConfig.BOSS_HEALTH_SCALE_LINEAR * minutes
        + GameConfig.BOSS_HEALTH_SCALE_QUADRATIC * minutes * minutes
    )
    return GameConfig.BOSS_HEALTH * health_scale


func _estimated_sustained_dps() -> float:
    var needle_effective_projectiles := (
        1.0
        + float(maxi(0, weapon_projectile_count - 1))
        * GameConfig.NEEDLE_EXTRA_PROJECTILE_DPS_FACTOR
    )
    var total_dps := weapon_damage * needle_effective_projectiles / maxf(0.01, weapon_cooldown)

    if _has_weapon("sniper"):
        total_dps += _scaled_weapon_damage(GameConfig.SNIPER_DAMAGE) / maxf(0.01, sniper_cooldown)

    if _has_weapon("aura"):
        total_dps += (
            _scaled_weapon_damage(GameConfig.AURA_DAMAGE)
            * float(aura_echoes + 1)
            / maxf(0.01, aura_cooldown)
            * GameConfig.AURA_DPS_UPTIME_FACTOR
        )

    if _has_weapon("field"):
        var field_equivalents := minf(
            GameConfig.FIELD_DPS_MAX_EQUIVALENTS,
            field_duration / maxf(0.01, field_cooldown) * GameConfig.FIELD_DPS_OVERLAP_FACTOR
        )
        total_dps += (
            _scaled_weapon_damage(GameConfig.FIELD_DAMAGE)
            / GameConfig.FIELD_TICK_INTERVAL
            * field_equivalents
        )

    # Each new weapon needs its own branch here or offense-pity under-counts a
    # player who invested in it and keeps force-feeding damage upgrades.
    if _has_weapon("chain"):
        # Geometric falloff over the jump chain: 1 + f + f^2 + ... + f^jumps.
        var chain_multiplier := 1.0
        var jump_scale := 1.0
        for jump in range(mini(chain_jumps, GameConfig.CHAIN_MAX_JUMPS)):
            jump_scale *= chain_falloff
            chain_multiplier += jump_scale
        total_dps += (
            _scaled_weapon_damage(GameConfig.CHAIN_DAMAGE)
            * chain_multiplier
            / maxf(0.01, chain_cooldown)
            * GameConfig.CHAIN_DPS_UPTIME_FACTOR
        )

    if _has_weapon("flak"):
        total_dps += (
            _scaled_weapon_damage(GameConfig.FLAK_DAMAGE)
            * float(maxi(1, flak_pellets))
            / maxf(0.01, flak_cooldown)
            * GameConfig.FLAK_DPS_UPTIME_FACTOR
        )

    if _has_weapon("orbital"):
        total_dps += (
            _scaled_weapon_damage(GameConfig.ORBITAL_DAMAGE)
            * float(clampi(orbital_count, 0, GameConfig.ORBITAL_CAP))
            / maxf(0.01, orbital_hit_interval)
            * GameConfig.ORBITAL_DPS_UPTIME_FACTOR
        )

    if _has_weapon("detonator"):
        total_dps += (
            _scaled_weapon_damage(GameConfig.DETONATOR_DAMAGE)
            / maxf(0.01, detonator_cooldown)
            * GameConfig.DETONATOR_DPS_UPTIME_FACTOR
        )

    return total_dps


func _required_sustained_dps() -> float:
    return _current_normal_enemy_health() / GameConfig.OFFENSE_PITY_TARGET_TTK


func _offense_pity_ratio() -> float:
    return _estimated_sustained_dps() / maxf(0.01, _required_sustained_dps())


func _offense_pity_option_count() -> int:
    if level > GameConfig.OFFENSE_PITY_MAX_LEVEL:
        return 0
    var ratio := _offense_pity_ratio()
    if ratio < GameConfig.OFFENSE_PITY_SEVERE_RATIO:
        return 2
    if ratio < 1.0:
        return 1
    return 0


func xp_required_for(target_level: int) -> int:
    var golomb_value := _golomb(target_level)
    return int(ceil(5.0 * target_level + 0.8 * target_level * target_level + 2.0 * golomb_value * golomb_value))


func _golomb(index: int) -> int:
    while golomb_cache.size() <= index:
        var n := golomb_cache.size()
        var previous := golomb_cache[n - 1]
        golomb_cache.append(1 + golomb_cache[n - golomb_cache[previous]])
    return golomb_cache[index]


func _camera_view_scale() -> float:
    # Capped so the visible half-extent stays below half the world; wrapped
    # rendering picks each entity's nearest image, which is only unambiguous
    # while the view is smaller than the torus.
    return clampf(
        player_move_speed / GameConfig.PLAYER_MOVE_SPEED,
        1.0,
        GameConfig.CAMERA_VIEW_SCALE_MAX
    )


func _update_camera_zoom() -> void:
    var zoom_value := 1.0 / _camera_view_scale()
    camera.zoom = Vector2.ONE * zoom_value


func toggle_targeting_mode() -> void:
    targeting_mode = (
        TargetingMode.STRONGEST
        if targeting_mode == TargetingMode.CLOSEST
        else TargetingMode.CLOSEST
    )
    _emit_stats()


func get_targeting_mode_name() -> String:
    return "STRONGEST" if targeting_mode == TargetingMode.STRONGEST else "CLOSEST"


func _find_target_enemy(origin: Vector2, max_range: float) -> int:
    if targeting_mode == TargetingMode.STRONGEST:
        return _find_strongest_enemy(origin, max_range)
    return _find_nearest_enemy(origin, max_range)


func _find_nearest_enemy(origin: Vector2, max_range: float) -> int:
    var best_index := -1
    var best_distance_squared := max_range * max_range
    for i in range(enemy_positions.size()):
        if enemy_health[i] <= 0.0:
            continue
        var distance_squared := WorldSpace.distance_squared(origin, enemy_positions[i])
        if distance_squared < best_distance_squared:
            best_distance_squared = distance_squared
            best_index = i
    return best_index


func _find_strongest_enemy(origin: Vector2, max_range: float) -> int:
    var best_index := -1
    var best_is_boss := false
    var max_range_squared := max_range * max_range
    var best_distance_squared := max_range_squared

    for i in range(enemy_positions.size()):
        if enemy_health[i] <= 0.0:
            continue
        var distance_squared := WorldSpace.distance_squared(origin, enemy_positions[i])
        if distance_squared >= max_range_squared:
            continue

        var is_boss := enemy_kinds[i] == EnemyKind.BOSS
        if best_index < 0 or (is_boss and not best_is_boss):
            best_index = i
            best_is_boss = is_boss
            best_distance_squared = distance_squared
        elif is_boss == best_is_boss and distance_squared < best_distance_squared:
            best_index = i
            best_distance_squared = distance_squared

    return best_index


func _count_nearby_normals(radius: float) -> int:
    var radius_squared := radius * radius
    var count := 0
    for i in range(enemy_positions.size()):
        if enemy_kinds[i] == EnemyKind.NORMAL and WorldSpace.distance_squared(enemy_positions[i], player_position) <= radius_squared:
            count += 1
    return count


func _rebuild_enemy_grid() -> void:
    _release_grid_buckets()
    enemy_grid.clear()
    for i in range(enemy_positions.size()):
        var cell := _grid_cell(enemy_positions[i])
        var bucket_value: Variant = enemy_grid.get(cell, null)
        if bucket_value == null:
            var new_bucket: Array = grid_bucket_pool.pop_back() if not grid_bucket_pool.is_empty() else []
            new_bucket.append(i)
            enemy_grid[cell] = new_bucket
        else:
            var bucket: Array = bucket_value
            bucket.append(i)


func _release_grid_buckets() -> void:
    for bucket_value in enemy_grid.values():
        var bucket: Array = bucket_value
        bucket.clear()
        grid_bucket_pool.append(bucket)


func _grid_cell(position: Vector2) -> Vector2i:
    return Vector2i(
        posmod(floori(position.x / GameConfig.GRID_CELL_SIZE), GameConfig.GRID_CELL_COUNT),
        posmod(floori(position.y / GameConfig.GRID_CELL_SIZE), GameConfig.GRID_CELL_COUNT)
    )


func _segment_circle_hit_fraction(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
    var segment := finish - start
    var length_squared := segment.length_squared()
    if length_squared <= 0.0001:
        return 0.0 if start.distance_squared_to(center) <= radius * radius else -1.0

    var projection := clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
    var closest := start + segment * projection
    var distance_squared := closest.distance_squared_to(center)
    var radius_squared := radius * radius
    if distance_squared > radius_squared:
        return -1.0

    var half_chord_fraction := sqrt(maxf(0.0, radius_squared - distance_squared) / length_squared)
    return clampf(projection - half_chord_fraction, 0.0, 1.0)


func _sort_projectile_candidates() -> void:
    for i in range(1, projectile_candidate_targets.size()):
        var target := projectile_candidate_targets[i]
        var fraction := projectile_candidate_fractions[i]
        var insertion_index := i - 1
        while insertion_index >= 0 and projectile_candidate_fractions[insertion_index] > fraction:
            projectile_candidate_targets[insertion_index + 1] = projectile_candidate_targets[insertion_index]
            projectile_candidate_fractions[insertion_index + 1] = projectile_candidate_fractions[insertion_index]
            insertion_index -= 1
        projectile_candidate_targets[insertion_index + 1] = target
        projectile_candidate_fractions[insertion_index + 1] = fraction


func _remove_enemy(index: int) -> void:
    var last := enemy_positions.size() - 1
    if index != last:
        enemy_positions[index] = enemy_positions[last]
        enemy_health[index] = enemy_health[last]
        enemy_max_health[index] = enemy_max_health[last]
        enemy_speeds[index] = enemy_speeds[last]
        enemy_damage[index] = enemy_damage[last]
        enemy_radii[index] = enemy_radii[last]
        enemy_xp[index] = enemy_xp[last]
        enemy_kinds[index] = enemy_kinds[last]
        enemy_archetypes[index] = enemy_archetypes[last]
        enemy_fire_timers[index] = enemy_fire_timers[last]
        enemy_sprite_frames[index] = enemy_sprite_frames[last]
        enemy_last_hit_attack[index] = enemy_last_hit_attack[last]
        enemy_reserved_damage[index] = enemy_reserved_damage[last]
        enemy_anchors[index] = enemy_anchors[last]
        enemy_boss_attack_timer[index] = enemy_boss_attack_timer[last]
        enemy_boss_telegraph[index] = enemy_boss_telegraph[last]
        enemy_boss_hit_protection_timer[index] = enemy_boss_hit_protection_timer[last]
    enemy_positions.pop_back()
    enemy_health.pop_back()
    enemy_max_health.pop_back()
    enemy_speeds.pop_back()
    enemy_damage.pop_back()
    enemy_radii.pop_back()
    enemy_xp.pop_back()
    enemy_kinds.pop_back()
    enemy_archetypes.pop_back()
    enemy_fire_timers.pop_back()
    enemy_sprite_frames.pop_back()
    enemy_last_hit_attack.pop_back()
    enemy_reserved_damage.pop_back()
    enemy_anchors.pop_back()
    enemy_boss_attack_timer.pop_back()
    enemy_boss_telegraph.pop_back()
    enemy_boss_hit_protection_timer.pop_back()


func _remove_projectile(index: int) -> void:
    var last := projectile_positions.size() - 1
    if index != last:
        projectile_positions[index] = projectile_positions[last]
        projectile_velocities[index] = projectile_velocities[last]
        projectile_lifetimes[index] = projectile_lifetimes[last]
        projectile_remaining_damage[index] = projectile_remaining_damage[last]
        projectile_attack_ids[index] = projectile_attack_ids[last]
        projectile_radii[index] = projectile_radii[last]
        projectile_kinds[index] = projectile_kinds[last]
    projectile_positions.pop_back()
    projectile_velocities.pop_back()
    projectile_lifetimes.pop_back()
    projectile_remaining_damage.pop_back()
    projectile_attack_ids.pop_back()
    projectile_radii.pop_back()
    projectile_kinds.pop_back()


func _remove_field(index: int) -> void:
    var last := field_positions.size() - 1
    if index != last:
        field_positions[index] = field_positions[last]
        field_lifetimes[index] = field_lifetimes[last]
        field_tick_timers[index] = field_tick_timers[last]
        field_radii[index] = field_radii[last]
    field_positions.pop_back()
    field_lifetimes.pop_back()
    field_tick_timers.pop_back()
    field_radii.pop_back()


func _remove_pickup(index: int) -> void:
    var last := pickup_positions.size() - 1
    if index != last:
        pickup_positions[index] = pickup_positions[last]
    pickup_positions.pop_back()


func get_boss_count() -> int:
    var count := 0
    for kind in enemy_kinds:
        if kind == EnemyKind.BOSS:
            count += 1
    return count


func get_boss_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    for i in range(enemy_positions.size()):
        if enemy_kinds[i] == EnemyKind.BOSS:
            result.append(enemy_positions[i])
    return result


func get_pickup_positions() -> Array[Vector2]:
    return pickup_positions


func get_player_health_fraction() -> float:
    if player_max_health <= 0.0:
        return 0.0
    return player_health / player_max_health


func get_stats_snapshot() -> Dictionary:
    return {
        "health": player_health,
        "max_health": player_max_health,
        "armor": player_armor,
        "damage_reduction": 1.0 - 100.0 / (100.0 + player_armor),
        "regen_rate": player_regen_rate,
        "pickup_radius": player_pickup_radius,
        "level": level,
        "xp": xp,
        "xp_required": xp_required,
        "elapsed": elapsed_time,
        "game_pace": GameConfig.GAME_PACE_MULTIPLIER,
        "paced_elapsed": _paced_elapsed_time(),
        "kills": kills,
        "enemies": enemy_positions.size(),
        "projectiles": projectile_positions.size(),
        "fields": field_positions.size(),
        "pickups": pickup_positions.size(),
        "bosses": get_boss_count(),
        "damage": weapon_damage,
        "damage_multiplier": weapon_damage / GameConfig.NEEDLE_DAMAGE,
        "estimated_dps": _estimated_sustained_dps(),
        "required_dps": _required_sustained_dps(),
        "offense_pity_choices": _offense_pity_option_count(),
        "owned_weapons": owned_weapons.duplicate(),
        "weapon_slots": owned_weapons.size(),
        "weapon_slot_cap": GameConfig.WEAPON_SLOT_CAP,
        "targeting_mode": get_targeting_mode_name(),
        "character": selected_character,
        "character_name": GameConfig.CHARACTERS.get(selected_character, {}).get("name", selected_character),
        "cooldown": weapon_cooldown,
        "projectile_count": weapon_projectile_count,
        "pierce": weapon_pierce,
        "needle_range": weapon_range,
        "sniper_radius": sniper_radius,
        "aura_echoes": aura_echoes,
        "move_speed": player_move_speed,
        "camera_zoom": camera.zoom.x,
        "one_shot_protection": player_one_shot_protection_timer > 0.0,
        "surge": surge_active,
        "fps": Engine.get_frames_per_second(),
    }


func _emit_stats() -> void:
    stats_updated.emit(get_stats_snapshot())


func _setup_batched_rendering() -> void:
    circle_texture = _make_circle_texture(32)
    sprite_atlas_texture = load(SPRITE_ATLAS_PATH) as Texture2D
    enemy_sprite_material = _make_atlas_material()
    material = enemy_sprite_material

    normal_enemy_multimesh = MultiMesh.new()
    normal_enemy_multimesh.transform_format = MultiMesh.TRANSFORM_2D
    normal_enemy_multimesh.use_colors = true
    normal_enemy_multimesh.use_custom_data = true
    normal_enemy_multimesh.instance_count = GameConfig.ENEMY_CAP
    normal_enemy_multimesh.visible_instance_count = 0
    var enemy_mesh := QuadMesh.new()
    enemy_mesh.size = Vector2.ONE * (GameConfig.NORMAL_ENEMY_RADIUS * 2.0 + 4.0)
    normal_enemy_multimesh.mesh = enemy_mesh

    projectile_multimesh = MultiMesh.new()
    projectile_multimesh.transform_format = MultiMesh.TRANSFORM_2D
    projectile_multimesh.use_colors = true
    projectile_multimesh.instance_count = GameConfig.PROJECTILE_CAP
    projectile_multimesh.visible_instance_count = 0
    var projectile_mesh := QuadMesh.new()
    var maximum_projectile_radius := maxf(GameConfig.NEEDLE_RADIUS, GameConfig.SNIPER_RADIUS)
    projectile_mesh.size = Vector2.ONE * (maximum_projectile_radius * 2.0 + 4.0)
    projectile_multimesh.mesh = projectile_mesh


func _make_atlas_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """shader_type canvas_item;

void vertex() {
	if (INSTANCE_CUSTOM.z > 0.0) {
		UV = UV * INSTANCE_CUSTOM.zw + INSTANCE_CUSTOM.xy;
	}
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material


func _sprite_frame_custom_data(frame_index: int) -> Color:
    var clamped := clampi(frame_index, 0, SPRITE_FRAME_COUNT - 1)
    var column := clamped % SPRITE_ATLAS_COLUMNS
    var row := clamped / SPRITE_ATLAS_COLUMNS
    var u_scale := 1.0 / float(SPRITE_ATLAS_COLUMNS)
    var v_scale := 1.0 / float(SPRITE_ATLAS_ROWS)
    return Color(float(column) * u_scale, float(row) * v_scale, u_scale, v_scale)


func _make_circle_texture(size: int) -> Texture2D:
    var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var center := Vector2(size - 1, size - 1) * 0.5
    var radius_squared := pow(float(size) * 0.46, 2.0)
    for y in range(size):
        for x in range(size):
            var offset := Vector2(x, y) - center
            if offset.length_squared() <= radius_squared:
                image.set_pixel(x, y, Color.WHITE)
    return ImageTexture.create_from_image(image)


func _projectile_visual_scale(radius: float) -> float:
    var maximum_projectile_radius := maxf(GameConfig.NEEDLE_RADIUS, GameConfig.SNIPER_RADIUS)
    return (radius * 2.0 + 4.0) / (maximum_projectile_radius * 2.0 + 4.0)


func _update_render_batches() -> void:
    if normal_enemy_multimesh == null or projectile_multimesh == null:
        return

    var visible_half := GameConfig.VIEW_SIZE * 0.62 * _camera_view_scale()
    var enemy_half := visible_half + Vector2(100.0, 100.0)
    var normal_count := 0
    for i in range(enemy_positions.size()):
        if enemy_kinds[i] != EnemyKind.NORMAL or not _is_near_view(enemy_positions[i], enemy_half):
            continue
        normal_enemy_multimesh.set_instance_transform_2d(
            normal_count,
            Transform2D(0.0, WorldSpace.nearest_image(player_position, enemy_positions[i]))
        )
        normal_enemy_multimesh.set_instance_color(normal_count, Color.WHITE)
        normal_enemy_multimesh.set_instance_custom_data(
            normal_count,
            _sprite_frame_custom_data(enemy_sprite_frames[i])
        )
        normal_count += 1
    normal_enemy_multimesh.visible_instance_count = normal_count

    var projectile_half := visible_half + Vector2(80.0, 80.0)
    var projectile_count := 0
    for projectile_index in range(projectile_positions.size()):
        var position := WorldSpace.nearest_image(player_position, projectile_positions[projectile_index])
        if not _is_near_view(position, projectile_half):
            continue
        var visual_scale := _projectile_visual_scale(projectile_radii[projectile_index])
        var projectile_transform := Transform2D.IDENTITY
        projectile_transform.x *= visual_scale
        projectile_transform.y *= visual_scale
        projectile_transform.origin = position
        projectile_multimesh.set_instance_transform_2d(projectile_count, projectile_transform)
        var projectile_color := Color(0.55, 0.95, 1.0, 1.0)
        match projectile_kinds[projectile_index]:
            ProjectileKind.SNIPER:
                projectile_color = Color(1.0, 0.78, 0.22, 1.0)
            ProjectileKind.FLAK:
                projectile_color = Color(1.0, 0.55, 0.30, 1.0)
        projectile_multimesh.set_instance_color(projectile_count, projectile_color)
        projectile_count += 1
    projectile_multimesh.visible_instance_count = projectile_count


func _draw() -> void:
    _draw_background_grid()

    var visible_half := GameConfig.VIEW_SIZE * 0.62 * _camera_view_scale()
    for field_index in range(field_positions.size()):
        var field_position := WorldSpace.nearest_image(player_position, field_positions[field_index])
        if not _is_near_view(field_position, visible_half + Vector2(180.0, 180.0)):
            continue
        var life_fraction := clampf(field_lifetimes[field_index] / maxf(0.001, field_duration), 0.0, 1.0)
        draw_circle(field_position, field_radii[field_index], Color(0.22, 0.72, 0.36, 0.10 + 0.10 * life_fraction))
        draw_arc(field_position, field_radii[field_index], 0.0, TAU, 48, Color(0.34, 0.94, 0.50, 0.48), 3.0)

    for raw_pickup_position in pickup_positions:
        var position := WorldSpace.nearest_image(player_position, raw_pickup_position)
        if _is_near_view(position, visible_half):
            draw_circle(position, 11.0, Color(0.25, 0.95, 0.45, 0.95))
            draw_line(position + Vector2(-6.0, 0.0), position + Vector2(6.0, 0.0), Color.WHITE, 3.0)
            draw_line(position + Vector2(0.0, -6.0), position + Vector2(0.0, 6.0), Color.WHITE, 3.0)

    for raw_shot_position in enemy_shot_positions:
        var shot_position := WorldSpace.nearest_image(player_position, raw_shot_position)
        if _is_near_view(shot_position, visible_half):
            draw_circle(shot_position, GameConfig.ARCHETYPE_RANGED_SHOT_RADIUS, Color(1.0, 0.35, 0.25, 0.95))

    for blast_index in range(detonator_blast_positions.size()):
        var blast_position := WorldSpace.nearest_image(player_position, detonator_blast_positions[blast_index])
        if not _is_near_view(blast_position, visible_half + Vector2(200.0, 200.0)):
            continue
        var blast_fraction := 1.0 - detonator_blast_timers[blast_index] / GameConfig.DETONATOR_VISUAL_DURATION
        var blast_radius := detonator_blast_radii[blast_index] * clampf(0.45 + 0.55 * blast_fraction, 0.0, 1.0)
        draw_circle(blast_position, blast_radius, Color(1.0, 0.62, 0.20, 0.30 * (1.0 - blast_fraction)))
        draw_arc(blast_position, blast_radius, 0.0, TAU, 48, Color(1.0, 0.82, 0.34, 1.0 - blast_fraction), 4.0)

    for shell_index in range(detonator_shell_positions.size()):
        var shell_position := WorldSpace.nearest_image(player_position, detonator_shell_positions[shell_index])
        if _is_near_view(shell_position, visible_half):
            draw_circle(shell_position, GameConfig.DETONATOR_RADIUS, Color(1.0, 0.72, 0.26, 0.95))

    if normal_enemy_multimesh != null and sprite_atlas_texture != null:
        draw_multimesh(normal_enemy_multimesh, sprite_atlas_texture)
    elif normal_enemy_multimesh != null and circle_texture != null:
        draw_multimesh(normal_enemy_multimesh, circle_texture)

    for i in range(enemy_positions.size()):
        var position := WorldSpace.nearest_image(player_position, enemy_positions[i])
        if not _is_near_view(position, visible_half + Vector2(100.0, 100.0)):
            continue
        if enemy_kinds[i] == EnemyKind.BOSS:
            draw_circle(position, enemy_radii[i] + 7.0, Color(0.22, 0.02, 0.08, 0.95))
            draw_circle(position, enemy_radii[i], Color(0.88, 0.12, 0.26, 1.0))
            draw_circle(position, 15.0, Color(1.0, 0.62, 0.2, 1.0))
            if enemy_boss_hit_protection_timer[i] > 0.0:
                var protection_fraction := clampf(
                    enemy_boss_hit_protection_timer[i] / GameConfig.BOSS_HIT_PROTECTION_DURATION,
                    0.0,
                    1.0
                )
                draw_arc(
                    position,
                    enemy_radii[i] + 12.0,
                    0.0,
                    TAU,
                    48,
                    Color(1.0, 0.72, 0.18, 0.35 + 0.65 * protection_fraction),
                    5.0
                )
            var health_fraction := clampf(enemy_health[i] / enemy_max_health[i], 0.0, 1.0)
            draw_rect(Rect2(position + Vector2(-48.0, -58.0), Vector2(96.0, 7.0)), Color(0.08, 0.08, 0.10, 0.9), true)
            draw_rect(Rect2(position + Vector2(-48.0, -58.0), Vector2(96.0 * health_fraction, 7.0)), Color(0.95, 0.22, 0.28, 1.0), true)
            if enemy_boss_telegraph[i] > 0.0:
                var pulse := 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.018)
                draw_circle(position, 220.0, Color(1.0, 0.12, 0.08, pulse * 0.18))
                draw_arc(position, 220.0, 0.0, TAU, 80, Color(1.0, 0.24, 0.12, pulse), 5.0)
        else:
            continue

    if projectile_multimesh != null and circle_texture != null:
        draw_multimesh(projectile_multimesh, circle_texture)

    for orbital_index in range(orbital_positions.size()):
        var orbital_position := WorldSpace.nearest_image(player_position, orbital_positions[orbital_index])
        if not _is_near_view(orbital_position, visible_half):
            continue
        draw_circle(orbital_position, orbital_hit_radius, Color(0.45, 0.85, 1.0, 0.85))
        draw_arc(orbital_position, orbital_hit_radius, 0.0, TAU, 20, Color(0.85, 0.97, 1.0, 0.95), 2.0)

    if chain_visual_timer > 0.0 and chain_visual_points.size() > 1:
        var chain_fade := chain_visual_timer / GameConfig.CHAIN_VISUAL_DURATION
        var chain_color := Color(0.65, 0.85, 1.0, chain_fade)
        for link_index in range(chain_visual_points.size() - 1):
            var link_start := WorldSpace.nearest_image(player_position, chain_visual_points[link_index])
            var link_end := WorldSpace.nearest_image(link_start, chain_visual_points[link_index + 1])
            draw_line(link_start, link_end, chain_color, 3.0)

    if aura_visual_timer > 0.0:
        var aura_fraction := 1.0 - aura_visual_timer / GameConfig.AURA_VISUAL_DURATION
        draw_arc(
            player_position,
            aura_radius * clampf(0.35 + 0.65 * aura_fraction, 0.0, 1.0),
            0.0,
            TAU,
            72,
            Color(0.72, 0.36, 1.0, 1.0 - aura_fraction),
            7.0
        )

    if player_one_shot_protection_timer > 0.0:
        var protection_fraction := player_one_shot_protection_timer / GameConfig.PLAYER_ONE_SHOT_PROTECTION_VISUAL_DURATION
        draw_arc(
            player_position,
            GameConfig.PLAYER_RADIUS + 13.0 + 5.0 * (1.0 - protection_fraction),
            0.0,
            TAU,
            48,
            Color(1.0, 0.88, 0.25, protection_fraction),
            5.0
        )

    var player_flash := player_invulnerability_timer > 0.0 and int(Time.get_ticks_msec() / 55) % 2 == 0
    var player_color := Color.WHITE if player_flash else Color(0.20, 0.82, 1.0, 1.0)
    draw_circle(player_position, GameConfig.PLAYER_RADIUS + 5.0, Color(0.03, 0.12, 0.18, 0.95))
    draw_circle(player_position, GameConfig.PLAYER_RADIUS, player_color)
    draw_circle(player_position, 6.0, Color.WHITE)


func _draw_background_grid() -> void:
    var half := GameConfig.VIEW_SIZE * 0.70 * _camera_view_scale()
    var bounds := Rect2(player_position - half, half * 2.0)
    draw_rect(bounds, Color(0.025, 0.035, 0.055, 1.0), true)
    var spacing := 96.0
    var start_x := floorf(bounds.position.x / spacing) * spacing
    var end_x := bounds.end.x
    var start_y := floorf(bounds.position.y / spacing) * spacing
    var end_y := bounds.end.y
    var x := start_x
    while x <= end_x:
        draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), Color(0.08, 0.11, 0.16, 0.55), 1.0)
        x += spacing
    var y := start_y
    while y <= end_y:
        draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color(0.08, 0.11, 0.16, 0.55), 1.0)
        y += spacing


func _is_near_view(position: Vector2, half_extent: Vector2) -> bool:
    var delta := WorldSpace.delta(player_position, position)
    return absf(delta.x) <= half_extent.x and absf(delta.y) <= half_extent.y
