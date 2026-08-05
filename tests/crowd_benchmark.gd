extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed_scene: PackedScene = load("res://scenes/main.tscn")
    var scene: Node = packed_scene.instantiate()
    root.add_child(scene)
    await process_frame

    var world := scene.get_node("World") as SimulationWorld
    _clear_combat_state(world)
    world.benchmark_mode = true
    world.is_running = true
    world.player_position = Vector2.ZERO
    world.needle_timer = 9999.0

    # 1200 enemies is the stated performance promise, so the grid has to match
    # it -- 32x25 only ever exercised 800.
    var columns := 40
    var rows := 30
    var spacing := Vector2(38.0, 27.0)
    var origin := Vector2(-float(columns - 1) * spacing.x * 0.5, -float(rows - 1) * spacing.y * 0.5)
    for row in range(rows):
        for column in range(columns):
            world._add_enemy(
                origin + Vector2(column * spacing.x, row * spacing.y),
                1000000.0,
                0.0,
                0.0,
                GameConfig.NORMAL_ENEMY_RADIUS,
                0,
                SimulationWorld.EnemyKind.NORMAL,
                Vector2.ZERO
            )

    world._update_render_batches()
    var started := Time.get_ticks_msec()
    while Time.get_ticks_msec() - started < 4000:
        await process_frame

    print("CROWD_BENCHMARK_RESULT ", JSON.stringify({
        "enemies": world.enemy_positions.size(),
        "visible_instances": world.normal_enemy_multimesh.visible_instance_count,
        "fps": Engine.get_frames_per_second(),
    }))
    scene.queue_free()
    await process_frame
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
    world.enemy_boss_hit_protection_timer.clear()
    world.enemy_update_accumulators.clear()
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
    world.enemy_query_candidates.clear()
    world._release_grid_buckets()
    world.enemy_grid.clear()
    world.enemy_grid_cells.clear()
    world.enemy_grid_slots.clear()
    world.enemy_update_tick = 0
