# Purpose: Broadcast projected stat values to the HUD when hovering actions or travel targets.
# Public API: set_projected(), apply_deltas(), clear().
# Dependencies: GameState, EventBus.
class_name HudStatPreviewNode
extends Node

const HUD_STATS := ["health", "hunger", "stamina", "thirst", "energy", "shield"]


func set_projected(projected: Dictionary) -> void:
	var filtered: Dictionary = {}
	for stat_name in projected:
		var key: String = str(stat_name)
		if key in HUD_STATS:
			filtered[key] = float(projected[stat_name])
	if filtered.is_empty():
		clear()
		return
	EventBus.stat_preview_changed.emit(filtered)


func clear() -> void:
	EventBus.stat_preview_cleared.emit()


func apply_deltas(deltas: Dictionary) -> void:
	var projected: Dictionary = {}
	for stat_name in deltas:
		var key: String = str(stat_name)
		if key not in HUD_STATS:
			continue
		projected[key] = _clamp_stat(key, _current(key) + float(deltas[stat_name]))
	set_projected(projected)


func _current(stat_name: String) -> float:
	return float(GameState.player_stats.get(stat_name, 0.0))


func _clamp_stat(stat_name: String, value: float) -> float:
	var maximum: float = GameState.max_resource(stat_name) if stat_name in ["health", "stamina", "energy"] else float(GameState.player_stats.get("max_" + stat_name, 100.0))
	return clampf(value, 0.0, maximum)
