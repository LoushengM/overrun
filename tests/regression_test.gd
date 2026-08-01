extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed_scene: PackedScene = load("res://scenes/main.tscn")
    var scene: Node = packed_scene.instantiate()
    root.add_child(scene)
    await process_frame

    var world := scene.get_node("World") as SimulationWorld
    var hud := scene.get_node("HUD") as GameHud

    _test_pause_and_keyboard_selection(scene, world, hud)
    _test_projectile_damage_conservation(world)
    _test_damage_pity(world)
    _test_player_invulnerability(world)
    _test_enemy_speed_scaling(world)
    _test_boss_scaling_and_protection(world)
    _test_weapon_slots_and_boss_rewards(scene, world, hud)
    _test_targeting_modes(scene, world, hud)
    _test_weapon_firing_rules(world)

    scene.queue_free()
    await process_frame
    print("REGRESSION_TEST_OK")
    quit()


func _test_pause_and_keyboard_selection(scene: Node, world: SimulationWorld, hud: GameHud) -> void:
    assert(scene.process_mode == Node.PROCESS_MODE_ALWAYS, "Game root must keep handling pause-menu input")
    assert(world.process_mode == Node.PROCESS_MODE_PAUSABLE, "World must stop processing during upgrades")

    world.pending_upgrade = true
    var old_pierce := world.weapon_pierce
    var options: Array[String] = ["damage", "needle_pierce", "armor"]
    scene.call("_on_level_up_requested", options)
    assert(paused, "Level-up must pause the scene tree")
    assert(hud.upgrade_overlay.visible, "Level-up choices must be visible")

    var key_event := InputEventKey.new()
    key_event.keycode = KEY_2
    key_event.pressed = true
    hud._input(key_event)
    assert(not paused, "Choosing an upgrade must resume the scene tree")
    assert(world.weapon_pierce == old_pierce + 1, "Key 2 must choose the second upgrade")


func _test_projectile_damage_conservation(world: SimulationWorld) -> void:
    _clear_combat_state(world)
    world.is_running = true
    world.player_position = Vector2.ZERO
    world.weapon_damage = 10.0
    world.weapon_pierce = 0
    world._add_enemy(Vector2(100.0, 0.0), 10.0, 0.0, 0.0, 14.0, 1, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._spawn_projectile(Vector2.RIGHT)
    world._spawn_projectile(Vector2.RIGHT)
    world._rebuild_enemy_grid()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_projectiles(0.10)

    assert(world.hit_targets.size() == 1, "Only one projectile should reserve a lethal hit")
    assert(world.projectile_positions.size() == 1, "The redundant projectile must survive an already-lethal collision")

    world._resolve_hits()
    world._process_deaths()
    assert(world.enemy_positions.is_empty(), "The lethal hit must still kill the enemy")

    _clear_combat_state(world)
    world.weapon_damage = 10.0
    world.weapon_pierce = 0
    world._add_enemy(Vector2(70.0, 0.0), 10.0, 0.0, 0.0, 14.0, 1, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(110.0, 0.0), 5.0, 0.0, 0.0, 14.0, 1, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._spawn_projectile(Vector2.LEFT)
    world.projectile_positions[0] = Vector2(140.0, 0.0)
    world.projectile_velocities[0] = Vector2(-900.0, 0.0)
    world._rebuild_enemy_grid()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_projectiles(0.10)

    assert(world.hit_targets == [1, 0], "Projectile hits must resolve from nearest to farthest along the path")
    assert(world.hit_damage.size() == 2, "Overkill damage must carry into the next enemy")
    assert(is_equal_approx(world.hit_damage[0], 5.0), "The first enemy should consume only its remaining 5 HP")
    assert(is_equal_approx(world.hit_damage[1], 5.0), "The remaining 5 damage should carry into the second enemy")
    assert(world.projectile_positions.is_empty(), "A projectile must expire when its damage budget is exhausted")

    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[0], 5.0), "The second enemy should retain 5 HP")
    assert(is_equal_approx(world.enemy_health[1], 0.0), "The first enemy should be killed")

    _clear_combat_state(world)
    world.weapon_damage = 10.0
    world.weapon_pierce = 1
    world._spawn_projectile(Vector2.RIGHT)
    assert(is_equal_approx(world.projectile_remaining_damage[0], 20.0), "Needle pierce must add one full damage budget")


func _test_damage_pity(world: SimulationWorld) -> void:
    world.elapsed_time = 180.0
    world.weapon_damage = 10.0
    assert(world._is_damage_pity_active(), "Damage pity must activate when enemy HP outscales base damage")
    for roll_index in range(20):
        var pity_options := world._roll_upgrade_options()
        assert(pity_options.size() == 3, "Damage pity rolls must still contain three choices")
        assert(pity_options.has("damage"), "Damage pity must guarantee a damage choice")
        assert(not pity_options.has("pickup_radius"), "Pickup radius must not return to upgrade rolls")
        assert(pity_options[0] != pity_options[1] and pity_options[0] != pity_options[2] and pity_options[1] != pity_options[2], "Upgrade choices must remain unique")

    world.weapon_damage = 100.0
    assert(not world._is_damage_pity_active(), "Damage pity must turn off after damage catches up")


func _test_player_invulnerability(world: SimulationWorld) -> void:
    world.benchmark_mode = false
    world.is_running = true
    world.player_health = 100.0
    world.player_armor = 0.0
    world.player_invulnerability_timer = 0.0
    world._apply_player_damage(10.0, true)
    assert(is_equal_approx(world.player_health, 90.0), "The first hit must damage the player")
    assert(world.player_invulnerability_timer > 0.0, "A hit must start player invulnerability frames")
    world._apply_player_damage(10.0, true)
    assert(is_equal_approx(world.player_health, 90.0), "Invulnerability frames must block immediate follow-up damage")
    world.player_invulnerability_timer = 0.0
    world._apply_player_damage(10.0, true)
    assert(is_equal_approx(world.player_health, 80.0), "Damage must resume after invulnerability expires")


func _test_enemy_speed_scaling(world: SimulationWorld) -> void:
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.elapsed_time = 0.0
    world.surge_active = false
    world._add_enemy(Vector2(1000.0, 0.0), 100.0, 100.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 950.0), "Normal enemies must use base speed at run start")

    world.enemy_positions[0] = Vector2(1000.0, 0.0)
    world.elapsed_time = 600.0
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 910.0), "Existing normal enemies must accelerate as run time increases")

    world.enemy_positions[0] = Vector2(2000.0, 0.0)
    world.elapsed_time = 0.0
    world.surge_active = true
    world.surge_time = GameConfig.SURGE_RAMP_TIME
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 1900.0), "A fully ramped surge must double distant normal movement")

    world.enemy_positions[0] = Vector2(400.0, 0.0)
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 350.0), "Surge speed must fade out near the player")


func _test_boss_scaling_and_protection(world: SimulationWorld) -> void:
    world.elapsed_time = 300.0
    assert(is_equal_approx(world._current_boss_health(), 6050.0), "Boss health must scale aggressively by five minutes")

    _clear_combat_state(world)
    world.elapsed_time = 0.0
    world.player_position = Vector2.ZERO
    world.weapon_damage = 100.0
    world.weapon_pierce = 0
    world._add_enemy(Vector2(100.0, 0.0), 1000.0, 0.0, 0.0, 42.0, 20, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    world._spawn_projectile(Vector2.RIGHT)
    world._rebuild_enemy_grid()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_projectiles(0.10)
    assert(is_equal_approx(world.hit_damage[0], 100.0), "The first boss hit must deal full damage")
    assert(world.enemy_boss_hit_protection_timer[0] > 0.0, "The first boss hit must start protection")
    world._resolve_hits()

    world._spawn_projectile(Vector2.RIGHT)
    world._rebuild_enemy_grid()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_projectiles(0.10)
    assert(is_equal_approx(world.hit_damage[0], 20.0), "Boss protection must mitigate 80% of follow-up damage")
    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[0], 880.0), "Boss health must reflect protected follow-up damage")


func _test_weapon_slots_and_boss_rewards(scene: Node, world: SimulationWorld, hud: GameHud) -> void:
    _clear_combat_state(world)
    world.reset_run()
    _clear_combat_state(world)
    world.pending_upgrade = false
    world.pending_boss_rewards = 0
    world.xp = 0
    world._add_enemy(Vector2.ZERO, 0.0, 0.0, 0.0, 42.0, 20, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    world._process_deaths()
    assert(world.pending_boss_rewards == 1, "A defeated boss must queue one weapon reward")
    assert(world.pickup_positions.is_empty(), "Bosses must not drop health pickups")

    var boss_options := world._roll_weapon_upgrade_options()
    assert(boss_options.size() == 3, "A fresh loadout must offer three boss choices")
    var contains_unlock := false
    for boss_option in boss_options:
        assert(GameConfig.WEAPON_UNLOCK_IDS.has(boss_option) or GameConfig.NEEDLE_UPGRADE_IDS.has(boss_option), "Boss rewards must be weapons or owned weapon upgrades")
        contains_unlock = contains_unlock or GameConfig.WEAPON_UNLOCK_IDS.has(boss_option)
    assert(contains_unlock, "Boss rewards must guarantee a new weapon while a slot is open")

    world.weapon_upgrade_levels["needle_projectile_count"] = GameConfig.WEAPON_UPGRADE_CAPS["needle_projectile_count"]
    assert(not world._is_upgrade_eligible("needle_projectile_count"), "Capped weapon upgrades must become ineligible")
    assert(not world._roll_weapon_upgrade_options().has("needle_projectile_count"), "Capped upgrades must disappear from boss rewards")
    world.weapon_upgrade_levels["needle_projectile_count"] = 0

    world._check_boss_reward()
    assert(paused, "A boss reward must pause the run")
    assert(hud.upgrade_title.text == "BOSS REWARD", "Boss rewards must use a distinct title")
    var chosen_upgrade: String = hud.upgrade_buttons[0].get_meta("upgrade_id", "")
    var boss_key_event := InputEventKey.new()
    boss_key_event.keycode = KEY_1
    boss_key_event.pressed = true
    hud._input(boss_key_event)
    assert(not paused, "Choosing a boss reward must resume the run")
    assert(GameConfig.WEAPON_UNLOCK_IDS.has(chosen_upgrade), "The guaranteed first boss choice should be a weapon unlock")
    assert(world.owned_weapons.size() == 2, "Choosing a new weapon must occupy a second slot")

    world.owned_weapons.assign(["needle", "sniper", "aura", "field"])
    assert(world.owned_weapons.size() == GameConfig.WEAPON_SLOT_CAP, "The loadout must cap at four weapons")
    assert(not world._is_upgrade_eligible("unlock_sniper"), "New weapon choices must disappear at the slot cap")
    assert(not world._is_upgrade_eligible("unlock_aura"), "Owned weapons cannot be unlocked twice")


func _test_targeting_modes(scene: Node, world: SimulationWorld, hud: GameHud) -> void:
    world.reset_run()
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.weapon_damage = GameConfig.NEEDLE_DAMAGE
    world.weapon_projectile_count = 1
    world.targeting_mode = SimulationWorld.TargetingMode.CLOSEST

    world._add_enemy(Vector2(100.0, 0.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(0.0, 600.0), 1000.0, 0.0, 0.0, 42.0, 20, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    assert(world._find_target_enemy(Vector2.ZERO, GameConfig.NEEDLE_RANGE) == 0, "Closest targeting must choose the nearby normal enemy")

    var toggle_event := InputEventKey.new()
    toggle_event.keycode = KEY_T
    toggle_event.pressed = true
    scene.call("_unhandled_input", toggle_event)
    assert(world.targeting_mode == SimulationWorld.TargetingMode.STRONGEST, "T must toggle targeting to Strongest")
    assert(world._find_target_enemy(Vector2.ZERO, GameConfig.NEEDLE_RANGE) == 1, "Strongest targeting must prioritize an in-range boss")
    assert(hud.stats_label.text.contains("TARGET STRONGEST"), "The HUD must show the active targeting mode")

    world.needle_timer = 0.0
    world._update_needle(0.0)
    assert(world.projectile_positions.size() == 1, "Needle must fire in Strongest mode")
    assert(world.projectile_velocities[0].y > 0.0 and absf(world.projectile_velocities[0].x) < 0.001, "Strongest Needle fire must aim at the boss instead of the closer normal enemy")

    scene.call("_unhandled_input", toggle_event)
    assert(world.targeting_mode == SimulationWorld.TargetingMode.CLOSEST, "T must toggle targeting back to Closest")


func _test_weapon_firing_rules(world: SimulationWorld) -> void:
    world.reset_run()
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.weapon_damage = GameConfig.NEEDLE_DAMAGE

    # Needle waits when its shortened acquisition range is empty.
    world._add_enemy(Vector2(GameConfig.NEEDLE_RANGE + 50.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.needle_timer = 0.0
    world._update_needle(0.0)
    assert(world.projectile_positions.is_empty(), "Needle must not fire beyond its acquisition range")
    world.enemy_positions[0] = Vector2(GameConfig.NEEDLE_RANGE - 50.0, 0.0)
    world.needle_timer = 0.0
    world._update_needle(0.0)
    assert(world.projectile_positions.size() == 1, "Needle must fire when a target enters range")
    assert(world.projectile_kinds[0] == SimulationWorld.ProjectileKind.NEEDLE, "Needle must create Needle projectiles")

    # Longshot is slower but much stronger and reaches distant targets.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "sniper"])
    world._add_enemy(Vector2(1800.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.sniper_timer = 0.0
    world._update_sniper(0.0)
    assert(world.projectile_positions.size() == 1, "Longshot must fire at distant targets")
    assert(world.projectile_kinds[0] == SimulationWorld.ProjectileKind.SNIPER, "Longshot must create Sniper projectiles")
    assert(is_equal_approx(world.projectile_remaining_damage[0], GameConfig.SNIPER_DAMAGE), "Longshot must use its stronger base damage")

    # Aura pierce repeats damage against every target in the same pulse.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "aura"])
    world.aura_pierce = 2
    world.aura_timer = 0.0
    world._add_enemy(Vector2(100.0, 0.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_aura(0.0)
    assert(world.hit_targets.size() == 3, "Aura pierce must add repeat damage instances to the same target")
    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[0], 64.0), "Three Aura instances should deal 36 total base damage")

    # Mire Field deploys with no target, persists, damages, and slows.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "field"])
    world.field_timer = 0.0
    world._update_field_launcher(0.0)
    assert(world.field_positions.size() == 1, "Mire Field must deploy without a target")
    var field_position := world.field_positions[0]
    world._add_enemy(field_position, 100.0, 100.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_fields(0.01)
    assert(world.hit_targets.size() == 1, "Mire Field must damage enemies inside its persistent zone")
    assert(is_equal_approx(world._field_slow_multiplier_at(field_position), GameConfig.FIELD_SLOW_MULTIPLIER), "Mire Field must slow enemies inside it")
    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[0], 96.0), "Mire Field must apply its damage-over-time tick")

    world.weapon_damage = GameConfig.NEEDLE_DAMAGE * 2.0
    assert(is_equal_approx(world._scaled_weapon_damage(GameConfig.SNIPER_DAMAGE), GameConfig.SNIPER_DAMAGE * 2.0), "Global base damage must scale every weapon")


func _clear_combat_state(world: SimulationWorld) -> void:
    world.enemy_positions.clear()
    world.enemy_health.clear()
    world.enemy_max_health.clear()
    world.enemy_speeds.clear()
    world.enemy_damage.clear()
    world.enemy_radii.clear()
    world.enemy_xp.clear()
    world.enemy_kinds.clear()
    world.enemy_last_hit_attack.clear()
    world.enemy_reserved_damage.clear()
    world.enemy_anchors.clear()
    world.enemy_boss_attack_timer.clear()
    world.enemy_boss_telegraph.clear()
    world.enemy_boss_hit_protection_timer.clear()
    world.projectile_positions.clear()
    world.projectile_velocities.clear()
    world.projectile_lifetimes.clear()
    world.projectile_remaining_damage.clear()
    world.projectile_attack_ids.clear()
    world.projectile_radii.clear()
    world.projectile_kinds.clear()
    world.field_positions.clear()
    world.field_lifetimes.clear()
    world.field_tick_timers.clear()
    world.field_radii.clear()
    world.projectile_candidate_targets.clear()
    world.projectile_candidate_fractions.clear()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._release_grid_buckets()
    world.enemy_grid.clear()
