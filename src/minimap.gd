class_name BossMinimap
extends Control

const RADAR_TEXTURE_SIZE := 194
const MARKER_FRAME_SIZE := 24
const MARKER_COLUMNS := 3

enum MarkerFrame { BOSS, PICKUP, PLAYER }

var world: SimulationWorld
var radar_texture: Texture2D
var marker_texture: Texture2D
var marker_multimesh: MultiMesh


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    radar_texture = _make_radar_texture(RADAR_TEXTURE_SIZE)
    marker_texture = _make_marker_atlas(MARKER_FRAME_SIZE)
    marker_multimesh = MultiMesh.new()
    marker_multimesh.transform_format = MultiMesh.TRANSFORM_2D
    marker_multimesh.use_colors = true
    marker_multimesh.use_custom_data = true
    marker_multimesh.instance_count = GameConfig.BOSS_CAP + GameConfig.PICKUP_CAP + 1
    marker_multimesh.visible_instance_count = 0
    var marker_mesh := QuadMesh.new()
    marker_mesh.size = Vector2.ONE * float(MARKER_FRAME_SIZE)
    marker_multimesh.mesh = marker_mesh

    var shader := Shader.new()
    shader.code = """shader_type canvas_item;

void vertex() {
    if (INSTANCE_CUSTOM.z > 0.0) {
        UV = UV * INSTANCE_CUSTOM.zw + INSTANCE_CUSTOM.xy;
    }
}
"""
    var atlas_material := ShaderMaterial.new()
    atlas_material.shader = shader
    material = atlas_material
    set_process(true)


func set_world(value: SimulationWorld) -> void:
    world = value
    queue_redraw()


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var center := size * 0.5
    var radar_radius := minf(size.x, size.y) * 0.5 - 13.0
    if radar_texture != null:
        draw_texture_rect(radar_texture, Rect2(Vector2.ZERO, size), false)

    # Only the sweep remains procedural. Static rings/brackets are baked, and
    # all player/boss/pickup markers share one MultiMesh draw call.
    var sweep_angle := Time.get_ticks_msec() * 0.0007
    draw_line(
        center,
        center + Vector2.from_angle(sweep_angle) * radar_radius,
        Color(0.10, 0.78, 0.88, 0.22),
        2.0
    )

    if marker_multimesh == null or marker_texture == null:
        return

    var marker_count := 0
    marker_count = _write_marker(marker_count, center, 0.80, MarkerFrame.PLAYER, Color.WHITE)
    if world != null:
        var scale_factor := radar_radius / (GameConfig.WORLD_HALF_SIZE * 0.72)
        for boss_position in world.get_boss_positions():
            if marker_count >= marker_multimesh.instance_count:
                break
            var relative := WorldSpace.delta(world.player_position, boss_position) * scale_factor
            var marker := center + relative.limit_length(radar_radius - 7.0)
            marker_count = _write_marker(marker_count, marker, 1.0, MarkerFrame.BOSS, Color.WHITE)

        if world.get_player_health_fraction() < 0.50:
            for pickup_position in world.get_pickup_positions():
                if marker_count >= marker_multimesh.instance_count:
                    break
                var relative := WorldSpace.delta(world.player_position, pickup_position) * scale_factor
                if relative.length() > radar_radius - 5.0:
                    continue
                marker_count = _write_marker(
                    marker_count,
                    center + relative,
                    0.56,
                    MarkerFrame.PICKUP,
                    Color.WHITE
                )
    marker_multimesh.visible_instance_count = marker_count
    draw_multimesh(marker_multimesh, marker_texture)


func _write_marker(
    marker_index: int,
    position: Vector2,
    scale_value: float,
    frame: int,
    color: Color
) -> int:
    var marker_transform := Transform2D.IDENTITY
    marker_transform.x *= scale_value
    marker_transform.y *= scale_value
    marker_transform.origin = position
    marker_multimesh.set_instance_transform_2d(marker_index, marker_transform)
    marker_multimesh.set_instance_color(marker_index, color)
    marker_multimesh.set_instance_custom_data(marker_index, _marker_frame_data(frame))
    return marker_index + 1


func _marker_frame_data(frame: int) -> Color:
    var scale_value := 1.0 / float(MARKER_COLUMNS)
    return Color(float(clampi(frame, 0, MARKER_COLUMNS - 1)) * scale_value, 0.0, scale_value, 1.0)


func _make_radar_texture(texture_size: int) -> Texture2D:
    var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.02, 0.055, 0.07, 0.94))
    var center := Vector2i(texture_size / 2, texture_size / 2)
    var radius := texture_size / 2 - 13

    _image_rect_outline(image, Rect2i(0, 0, texture_size, texture_size), 2, Color(0.07, 0.47, 0.58, 0.92))
    _image_circle(image, center, radius, Color(0.01, 0.025, 0.035, 0.76), true)
    for ring_index in range(1, 4):
        _image_circle(
            image,
            center,
            roundi(float(radius) * float(ring_index) / 3.0),
            Color(0.12, 0.48, 0.57, 0.34),
            false
        )
    _image_line(image, center - Vector2i(radius, 0), center + Vector2i(radius, 0), 1, Color(0.10, 0.39, 0.46, 0.30))
    _image_line(image, center - Vector2i(0, radius), center + Vector2i(0, radius), 1, Color(0.10, 0.39, 0.46, 0.30))

    var bracket := 16
    var inset := 5
    var cyan := Color("12d9f2")
    _image_line(image, Vector2i(inset, inset), Vector2i(inset + bracket, inset), 2, cyan)
    _image_line(image, Vector2i(inset, inset), Vector2i(inset, inset + bracket), 2, cyan)
    _image_line(image, Vector2i(texture_size - inset, inset), Vector2i(texture_size - inset - bracket, inset), 2, cyan)
    _image_line(image, Vector2i(texture_size - inset, inset), Vector2i(texture_size - inset, inset + bracket), 2, cyan)
    _image_line(image, Vector2i(inset, texture_size - inset), Vector2i(inset + bracket, texture_size - inset), 2, cyan)
    _image_line(image, Vector2i(inset, texture_size - inset), Vector2i(inset, texture_size - inset - bracket), 2, cyan)
    _image_line(image, Vector2i(texture_size - inset, texture_size - inset), Vector2i(texture_size - inset - bracket, texture_size - inset), 2, cyan)
    _image_line(image, Vector2i(texture_size - inset, texture_size - inset), Vector2i(texture_size - inset, texture_size - inset - bracket), 2, cyan)
    return ImageTexture.create_from_image(image)


func _make_marker_atlas(frame_size: int) -> Texture2D:
    var image := Image.create(frame_size * MARKER_COLUMNS, frame_size, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var center := Vector2i(frame_size / 2, frame_size / 2)

    # Boss: orange-red diamond with a soft circular warning halo.
    var boss_origin := Vector2i.ZERO
    _image_circle(image, boss_origin + center, 10, Color(1.0, 0.25, 0.12, 0.14), true)
    for y in range(-7, 8):
        for x in range(-7, 8):
            if absi(x) + absi(y) <= 7:
                image.set_pixelv(boss_origin + center + Vector2i(x, y), Color("ff5b3d"))
    _image_line(image, boss_origin + center + Vector2i(0, -7), boss_origin + center + Vector2i(7, 0), 1, Color("ffb143"))
    _image_line(image, boss_origin + center + Vector2i(7, 0), boss_origin + center + Vector2i(0, 7), 1, Color("ffb143"))
    _image_line(image, boss_origin + center + Vector2i(0, 7), boss_origin + center + Vector2i(-7, 0), 1, Color("ffb143"))
    _image_line(image, boss_origin + center + Vector2i(-7, 0), boss_origin + center + Vector2i(0, -7), 1, Color("ffb143"))

    # Pickup: compact teal repair signal.
    var pickup_origin := Vector2i(frame_size, 0)
    _image_circle(image, pickup_origin + center, 7, Color(0.23, 0.95, 0.81, 0.24), true)
    _image_circle(image, pickup_origin + center, 4, Color("3bf2cf"), true)
    _image_line(image, pickup_origin + center + Vector2i(-5, 0), pickup_origin + center + Vector2i(5, 0), 2, Color.WHITE)
    _image_line(image, pickup_origin + center + Vector2i(0, -5), pickup_origin + center + Vector2i(0, 5), 2, Color.WHITE)

    # Player: forward-facing cyan operator arrow.
    var player_origin := Vector2i(frame_size * 2, 0)
    for y in range(-7, 7):
        var half_width := maxi(1, (y + 7) / 2)
        for x in range(-half_width, half_width + 1):
            image.set_pixelv(player_origin + center + Vector2i(x, y), Color("12d9f2"))
    _image_line(image, player_origin + center + Vector2i(0, -7), player_origin + center + Vector2i(6, 6), 1, Color.WHITE)
    _image_line(image, player_origin + center + Vector2i(0, -7), player_origin + center + Vector2i(-6, 6), 1, Color.WHITE)
    return ImageTexture.create_from_image(image)


func _image_rect_outline(image: Image, rect: Rect2i, width: int, color: Color) -> void:
    for offset in range(width):
        _image_line(image, rect.position + Vector2i(offset, offset), Vector2i(rect.end.x - 1 - offset, rect.position.y + offset), 1, color)
        _image_line(image, Vector2i(rect.position.x + offset, rect.end.y - 1 - offset), rect.end - Vector2i(1 + offset, 1 + offset), 1, color)
        _image_line(image, rect.position + Vector2i(offset, offset), Vector2i(rect.position.x + offset, rect.end.y - 1 - offset), 1, color)
        _image_line(image, Vector2i(rect.end.x - 1 - offset, rect.position.y + offset), rect.end - Vector2i(1 + offset, 1 + offset), 1, color)


func _image_circle(image: Image, center: Vector2i, radius: int, color: Color, filled: bool) -> void:
    var radius_squared := radius * radius
    var inner_radius := maxi(0, radius - 1)
    var inner_squared := inner_radius * inner_radius
    for y in range(center.y - radius, center.y + radius + 1):
        for x in range(center.x - radius, center.x + radius + 1):
            if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
                continue
            var dx := x - center.x
            var dy := y - center.y
            var distance_squared := dx * dx + dy * dy
            if distance_squared <= radius_squared and (filled or distance_squared >= inner_squared):
                image.set_pixel(x, y, color)


func _image_line(image: Image, start: Vector2i, finish: Vector2i, width: int, color: Color) -> void:
    var delta := finish - start
    var steps := maxi(absi(delta.x), absi(delta.y))
    if steps <= 0:
        _image_circle(image, start, maxi(1, width / 2), color, true)
        return
    for step in range(steps + 1):
        var point := Vector2(start).lerp(Vector2(finish), float(step) / float(steps))
        _image_circle(
            image,
            Vector2i(roundi(point.x), roundi(point.y)),
            maxi(1, width / 2),
            color,
            true
        )
