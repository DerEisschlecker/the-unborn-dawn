# Purpose: Owns three JSON save slots under user://saves.
# Public API: save_game(), load_game(), slot_info(), delete_slot().
# Dependencies: GameState, InventorySystem, TimeSystem, WaveManager.
extends Node

const SAVE_DIRECTORY := "user://saves"
const SLOT_COUNT := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))


func _slot_path(slot: int) -> String:
	return "%s/savegame_%02d.json" % [SAVE_DIRECTORY, clampi(slot, 1, SLOT_COUNT)]


func save_game(slot: int = 1, autosave: bool = false) -> bool:
	if not GameState.game_active:
		return false
	var payload := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(),
		"autosave": autosave,
		"game_state": GameState.serialize(),
		"time": TimeSystem.serialize(),
		"inventory": InventorySystem.serialize(),
		"waves": WaveManager.serialize()
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		EventBus.post_message("Speichern fehlgeschlagen.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	EventBus.save_completed.emit(slot)
	if not autosave:
		EventBus.post_message("Spielstand %d gespeichert." % slot)
	return true


func load_game(slot: int = 1) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		EventBus.post_message("Dieser Speicherplatz ist leer.")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		EventBus.post_message("Der Spielstand konnte nicht gelesen werden.")
		return false
	var payload: Dictionary = parsed
	GameState.restore(payload.get("game_state", {}))
	TimeSystem.restore(payload.get("time", {}))
	InventorySystem.restore(payload.get("inventory", {}))
	WaveManager.restore(payload.get("waves", {}))
	GameState.game_active = true
	EventBus.post_message("Spielstand %d geladen." % slot)
	return true


func slot_info(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false, "slot": slot}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"exists": false, "slot": slot}
	var payload: Dictionary = parsed
	var time_data: Dictionary = payload.get("time", {})
	return {
		"exists": true,
		"slot": slot,
		"day": int(time_data.get("current_day", 1)),
		"saved_at": str(payload.get("saved_at", "unbekannt"))
	}


func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
