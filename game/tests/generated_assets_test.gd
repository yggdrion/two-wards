extends GdUnitTestSuite
## Checks the committed output of tools/build_assets.gd against res://assets/manifest.json.


func _manifest_entry(id: String) -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/manifest.json")
	)
	for entry: Dictionary in manifest["assets"]:
		if entry["id"] == id:
			return entry
	return {}


func test_hero_sprite_frames_match_manifest() -> void:
	var entry := _manifest_entry("unit_hero")
	var frames: SpriteFrames = load("res://resources/generated/unit_hero_frames.tres")
	for anim: String in entry["anims"]:
		var spec: Dictionary = entry["anims"][anim]
		for dir: String in entry["dirs"]:
			var anim_name := "%s_%s" % [anim, dir]
			assert_bool(frames.has_animation(anim_name)).is_true()
			assert_int(frames.get_frame_count(anim_name)).is_equal(int(spec["frames"]))
			assert_float(frames.get_animation_speed(anim_name)).is_equal(float(spec["fps"]))
			assert_bool(frames.get_animation_loop(anim_name)).is_equal(spec["loop"])
			var frame: AtlasTexture = frames.get_frame_texture(anim_name, 0)
			assert_vector(frame.get_size()).is_equal(Vector2(64, 64))


func test_base_tile_set_has_one_source_per_tile() -> void:
	var tile_set: TileSet = load("res://resources/generated/tile_base.tres")
	assert_int(tile_set.get_source_count()).is_equal(int(_manifest_entry("tile_base")["count"]))
	assert_vector(Vector2(tile_set.tile_size)).is_equal(Vector2(32, 32))
