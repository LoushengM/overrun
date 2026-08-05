class_name SoundManager
extends Node

const PLAYER_POOL_SIZE := 24


static func _cue(
    file_name: String,
    volume_db: float,
    cooldown: float,
    pitch_min: float,
    pitch_max: float,
    priority: int
) -> Dictionary:
    return {
        "path": "res://assets/audio/%s.wav" % file_name,
        "volume_db": volume_db,
        "cooldown": cooldown,
        "pitch_min": pitch_min,
        "pitch_max": pitch_max,
        "priority": priority,
    }

static var CUE_CONFIG := {
    # Player weapons share a clean cyan-energy language. High-frequency or
    # high-repetition cues are deliberately quieter and lower priority.
    "needle_fire": _cue("needle_fire", -17.0, 0.060, 0.97, 1.03, 1),
    "longshot_fire": _cue("longshot_fire", -10.0, 0.180, 0.98, 1.02, 2),
    "aura_pulse": _cue("aura_pulse", -11.0, 0.300, 0.97, 1.02, 2),
    "mire_deploy": _cue("mire_deploy", -14.0, 0.180, 0.95, 1.04, 2),
    "chain_arc": _cue("chain_arc", -16.0, 0.160, 0.94, 1.04, 1),
    "flak_fire": _cue("flak_fire", -14.0, 0.120, 0.94, 1.05, 1),
    "orbital_contact": _cue("orbital_contact", -22.0, 0.090, 0.90, 1.09, 0),
    "detonator_launch": _cue("detonator_launch", -12.0, 0.220, 0.96, 1.03, 2),
    "detonator_blast": _cue("detonator_blast", -9.0, 0.140, 0.95, 1.03, 3),

    # Enemy and damage feedback uses rougher, lower metal tones. Destruction is
    # separate from hit feedback so a kill reads even in a crowded volley.
    "enemy_ranged_fire": _cue("enemy_ranged_fire", -20.0, 0.100, 0.94, 1.06, 1),
    "enemy_hit": _cue("enemy_hit", -23.0, 0.050, 0.90, 1.10, 0),
    "enemy_destroy": _cue("enemy_destroy", -18.0, 0.060, 0.91, 1.08, 1),
    "boss_hit": _cue("boss_hit", -13.0, 0.080, 0.96, 1.03, 3),
    "player_hit": _cue("player_hit", -8.0, 0.200, 0.98, 1.02, 5),
    "last_stand": _cue("last_stand", -5.0, 0.500, 1.00, 1.00, 7),

    # Boss and pacing events must survive a saturated combat mix.
    "boss_spawn": _cue("boss_spawn", -6.0, 0.500, 0.98, 1.01, 7),
    "boss_telegraph": _cue("boss_telegraph", -9.0, 0.300, 0.99, 1.01, 6),
    "boss_slam": _cue("boss_slam", -5.0, 0.450, 0.98, 1.01, 7),
    "boss_defeat": _cue("boss_defeat", -5.0, 0.500, 0.98, 1.01, 7),
    "surge_start": _cue("surge_start", -12.0, 0.800, 0.99, 1.01, 4),

    # Progression and UI are concise digital/servo cues. Menu movement is kept
    # very quiet because held-arrow navigation can repeat quickly.
    "health_pickup": _cue("health_pickup", -10.0, 0.100, 0.98, 1.03, 4),
    "level_up": _cue("level_up", -7.0, 0.200, 1.00, 1.00, 7),
    "boss_reward": _cue("boss_reward", -6.0, 0.200, 1.00, 1.00, 7),
    "menu_move": _cue("menu_move", -22.0, 0.035, 0.98, 1.03, 4),
    "upgrade_select": _cue("upgrade_select", -15.0, 0.050, 0.99, 1.02, 5),
    "character_select": _cue("character_select", -10.0, 0.120, 0.99, 1.01, 6),
    "menu_back": _cue("menu_back", -14.0, 0.100, 0.99, 1.01, 5),
    "restart": _cue("restart", -10.0, 0.200, 0.99, 1.01, 6),
    "weapon_unlock": _cue("weapon_unlock", -6.0, 0.200, 1.00, 1.00, 7),
    "target_toggle": _cue("target_toggle", -15.0, 0.080, 0.99, 1.01, 4),
    "run_over": _cue("run_over", -7.0, 0.300, 1.00, 1.00, 7),
}

var players: Array[AudioStreamPlayer] = []
var player_priorities: Array[int] = []
var streams: Dictionary = {}
var next_allowed_time: Dictionary = {}
var rng := RandomNumberGenerator.new()
var next_player_index := 0
var playback_enabled := true
var last_cue_requested := ""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    playback_enabled = DisplayServer.get_name() != "headless"
    rng.randomize()
    for cue in CUE_CONFIG.keys():
        var path: String = CUE_CONFIG[cue].get("path", "")
        streams[cue] = load(path)
    for i in range(PLAYER_POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(player)
        players.append(player)
        player_priorities.append(-1)


func play_cue(cue: String) -> void:
    var config_value: Variant = CUE_CONFIG.get(cue, null)
    if config_value == null:
        return
    last_cue_requested = cue
    if not playback_enabled:
        return
    var config: Dictionary = config_value
    var now := Time.get_ticks_msec() / 1000.0
    if now < float(next_allowed_time.get(cue, 0.0)):
        return
    next_allowed_time[cue] = now + float(config.get("cooldown", 0.0))

    var priority := int(config.get("priority", 0))
    var player := _claim_player(priority)
    if player == null:
        return
    player.stream = streams.get(cue)
    player.volume_db = float(config.get("volume_db", 0.0))
    player.pitch_scale = rng.randf_range(
        float(config.get("pitch_min", 1.0)),
        float(config.get("pitch_max", 1.0))
    )
    player.play()


func stop_all() -> void:
    for index in range(players.size()):
        players[index].stop()
        players[index].stream = null
        player_priorities[index] = -1
    next_allowed_time.clear()


func _exit_tree() -> void:
    stop_all()
    streams.clear()


func has_cue(cue: String) -> bool:
    return CUE_CONFIG.has(cue)


func get_stream(cue: String) -> AudioStream:
    return streams.get(cue) as AudioStream


func get_cue_names() -> Array[String]:
    var result: Array[String] = []
    for cue in CUE_CONFIG.keys():
        result.append(cue)
    result.sort()
    return result


func _claim_player(priority: int) -> AudioStreamPlayer:
    for offset in range(players.size()):
        var index := (next_player_index + offset) % players.size()
        if not players[index].playing:
            next_player_index = (index + 1) % players.size()
            player_priorities[index] = priority
            return players[index]

    # When all voices are busy, replace the least important cue rather than a
    # boss warning, damage alert, or progression confirmation at random.
    var claim_index := next_player_index
    var lowest_priority := player_priorities[claim_index]
    for index in range(players.size()):
        if player_priorities[index] < lowest_priority:
            lowest_priority = player_priorities[index]
            claim_index = index
    if priority < lowest_priority:
        return null
    var player := players[claim_index]
    next_player_index = (claim_index + 1) % players.size()
    player.stop()
    player_priorities[claim_index] = priority
    return player
