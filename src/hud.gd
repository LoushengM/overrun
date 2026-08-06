class_name GameHud
extends CanvasLayer

const UI_VOID := Color("071016")
const UI_PANEL := Color(0.035, 0.075, 0.095, 0.93)
const UI_PANEL_ALT := Color(0.055, 0.11, 0.135, 0.96)
const UI_BORDER := Color(0.12, 0.58, 0.68, 0.88)
const UI_CYAN := Color("12d9f2")
const UI_TEAL := Color("3bf2cf")
const UI_ORANGE := Color("f3942d")
const UI_RED := Color("ff4d3d")
const UI_TEXT := Color("d7e7ec")
const UI_MUTED := Color("78909b")

signal upgrade_selected(upgrade_id: String)
signal character_selected(character_id: String)
signal restart_requested(change_character: bool)
signal sound_requested(cue: String)

var root: Control
var health_bar: ProgressBar
var health_label: Label
var stats_label: Label
var build_label: Label
var weapon_hotbar_labels: Array[Label] = []
var surge_label: Label
var boss_notice: Label
var minimap: BossMinimap
var performance_label: Label

var upgrade_overlay: ColorRect
var upgrade_title: Label
var upgrade_subtitle: Label
var upgrade_buttons: Array[Button] = []
var upgrade_selection_index := 0
var death_overlay: ColorRect
var death_summary: Label
var character_overlay: ColorRect
var character_buttons: Array[Button] = []
var character_selection_index := -1
var death_restart_button: Button
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


func _input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return

    # The upgrade overlay is checked first because it is the modal that opens on
    # top of everything else; the select screen only owns input when no upgrade
    # choice is pending.
    if upgrade_overlay.visible:
        var option_index := _digit_index(key_event.keycode)
        if option_index >= 0 and option_index < upgrade_buttons.size() and upgrade_buttons[option_index].visible:
            _on_upgrade_button_pressed(upgrade_buttons[option_index])
            get_viewport().set_input_as_handled()
            return
        match key_event.keycode:
            KEY_UP, KEY_LEFT:
                _move_upgrade_focus(-1)
                get_viewport().set_input_as_handled()
            KEY_DOWN, KEY_RIGHT:
                _move_upgrade_focus(1)
                get_viewport().set_input_as_handled()
            KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
                _confirm_upgrade_selection()
                get_viewport().set_input_as_handled()
        return

    if character_overlay.visible:
        var character_index := _digit_index(key_event.keycode)
        if character_index >= 0 and character_index < character_buttons.size():
            _on_character_button_pressed(character_buttons[character_index])
            get_viewport().set_input_as_handled()
        return

    if death_overlay.visible:
        match key_event.keycode:
            KEY_R, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
                restart_requested.emit(false)
                get_viewport().set_input_as_handled()
            KEY_ESCAPE:
                restart_requested.emit(true)
                get_viewport().set_input_as_handled()


func _digit_index(keycode: int) -> int:
    match keycode:
        KEY_1, KEY_KP_1:
            return 0
        KEY_2, KEY_KP_2:
            return 1
        KEY_3, KEY_KP_3:
            return 2
        KEY_4, KEY_KP_4:
            return 3
        KEY_5, KEY_KP_5:
            return 4
        KEY_6, KEY_KP_6:
            return 5
        _:
            return -1


func _move_upgrade_focus(direction: int) -> void:
    var visible_indices: Array[int] = []
    for i in range(upgrade_buttons.size()):
        if upgrade_buttons[i].visible:
            visible_indices.append(i)
    if visible_indices.is_empty():
        return
    var current_position := visible_indices.find(upgrade_selection_index)
    if current_position < 0:
        current_position = 0
    var next_position := posmod(current_position + direction, visible_indices.size())
    var next_index := visible_indices[next_position]
    if next_index != upgrade_selection_index:
        sound_requested.emit("menu_move")
    _focus_upgrade_button(next_index)


func _focus_upgrade_button(index: int) -> void:
    if index < 0 or index >= upgrade_buttons.size() or not upgrade_buttons[index].visible:
        return
    upgrade_selection_index = index
    upgrade_buttons[index].grab_focus()


func _confirm_upgrade_selection() -> void:
    if upgrade_selection_index < 0 or upgrade_selection_index >= upgrade_buttons.size():
        return
    var button := upgrade_buttons[upgrade_selection_index]
    if button.visible:
        _on_upgrade_button_pressed(button)


func _on_upgrade_button_focused(index: int) -> void:
    if upgrade_overlay.visible and index != upgrade_selection_index:
        sound_requested.emit("menu_move")
    upgrade_selection_index = index


func _on_character_button_focused(index: int) -> void:
    if character_overlay.visible and index != character_selection_index:
        sound_requested.emit("menu_move")
    character_selection_index = index


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

    # Every weapon in WEAPON_IDS needs an entry or the loadout line renders "?"
    # for it. The four newer weapons were missing, so an expanded loadout was
    # unreadable during play.
    var weapon_codes := {
        "needle": "N",
        "sniper": "S",
        "aura": "A",
        "field": "F",
        "chain": "C",
        "flak": "K",
        "orbital": "O",
        "detonator": "D",
    }
    var owned_weapon_ids: Array = stats.get("owned_weapons", [])
    _update_weapon_hotbar(
        owned_weapon_ids,
        stats.get("weapon_targeting_modes", {}),
        stats
    )
    var loadout_codes: Array[String] = []
    for weapon_id in owned_weapon_ids:
        loadout_codes.append(weapon_codes.get(weapon_id, "?"))

    build_label.text = (
        "DMG x%.2f  ASPD x%.2f\n" % [
            stats.get("damage_multiplier", 1.0),
            stats.get("attack_speed_multiplier", 1.0),
        ]
        + "W %d/%d  LOADOUT %s\n" % [
            stats.get("weapon_slots", 1),
            stats.get("weapon_slot_cap", 4),
            " ".join(loadout_codes),
        ]
        + "NEEDLE %dx  %dp  H%d%%\n" % [
            stats.get("projectile_count", 1),
            stats.get("pierce", 0),
            stats.get("needle_homing_percent", 0),
        ]
        + "%.0f armor  %.1f%% regen/s" % [
            stats.get("armor", 0.0),
            stats.get("regen_rate", 0.0) * 100.0,
        ]
    )
    surge_label.visible = stats.get("surge", false)
    if performance_label.visible:
        var fps := maxi(1, int(stats.get("fps", 0)))
        performance_label.text = (
            "PERFORMANCE  [F3]
"
            + "FPS %d    FRAME %.2f ms
" % [fps, 1000.0 / float(fps)]
            + "PROCESS %.2f ms    PHYSICS %.2f ms
" % [
                stats.get("process_ms", 0.0),
                stats.get("physics_ms", 0.0),
            ]
            + "DRAW %d    PRIMS %d    OBJECTS %d
" % [
                int(stats.get("draw_calls", 0)),
                int(stats.get("primitives", 0)),
                int(stats.get("render_objects", 0)),
            ]
            + "ENEMY %d/%d    SHOTS %d    FIELDS %d
" % [
                int(stats.get("enemies", 0)),
                int(stats.get("enemy_cap", 0)),
                int(stats.get("enemy_shots", 0)),
                int(stats.get("fields", 0)),
            ]
            + "PROJECTILES %d    ORBITALS %d    BLASTS %d
" % [
                int(stats.get("projectiles", 0)),
                int(stats.get("orbitals", 0)),
                int(stats.get("blasts", 0)),
            ]
            + "GRID CELLS %d    SPAWN POP %.0f%%" % [
                int(stats.get("grid_cells", 0)),
                float(stats.get("spawn_population_multiplier", 1.0)) * 100.0,
            ]
        )


func _update_weapon_hotbar(
    owned_weapon_ids: Array,
    targeting_modes_variant: Variant,
    stats: Dictionary
) -> void:
    var targeting_modes: Dictionary = (
        targeting_modes_variant
        if targeting_modes_variant is Dictionary
        else {}
    )
    for slot_index in range(weapon_hotbar_labels.size()):
        var label := weapon_hotbar_labels[slot_index]
        if slot_index >= owned_weapon_ids.size():
            label.text = "[%d]  EMPTY\n—" % (slot_index + 1)
            label.add_theme_color_override("font_color", UI_MUTED)
            continue
        var weapon_id := str(owned_weapon_ids[slot_index])
        var weapon_name := str(GameConfig.WEAPON_NAMES.get(weapon_id, weapon_id)).to_upper()
        var mode := str(targeting_modes.get(weapon_id, "AREA"))
        var detail := mode
        if weapon_id == "needle":
            detail += "  H%d%%" % int(stats.get("needle_homing_percent", 0))
        elif weapon_id == "sniper":
            detail += "  x%.2f" % float(stats.get("sniper_size_multiplier", 1.0))
        elif weapon_id == "flak":
            detail += "  %.1f°" % float(stats.get("flak_spread_degrees", GameConfig.FLAK_SPREAD_DEGREES))
        label.text = "[%d]  %s\n%s" % [slot_index + 1, weapon_name, detail]
        match mode:
            "STRONGEST":
                label.add_theme_color_override("font_color", UI_ORANGE)
            "CLOSEST":
                label.add_theme_color_override("font_color", UI_CYAN)
            _:
                label.add_theme_color_override("font_color", UI_TEAL)


func toggle_performance_overlay() -> bool:
    performance_label.visible = not performance_label.visible
    return performance_label.visible


func show_upgrade(
    options: Array[String],
    title_text: String = "LEVEL UP",
    subtitle_text: String = "Click a choice or press 1, 2, or 3"
) -> void:
    upgrade_title.text = title_text
    upgrade_subtitle.text = "%s — arrows select, Enter/Space confirm, or press 1/2/3" % subtitle_text
    for i in range(upgrade_buttons.size()):
        var button := upgrade_buttons[i]
        if i < options.size():
            var upgrade_id := options[i]
            button.visible = true
            button.set_meta("upgrade_id", upgrade_id)
            button.text = "[%d]  %s\n%s" % [
                i + 1,
                GameConfig.UPGRADE_NAMES.get(upgrade_id, upgrade_id),
                GameConfig.UPGRADE_DESCRIPTIONS.get(upgrade_id, ""),
            ]
        else:
            button.visible = false
    upgrade_overlay.visible = true
    upgrade_selection_index = 0
    _focus_upgrade_button(0)


func hide_upgrade() -> void:
    upgrade_overlay.visible = false


func show_death(summary: Dictionary) -> void:
    death_summary.text = (
        "Run ended\n\n"
        + "Time survived: %s\n" % _format_time(summary.get("elapsed", 0.0))
        + "Level reached: %d\n" % summary.get("level", 1)
        + "Enemies destroyed: %d\n" % summary.get("kills", 0)
        + "Peak base damage: %.1f\n" % summary.get("damage", 0.0)
        + "Weapons equipped: %d / %d\n\n" % [summary.get("weapon_slots", 1), summary.get("weapon_slot_cap", 4)]
        + "R / Enter / Space: restart same operator\n"
        + "Escape: choose a different operator"
    )
    death_overlay.visible = true
    if death_restart_button != null:
        death_restart_button.grab_focus()


func show_character_select(current_character_id: String = "") -> void:
    var current_index := 0
    for index in range(character_buttons.size()):
        var button := character_buttons[index]
        var character_id: String = button.get_meta("character_id", "")
        var is_current := character_id == current_character_id
        if is_current:
            current_index = index
        button.add_theme_color_override(
            "font_color",
            Color(0.48, 0.92, 1.0) if is_current else Color(0.88, 0.93, 1.0)
        )
    character_overlay.visible = true
    character_selection_index = current_index
    if not character_buttons.is_empty():
        character_buttons[current_index].grab_focus()


func hide_character_select() -> void:
    character_overlay.visible = false


func reset_display() -> void:
    upgrade_overlay.visible = false
    death_overlay.visible = false
    character_overlay.visible = false
    boss_notice.visible = false
    boss_notice_time = 0.0


func show_boss_notice() -> void:
    boss_notice.text = "HEAVY SIGNAL DETECTED — TRACKING ON RADAR"
    boss_notice_time = 2.5
    boss_notice.modulate.a = 1.0
    boss_notice.visible = true


func _on_upgrade_button_pressed(button: Button) -> void:
    var upgrade_id: String = button.get_meta("upgrade_id", "")
    if upgrade_id.is_empty():
        return
    upgrade_selected.emit(upgrade_id)


func _on_character_button_pressed(button: Button) -> void:
    var character_id: String = button.get_meta("character_id", "")
    if character_id.is_empty():
        return
    character_selected.emit(character_id)


func _on_restart_pressed() -> void:
    restart_requested.emit(false)


func _build_interface() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var top_back := Panel.new()
    top_back.position = Vector2(18.0, 18.0)
    top_back.size = Vector2(430.0, 152.0)
    top_back.add_theme_stylebox_override("panel", _make_panel_style(UI_PANEL, UI_BORDER, 2, 7))
    top_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top_back)

    var top_accent := ColorRect.new()
    top_accent.position = Vector2(18.0, 18.0)
    top_accent.size = Vector2(8.0, 152.0)
    top_accent.color = UI_CYAN
    top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top_accent)

    health_bar = ProgressBar.new()
    health_bar.position = Vector2(32.0, 32.0)
    health_bar.size = Vector2(400.0, 24.0)
    health_bar.show_percentage = false
    health_bar.add_theme_stylebox_override("background", _make_panel_style(Color("0b151b"), Color("1c3d47"), 1, 3))
    health_bar.add_theme_stylebox_override("fill", _make_panel_style(UI_CYAN, UI_TEAL, 1, 3))
    root.add_child(health_bar)

    health_label = Label.new()
    health_label.position = Vector2(42.0, 33.0)
    health_label.size = Vector2(380.0, 24.0)
    health_label.add_theme_font_size_override("font_size", 15)
    health_label.add_theme_color_override("font_color", UI_TEXT)
    health_label.add_theme_constant_override("outline_size", 5)
    health_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
    root.add_child(health_label)

    stats_label = Label.new()
    stats_label.position = Vector2(32.0, 64.0)
    stats_label.size = Vector2(270.0, 100.0)
    stats_label.add_theme_font_size_override("font_size", 15)
    stats_label.add_theme_color_override("font_color", UI_TEXT)
    root.add_child(stats_label)

    build_label = Label.new()
    build_label.position = Vector2(255.0, 64.0)
    build_label.size = Vector2(180.0, 100.0)
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    build_label.add_theme_font_size_override("font_size", 14)
    build_label.add_theme_color_override("font_color", Color("a8c0c8"))
    root.add_child(build_label)

    _build_weapon_hotbar()

    surge_label = Label.new()
    surge_label.position = Vector2(18.0, 178.0)
    surge_label.size = Vector2(260.0, 30.0)
    surge_label.text = "SPAWN SURGE"
    surge_label.add_theme_font_size_override("font_size", 18)
    surge_label.add_theme_color_override("font_color", UI_ORANGE)
    root.add_child(surge_label)

    minimap = BossMinimap.new()
    minimap.position = Vector2(1068.0, 18.0)
    minimap.size = Vector2(194.0, 194.0)
    root.add_child(minimap)

    var minimap_label := Label.new()
    minimap_label.position = Vector2(1068.0, 214.0)
    minimap_label.size = Vector2(194.0, 24.0)
    minimap_label.text = "TACTICAL RADAR"
    minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    minimap_label.add_theme_font_size_override("font_size", 13)
    minimap_label.add_theme_color_override("font_color", UI_CYAN)
    root.add_child(minimap_label)

    var controls := Label.new()
    controls.position = Vector2(18.0, 675.0)
    controls.size = Vector2(980.0, 28.0)
    controls.text = "MOVE: WASD / ARROWS     1–4: TOGGLE WEAPON TARGET     T: TOGGLE ALL     F3: PERFORMANCE     ESC: QUIT"
    controls.add_theme_font_size_override("font_size", 14)
    controls.add_theme_color_override("font_color", UI_MUTED)
    root.add_child(controls)

    performance_label = Label.new()
    performance_label.position = Vector2(18.0, 468.0)
    performance_label.size = Vector2(360.0, 190.0)
    performance_label.add_theme_font_size_override("font_size", 14)
    performance_label.add_theme_color_override("font_color", UI_CYAN)
    performance_label.add_theme_constant_override("outline_size", 5)
    performance_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
    performance_label.visible = false
    performance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(performance_label)

    boss_notice = Label.new()
    boss_notice.position = Vector2(390.0, 245.0)
    boss_notice.size = Vector2(500.0, 50.0)
    boss_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_notice.add_theme_font_size_override("font_size", 24)
    boss_notice.add_theme_color_override("font_color", UI_ORANGE)
    boss_notice.add_theme_constant_override("outline_size", 8)
    boss_notice.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
    boss_notice.visible = false
    root.add_child(boss_notice)

    _build_upgrade_overlay()
    _build_death_overlay()
    _build_character_overlay()


func _build_weapon_hotbar() -> void:
    var hotbar_back := Panel.new()
    hotbar_back.position = Vector2(466.0, 18.0)
    hotbar_back.size = Vector2(584.0, 80.0)
    hotbar_back.add_theme_stylebox_override("panel", _make_panel_style(UI_PANEL, UI_BORDER, 2, 7))
    hotbar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hotbar_back)

    for slot_index in range(GameConfig.WEAPON_SLOT_CAP):
        var label := Label.new()
        label.position = Vector2(6.0 + float(slot_index) * 143.0, 8.0)
        label.size = Vector2(137.0, 64.0)
        label.text = "[%d]  EMPTY\n—" % (slot_index + 1)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 13)
        label.add_theme_color_override("font_color", UI_MUTED)
        hotbar_back.add_child(label)
        weapon_hotbar_labels.append(label)


func _build_upgrade_overlay() -> void:
    upgrade_overlay = ColorRect.new()
    upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    upgrade_overlay.color = Color(0.01, 0.03, 0.04, 0.82)
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
    panel.add_theme_stylebox_override("panel", _make_panel_style(UI_PANEL, UI_BORDER, 2, 9))
    upgrade_overlay.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 14)
    panel.add_child(layout)

    upgrade_title = Label.new()
    upgrade_title.text = "LEVEL UP"
    upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    upgrade_title.add_theme_font_size_override("font_size", 34)
    upgrade_title.add_theme_color_override("font_color", UI_CYAN)
    layout.add_child(upgrade_title)

    upgrade_subtitle = Label.new()
    upgrade_subtitle.text = "Arrows select, Enter/Space confirm, or press 1/2/3"
    upgrade_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    upgrade_subtitle.add_theme_font_size_override("font_size", 18)
    layout.add_child(upgrade_subtitle)

    for i in range(3):
        var button := Button.new()
        button.custom_minimum_size = Vector2(730.0, 82.0)
        button.add_theme_font_size_override("font_size", 19)
        button.focus_mode = Control.FOCUS_ALL
        _style_button(button)
        button.pressed.connect(_on_upgrade_button_pressed.bind(button))
        button.focus_entered.connect(_on_upgrade_button_focused.bind(i))
        layout.add_child(button)
        upgrade_buttons.append(button)


func _build_character_overlay() -> void:
    character_overlay = ColorRect.new()
    character_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    character_overlay.color = Color(0.01, 0.025, 0.035, 0.90)
    character_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    character_overlay.visible = false
    root.add_child(character_overlay)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -430.0
    panel.offset_top = -320.0
    panel.offset_right = 430.0
    panel.offset_bottom = 320.0
    panel.add_theme_stylebox_override("panel", _make_panel_style(UI_PANEL, UI_BORDER, 2, 9))
    character_overlay.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 8)
    panel.add_child(layout)

    var title := Label.new()
    title.text = "SELECT OPERATOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", UI_CYAN)
    layout.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Click an operator or press its number"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    layout.add_child(subtitle)

    for i in range(GameConfig.CHARACTER_IDS.size()):
        var character_id: String = GameConfig.CHARACTER_IDS[i]
        var data: Dictionary = GameConfig.CHARACTERS.get(character_id, {})
        var button := Button.new()
        button.custom_minimum_size = Vector2(820.0, 72.0)
        button.add_theme_font_size_override("font_size", 17)
        button.set_meta("character_id", character_id)
        button.focus_mode = Control.FOCUS_ALL
        _style_button(button)
        var starting_weapon := str(data.get("weapon", ""))
        var loadout := "Needle"
        if not starting_weapon.is_empty():
            loadout += " + " + str(GameConfig.WEAPON_NAMES.get(starting_weapon, starting_weapon))
        button.text = "[%d]  %s — %s\n%s   |   HP x%.2f  SPD x%.2f  DMG x%.2f   |   %s" % [
            i + 1,
            str(data.get("name", character_id)),
            str(data.get("passive", "")),
            str(data.get("blurb", "")),
            float(data.get("health", 1.0)),
            float(data.get("speed", 1.0)),
            float(data.get("damage", 1.0)),
            loadout,
        ]
        button.pressed.connect(_on_character_button_pressed.bind(button))
        button.focus_entered.connect(_on_character_button_focused.bind(i))
        layout.add_child(button)
        character_buttons.append(button)


func _build_death_overlay() -> void:
    death_overlay = ColorRect.new()
    death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    death_overlay.color = Color(0.01, 0.025, 0.035, 0.88)
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
    panel.add_theme_stylebox_override("panel", _make_panel_style(UI_PANEL, UI_RED, 2, 9))
    death_overlay.add_child(panel)

    var layout := VBoxContainer.new()
    layout.alignment = BoxContainer.ALIGNMENT_CENTER
    layout.add_theme_constant_override("separation", 18)
    panel.add_child(layout)

    death_summary = Label.new()
    death_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    death_summary.add_theme_font_size_override("font_size", 22)
    death_summary.add_theme_color_override("font_color", UI_TEXT)
    layout.add_child(death_summary)

    death_restart_button = Button.new()
    death_restart_button.text = "Restart same operator"
    death_restart_button.custom_minimum_size = Vector2(300.0, 54.0)
    death_restart_button.add_theme_font_size_override("font_size", 21)
    death_restart_button.focus_mode = Control.FOCUS_ALL
    _style_button(death_restart_button, UI_ORANGE)
    death_restart_button.pressed.connect(_on_restart_pressed)
    layout.add_child(death_restart_button)


func _make_panel_style(
    fill: Color,
    border: Color,
    border_width: int = 1,
    corner_radius: int = 4
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.border_width_left = border_width
    style.border_width_top = border_width
    style.border_width_right = border_width
    style.border_width_bottom = border_width
    style.corner_radius_top_left = corner_radius
    style.corner_radius_top_right = corner_radius
    style.corner_radius_bottom_left = corner_radius
    style.corner_radius_bottom_right = corner_radius
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style


func _style_button(button: Button, accent: Color = UI_CYAN) -> void:
    button.add_theme_stylebox_override(
        "normal",
        _make_panel_style(UI_PANEL_ALT, Color(accent, 0.42), 1, 5)
    )
    button.add_theme_stylebox_override(
        "hover",
        _make_panel_style(Color(0.07, 0.16, 0.19, 0.98), Color(accent, 0.82), 2, 5)
    )
    button.add_theme_stylebox_override(
        "pressed",
        _make_panel_style(Color(0.035, 0.11, 0.14, 1.0), accent, 2, 5)
    )
    button.add_theme_stylebox_override(
        "focus",
        _make_panel_style(Color(0.04, 0.13, 0.16, 0.36), accent, 3, 5)
    )
    button.add_theme_color_override("font_color", UI_TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_focus_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _format_time(seconds_value: float) -> String:
    var whole_seconds := floori(seconds_value)
    return "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]
