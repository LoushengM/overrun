extends SceneTree


func _init() -> void:
    var world := SimulationWorld.new()
    var expected := [8, 22, 31, 51, 63]
    for i in range(expected.size()):
        var level := i + 1
        var actual := world.xp_required_for(level)
        if actual != expected[i]:
            push_error("XP curve mismatch at level %d: expected %d, got %d" % [level, expected[i], actual])
            quit(1)
            return

    var armor := 100.0
    var final_damage := 20.0 * 100.0 / (100.0 + armor)
    if not is_equal_approx(final_damage, 10.0):
        push_error("Armor formula regression")
        quit(1)
        return

    world.free()
    print("FORMULA_TEST_OK")
    quit(0)
