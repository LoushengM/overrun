class_name GameHud
extends CanvasLayer

signal upgrade_selected(upgrade_id: String)
signal restart_requested

var root: Control
var health_bar: ProgressBar
var health_label: Label
var stats_label: Label
var build_label: Label
var surge_label: Label
var boss_notice: Label
var minimap: BossMinimap

var upgrade_overlay: ColorRect
var upgrade_buttons: Array[Button] = []
var death_overlay: ColorRect
var death_summary: Label
var boss_notice_time := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    _build_interface()


func _process(delta: float) -> void:
    if boss_notice_time > 0.0:
        boss_notice_time -= delta
        boss_notice.visible = true
        boss_notice.modulate.a = clampf(boss_notice_time, 0.0, 1.0)
    else:
        boss_notice.visible = false


func set_world(world: SimulationWorld) -> void:
    minimap.set_world(world)


func update_stats(stats: Dictionary) -> void:
    var health: float = stats.get("health", 0.0)
    var max_health: float = stats.get("max_health", 1.0)
    health_bar.max_value = max_health
    health_bar.value = health
    health_label.text = "HP  %d / %d" % [ceili(health), ceili(max_health)]

    stats_label.text = (
        "LEVEL %d    XP %d / %d\n" % [stats.get("level", 1), stats.get("xp", 0), stats.get("xp_required", 1)]
        + "TIME %s    KILLS %d\n" % [_format_time(stats.get("elapsed", 0.0)), stats.get("kills", 0)]
        + "ENEMIES %d    SHOTS %d    BOSSES %d\n" % [stats.get("enemies", 0), stats.get("projectiles", 0), stats.get("bosses", 0)]
        + "FPS %d" % stats.get("fps", 0)
    )

    build_label.text = (
        "NEEDLE  %.1f dmg  %.2fs\n" % [stats.get("damage", 0.0), stats.get("cooldown", 0.0)]
        + "%d projectile(s)  %d pierce\n" % [stats.get("projectile_count", 1), stats.get("pierce", 0)]
        + "%.0f armor  %.0f%% reduction\n" % [stats.get("armor", 0.0), stats.get("damage_reduction", 0.0) * 100.0]
        + "%.1f%% regen/s" % [stats.get("regen_rate", 0.0) * 100.0]
    )
    surge_label.visible = stats.get("surge", false)


func show_upgrade(options: Array[String]) -> void:
    for i in range(upgrade_buttons.size()):
        var button := upgrade_buttons[i]
        if i < options.size():
            var upgrade_id := options[i]
            button.visible = true
            button.set_meta("upgrade_id", upgrade_id)
            button.text = "%s\n%s" % [
                GameConfig.UPGRADE_NAMES.get(upgrade_id, upgrade_id),
                GameConfig.UPGRADE_DESCRIPTIONS.get(upgrade_id, ""),
            ]
        else:
            button.visible = false
    upgrade_overlay.visible = true


func hide_upgrade() -> void:
    upgrade_overlay.visible = false


func show_death(summary: Dictionary) -> void:
    death_summary.text = (
        "Run ended\n\n"
        + "Time survived: %s\n" % _format_time(summary.get("elapsed", 0.0))
        + "Level reached: %d\n" % summary.get("level", 1)
        + "Enemies destroyed: %d\n" % summary.get("kills", 0)
        + "Peak Needle damage: %.1f\n\n" % summary.get("damage", 0.0)
        + "Press R or Enter to restart"
    )
    death_overlay.visible = true


func reset_display() -> void:
    upgrade_overlay.visible = false
    death_overlay.visible = false
    boss_notice.visible = false
    boss_notice_time = 0.0


func show_boss_notice() -> void:
    boss_notice.text = "BOSS DETECTED — marked on minimap"
    boss_notice_time = 2.5
    boss_notice.modulate.a = 1.0
    boss_notice.visible = true


func _on_upgrade_button_pressed(button: Button) -> void:
    var upgrade_id: String = button.get_meta("upgrade_id", "")
    if upgrade_id.is_empty():
        return
    upgrade_selected.emit(upgrade_id)


func _on_restart_pressed() -> void:
    restart_requested.emit()


func _build_interface() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var top_back := ColorRect.new()
    top_back.position = Vector2(18.0, 18.0)
    top_back.size = Vector2(430.0, 152.0)
    top_back.color = Color(0.01, 0.02, 0.035, 0.82)
    top_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top_back)

    health_bar = ProgressBar.new()
    health_bar.position = Vector2(32.0, 32.0)
    health_bar.size = Vector2(400.0, 24.0)
    health_bar.show_percentage = false
    root.add_child(health_bar)

    health_label = Label.new()
    health_label.position = Vector2(42.0, 33.0)
    health_label.size = Vector2(380.0, 24.0)
    health_label.add_theme_font_size_override("font_size", 15)
    health_label.add_theme_color_override("font_color", Color.WHITE)
    health_label.add_theme_constant_override("outline_size", 5)
    health_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
    root.add_child(health_label)

    stats_label = Label.new()
    stats_label.position = Vector2(32.0, 64.0)
    stats_label.size = Vector2(270.0, 100.0)
    stats_label.add_theme_font_size_override("font_size", 15)
    stats_label.add_theme_color_override("font_color", Color(0.82, 0.91, 1.0))
    root.add_child(stats_label)

    build_label = Label.new()
    build_label.position = Vector2(255.0, 64.0)
    build_label.size = Vector2(180.0, 100.0)
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    build_label.add_theme_font_size_override("font_size", 14)
    build_label.add_theme_color_override("font_color", Color(0.75, 0.86, 0.95))
    root.add_child(build_label)

    surge_label = Label.new()
    surge_label.position = Vector2(18.0, 178.0)
    surge_label.size = Vector2(260.0, 30.0)
    surge_label.text = "SPAWN SURGE"
    surge_label.add_theme_font_size_override("font_size", 18)
    surge_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.22))
    root.add_child(surge_label)

    minimap = BossMinimap.new()
    minimap.position = Vector2(1068.0, 18.0)
    minimap.size = Vector2(194.0, 194.0)
    root.add_child(minimap)

    var minimap_label := Label.new()
    minimap_label.position = Vector2(1068.0, 214.0)
    minimap_label.size = Vector2(194.0, 24.0)
    minimap_label.text = "BOSS RADAR"
    minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    minimap_label.add_theme_font_size_override("font_size", 13)
    minimap_label.add_theme_color_override("font_color", Color(0.60, 0.76, 0.88))
    root.add_child(minimap_label)

    var controls := Label.new()
    controls.position = Vector2(18.0, 675.0)
    controls.size = Vector2(620.0, 28.0)
    controls.text = "MOVE: WASD / ARROWS     AUTO-FIRE: NEAREST TARGET     ESC: QUIT"
    controls.add_theme_font_size_override("font_size", 14)
    controls.add_theme_color_override("font_color", Color(0.52, 0.64, 0.75))
    root.add_child(controls)

    boss_notice = Label.new()
    boss_notice.position = Vector2(390.0, 245.0)
    boss_notice.size = Vector2(500.0, 50.0)
    boss_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_notice.add_theme_font_size_override("font_size", 24)
    boss_notice.add_theme_color_override("font_color", Color(1.0, 0.30, 0.32))
    boss_notice.add_theme_constant_override("outline_size", 8)
    boss_notice.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
    boss_notice.visible = false
    root.add_child(boss_notice)

    _build_upgrade_overlay()
    _build_death_overlay()


func _build_upgrade_overlay() -> void:
    upgrade_overlay = ColorRect.new()
    upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    upgrade_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
    upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    upgrade_overlay.visible = false
    root.add_child(upgrade_overlay)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -390.0
    panel.offset_top = -210.0
    panel.offset_right = 390.0
    panel.offset_bottom = 210.0
    upgrade_overlay.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 14)
    panel.add_child(layout)

    var title := Label.new()
    title.text = "LEVEL UP"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color(0.48, 0.92, 1.0))
    layout.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Choose one upgrade"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 18)
    layout.add_child(subtitle)

    for i in range(3):
        var button := Button.new()
        button.custom_minimum_size = Vector2(730.0, 82.0)
        button.add_theme_font_size_override("font_size", 19)
        button.pressed.connect(_on_upgrade_button_pressed.bind(button))
        layout.add_child(button)
        upgrade_buttons.append(button)


func _build_death_overlay() -> void:
    death_overlay = ColorRect.new()
    death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    death_overlay.color = Color(0.0, 0.0, 0.0, 0.80)
    death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    death_overlay.visible = false
    root.add_child(death_overlay)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -260.0
    panel.offset_top = -190.0
    panel.offset_right = 260.0
    panel.offset_bottom = 190.0
    death_overlay.add_child(panel)

    var layout := VBoxContainer.new()
    layout.alignment = BoxContainer.ALIGNMENT_CENTER
    layout.add_theme_constant_override("separation", 18)
    panel.add_child(layout)

    death_summary = Label.new()
    death_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    death_summary.add_theme_font_size_override("font_size", 22)
    death_summary.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
    layout.add_child(death_summary)

    var restart_button := Button.new()
    restart_button.text = "Restart"
    restart_button.custom_minimum_size = Vector2(300.0, 54.0)
    restart_button.add_theme_font_size_override("font_size", 21)
    restart_button.pressed.connect(_on_restart_pressed)
    layout.add_child(restart_button)


func _format_time(seconds_value: float) -> String:
    var whole_seconds := floori(seconds_value)
    return "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]
