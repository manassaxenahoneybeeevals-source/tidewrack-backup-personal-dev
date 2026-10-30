extends Node
## Journal — discovered-logs system. Autoloaded as `Journal`.
##
## Entries live in `GameState.journal` so they are saved and loaded with the
## story flags; this node is the gameplay-facing API. Dialogue graphs add
## entries with a "journal" hook on a node or choice (see DialogueManager).
## Reader UI is still to come.

signal entry_added(id: String)


## Record a discovered log. No-op for empty ids and repeats.
func discover(id: String) -> void:
	if id.is_empty() or id in GameState.journal:
		return
	GameState.journal.append(id)
	GameState.state_changed.emit()
	entry_added.emit(id)


func entries() -> Array[String]:
	return GameState.journal.duplicate()


func has(id: String) -> bool:
	return id in GameState.journal
