# Purpose: Central RPG rules for attributes, combat values, damage, resistances, buffs, and debuffs.
# Public API: default_player_stats(), normalize_stats(), effective_stats(), hit_chance(), calculate_damage().
# Dependencies: None; callers pass plain dictionaries so rules stay modular.
extends Node

const MIN_HIT_CHANCE := 0.05
const MAX_HIT_CHANCE := 0.95
const MIN_DAMAGE_FACTOR := 0.05
const MAX_RESISTANCE := 95.0

const PRIMARY_ATTRIBUTES := {
	"strength": {"name": "Staerke", "short": "STR", "description": "Nahkampfschaden, Traglast, Blockkraft und Ruestungsdurchdringung.", "base": 5.0},
	"dexterity": {"name": "Geschicklichkeit", "short": "DEX", "description": "Fernkampfschaden, Praezision, Ausweichen und Tempo.", "base": 5.0},
	"intelligence": {"name": "Intelligenz", "short": "INT", "description": "Magieschaden, Mana und Zauberstaerke.", "base": 3.0},
	"vitality": {"name": "Vitalitaet", "short": "VIT", "description": "Leben, Regeneration und Widerstand gegen Gift und Blutung.", "base": 5.0},
	"willpower": {"name": "Willenskraft", "short": "WIL", "description": "Kontrollresistenz, Heilungsstaerke und Debuff-Widerstand.", "base": 4.0}
}

const SECONDARY_STATS := {
	"health": {"name": "Lebenspunkte", "short": "HP", "max": "max_health"},
	"mana": {"name": "Mana", "short": "MP", "max": "max_mana"},
	"stamina": {"name": "Ausdauer", "short": "STA", "max": "max_stamina"},
	"energy": {"name": "Energie", "short": "ENG", "max": "max_energy"}
}

const COMBAT_STATS := {
	"precision": {"name": "Praezision", "description": "Grundlage fuer Trefferchance."},
	"evasion": {"name": "Ausweichen", "description": "Senkt gegnerische Trefferchance."},
	"block_chance": {"name": "Blockchance", "description": "Chance, einen Teil des Schadens zu blocken."},
	"parry_chance": {"name": "Parierchance", "description": "Chance, Nahkampfangriffe abzuwehren."},
	"control_resist": {"name": "Kontrollresistenz", "description": "Schutz gegen Stun, Furcht, Stille und Einfrieren."},
	"critical_chance": {"name": "Krit-Chance", "description": "Chance auf kritische Treffer."},
	"critical_damage": {"name": "Krit-Schaden", "description": "Multiplikator fuer kritische Treffer."},
	"critical_resist": {"name": "Krit-Resistenz", "description": "Senkt gegnerische Krit-Chance."},
	"critical_protection": {"name": "Krit-Schutz", "description": "Senkt kritischen Bonusschaden."}
}

const DAMAGE_TYPES := {
	"physical": {"name": "Physisch", "resistance": "physical_resistance"},
	"pierce": {"name": "Stich", "resistance": "pierce_resistance"},
	"slash": {"name": "Hieb", "resistance": "slash_resistance"},
	"ranged": {"name": "Fernkampf", "resistance": "ranged_resistance"},
	"explosive": {"name": "Explosiv", "resistance": "explosive_resistance"},
	"magic": {"name": "Magie", "resistance": "magic_resistance"},
	"fire": {"name": "Feuer", "resistance": "fire_resistance"},
	"frost": {"name": "Frost", "resistance": "frost_resistance"},
	"lightning": {"name": "Blitz", "resistance": "lightning_resistance"},
	"poison": {"name": "Gift", "resistance": "poison_resistance"},
	"acid": {"name": "Saeure", "resistance": "acid_resistance"},
	"bleed": {"name": "Blut", "resistance": "bleed_resistance"},
	"light": {"name": "Licht", "resistance": "light_resistance"},
	"shadow": {"name": "Schatten", "resistance": "shadow_resistance"},
	"soul": {"name": "Seele", "resistance": "soul_resistance"},
	"chaos": {"name": "Chaos", "resistance": "chaos_resistance", "resistance_ignore": 0.50}
}

const BUFF_DEFINITIONS := {
	"shielded": {"name": "Schild", "category": "defense", "stackable": false, "priority": 50, "stat": "shield_strength"},
	"guarded": {"name": "Verteidigungsbonus", "category": "defense", "stackable": true, "priority": 40, "stat": "defense"},
	"weapon_focus": {"name": "Schadensbonus", "category": "offense", "stackable": true, "priority": 40, "stat": "damage_bonus"},
	"haste": {"name": "Angriffsgeschwindigkeit", "category": "speed", "stackable": false, "priority": 35, "stat": "attack_speed"},
	"regeneration": {"name": "Regeneration", "category": "recovery", "stackable": true, "priority": 30, "stat": "health_regen"},
	"invisible": {"name": "Unsichtbarkeit", "category": "stealth", "stackable": false, "priority": 80, "stat": "evasion"},
	"focus": {"name": "Fokus", "category": "precision", "stackable": false, "priority": 45, "stat": "precision"},
	"berserker": {"name": "Berserker", "category": "offense", "stackable": false, "priority": 60, "stat": "critical_chance"},
	"holy_aura": {"name": "Heilige Aura", "category": "aura", "stackable": false, "priority": 55, "stat": "light_resistance"},
	"shadow_form": {"name": "Schattenform", "category": "form", "stackable": false, "priority": 55, "stat": "shadow_resistance"}
}

const DEBUFF_DEFINITIONS := {
	"burning": {"name": "Brennen", "counter_resistance": "fire_resistance", "category": "dot"},
	"poisoned": {"name": "Vergiftung", "counter_resistance": "poison_resistance", "category": "dot"},
	"bleeding": {"name": "Blutung", "counter_resistance": "bleed_resistance", "category": "dot"},
	"slowed": {"name": "Verlangsamung", "counter_resistance": "control_resist", "category": "control"},
	"frozen": {"name": "Einfrieren", "counter_resistance": "frost_resistance", "category": "control"},
	"stunned": {"name": "Betaeubung", "counter_resistance": "control_resist", "category": "control"},
	"blinded": {"name": "Blindheit", "counter_resistance": "willpower", "category": "control"},
	"cursed": {"name": "Verfluchung", "counter_resistance": "shadow_resistance", "category": "curse"},
	"corroded": {"name": "Korrosion", "counter_resistance": "acid_resistance", "category": "armor_break"},
	"feared": {"name": "Furcht", "counter_resistance": "control_resist", "category": "control"},
	"silenced": {"name": "Stille", "counter_resistance": "willpower", "category": "control"}
}

const ENDGAME_STATS := {
	"life_steal": {"name": "Lebensraub", "default": 0.0},
	"mana_steal": {"name": "Manaraub", "default": 0.0},
	"thorns": {"name": "Dornen", "default": 0.0},
	"luck": {"name": "Glueck", "default": 0.0},
	"cooldown_reduction": {"name": "Cooldown-Reduktion", "default": 0.0},
	"buff_power": {"name": "Buff-Staerke", "default": 0.0},
	"debuff_power": {"name": "Debuff-Staerke", "default": 0.0},
	"armor_pierce": {"name": "Ruestungsdurchdringung", "default": 0.0},
	"magic_pierce": {"name": "Magiedurchdringung", "default": 0.0},
	"shield_strength": {"name": "Schildstaerke", "default": 0.0},
	"healing_power": {"name": "Heilverstaerkung", "default": 0.0},
	"area_damage_bonus": {"name": "Flaechenschaden", "default": 0.0}
}


func default_player_stats() -> Dictionary:
	var stats := {
		"health": 100.0, "max_health": 100.0, "shield": 0.0,
		"mana": 40.0, "max_mana": 40.0,
		"hunger": 86.0, "thirst": 82.0, "stamina": 100.0,
		"energy": 100.0, "max_stamina": 100.0, "max_energy": 100.0,
		"infection": 0.0, "level": 1, "xp": 0, "next_xp": 60, "skill_points": 0, "initiative": 0.0,
		"melee": 0.0, "ranged": 0.0, "accuracy": 0.0, "defense": 0.0, "crafting": 0.0
	}
	for key in PRIMARY_ATTRIBUTES:
		stats[key] = float(PRIMARY_ATTRIBUTES[key].get("base", 0.0))
	for key in COMBAT_STATS:
		stats[key] = 0.0
	for key in resistance_keys():
		stats[key] = 0.0
	for key in ENDGAME_STATS:
		stats[key] = float(ENDGAME_STATS[key].get("default", 0.0))
	return stats


func normalize_stats(stats: Dictionary) -> Dictionary:
	var result := default_player_stats()
	for key in stats:
		result[key] = stats[key]
	return result


func effective_stats(base_stats: Dictionary, bonuses: Dictionary = {}) -> Dictionary:
	var stats := normalize_stats(base_stats)
	for key in bonuses:
		stats[key] = float(stats.get(key, 0.0)) + float(bonuses[key])
	stats.max_health = float(stats.max_health) + float(stats.vitality) * 8.0
	stats.max_mana = float(stats.max_mana) + float(stats.intelligence) * 10.0
	stats.max_stamina = float(stats.max_stamina) + float(stats.dexterity) * 2.0 + float(stats.vitality)
	stats.max_energy = float(stats.max_energy) + float(stats.willpower) * 2.0
	stats.melee_power = float(stats.melee) + float(stats.strength) * 1.8 + float(stats.dexterity) * 0.25
	stats.ranged_power = float(stats.ranged) + float(stats.dexterity) * 1.6
	stats.magic_power = float(stats.intelligence) * 2.0
	stats.block_power = float(stats.defense) + float(stats.strength) * 0.75
	stats.precision = 70.0 + float(stats.accuracy) * 3.0 + float(stats.dexterity) * 1.2
	stats.evasion = 5.0 + float(stats.dexterity) * 0.9 + float(stats.stamina) * 0.03
	stats.block_chance = clampf(float(stats.defense) * 1.5 + float(stats.strength) * 0.8, 0.0, 75.0)
	stats.parry_chance = clampf(float(stats.dexterity) * 0.7 + float(stats.strength) * 0.3, 0.0, 65.0)
	stats.control_resist = float(stats.willpower) * 1.4 + float(stats.vitality) * 0.4
	stats.critical_chance = clampf(5.0 + float(stats.dexterity) * 0.45 + float(stats.luck) * 0.2, 0.0, 85.0)
	stats.critical_damage = 1.50 + float(stats.strength) * 0.015 + float(stats.dexterity) * 0.01
	stats.critical_resist = float(stats.willpower) * 0.35
	stats.critical_protection = float(stats.vitality) * 0.01
	stats.healing_power = float(stats.healing_power) + float(stats.willpower) * 1.2
	stats.armor_pierce = float(stats.armor_pierce) + float(stats.strength) * 0.25
	stats.magic_pierce = float(stats.magic_pierce) + float(stats.intelligence) * 0.3
	stats.initiative = float(stats.get("initiative", 0.0)) + float(stats.dexterity) * 0.65 + float(stats.willpower) * 0.25
	stats.poison_resistance = float(stats.poison_resistance) + float(stats.vitality) * 0.6
	stats.bleed_resistance = float(stats.bleed_resistance) + float(stats.vitality) * 0.5
	return stats


func enemy_stats(enemy_data: Dictionary) -> Dictionary:
	var stats := default_player_stats()
	stats.health = float(enemy_data.get("health", 30.0))
	stats.max_health = float(enemy_data.get("health", 30.0))
	stats.strength = float(enemy_data.get("strength", 4.0)) + float(enemy_data.get("damage", 6.0)) * 0.25
	stats.dexterity = float(enemy_data.get("dexterity", 4.0)) + float(enemy_data.get("speed", 1.0))
	stats.vitality = float(enemy_data.get("vitality", 4.0)) + float(enemy_data.get("health", 30.0)) * 0.035
	stats.willpower = float(enemy_data.get("willpower", 4.0))
	stats.accuracy = float(enemy_data.get("accuracy", 0.0)) + float(enemy_data.get("speed", 1.0))
	stats.initiative = float(enemy_data.get("initiative", 0.0)) + float(enemy_data.get("speed", 1.0)) * 2.5
	stats.melee = float(enemy_data.get("damage", 6.0)) * 0.35
	stats.ranged = float(enemy_data.get("ranged", 0.0))
	var resistances: Dictionary = enemy_data.get("resistances", {})
	for key in resistances:
		stats[key] = float(resistances[key])
	return effective_stats(stats)


func hit_chance(attacker_stats: Dictionary, defender_stats: Dictionary = {}, modifier: float = 0.0) -> float:
	var attacker := effective_stats(attacker_stats)
	var defender := effective_stats(defender_stats)
	var raw := (float(attacker.precision) - float(defender.evasion) + modifier) / 100.0
	return clampf(raw, MIN_HIT_CHANCE, MAX_HIT_CHANCE)


func calculate_damage(base_damage: float, damage_type: String, attacker_stats: Dictionary = {}, defender_stats: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var attacker := effective_stats(attacker_stats)
	var defender := effective_stats(defender_stats)
	var type_data := damage_type_data(damage_type)
	var resistance_key := str(type_data.get("resistance", "physical_resistance"))
	var resistance := float(defender.get(resistance_key, 0.0))
	var pierce_key := "magic_pierce" if damage_type in ["magic", "fire", "frost", "lightning", "light", "shadow", "soul", "chaos"] else "armor_pierce"
	resistance -= float(options.get("resistance_pierce", attacker.get(pierce_key, 0.0)))
	resistance = clampf(resistance, -100.0, MAX_RESISTANCE)
	if damage_type == "chaos":
		resistance *= 1.0 - float(type_data.get("resistance_ignore", 0.50))
	var damage := maxf(0.0, base_damage + float(attacker.get("damage_bonus", 0.0)))
	damage *= maxf(MIN_DAMAGE_FACTOR, (100.0 - resistance) / 100.0)
	var critical := false
	if bool(options.get("allow_critical", true)):
		var crit_chance := clampf(float(attacker.critical_chance) - float(defender.critical_resist), 0.0, 95.0)
		critical = randf() * 100.0 <= crit_chance
		if critical:
			var crit_multiplier := maxf(1.0, float(attacker.critical_damage) - float(defender.critical_protection))
			damage *= crit_multiplier
	return {
		"damage": maxf(0.0, damage),
		"damage_type": damage_type,
		"resistance_key": resistance_key,
		"effective_resistance": resistance,
		"critical": critical
	}


func resistance_keys() -> Array[String]:
	var keys: Array[String] = []
	for damage_type in DAMAGE_TYPES:
		var key := str(DAMAGE_TYPES[damage_type].get("resistance", ""))
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


func damage_type_data(damage_type: String) -> Dictionary:
	return DAMAGE_TYPES.get(damage_type, DAMAGE_TYPES.physical)


func status_effect_data(effect_id: String) -> Dictionary:
	if BUFF_DEFINITIONS.has(effect_id):
		return BUFF_DEFINITIONS[effect_id]
	return DEBUFF_DEFINITIONS.get(effect_id, {})


func make_effect(effect_id: String, duration: int, power: float, source: String = "") -> Dictionary:
	var data := status_effect_data(effect_id)
	return {
		"id": effect_id,
		"name": data.get("name", effect_id),
		"duration": maxi(1, duration),
		"power": power,
		"source": source,
		"stackable": bool(data.get("stackable", false)),
		"priority": int(data.get("priority", 0)),
		"category": data.get("category", "generic")
	}
