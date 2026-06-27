# Purpose: Pick enemies and difficulty scaling from location, player level, and day.
# Public API: pick_enemy(), scale_health(), scale_damage().
extends Object

const ENEMY_TYPES := ["demon_basic", "demon_runner", "demon_brute", "demon_boss"]


static func pick_enemy(location: Dictionary, player_level: int, seed_value: int) -> String:
	var danger := int(location.get("danger", 1))
	var loc_type := str(location.get("type", "Zone"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array[String] = []
	if loc_type == "Dungeon":
		if danger >= 5 or player_level >= 8:
			pool = ["demon_boss", "demon_brute", "demon_brute"]
		elif danger >= 4 or player_level >= 5:
			pool = ["demon_brute", "demon_runner", "demon_brute"]
		else:
			pool = ["demon_runner", "demon_basic", "demon_brute"]
	elif danger >= 4 or player_level >= 6:
		pool = ["demon_brute", "demon_runner", "demon_basic"]
	elif danger >= 3 or player_level >= 3:
		pool = ["demon_runner", "demon_basic", "demon_runner"]
	else:
		pool = ["demon_basic", "demon_runner", "demon_basic"]
	if player_level <= 1:
		pool = ["demon_basic", "demon_basic", "demon_runner"]
	elif player_level >= 10:
		pool.append("demon_boss")
	return pool[rng.randi_range(0, pool.size() - 1)]


static func difficulty_multiplier(location: Dictionary, player_level: int) -> float:
	var danger := int(location.get("danger", 1))
	var level_gap := float(danger - player_level)
	var multiplier := 1.0 + float(maxi(0, player_level - 1)) * 0.06
	if level_gap > 0.0:
		multiplier += level_gap * 0.12
	elif level_gap < -2.0:
		multiplier = maxf(0.72, multiplier + level_gap * 0.04)
	return multiplier


static func scale_health(base_health: float, location: Dictionary, player_level: int, day: int, time_multiplier: float) -> float:
	return (base_health + day * 0.18) * time_multiplier * difficulty_multiplier(location, player_level)


static func scale_damage(base_damage: float, location: Dictionary, player_level: int, day: int, time_multiplier: float) -> float:
	return (base_damage + floorf(float(day) / 45.0)) * time_multiplier * difficulty_multiplier(location, player_level)
