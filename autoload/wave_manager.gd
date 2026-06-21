# Purpose: Schedules and describes escalating defense waves from day 7 through the finale.
# Public API: is_wave_day(), prepare_wave(), current_wave(), complete_wave(), reset_waves().
# Dependencies: DataCatalog, TimeSystem, GameState, and EventBus.
extends Node

var pending_wave := false
var pending_day := 0


func reset_waves() -> void:
	pending_wave = false
	pending_day = 0


func is_wave_day(day: int) -> bool:
	var config := DataCatalog.wave_config()
	if day == GameState.MAX_DAY:
		return true
	var first_day := int(config.get("first_day", 7))
	var interval := int(config.get("interval", 7))
	return day >= first_day and (day - first_day) % interval == 0


func prepare_wave(day: int) -> void:
	pending_wave = true
	pending_day = day


func current_wave() -> Dictionary:
	var day := pending_day if pending_day > 0 else TimeSystem.current_day
	var config := DataCatalog.wave_config()
	var tier := 1 + int(float(day) / float(config.get("tier_days", 45)))
	var enemy_count := int(config.get("base_count", 3)) + int(float(day) / float(config.get("count_growth_days", 20)))
	if day == GameState.MAX_DAY:
		enemy_count += int(config.get("finale_bonus", 14))
		tier += 3
	return {
		"day": day,
		"tier": tier,
		"enemy_count": enemy_count,
		"enemy_health": 18 + tier * 8,
		"enemy_damage": 5 + tier * 2,
		"title": "THE LONGEST NIGHT" if day == GameState.MAX_DAY else "Angriff in der Nacht"
	}


func complete_wave() -> void:
	pending_wave = false
	GameState.run_statistics.waves_survived = int(GameState.run_statistics.waves_survived) + 1


func serialize() -> Dictionary:
	return {"pending_wave": pending_wave, "pending_day": pending_day}


func restore(data: Dictionary) -> void:
	pending_wave = bool(data.get("pending_wave", false))
	pending_day = int(data.get("pending_day", 0))
