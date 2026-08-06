extends Node

@onready var world: SimulationWorld = $World
@onready var hud: GameHud = $HUD
@onready var audio: SoundManager = $SoundManager

var benchmark_mode := false
var benchmark_expanded := false
var level_up_choice_open := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    world.process_mode = Node.PROCESS_MODE_PAUSABLE
    world.stats_updated.connect(hud.update_stats)
    world.level_up_requested.connect(_on_level_up_requested)
    world.boss_upgrade_requested.connect(_on_boss_upgrade_requested)
    world.run_ended.connect(_on_run_ended)
    world.boss_spawned.connect(hud.show_boss_notice)
    world.sound_requested.connect(audio.play_cue)
    hud.upgrade_selected.connect(_on_upgrade_selected)
    hud.character_selected.connect(_on_character_selected)
    hud.restart_requested.connect(_restart_run)
    hud.sound_requested.connect(audio.play_cue)
    hud.set_world(world)

    var arguments := OS.get_cmdline_args()
    var user_arguments := OS.get_cmdline_user_args()
    # --benchmark-expanded implies --benchmark; it only swaps the loadout so the
    # newer four weapons get measured instead of the stock four.
    benchmark_expanded = arguments.has("--benchmark-expanded") or user_arguments.has("--benchmark-expanded")
    benchmark_mode = benchmark_expanded or arguments.has("--benchmark") or user_arguments.has("--benchmark")

    world.reset_run()
    hud.reset_display()
    if benchmark_mode:
        world.enable_benchmark(benchmark_expanded)
    else:
        _open_character_select()


# The select screen pauses the tree, which halts the world (PROCESS_MODE_PAUSABLE)
# while leaving this node and the HUD running to take the choice.
func _open_character_select() -> void:
    level_up_choice_open = false
    get_tree().paused = true
    hud.show_character_select(world.selected_character)


func _on_character_selected(character_id: String) -> void:
    level_up_choice_open = false
    audio.play_cue("character_select")
    world.select_character(character_id)
    world.reset_run()
    hud.reset_display()
    get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused or not world.is_running or not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    var weapon_slot_index := _weapon_slot_index(key_event.keycode)
    if weapon_slot_index >= 0:
        if world.toggle_weapon_targeting_slot(weapon_slot_index):
            audio.play_cue("target_toggle")
        get_viewport().set_input_as_handled()
        return
    match key_event.keycode:
        KEY_T:
            if world.toggle_all_weapon_targeting_modes():
                audio.play_cue("target_toggle")
            get_viewport().set_input_as_handled()
        KEY_F3:
            hud.toggle_performance_overlay()
            audio.play_cue("target_toggle")
            get_viewport().set_input_as_handled()
        KEY_ESCAPE:
            get_tree().quit()
            get_viewport().set_input_as_handled()


func _weapon_slot_index(keycode: int) -> int:
    match keycode:
        KEY_1, KEY_KP_1:
            return 0
        KEY_2, KEY_KP_2:
            return 1
        KEY_3, KEY_KP_3:
            return 2
        KEY_4, KEY_KP_4:
            return 3
        _:
            return -1


func _process(_delta: float) -> void:
    if benchmark_mode and world.elapsed_time >= 10.0:
        print("BENCHMARK_RESULT ", JSON.stringify(world.get_stats_snapshot()))
        get_tree().quit()


func _on_level_up_requested(options: Array[String]) -> void:
    if benchmark_mode:
        if not options.is_empty():
            world.apply_upgrade(options[0])
        return
    level_up_choice_open = true
    audio.play_cue("level_up")
    get_tree().paused = true
    hud.show_upgrade(
        options,
        "LEVEL UP",
        "Choose any eligible upgrade",
        world.get_upgrade_progress_snapshot(options)
    )


func _on_boss_upgrade_requested(options: Array[String]) -> void:
    if benchmark_mode:
        if not options.is_empty():
            world.apply_upgrade(options[0])
        return
    level_up_choice_open = false
    audio.play_cue("boss_reward")
    get_tree().paused = true
    hud.show_upgrade(
        options,
        "BOSS REWARD",
        "Choose a weapon upgrade",
        world.get_upgrade_progress_snapshot(options)
    )


func _on_upgrade_selected(upgrade_id: String) -> void:
    audio.play_cue("weapon_unlock" if GameConfig.WEAPON_UNLOCK_IDS.has(upgrade_id) else "upgrade_select")
    var grant_level_up_invulnerability := level_up_choice_open
    world.apply_upgrade(upgrade_id)
    if grant_level_up_invulnerability and not world.pending_upgrade:
        world.grant_player_invulnerability(GameConfig.PLAYER_LEVEL_UP_INVULNERABILITY)
    level_up_choice_open = false
    hud.hide_upgrade()
    get_tree().paused = false


func _on_run_ended(summary: Dictionary) -> void:
    if benchmark_mode:
        print("BENCHMARK_RUN_ENDED ", JSON.stringify(summary))
        get_tree().quit()
        return
    audio.play_cue("run_over")
    hud.show_death(summary)


func _restart_run(change_character: bool = false) -> void:
    level_up_choice_open = false
    audio.stop_all()
    get_tree().paused = false
    hud.reset_display()
    world.reset_run()
    if benchmark_mode:
        world.enable_benchmark(benchmark_expanded)
    elif change_character:
        audio.play_cue("menu_back")
        _open_character_select()
    else:
        audio.play_cue("restart")
