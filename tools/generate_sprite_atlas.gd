extends SceneTree

# Regenerates assets/robots.png, the enemy sprite atlas.
#
# Run with:
#   .tools/godot/Godot_v4.7.1-stable_linux.x86_64 --headless --path . \
#       --script tools/generate_sprite_atlas.gd
#
# The atlas is committed, so this only runs when a frame changes. Frames are
# laid out left-to-right, top-to-bottom: frame N sits at column N % COLUMNS,
# row N / COLUMNS. GameConfig mirrors these dimensions -- keep them in sync or
# the UV rects will sample the wrong cell.

const FRAME_SIZE := 32
const COLUMNS := 4
const ROWS := 2
const FRAME_COUNT := COLUMNS * ROWS

const OUTLINE := Color(0.07, 0.08, 0.11, 1.0)
const SHELL := Color(0.58, 0.63, 0.72, 1.0)
const SHELL_LIT := Color(0.83, 0.87, 0.94, 1.0)
const SHELL_DARK := Color(0.34, 0.37, 0.45, 1.0)
const VISOR := Color(0.97, 0.25, 0.29, 1.0)
const VISOR_LIT := Color(1.0, 0.66, 0.42, 1.0)


func _init() -> void:
	var image := Image.create(FRAME_SIZE * COLUMNS, FRAME_SIZE * ROWS, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for frame_index in range(FRAME_COUNT):
		@warning_ignore("integer_division")
		var row := frame_index / COLUMNS
		var origin := Vector2i((frame_index % COLUMNS) * FRAME_SIZE, row * FRAME_SIZE)
		for part in _frame_parts(frame_index):
			_fill(image, origin, part[0], part[1])
		_outline_frame(image, origin)

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


func _fill(image: Image, origin: Vector2i, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		if y < 0 or y >= FRAME_SIZE:
			continue
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or x >= FRAME_SIZE:
				continue
			image.set_pixel(origin.x + x, origin.y + y, color)


# Wraps every opaque cluster in a one-pixel dark border so silhouettes stay
# readable against the dark arena at small sizes.
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
	var neighbours: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for offset in neighbours:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx < 0 or ny < 0 or nx >= FRAME_SIZE or ny >= FRAME_SIZE:
			continue
		if image.get_pixel(origin.x + nx, origin.y + ny).a > 0.0:
			return true
	return false


# Each entry is [Rect2i, Color], painted in order. Frames read as chassis
# archetypes so enemy variants can map onto them.
func _frame_parts(frame_index: int) -> Array:
	match frame_index:
		0:  # Grunt: boxy tracked chassis.
			return [
				[Rect2i(15, 3, 2, 4), SHELL_DARK],
				[Rect2i(11, 6, 10, 6), SHELL_LIT],
				[Rect2i(13, 8, 6, 2), VISOR],
				[Rect2i(8, 12, 16, 11), SHELL],
				[Rect2i(11, 15, 10, 3), SHELL_DARK],
				[Rect2i(5, 23, 8, 5), SHELL_DARK],
				[Rect2i(19, 23, 8, 5), SHELL_DARK],
			]
		1:  # Swarmer: small core on spindly legs.
			return [
				[Rect2i(13, 8, 6, 3), SHELL_LIT],
				[Rect2i(11, 11, 10, 10), SHELL],
				[Rect2i(13, 14, 6, 3), VISOR],
				[Rect2i(7, 21, 3, 7), SHELL_DARK],
				[Rect2i(13, 21, 2, 7), SHELL_DARK],
				[Rect2i(17, 21, 2, 7), SHELL_DARK],
				[Rect2i(22, 21, 3, 7), SHELL_DARK],
			]
		2:  # Shielded: bulk behind a bolted plate.
			return [
				[Rect2i(9, 9, 14, 15), SHELL],
				[Rect2i(13, 12, 8, 3), VISOR],
				[Rect2i(6, 6, 6, 20), SHELL_LIT],
				[Rect2i(7, 10, 3, 3), SHELL_DARK],
				[Rect2i(7, 19, 3, 3), SHELL_DARK],
				[Rect2i(10, 24, 5, 4), SHELL_DARK],
				[Rect2i(18, 24, 5, 4), SHELL_DARK],
			]
		3:  # Ranged: side-mounted barrel.
			return [
				[Rect2i(10, 6, 8, 5), SHELL_LIT],
				[Rect2i(12, 8, 4, 2), VISOR],
				[Rect2i(8, 11, 12, 13), SHELL],
				[Rect2i(20, 13, 8, 4), SHELL_DARK],
				[Rect2i(28, 13, 2, 4), VISOR_LIT],
				[Rect2i(9, 24, 5, 4), SHELL_DARK],
				[Rect2i(15, 24, 5, 4), SHELL_DARK],
			]
		4:  # Splitter: seamed shell, twin optics.
			return [
				[Rect2i(8, 8, 16, 16), SHELL],
				[Rect2i(10, 12, 4, 3), VISOR],
				[Rect2i(18, 12, 4, 3), VISOR],
				[Rect2i(15, 8, 1, 14), OUTLINE],
				[Rect2i(8, 24, 16, 2), SHELL_DARK],
				[Rect2i(9, 26, 5, 2), SHELL_DARK],
				[Rect2i(18, 26, 5, 2), SHELL_DARK],
			]
		5:  # Heavy: shouldered brawler.
			return [
				[Rect2i(13, 4, 6, 4), SHELL_DARK],
				[Rect2i(4, 9, 6, 9), SHELL_LIT],
				[Rect2i(22, 9, 6, 9), SHELL_LIT],
				[Rect2i(9, 8, 14, 17), SHELL],
				[Rect2i(12, 12, 8, 3), VISOR],
				[Rect2i(9, 25, 5, 3), SHELL_DARK],
				[Rect2i(18, 25, 5, 3), SHELL_DARK],
			]
		6:  # Skitter: low core with splayed struts.
			return [
				[Rect2i(5, 9, 3, 3), SHELL_DARK],
				[Rect2i(8, 12, 3, 3), SHELL_DARK],
				[Rect2i(24, 9, 3, 3), SHELL_DARK],
				[Rect2i(21, 12, 3, 3), SHELL_DARK],
				[Rect2i(6, 21, 3, 3), SHELL_DARK],
				[Rect2i(9, 18, 3, 3), SHELL_DARK],
				[Rect2i(23, 21, 3, 3), SHELL_DARK],
				[Rect2i(20, 18, 3, 3), SHELL_DARK],
				[Rect2i(11, 12, 10, 8), SHELL],
				[Rect2i(13, 14, 6, 3), VISOR],
			]
		7:  # Elite: crowned, brighter plating.
			return [
				[Rect2i(9, 4, 3, 7), SHELL_LIT],
				[Rect2i(14, 2, 4, 9), SHELL_LIT],
				[Rect2i(20, 4, 3, 7), SHELL_LIT],
				[Rect2i(9, 4, 3, 2), VISOR_LIT],
				[Rect2i(14, 2, 4, 2), VISOR_LIT],
				[Rect2i(20, 4, 3, 2), VISOR_LIT],
				[Rect2i(9, 10, 14, 14), SHELL_LIT],
				[Rect2i(12, 13, 8, 3), VISOR],
				[Rect2i(11, 18, 10, 2), SHELL_DARK],
				[Rect2i(9, 24, 5, 4), SHELL_DARK],
				[Rect2i(18, 24, 5, 4), SHELL_DARK],
			]
		_:
			return []
