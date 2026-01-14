extends Node
class_name TextureManager

# TextureManager centralizes loading of floor textures and provides a
# selection API prepared for weighted randomness in the future.
#
# IMPORTANT: To make sure everything works in exported builds, we avoid
# relying on DirAccess to scan folders at runtime and instead reference
# floor textures explicitly with `preload`. This guarantees that Godot's
# exporter includes these PNG files inside the .pck.

const FLOOR_DIR := "res://assets/floor/"

# Explicit references so the exporter always includes these textures.
const FLOOR_TILE_MAIN: Texture2D = preload("res://assets/floor/tile.png")
const FLOOR_TILE_2: Texture2D = preload("res://assets/floor/tile 2.png")
const FLOOR_TILE_3: Texture2D = preload("res://assets/floor/tile 3.png")
const FLOOR_TILE_4: Texture2D = preload("res://assets/floor/tile 4.png")

static var floor_textures: Array = []

static func init(force: bool = false) -> void:
	# Initialize or re-initialize textures for the floor.
	# If `force` is true, clear any existing cached textures and rebuild the list.
	if force:
		floor_textures.clear()

	# Avoid re-initializing when already loaded (unless forced)
	if floor_textures.size() > 0:
		return

	# Build the weighted list using explicitly preloaded textures.
	# Policy:
	# - tile.png => 90%
	# - Others share remaining 10%
	var entries: Array = []
	if FLOOR_TILE_MAIN:
		entries.append({"texture": FLOOR_TILE_MAIN, "weight": 0.9, "file": "tile.png"})

	var secondary: Array = []
	if FLOOR_TILE_2:
		secondary.append({"texture": FLOOR_TILE_2, "weight": 0.0, "file": "tile 2.png"})
	if FLOOR_TILE_3:
		secondary.append({"texture": FLOOR_TILE_3, "weight": 0.0, "file": "tile 3.png"})
	if FLOOR_TILE_4:
		secondary.append({"texture": FLOOR_TILE_4, "weight": 0.0, "file": "tile 4.png"})

	if secondary.size() > 0:
		var share: float = 0.1 / float(secondary.size())
		for i in range(secondary.size()):
			var entry: Dictionary = secondary[i]
			entry["weight"] = share
			secondary[i] = entry
		entries.append_array(secondary)

	floor_textures = entries

	# If nothing was created (e.g. all textures missing), create a
	# procedural fallback ImageTexture so rendering doesn't break.
	if floor_textures.size() == 0:
		var img := Image.new()
		img.create(IsometricUtils.TILE_WIDTH, IsometricUtils.TILE_HEIGHT, false, Image.FORMAT_RGBA8)
		# Simple neutral checker-ish pattern so tiles are visibly textured
		for x in range(IsometricUtils.TILE_WIDTH):
			for y in range(IsometricUtils.TILE_HEIGHT):
				var shade = 0.8 if ((x / 8 + y / 8) % 2) == 0 else 0.85
				img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
		var tex := ImageTexture.create_from_image(img)
		floor_textures.append({"texture": tex, "weight": 1.0, "file": "procedural"})

# Helper to force reload textures at runtime after adding images to the folder
static func reload() -> void:
	init(true)

# RNG used for weighted selection
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Returns the selected floor texture using weighted random selection.
# Weights are defined per-entry in `floor_textures[i]["weight"]` and sum to ~1.0.
static func get_floor_texture() -> Texture2D:
	init()
	if floor_textures.size() == 0:
		return null

	# Sum weights (safety in case of floating point rounding)
	var total: float = 0.0
	for i in range(floor_textures.size()):
		var entry: Dictionary = floor_textures[i] as Dictionary
		total += float(entry["weight"])
	if total <= 0.0:
		# Fallback deterministic choice
		return floor_textures[0]["texture"]

	rng.randomize()
	var r: float = rng.randf() * total
	var cum: float = 0.0
	for i in range(floor_textures.size()):
		var entry: Dictionary = floor_textures[i] as Dictionary
		cum += float(entry["weight"])
		if r <= cum:
			return entry["texture"]

	# Fallback: return last texture
	return floor_textures[floor_textures.size() - 1]["texture"]


# Deterministic per-tile selection
# Returns a texture chosen based on tile grid coordinates. Selection is deterministic
# (same result for the same coordinates) so textures won't change each frame.
static func get_floor_texture_for_position(tile_pos: Vector2) -> Texture2D:
	init()
	if floor_textures.size() == 0:
		return null

	# Create a local RNG seeded from the tile coordinates to ensure deterministic picks
	var seed: int = int(tile_pos.x) * 73856093 ^ int(tile_pos.y) * 19349663
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed

	# Sum weights
	var total: float = 0.0
	for i in range(floor_textures.size()):
		var entry: Dictionary = floor_textures[i] as Dictionary
		total += float(entry["weight"])
	if total <= 0.0:
		return floor_textures[0]["texture"]

	var r: float = local_rng.randf() * total
	var cum: float = 0.0
	for i in range(floor_textures.size()):
		var entry: Dictionary = floor_textures[i] as Dictionary
		cum += float(entry["weight"])
		if r <= cum:
			return entry["texture"]

	return floor_textures[floor_textures.size() - 1]["texture"]
