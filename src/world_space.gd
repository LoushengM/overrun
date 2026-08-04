class_name WorldSpace
extends RefCounted

# Toroidal world helpers.
#
# The arena is a torus: leaving one edge re-enters the opposite edge. Every
# distance, targeting, and collision query must therefore use the *shortest*
# separation between two points, which may wrap around an edge rather than
# travel across the middle of the map.
#
# These are static so hot loops can call them without an instance lookup, and
# they deliberately avoid allocation.

const SIZE := GameConfig.WORLD_SIZE
const HALF_SIZE := GameConfig.WORLD_HALF_SIZE


# Wrap a world position back into [0, SIZE) on both axes.
static func wrap_position(position: Vector2) -> Vector2:
	return Vector2(fposmod(position.x, SIZE), fposmod(position.y, SIZE))


# Shortest vector from `from` to `to` across the torus. Each component lands in
# [-HALF_SIZE, HALF_SIZE].
static func delta(from: Vector2, to: Vector2) -> Vector2:
	var dx := fposmod(to.x - from.x + HALF_SIZE, SIZE) - HALF_SIZE
	var dy := fposmod(to.y - from.y + HALF_SIZE, SIZE) - HALF_SIZE
	return Vector2(dx, dy)


static func distance_squared(from: Vector2, to: Vector2) -> float:
	return delta(from, to).length_squared()


static func distance(from: Vector2, to: Vector2) -> float:
	return delta(from, to).length()


# Unit vector pointing from `from` toward `to` along the shortest wrapped path.
static func direction(from: Vector2, to: Vector2) -> Vector2:
	var offset := delta(from, to)
	var length := offset.length()
	if length <= 0.00001:
		return Vector2.ZERO
	return offset / length


# Position of `target` expressed near `reference` instead of inside the base
# world rectangle. Rendering and collision use this so an entity one cell over
# the seam draws and collides beside the viewer rather than a world away.
static func nearest_image(reference: Vector2, target: Vector2) -> Vector2:
	return reference + delta(reference, target)
