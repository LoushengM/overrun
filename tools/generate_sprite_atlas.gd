extends SceneTree

# Regenerates assets/robots.png, the batched normal-enemy atlas.
#
# Run with:
#   .tools/godot/Godot_v4.7.1-stable_linux.x86_64 --headless --path . \
#       --script tools/generate_sprite_atlas.gd
#
# The art is intentionally compact, high-contrast pixel work. Normal enemies can
# number in the thousands, so one atlas plus one MultiMesh stays far cheaper than
# a node or animated sprite per unit.

const FRAME_SIZE := 48
const COLUMNS := 4
const ROWS := 2
const FRAME_COUNT := COLUMNS * ROWS

const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)
const OUTLINE := Color("101820")
const JOINT := Color("26343f")
const SHELL_DARK := Color("3d4a55")
const SHELL := Color("788690")
const SHELL_LIT := Color("c5d0d6")
const WHITE_EDGE := Color("eef7fa")
const OPTIC := Color("ff5a38")
const OPTIC_LIT := Color("ffb143")
const CYAN := Color("15d6ed")
const HAZARD := Color("f3922b")


func _init() -> void:
    var image := Image.create(FRAME_SIZE * COLUMNS, FRAME_SIZE * ROWS, false, Image.FORMAT_RGBA8)
    image.fill(TRANSPARENT)

    for frame_index in range(FRAME_COUNT):
        @warning_ignore("integer_division")
        var row := frame_index / COLUMNS
        var origin := Vector2i((frame_index % COLUMNS) * FRAME_SIZE, row * FRAME_SIZE)
        _draw_frame(image, origin, frame_index)
        _outline_frame(image, origin)
        if frame_index == 3:
            _draw_ranged_warning_rim(image, origin)
            _draw_ranged_glow(image, origin)

    var path := ProjectSettings.globalize_path("res://assets/robots.png")
    var error := image.save_png(path)
    if error != OK:
        push_error("Could not write %s (error %d)" % [path, error])
        print("SPRITE_ATLAS_FAILED")
        quit(1)
        return
    print("SPRITE_ATLAS_OK ", JSON.stringify({
        "path": "res://assets/robots.png",
        "size": [image.get_width(), image.get_height()],
        "frames": FRAME_COUNT,
    }))
    quit()


func _draw_frame(image: Image, origin: Vector2i, frame_index: int) -> void:
    match frame_index:
        0:
            _draw_chaser(image, origin)
        1:
            _draw_swarmer(image, origin)
        2:
            _draw_shielded(image, origin)
        3:
            _draw_ranged(image, origin)
        4:
            _draw_splitter(image, origin)
        5:
            _draw_heavy(image, origin)
        6:
            _draw_skitter(image, origin)
        7:
            _draw_elite(image, origin)


func _draw_chaser(image: Image, origin: Vector2i) -> void:
    _line(image, origin, Vector2i(16, 29), Vector2i(8, 40), 4, JOINT)
    _line(image, origin, Vector2i(32, 29), Vector2i(40, 40), 4, JOINT)
    _line(image, origin, Vector2i(17, 31), Vector2i(15, 43), 4, SHELL_DARK)
    _line(image, origin, Vector2i(31, 31), Vector2i(33, 43), 4, SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 25), Vector2i(16, 13), SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 22), Vector2i(14, 12), SHELL)
    _ellipse(image, origin, Vector2i(24, 19), Vector2i(10, 8), SHELL_LIT)
    _rect(image, origin, Rect2i(17, 20, 14, 5), OUTLINE)
    _rect(image, origin, Rect2i(19, 21, 10, 3), OPTIC)
    _rect(image, origin, Rect2i(22, 21, 4, 2), OPTIC_LIT)
    _line(image, origin, Vector2i(24, 11), Vector2i(24, 5), 2, SHELL_DARK)
    _circle(image, origin, Vector2i(24, 4), 2, CYAN)
    _rect(image, origin, Rect2i(10, 26, 5, 3), HAZARD)


func _draw_swarmer(image: Image, origin: Vector2i) -> void:
    for endpoint in [Vector2i(6, 14), Vector2i(5, 28), Vector2i(11, 42), Vector2i(37, 42), Vector2i(43, 28), Vector2i(42, 14)]:
        _line(image, origin, Vector2i(24, 26), endpoint, 3, JOINT)
        _circle(image, origin, endpoint, 2, SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 25), Vector2i(12, 10), SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 22), Vector2i(10, 8), SHELL)
    _ellipse(image, origin, Vector2i(24, 19), Vector2i(7, 5), SHELL_LIT)
    _circle(image, origin, Vector2i(24, 22), 4, OPTIC)
    _circle(image, origin, Vector2i(23, 20), 1, OPTIC_LIT)
    _rect(image, origin, Rect2i(21, 32, 6, 3), HAZARD)


func _draw_shielded(image: Image, origin: Vector2i) -> void:
    _line(image, origin, Vector2i(18, 33), Vector2i(14, 43), 6, JOINT)
    _line(image, origin, Vector2i(31, 33), Vector2i(35, 43), 6, JOINT)
    _rect(image, origin, Rect2i(13, 14, 25, 23), SHELL_DARK)
    _rect(image, origin, Rect2i(17, 11, 17, 22), SHELL)
    _rect(image, origin, Rect2i(19, 12, 13, 7), SHELL_LIT)
    _rect(image, origin, Rect2i(21, 15, 9, 4), OPTIC)
    _rect(image, origin, Rect2i(7, 12, 11, 28), SHELL_LIT)
    _rect(image, origin, Rect2i(9, 15, 6, 22), SHELL)
    _rect(image, origin, Rect2i(9, 19, 6, 4), HAZARD)
    _rect(image, origin, Rect2i(9, 29, 6, 4), HAZARD)
    _circle(image, origin, Vector2i(31, 27), 3, CYAN)


func _draw_ranged(image: Image, origin: Vector2i) -> void:
    _line(image, origin, Vector2i(22, 31), Vector2i(13, 43), 4, JOINT)
    _line(image, origin, Vector2i(27, 31), Vector2i(35, 43), 4, JOINT)
    _line(image, origin, Vector2i(25, 31), Vector2i(25, 44), 4, JOINT)
    _ellipse(image, origin, Vector2i(24, 26), Vector2i(13, 11), SHELL_DARK)
    _ellipse(image, origin, Vector2i(23, 23), Vector2i(11, 9), SHELL)
    _ellipse(image, origin, Vector2i(22, 20), Vector2i(7, 5), SHELL_LIT)
    _rect(image, origin, Rect2i(17, 21, 10, 4), OPTIC)
    _rect(image, origin, Rect2i(29, 21, 15, 6), SHELL_DARK)
    _rect(image, origin, Rect2i(33, 22, 12, 4), SHELL)
    _rect(image, origin, Rect2i(43, 22, 3, 4), OPTIC)
    _line(image, origin, Vector2i(22, 13), Vector2i(22, 6), 2, SHELL_DARK)
    _circle(image, origin, Vector2i(22, 5), 2, OPTIC)
    _rect(image, origin, Rect2i(29, 29, 6, 3), HAZARD)


# A two-pixel warning rim guarantees the ranged silhouette reads red even when
# the soft halo blends into a busy floor. The first pass is opaque and the outer
# pass stays translucent, creating a clear edge without another draw call.
func _draw_ranged_warning_rim(image: Image, origin: Vector2i) -> void:
    for pass_index in range(2):
        var pending: Array[Vector2i] = []
        for y in range(FRAME_SIZE):
            for x in range(FRAME_SIZE):
                if image.get_pixel(origin.x + x, origin.y + y).a > 0.0:
                    continue
                if _has_opaque_neighbour(image, origin, x, y):
                    pending.append(Vector2i(x, y))
        var rim_color := Color("ff2b20") if pass_index == 0 else Color(1.0, 0.03, 0.01, 0.72)
        for point in pending:
            image.set_pixel(origin.x + point.x, origin.y + point.y, rim_color)


# The glow is added after the warning rim so it only fills untouched background
# pixels. Stronger alpha and wider overlapping lobes make the halo visible at
# gameplay scale while keeping all ranged robots in the existing atlas batch.
func _draw_ranged_glow(image: Image, origin: Vector2i) -> void:
    _glow_circle(image, origin, Vector2i(23, 23), 24, Color(1.0, 0.02, 0.01, 0.72))
    _glow_circle(image, origin, Vector2i(39, 24), 15, Color(1.0, 0.01, 0.00, 0.78))
    _glow_circle(image, origin, Vector2i(22, 5), 10, Color(1.0, 0.04, 0.01, 0.64))


func _draw_splitter(image: Image, origin: Vector2i) -> void:
    _line(image, origin, Vector2i(16, 33), Vector2i(10, 43), 5, JOINT)
    _line(image, origin, Vector2i(32, 33), Vector2i(38, 43), 5, JOINT)
    _ellipse(image, origin, Vector2i(24, 25), Vector2i(17, 13), SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 22), Vector2i(15, 11), SHELL)
    _line(image, origin, Vector2i(24, 10), Vector2i(24, 35), 2, OUTLINE)
    _ellipse(image, origin, Vector2i(17, 21), Vector2i(6, 5), SHELL_LIT)
    _ellipse(image, origin, Vector2i(31, 21), Vector2i(6, 5), SHELL_LIT)
    _circle(image, origin, Vector2i(17, 22), 3, OPTIC)
    _circle(image, origin, Vector2i(31, 22), 3, OPTIC)
    _rect(image, origin, Rect2i(20, 34, 8, 3), HAZARD)


func _draw_heavy(image: Image, origin: Vector2i) -> void:
    _line(image, origin, Vector2i(17, 34), Vector2i(13, 44), 7, JOINT)
    _line(image, origin, Vector2i(31, 34), Vector2i(35, 44), 7, JOINT)
    _ellipse(image, origin, Vector2i(24, 25), Vector2i(17, 15), SHELL_DARK)
    _rect(image, origin, Rect2i(8, 14, 10, 18), SHELL)
    _rect(image, origin, Rect2i(30, 14, 10, 18), SHELL)
    _rect(image, origin, Rect2i(10, 16, 6, 7), SHELL_LIT)
    _rect(image, origin, Rect2i(32, 16, 6, 7), SHELL_LIT)
    _ellipse(image, origin, Vector2i(24, 23), Vector2i(13, 12), SHELL)
    _ellipse(image, origin, Vector2i(24, 18), Vector2i(9, 6), SHELL_LIT)
    _rect(image, origin, Rect2i(18, 19, 12, 5), OPTIC)
    _rect(image, origin, Rect2i(21, 20, 6, 2), OPTIC_LIT)
    _rect(image, origin, Rect2i(31, 28, 7, 4), HAZARD)


func _draw_skitter(image: Image, origin: Vector2i) -> void:
    for pair in [
        [Vector2i(17, 22), Vector2i(5, 9)],
        [Vector2i(15, 26), Vector2i(3, 24)],
        [Vector2i(17, 30), Vector2i(7, 42)],
        [Vector2i(31, 22), Vector2i(43, 9)],
        [Vector2i(33, 26), Vector2i(45, 24)],
        [Vector2i(31, 30), Vector2i(41, 42)],
    ]:
        _line(image, origin, pair[0], pair[1], 3, JOINT)
        _circle(image, origin, pair[1], 2, SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 26), Vector2i(12, 8), SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 23), Vector2i(10, 7), SHELL)
    _rect(image, origin, Rect2i(17, 21, 14, 5), OPTIC)
    _rect(image, origin, Rect2i(21, 22, 6, 2), OPTIC_LIT)
    _rect(image, origin, Rect2i(21, 31, 6, 3), CYAN)


func _draw_elite(image: Image, origin: Vector2i) -> void:
    _line(image, origin, Vector2i(17, 34), Vector2i(13, 44), 6, JOINT)
    _line(image, origin, Vector2i(31, 34), Vector2i(35, 44), 6, JOINT)
    _ellipse(image, origin, Vector2i(24, 26), Vector2i(16, 14), SHELL_DARK)
    _ellipse(image, origin, Vector2i(24, 23), Vector2i(14, 12), SHELL_LIT)
    _line(image, origin, Vector2i(15, 14), Vector2i(12, 5), 4, SHELL_LIT)
    _line(image, origin, Vector2i(24, 12), Vector2i(24, 2), 5, SHELL_LIT)
    _line(image, origin, Vector2i(33, 14), Vector2i(36, 5), 4, SHELL_LIT)
    _circle(image, origin, Vector2i(12, 5), 2, HAZARD)
    _circle(image, origin, Vector2i(24, 2), 2, HAZARD)
    _circle(image, origin, Vector2i(36, 5), 2, HAZARD)
    _rect(image, origin, Rect2i(16, 20, 16, 6), OPTIC)
    _rect(image, origin, Rect2i(20, 21, 8, 3), OPTIC_LIT)
    _rect(image, origin, Rect2i(9, 25, 7, 7), SHELL)
    _rect(image, origin, Rect2i(32, 25, 7, 7), SHELL)
    _circle(image, origin, Vector2i(24, 32), 3, CYAN)


func _rect(image: Image, origin: Vector2i, rect: Rect2i, color: Color) -> void:
    for y in range(maxi(0, rect.position.y), mini(FRAME_SIZE, rect.end.y)):
        for x in range(maxi(0, rect.position.x), mini(FRAME_SIZE, rect.end.x)):
            image.set_pixel(origin.x + x, origin.y + y, color)


func _circle(image: Image, origin: Vector2i, center: Vector2i, radius: int, color: Color) -> void:
    var radius_squared := radius * radius
    for y in range(center.y - radius, center.y + radius + 1):
        for x in range(center.x - radius, center.x + radius + 1):
            if x < 0 or y < 0 or x >= FRAME_SIZE or y >= FRAME_SIZE:
                continue
            var dx := x - center.x
            var dy := y - center.y
            if dx * dx + dy * dy <= radius_squared:
                image.set_pixel(origin.x + x, origin.y + y, color)


func _ellipse(image: Image, origin: Vector2i, center: Vector2i, radius: Vector2i, color: Color) -> void:
    for y in range(center.y - radius.y, center.y + radius.y + 1):
        for x in range(center.x - radius.x, center.x + radius.x + 1):
            if x < 0 or y < 0 or x >= FRAME_SIZE or y >= FRAME_SIZE:
                continue
            var nx: float = float(x - center.x) / maxf(1.0, float(radius.x))
            var ny: float = float(y - center.y) / maxf(1.0, float(radius.y))
            if nx * nx + ny * ny <= 1.0:
                image.set_pixel(origin.x + x, origin.y + y, color)


func _line(image: Image, origin: Vector2i, start: Vector2i, finish: Vector2i, width: int, color: Color) -> void:
    var delta := finish - start
    var steps := maxi(absi(delta.x), absi(delta.y))
    if steps <= 0:
        _circle(image, origin, start, maxi(1, width / 2), color)
        return
    for step in range(steps + 1):
        var point := Vector2(start).lerp(Vector2(finish), float(step) / float(steps))
        _circle(image, origin, Vector2i(roundi(point.x), roundi(point.y)), maxi(1, width / 2), color)


func _glow_circle(image: Image, origin: Vector2i, center: Vector2i, radius: int, color: Color) -> void:
    var radius_float := float(radius)
    var radius_squared := radius * radius
    for y in range(maxi(0, center.y - radius), mini(FRAME_SIZE, center.y + radius + 1)):
        for x in range(maxi(0, center.x - radius), mini(FRAME_SIZE, center.x + radius + 1)):
            var pixel_position := origin + Vector2i(x, y)
            if image.get_pixelv(pixel_position).a > 0.0:
                continue
            var dx := x - center.x
            var dy := y - center.y
            var distance_squared := dx * dx + dy * dy
            if distance_squared > radius_squared:
                continue
            var falloff := 1.0 - sqrt(float(distance_squared)) / radius_float
            var alpha := color.a * falloff * falloff
            if alpha > 0.002:
                image.set_pixelv(pixel_position, Color(color.r, color.g, color.b, alpha))


# Wrap every opaque cluster in a dark one-pixel border so silhouettes remain
# readable against the industrial floor at gameplay scale.
func _outline_frame(image: Image, origin: Vector2i) -> void:
    var pending: Array[Vector2i] = []
    for y in range(FRAME_SIZE):
        for x in range(FRAME_SIZE):
            if image.get_pixel(origin.x + x, origin.y + y).a > 0.0:
                continue
            if _has_opaque_neighbour(image, origin, x, y):
                pending.append(Vector2i(x, y))
    for point in pending:
        image.set_pixel(origin.x + point.x, origin.y + point.y, OUTLINE)


func _has_opaque_neighbour(image: Image, origin: Vector2i, x: int, y: int) -> bool:
    for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var nx: int = x + int(offset.x)
        var ny: int = y + int(offset.y)
        if nx < 0 or ny < 0 or nx >= FRAME_SIZE or ny >= FRAME_SIZE:
            continue
        if image.get_pixel(origin.x + nx, origin.y + ny).a > 0.0:
            return true
    return false
