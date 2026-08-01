extends Node

@onready var world: SimulationWorld = $World
@onready var hud: GameHud = $HUD

var benchmark_mode := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    world.process_mode = Node.PROCESS_MODE_PAUSABLE
    world.stats_updated.connect(hud.update_stats)
    world.level_up_requested.connect(_on_level_up_requested)
    world.boss_upgrade_requested.connect(_on_boss_upgrade_requested)
    world.run_ended.connect(_on_run_ended)
    world.boss_spawned.connect(hud.show_boss_notice)
    hud.upgrade_selected.connect(_on_upgrade_selected)
    hud.restart_requested.connect(_restart_run)
    hud.set_world(world)

    var arguments := OS.get_cmdline_args()
    var user_arguments := OS.get_cmdline_user_args()
    benchmark_mode = arguments.has("--benchmark") or user_arguments.has("--benchmark")

    world.reset_run()
    hud.reset_display()
    if benchmark_mode:
        world.enable_benchmark()


func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused or not world.is_running or not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if key_event.keycode == KEY_T:
        world.toggle_targeting_mode()
        get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
    if Input.is_key_pressed(KEY_ESCAPE):
        get_tree().quit()
        return

    if not world.is_running and (Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER)):
        _restart_run()

    if benchmark_mode and world.elapsed_time >= 10.0:
        print("BENCHMARK_RESULT ", JSON.stringify(world.get_stats_snapshot()))
        get_tree().quit()


func _on_level_up_requested(options: Array[String]) -> void:
    if benchmark_mode:
        if not options.is_empty():
            world.apply_upgrade(options[0])
        return
    get_tree().paused = true
    hud.show_upgrade(options, "LEVEL UP", "Choose any eligible upgrade")


func _on_boss_upgrade_requested(options: Array[String]) -> void:
    if benchmark_mode:
        if not options.is_empty():
            world.apply_upgrade(options[0])
        return
    get_tree().paused = true
    hud.show_upgrade(options, "BOSS REWARD", "Choose a new weapon or an owned-weapon upgrade")


func _on_upgrade_selected(upgrade_id: String) -> void:
    world.apply_upgrade(upgrade_id)
    hud.hide_upgrade()
    get_tree().paused = false


func _on_run_ended(summary: Dictionary) -> void:
    if benchmark_mode:
        print("BENCHMARK_RUN_ENDED ", JSON.stringify(summary))
        get_tree().quit()
        return
    hud.show_death(summary)


func _restart_run() -> void:
    get_tree().paused = false
    hud.reset_display()
    world.reset_run()
    if benchmark_mode:
        world.enable_benchmark()
