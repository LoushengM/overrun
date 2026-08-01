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

    assert(scene.process_mode == Node.PROCESS_MODE_ALWAYS, "Game root must keep handling pause-menu input")
    assert(world.process_mode == Node.PROCESS_MODE_PAUSABLE, "World must stop processing during level-up")

    world.pending_upgrade = true
    var old_pierce := world.weapon_pierce
    var options: Array[String] = ["damage", "pierce", "armor"]
    scene.call("_on_level_up_requested", options)
    assert(paused, "Level-up must pause the scene tree")
    assert(hud.upgrade_overlay.visible, "Level-up choices must be visible")

    var key_event := InputEventKey.new()
    key_event.keycode = KEY_2
    key_event.pressed = true
    hud._input(key_event)
    assert(not paused, "Choosing an upgrade must resume the scene tree")
    assert(world.weapon_pierce == old_pierce + 1, "Key 2 must choose the second upgrade")

    _clear_combat_state(world)
    world.is_running = true
    world.player_position = Vector2.ZERO
    world.weapon_damage = 10.0
    world.weapon_pierce = 0
    world._add_enemy(Vector2(100.0, 0.0), 10.0, 0.0, 0.0, 14.0, 1, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._spawn_projectile(Vector2.RIGHT)
    world._spawn_projectile(Vector2.RIGHT)
    world._rebuild_enemy_grid()
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
    assert(
        is_equal_approx(world.projectile_remaining_damage[0], 20.0),
        "Each pierce level must add one full projectile damage budget"
    )

    world.elapsed_time = 180.0
    world.weapon_damage = 10.0
    assert(world._is_damage_pity_active(), "Damage pity must activate when enemy HP outscales weapon damage")
    for roll_index in range(20):
        var pity_options := world._roll_upgrade_options()
        assert(pity_options.size() == 3, "Damage pity rolls must still contain three choices")
        assert(pity_options.has("damage"), "Damage pity must guarantee a damage choice")
        assert(pity_options[0] != pity_options[1] and pity_options[0] != pity_options[2] and pity_options[1] != pity_options[2], "Upgrade choices must remain unique")

    world.weapon_damage = 100.0
    assert(not world._is_damage_pity_active(), "Damage pity must turn off after damage catches up")

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

    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.elapsed_time = 0.0
    world.surge_active = false
    world._add_enemy(Vector2(1000.0, 0.0), 100.0, 100.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 950.0), "Normal enemies must use their base speed at run start")

    world.enemy_positions[0] = Vector2(1000.0, 0.0)
    world.elapsed_time = 600.0
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 910.0), "Existing normal enemies must accelerate as run time increases")

    world.enemy_positions[0] = Vector2(2000.0, 0.0)
    world.elapsed_time = 0.0
    world.surge_active = true
    world.surge_time = GameConfig.SURGE_RAMP_TIME
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 1900.0), "A fully ramped surge must double distant normal-enemy movement")

    world.enemy_positions[0] = Vector2(400.0, 0.0)
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 350.0), "Surge speed must fade out near the player")

    scene.queue_free()
    await process_frame
    print("REGRESSION_TEST_OK")
    quit()


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
    world.projectile_positions.clear()
    world.projectile_velocities.clear()
    world.projectile_lifetimes.clear()
    world.projectile_remaining_damage.clear()
    world.projectile_attack_ids.clear()
    world.projectile_candidate_targets.clear()
    world.projectile_candidate_fractions.clear()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._release_grid_buckets()
    world.enemy_grid.clear()
