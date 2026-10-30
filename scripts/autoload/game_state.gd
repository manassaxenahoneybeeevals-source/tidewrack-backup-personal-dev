extends Node
## GameState — global save/load, story flags, and the discovered-logs journal.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices plus the journal entries the player has discovered, and persists
## both to user://save.json so "Continue" works.
##
## Save versions:
##   v1  { "version": 1, "scene": String, "flags": Dictionary }
##   v2  v1 + { "journal": Array[String] }   # discovery order, no duplicates
## A v1 file loads with an empty journal; flags and scene are untouched.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Journal entry ids in the order they were discovered. Owned here (not in
## Journal) so they ride along in the same save file as the flags.
var journal: Array[String] = []
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	journal.clear()
	current_scene = "res://scenes/game.tscn"
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal": journal,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	current_scene = data.get("scene", "res://scenes/game.tscn")
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	# v1 -> v2: "journal" is simply absent, which yields an empty journal.
	journal = _read_journal(data.get("journal", []))
	state_changed.emit()
	return true


## Accept only non-empty strings, drop duplicates, keep order. Anything else
## in the array (a hand-edited save, a future format) is skipped, not fatal.
func _read_journal(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in (value as Array):
		if typeof(item) == TYPE_STRING and not (item as String).is_empty() and not (item in out):
			out.append(item)
	return out


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
