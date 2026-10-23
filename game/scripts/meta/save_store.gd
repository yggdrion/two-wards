class_name SaveStore
## Local JSON saves, one file per profile, with a version field.
##
## Loading runs every migration from the file's version up to VERSION, one step at a time, so
## an old save always goes through the same chain. A save from a newer game is not loaded.

const VERSION := 3
const DIR := "user://profiles"


static func path_for(profile_name: String) -> String:
	return DIR.path_join("%s.json" % profile_name)


## Writes the profile to a temp file first and then renames it, so a crash mid-write never
## leaves a half-written save behind.
static func save(profile: Profile, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var data := profile.to_dict()
	data["version"] = VERSION
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(temp, path)


## The saved profile, or null if the file is missing, unreadable or from a newer version.
static func load_profile(path: String) -> Profile:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	var migrated := migrate(data)
	if migrated.is_empty():
		return null
	return Profile.from_dict(migrated)


## Loads the profile at path, or creates and saves a new one. A file that exists but can't be
## loaded is kept next to it as .bak instead of being overwritten.
static func load_or_create(path: String, profile_name: String = "default") -> Profile:
	var profile := load_profile(path)
	if profile == null:
		if FileAccess.file_exists(path):
			DirAccess.rename_absolute(path, path + ".bak")
		profile = Profile.create(profile_name)
		save(profile, path)
	return profile


## Brings save data up to VERSION. Returns {} for data from a newer version.
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > VERSION:
		return {}
	var result := data.duplicate(true)
	while version < VERSION:
		result = _migrations()[version].call(result)
		version += 1
		result["version"] = version
	return result


## Step i turns version i into version i + 1.
static func _migrations() -> Array[Callable]:
	return [_v0_to_v1, _v1_to_v2, _v2_to_v3]


## Version 0 (pre-release) kept owned cards as a flat id list and had no decks or pity counter.
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	var collection := {}
	for card_id: Variant in data.get("cards", []):
		collection[str(card_id)] = int(collection.get(str(card_id), 0)) + 1
	var starter := Profile.create(str(data.get("name", "default")))
	return {
		"name": starter.profile_name,
		"gold": int(data.get("gold", 0)),
		"collection": collection,
		"decks": starter.decks,
		"active_deck": 0,
		"boosters_since_epic": 0,
	}


## Version 2 (M3b) adds the chosen wizard and replaces the Blink card with Empower: owned
## Blink copies become Empower copies, in the collection and in every deck.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result["hero"] = Profile.DEFAULT_HERO
	var collection: Dictionary = result.get("collection", {})
	if collection.has("blink"):
		collection["empower"] = int(collection.get("empower", 0)) + int(collection["blink"])
		collection.erase("blink")
	for deck: Dictionary in result.get("decks", []):
		var cards: Array = deck.get("cards", [])
		for i in cards.size():
			if str(cards[i]) == "blink":
				cards[i] = "empower"
	return result


## Version 3 (M4) adds the player name shown to the co-op partner; empty means "not set yet".
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result["player_name"] = ""
	return result
