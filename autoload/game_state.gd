# Purpose: Stores the global campaign, player, Elena, base, NPC, quest, and statistics state.
# Public API: new_game(), serialize(), restore(), stat changes, care actions, building, and survivor recruitment.
# Dependencies: DataCatalog and EventBus.
extends Node

const MAX_DAY := 260

var game_active := false
var player_gender := "female"
var player_name := "Morgan"
var player_class := "scout"
var player_appearance := "wanderer"
var player_stats: Dictionary = {}
var elena: Dictionary = {}
var base_state: Dictionary = {}
var survivors: Array[Dictionary] = []
var status_effects: Array[String] = []
var active_buffs: Array[Dictionary] = []
var active_debuffs: Array[Dictionary] = []
var story_flags: Dictionary = {}
var quest_flags: Dictionary = {}
var current_location := "base"
var return_scene := "res://scenes/world_map/world_map.tscn"
var pending_story := ""
var story_return_scene := "res://scenes/world_map/world_map.tscn"
var run_statistics: Dictionary = {}
var learned_abilities: Array[String] = []
var equipped_abilities: Array[String] = []
var claimed_ability_levels: Array[int] = []
var pending_ability_picks := 0

const SKILL_UPGRADES := {
	"strength": {"name": "Staerke", "amount": 1.0},
	"dexterity": {"name": "Geschicklichkeit", "amount": 1.0},
	"intelligence": {"name": "Intelligenz", "amount": 1.0},
	"vitality": {"name": "Vitalitaet", "amount": 1.0},
	"willpower": {"name": "Willenskraft", "amount": 1.0},
	"max_health": {"name": "Leben", "amount": 10.0},
	"max_mana": {"name": "Mana", "amount": 10.0},
	"max_stamina": {"name": "Ausdauer", "amount": 10.0},
	"max_energy": {"name": "Energie", "amount": 10.0},
	"melee": {"name": "Nahkampf", "amount": 1.0},
	"ranged": {"name": "Schusswaffen", "amount": 1.0},
	"accuracy": {"name": "Genauigkeit", "amount": 1.0},
	"defense": {"name": "Verteidigung", "amount": 1.0},
	"crafting": {"name": "Handwerk", "amount": 1.0},
	"critical_chance": {"name": "Krit-Chance", "amount": 1.0},
	"armor_pierce": {"name": "Ruestungsdurchdringung", "amount": 1.0},
	"control_resist": {"name": "Kontrollresistenz", "amount": 1.0}
}

const APPEARANCE_OPTIONS := {
	"wanderer": {"name": "Streuner", "description": "Abgenutzte Reisekleidung und leichter Mantel."},
	"mechanic": {"name": "Schrauber", "description": "Werkstattkleidung, Gurte und improvisierte Taschen."},
	"medic": {"name": "Sanitaeter", "description": "Helle Jacke mit sichtbarer medizinischer Markierung."},
	"guardian": {"name": "Waechter", "description": "Schwere Schutzkleidung und verstaerkte Weste."}
}

const MAX_EQUIPPED_ABILITIES := 9
const STARTING_ABILITY_COUNT := 4
const ABILITY_UNLOCK_LEVELS: Array[int] = [2, 4, 7, 10, 15, 17, 20]
const SURVIVOR_ROLE_NAMES := {
	"waechter": "Waechter",
	"sammler": "Sammler",
	"arzt": "Arzt"
}
const CLASS_ABILITIES := {
	"scout": [
		{"id": "scout_shadow_step", "name": "Schattenlauf", "description": "Schneller Schnitt und halber naechster Gegenschlag.", "effect": "damage_defend", "power": 10.0, "scale_stat": "melee", "scale": 2.0, "stamina_cost": 8.0, "energy_cost": 3.0, "defense_multiplier": 0.50, "icon": "res://assets/ui/icons/stamina.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#f0d17a"},
		{"id": "scout_knife_work", "name": "Kehlenschnitt", "description": "Praeziser Nahkampfangriff mit hohem Grundschaden.", "effect": "damage", "power": 15.0, "scale_stat": "melee", "scale": 2.4, "stamina_cost": 10.0, "energy_cost": 2.0, "icon": "res://assets/items/weapons/melee/rusty_knife.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ffd27a"},
		{"id": "scout_smoke_feint", "name": "Nebeltritt", "description": "Ausweichen, kleine Ausdauererholung und weniger Schaden.", "effect": "recover_defend", "power": 10.0, "scale_stat": "defense", "scale": 1.0, "stamina_cost": 3.0, "energy_cost": 4.0, "defense_multiplier": 0.35, "icon": "res://assets/ui/icons/energy.svg", "sound": "res://assets/audio/sfx/environment/wave_warning.wav", "color": "#9fb7ff"},
		{"id": "scout_weak_point", "name": "Schwachstelle", "description": "Treffer auf eine offene Stelle, skaliert mit Schusswaffen.", "effect": "damage", "power": 13.0, "scale_stat": "ranged", "scale": 2.7, "stamina_cost": 7.0, "energy_cost": 5.0, "icon": "res://assets/items/weapons/ranged/old_revolver.svg", "sound": "res://assets/audio/sfx/weapons/gunshot.wav", "color": "#ffb36a"},
		{"id": "scout_adrenaline", "name": "Adrenalinsprung", "description": "Gewinnt Ausdauer und Energie zurueck.", "effect": "recover", "power": 18.0, "scale_stat": "melee", "scale": 1.2, "stamina_cost": 0.0, "energy_cost": 0.0, "icon": "res://assets/ui/icons/stamina.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#b8ff8f"},
		{"id": "scout_flank", "name": "Flankieren", "description": "Angriff aus der Seite und leichter Schutz.", "effect": "damage_defend", "power": 17.0, "scale_stat": "melee", "scale": 2.1, "stamina_cost": 11.0, "energy_cost": 4.0, "defense_multiplier": 0.65, "icon": "res://assets/ui/icons/stamina.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ffe08a"},
		{"id": "scout_silent_shot", "name": "Lautloser Schuss", "description": "Starker Fernangriff, wenn Schusswaffen trainiert sind.", "effect": "damage", "power": 20.0, "scale_stat": "ranged", "scale": 3.0, "stamina_cost": 8.0, "energy_cost": 8.0, "icon": "res://assets/items/weapons/ranged/hunting_rifle.svg", "sound": "res://assets/audio/sfx/weapons/gunshot.wav", "color": "#ffc069"},
		{"id": "scout_tripwire", "name": "Stolperdraht", "description": "Schwacher Treffer, aber der Gegenschlag wird stark gebremst.", "effect": "snare", "power": 8.0, "scale_stat": "crafting", "scale": 2.0, "stamina_cost": 6.0, "energy_cost": 6.0, "defense_multiplier": 0.38, "icon": "res://assets/items/materials/nails.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#d7c79a"},
		{"id": "scout_vanish", "name": "Rueckzug", "description": "Kaum Schaden, dafuer sehr starker Schutz fuer den naechsten Angriff.", "effect": "defend", "power": 12.0, "scale_stat": "defense", "scale": 1.0, "stamina_cost": 4.0, "energy_cost": 5.0, "defense_multiplier": 0.22, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/environment/wave_warning.wav", "color": "#9bb8ff"},
		{"id": "scout_night_hunter", "name": "Nachtjaeger", "description": "Sehr schwerer Einzelangriff.", "effect": "damage", "power": 30.0, "scale_stat": "melee", "scale": 3.2, "stamina_cost": 18.0, "energy_cost": 12.0, "icon": "res://assets/items/weapons/melee/machete.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ff9a63"},
		{"id": "scout_survival_instinct", "name": "Ueberlebensinstinkt", "description": "Schild und Ausdauer in einem riskanten Moment.", "effect": "shield_recover", "power": 16.0, "scale_stat": "defense", "scale": 1.5, "stamina_cost": 0.0, "energy_cost": 8.0, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#a8f0ff"}
	],
	"medic": [
		{"id": "medic_field_dressing", "name": "Notversorgung", "description": "Heilt im Kampf sofort Leben.", "effect": "heal", "power": 18.0, "scale_stat": "defense", "scale": 2.0, "stamina_cost": 4.0, "energy_cost": 8.0, "icon": "res://assets/items/medical/bandage.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#8fffa8"},
		{"id": "medic_cleanse", "name": "Wunde reinigen", "description": "Heilt und entfernt eine frische Verunreinigung.", "effect": "cleanse_heal", "power": 12.0, "scale_stat": "crafting", "scale": 1.5, "stamina_cost": 3.0, "energy_cost": 10.0, "icon": "res://assets/items/medical/antiseptic.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#9dffd0"},
		{"id": "medic_stimulant", "name": "Stimulanz", "description": "Stellt Ausdauer und Energie wieder her.", "effect": "recover", "power": 16.0, "scale_stat": "defense", "scale": 1.2, "stamina_cost": 0.0, "energy_cost": 0.0, "icon": "res://assets/items/medical/painkillers.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#d2ff8a"},
		{"id": "medic_scalpel", "name": "Skalpellgriff", "description": "Kleiner Angriff, ein Teil heilt dich.", "effect": "damage_heal", "power": 10.0, "scale_stat": "melee", "scale": 1.8, "stamina_cost": 8.0, "energy_cost": 4.0, "heal_ratio": 0.45, "icon": "res://assets/items/weapons/melee/rusty_knife.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#b8ffd6"},
		{"id": "medic_triage", "name": "Triage", "description": "Grosse Heilung, aber teuer.", "effect": "heal", "power": 30.0, "scale_stat": "defense", "scale": 2.6, "stamina_cost": 6.0, "energy_cost": 16.0, "icon": "res://assets/items/medical/bandage.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#77ff9e"},
		{"id": "medic_bitter_dose", "name": "Bittere Dosis", "description": "Schwacher Treffer und Schutz durch Schmerzblockade.", "effect": "damage_defend", "power": 9.0, "scale_stat": "crafting", "scale": 2.0, "stamina_cost": 5.0, "energy_cost": 8.0, "defense_multiplier": 0.55, "icon": "res://assets/items/medical/painkillers.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#e7ffa8"},
		{"id": "medic_antibiotic_push", "name": "Antibiotischer Schub", "description": "Heilt, reinigt und gibt Schild.", "effect": "cleanse_shield", "power": 16.0, "scale_stat": "crafting", "scale": 1.8, "stamina_cost": 4.0, "energy_cost": 12.0, "shield": 12.0, "icon": "res://assets/items/medical/antibiotics.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#aaffef"},
		{"id": "medic_pressure_point", "name": "Druckpunkt", "description": "Praeziser Treffer, der den naechsten Schaden senkt.", "effect": "snare", "power": 14.0, "scale_stat": "melee", "scale": 2.2, "stamina_cost": 9.0, "energy_cost": 7.0, "defense_multiplier": 0.50, "icon": "res://assets/ui/icons/health.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ffd69a"},
		{"id": "medic_last_reserve", "name": "Letzte Reserve", "description": "Sehr starke Heilung, wenn du fast faellst.", "effect": "heal", "power": 42.0, "scale_stat": "defense", "scale": 2.8, "stamina_cost": 4.0, "energy_cost": 18.0, "icon": "res://assets/ui/icons/health.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#8cffb1"},
		{"id": "medic_bone_saw", "name": "Knochensaege", "description": "Brutaler Nahkampfangriff.", "effect": "damage", "power": 26.0, "scale_stat": "melee", "scale": 2.8, "stamina_cost": 16.0, "energy_cost": 9.0, "icon": "res://assets/items/weapons/melee/machete.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ff9f7a"},
		{"id": "medic_oath", "name": "Eid des Helfers", "description": "Schild, Heilung und etwas Energie.", "effect": "heal_shield", "power": 18.0, "scale_stat": "defense", "scale": 2.0, "stamina_cost": 0.0, "energy_cost": 12.0, "shield": 18.0, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#bfffd8"}
	],
	"guardian": [
		{"id": "guardian_shield_wall", "name": "Schildwall", "description": "Starker Schutz und stabiler Konter.", "effect": "damage_defend", "power": 8.0, "scale_stat": "defense", "scale": 2.5, "stamina_cost": 7.0, "energy_cost": 4.0, "defense_multiplier": 0.25, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/environment/wave_warning.wav", "color": "#9bb8ff"},
		{"id": "guardian_bash", "name": "Schildschlag", "description": "Verteidigungsangriff mit Schild-Skalierung.", "effect": "damage", "power": 14.0, "scale_stat": "defense", "scale": 2.8, "stamina_cost": 10.0, "energy_cost": 3.0, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#c8d7ff"},
		{"id": "guardian_warning_shot", "name": "Warnschuss", "description": "Fernangriff und weniger Druck durch den Gegner.", "effect": "snare", "power": 13.0, "scale_stat": "ranged", "scale": 2.4, "stamina_cost": 7.0, "energy_cost": 6.0, "defense_multiplier": 0.60, "icon": "res://assets/items/weapons/ranged/old_revolver.svg", "sound": "res://assets/audio/sfx/weapons/gunshot.wav", "color": "#ffd08a"},
		{"id": "guardian_hold_line", "name": "Linie halten", "description": "Schild und sehr guter Schutz fuer den naechsten Schlag.", "effect": "shield_defend", "power": 12.0, "scale_stat": "defense", "scale": 2.0, "stamina_cost": 5.0, "energy_cost": 4.0, "defense_multiplier": 0.28, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/environment/wave_warning.wav", "color": "#a9c5ff"},
		{"id": "guardian_counter", "name": "Konterstand", "description": "Schaden, Schild und guter Gegenschlagschutz.", "effect": "damage_shield_defend", "power": 12.0, "scale_stat": "defense", "scale": 2.4, "stamina_cost": 11.0, "energy_cost": 5.0, "shield": 8.0, "defense_multiplier": 0.48, "icon": "res://assets/items/armor/leather_vest.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#b7c9ff"},
		{"id": "guardian_hammer_arc", "name": "Brecherbogen", "description": "Schwerer Nahkampfangriff.", "effect": "damage", "power": 24.0, "scale_stat": "melee", "scale": 2.6, "stamina_cost": 16.0, "energy_cost": 7.0, "icon": "res://assets/items/weapons/melee/crowbar.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ffb184"},
		{"id": "guardian_covering_fire", "name": "Deckungsfeuer", "description": "Fernschaden und deutlicher Schutz.", "effect": "damage_defend", "power": 18.0, "scale_stat": "ranged", "scale": 2.7, "stamina_cost": 10.0, "energy_cost": 9.0, "defense_multiplier": 0.45, "icon": "res://assets/items/weapons/ranged/pump_shotgun.svg", "sound": "res://assets/audio/sfx/weapons/gunshot.wav", "color": "#ffd58a"},
		{"id": "guardian_taunt", "name": "Provozieren", "description": "Kaum Schaden, aber extrem viel Schutz.", "effect": "defend", "power": 14.0, "scale_stat": "defense", "scale": 1.5, "stamina_cost": 4.0, "energy_cost": 5.0, "defense_multiplier": 0.18, "icon": "res://assets/ui/icons/shield.svg", "sound": "res://assets/audio/sfx/enemies/growl.wav", "color": "#c6d5ff"},
		{"id": "guardian_bastion", "name": "Bastion", "description": "Massiver Schildaufbau.", "effect": "shield", "power": 28.0, "scale_stat": "defense", "scale": 3.0, "stamina_cost": 8.0, "energy_cost": 12.0, "icon": "res://assets/items/armor/scrap_helmet.svg", "sound": "res://assets/audio/sfx/environment/wave_warning.wav", "color": "#a8bdff"},
		{"id": "guardian_last_stand", "name": "Letzter Stand", "description": "Grosser Konter und starker Schutz.", "effect": "damage_shield_defend", "power": 28.0, "scale_stat": "defense", "scale": 3.0, "stamina_cost": 18.0, "energy_cost": 14.0, "shield": 18.0, "defense_multiplier": 0.30, "icon": "res://assets/ui/icons/health.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ffe0a0"},
		{"id": "guardian_anchor", "name": "Ankerpunkt", "description": "Ausdauer zurueck und Schild halten.", "effect": "shield_recover", "power": 14.0, "scale_stat": "defense", "scale": 2.0, "stamina_cost": 0.0, "energy_cost": 6.0, "icon": "res://assets/ui/icons/stamina.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#a9cfff"}
	],
	"tinker": [
		{"id": "tinker_scrap_charge", "name": "Improvisierte Ladung", "description": "Schrottexplosion; mit Metall und Naegeln staerker.", "effect": "material_damage", "power": 13.0, "scale_stat": "crafting", "scale": 3.0, "stamina_cost": 6.0, "energy_cost": 8.0, "item_cost": {"metal": 1, "nails": 1}, "bonus_power": 12.0, "icon": "res://assets/items/materials/powder.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#ffca7a"},
		{"id": "tinker_nail_snare", "name": "Nagelfalle", "description": "Schaden und gebremster Gegenschlag.", "effect": "snare", "power": 10.0, "scale_stat": "crafting", "scale": 2.4, "stamina_cost": 5.0, "energy_cost": 7.0, "defense_multiplier": 0.42, "icon": "res://assets/items/materials/nails.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#e0c990"},
		{"id": "tinker_overclock", "name": "Uebertakten", "description": "Energie und Ausdauer durch schnellen Umbau.", "effect": "recover", "power": 18.0, "scale_stat": "crafting", "scale": 1.6, "stamina_cost": 0.0, "energy_cost": 0.0, "icon": "res://assets/items/materials/electronics.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#a8e6ff"},
		{"id": "tinker_jury_rig", "name": "Flickwerk", "description": "Schildaufbau aus Teilen am Koerper.", "effect": "shield", "power": 16.0, "scale_stat": "crafting", "scale": 2.4, "stamina_cost": 5.0, "energy_cost": 6.0, "icon": "res://assets/items/materials/metal.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#c4d5e0"},
		{"id": "tinker_flash_pop", "name": "Blitzknall", "description": "Leichter Schaden, sehr starker Schutz.", "effect": "snare", "power": 8.0, "scale_stat": "crafting", "scale": 2.1, "stamina_cost": 4.0, "energy_cost": 8.0, "defense_multiplier": 0.25, "icon": "res://assets/items/misc/flashlight_battery.svg", "sound": "res://assets/audio/sfx/environment/wave_warning.wav", "color": "#f8f0a0"},
		{"id": "tinker_pipe_launcher", "name": "Rohrwerfer", "description": "Schwerer technischer Treffer.", "effect": "damage", "power": 24.0, "scale_stat": "crafting", "scale": 3.2, "stamina_cost": 12.0, "energy_cost": 10.0, "icon": "res://assets/items/weapons/ranged/pump_shotgun.svg", "sound": "res://assets/audio/sfx/weapons/gunshot.wav", "color": "#ffb26f"},
		{"id": "tinker_saw_trap", "name": "Saegefalle", "description": "Starker Schaden und Schutz durch Abstand.", "effect": "damage_defend", "power": 18.0, "scale_stat": "crafting", "scale": 2.8, "stamina_cost": 10.0, "energy_cost": 10.0, "defense_multiplier": 0.55, "icon": "res://assets/items/weapons/melee/fire_axe.svg", "sound": "res://assets/audio/sfx/weapons/melee_hit.wav", "color": "#ff9e74"},
		{"id": "tinker_patch_armor", "name": "Panzerflicken", "description": "Schild und etwas Heilung.", "effect": "heal_shield", "power": 10.0, "scale_stat": "crafting", "scale": 1.8, "stamina_cost": 5.0, "energy_cost": 8.0, "shield": 18.0, "icon": "res://assets/items/armor/reinforced_coat.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#bdd0ff"},
		{"id": "tinker_magnetic_pull", "name": "Magnetzug", "description": "Treffer und der Gegner verliert Druck.", "effect": "snare", "power": 16.0, "scale_stat": "crafting", "scale": 2.6, "stamina_cost": 7.0, "energy_cost": 9.0, "defense_multiplier": 0.48, "icon": "res://assets/items/materials/electronics.svg", "sound": "res://assets/audio/sfx/ui/craft.wav", "color": "#9de4ff"},
		{"id": "tinker_blackpowder", "name": "Schwarzpulver", "description": "Sehr schwerer Explosionsschaden.", "effect": "damage", "power": 34.0, "scale_stat": "crafting", "scale": 3.5, "stamina_cost": 16.0, "energy_cost": 16.0, "icon": "res://assets/items/materials/powder.svg", "sound": "res://assets/audio/sfx/weapons/gunshot.wav", "color": "#ff9f5c"},
		{"id": "tinker_emergency_rig", "name": "Notapparat", "description": "Schild, Erholung und weniger naechster Schaden.", "effect": "shield_recover_defend", "power": 18.0, "scale_stat": "crafting", "scale": 2.0, "stamina_cost": 0.0, "energy_cost": 12.0, "defense_multiplier": 0.36, "icon": "res://assets/items/misc/radio_parts.svg", "sound": "res://assets/audio/sfx/ui/loot.wav", "color": "#aef0ff"}
	]
}


func _ready() -> void:
	if player_stats.is_empty():
		_reset_runtime_state()
	if learned_abilities.is_empty():
		_initialize_class_abilities()


func new_game(gender: String, class_id: String = "scout", display_name: String = "Morgan", appearance_id: String = "wanderer") -> void:
	_reset_runtime_state()
	game_active = true
	player_gender = gender
	player_class = class_id
	player_appearance = appearance_id if APPEARANCE_OPTIONS.has(appearance_id) else "wanderer"
	player_name = display_name.strip_edges()
	if player_name.is_empty():
		player_name = "Morgan"
	var config := DataCatalog.player_config()
	player_stats = RpgRules.normalize_stats(config.get("stats", {}).duplicate(true))
	var selected_class_config: Dictionary = config.get("classes", {}).get(class_id, {})
	for stat_name in selected_class_config.get("stat_bonus", {}):
		var base_value := float(player_stats.get(stat_name, 0.0))
		if not player_stats.has(stat_name) and str(stat_name).begins_with("max_"):
			base_value = float(player_stats.get(str(stat_name).trim_prefix("max_"), 100.0))
		player_stats[stat_name] = base_value + float(selected_class_config.stat_bonus[stat_name])
	elena = config.get("elena", {}).duplicate(true)
	base_state = _default_base_state()
	var config_base: Dictionary = config.get("base", {})
	base_state.integrity = float(config_base.get("integrity", base_state.integrity))
	base_state.max_integrity = float(config_base.get("max_integrity", base_state.max_integrity))
	var starting_inventory: Dictionary = config.get("starting_inventory", {}).duplicate(true)
	for item_id in selected_class_config.get("starting_inventory", {}):
		starting_inventory[item_id] = int(starting_inventory.get(item_id, 0)) + int(selected_class_config.starting_inventory[item_id])
	InventorySystem.reset_inventory(starting_inventory, str(config.get("starting_backpack", "small_backpack")))
	_initialize_class_abilities()
	TimeSystem.reset_time()
	WaveManager.reset_waves()
	EventBus.stats_changed.emit()


func _reset_runtime_state() -> void:
	player_stats = RpgRules.default_player_stats()
	player_class = "scout"
	player_appearance = "wanderer"
	elena = {"health": 100.0, "max_health": 100.0, "stress": 15.0}
	base_state = _default_base_state()
	survivors = []
	status_effects = []
	active_buffs = []
	active_debuffs = []
	story_flags = {}
	quest_flags = {}
	learned_abilities = []
	equipped_abilities = []
	claimed_ability_levels = []
	pending_ability_picks = 0
	current_location = "base"
	pending_story = ""
	run_statistics = {
		"loot_collected": 0,
		"enemies_defeated": 0,
		"structures_built": 0,
		"items_crafted": 0,
		"waves_survived": 0,
		"locations_visited": 0
	}


func change_stat(stat_name: String, amount: float) -> void:
	if not player_stats.has(stat_name):
		return
	var maximum := float(player_stats.get("max_" + stat_name, 100.0))
	player_stats[stat_name] = clampf(float(player_stats[stat_name]) + amount, 0.0, maximum)
	if stat_name == "health" and float(player_stats.health) <= 0.0:
		EventBus.game_over.emit("Du bist den Wunden der letzten Tage erlegen.")
	EventBus.stats_changed.emit()


func spend_for_action(stamina_cost: float, energy_cost: float, hunger_cost: float = 2.0, thirst_cost: float = 3.0) -> void:
	change_stat("stamina", -stamina_cost)
	change_stat("energy", -energy_cost)
	change_stat("hunger", -hunger_cost)
	change_stat("thirst", -thirst_cost)
	if float(player_stats.hunger) <= 0.0 or float(player_stats.thirst) <= 0.0:
		change_stat("health", -5.0)


func rest_player() -> void:
	player_stats.stamina = 100.0
	player_stats.energy = 100.0
	if not status_effects.has("well_rested"):
		status_effects.append("well_rested")
	EventBus.stats_changed.emit()


func care_for_elena(kind: String) -> String:
	var result := ""
	match kind:
		"talk":
			elena.stress = maxf(0.0, float(elena.stress) - 12.0)
			result = "Du bleibst eine Weile bei Elena. Ihre Atmung wird ruhiger."
		"food":
			if InventorySystem.remove_item("canned_beans", 1):
				elena.stress = maxf(0.0, float(elena.stress) - 8.0)
				elena.health = minf(float(elena.max_health), float(elena.health) + 4.0)
				result = "Eine warme Mahlzeit gibt Elena neue Kraft."
			else:
				result = "Dafür fehlt eine Dose Nahrung."
		"medicine":
			if InventorySystem.remove_item("bandage", 1):
				elena.health = minf(float(elena.max_health), float(elena.health) + 18.0)
				elena.stress = maxf(0.0, float(elena.stress) - 5.0)
				result = "Du versorgst Elena sorgfältig."
			else:
				result = "Du hast keine Bandage."
	EventBus.stats_changed.emit()
	return result


func damage_elena(amount: float) -> void:
	var shelter_level := int(base_state.structures.get("elena_shelter", 0))
	var reduced := amount * maxf(0.25, 1.0 - shelter_level * 0.22)
	elena.health = maxf(0.0, float(elena.health) - reduced)
	elena.stress = minf(100.0, float(elena.stress) + reduced * 0.8)
	EventBus.stats_changed.emit()
	if float(elena.health) <= 0.0:
		EventBus.game_over.emit("Elena ist gefallen. Mit ihr erlischt die letzte Hoffnung.")


func damage_base(amount: float) -> void:
	base_state.integrity = maxf(0.0, float(base_state.integrity) - amount)
	elena.stress = minf(100.0, float(elena.stress) + amount * 0.25)
	EventBus.stats_changed.emit()


func build_structure(structure_id: String) -> bool:
	var structure := DataCatalog.structure(structure_id)
	if structure.is_empty():
		return false
	if not InventorySystem.consume_cost(structure.get("cost", {})):
		return false
	var levels: Dictionary = base_state.structures
	levels[structure_id] = int(levels.get(structure_id, 0)) + 1
	run_statistics.structures_built = int(run_statistics.structures_built) + 1
	EventBus.stats_changed.emit()
	return true


func _default_base_state() -> Dictionary:
	var unlocked: Array[String] = []
	var placements := {}
	for room_id in DataCatalog.base_rooms:
		var data := DataCatalog.base_room(str(room_id))
		if bool(data.get("starts_unlocked", false)):
			unlocked.append(str(room_id))
		if str(data.get("zone", "")) == "surface":
			placements[str(room_id)] = ""
	return {
		"integrity": 100.0,
		"max_integrity": 100.0,
		"structures": {},
		"unlocked_rooms": unlocked,
		"surface_placements": placements,
		"elena_room": "shaft_room"
	}


func _normalize_base_state() -> void:
	if not base_state.has("unlocked_rooms"):
		base_state.unlocked_rooms = ["shaft_room"]
	if not base_state.has("surface_placements"):
		base_state.surface_placements = {}
		for room_id in DataCatalog.surface_slots():
			base_state.surface_placements[room_id] = ""
	if not base_state.has("elena_room"):
		base_state.elena_room = "shaft_room"


func is_room_unlocked(room_id: String) -> bool:
	_normalize_base_state()
	return str(room_id) in base_state.unlocked_rooms


func unlock_room(room_id: String) -> bool:
	_normalize_base_state()
	if is_room_unlocked(room_id):
		return false
	var data := DataCatalog.base_room(room_id)
	if data.is_empty():
		return false
	if not InventorySystem.consume_cost(data.get("unlock_cost", {})):
		EventBus.post_message("Fuer %s fehlen Materialien." % data.get("name", room_id))
		return false
	base_state.unlocked_rooms.append(room_id)
	var linked := str(data.get("structure_id", ""))
	if not linked.is_empty():
		base_state.structures[linked] = maxi(1, int(base_state.structures.get(linked, 0)))
	run_statistics.structures_built = int(run_statistics.structures_built) + 1
	EventBus.post_message("%s freigeschaltet." % data.get("name", room_id))
	EventBus.stats_changed.emit()
	return true


func surface_placement(slot_id: String) -> String:
	_normalize_base_state()
	return str(base_state.surface_placements.get(slot_id, ""))


func can_place_on_surface(slot_id: String, structure_id: String) -> bool:
	if not is_room_unlocked(slot_id):
		return false
	var slot := DataCatalog.base_room(slot_id)
	if slot.is_empty():
		return false
	var allowed: Array = slot.get("allowed_structures", [])
	if not allowed.is_empty() and not allowed.has(structure_id):
		return false
	var structure := DataCatalog.structure(structure_id)
	if structure.is_empty():
		return false
	return InventorySystem.has_items(structure.get("cost", {}))


func place_surface_defense(slot_id: String, structure_id: String) -> bool:
	if not can_place_on_surface(slot_id, structure_id):
		return false
	var structure := DataCatalog.structure(structure_id)
	if not InventorySystem.consume_cost(structure.get("cost", {})):
		return false
	var previous := surface_placement(slot_id)
	if not previous.is_empty():
		InventorySystem.add_item(previous, 1)
	base_state.surface_placements[slot_id] = structure_id
	base_state.structures[structure_id] = int(base_state.structures.get(structure_id, 0)) + 1
	run_statistics.structures_built = int(run_statistics.structures_built) + 1
	EventBus.post_message("%s auf %s platziert." % [structure.get("name", structure_id), DataCatalog.base_room(slot_id).get("name", slot_id)])
	EventBus.stats_changed.emit()
	return true


func remove_surface_defense(slot_id: String) -> bool:
	_normalize_base_state()
	var structure_id := surface_placement(slot_id)
	if structure_id.is_empty():
		return false
	if not InventorySystem.can_add_item(structure_id, 1):
		EventBus.post_message("Kein Platz im Rucksack fuer die Anlage.")
		return false
	base_state.surface_placements[slot_id] = ""
	base_state.structures[structure_id] = maxi(0, int(base_state.structures.get(structure_id, 0)) - 1)
	if int(base_state.structures.get(structure_id, 0)) <= 0:
		base_state.structures.erase(structure_id)
	InventorySystem.add_item(structure_id, 1)
	EventBus.stats_changed.emit()
	return true


func surface_defense_damage() -> float:
	_normalize_base_state()
	var total := 0.0
	for slot_id in base_state.surface_placements:
		var structure_id := surface_placement(str(slot_id))
		if structure_id.is_empty():
			continue
		var data := DataCatalog.structure(structure_id)
		total += float(data.get("surface_damage", data.get("trap_damage", data.get("defense", 0))))
		if structure_id == "watchtower":
			total += float(count_role("waechter")) * 4.0
	return total


func elena_allowed_rooms() -> Array[String]:
	var rooms: Array[String] = []
	for room_id in base_state.get("unlocked_rooms", []):
		var data := DataCatalog.base_room(str(room_id))
		if bool(data.get("elena_allowed", false)):
			rooms.append(str(room_id))
	return rooms


func set_elena_room(room_id: String) -> void:
	if room_id in elena_allowed_rooms():
		base_state.elena_room = room_id
		EventBus.stats_changed.emit()


func room_center(room_id: String, canvas_size: Vector2) -> Vector2:
	var data := DataCatalog.base_room(room_id)
	var rect: Dictionary = data.get("rect", {})
	return Vector2(
		float(rect.get("x", 0.5)) * canvas_size.x + float(rect.get("w", 0.1)) * canvas_size.x * 0.5,
		float(rect.get("y", 0.5)) * canvas_size.y + float(rect.get("h", 0.1)) * canvas_size.y * 0.5
	)


func recruit_survivor(survivor_id: String, display_name: String, role: String) -> bool:
	for survivor in survivors:
		if survivor.id == survivor_id:
			return false
	survivors.append({"id": survivor_id, "name": display_name, "role": role, "health": 100})
	return true


func count_role(role: String) -> int:
	var count := 0
	for survivor in survivors:
		if survivor.role == role:
			count += 1
	return count


func survivor_role_name(role: String) -> String:
	return str(SURVIVOR_ROLE_NAMES.get(role, role.capitalize()))


func class_config() -> Dictionary:
	return DataCatalog.player_config().get("classes", {}).get(player_class, {})


func player_class_name() -> String:
	return str(class_config().get("name", player_class))


func player_appearance_name() -> String:
	return str(APPEARANCE_OPTIONS.get(player_appearance, {}).get("name", player_appearance))


func player_appearance_path(gender_override: String = "", appearance_override: String = "") -> String:
	var gender := gender_override if not gender_override.is_empty() else player_gender
	var appearance_id := appearance_override if not appearance_override.is_empty() else player_appearance
	if not APPEARANCE_OPTIONS.has(appearance_id):
		appearance_id = "wanderer"
	if gender != "male":
		gender = "female"
	return "res://assets/characters/player_variants/%s_%s.png" % [gender, appearance_id]


func effective_player_stats() -> Dictionary:
	return RpgRules.effective_stats(player_stats, InventorySystem.equipment_stat_bonuses())


func max_resource(resource_name: String) -> float:
	var effective := effective_player_stats()
	return float(effective.get("max_" + resource_name, player_stats.get("max_" + resource_name, 100.0)))


func add_buff(effect_id: String, duration: int, power: float, source: String = "") -> void:
	_add_timed_effect(active_buffs, RpgRules.make_effect(effect_id, duration, power, source))
	EventBus.stats_changed.emit()


func add_debuff(effect_id: String, duration: int, power: float, source: String = "") -> void:
	_add_timed_effect(active_debuffs, RpgRules.make_effect(effect_id, duration, power, source))
	EventBus.stats_changed.emit()


func tick_timed_effects() -> void:
	_tick_effect_list(active_buffs)
	_tick_effect_list(active_debuffs)
	EventBus.stats_changed.emit()


func class_ability() -> Dictionary:
	for ability_id in equipped_abilities:
		if not str(ability_id).is_empty():
			return ability(str(ability_id))
	return class_config().get("ability", {})


func class_abilities(class_id: String = "") -> Array:
	var resolved_class := class_id if not class_id.is_empty() else player_class
	return CLASS_ABILITIES.get(resolved_class, [])


func ability(ability_id: String) -> Dictionary:
	for data in class_abilities():
		if str(data.get("id", "")) == ability_id:
			return data
	return {}


func ability_unlock_level(ability_id: String) -> int:
	var pool := class_abilities()
	for index in range(pool.size()):
		if str(pool[index].get("id", "")) != ability_id:
			continue
		if index < STARTING_ABILITY_COUNT:
			return 1
		var unlock_index := index - STARTING_ABILITY_COUNT
		if ABILITY_UNLOCK_LEVELS.is_empty():
			return 1
		return ABILITY_UNLOCK_LEVELS[mini(unlock_index, ABILITY_UNLOCK_LEVELS.size() - 1)]
	return 999


func ability_unlocked_for_level(ability_id: String, level: int = -1) -> bool:
	var resolved_level := level if level > 0 else int(player_stats.get("level", 1))
	return resolved_level >= ability_unlock_level(ability_id)


func ability_slot_id(index: int) -> String:
	if index < 0 or index >= MAX_EQUIPPED_ABILITIES or index >= equipped_abilities.size():
		return ""
	return str(equipped_abilities[index])


func equipped_ability_count() -> int:
	var count := 0
	for ability_id in equipped_abilities:
		if not str(ability_id).is_empty():
			count += 1
	return count


func ability_action_points(ability_id: String) -> int:
	var data := ability(ability_id)
	if data.is_empty():
		return 0
	var effect := str(data.get("effect", "damage"))
	var power := float(data.get("power", 0.0))
	var cost := 2
	if effect in ["defend", "shield", "shield_defend", "recover", "recover_defend", "shield_recover", "shield_recover_defend"]:
		cost = 1
	elif effect in ["heal", "cleanse_heal", "cleanse_shield", "heal_shield"]:
		cost = 2
	elif effect in ["material_damage", "damage_shield_defend"]:
		cost = 3
	if power >= 28.0 or float(data.get("stamina_cost", 0.0)) >= 16.0:
		cost += 1
	return clampi(cost, 1, 4)


func ability_cooldown(ability_id: String) -> int:
	var data := ability(ability_id)
	if data.is_empty():
		return 0
	var effect := str(data.get("effect", "damage"))
	var power := float(data.get("power", 0.0))
	var cooldown := 1
	if effect in ["recover", "recover_defend", "shield_recover", "shield_recover_defend"]:
		cooldown = 3
	elif effect in ["heal", "cleanse_heal", "cleanse_shield", "heal_shield", "shield", "shield_defend"]:
		cooldown = 2
	elif effect in ["snare", "damage_defend", "damage_shield_defend", "material_damage"]:
		cooldown = 2
	if power >= 28.0:
		cooldown += 1
	if float(data.get("energy_cost", 0.0)) >= 14.0:
		cooldown += 1
	return clampi(cooldown, 1, 5)


func _initialize_class_abilities() -> void:
	learned_abilities.clear()
	equipped_abilities.clear()
	claimed_ability_levels.clear()
	pending_ability_picks = 0
	var pool := class_abilities()
	for index in range(mini(STARTING_ABILITY_COUNT, pool.size())):
		var ability_id := str(pool[index].get("id", ""))
		if not ability_id.is_empty():
			learned_abilities.append(ability_id)
			equipped_abilities.append(ability_id)


func _validate_ability_state() -> void:
	var valid_ids: Array[String] = []
	for data in class_abilities():
		valid_ids.append(str(data.get("id", "")))
	var filtered_learned: Array[String] = []
	for ability_id in learned_abilities:
		if valid_ids.has(ability_id) and not filtered_learned.has(ability_id):
			filtered_learned.append(ability_id)
	learned_abilities = filtered_learned
	if learned_abilities.is_empty():
		_initialize_class_abilities()
		_grant_ability_picks_for_level(int(player_stats.get("level", 1)))
		return
	var filtered_equipped: Array[String] = []
	var seen_equipped: Dictionary = {}
	for ability_id in equipped_abilities:
		if filtered_equipped.size() >= MAX_EQUIPPED_ABILITIES:
			break
		var id := str(ability_id)
		if id.is_empty():
			filtered_equipped.append("")
		elif learned_abilities.has(id) and not seen_equipped.has(id):
			filtered_equipped.append(id)
			seen_equipped[id] = true
		else:
			filtered_equipped.append("")
	if filtered_equipped.is_empty():
		for ability_id in learned_abilities:
			if filtered_equipped.size() >= mini(MAX_EQUIPPED_ABILITIES, STARTING_ABILITY_COUNT):
				break
			filtered_equipped.append(ability_id)
	equipped_abilities = filtered_equipped
	_grant_ability_picks_for_level(int(player_stats.get("level", 1)))


func _grant_ability_picks_for_level(level: int) -> void:
	for unlock_level in ABILITY_UNLOCK_LEVELS:
		if level >= unlock_level and not claimed_ability_levels.has(unlock_level):
			claimed_ability_levels.append(unlock_level)
			pending_ability_picks += 1


func available_ability_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data in class_abilities():
		var ability_id := str(data.get("id", ""))
		if not learned_abilities.has(ability_id) and ability_unlocked_for_level(ability_id):
			result.append(data)
	return result


func learn_ability(ability_id: String) -> bool:
	if pending_ability_picks <= 0 or learned_abilities.has(ability_id) or ability(ability_id).is_empty() or not ability_unlocked_for_level(ability_id):
		return false
	learned_abilities.append(ability_id)
	pending_ability_picks -= 1
	_add_ability_to_first_free_slot(ability_id)
	EventBus.stats_changed.emit()
	return true


func equip_ability(ability_id: String) -> bool:
	if not learned_abilities.has(ability_id) or equipped_abilities.has(ability_id):
		return false
	if equipped_ability_count() >= MAX_EQUIPPED_ABILITIES:
		EventBus.post_message("Die Faehigkeitenleiste ist voll.")
		return false
	_add_ability_to_first_free_slot(ability_id)
	EventBus.stats_changed.emit()
	return true


func unequip_ability(ability_id: String) -> bool:
	if not equipped_abilities.has(ability_id):
		return false
	var index := equipped_abilities.find(ability_id)
	if index >= 0:
		equipped_abilities[index] = ""
	EventBus.stats_changed.emit()
	return true


func set_ability_slot(ability_id: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_EQUIPPED_ABILITIES or not learned_abilities.has(ability_id):
		return false
	while equipped_abilities.size() < MAX_EQUIPPED_ABILITIES:
		equipped_abilities.append("")
	var current_index := equipped_abilities.find(ability_id)
	var target_id := str(equipped_abilities[slot_index])
	if current_index == slot_index:
		return true
	if current_index >= 0:
		equipped_abilities[current_index] = target_id if target_id != ability_id else ""
	equipped_abilities[slot_index] = ability_id
	EventBus.stats_changed.emit()
	return true


func clear_ability_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= equipped_abilities.size():
		return false
	if str(equipped_abilities[slot_index]).is_empty():
		return false
	equipped_abilities[slot_index] = ""
	EventBus.stats_changed.emit()
	return true


func _add_ability_to_first_free_slot(ability_id: String) -> void:
	var empty_index := equipped_abilities.find("")
	if empty_index >= 0:
		equipped_abilities[empty_index] = ability_id
	elif equipped_abilities.size() < MAX_EQUIPPED_ABILITIES:
		equipped_abilities.append(ability_id)


func _add_timed_effect(list: Array[Dictionary], effect: Dictionary) -> void:
	var effect_id := str(effect.get("id", ""))
	if effect_id.is_empty():
		return
	var stackable := bool(effect.get("stackable", false))
	if not stackable:
		for index in range(list.size()):
			if str(list[index].get("id", "")) == effect_id:
				list[index] = effect
				return
	list.append(effect)


func _tick_effect_list(list: Array[Dictionary]) -> void:
	for index in range(list.size() - 1, -1, -1):
		var entry: Dictionary = list[index]
		entry.duration = int(entry.get("duration", 0)) - 1
		if int(entry.duration) <= 0:
			list.remove_at(index)
		else:
			list[index] = entry


func ability_tooltip_text(ability_id: String) -> String:
	var data := ability(ability_id)
	if data.is_empty():
		return ""
	var lines: Array[String] = [
		str(data.get("name", ability_id)),
		str(data.get("description", ""))
	]
	var stat := str(data.get("scale_stat", ""))
	var stats: Array[String] = []
	if float(data.get("power", 0.0)) > 0.0:
		stats.append("Grundwert %.0f" % float(data.get("power", 0.0)))
	if not stat.is_empty() and float(data.get("scale", 0.0)) > 0.0:
		stats.append("%s x %.1f" % [SKILL_UPGRADES.get(stat, {"name": stat}).get("name", stat), float(data.get("scale", 0.0))])
	if float(data.get("shield", 0.0)) > 0.0:
		stats.append("Schild +%.0f" % float(data.get("shield", 0.0)))
	if data.has("defense_multiplier"):
		stats.append("Naechster Schaden %.0f%%" % (float(data.get("defense_multiplier", 1.0)) * 100.0))
	if not stats.is_empty():
		lines.append("Stats: %s" % ", ".join(stats))
	var costs: Array[String] = []
	costs.append("AP %d" % ability_action_points(ability_id))
	if float(data.get("stamina_cost", 0.0)) > 0.0:
		costs.append("Ausdauer %.0f" % float(data.get("stamina_cost", 0.0)))
	if float(data.get("energy_cost", 0.0)) > 0.0:
		costs.append("Energie %.0f" % float(data.get("energy_cost", 0.0)))
	var item_cost: Dictionary = data.get("item_cost", {})
	if not item_cost.is_empty():
		costs.append(UiFactory.cost_text(item_cost))
	lines.append("Kosten: %s" % (", ".join(costs) if not costs.is_empty() else "keine"))
	lines.append("Abklingzeit: %d Runde(n)" % ability_cooldown(ability_id))
	return "\n".join(lines)


func grant_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	player_stats.xp = int(player_stats.get("xp", 0)) + amount
	var leveled := false
	while int(player_stats.get("xp", 0)) >= int(player_stats.get("next_xp", 60)):
		player_stats.xp = int(player_stats.xp) - int(player_stats.get("next_xp", 60))
		player_stats.level = int(player_stats.get("level", 1)) + 1
		player_stats.skill_points = int(player_stats.get("skill_points", 0)) + 2
		_grant_ability_picks_for_level(int(player_stats.level))
		player_stats.next_xp = maxi(60, roundi(float(player_stats.get("next_xp", 60)) * 1.35 + 20.0))
		leveled = true
	if leveled:
		EventBus.post_message("Levelaufstieg! Oeffne mit K das Levelmenue: passive Punkte und neue Faehigkeiten warten.")
	elif not reason.is_empty():
		EventBus.post_message("+%d Erfahrung: %s" % [amount, reason])
	EventBus.stats_changed.emit()


func spend_skill_point(stat_name: String) -> bool:
	if int(player_stats.get("skill_points", 0)) <= 0 or not SKILL_UPGRADES.has(stat_name):
		return false
	var upgrade: Dictionary = SKILL_UPGRADES[stat_name]
	var amount := float(upgrade.get("amount", 1.0))
	player_stats.skill_points = int(player_stats.skill_points) - 1
	player_stats[stat_name] = float(player_stats.get(stat_name, 0.0)) + amount
	match stat_name:
		"max_health":
			player_stats.health = minf(float(player_stats.max_health), float(player_stats.get("health", 0.0)) + amount)
		"max_mana":
			player_stats.mana = minf(float(player_stats.max_mana), float(player_stats.get("mana", 0.0)) + amount)
		"max_stamina":
			player_stats.stamina = minf(float(player_stats.max_stamina), float(player_stats.get("stamina", 0.0)) + amount)
		"max_energy":
			player_stats.energy = minf(float(player_stats.max_energy), float(player_stats.get("energy", 0.0)) + amount)
		"vitality":
			player_stats.health = minf(max_resource("health"), float(player_stats.get("health", 0.0)) + 4.0)
		"dexterity":
			player_stats.stamina = minf(max_resource("stamina"), float(player_stats.get("stamina", 0.0)) + 2.0)
		"intelligence":
			player_stats.mana = minf(max_resource("mana"), float(player_stats.get("mana", 0.0)) + 4.0)
		"willpower":
			player_stats.energy = minf(max_resource("energy"), float(player_stats.get("energy", 0.0)) + 2.0)
	EventBus.stats_changed.emit()
	return true


func serialize() -> Dictionary:
	return {
		"game_active": game_active,
		"player_gender": player_gender,
		"player_name": player_name,
		"player_class": player_class,
		"player_appearance": player_appearance,
		"player_stats": player_stats,
		"elena": elena,
		"base_state": base_state,
		"survivors": survivors,
		"status_effects": status_effects,
		"active_buffs": active_buffs,
		"active_debuffs": active_debuffs,
		"story_flags": story_flags,
		"quest_flags": quest_flags,
		"current_location": current_location,
		"run_statistics": run_statistics,
		"learned_abilities": learned_abilities,
		"equipped_abilities": equipped_abilities,
		"claimed_ability_levels": claimed_ability_levels,
		"pending_ability_picks": pending_ability_picks
	}


func restore(data: Dictionary) -> void:
	game_active = bool(data.get("game_active", true))
	player_gender = str(data.get("player_gender", "female"))
	player_name = str(data.get("player_name", "Morgan"))
	player_class = str(data.get("player_class", "scout"))
	player_appearance = str(data.get("player_appearance", "wanderer"))
	if not APPEARANCE_OPTIONS.has(player_appearance):
		player_appearance = "wanderer"
	player_stats = RpgRules.normalize_stats(data.get("player_stats", player_stats).duplicate(true))
	elena = data.get("elena", elena).duplicate(true)
	base_state = data.get("base_state", base_state).duplicate(true)
	_normalize_base_state()
	survivors.assign(data.get("survivors", []))
	status_effects.assign(data.get("status_effects", []))
	active_buffs.assign(data.get("active_buffs", []))
	active_debuffs.assign(data.get("active_debuffs", []))
	story_flags = data.get("story_flags", {}).duplicate(true)
	quest_flags = data.get("quest_flags", {}).duplicate(true)
	current_location = str(data.get("current_location", "base"))
	run_statistics = data.get("run_statistics", run_statistics).duplicate(true)
	learned_abilities.assign(data.get("learned_abilities", []))
	equipped_abilities.assign(data.get("equipped_abilities", []))
	claimed_ability_levels.clear()
	for level in data.get("claimed_ability_levels", []):
		claimed_ability_levels.append(int(level))
	pending_ability_picks = int(data.get("pending_ability_picks", 0))
	_validate_ability_state()
	EventBus.stats_changed.emit()
