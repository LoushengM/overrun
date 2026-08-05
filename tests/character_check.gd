extends SceneTree

# Ad-hoc verification: instantiate the world, select each operator, reset, and
# confirm the roster overlay actually lands on the live stats.

func _initialize() -> void:
    var world_script = load("res://src/simulation_world.gd")
    var world = world_script.new()
    # SimulationWorld resolves $Camera2D on ready and _apply_character calls
    # _update_camera_zoom, so the child has to exist before the node enters the
    # tree or every reset spams null-instance errors.
    var camera := Camera2D.new()
    camera.name = "Camera2D"
    world.add_child(camera)
    root.add_child(world)
    # @onready resolution has not run yet this early in _initialize, so bind the
    # camera by hand rather than letting _update_camera_zoom hit a nil.
    world.camera = camera

    for character_id in GameConfig.CHARACTER_IDS:
        world.select_character(character_id)
        world.reset_run()
        var data: Dictionary = GameConfig.CHARACTERS[character_id]
        var expected_hp := GameConfig.PLAYER_MAX_HEALTH * float(data.get("health", 1.0))
        var expected_speed := GameConfig.PLAYER_MOVE_SPEED * float(data.get("speed", 1.0))
        var expected_armor := GameConfig.PLAYER_ARMOR + float(data.get("armor_bonus", 0.0))
        assert(is_equal_approx(world.player_max_health, expected_hp), "hp mismatch %s" % character_id)
        assert(is_equal_approx(world.player_health, expected_hp), "cur hp mismatch %s" % character_id)
        assert(is_equal_approx(world.player_move_speed, expected_speed), "speed mismatch %s" % character_id)
        assert(is_equal_approx(world.player_armor, expected_armor), "armor mismatch %s" % character_id)
        var starting_weapon := str(data.get("weapon", ""))
        if not starting_weapon.is_empty():
            assert(world.owned_weapons.has(starting_weapon), "missing weapon %s" % character_id)
        assert(world.owned_weapons.size() <= GameConfig.WEAPON_SLOT_CAP, "slot overflow %s" % character_id)
        assert(world.owned_weapons.has("needle"), "needle missing %s" % character_id)
        print("%s hp=%.0f spd=%.0f armor=%.0f dmg=%.1f pierce=%d field=%.2f xp_gain=%.2f weapons=%s" % [
            character_id,
            world.player_max_health,
            world.player_move_speed,
            world.player_armor,
            world.weapon_damage,
            world.sniper_pierce,
            world.field_duration,
            world.character_xp_gain,
            str(world.owned_weapons),
        ])

    # Re-selecting must not accumulate: reset twice on the same operator and
    # confirm additive passives (pierce, field duration, weapon list) are stable.
    world.select_character("gunner")
    world.reset_run()
    var pierce_once: int = world.sniper_pierce
    var weapons_once: int = world.owned_weapons.size()
    world.reset_run()
    assert(world.sniper_pierce == pierce_once, "pierce accumulated across resets")
    assert(world.owned_weapons.size() == weapons_once, "weapons accumulated across resets")

    world.select_character("warden")
    world.reset_run()
    var field_once: float = world.field_duration
    world.reset_run()
    assert(is_equal_approx(world.field_duration, field_once), "field duration accumulated")

    world.select_character("bogus_id")
    assert(world.selected_character == "warden", "invalid id changed selection")

    print("CHARACTER_CHECK_OK")
    world.queue_free()
    quit()
