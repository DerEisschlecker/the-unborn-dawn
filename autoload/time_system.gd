# Purpose: Controls the fixed 260-day campaign clock and 24 hourly rounds per day.
# Public API: reset_time(), advance(), advance_rest(), advance_to_morning(), serialize(), restore().
# Dependencies: EventBus, GameState, WaveManager, SaveSystem.
extends Node

const HOURS_PER_DAY := 24
const WAVE_WARNING_HOUR := 21

var current_day := 1
var phase_index := 0


func reset_time() -> void:
	current_day = 1
	phase_index = 0
	EventBus.time_changed.emit(current_day, current_phase())


func current_phase() -> String:
	var hour := current_hour()
	var label := "Nacht"
	if hour >= 6 and hour < 12:
		label = "Morgen"
	elif hour >= 12 and hour < 18:
		label = "Tag"
	elif hour >= 18 and hour < 22:
		label = "Abend"
	return "%02d:00 - %s" % [hour, label]


func current_hour() -> int:
	return clampi(phase_index, 0, HOURS_PER_DAY - 1)


func is_night() -> bool:
	var hour := current_hour()
	return hour < 6 or hour >= 22


func light_multiplier() -> float:
	var hour := current_hour()
	if hour >= 7 and hour <= 17:
		return 1.0
	if hour == 6 or hour == 18:
		return 0.82
	if hour == 19 or hour == 21:
		return 0.62
	if hour == 20:
		return 0.48
	return 0.36


func scene_light_color() -> Color:
	var light := light_multiplier()
	var warm := 0.10 if current_hour() >= 18 and current_hour() <= 21 else 0.0
	return Color(clampf(light + warm, 0.25, 1.05), clampf(light, 0.24, 1.0), clampf(light + 0.12, 0.32, 1.0), 1.0)


func enemy_strength_multiplier() -> float:
	if is_night():
		return 1.22
	if current_hour() >= 18:
		return 1.10
	if current_hour() < 7:
		return 1.15
	return 1.0


func advance(segments: int = 1, reason: String = "", spend_action_costs: bool = true) -> void:
	for _step in range(maxi(1, segments)):
		if spend_action_costs:
			GameState.spend_for_action(4.0, 3.0)
		_advance_one_hour()
	if not reason.is_empty():
		EventBus.post_message(reason)


func advance_rest(hours: int, reason: String = "") -> void:
	advance(hours, reason, false)


func advance_to_morning() -> void:
	var steps := HOURS_PER_DAY - phase_index
	advance(steps, "Ein neuer Morgen bricht an.")
	GameState.rest_player()


func _apply_daily_changes() -> void:
	GameState.change_stat("hunger", -7.0)
	GameState.change_stat("thirst", -10.0)
	GameState.elena.stress = maxf(0.0, float(GameState.elena.stress) - 4.0)
	if GameState.count_role("sammler") > 0:
		InventorySystem.add_item("wood", GameState.count_role("sammler"))
	if GameState.count_role("arzt") > 0:
		GameState.elena.health = minf(float(GameState.elena.max_health), float(GameState.elena.health) + 4.0)
	_apply_status_effects()


func _apply_status_effects() -> void:
	if GameState.status_effects.has("food_poisoning"):
		GameState.change_stat("health", -5.0)
	if GameState.status_effects.has("infected_wound"):
		GameState.change_stat("stamina", -8.0)
	if GameState.status_effects.has("demonic_taint"):
		GameState.change_stat("health", -3.0)
	if GameState.status_effects.has("well_fed"):
		GameState.change_stat("stamina", 8.0)
		GameState.status_effects.erase("well_fed")
	if GameState.status_effects.has("well_rested"):
		GameState.change_stat("energy", 6.0)
		GameState.status_effects.erase("well_rested")
	if float(GameState.elena.stress) >= 85.0:
		GameState.elena.health = maxf(1.0, float(GameState.elena.health) - 3.0)
		EventBus.post_message("Elenas hoher Stress verursacht Komplikationen.")


func _check_story_day() -> void:
	if current_day >= 60 and not GameState.story_flags.get("act_2", false):
		GameState.story_flags.act_2 = true
		EventBus.story_due.emit("act_2")
	elif current_day >= 180 and not GameState.story_flags.get("act_3", false):
		GameState.story_flags.act_3 = true
		EventBus.story_due.emit("act_3")


func _advance_one_hour() -> void:
	phase_index += 1
	if phase_index >= HOURS_PER_DAY:
		phase_index = 0
		if current_day < GameState.MAX_DAY:
			current_day += 1
		_apply_daily_changes()
		if current_day >= GameState.MAX_DAY - 10 and current_day < GameState.MAX_DAY:
			EventBus.post_message("Nur noch %d Tage bis zur laengsten Nacht." % (GameState.MAX_DAY - current_day))
		if current_day >= GameState.MAX_DAY:
			EventBus.post_message("Tag 260. Heute Nacht entscheidet alles.")
		if GameState.game_active:
			SaveSystem.save_autosave()
		_check_story_day()
	if phase_index == WAVE_WARNING_HOUR and WaveManager.is_wave_day(current_day):
		WaveManager.prepare_wave(current_day)
		EventBus.wave_due.emit(current_day)
	EventBus.time_changed.emit(current_day, current_phase())


func serialize() -> Dictionary:
	return {"current_day": current_day, "phase_index": phase_index}


func restore(data: Dictionary) -> void:
	current_day = clampi(int(data.get("current_day", 1)), 1, GameState.MAX_DAY)
	phase_index = clampi(int(data.get("phase_index", 0)), 0, HOURS_PER_DAY - 1)
	EventBus.time_changed.emit(current_day, current_phase())
