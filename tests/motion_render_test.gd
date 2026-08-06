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
    var radar_capture: Image = await _capture_pickup_radar(world, hud)
    _verify_pickup_radar(radar_capture)
    var hotbar_capture: Image = await _capture_weapon_hotbar(world, hud)
    _verify_weapon_hotbar(hotbar_capture)
    await _verify_upgrade_overlay_layout(world, hud)
    var base_longshot: Image = await _capture_longshot_size(world, hud, GameConfig.SNIPER_RADIUS)
    var upgraded_longshot: Image = await _capture_longshot_size(
        world,
        hud,
        GameConfig.SNIPER_RADIUS * pow(GameConfig.SNIPER_SIZE_UPGRADE_MULTIPLIER, 2.0)
    )
    _verify_longshot_size_feedback(base_longshot, upgraded_longshot)
    var flak_captures: Array[Image] = await _capture_flak_cone(world, hud)
    _verify_flak_cone_feedback(flak_captures[0], flak_captures[1])

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


func _capture_longshot_size(world: SimulationWorld, hud: GameHud, radius: float) -> Image:
    hud.visible = false
    for enemy_index in range(world.enemy_positions.size()):
        world.enemy_positions[enemy_index] = Vector2(4000.0, 4000.0)
    world._rebuild_enemy_grid()
    _clear_projectiles(world)
    world._spawn_projectile(
        Vector2.RIGHT,
        100.0,
        0.0,
        10.0,
        radius,
        SimulationWorld.ProjectileKind.SNIPER
    )
    world.projectile_positions[0] = world.player_position + Vector2(220.0, 0.0)
    world._update_render_batches()
    world.queue_redraw()
    for frame_index in range(2):
        await process_frame
    return root.get_viewport().get_texture().get_image()


func _verify_longshot_size_feedback(base_image: Image, upgraded_image: Image) -> void:
    var base_metrics := _longshot_visual_metrics(base_image)
    var upgraded_metrics := _longshot_visual_metrics(upgraded_image)
    print("LONGSHOT_SIZE_METRICS ", JSON.stringify({
        "base": base_metrics,
        "upgraded": upgraded_metrics,
    }))
    assert(
        int(upgraded_metrics["width"]) >= int(base_metrics["width"]) + 20,
        "Later Longshot size ranks must visibly widen the projectile"
    )
    assert(
        int(upgraded_metrics["count"]) >= int(float(base_metrics["count"]) * 1.55),
        "Later Longshot size ranks must visibly increase projectile coverage"
    )


func _longshot_visual_metrics(image: Image) -> Dictionary:
    var count := 0
    var minimum_x := 9999
    var maximum_x := -1
    var minimum_y := 9999
    var maximum_y := -1
    for y in range(300, 420):
        for x in range(760, 960):
            var color := image.get_pixel(x, y)
            var bright_cyan := color.b > 0.72 and color.g > 0.58 and color.r < 0.65
            var bright_white := color.r > 0.72 and color.g > 0.72 and color.b > 0.72
            var orange := color.r > 0.65 and color.g > 0.25 and color.g < color.r * 0.85 and color.b < 0.45
            if not bright_cyan and not bright_white and not orange:
                continue
            count += 1
            minimum_x = mini(minimum_x, x)
            maximum_x = maxi(maximum_x, x)
            minimum_y = mini(minimum_y, y)
            maximum_y = maxi(maximum_y, y)
    return {
        "count": count,
        "width": maximum_x - minimum_x + 1,
        "height": maximum_y - minimum_y + 1,
    }


func _capture_flak_cone(world: SimulationWorld, hud: GameHud) -> Array[Image]:
    hud.visible = false
    _clear_projectiles(world)
    world._update_render_batches()
    world.flak_visual_timer = 0.0
    world.queue_redraw()
    await process_frame
    var without_cone := root.get_viewport().get_texture().get_image()
    world.flak_visual_direction = Vector2.RIGHT
    world.flak_spread = deg_to_rad(35.0)
    world.flak_range = GameConfig.FLAK_RANGE
    world.flak_visual_timer = GameConfig.FLAK_VISUAL_DURATION
    world.queue_redraw()
    await process_frame
    var with_cone := root.get_viewport().get_texture().get_image()
    return [without_cone, with_cone]


func _verify_flak_cone_feedback(without_cone: Image, with_cone: Image) -> void:
    var changed_orange_pixels := 0
    for y in range(120, 600):
        for x in range(640, 1160):
            var before := without_cone.get_pixel(x, y)
            var after := with_cone.get_pixel(x, y)
            var difference := (
                absf(after.r - before.r)
                + absf(after.g - before.g)
                + absf(after.b - before.b)
            )
            if (
                after.r > 0.45
                and after.r > after.g * 1.25
                and after.r > after.b * 1.8
                and difference > 0.18
            ):
                changed_orange_pixels += 1
    print("FLAK_CONE_METRICS ", JSON.stringify({
        "changed_orange_pixels": changed_orange_pixels,
    }))
    assert(changed_orange_pixels >= 900, "Flak fire must visibly flash its current cone boundaries")


func _clear_projectiles(world: SimulationWorld) -> void:
    world.projectile_positions.clear()
    world.projectile_velocities.clear()
    world.projectile_lifetimes.clear()
    world.projectile_remaining_damage.clear()
    world.projectile_attack_ids.clear()
    world.projectile_radii.clear()
    world.projectile_kinds.clear()
    world.projectile_per_target_damage.clear()
    world.projectile_hit_enemy_ids.clear()
    world.projectile_homing_strengths.clear()
    world.projectile_homing_aim_positions.clear()
    world.projectile_homing_refresh_timers.clear()
    world.projectile_homing_has_targets.clear()




func _verify_upgrade_overlay_layout(world: SimulationWorld, hud: GameHud) -> void:
    hud.reset_display()
    hud.visible = true
    world.weapon_upgrade_levels["needle_homing"] = 2
    world.global_upgrade_levels["attack_speed"] = GameConfig.GLOBAL_UPGRADE_CAPS["attack_speed"] + 1
    var options: Array[String] = ["damage", "needle_homing", "attack_speed"]
    hud.show_upgrade(
        options,
        "BOSS REWARD",
        "Choose a weapon upgrade",
        world.get_upgrade_progress_snapshot(options)
    )
    for frame_index in range(3):
        await process_frame
    var viewport_size := root.get_viewport().get_visible_rect().size
    var panel_rect := Rect2(hud.upgrade_panel.position, hud.upgrade_panel.size)
    print("UPGRADE_OVERLAY_METRICS ", JSON.stringify({
        "viewport_width": viewport_size.x,
        "viewport_height": viewport_size.y,
        "panel_x": panel_rect.position.x,
        "panel_y": panel_rect.position.y,
        "panel_width": panel_rect.size.x,
        "panel_height": panel_rect.size.y,
        "panel_right": panel_rect.end.x,
        "panel_bottom": panel_rect.end.y,
        "button_height": hud.upgrade_buttons[0].size.y,
    }))
    assert(panel_rect.position.x >= 0.0, "The rendered boss reward modal must not clip left of the viewport")
    assert(panel_rect.end.x <= viewport_size.x, "The rendered boss reward modal must not clip right of the viewport")
    assert(panel_rect.position.y >= 0.0, "The rendered upgrade modal must not clip above the viewport")
    assert(panel_rect.end.y <= viewport_size.y, "The rendered upgrade modal must not clip below the viewport")
    assert(panel_rect.size.y <= 420.0, "Rank labels must not enlarge the rendered upgrade modal")
    assert(hud.upgrade_buttons[0].text.contains("RANK 0"), "Unlimited rank progress must remain visible in the compact card")
    assert(hud.upgrade_buttons[1].text.contains("RANK 2/4"), "Capped rank progress must remain visible in the compact card")
    assert(hud.upgrade_buttons[2].text.contains("RANK 9/8"), "Overcap rank progress must remain visible in the compact card")
    hud.hide_upgrade()

func _capture_weapon_hotbar(world: SimulationWorld, hud: GameHud) -> Image:
    hud.reset_display()
    hud.visible = true
    world.owned_weapons.assign(["needle", "sniper", "aura", "detonator"])
    world.weapon_targeting_modes["needle"] = SimulationWorld.TargetingMode.STRONGEST
    world.weapon_targeting_modes["sniper"] = SimulationWorld.TargetingMode.CLOSEST
    world.weapon_targeting_modes["detonator"] = SimulationWorld.TargetingMode.STRONGEST
    world._emit_stats()
    for frame_index in range(3):
        await process_frame
    return root.get_viewport().get_texture().get_image()


func _verify_weapon_hotbar(image: Image) -> void:
    var slot_colors := ["orange", "cyan", "teal", "orange"]
    var matching_pixels: Array[int] = [0, 0, 0, 0]
    for slot_index in range(4):
        var start_x := 480 + slot_index * 143
        var end_x := start_x + 127
        for y in range(48, 101):
            for x in range(start_x, end_x):
                var color := image.get_pixel(x, y)
                match slot_colors[slot_index]:
                    "orange":
                        if color.r > 0.65 and color.g > 0.28 and color.g < color.r * 0.82 and color.b < 0.35:
                            matching_pixels[slot_index] += 1
                    "cyan":
                        if color.g > 0.62 and color.b > 0.68 and color.r < 0.30:
                            matching_pixels[slot_index] += 1
                    "teal":
                        if color.g > 0.65 and color.b > 0.52 and color.r < 0.40:
                            matching_pixels[slot_index] += 1
    print("WEAPON_HOTBAR_METRICS ", JSON.stringify({
        "slot_1_orange": matching_pixels[0],
        "slot_2_cyan": matching_pixels[1],
        "slot_3_teal": matching_pixels[2],
        "slot_4_orange": matching_pixels[3],
    }))
    for slot_index in range(4):
        assert(matching_pixels[slot_index] >= 20, "Weapon hotbar slot %d must visibly render its targeting color" % (slot_index + 1))


func _capture_pickup_radar(world: SimulationWorld, hud: GameHud) -> Image:
    hud.reset_display()
    world.pickup_positions.clear()
    world.player_health = world.player_max_health * 0.49
    world.pickup_positions.append(world.player_position + Vector2(900.0, 0.0))
    hud.visible = true
    hud.minimap._update_marker_instances()
    hud.minimap.queue_redraw()
    for frame_index in range(3):
        await process_frame
    return root.get_viewport().get_texture().get_image()


func _verify_pickup_radar(image: Image) -> void:
    # HUD minimap origin is (1068, 18). A pickup 900 world pixels to the right
    # lands about 34 screen pixels right of radar center, away from the player,
    # sweep origin, rings, and border.
    var teal_pixels := 0
    var white_pixels := 0
    for y in range(103, 128):
        for x in range(1188, 1215):
            var color := image.get_pixel(x, y)
            if color.g > 0.62 and color.b > 0.52 and color.g > color.r * 1.45:
                teal_pixels += 1
            if color.r > 0.82 and color.g > 0.82 and color.b > 0.82:
                white_pixels += 1
    print("PICKUP_RADAR_METRICS ", JSON.stringify({
        "teal_pixels": teal_pixels,
        "white_pixels": white_pixels,
    }))
    assert(teal_pixels >= 20, "A low-health player must see the teal pickup marker on the radar")
    assert(white_pixels >= 8, "The pickup radar marker must retain its white repair cross")


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
