extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed_scene: PackedScene = load("res://scenes/main.tscn")
    var scene: Node = packed_scene.instantiate()
    root.add_child(scene)
    paused = false
    await process_frame

    var world := scene.get_node("World") as SimulationWorld
    world.reset_run()
    world.enable_benchmark(true)
    world.is_running = false
    _fill_visual_caps(world)
    world._update_render_batches()
    world.queue_redraw()

    # Warm shader compilation and texture uploads before timing the sustained
    # workload. This runs through an actual OpenGL window under Xvfb, unlike the
    # dummy-renderer crowd benchmark.
    for frame_index in range(30):
        await process_frame

    var started := Time.get_ticks_msec()
    var frames := 0
    while Time.get_ticks_msec() - started < 4000:
        frames += 1
        await process_frame
    var elapsed := float(Time.get_ticks_msec() - started) / 1000.0

    print("RENDER_BENCHMARK_RESULT ", JSON.stringify({
        "fps": float(frames) / elapsed,
        "engine_fps": Engine.get_frames_per_second(),
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
        "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
        "enemies": world.enemy_positions.size(),
        "fields": world.field_positions.size(),
        "enemy_shots": world.enemy_shot_positions.size(),
        "pickups": world.pickup_positions.size(),
        "blasts": world.detonator_blast_positions.size(),
        "orbitals": world.orbital_positions.size(),
        "bosses": world.get_boss_count(),
    }))

    scene.queue_free()
    await process_frame
    quit()


func _fill_visual_caps(world: SimulationWorld) -> void:
    for i in range(GameConfig.FIELD_CAP):
        var angle := TAU * float(i) / float(GameConfig.FIELD_CAP)
        var ring := 180.0 + float(i % 6) * 105.0
        world.field_positions.append(world.player_position + Vector2.from_angle(angle) * ring)
        world.field_lifetimes.append(world.field_duration)
        world.field_tick_timers.append(1.0)
        world.field_radii.append(world.field_radius)

    for i in range(GameConfig.PICKUP_CAP):
        var angle := TAU * float(i) / float(GameConfig.PICKUP_CAP)
        world.pickup_positions.append(
            world.player_position + Vector2.from_angle(angle) * (120.0 + float(i % 4) * 90.0)
        )

    for i in range(GameConfig.ENEMY_SHOT_CAP):
        var angle := TAU * float(i) / float(GameConfig.ENEMY_SHOT_CAP)
        world.enemy_shot_positions.append(
            world.player_position + Vector2.from_angle(angle) * (100.0 + float(i % 12) * 45.0)
        )
        world.enemy_shot_velocities.append(Vector2.from_angle(angle) * 100.0)
        world.enemy_shot_lifetimes.append(10.0)
        world.enemy_shot_damage.append(1.0)

    for i in range(GameConfig.DETONATOR_BLAST_CAP):
        var angle := TAU * float(i) / float(GameConfig.DETONATOR_BLAST_CAP)
        world.detonator_blast_positions.append(
            world.player_position + Vector2.from_angle(angle) * (170.0 + float(i % 5) * 100.0)
        )
        world.detonator_blast_radii.append(world.detonator_blast_radius)
        world.detonator_blast_timers.append(GameConfig.DETONATOR_VISUAL_DURATION * 0.5)

    for i in range(GameConfig.ORBITAL_CAP):
        var angle := TAU * float(i) / float(GameConfig.ORBITAL_CAP)
        world.orbital_positions.append(
            world.player_position + Vector2.from_angle(angle) * world.orbital_radius
        )
        world.orbital_hit_timers.append(1.0)

    for i in range(GameConfig.BOSS_CAP):
        var angle := TAU * float(i) / float(GameConfig.BOSS_CAP)
        world._add_enemy(
            world.player_position + Vector2.from_angle(angle) * (220.0 + float(i % 3) * 160.0),
            1000.0,
            0.0,
            0.0,
            GameConfig.BOSS_RADIUS,
            0,
            SimulationWorld.EnemyKind.BOSS,
            Vector2.ZERO
        )
