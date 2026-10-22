extends SceneTree
## Builds SpriteFrames and TileSet resources from the PNGs listed in res://assets/manifest.json.
## Run headless after an import: tools/build_assets.sh (or .ps1). Output goes to
## res://resources/generated/ and is committed; CI reruns this and fails on any diff.

const MANIFEST_PATH := "res://assets/manifest.json"
const OUT_DIR := "res://resources/generated"
const UNIT_FRAME := 32
const TILE_SIZE := Vector2i(16, 16)


func _initialize() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if manifest == null:
		push_error("Cannot parse %s" % MANIFEST_PATH)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var failed := false
	for entry: Dictionary in manifest["assets"]:
		if entry["status"] == "todo":
			continue
		match entry["type"]:
			"unit":
				failed = (
					not _save(build_sprite_frames(entry), "%s_frames.tres" % entry["id"]) or failed
				)
			"tileset":
				failed = not _save(build_tile_set(entry), "%s.tres" % entry["id"]) or failed
	quit(1 if failed else 0)


## One animation per anim and direction, named "<anim>_<dir>" (e.g. "walk_side").
## Left-facing sprites come from flip_h on "side".
static func build_sprite_frames(entry: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var unit_name: String = entry["id"].trim_prefix("unit_")
	for anim: String in entry["anims"]:
		var spec: Dictionary = entry["anims"][anim]
		for dir: String in entry["dirs"]:
			var anim_name := "%s_%s" % [anim, dir]
			var texture: Texture2D = load(
				"res://assets/units/%s/%s_%s.png" % [unit_name, entry["id"], anim_name]
			)
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, spec["fps"])
			frames.set_animation_loop(anim_name, spec["loop"])
			for i in int(spec["frames"]):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(i * UNIT_FRAME, 0, UNIT_FRAME, UNIT_FRAME)
				# Fixed ids keep the saved .tres byte-identical between runs.
				atlas.resource_scene_unique_id = "%s_%d" % [anim_name, i]
				frames.add_frame(anim_name, atlas)
	return frames


## One atlas source per tile file; source id = tile number.
static func build_tile_set(entry: Dictionary) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	var set_name: String = entry["id"].trim_prefix("tile_")
	for n in int(entry["count"]):
		var source := TileSetAtlasSource.new()
		source.texture = load("res://assets/tiles/%s/%s_%02d.png" % [set_name, entry["id"], n])
		source.texture_region_size = TILE_SIZE
		source.create_tile(Vector2i.ZERO)
		source.resource_scene_unique_id = "tile_%02d" % n
		tile_set.add_source(source, n)
	return tile_set


func _save(resource: Resource, file_name: String) -> bool:
	var path := OUT_DIR.path_join(file_name)
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_error("Saving %s failed: %s" % [path, error_string(err)])
		return false
	print("Wrote ", path)
	return true
