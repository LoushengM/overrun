extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed_scene: PackedScene = load("res://scenes/main.tscn")
    var scene: Node = packed_scene.instantiate()
    root.add_child(scene)
    await process_frame

    var world := scene.get_node("World") as SimulationWorld
    var hud := scene.get_node("HUD") as CanvasLayer
    hud.visible = false
    world.reset_run()
    world.is_running = false

    # Keep all spawned enemies outside both captured views without mutating the
    # parallel entity arrays. The test then isolates camera, player, and floor.
    for enemy_index in range(world.enemy_positions.size()):
        world.enemy_positions[enemy_index] = Vector2(4000.0, 4000.0)
    world._rebuild_enemy_grid()

    var first: Image = await _capture(world, Vector2(1000.0, 1000.0), 3)
    # Capture the first presented frame after movement starts. This is the frame
    # that used to expose the gray clear buffer while camera smoothing caught up.
    var second: Image = await _capture(world, Vector2(1120.0, 1000.0), 1)
    _verify_captures(first, second)
    var ranged_capture: Image = await _capture_ranged_threat(world)
    _verify_ranged_threat(ranged_capture)

    scene.queue_free()
    await process_frame
    print("MOTION_RENDER_TEST_OK")
    quit()


func _capture(world: SimulationWorld, position: Vector2, frame_count: int) -> Image:
    world.player_position = position
    world.camera.position = position
    world.camera.force_update_scroll()
    world._update_render_batches()
    world.queue_redraw()
    for frame_index in range(frame_count):
        await process_frame
    return root.get_viewport().get_texture().get_image()


func _capture_ranged_threat(world: SimulationWorld) -> Image:
    var ranged_position := world.player_position + Vector2(220.0, 0.0)
    world._add_enemy(
        ranged_position,
        1000.0,
        0.0,
        0.0,
        GameConfig.NORMAL_ENEMY_RADIUS * GameConfig.ARCHETYPE_RANGED_RADIUS,
        0,
        SimulationWorld.EnemyKind.NORMAL,
        Vector2.ZERO,
        SimulationWorld.EnemyArchetype.RANGED
    )
    world._update_render_batches()
    world.queue_redraw()
    for frame_index in range(3):
        await process_frame
    return root.get_viewport().get_texture().get_image()


func _verify_ranged_threat(image: Image) -> void:
    var red_pixels := 0
    var bright_red_pixels := 0
    for y in range(320, 402):
        for x in range(815, 907):
            var color := image.get_pixel(x, y)
            if color.r > 0.28 and color.r > color.g * 1.65 and color.r > color.b * 1.65:
                red_pixels += 1
                if color.r > 0.70:
                    bright_red_pixels += 1
    print("RANGED_RENDER_METRICS ", JSON.stringify({
        "red_pixels": red_pixels,
        "bright_red_pixels": bright_red_pixels,
    }))
    assert(red_pixels >= 350, "The ranged-enemy halo must remain visible against the rendered floor")
    assert(bright_red_pixels >= 90, "The ranged-enemy silhouette must retain a bright red warning rim")


func _verify_captures(first: Image, second: Image) -> void:
    var first_centroid := _player_centroid(first)
    var second_centroid := _player_centroid(second)
    assert(
        first_centroid.distance_to(second_centroid) <= 1.0,
        "The player must remain screen-locked while the camera moves"
    )

    var shifted_error := 0.0
    var unchanged_error := 0.0
    var samples := 0
    for y in range(80, 250, 2):
        for x in range(80, 900, 2):
            var moved_pixel := second.get_pixel(x, y)
            var shifted_pixel := first.get_pixel(x + 120, y)
            var unchanged_pixel := first.get_pixel(x, y)
            shifted_error += _color_distance(moved_pixel, shifted_pixel)
            unchanged_error += _color_distance(moved_pixel, unchanged_pixel)
            samples += 1
    shifted_error /= float(samples)
    unchanged_error /= float(samples)

    print("MOTION_RENDER_METRICS ", JSON.stringify({
        "player_a": first_centroid,
        "player_b": second_centroid,
        "shifted_error": shifted_error,
        "unchanged_error": unchanged_error,
    }))
    assert(
        shifted_error < unchanged_error * 0.25,
        "The floor must counter-scroll with the camera instead of following the player"
    )

    # The arena must cover the viewport with its dark palette. A neutral gray
    # corner indicates that the clear buffer was exposed during a camera step.
    for corner in [Vector2i(1, 1), Vector2i(1278, 1), Vector2i(1, 718), Vector2i(1278, 718)]:
        var color := second.get_pixelv(corner)
        assert(
            color.b > color.r * 1.10 and color.get_luminance() < 0.18,
            "Camera movement must not expose a gray clear-buffer edge"
        )


func _player_centroid(image: Image) -> Vector2:
    var total := Vector2.ZERO
    var count := 0
    for y in range(290, 430):
        for x in range(570, 710):
            var color := image.get_pixel(x, y)
            if color.g > 0.57 and color.b > 0.59 and color.b > color.r + 0.08:
                total += Vector2(x, y)
                count += 1
    assert(count > 0, "The player emissive pixels must be visible in the capture")
    return total / float(count)


func _color_distance(first: Color, second: Color) -> float:
    return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
