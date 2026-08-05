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
    world.is_running = true

    # Keep the population alive so this measures sustained movement, spatial
    # queries, projectile sweeps, field checks, batch uploads, and rendering at
    # the same time instead of turning into a kill-throughput benchmark.
    for enemy_index in range(world.enemy_positions.size()):
        world.enemy_health[enemy_index] = 1000000000.0
        world.enemy_max_health[enemy_index] = 1000000000.0
        world.enemy_damage[enemy_index] = 0.0

    for field_index in range(GameConfig.FIELD_CAP):
        var angle := TAU * float(field_index) / float(GameConfig.FIELD_CAP)
        var ring := 240.0 + float(field_index % 8) * 155.0
        world.field_positions.append(
            WorldSpace.wrap_position(world.player_position + Vector2.from_angle(angle) * ring)
        )
        world.field_lifetimes.append(100.0)
        world.field_tick_timers.append(float(field_index % 4) * 0.05)
        world.field_radii.append(world.field_radius)
    world._rebuild_field_grid()

    for shot_index in range(GameConfig.ENEMY_SHOT_CAP):
        var angle := TAU * float(shot_index) / float(GameConfig.ENEMY_SHOT_CAP)
        world.enemy_shot_positions.append(
            WorldSpace.wrap_position(
                world.player_position
                + Vector2.from_angle(angle) * (180.0 + float(shot_index % 18) * 70.0)
            )
        )
        world.enemy_shot_velocities.append(Vector2.from_angle(angle + PI * 0.5) * 65.0)
        world.enemy_shot_lifetimes.append(100.0)
        world.enemy_shot_damage.append(0.0)

    # Warm shaders, texture uploads, and the stagger scheduler before timing.
    for frame_index in range(60):
        await process_frame

    var started := Time.get_ticks_usec()
    var previous_frame := started
    var frames := 0
    var frame_times := PackedFloat32Array()
    while Time.get_ticks_usec() - started < 4000000:
        await process_frame
        var now := Time.get_ticks_usec()
        frame_times.append(float(now - previous_frame) / 1000.0)
        previous_frame = now
        frames += 1
    var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
    frame_times.sort()
    var percentile_95 := frame_times[clampi(ceili(float(frame_times.size()) * 0.95) - 1, 0, frame_times.size() - 1)]
    var percentile_99 := frame_times[clampi(ceili(float(frame_times.size()) * 0.99) - 1, 0, frame_times.size() - 1)]
    var maximum_frame_ms := frame_times[frame_times.size() - 1]

    print("GAMEPLAY_STRESS_RESULT ", JSON.stringify({
        "fps": float(frames) / elapsed,
        "frame_ms_p95": percentile_95,
        "frame_ms_p99": percentile_99,
        "maximum_frame_ms": maximum_frame_ms,
        "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
        "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "enemies": world.enemy_positions.size(),
        "projectiles": world.projectile_positions.size(),
        "enemy_shots": world.enemy_shot_positions.size(),
        "fields": world.field_positions.size(),
        "grid_cells": world.enemy_grid.size(),
    }))

    scene.queue_free()
    await process_frame
    quit()
