# Purpose: Loads all balancing resources and exposes read-only catalog lookup helpers.
# Public API: item(), enemy(), recipe(), structure(), location(), wave_config(), player_config(), weighted_loot().
# Dependencies: CatalogData resources under res://data.
extends Node

const ITEM_PATHS: Array[String] = [
	"res://data/items/weapons_melee.tres",
	"res://data/items/weapons_ranged.tres",
	"res://data/items/weapons_dd_sheet.tres",
	"res://data/items/ammo.tres",
	"res://data/items/food.tres",
	"res://data/items/drinks.tres",
	"res://data/items/medical.tres",
	"res://data/items/armor.tres",
	"res://data/items/backpacks.tres",
	"res://data/items/materials.tres",
	"res://data/items/misc.tres",
	"res://data/items/accessories.tres",
]

var items: Dictionary = {}
var enemies: Dictionary = {}
var recipes: Dictionary = {}
var structures: Dictionary = {}
var base_rooms: Dictionary = {}
var modular_pieces: Dictionary = {}
var locations: Dictionary = {}
var map_events: Dictionary = {}
var travel_events: Dictionary = {}
var waves: Dictionary = {}
var player: Dictionary = {}
var stories: Dictionary = {}

const CATEGORY_VALUE := {
	"Material": 6,
	"Munition": 10,
	"Nahrung": 16,
	"Getraenk": 14,
	"Medizin": 28,
	"Rucksack": 44,
	"Kleidung": 38,
	"Ruestung": 54,
	"Maske": 42,
	"Helm": 56,
	"Schuhe": 36,
	"Handschuhe": 30,
	"Nahkampf": 58,
	"Waffe": 82,
	"Pistole": 94,
	"Fernkampf": 78,
	"Maschinenpistole": 132,
	"Sniper": 160,
	"Wurfgegenstand": 46,
	"Ring": 34,
	"Guertel": 32,
	"Amulett": 36,
	"Schild": 58
}

const RARITY_PRICE_MULTIPLIER := {
	"normal": 1.0,
	"selten": 1.75,
	"rare": 1.75,
	"episch": 3.15,
	"epic": 3.15,
	"legendaer": 5.8,
	"legendär": 5.8,
	"legendary": 5.8
}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	items.clear()
	for path in ITEM_PATHS:
		items.merge(_entries(path), true)
	enemies = _entries("res://data/enemies/enemy_stats.tres")
	recipes = _entries("res://data/crafting/recipes.tres")
	structures = _entries("res://data/building/structures.tres")
	base_rooms = _entries("res://data/building/base_rooms.tres")
	modular_pieces = _entries("res://data/building/modular_kit_pieces.tres")
	locations = _entries("res://data/world/locations.tres")
	map_events = _entries("res://data/world/map_events.tres")
	travel_events = _entries("res://data/world/travel_events.tres")
	waves = _entries("res://data/waves/wave_schedule.tres")
	player = _entries("res://data/player/player_stats_base.tres")
	stories = _entries("res://data/story/story_slides.tres")


func _entries(path: String) -> Dictionary:
	var resource := load(path) as CatalogData
	return resource.entries.duplicate(true) if resource else {}


func item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func item_value(item_id: String) -> int:
	var data := item(item_id)
	if data.is_empty():
		return 0
	if data.has("value"):
		return maxi(1, int(data.get("value", 1)))
	var category := str(data.get("category", "Material"))
	var base := float(CATEGORY_VALUE.get(category, 12))
	base += float(data.get("damage", 0)) * 3.0
	base += float(data.get("armor", 0)) * 5.0
	base += float(data.get("shield", 0)) * 4.0
	base += float(data.get("capacity_slots", 0)) * 8.0
	base += float(data.get("pocket_slots", 0)) * 7.0
	base += float(data.get("max_weight", 0.0)) * 0.8
	base += float(data.get("weight", 0.0)) * 2.0
	var effects: Dictionary = data.get("effects", {})
	for stat_name in effects:
		base += absf(float(effects[stat_name])) * (1.8 if str(stat_name) == "health" else 1.0)
	if int(data.get("max_condition", 0)) > 0:
		base += float(data.get("max_condition", 0)) * 0.22
	var rarity := str(data.get("rarity", "normal")).to_lower()
	base *= float(RARITY_PRICE_MULTIPLIER.get(rarity, 1.0))
	return maxi(1, roundi(base))


func item_buy_price(item_id: String) -> int:
	return maxi(1, ceili(float(item_value(item_id)) * 1.22))


func item_sell_price(item_id: String) -> int:
	return maxi(1, floori(float(item_value(item_id)) * 0.52))


func enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})


func recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {})


func structure(structure_id: String) -> Dictionary:
	return structures.get(structure_id, {})


func modular_piece(piece_id: String) -> Dictionary:
	return modular_pieces.get(piece_id, {})


func base_room(room_id: String) -> Dictionary:
	return base_rooms.get(room_id, {})


func bunker_rooms() -> Array[String]:
	var ids: Array[String] = []
	for room_id in base_rooms:
		if str(base_rooms[room_id].get("zone", "")) == "bunker":
			ids.append(str(room_id))
	return ids


func surface_slots() -> Array[String]:
	var ids: Array[String] = []
	for room_id in base_rooms:
		if str(base_rooms[room_id].get("zone", "")) == "surface":
			ids.append(str(room_id))
	return ids


func location(location_id: String) -> Dictionary:
	return locations.get(location_id, {})


func map_event(event_id: String) -> Dictionary:
	return map_events.get(event_id, {})


func travel_event(event_id: String) -> Dictionary:
	return travel_events.get(event_id, {})


func random_travel_event() -> Dictionary:
	if travel_events.is_empty():
		return {}
	var ids: Array = travel_events.keys()
	return travel_events[str(ids[randi() % ids.size()])].duplicate(true)


func wave_config() -> Dictionary:
	return waves.get("schedule", {})


func player_config() -> Dictionary:
	return player.get("base", {})


func story(story_id: String) -> Dictionary:
	return stories.get(story_id, {})


func weighted_loot(location_id: String, seed_value: int = 0) -> Dictionary:
	var location_data := location(location_id)
	var pool := _loot_pool(location_data)
	if pool.is_empty():
		return {}
	var total_weight := 0
	for entry in pool:
		total_weight += int(entry.get("weight", 0))
	if total_weight <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value)
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in pool:
		cursor += int(entry.get("weight", 0))
		if roll <= cursor:
			var item_id := str(entry.get("item_id", ""))
			var data := item(item_id)
			var amount := int(data.get("loot_amount", 1))
			if not str(data.get("ammo", "")).is_empty():
				amount = 1
			if str(data.get("category", "")) == "Munition":
				amount = int(data.get("loot_amount", 4))
			return {"item_id": item_id, "amount": maxi(1, amount)}
	return {}


func all_admin_items() -> Array[String]:
	var ids: Array[String] = []
	for item_id in items:
		ids.append(str(item_id))
	ids.sort()
	return ids


func _loot_pool(location_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var danger := int(location_data.get("danger", 0))
	for item_id in location_data.get("loot", []):
		_add_loot_entry(result, seen, str(item_id), 80)
	for item_id in items:
		var data := item(str(item_id))
		if not bool(data.get("loot_enabled", false)):
			continue
		if danger < int(data.get("min_danger", 0)):
			continue
		_add_loot_entry(result, seen, str(item_id), int(data.get("spawn_weight", 10)))
	return result


func _add_loot_entry(pool: Array[Dictionary], seen: Dictionary, item_id: String, fallback_weight: int) -> void:
	if item_id.is_empty() or seen.has(item_id) or item(item_id).is_empty():
		return
	var data := item(item_id)
	var weight := int(data.get("spawn_weight", fallback_weight))
	if weight <= 0:
		return
	seen[item_id] = true
	pool.append({"item_id": item_id, "weight": weight})
