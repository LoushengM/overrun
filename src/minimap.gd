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
    draw_rect(rect, Color(0.015, 0.02, 0.035, 0.92), true)
    draw_rect(rect, Color(0.30, 0.45, 0.58, 0.85), false, 2.0)

    if world == null:
        return

    var center := size * 0.5
    draw_line(Vector2(center.x, 8.0), Vector2(center.x, size.y - 8.0), Color(0.18, 0.25, 0.32, 0.45), 1.0)
    draw_line(Vector2(8.0, center.y), Vector2(size.x - 8.0, center.y), Color(0.18, 0.25, 0.32, 0.45), 1.0)
    draw_circle(center, 4.0, Color(0.30, 0.88, 1.0, 1.0))

    var scale_factor := 0.045
    for boss_position in world.get_boss_positions():
        var relative := WorldSpace.delta(world.player_position, boss_position) * scale_factor
        var marker := center + relative
        marker.x = clampf(marker.x, 9.0, size.x - 9.0)
        marker.y = clampf(marker.y, 9.0, size.y - 9.0)
        var diamond := PackedVector2Array([
            marker + Vector2(0.0, -7.0),
            marker + Vector2(7.0, 0.0),
            marker + Vector2(0.0, 7.0),
            marker + Vector2(-7.0, 0.0),
        ])
        draw_colored_polygon(diamond, Color(1.0, 0.18, 0.28, 1.0))

    if world.get_player_health_fraction() < 0.50:
        for pickup_position in world.get_pickup_positions():
            var relative := WorldSpace.delta(world.player_position, pickup_position) * scale_factor
            var marker := center + relative
            if Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0)).has_point(marker):
                draw_circle(marker, 2.5, Color(0.30, 1.0, 0.48, 0.9))
