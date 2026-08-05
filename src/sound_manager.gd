class_name SoundManager
extends Node

const PLAYER_POOL_SIZE := 24

const CUE_CONFIG := {
    "needle_fire": {
        "path": "res://assets/audio/needle_fire.wav",
        "volume_db": -15.0,
        "cooldown": 0.065,
        "pitch_min": 0.96,
        "pitch_max": 1.04,
    },
    "longshot_fire": {
        "path": "res://assets/audio/longshot_fire.wav",
        "volume_db": -8.0,
        "cooldown": 0.18,
        "pitch_min": 0.97,
        "pitch_max": 1.03,
    },
    "aura_pulse": {
        "path": "res://assets/audio/aura_pulse.wav",
        "volume_db": -9.0,
        "cooldown": 0.30,
        "pitch_min": 0.96,
        "pitch_max": 1.01,
    },
    "mire_deploy": {
        "path": "res://assets/audio/mire_deploy.wav",
        "volume_db": -16.0,
        "cooldown": 0.18,
        "pitch_min": 0.92,
        "pitch_max": 1.06,
    },
    # The expanded weapon roster gets its own cues rather than borrowing from
    # the original four. These fire far more often than anything else in the
    # game, so every source was pitched down and band-checked: all five sit at
    # hi_2k <= -37 dB, well clear of the bright band that gets fatiguing on
    # repeat. Cooldowns are deliberately at or above each weapon's floor cadence
    # so a dense crowd cannot machine-gun the pool.
    "chain_arc": {
        "path": "res://assets/audio/chain_arc.wav",
        "volume_db": -17.0,
        "cooldown": 0.16,
        "pitch_min": 0.94,
        "pitch_max": 1.04,
    },
    "flak_fire": {
        "path": "res://assets/audio/flak_fire.wav",
        "volume_db": -14.0,
        "cooldown": 0.12,
        "pitch_min": 0.92,
        "pitch_max": 1.06,
    },
    # Orbital contact is the highest-repetition cue in the game: eight
    # satellites can each land a hit every interval. Quietest of the set with
    # the widest pitch jitter so repeats do not phase into a single tone.
    "orbital_contact": {
        "path": "res://assets/audio/orbital_contact.wav",
        "volume_db": -23.0,
        "cooldown": 0.09,
        "pitch_min": 0.88,
        "pitch_max": 1.10,
    },
    "detonator_launch": {
        "path": "res://assets/audio/detonator_launch.wav",
        "volume_db": -13.0,
        "cooldown": 0.22,
        "pitch_min": 0.95,
        "pitch_max": 1.05,
    },
    "detonator_blast": {
        "path": "res://assets/audio/detonator_blast.wav",
        "volume_db": -11.0,
        "cooldown": 0.14,
        "pitch_min": 0.93,
        "pitch_max": 1.05,
    },
    "enemy_hit": {
        "path": "res://assets/audio/enemy_hit.wav",
        "volume_db": -21.0,
        "cooldown": 0.055,
        "pitch_min": 0.90,
        "pitch_max": 1.10,
    },
    "boss_hit": {
        "path": "res://assets/audio/boss_hit.wav",
        "volume_db": -13.0,
        "cooldown": 0.08,
        "pitch_min": 0.95,
        "pitch_max": 1.04,
    },
    "player_hit": {
        "path": "res://assets/audio/player_hit.wav",
        "volume_db": -8.0,
        "cooldown": 0.20,
        "pitch_min": 0.97,
        "pitch_max": 1.03,
    },
    "last_stand": {
        "path": "res://assets/audio/last_stand.wav",
        "volume_db": -5.0,
        "cooldown": 0.50,
        "pitch_min": 1.0,
        "pitch_max": 1.0,
    },
    "boss_spawn": {
        "path": "res://assets/audio/boss_spawn.wav",
        "volume_db": -7.0,
        "cooldown": 0.50,
        "pitch_min": 0.96,
        "pitch_max": 1.02,
    },
    "boss_telegraph": {
        "path": "res://assets/audio/boss_telegraph.wav",
        "volume_db": -10.0,
        "cooldown": 0.30,
        "pitch_min": 0.98,
        "pitch_max": 1.02,
    },
    "boss_defeat": {
        "path": "res://assets/audio/boss_defeat.wav",
        "volume_db": -6.0,
        "cooldown": 0.40,
        "pitch_min": 0.96,
        "pitch_max": 1.02,
    },
    "health_pickup": {
        "path": "res://assets/audio/health_pickup.wav",
        "volume_db": -12.0,
        "cooldown": 0.10,
        "pitch_min": 0.98,
        "pitch_max": 1.05,
    },
    "level_up": {
        "path": "res://assets/audio/level_up.wav",
        "volume_db": -8.0,
        "cooldown": 0.20,
        "pitch_min": 1.0,
        "pitch_max": 1.0,
    },
    "boss_reward": {
        "path": "res://assets/audio/boss_reward.wav",
        "volume_db": -8.0,
        "cooldown": 0.20,
        "pitch_min": 1.0,
        "pitch_max": 1.0,
    },
    "upgrade_select": {
        "path": "res://assets/audio/upgrade_select.wav",
        "volume_db": -10.0,
        "cooldown": 0.05,
        "pitch_min": 0.98,
        "pitch_max": 1.04,
    },
    "weapon_unlock": {
        "path": "res://assets/audio/weapon_unlock.wav",
        "volume_db": -7.0,
        "cooldown": 0.20,
        "pitch_min": 1.0,
        "pitch_max": 1.0,
    },
    "target_toggle": {
        "path": "res://assets/audio/target_toggle.wav",
        "volume_db": -12.0,
        "cooldown": 0.08,
        "pitch_min": 0.98,
        "pitch_max": 1.02,
    },
    "run_over": {
        "path": "res://assets/audio/run_over.wav",
        "volume_db": -8.0,
        "cooldown": 0.30,
        "pitch_min": 1.0,
        "pitch_max": 1.0,
    },
}

var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var next_allowed_time: Dictionary = {}
var rng := RandomNumberGenerator.new()
var next_player_index := 0
var playback_enabled := true


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


func play_cue(cue: String) -> void:
    if not playback_enabled:
        return
    var config_value: Variant = CUE_CONFIG.get(cue, null)
    if config_value == null:
        return
    var config: Dictionary = config_value
    var now := Time.get_ticks_msec() / 1000.0
    if now < float(next_allowed_time.get(cue, 0.0)):
        return
    next_allowed_time[cue] = now + float(config.get("cooldown", 0.0))

    var player := _claim_player()
    player.stream = streams.get(cue)
    player.volume_db = float(config.get("volume_db", 0.0))
    player.pitch_scale = rng.randf_range(
        float(config.get("pitch_min", 1.0)),
        float(config.get("pitch_max", 1.0))
    )
    player.play()


func stop_all() -> void:
    for player in players:
        player.stop()
        player.stream = null
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


func _claim_player() -> AudioStreamPlayer:
    for offset in range(players.size()):
        var index := (next_player_index + offset) % players.size()
        if not players[index].playing:
            next_player_index = (index + 1) % players.size()
            return players[index]

    var player := players[next_player_index]
    next_player_index = (next_player_index + 1) % players.size()
    player.stop()
    return player
