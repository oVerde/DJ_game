extends Node
class_name TextureManager

# TextureManager centralizes loading of floor textures and provides a
# selection API prepared for weighted randomness in the future.
#
# Usage:
# - Call `TextureManager.init()` once at startup (or lazily).
# - Use `TextureManager.get_floor_texture()` to obtain the Texture2D to draw.

const FLOOR_DIR := "res://assets/floor/"
static var floor_textures: Array = []

static func init(force: bool = false) -> void:
	# Initialize or re-initialize textures for the floor.
	# If `force` is true, clear any existing cached textures and reload from disk.
	if force:
		floor_textures.clear()

	# Avoid re-initializing when already loaded (unless forced)
	if floor_textures.size() > 0:
		return

	# Collect available image files from the assets directory
	var files: Array = []
	var dir: DirAccess = DirAccess.open(FLOOR_DIR)
	if dir:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir():
				var ext = fname.get_extension().to_lower()
				if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
					files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()

	# Prefer an explicit tile.png if user provides it
	var ordered_files: Array = []
	if "tile.png" in files:
		ordered_files.append("tile.png")
	# Append remaining files in directory order (excluding tile.png to avoid duplicates)
	for f in files:
		if f != "tile.png":
			ordered_files.append(f)

	# Try to load discovered files into textures (keep filename to compute weights)
	for f in ordered_files:
		# `path` must have an explicit type so GDScript can infer correctly in all versions
		var path: String = FLOOR_DIR + String(f)
		if ResourceLoader.exists(path):
			var loaded: Texture2D = load(path) as Texture2D
			if loaded != null:
				# Store file name to later compute weights; initial weight is placeholder (0.0)
				floor_textures.append({"texture": loaded, "weight": 0.0, "file": String(f)})

	# Compute weights according to policy:
	# - "tile.png" => 90%
	# - Any other files divide the remaining 10% equally
	# The implementation is robust: if some named files are missing, remaining weight is redistributed equally.
	if floor_textures.size() > 0:
		var desired_weights := {"tile.png": 0.9}
		var assigned_sum := 0.0
		# Assign specified weights (case-insensitive matching)
		for i in range(floor_textures.size()):
			var entry: Dictionary = floor_textures[i] as Dictionary
			var fname: String = String(entry.get("file", "")).to_lower()
			if desired_weights.has(fname):
				entry["weight"] = desired_weights[fname]
				assigned_sum += float(entry["weight"])
			floor_textures[i] = entry

		# Distribute remaining weight equally among unassigned entries
		var remaining: float = max(0.0, 1.0 - assigned_sum)
		var unassigned: Array = []
		for i in range(floor_textures.size()):
			var entry: Dictionary = floor_textures[i] as Dictionary
			if float(entry["weight"]) == 0.0:
				unassigned.append(entry)

		if unassigned.size() > 0:
			var share: float = remaining / float(unassigned.size())
			for entry in unassigned:
				entry["weight"] = share
		else:
			# No unassigned entries: normalize weights so they sum to 1.0 (safety)
			if assigned_sum > 0.0 and abs(assigned_sum - 1.0) > 0.0001:
				for entry in floor_textures:
					entry["weight"] = entry["weight"] / assigned_sum

	# If nothing was loaded, create a procedural fallback ImageTexture so rendering doesn't break
	if floor_textures.size() == 0:
		var img := Image.new()
		img.create(IsometricUtils.TILE_WIDTH, IsometricUtils.TILE_HEIGHT, false, Image.FORMAT_RGBA8)
		# Note: Image.lock()/unlock() are not available in this Godot version; set_pixel works without them.
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
