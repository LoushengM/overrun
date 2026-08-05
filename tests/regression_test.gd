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
    var audio := scene.get_node("SoundManager") as SoundManager

    _test_audio_wiring(audio, world, hud)
    _test_visual_overhaul_assets(world, hud)
    _test_incremental_spatial_grid(world)
    _test_motion_rendering(world)
    _test_pause_and_keyboard_selection(scene, world, hud, audio)
    _test_restart_input_and_character_reuse(scene, world, hud, audio)
    _test_projectile_damage_conservation(world)
    _test_offense_pity(world)
    _test_upgrade_roll_weights(world)
    _test_player_invulnerability(world)
    _test_speed_upgrade_camera_zoom(world)
    _test_game_pace_scaling(world)
    _test_population_spawn_curve(world)
    _test_enemy_speed_scaling(world)
    _test_boss_scaling_and_protection(world)
    _test_weapon_slots_and_boss_rewards(scene, world, hud)
    _test_targeting_modes(scene, world, hud)
    _test_weapon_firing_rules(world)
    _test_expanded_weapon_roster(world)
    _test_toroidal_world(world)

    audio.stop_all()
    scene.queue_free()
    for frame_index in range(6):
        await process_frame
    print("REGRESSION_TEST_OK")
    quit()


func _test_audio_wiring(audio: SoundManager, world: SimulationWorld, hud: GameHud) -> void:
    assert(audio != null, "The main scene must include a SoundManager")
    assert(audio.players.size() == SoundManager.PLAYER_POOL_SIZE, "The sound manager must initialize its bounded player pool")
    var expected_cues := [
        "needle_fire",
        "longshot_fire",
        "aura_pulse",
        "mire_deploy",
        "enemy_ranged_fire",
        "enemy_hit",
        "enemy_destroy",
        "boss_hit",
        "player_hit",
        "last_stand",
        "boss_spawn",
        "boss_telegraph",
        "boss_slam",
        "boss_defeat",
        "surge_start",
        "health_pickup",
        "level_up",
        "boss_reward",
        "menu_move",
        "upgrade_select",
        "character_select",
        "menu_back",
        "restart",
        "weapon_unlock",
        "target_toggle",
        "run_over",
        "chain_arc",
        "flak_fire",
        "orbital_contact",
        "detonator_launch",
        "detonator_blast",
    ]
    for cue in expected_cues:
        assert(audio.has_cue(cue), "Missing robot sound cue: %s" % cue)
        assert(audio.get_stream(cue) != null, "Sound cue must have a loaded stream: %s" % cue)
    assert(audio.get_cue_names().size() == expected_cues.size(), "The configured cue set and regression inventory must stay in sync")
    assert(int(SoundManager.CUE_CONFIG["boss_slam"].get("priority", 0)) > int(SoundManager.CUE_CONFIG["needle_fire"].get("priority", 0)), "Boss impacts must outrank frequent weapon voices")

    world.reset_run()
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.weapon_projectile_count = 1
    world.needle_timer = 0.0
    world._add_enemy(Vector2(100.0, 0.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    var emitted_cues: Array[String] = []
    var capture_cue := func(cue: String) -> void:
        emitted_cues.append(cue)
    world.sound_requested.connect(capture_cue)
    world._update_needle(0.0)
    assert(emitted_cues.has("needle_fire"), "Needle fire must request its robot weapon cue")

    emitted_cues.clear()
    world._spawn_enemy_shot(Vector2(100.0, 0.0), Vector2.LEFT, 1.0)
    assert(emitted_cues.has("enemy_ranged_fire"), "Ranged robots must announce a fired energy bolt")

    emitted_cues.clear()
    _clear_combat_state(world)
    world._add_enemy(Vector2(80.0, 0.0), 0.0, 0.0, 0.0, 14.0, 1, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._process_deaths()
    assert(emitted_cues.has("enemy_destroy"), "Destroyed normal robots must have a distinct collapse cue")

    emitted_cues.clear()
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world._add_enemy(Vector2(120.0, 0.0), 100.0, 0.0, 0.0, GameConfig.BOSS_RADIUS, 1, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    world.enemy_boss_telegraph[0] = 0.01
    world._update_enemies(0.02)
    assert(emitted_cues.has("boss_slam"), "A completed boss telegraph must end with a slam impact cue")

    emitted_cues.clear()
    _clear_combat_state(world)
    world.surge_active = false
    world.surge_cooldown = 0.0
    world.nearby_threat = 0
    world.threat_check_timer = 1.0
    world._update_spawning(0.0)
    assert(emitted_cues.has("surge_start"), "A new spawn surge must have an audible warning")

    var hud_cues: Array[String] = []
    var capture_hud_cue := func(cue: String) -> void:
        hud_cues.append(cue)
    hud.sound_requested.connect(capture_hud_cue)
    hud.show_upgrade(["damage", "armor", "max_health"])
    hud._move_upgrade_focus(1)
    assert(hud_cues.has("menu_move"), "Keyboard focus movement must emit the quiet servo navigation cue")
    hud.hide_upgrade()
    hud.sound_requested.disconnect(capture_hud_cue)
    world.sound_requested.disconnect(capture_cue)


func _test_visual_overhaul_assets(world: SimulationWorld, hud: GameHud) -> void:
    assert(world.sprite_atlas_texture != null, "The robot enemy atlas must load")
    assert(world.sprite_atlas_texture.get_size() == Vector2(192, 96), "The robot atlas must keep eight 48px frames")
    var robot_atlas_image := world.sprite_atlas_texture.get_image()
    var ranged_red_pixels := 0
    var ranged_strong_red_pixels := 0
    var ranged_opaque_red_pixels := 0
    for y in range(48):
        for x in range(48 * 3, 48 * 4):
            var pixel := robot_atlas_image.get_pixel(x, y)
            if pixel.a > 0.002 and pixel.r > pixel.g * 3.0 and pixel.r > pixel.b * 3.0:
                ranged_red_pixels += 1
                if pixel.a >= 0.65:
                    ranged_strong_red_pixels += 1
                if pixel.a >= 0.95:
                    ranged_opaque_red_pixels += 1
    assert(ranged_red_pixels >= 800, "Ranged robots must retain a broad red warning halo")
    assert(ranged_strong_red_pixels >= 250, "The ranged warning halo must stay visible against the floor")
    assert(ranged_opaque_red_pixels >= 120, "Ranged robots must retain a solid red silhouette rim")
    var ranged_muzzle := robot_atlas_image.get_pixel(48 * 3 + 45, 24)
    assert(ranged_muzzle.r > 0.90 and ranged_muzzle.g < 0.45, "The ranged robot muzzle must emit red rather than cyan")

    assert(world.floor_texture != null and world.floor_texture.get_size() == Vector2(768, 768), "The industrial floor must be baked into one low-draw-call tile")
    assert(world.projectile_texture != null and world.projectile_texture.get_size() == Vector2(288, 48), "The compact-effect atlas must contain six 48px frames")
    var projectile_atlas_image := world.projectile_texture.get_image()
    var enemy_bolt_core := projectile_atlas_image.get_pixel(48 * 3 + 24, 24)
    assert(enemy_bolt_core.r > 0.95 and enemy_bolt_core.g < 0.40 and enemy_bolt_core.b < 0.35, "Enemy projectile cores must be visibly red")
    var enemy_bolt_tip := projectile_atlas_image.get_pixel(48 * 3 + 40, 24)
    assert(enemy_bolt_tip.r > enemy_bolt_tip.g and enemy_bolt_tip.r > enemy_bolt_tip.b, "Enemy projectile hot points must remain red-tinted")
    assert(world.world_effect_texture != null and world.world_effect_texture.get_size() == Vector2(576, 192), "The large-effect atlas must contain three 192px frames")
    assert(world.boss_texture != null and world.boss_texture.get_size() == Vector2(160, 160), "The spider boss must use one baked texture")
    assert(world.player_texture != null and world.player_texture.get_size() == Vector2(96, 96), "The operator must use one baked texture")
    assert(world.normal_enemy_multimesh.use_custom_data, "Enemy batching must retain atlas UV custom data")
    assert(not world.normal_enemy_multimesh.use_colors, "Enemy buffers must not upload an unused all-white color")
    assert(not world.boss_multimesh.use_colors and not world.boss_multimesh.use_custom_data, "Boss buffers must contain transforms only")
    assert(world.normal_enemy_buffer.size() == GameConfig.ENEMY_CAP * SimulationWorld.MULTIMESH_CUSTOM_STRIDE, "Enemy bulk buffers must match the compact transform-plus-custom layout")
    assert(world.projectile_buffer.size() == SimulationWorld.COMPACT_VISUAL_CAP * SimulationWorld.MULTIMESH_FULL_STRIDE, "Compact visuals must use the bounded bulk buffer")
    assert(world.projectile_multimesh.use_custom_data, "Compact effects must select atlas frames through custom data")
    assert(world.world_effect_multimesh.use_custom_data, "Large effects must select atlas frames through custom data")
    assert(world.projectile_multimesh.instance_count == SimulationWorld.COMPACT_VISUAL_CAP, "The compact render batch must stay bounded independently of the simulation cap")
    assert(hud.minimap.radar_texture != null, "The radar face must be baked into one texture")
    assert(hud.minimap.marker_multimesh != null and hud.minimap.marker_multimesh.use_custom_data, "Radar markers must share one atlas batch")
    assert(hud.upgrade_buttons[0].get_theme_stylebox("focus") is StyleBoxFlat, "Upgrade buttons must expose the cyan keyboard-focus treatment")

    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.pickup_positions.append(Vector2(900.0, 0.0))
    world.pickup_positions.append(Vector2(GameConfig.WORLD_HALF_SIZE - 1.0, 0.0))
    var radar_center := hud.minimap.size * 0.5
    var radar_radius := minf(hud.minimap.size.x, hud.minimap.size.y) * 0.5 - 13.0

    world.player_health = world.player_max_health * 0.50
    var healthy_marker_count := hud.minimap._update_marker_instances(radar_center, radar_radius)
    assert(healthy_marker_count == 1, "Pickup markers must remain hidden at or above 50% health")

    world.player_health = world.player_max_health * 0.49
    var low_health_marker_count := hud.minimap._update_marker_instances(radar_center, radar_radius)
    assert(low_health_marker_count == 3, "Every pickup must appear once health drops below 50%")
    var distant_relative := WorldSpace.delta(
        world.player_position,
        world.pickup_positions[1]
    ) * (radar_radius / (GameConfig.WORLD_HALF_SIZE * 0.72))
    var distant_marker := hud.minimap._radar_marker_position(
        radar_center,
        distant_relative,
        radar_radius - 10.0
    )
    assert(
        is_equal_approx(distant_marker.distance_to(radar_center), radar_radius - 10.0),
        "Distant low-health pickups must pin to the radar rim instead of disappearing"
    )

    world.pickup_positions.clear()
    world.field_positions.append(Vector2(50.0, 0.0))
    world.field_lifetimes.append(world.field_duration)
    world.field_tick_timers.append(1.0)
    world.field_radii.append(world.field_radius)
    world.pickup_positions.append(Vector2(70.0, 0.0))
    world.enemy_shot_positions.append(Vector2(90.0, 0.0))
    world.enemy_shot_velocities.append(Vector2.RIGHT * 100.0)
    world.enemy_shot_lifetimes.append(1.0)
    world.enemy_shot_damage.append(1.0)
    world.detonator_shell_positions.append(Vector2(110.0, 0.0))
    world.detonator_shell_velocities.append(Vector2.RIGHT * 100.0)
    world.detonator_shell_remaining.append(100.0)
    world.detonator_shell_lifetimes.append(1.0)
    world.detonator_blast_positions.append(Vector2(130.0, 0.0))
    world.detonator_blast_radii.append(world.detonator_blast_radius)
    world.detonator_blast_timers.append(GameConfig.DETONATOR_VISUAL_DURATION * 0.5)
    world.orbital_positions.append(Vector2(150.0, 0.0))
    world.orbital_hit_timers.append(1.0)
    world._add_enemy(Vector2(180.0, 0.0), 1000.0, 0.0, 0.0, GameConfig.BOSS_RADIUS, 0, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    world._update_render_batches()
    assert(world.world_effect_multimesh.visible_instance_count == 3, "Fields, pickups, and blasts must share the large-effect batch")
    assert(world.projectile_multimesh.visible_instance_count == 3, "Enemy bolts, shells, and orbitals must share the compact batch")
    assert(world.boss_multimesh.visible_instance_count == 1, "Boss bodies must render through one batch")
    world.reset_run()


func _test_incremental_spatial_grid(world: SimulationWorld) -> void:
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world._add_enemy(Vector2(100.0, 100.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(120.0, 110.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(900.0, 700.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    _assert_enemy_grid_consistent(world)

    world.enemy_positions[0] = Vector2(1200.0, 900.0)
    world._grid_move_enemy(0, world.enemy_positions[0])
    _assert_enemy_grid_consistent(world)
    assert(world._find_nearest_enemy(Vector2(1200.0, 900.0), 80.0) == 0, "Target queries must see an enemy after it crosses grid cells")

    # Removing a middle element swap-moves the last enemy. Its bucket entry,
    # cell, and slot must all be rewritten to the new compact-array index.
    world.enemy_health[1] = 0.0
    world._process_deaths()
    assert(world.enemy_positions.size() == 2, "The grid regression must remove one enemy")
    _assert_enemy_grid_consistent(world)

    world.field_positions.append(Vector2(1200.0, 900.0))
    world.field_lifetimes.append(5.0)
    world.field_tick_timers.append(1.0)
    world.field_radii.append(120.0)
    world._rebuild_field_grid()
    assert(world._field_slow_multiplier_at(Vector2(1200.0, 900.0)) == GameConfig.FIELD_SLOW_MULTIPLIER, "Field slowdown must query the field grid")
    assert(is_equal_approx(world._field_slow_multiplier_at(Vector2(1600.0, 900.0)), 1.0), "Field slowdown must reject distant cells")

    # A synchronized field stack must be spread over multiple physics ticks
    # rather than creating one large periodic spike.
    _clear_combat_state(world)
    world._add_enemy(Vector2.ZERO, 100000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    for field_index in range(SimulationWorld.FIELD_TICK_BUDGET * 2):
        world.field_positions.append(Vector2.ZERO)
        world.field_lifetimes.append(10.0)
        world.field_tick_timers.append(0.0)
        world.field_radii.append(100.0)
    world._rebuild_field_grid()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_fields(0.0)
    assert(world.hit_targets.size() == SimulationWorld.FIELD_TICK_BUDGET, "Only the bounded field-work budget may resolve in one tick")
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_fields(0.0)
    assert(world.hit_targets.size() == SimulationWorld.FIELD_TICK_BUDGET, "The rotating field cursor must process the deferred half on the next tick")
    _clear_combat_state(world)


func _assert_enemy_grid_consistent(world: SimulationWorld) -> void:
    var enemy_count := world.enemy_positions.size()
    assert(world.enemy_grid_cells.size() == enemy_count, "Every enemy must own one grid cell")
    assert(world.enemy_grid_slots.size() == enemy_count, "Every enemy must own one grid slot")
    var seen: Array[int] = []
    seen.resize(enemy_count)
    seen.fill(0)
    for cell_variant in world.enemy_grid.keys():
        var cell: Vector2i = cell_variant
        var bucket: Array = world.enemy_grid[cell]
        for slot in range(bucket.size()):
            var enemy_index := int(bucket[slot])
            assert(enemy_index >= 0 and enemy_index < enemy_count, "Grid buckets must never retain removed enemy indices")
            assert(world.enemy_grid_cells[enemy_index] == cell, "Enemy cell metadata must match its bucket")
            assert(world.enemy_grid_slots[enemy_index] == slot, "Enemy slot metadata must match its bucket position")
            seen[enemy_index] += 1
    for enemy_index in range(enemy_count):
        assert(seen[enemy_index] == 1, "Every enemy must appear in exactly one grid bucket")


func _test_motion_rendering(world: SimulationWorld) -> void:
    assert(not world.camera.position_smoothing_enabled, "Camera smoothing must stay disabled so the robot and retained world snapshot cannot drift apart")

    var tile_size := float(SimulationWorld.FLOOR_TEXTURE_SIZE)
    var first_bounds := world._background_bounds_for(Vector2(100.0, 100.0))
    var nearby_bounds := world._background_bounds_for(Vector2(140.0, 100.0))
    assert(first_bounds.position == nearby_bounds.position, "Small player movement must not drag the floor tile origin")
    assert(is_zero_approx(fposmod(first_bounds.position.x, tile_size)), "Floor bounds must be aligned to the world-space texture grid on X")
    assert(is_zero_approx(fposmod(first_bounds.position.y, tile_size)), "Floor bounds must be aligned to the world-space texture grid on Y")

    var crossed_bounds := world._background_bounds_for(Vector2(tile_size * 2.0 + 100.0, 100.0))
    assert(is_zero_approx(fposmod(crossed_bounds.position.x, tile_size)), "Floor bounds must remain tile-aligned after crossing a texture cell")
    var required_width := GameConfig.VIEW_SIZE.x * world._camera_view_scale() + 64.0
    assert(crossed_bounds.size.x >= required_width, "The floor must retain a guard band around the camera")


func _test_pause_and_keyboard_selection(scene: Node, world: SimulationWorld, hud: GameHud, audio: SoundManager) -> void:
    assert(scene.process_mode == Node.PROCESS_MODE_ALWAYS, "Game root must keep handling pause-menu input")
    assert(world.process_mode == Node.PROCESS_MODE_PAUSABLE, "World must stop processing during upgrades")

    world.pending_upgrade = true
    var old_pierce := world.weapon_pierce
    var options: Array[String] = ["damage", "needle_pierce", "armor"]
    scene.call("_on_level_up_requested", options)
    assert(paused, "Level-up must pause the scene tree")
    assert(hud.upgrade_overlay.visible, "Level-up choices must be visible")

    assert(hud.upgrade_buttons[0].has_focus(), "The first upgrade must receive keyboard focus when the menu opens")
    var down_event := InputEventKey.new()
    down_event.keycode = KEY_DOWN
    down_event.pressed = true
    hud._input(down_event)
    assert(hud.upgrade_buttons[1].has_focus(), "Down arrow must move upgrade focus to the next choice")
    assert(audio.last_cue_requested == "menu_move", "Arrow navigation must play the menu movement cue")

    var space_event := InputEventKey.new()
    space_event.keycode = KEY_SPACE
    space_event.pressed = true
    hud._input(space_event)
    assert(not paused, "Space must confirm the focused upgrade and resume the scene tree")
    assert(world.weapon_pierce == old_pierce + 1, "Space must apply the focused second upgrade")
    assert(audio.last_cue_requested == "upgrade_select", "Confirming a stat upgrade must play its digital confirmation")

    world.pending_upgrade = true
    var old_armor := world.player_armor
    scene.call("_on_level_up_requested", options)
    var up_event := InputEventKey.new()
    up_event.keycode = KEY_UP
    up_event.pressed = true
    hud._input(up_event)
    assert(hud.upgrade_buttons[2].has_focus(), "Up arrow from the first choice must wrap to the last choice")

    var enter_event := InputEventKey.new()
    enter_event.keycode = KEY_ENTER
    enter_event.pressed = true
    hud._input(enter_event)
    assert(not paused, "Enter must confirm the focused upgrade and resume the scene tree")
    assert(world.player_armor > old_armor, "Enter must apply the focused last upgrade")

    var performance_event := InputEventKey.new()
    performance_event.keycode = KEY_F3
    performance_event.pressed = true
    scene.call("_unhandled_input", performance_event)
    assert(hud.performance_label.visible, "F3 must expose target-machine performance diagnostics")
    scene.call("_unhandled_input", performance_event)
    assert(not hud.performance_label.visible, "F3 must hide the performance diagnostics on a second press")


func _test_restart_input_and_character_reuse(scene: Node, world: SimulationWorld, hud: GameHud, audio: SoundManager) -> void:
    world.select_character("scout")
    world.reset_run()
    hud.reset_display()
    paused = false

    for restart_key in [KEY_R, KEY_ENTER, KEY_SPACE]:
        world.is_running = false
        hud.show_death({})
        var restart_event := InputEventKey.new()
        restart_event.keycode = restart_key
        restart_event.pressed = true
        hud._input(restart_event)
        assert(world.is_running, "R, Enter, and Space must each restart a finished run")
        assert(world.selected_character == "scout", "Normal restart must preserve the chosen character")
        assert(not hud.death_overlay.visible, "Restart must close the death overlay")
        assert(not hud.character_overlay.visible, "Normal restart must skip character selection")
        assert(not paused, "Normal restart must resume play immediately")
        assert(audio.last_cue_requested == "restart", "Normal restart must play the robot boot cue")

    world.is_running = false
    hud.show_death({})
    assert("Space" in hud.death_summary.text and "Escape" in hud.death_summary.text, "Death instructions must show both restart and character-select controls")
    var escape_event := InputEventKey.new()
    escape_event.keycode = KEY_ESCAPE
    escape_event.pressed = true
    hud._input(escape_event)
    assert(world.selected_character == "scout", "Opening character selection must keep the current choice highlighted")
    assert(hud.character_overlay.visible, "Escape on the death screen must open character selection")
    assert(paused, "Character selection must pause the world")
    assert(audio.last_cue_requested == "menu_back", "Escape from death must play the menu-back cue")

    scene.call("_on_character_selected", GameConfig.DEFAULT_CHARACTER_ID)
    assert(not paused, "Choosing a character after death must resume the run")
    assert(world.selected_character == GameConfig.DEFAULT_CHARACTER_ID, "The test must restore the default character for later baseline checks")
    assert(audio.last_cue_requested == "character_select", "Operator confirmation must use its dedicated servo cue")


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


func _test_offense_pity(world: SimulationWorld) -> void:
    world.reset_run()
    world.elapsed_time = 600.0
    world.level = 9
    world.weapon_damage = GameConfig.NEEDLE_DAMAGE
    world.weapon_cooldown = GameConfig.NEEDLE_COOLDOWN
    world.weapon_projectile_count = GameConfig.NEEDLE_PROJECTILES
    world.owned_weapons.assign(["needle"])

    assert(world._estimated_sustained_dps() < world._required_sustained_dps(), "A weak early build must fall behind enemy-health growth")
    assert(world._offense_pity_option_count() == 2, "A severely underpowered early build must guarantee two DPS choices")
    var eligible_dps := world._eligible_dps_upgrades()
    assert(eligible_dps.has("damage"), "Base Damage must be eligible for offense pity")
    assert(eligible_dps.has("needle_fire_rate"), "Owned-weapon fire rate must be eligible for offense pity")
    assert(eligible_dps.has("needle_projectile_count"), "Owned-weapon projectile count must be eligible for offense pity")
    assert(not eligible_dps.has("sniper_fire_rate"), "Unowned weapon upgrades must not enter offense pity")
    assert(not eligible_dps.has("needle_range"), "Range must not satisfy offense pity")
    for roll_index in range(20):
        var pity_options := world._roll_upgrade_options()
        assert(pity_options.size() == 3, "Offense pity rolls must still contain three choices")
        var dps_choice_count := 0
        for upgrade_id in pity_options:
            if GameConfig.DPS_UPGRADE_IDS.has(upgrade_id):
                dps_choice_count += 1
        assert(dps_choice_count >= 2, "Severe offense pity must guarantee two eligible DPS upgrades")
        assert(not pity_options.has("pickup_radius"), "Pickup radius must not return to upgrade rolls")
        assert(pity_options[0] != pity_options[1] and pity_options[0] != pity_options[2] and pity_options[1] != pity_options[2], "Upgrade choices must remain unique")

    world.weapon_damage = 100.0
    assert(world._offense_pity_option_count() == 0, "Offense pity must turn off after sustained DPS catches up")

    world.weapon_damage = GameConfig.NEEDLE_DAMAGE
    world.level = GameConfig.OFFENSE_PITY_MAX_LEVEL + 1
    assert(world._offense_pity_option_count() == 0, "Offense pity must stop after level 30 so endless scaling can win")


func _test_upgrade_roll_weights(world: SimulationWorld) -> void:
    var low_frequency_ids := ["needle_range", "sniper_range", "regen", "max_health", "armor"]
    for upgrade_id in low_frequency_ids:
        assert(
            is_equal_approx(world._upgrade_roll_weight(upgrade_id), GameConfig.LOW_FREQUENCY_UPGRADE_WEIGHT),
            "%s must use the shared low-frequency roll tier" % upgrade_id
        )
    assert(is_equal_approx(world._upgrade_roll_weight("damage"), 1.0), "Damage must retain normal roll weight")
    assert(is_equal_approx(world._upgrade_roll_weight("move_speed"), 1.0), "Movement speed must retain normal roll weight")
    assert(GameConfig.DPS_UPGRADE_IDS.has("damage"), "Base Damage must remain a DPS pity option")
    assert(GameConfig.DPS_UPGRADE_IDS.has("needle_fire_rate"), "Weapon fire-rate upgrades must be valid DPS pity options")
    assert(not GameConfig.DPS_UPGRADE_IDS.has("needle_range"), "Range must not satisfy the DPS pity system")

    world.rng.seed = 18071988
    var low_frequency_count := 0
    var sample_count := 5000
    for sample_index in range(sample_count):
        var pool: Array[String] = ["damage", "armor"]
        if world._take_weighted_upgrade(pool) == "armor":
            low_frequency_count += 1
    assert(low_frequency_count > 600, "Low-frequency upgrades must remain possible")
    assert(low_frequency_count < 1100, "Low-frequency upgrades must roll substantially less often than normal upgrades")


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

    world.player_health = 51.0
    world.player_max_health = 100.0
    world.player_armor = 0.0
    world.player_invulnerability_timer = 0.0
    world.player_one_shot_protection_timer = 0.0
    world._apply_player_damage(1000.0, true)
    assert(world.is_running, "A lethal hit above 50% health must not end the run")
    assert(is_equal_approx(world.player_health, 1.0), "One-shot protection must leave the player at exactly 1 HP")
    assert(world.player_one_shot_protection_timer > 0.0, "One-shot protection must trigger its visible feedback")
    assert(world.player_invulnerability_timer > 0.0, "One-shot protection must still grant normal post-hit invulnerability")

    world.player_health = 50.0
    world.player_invulnerability_timer = 0.0
    world.player_one_shot_protection_timer = 0.0
    world._apply_player_damage(1000.0, true)
    assert(not world.is_running, "Exactly 50% health must not qualify for one-shot protection")
    assert(is_equal_approx(world.player_health, 0.0), "An unprotected lethal hit must still end the run")
    world.reset_run()
    _clear_combat_state(world)


func _test_speed_upgrade_camera_zoom(world: SimulationWorld) -> void:
    world.reset_run()
    _clear_combat_state(world)
    var old_speed := world.player_move_speed
    var old_zoom := world.camera.zoom.x
    world.pending_upgrade = true
    world.apply_upgrade("move_speed")
    assert(is_equal_approx(world.player_move_speed, old_speed * 1.10), "Move speed upgrades must still add 10% speed")
    assert(is_equal_approx(world.camera.zoom.x, old_zoom / 1.10), "Camera zoom must decrease by the same multiplier as movement speed increases")
    assert(is_equal_approx(world._camera_view_scale(), 1.10), "Camera view scale must track the player speed multiplier")

    world._spawn_normal_enemy()
    var spawn_distance := WorldSpace.distance(world.enemy_positions[0], world.player_position)
    assert(spawn_distance >= 760.0 * 1.10 - 0.01, "Zoomed-out normal enemies must still spawn outside the enlarged viewport")
    assert(spawn_distance <= 1040.0 * 1.10 + 0.01, "Zoom-scaled normal spawn distance must retain its upper bound")


func _test_game_pace_scaling(world: SimulationWorld) -> void:
    assert(is_equal_approx(GameConfig.GAME_PACE_MULTIPLIER, 2.0), "The run progression clock must be doubled")
    assert(GameConfig.MAX_SPAWNS_PER_TICK == 24, "The per-tick spawn cap must scale with the doubled throughput")

    world.reset_run()
    _clear_combat_state(world)
    world.elapsed_time = 15.0
    assert(is_equal_approx(world._paced_elapsed_time(), 30.0), "The progression clock must advance twice as fast as displayed run time")

    world.xp = 0
    world._add_enemy(Vector2.ZERO, 0.0, 0.0, 0.0, 14.0, GameConfig.NORMAL_ENEMY_XP, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._process_deaths()
    assert(world.xp == 2, "Normal enemy XP rewards must double with game pace")

    _clear_combat_state(world)
    world.elapsed_time = 0.0
    world.player_position = Vector2.ZERO
    world.spawn_accumulator = 0.0
    world.surge_active = false
    world.surge_cooldown = 999.0
    world.threat_check_timer = 999.0
    world._update_spawning(0.50)
    assert(world.enemy_positions.size() == 8, "Opening spawn throughput must double from 8 to 16 enemies per second")

    _clear_combat_state(world)
    world.next_boss_time = GameConfig.FIRST_BOSS_TIME
    world.elapsed_time = GameConfig.FIRST_BOSS_TIME / GameConfig.GAME_PACE_MULTIPLIER - 0.01
    world._update_boss_schedule()
    assert(world.get_boss_count() == 0, "The first boss must not spawn before 22.5 real seconds")
    world.elapsed_time = GameConfig.FIRST_BOSS_TIME / GameConfig.GAME_PACE_MULTIPLIER
    world._update_boss_schedule()
    assert(world.get_boss_count() == 1, "The first boss must spawn at 22.5 real seconds under 2x pace")


func _test_population_spawn_curve(world: SimulationWorld) -> void:
    assert(GameConfig.ENEMY_CAP == 725, "The total live-enemy cap must be halved to 725")
    assert(GameConfig.NORMAL_ENEMY_CAP == 715, "Ten slots must remain reserved for bosses")

    var empty_multiplier := world._population_spawn_multiplier(0)
    var half_multiplier := world._population_spawn_multiplier(GameConfig.ENEMY_CAP / 2)
    var crowded_multiplier := world._population_spawn_multiplier(
        floori(float(GameConfig.ENEMY_CAP) * 0.90)
    )
    var nearly_full_multiplier := world._population_spawn_multiplier(GameConfig.ENEMY_CAP - 1)
    var full_multiplier := world._population_spawn_multiplier(GameConfig.ENEMY_CAP)

    assert(is_equal_approx(empty_multiplier, 1.0), "An empty arena must retain the full spawn rate")
    assert(half_multiplier > 0.79 and half_multiplier < 0.83, "Half capacity must retain roughly 81% of the base spawn rate")
    assert(crowded_multiplier > 0.38 and crowded_multiplier < 0.44, "At 90% capacity the logarithmic throttle must reduce spawning to roughly 41%")
    assert(nearly_full_multiplier > 0.0 and nearly_full_multiplier < crowded_multiplier, "The curve must continue easing toward the cap")
    assert(is_zero_approx(full_multiplier), "The population multiplier must reach zero at the hard cap")

    _clear_combat_state(world)
    for enemy_index in range(GameConfig.NORMAL_ENEMY_CAP):
        world._add_enemy(
            Vector2(float(enemy_index), 0.0),
            1.0,
            0.0,
            0.0,
            GameConfig.NORMAL_ENEMY_RADIUS,
            0,
            SimulationWorld.EnemyKind.NORMAL,
            Vector2.ZERO
        )
    world._spawn_normal_enemy()
    assert(world.enemy_positions.size() == GameConfig.NORMAL_ENEMY_CAP, "Normal spawning must preserve ten boss slots")
    _clear_combat_state(world)


func _test_enemy_speed_scaling(world: SimulationWorld) -> void:
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.elapsed_time = 0.0
    world.surge_active = false
    world._add_enemy(Vector2(1000.0, 0.0), 100.0, 100.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 950.0), "Normal enemies must use base speed at run start")

    world.enemy_positions[0] = Vector2(1000.0, 0.0)
    world.elapsed_time = 300.0
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 910.0), "Five real minutes must reach the old ten-minute enemy speed")

    world.enemy_positions[0] = Vector2(2000.0, 0.0)
    world.elapsed_time = 0.0
    world.surge_active = true
    world.surge_time = GameConfig.SURGE_RAMP_TIME
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 1900.0), "A fully ramped surge must double distant normal movement")

    world.enemy_positions[0] = Vector2(400.0, 0.0)
    world._update_enemies(0.50)
    assert(is_equal_approx(world.enemy_positions[0].x, 350.0), "Surge speed must fade out near the player")

    world.elapsed_time = 1800.0
    assert(world._current_normal_speed_scale() > 2.25, "Normal enemy speed scaling must continue beyond the former cap")
    assert(world._current_boss_speed_scale() > 1.50, "Boss speed scaling must continue beyond the former cap")


func _test_boss_scaling_and_protection(world: SimulationWorld) -> void:
    world.elapsed_time = 150.0
    assert(is_equal_approx(world._current_boss_health(), 6050.0), "Two and a half real minutes must reach the old five-minute boss health")

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

    _test_boss_phases(world)


func _test_boss_phases(world: SimulationWorld) -> void:
    # Phase is derived from the health fraction, so drive it by setting health
    # directly rather than by simulating a whole fight.
    _clear_combat_state(world)
    world._add_enemy(Vector2(100.0, 0.0), 1000.0, 0.0, 0.0, 42.0, 20, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)

    world.enemy_health[0] = 1000.0
    assert(world._boss_phase(0) == 0, "A full-health boss must be in phase one")
    world.enemy_health[0] = 700.0
    assert(world._boss_phase(0) == 0, "Above the phase two threshold must stay phase one")
    world.enemy_health[0] = 660.0
    assert(world._boss_phase(0) == 1, "At the phase two threshold the boss must escalate")
    world.enemy_health[0] = 400.0
    assert(world._boss_phase(0) == 1, "Between thresholds must stay phase two")
    world.enemy_health[0] = 330.0
    assert(world._boss_phase(0) == 2, "At the phase three threshold the boss must escalate again")
    world.enemy_health[0] = 1.0
    assert(world._boss_phase(0) == 2, "Near death must stay phase three")

    # A zero max health must not divide by zero mid-frame.
    world.enemy_max_health[0] = 0.0
    assert(world._boss_phase(0) == 0, "A zero max health must fall back to phase one")
    world.enemy_max_health[0] = 1000.0

    # Escalation has to be monotonic in the direction that matters: later
    # phases telegraph for less time, attack sooner, hit wider, and close
    # faster. Otherwise "multi-phase" is just different, not harder.
    for phase in range(2):
        assert(
            float(GameConfig.BOSS_PHASE_TELEGRAPH[phase + 1]) < float(GameConfig.BOSS_PHASE_TELEGRAPH[phase]),
            "Each phase must telegraph faster than the last"
        )
        assert(
            float(GameConfig.BOSS_PHASE_ATTACK_INTERVAL[phase + 1]) < float(GameConfig.BOSS_PHASE_ATTACK_INTERVAL[phase]),
            "Each phase must attack more often than the last"
        )
        assert(
            float(GameConfig.BOSS_PHASE_SLAM_RADIUS[phase + 1]) > float(GameConfig.BOSS_PHASE_SLAM_RADIUS[phase]),
            "Each phase must slam wider than the last"
        )
        assert(
            float(GameConfig.BOSS_PHASE_SPEED_MULTIPLIER[phase + 1]) > float(GameConfig.BOSS_PHASE_SPEED_MULTIPLIER[phase]),
            "Each phase must close faster than the last"
        )

    # The telegraph must still be long enough to dodge at the widest radius.
    assert(float(GameConfig.BOSS_PHASE_TELEGRAPH[2]) > 0.5, "The final phase must stay dodgeable")

    _clear_combat_state(world)


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
    world._add_enemy(Vector2(0.0, 600.0), 5000.0, 0.0, 0.0, 42.0, 20, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    world._add_enemy(Vector2(300.0, 0.0), 1000.0, 0.0, 0.0, 42.0, 20, SimulationWorld.EnemyKind.BOSS, Vector2.ZERO)
    assert(world._find_target_enemy(Vector2.ZERO, GameConfig.NEEDLE_RANGE) == 0, "Closest targeting must choose the nearby normal enemy")

    var toggle_event := InputEventKey.new()
    toggle_event.keycode = KEY_T
    toggle_event.pressed = true
    scene.call("_unhandled_input", toggle_event)
    assert(world.targeting_mode == SimulationWorld.TargetingMode.STRONGEST, "T must toggle targeting to Strongest")
    assert(world._find_target_enemy(Vector2.ZERO, GameConfig.NEEDLE_RANGE) == 2, "Strongest targeting must prioritize the closest in-range boss")
    assert(hud.stats_label.text.contains("TARGET STRONGEST"), "The HUD must show the active targeting mode")

    world.needle_timer = 0.0
    world._update_needle(0.0)
    assert(world.projectile_positions.size() == 1, "Needle must fire in Strongest mode")
    assert(world.projectile_velocities[0].x > 0.0 and absf(world.projectile_velocities[0].y) < 0.001, "Strongest Needle fire must aim at the closest boss instead of the farther stronger boss")

    _clear_combat_state(world)
    world._add_enemy(Vector2(500.0, 0.0), 5000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(150.0, 0.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    assert(world._find_target_enemy(Vector2.ZERO, GameConfig.NEEDLE_RANGE) == 1, "Strongest targeting must fall back to the closest normal enemy when no boss is valid")

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

    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "sniper"])
    var old_sniper_radius := world.sniper_radius
    world.pending_upgrade = true
    world.apply_upgrade("sniper_size")
    assert(is_equal_approx(GameConfig.SNIPER_SIZE_UPGRADE_MULTIPLIER, 1.45), "Heavy Caliber must increase Longshot radius by 45% per rank")
    assert(is_equal_approx(world.sniper_radius, old_sniper_radius * GameConfig.SNIPER_SIZE_UPGRADE_MULTIPLIER), "Longshot size upgrades must enlarge its projectile radius")
    world._add_enemy(Vector2(1800.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.sniper_timer = 0.0
    world._update_sniper(0.0)
    assert(is_equal_approx(world.projectile_radii[0], world.sniper_radius), "Longshot must spawn with its upgraded collision radius")
    assert(world._projectile_visual_scale(world.sniper_radius) > 1.0, "Longshot size upgrades must enlarge the rendered projectile")
    world.weapon_upgrade_levels["sniper_size"] = GameConfig.WEAPON_UPGRADE_CAPS["sniper_size"]
    assert(not world._is_upgrade_eligible("sniper_size"), "Longshot size upgrades must disappear at their cap")
    world.weapon_upgrade_levels["sniper_size"] = 1

    # Aura echoes are distinct delayed pulses that recheck current targets.
    _clear_combat_state(world)
    world.benchmark_mode = false
    world.owned_weapons.assign(["needle", "aura"])
    world.aura_echoes = 2
    world.aura_timer = 0.0
    world._add_enemy(Vector2(100.0, 0.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(400.0, 0.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.hit_targets.clear()
    world.hit_damage.clear()
    var aura_sounds: Array[String] = []
    var capture_aura_sound := func(cue: String) -> void:
        if cue == "aura_pulse":
            aura_sounds.append(cue)
    world.sound_requested.connect(capture_aura_sound)
    world._update_aura(0.0)
    assert(world.hit_targets == [0], "The initial Aura pulse must hit each current in-range enemy once")
    assert(aura_sounds.size() == 1, "Aura must play one bass cue on the initial cast")
    assert(world.aura_echoes_remaining == 2, "Aura upgrades must schedule delayed echo pulses")
    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[0], 88.0), "The initial Aura pulse must deal one damage instance")

    world.enemy_positions[0] = Vector2(400.0, 0.0)
    world.enemy_positions[1] = Vector2(100.0, 0.0)
    world._rebuild_enemy_grid()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_aura(GameConfig.AURA_ECHO_INTERVAL)
    assert(world.hit_targets == [1], "Each Aura echo must recheck which enemies are currently in range")
    assert(aura_sounds.size() == 1, "Aura echoes must not replay the cast sound")
    assert(world.aura_echoes_remaining == 1, "One delayed Aura echo must remain after the first echo")
    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[1], 88.0), "A newly entered enemy must be hit by the delayed echo")

    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_aura(GameConfig.AURA_ECHO_INTERVAL)
    assert(world.hit_targets == [1], "The final Aura echo must be a separate pulse")
    assert(world.aura_echoes_remaining == 0, "The Aura echo sequence must end after the configured pulse count")
    world._resolve_hits()
    assert(is_equal_approx(world.enemy_health[1], 76.0), "Two separate echoes must each deal one Aura damage instance")
    assert(aura_sounds.size() == 1, "The full Aura echo sequence must use only one cast sound")
    world.sound_requested.disconnect(capture_aura_sound)

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


func _test_toroidal_world(world: SimulationWorld) -> void:
    # The arena wraps. Every spatial query must use the shortest separation,
    # which may cross a seam rather than travel across the middle of the map.
    var size := GameConfig.WORLD_SIZE

    assert(is_equal_approx(size / GameConfig.GRID_CELL_SIZE, float(GameConfig.GRID_CELL_COUNT)), "World size must be a whole number of grid cells")
    assert(is_equal_approx(WorldSpace.SIZE, size), "WorldSpace must read its extent from GameConfig")

    # Wrapping folds arbitrary coordinates back into [0, SIZE).
    var wrapped := WorldSpace.wrap_position(Vector2(-10.0, size + 25.0))
    assert(is_equal_approx(wrapped.x, size - 10.0), "Negative coordinates must wrap to the far edge")
    assert(is_equal_approx(wrapped.y, 25.0), "Coordinates beyond the world must wrap to the near edge")

    # Deltas take the short way around a seam and stay within half the world.
    assert(is_equal_approx(WorldSpace.delta(Vector2(size - 10.0, 0.0), Vector2(10.0, 0.0)).x, 20.0), "Crossing a seam must be the short way, not the long way")
    assert(WorldSpace.delta(Vector2(1000.0, 2000.0), Vector2(1300.0, 1700.0)).is_equal_approx(Vector2(300.0, -300.0)), "Interior deltas must match plain subtraction")
    assert(WorldSpace.direction(Vector2(5.0, 5.0), Vector2(5.0, 5.0)) == Vector2.ZERO, "Coincident points must not produce a NaN direction")
    assert(is_equal_approx(WorldSpace.nearest_image(Vector2(size - 10.0, 10.0), Vector2(10.0, 10.0)).x, size + 10.0), "Nearest image must project across the seam")

    # Camera smoothing must not interpolate across the full flat map when the
    # player crosses a toroidal seam. The rendered center should rebase onto the
    # wrapped player position immediately.
    world.camera.position = Vector2(size - 5.0, 100.0)
    world.camera.reset_smoothing()
    world.camera.force_update_scroll()
    world.player_position = Vector2(size - 5.0, 100.0)
    world._set_player_position(Vector2(size + 5.0, 100.0))
    assert(world.player_position.is_equal_approx(Vector2(5.0, 100.0)), "Player movement must wrap onto the opposite edge")
    assert(world.camera.position.is_equal_approx(world.player_position), "Camera target must follow the wrapped player immediately")
    assert(world.camera.get_screen_center_position().is_equal_approx(world.player_position), "Camera smoothing state must rebase instead of panning across the map")

    # Targeting finds an enemy that is only close across a seam.
    world.reset_run()
    _clear_combat_state(world)
    world.elapsed_time = 0.0
    world.surge_active = false
    world.player_position = Vector2(10.0, 10.0)
    world._add_enemy(Vector2(size - 10.0, 10.0), 100.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    assert(world._find_nearest_enemy(world.player_position, 100.0) == 0, "Targeting must see an enemy that is adjacent across a seam")
    assert(world._count_nearby_normals(100.0) == 1, "Threat counting must use wrapped distance")

    # Enemies chase across a seam and their stored position stays wrapped.
    _clear_combat_state(world)
    world.player_position = Vector2(10.0, 0.0)
    world._add_enemy(Vector2(size - 30.0, 0.0), 100.0, 100.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._update_enemies(0.5)
    var chased := world.enemy_positions[0]
    assert(chased.x >= 0.0 and chased.x < size, "Enemy positions must stay wrapped inside the world")
    assert(is_equal_approx(chased.x, 20.0), "An enemy must cross the seam toward the player rather than turn around")

    # Projectile sweeps collide with enemies on the far side of a seam.
    _clear_combat_state(world)
    world.player_position = Vector2(size - 40.0, 100.0)
    world._add_enemy(Vector2(30.0, 100.0), 500.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._rebuild_enemy_grid()
    world._spawn_projectile(Vector2.RIGHT, 50.0, 600.0, 1.0, 6.0, SimulationWorld.ProjectileKind.NEEDLE)
    world.hit_targets.clear()
    world.hit_damage.clear()
    world._update_projectiles(0.1)
    assert(world.hit_targets == [0], "A projectile must hit an enemy across the seam")

    # Grid cells wrap, so opposite edges share a neighbourhood.
    assert(world._grid_cell(Vector2(-1.0, -1.0)) == Vector2i(GameConfig.GRID_CELL_COUNT - 1, GameConfig.GRID_CELL_COUNT - 1), "Negative coordinates must map into the wrapped grid")
    assert(world._grid_cell(Vector2(size, size)) == Vector2i(0, 0), "The far edge must map onto the origin cell")

    # Wrapped rendering resolves nearest images, so the view can never span
    # more than half the world.
    world.player_move_speed = GameConfig.PLAYER_MOVE_SPEED * 10.0
    assert(is_equal_approx(world._camera_view_scale(), GameConfig.CAMERA_VIEW_SCALE_MAX), "Camera view scale must be capped for wrapped rendering")
    assert(GameConfig.VIEW_SIZE.x * 0.70 * GameConfig.CAMERA_VIEW_SCALE_MAX < GameConfig.WORLD_HALF_SIZE, "The capped view must stay smaller than half the world")
    assert(GameConfig.VIEW_SIZE.y * 0.70 * GameConfig.CAMERA_VIEW_SCALE_MAX < GameConfig.WORLD_HALF_SIZE, "The capped view must stay smaller than half the world")

    world.reset_run()
    _clear_combat_state(world)


# Covers the four weapons added on top of the original roster. Each is driven
# through its own update entry point with hand-placed targets, so a broken hook
# fails here instead of silently doing nothing in a run.
func _test_expanded_weapon_roster(world: SimulationWorld) -> void:
    world.reset_run()
    _clear_combat_state(world)
    world.player_position = Vector2.ZERO
    world.weapon_damage = GameConfig.NEEDLE_DAMAGE

    # Arc Chain walks outward from its target with per-jump falloff.
    world.owned_weapons.assign(["needle", "chain"])
    world._add_enemy(Vector2(200.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(320.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(440.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.chain_timer = 0.0
    world._update_chain(0.0)
    assert(world.hit_targets.size() == world.chain_jumps + 1, "Arc Chain must strike its target plus one enemy per jump")
    assert(world.hit_damage[1] < world.hit_damage[0], "Arc Chain damage must fall off along the chain")
    assert(world.chain_hit_scratch.size() == world.hit_targets.size(), "Arc Chain must not strike the same enemy twice in a cast")

    # Flak Burst spreads a cone of pellets on the shared projectile arrays.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "flak"])
    world._add_enemy(Vector2(200.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.flak_timer = 0.0
    world._update_flak(0.0)
    assert(world.projectile_positions.size() == world.flak_pellets, "Flak Burst must spawn one projectile per pellet")
    assert(world.projectile_kinds[0] == SimulationWorld.ProjectileKind.FLAK, "Flak Burst must tag its pellets as FLAK")
    var spread := absf(angle_difference(
        world.projectile_velocities[0].angle(),
        world.projectile_velocities[world.flak_pellets - 1].angle()
    ))
    assert(spread > 0.01, "Flak Burst pellets must fan across a cone")

    # Orbitals ring the player and respect their contact interval.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "orbital"])
    world._update_orbitals(0.0)
    assert(world.orbital_positions.size() == world.orbital_count, "Orbital must hold one satellite per count")
    var orbit_offset := WorldSpace.nearest_image(world.player_position, world.orbital_positions[0]) - world.player_position
    assert(absf(orbit_offset.length() - world.orbital_radius) < 1.0, "Orbital satellites must sit on the orbit radius")
    world._add_enemy(world.orbital_positions[0], 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.orbital_hit_timers[0] = 0.0
    world._update_orbitals(0.0)
    assert(not world.hit_targets.is_empty(), "Orbital satellites must damage enemies they overlap")
    assert(world.orbital_hit_timers[0] > 0.0, "Orbital contact must go on cooldown after a hit")

    # Detonator lobs a shell that resolves as an area blast on arrival.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "detonator"])
    world._add_enemy(Vector2(300.0, 0.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world._add_enemy(Vector2(300.0, 80.0), 1000.0, 0.0, 0.0, 14.0, 0, SimulationWorld.EnemyKind.NORMAL, Vector2.ZERO)
    world.detonator_timer = 0.0
    world._update_detonator(0.0)
    assert(world.detonator_shell_positions.size() == 1, "Detonator must launch a shell at its target")
    assert(world.hit_targets.is_empty(), "Detonator must not damage anything before the shell lands")
    for step in range(240):
        world._update_detonator_shells(1.0 / 60.0)
        if world.detonator_shell_positions.is_empty():
            break
    assert(world.detonator_shell_positions.is_empty(), "Detonator shells must detonate instead of flying forever")
    assert(world.hit_targets.size() == 2, "Detonator blasts must damage every enemy inside the radius")

    # Slots stay scarce even though the pool grew to eight.
    _clear_combat_state(world)
    world.owned_weapons.assign(["needle", "sniper", "aura", "field"])
    assert(not world._is_upgrade_eligible("unlock_chain"), "Weapon unlocks must stay blocked once every slot is filled")
    world.owned_weapons.assign(["needle"])
    assert(world._is_upgrade_eligible("unlock_orbital"), "Weapon unlocks must be offered while slots remain open")

    # Offense-pity has to see the new weapons or it force-feeds damage picks.
    var baseline_dps := world._estimated_sustained_dps()
    for weapon_id in ["chain", "flak", "orbital", "detonator"]:
        world.owned_weapons.assign(["needle", weapon_id])
        assert(world._estimated_sustained_dps() > baseline_dps, "Offense-pity must count %s toward sustained DPS" % weapon_id)

    # One guaranteed unlock per reward screen, however many remain unowned.
    world.owned_weapons.assign(["needle"])
    for roll in range(12):
        var unlock_count := 0
        for option_id in world._roll_weapon_upgrade_options():
            if GameConfig.WEAPON_UNLOCK_IDS.has(option_id):
                unlock_count += 1
        assert(unlock_count <= 1, "Weapon reward screens must offer at most one unlock")

    world.reset_run()
    _clear_combat_state(world)


func _clear_combat_state(world: SimulationWorld) -> void:
    world.enemy_positions.clear()
    world.enemy_health.clear()
    world.enemy_max_health.clear()
    world.enemy_speeds.clear()
    world.enemy_damage.clear()
    world.enemy_radii.clear()
    world.enemy_xp.clear()
    world.enemy_kinds.clear()
    world.enemy_archetypes.clear()
    world.enemy_fire_timers.clear()
    world.enemy_shot_positions.clear()
    world.enemy_shot_velocities.clear()
    world.enemy_shot_lifetimes.clear()
    world.enemy_shot_damage.clear()
    world.pending_split_positions.clear()
    world.pending_split_health.clear()
    world.enemy_sprite_frames.clear()
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
    world.pickup_positions.clear()
    world.orbital_positions.clear()
    world.orbital_hit_timers.clear()
    world.detonator_shell_positions.clear()
    world.detonator_shell_velocities.clear()
    world.detonator_shell_remaining.clear()
    world.detonator_shell_lifetimes.clear()
    world.detonator_blast_positions.clear()
    world.detonator_blast_radii.clear()
    world.detonator_blast_timers.clear()
    world.chain_visual_points.clear()
    world.chain_hit_scratch.clear()
    world.projectile_candidate_targets.clear()
    world.projectile_candidate_fractions.clear()
    world.hit_targets.clear()
    world.hit_damage.clear()
    world.enemy_query_candidates.clear()
    world._release_grid_buckets()
    world.enemy_grid.clear()
    world.enemy_grid_cells.clear()
    world.enemy_grid_slots.clear()
    world._release_field_grid_buckets()
    world.field_grid.clear()
    world.enemy_update_tick = 0
