extends RefCounted

static func enemy_initiative_stats(enemy_data: Dictionary) -> Dictionary:
	return {
		"initiative": float(enemy_data.get("initiative", 0.0)) + float(enemy_data.get("speed", 1.0)) * 2.5,
	}


static func roll_initiative(stats: Dictionary, rng: RandomNumberGenerator = null) -> int:
	var spread := rng.randi_range(-1, 2) if rng != null else randi_range(-1, 2)
	return int(roundf(float(stats.get("initiative", 0.0)))) + spread


static func build_turn_order(
	include_companion: bool,
	companion_alive: bool,
	player_stats: Dictionary,
	companion_stats: Dictionary,
	enemy_data: Dictionary,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var rolls: Array[Dictionary] = []
	rolls.append({"id": "player", "value": roll_initiative(player_stats, rng)})
	if include_companion and companion_alive:
		rolls.append({"id": "companion", "value": roll_initiative(companion_stats, rng)})
	rolls.append({"id": "enemy", "value": roll_initiative(enemy_initiative_stats(enemy_data), rng)})
	rolls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("value", 0)) > int(b.get("value", 0))
	)
	var order: Array[String] = []
	var initiatives: Dictionary = {}
	for entry in rolls:
		var actor_id := str(entry.get("id", ""))
		order.append(actor_id)
		initiatives[actor_id] = int(entry.get("value", 0))
	return {"turn_order": order, "initiatives": initiatives}


static func next_actor(
	turn_order: Array[String],
	turn_order_index: int,
	companion_active: bool,
	companion_hp: float
) -> Dictionary:
	if turn_order.is_empty():
		return {"index": turn_order_index, "actor_id": "", "new_round": false}
	var visited := 0
	var index := turn_order_index
	while visited < turn_order.size():
		index = (index + 1) % turn_order.size()
		visited += 1
		var actor_id := turn_order[index]
		if actor_id == "companion" and (not companion_active or companion_hp <= 0.0):
			continue
		return {"index": index, "actor_id": actor_id, "new_round": index == 0}
	return {"index": turn_order_index, "actor_id": "", "new_round": false}


static func pick_enemy_target(
	companion_active: bool,
	companion_hp: float,
	player_hp: float,
	rng: RandomNumberGenerator = null
) -> String:
	if not companion_active or companion_hp <= 0.0:
		return "player"
	if companion_hp < player_hp:
		return "companion"
	if player_hp < companion_hp:
		return "player"
	var roll := rng.randf() if rng != null else randf()
	return "player" if roll < 0.5 else "companion"


static func simulate_fight(config: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("seed", 1))
	var enemy_data: Dictionary = config.get("enemy", {"initiative": 4.0, "speed": 2})
	var has_companion := bool(config.get("has_companion", false))
	var player_hp := float(config.get("player_hp", 100.0))
	var companion_hp := float(config.get("companion_hp", 80.0))
	var enemy_hp := float(config.get("enemy_hp", 36.0))
	var player_damage := float(config.get("player_damage", 12.0))
	var companion_damage := float(config.get("companion_damage", 9.0))
	var enemy_damage := float(config.get("enemy_damage", 7.0))
	var player_stats: Dictionary = config.get("player_stats", {"initiative": 8.0})
	var companion_stats: Dictionary = config.get("companion_stats", {"initiative": 6.0})
	var built := build_turn_order(
		has_companion,
		companion_hp > 0.0,
		player_stats,
		companion_stats,
		enemy_data,
		rng
	)
	var turn_order: Array[String] = built.turn_order
	var turn_order_index := 0
	var turn := 1
	var actor_id := turn_order[0] if not turn_order.is_empty() else ""
	var companion_active := has_companion and companion_hp > 0.0
	var actions := 0
	var max_actions := int(config.get("max_actions", 120))
	var action_log: Array[String] = []
	while enemy_hp > 0.0 and player_hp > 0.0 and actions < max_actions and not actor_id.is_empty():
		actions += 1
		if actor_id == "enemy":
			var target := pick_enemy_target(companion_active, companion_hp, player_hp, rng)
			if target == "companion":
				companion_hp = maxf(0.0, companion_hp - enemy_damage)
				if companion_hp <= 0.0:
					companion_active = false
			else:
				player_hp = maxf(0.0, player_hp - enemy_damage)
			action_log.append("enemy->%s" % target)
		elif actor_id == "companion":
			enemy_hp = maxf(0.0, enemy_hp - companion_damage)
			action_log.append("companion_attack")
		else:
			enemy_hp = maxf(0.0, enemy_hp - player_damage)
			action_log.append("player_attack")
		if enemy_hp <= 0.0 or player_hp <= 0.0:
			break
		var next := next_actor(turn_order, turn_order_index, companion_active, companion_hp)
		if str(next.get("actor_id", "")).is_empty():
			break
		turn_order_index = int(next.get("index", turn_order_index))
		if bool(next.get("new_round", false)):
			turn += 1
		actor_id = str(next.get("actor_id", ""))
	return {
		"victory": enemy_hp <= 0.0 and player_hp > 0.0,
		"defeat": player_hp <= 0.0,
		"turn_order": turn_order,
		"turns": turn,
		"actions": actions,
		"player_hp": player_hp,
		"companion_hp": companion_hp,
		"enemy_hp": enemy_hp,
		"log": action_log,
	}
