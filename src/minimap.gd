class_name BossMinimap
extends Control

var world: SimulationWorld


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)


func set_world(value: SimulationWorld) -> void:
    world = value
    queue_redraw()


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    var center := size * 0.5
    var radar_radius := minf(size.x, size.y) * 0.5 - 13.0
    draw_rect(rect, Color(0.02, 0.055, 0.07, 0.94), true)
    draw_rect(rect, Color(0.07, 0.47, 0.58, 0.92), false, 2.0)

    # Cyan corner brackets echo the rest of the HUD without enclosing the radar
    # in another heavy box.
    var bracket := 16.0
    var inset := 5.0
    var corner_color := Color("12d9f2")
    draw_line(Vector2(inset, inset), Vector2(inset + bracket, inset), corner_color, 2.0)
    draw_line(Vector2(inset, inset), Vector2(inset, inset + bracket), corner_color, 2.0)
    draw_line(Vector2(size.x - inset, inset), Vector2(size.x - inset - bracket, inset), corner_color, 2.0)
    draw_line(Vector2(size.x - inset, inset), Vector2(size.x - inset, inset + bracket), corner_color, 2.0)
    draw_line(Vector2(inset, size.y - inset), Vector2(inset + bracket, size.y - inset), corner_color, 2.0)
    draw_line(Vector2(inset, size.y - inset), Vector2(inset, size.y - inset - bracket), corner_color, 2.0)
    draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset - bracket, size.y - inset), corner_color, 2.0)
    draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - bracket), corner_color, 2.0)

    draw_circle(center, radar_radius, Color(0.01, 0.025, 0.035, 0.76))
    for ring_index in range(1, 4):
        draw_arc(
            center,
            radar_radius * float(ring_index) / 3.0,
            0.0,
            TAU,
            64,
            Color(0.12, 0.48, 0.57, 0.34),
            1.0
        )
    draw_line(center - Vector2(radar_radius, 0.0), center + Vector2(radar_radius, 0.0), Color(0.10, 0.39, 0.46, 0.30), 1.0)
    draw_line(center - Vector2(0.0, radar_radius), center + Vector2(0.0, radar_radius), Color(0.10, 0.39, 0.46, 0.30), 1.0)

    var sweep_angle := Time.get_ticks_msec() * 0.0007
    draw_line(center, center + Vector2.from_angle(sweep_angle) * radar_radius, Color(0.10, 0.78, 0.88, 0.22), 2.0)

    var player_marker := PackedVector2Array([
        center + Vector2(0.0, -7.0),
        center + Vector2(6.0, 6.0),
        center,
        center + Vector2(-6.0, 6.0),
    ])
    draw_colored_polygon(player_marker, Color("12d9f2"))
    draw_polyline(player_marker + PackedVector2Array([player_marker[0]]), Color.WHITE, 1.0)

    if world == null:
        return

    var scale_factor := radar_radius / (GameConfig.WORLD_HALF_SIZE * 0.72)
    for boss_position in world.get_boss_positions():
        var relative := WorldSpace.delta(world.player_position, boss_position) * scale_factor
        var marker := center + relative.limit_length(radar_radius - 7.0)
        var diamond := PackedVector2Array([
            marker + Vector2(0.0, -7.0),
            marker + Vector2(7.0, 0.0),
            marker + Vector2(0.0, 7.0),
            marker + Vector2(-7.0, 0.0),
        ])
        draw_circle(marker, 10.0, Color(1.0, 0.25, 0.12, 0.12))
        draw_colored_polygon(diamond, Color("ff5b3d"))
        draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color("ffb143"), 1.0)

    if world.get_player_health_fraction() < 0.50:
        for pickup_position in world.get_pickup_positions():
            var relative := WorldSpace.delta(world.player_position, pickup_position) * scale_factor
            if relative.length() <= radar_radius - 5.0:
                var marker := center + relative
                draw_circle(marker, 3.0, Color("3bf2cf"))
                draw_arc(marker, 5.0, 0.0, TAU, 16, Color(0.23, 0.95, 0.81, 0.38), 1.0)
