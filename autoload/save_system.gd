# Purpose: Owns three JSON save slots under user://saves plus autosave.
# Public API: save_game(), load_game(), load_latest_save(), slot_info(), delete_slot().
# Dependencies: GameState, InventorySystem, TimeSystem, WaveManager.
extends Node

const SAVE_DIRECTORY := "user://saves"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const SLOT_COUNT := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))


func _slot_path(slot: int) -> String:
	return "%s/savegame_%02d.json" % [SAVE_DIRECTORY, clampi(slot, 1, SLOT_COUNT)]


func _build_payload(autosave: bool) -> Dictionary:
	return {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(),
		"autosave": autosave,
		"game_state": GameState.serialize(),
		"time": TimeSystem.serialize(),
		"inventory": InventorySystem.serialize(),
		"waves": WaveManager.serialize()
	}


func _write_payload(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		EventBus.post_message("Speichern fehlgeschlagen.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func save_autosave() -> bool:
	if not GameState.game_active:
		return false
	if not _write_payload(AUTOSAVE_PATH, _build_payload(true)):
		return false
	EventBus.save_completed.emit(0)
	return true


func save_game(slot: int = 1, autosave: bool = false) -> bool:
	if not GameState.game_active:
		return false
	if autosave:
		return save_autosave()
	var payload := _build_payload(false)
	if not _write_payload(_slot_path(slot), payload):
		return false
	EventBus.save_completed.emit(slot)
	EventBus.post_message("Spielstand %d gespeichert." % slot)
	return true


func load_game(slot: int = 1) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		EventBus.post_message("Dieser Speicherplatz ist leer.")
		return false
	return _load_payload_path(path, "Spielstand %d geladen." % slot)


func load_autosave() -> bool:
	if not FileAccess.file_exists(AUTOSAVE_PATH):
		EventBus.post_message("Kein Autosave vorhanden.")
		return false
	return _load_payload_path(AUTOSAVE_PATH, "Autosave geladen.")


func any_save_exists() -> bool:
	return bool(latest_save_info().get("exists", false))


func latest_save_info() -> Dictionary:
	var best: Dictionary = {"exists": false, "saved_at": ""}
	var autosave := autosave_info()
	if autosave.get("exists", false):
		best = autosave
	for slot in range(1, SLOT_COUNT + 1):
		var info := slot_info(slot)
		if not info.get("exists", false):
			continue
		if not bool(best.get("exists", false)) or str(info.get("saved_at", "")) > str(best.get("saved_at", "")):
			best = info
	return best


func load_latest_save() -> bool:
	var info := latest_save_info()
	if not info.get("exists", false):
		EventBus.post_message("Kein Spielstand vorhanden.")
		return false
	var path: String = str(info.get("path", ""))
	var slot: int = int(info.get("slot", 0))
	var message: String = "Letzter Spielstand geladen."
	if slot > 0:
		message = "Spielstand %d geladen." % slot
	elif bool(info.get("autosave", false)):
		message = "Autosave geladen."
	return _load_payload_path(path, message)


func _load_payload_path(path: String, success_message: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		EventBus.post_message("Der Spielstand konnte nicht gelesen werden.")
		return false
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
	EventBus.post_message(success_message)
	return true


func autosave_info() -> Dictionary:
	var info := _payload_info(AUTOSAVE_PATH, 0)
	if info.get("exists", false):
		info["autosave"] = true
	return info


func slot_info(slot: int) -> Dictionary:
	var info := _payload_info(_slot_path(slot), slot)
	if info.get("exists", false):
		return info
	return {"exists": false, "slot": slot}


func _payload_info(path: String, slot: int = 0) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"exists": false}
	var payload: Dictionary = parsed
	var time_data: Dictionary = payload.get("time", {})
	return {
		"exists": true,
		"path": path,
		"slot": slot,
		"day": int(time_data.get("current_day", 1)),
		"saved_at": str(payload.get("saved_at", "")),
		"autosave": bool(payload.get("autosave", slot == 0))
	}


func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
