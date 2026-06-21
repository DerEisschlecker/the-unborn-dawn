# Purpose: Stores the weighted player inventory independently of the current scene.
# Public API: add_item(), remove_item(), has_items(), consume_cost(), use_item(), serialize(), restore().
# Dependencies: DataCatalog and EventBus.
extends Node

var items: Dictionary = {}
var equipped_backpack_id := "small_backpack"
var slot_capacity := 6
var backpack_slot_capacity := 6
var clothing_slot_capacity := 0
var max_weight := 35.0
var money := 38
var equipment: Dictionary = {}
var item_order: Array[String] = []
var item_condition: Dictionary = {}
var storage_items: Dictionary = {}
var storage_order: Array[String] = []
var quick_slots: Array[String] = []

const QUICK_SLOT_COUNT := 6
const BASE_STORAGE_WEIGHT := 200.0
const STORAGE_SLOTS_BASE := 63

const EQUIPMENT_SLOTS := {
	"head": {"name": "Helm", "order": 10},
	"mask": {"name": "Maske", "order": 20},
	"jacket": {"name": "Jacke", "order": 30},
	"vest": {"name": "Weste", "order": 40},
	"pants": {"name": "Hose", "order": 50},
	"gloves": {"name": "Handschuhe", "order": 60},
	"shoes": {"name": "Schuhe", "order": 70},
	"shield": {"name": "Schild", "order": 75},
	"tool": {"name": "Axt / Werkzeug", "order": 80},
	"melee": {"name": "Nahkampfwaffe", "order": 90},
	"firearm": {"name": "Waffe / Pistole", "order": 100},
	"throwable": {"name": "Wurfgegenstand", "order": 110},
	"ring": {"name": "Ring", "order": 120},
	"belt": {"name": "Guertel", "order": 130},
	"amulet": {"name": "Amulett", "order": 140}
}

const CLOTHING_CONTAINER_SLOTS := ["jacket", "vest", "pants"]
const SORT_CATEGORY_ORDER := {
	"Rucksack": 10,
	"Waffe": 20,
	"Pistole": 21,
	"Maschinenpistole": 22,
	"Sniper": 23,
	"Fernkampf": 24,
	"Nahkampf": 25,
	"Wurfgegenstand": 26,
	"Munition": 30,
	"Medizin": 40,
	"Nahrung": 50,
	"Getraenk": 51,
	"Ruestung": 60,
	"Kleidung": 61,
	"Maske": 62,
	"Helm": 63,
	"Schuhe": 64,
	"Handschuhe": 65,
	"Ring": 66,
	"Guertel": 67,
	"Amulett": 68,
	"Schild": 69,
	"Material": 70
}


func reset_inventory(starting_items: Dictionary = {}, backpack_id: String = "small_backpack", starting_money: int = 38) -> void:
	equipped_backpack_id = backpack_id
	money = maxi(0, starting_money)
	equipment = _empty_equipment()
	storage_items.clear()
	storage_order.clear()
	quick_slots = _empty_quick_slots()
	_apply_backpack_limits()
	items = starting_items.duplicate(true)
	item_order.clear()
	for item_id in starting_items:
		item_order.append(str(item_id))
	item_condition.clear()
	for item_id in items:
		_ensure_condition(str(item_id))
	EventBus.inventory_changed.emit()


func add_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or DataCatalog.item(item_id).is_empty():
		return false
	if not items.has(item_id) and used_slots() >= slot_capacity:
		EventBus.post_message("Kein Platz im Rucksack.")
		return false
	var added_weight := float(DataCatalog.item(item_id).get("weight", 0.0)) * amount
	if current_weight() + added_weight > max_weight:
		EventBus.post_message("Dein Rucksack ist zu schwer.")
		return false
	if not items.has(item_id):
		item_order.append(item_id)
	items[item_id] = int(items.get(item_id, 0)) + amount
	_ensure_condition(item_id)
	if GameState.game_active:
		GameState.run_statistics.loot_collected = int(GameState.run_statistics.loot_collected) + amount
	EventBus.inventory_changed.emit()
	return true


func can_add_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or DataCatalog.item(item_id).is_empty():
		return false
	if not items.has(item_id) and used_slots() >= slot_capacity:
		return false
	var added_weight := float(DataCatalog.item(item_id).get("weight", 0.0)) * amount
	return current_weight() + added_weight <= max_weight


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	EventBus.inventory_changed.emit()


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	EventBus.inventory_changed.emit()
	return true


func admin_grant_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or DataCatalog.item(item_id).is_empty():
		return false
	_add_item_direct(item_id, amount)
	_ensure_condition(item_id)
	EventBus.post_message("%s x%d erhalten." % [DataCatalog.item(item_id).get("name", item_id), amount])
	EventBus.inventory_changed.emit()
	return true


func remove_item(item_id: String, amount: int = 1) -> bool:
	if int(items.get(item_id, 0)) < amount:
		return false
	items[item_id] = int(items[item_id]) - amount
	if int(items[item_id]) <= 0:
		items.erase(item_id)
		item_order.erase(item_id)
		_sanitize_quick_slots()
	EventBus.inventory_changed.emit()
	return true


func discard_item(item_id: String, amount: int = 1) -> bool:
	if remove_item(item_id, amount):
		EventBus.post_message("%s entsorgt." % DataCatalog.item(item_id).get("name", item_id))
		return true
	return false


func discard_storage_item(item_id: String, amount: int = 1) -> bool:
	var moved := amount if amount > 0 else int(storage_items.get(item_id, 0))
	if moved <= 0:
		return false
	if _remove_storage_direct(item_id, moved):
		EventBus.post_message("%s x%d aus dem Lager entsorgt." % [DataCatalog.item(item_id).get("name", item_id), moved])
		EventBus.inventory_changed.emit()
		return true
	return false


func equip_backpack(item_id: String) -> bool:
	var data := DataCatalog.item(item_id)
	if data.is_empty() or int(data.get("capacity_slots", 0)) <= 0:
		return false
	if int(data.get("capacity_slots", 0)) < slot_capacity:
		EventBus.post_message("Dieser Rucksack ist kleiner als dein aktueller.")
		return false
	if not remove_item(item_id, 1):
		return false
	var old_backpack_id := equipped_backpack_id
	if not old_backpack_id.is_empty() and old_backpack_id != item_id:
		_add_item_direct(old_backpack_id, 1)
	equipped_backpack_id = item_id
	_apply_backpack_limits()
	EventBus.post_message("%s ausgeruestet." % data.get("name", item_id))
	EventBus.inventory_changed.emit()
	return true


func equip_item(item_id: String) -> bool:
	var data := DataCatalog.item(item_id)
	var slot := str(data.get("equip_slot", ""))
	if slot.is_empty() or not EQUIPMENT_SLOTS.has(slot):
		EventBus.post_message("Das kann nicht angelegt werden.")
		return false
	if int(items.get(item_id, 0)) <= 0:
		EventBus.post_message("Dieser Gegenstand liegt nicht im Rucksack.")
		return false
	remove_item(item_id, 1)
	var old_item := str(equipment.get(slot, ""))
	if not old_item.is_empty():
		_add_item_direct(old_item, 1)
	equipment[slot] = item_id
	_recalculate_capacity()
	EventBus.post_message("%s angelegt." % data.get("name", item_id))
	EventBus.inventory_changed.emit()
	EventBus.stats_changed.emit()
	return true


func unequip_slot(slot: String) -> bool:
	if not EQUIPMENT_SLOTS.has(slot):
		return false
	var item_id := str(equipment.get(slot, ""))
	if item_id.is_empty():
		return false
	if not items.has(item_id) and used_slots() + 1 > _capacity_without_slot(slot):
		EventBus.post_message("Kein Platz im Rucksack, um das abzulegen.")
		return false
	if current_weight() > _max_weight_without_slot(slot):
		EventBus.post_message("Der Rucksack waere zu schwer.")
		return false
	equipment[slot] = ""
	_add_item_direct(item_id, 1)
	_recalculate_capacity()
	EventBus.post_message("%s abgelegt." % DataCatalog.item(item_id).get("name", item_id))
	EventBus.inventory_changed.emit()
	EventBus.stats_changed.emit()
	return true


func equipped_item(slot: String) -> String:
	return str(equipment.get(slot, ""))


func total_equipment_bonus(bonus_name: String) -> float:
	var total := 0.0
	for slot in equipment:
		var item_id := str(equipment[slot])
		if item_id.is_empty():
			continue
		total += float(DataCatalog.item(item_id).get(bonus_name, 0.0))
	return total


func equipment_stat_bonuses() -> Dictionary:
	var totals := {}
	for slot in equipment:
		var item_id := str(equipment[slot])
		if item_id.is_empty():
			continue
		var data := DataCatalog.item(item_id)
		for key in data:
			if typeof(data[key]) == TYPE_INT or typeof(data[key]) == TYPE_FLOAT:
				if _is_stat_bonus_key(str(key)):
					totals[key] = float(totals.get(key, 0.0)) + float(data[key])
	return totals


func armor_value() -> float:
	return total_equipment_bonus("armor") + total_equipment_bonus("shield") * 0.35


func attack_candidates() -> Array[String]:
	var result: Array[String] = []
	for slot in ["firearm", "tool", "melee", "throwable"]:
		var item_id := equipped_item(slot)
		if not item_id.is_empty() and _weapon_available(item_id):
			result.append(item_id)
	for item_id in ordered_items():
		if int(items.get(item_id, 0)) > 0 and _weapon_available(item_id) and not result.has(item_id):
			result.append(item_id)
	return result


func preferred_weapon() -> String:
	var candidates := attack_candidates()
	return candidates[0] if not candidates.is_empty() else ""


func _weapon_available(item_id: String) -> bool:
	var data := DataCatalog.item(item_id)
	return float(data.get("damage", 0.0)) > 0.0 and not is_broken(item_id)


func has_items(cost: Dictionary) -> bool:
	for item_id in cost:
		if int(items.get(item_id, 0)) < int(cost[item_id]):
			return false
	return true


func consume_cost(cost: Dictionary) -> bool:
	if not has_items(cost):
		return false
	for item_id in cost:
		remove_item(item_id, int(cost[item_id]))
	return true


func current_weight() -> float:
	var total := 0.0
	for item_id in items:
		total += float(DataCatalog.item(item_id).get("weight", 0.0)) * int(items[item_id])
	for slot in equipment:
		var item_id := str(equipment[slot])
		if not item_id.is_empty():
			total += float(DataCatalog.item(item_id).get("weight", 0.0))
	return total


func is_durable(item_id: String) -> bool:
	return int(DataCatalog.item(item_id).get("max_condition", 0)) > 0


func max_condition(item_id: String) -> int:
	return int(DataCatalog.item(item_id).get("max_condition", 0))


func condition(item_id: String) -> int:
	var max_value := max_condition(item_id)
	if max_value <= 0:
		return 0
	_ensure_condition(item_id)
	return clampi(int(item_condition.get(item_id, max_value)), 0, max_value)


func condition_ratio(item_id: String) -> float:
	var max_value := max_condition(item_id)
	if max_value <= 0:
		return 1.0
	return clampf(float(condition(item_id)) / float(max_value), 0.0, 1.0)


func is_broken(item_id: String) -> bool:
	return is_durable(item_id) and condition(item_id) <= 0


func damage_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0 or not is_durable(item_id):
		return
	_ensure_condition(item_id)
	item_condition[item_id] = maxi(0, condition(item_id) - amount)
	if int(item_condition[item_id]) <= 0:
		EventBus.post_message("%s ist kaputt und muss repariert werden." % DataCatalog.item(item_id).get("name", item_id))
	EventBus.inventory_changed.emit()


func repair_item(item_id: String) -> bool:
	if not is_durable(item_id):
		return false
	var max_value := max_condition(item_id)
	if condition(item_id) >= max_value:
		EventBus.post_message("%s ist bereits in gutem Zustand." % DataCatalog.item(item_id).get("name", item_id))
		return false
	var cost: Dictionary = DataCatalog.item(item_id).get("repair_cost", _default_repair_cost(item_id))
	if not consume_cost(cost):
		EventBus.post_message("Material fuer Reparatur fehlt: %s" % UiFactory.cost_text(cost))
		return false
	item_condition[item_id] = max_value
	EventBus.post_message("%s repariert." % DataCatalog.item(item_id).get("name", item_id))
	EventBus.inventory_changed.emit()
	return true


func condition_text(item_id: String) -> String:
	if not is_durable(item_id):
		return ""
	return "Zustand: %d/%d" % [condition(item_id), max_condition(item_id)]


func repair_cost_text(item_id: String) -> String:
	if not is_durable(item_id):
		return ""
	var cost: Dictionary = DataCatalog.item(item_id).get("repair_cost", _default_repair_cost(item_id))
	return UiFactory.cost_text(cost)


func consume_equipped_or_inventory(item_id: String, amount: int = 1) -> bool:
	for slot in equipment:
		if str(equipment[slot]) == item_id:
			equipment[slot] = ""
			EventBus.inventory_changed.emit()
			EventBus.stats_changed.emit()
			return true
	return remove_item(item_id, amount)


func used_slots() -> int:
	return items.size()


func free_slots() -> int:
	return maxi(0, slot_capacity - used_slots())


func storage_used_slots() -> int:
	return storage_items.size()


func storage_slot_capacity() -> int:
	var chest_level := int(GameState.base_state.get("structures", {}).get("storage_chest", 0))
	return STORAGE_SLOTS_BASE + chest_level * 14


func storage_current_weight() -> float:
	var total := 0.0
	for item_id in storage_items:
		total += float(DataCatalog.item(str(item_id)).get("weight", 0.0)) * int(storage_items[item_id])
	return total


func storage_max_weight() -> float:
	var chest_level := int(GameState.base_state.get("structures", {}).get("storage_chest", 0))
	var chest_data := DataCatalog.structure("storage_chest")
	return BASE_STORAGE_WEIGHT + float(chest_level) * float(chest_data.get("storage_weight", 100.0))


func can_add_storage_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or DataCatalog.item(item_id).is_empty():
		return false
	if not storage_items.has(item_id) and storage_used_slots() >= storage_slot_capacity():
		return false
	var added_weight := float(DataCatalog.item(item_id).get("weight", 0.0)) * amount
	return storage_current_weight() + added_weight <= storage_max_weight()


func transfer_to_storage(item_id: String, amount: int = -1) -> bool:
	var available := int(items.get(item_id, 0))
	if available <= 0:
		return false
	var moved := available if amount <= 0 else mini(amount, available)
	if not can_add_storage_item(item_id, moved):
		EventBus.post_message("Im Lager ist nicht genug Platz oder Traglast.")
		return false
	if not remove_item(item_id, moved):
		return false
	_add_storage_direct(item_id, moved)
	EventBus.post_message("%s x%d ins Lager gelegt." % [DataCatalog.item(item_id).get("name", item_id), moved])
	EventBus.inventory_changed.emit()
	return true


func transfer_to_backpack(item_id: String, amount: int = -1) -> bool:
	var available := int(storage_items.get(item_id, 0))
	if available <= 0:
		return false
	var moved := available if amount <= 0 else mini(amount, available)
	if not can_add_item(item_id, moved):
		EventBus.post_message("Rucksack voll oder zu schwer.")
		return false
	if not add_item(item_id, moved):
		return false
	_remove_storage_direct(item_id, moved)
	EventBus.post_message("%s x%d in den Rucksack gelegt." % [DataCatalog.item(item_id).get("name", item_id), moved])
	EventBus.inventory_changed.emit()
	return true


func split_stack_to_other_container(item_id: String, source: String) -> bool:
	var amount := int(items.get(item_id, 0)) if source == "backpack" else int(storage_items.get(item_id, 0))
	if amount <= 1:
		EventBus.post_message("Stapel ist zu klein zum Teilen.")
		return false
	var moved := maxi(1, floori(float(amount) * 0.5))
	if source == "backpack":
		return transfer_to_storage(item_id, moved)
	if source == "storage":
		return transfer_to_backpack(item_id, moved)
	return false


func set_quick_slot(index: int, item_id: String) -> bool:
	if index < 0 or index >= QUICK_SLOT_COUNT:
		return false
	while quick_slots.size() < QUICK_SLOT_COUNT:
		quick_slots.append("")
	if item_id.is_empty():
		quick_slots[index] = ""
		EventBus.inventory_changed.emit()
		return true
	if not usable_item(item_id):
		EventBus.post_message("Nur Verbrauchsgegenstaende aus dem Rucksack koennen in den Schnellzugriff.")
		return false
	quick_slots[index] = item_id
	EventBus.inventory_changed.emit()
	return true


func clear_quick_slot(index: int) -> bool:
	if index < 0 or index >= quick_slots.size() or str(quick_slots[index]).is_empty():
		return false
	quick_slots[index] = ""
	EventBus.inventory_changed.emit()
	return true


func quick_slot_item(index: int) -> String:
	_sanitize_quick_slots()
	if index < 0 or index >= quick_slots.size():
		return ""
	return str(quick_slots[index])


func quick_slot_items() -> Array[String]:
	_sanitize_quick_slots()
	var result: Array[String] = []
	for index in range(QUICK_SLOT_COUNT):
		result.append(quick_slot_item(index))
	return result


func backpack_data() -> Dictionary:
	return DataCatalog.item(equipped_backpack_id)


func clothing_capacity() -> int:
	return clothing_slot_capacity


func clothing_container_text() -> String:
	var names: Array[String] = []
	for slot in CLOTHING_CONTAINER_SLOTS:
		var item_id := equipped_item(slot)
		if item_id.is_empty():
			continue
		var data := DataCatalog.item(item_id)
		var pockets := int(data.get("pocket_slots", 0))
		if pockets > 0:
			names.append("%s +%d" % [data.get("name", item_id), pockets])
	return ", ".join(names) if not names.is_empty() else "Keine Kleidungstaschen ausgeruestet."


func ordered_items() -> Array[String]:
	var ordered: Array[String] = []
	for item_id in item_order:
		if items.has(item_id) and not ordered.has(item_id):
			ordered.append(item_id)
	for item_id in items:
		if not ordered.has(str(item_id)):
			ordered.append(str(item_id))
	item_order = ordered.duplicate()
	return ordered


func ordered_storage_items() -> Array[String]:
	var ordered: Array[String] = []
	for item_id in storage_order:
		if storage_items.has(item_id) and not ordered.has(item_id):
			ordered.append(item_id)
	for item_id in storage_items:
		if not ordered.has(str(item_id)):
			ordered.append(str(item_id))
	storage_order = ordered.duplicate()
	return ordered


func sorted_items_for_layout() -> Array[String]:
	var ordered := ordered_items()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return _item_sort_key(a) < _item_sort_key(b)
	)
	return ordered


func sorted_storage_items_for_layout() -> Array[String]:
	var ordered := ordered_storage_items()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return _item_sort_key(a) < _item_sort_key(b)
	)
	return ordered


func move_item(item_id: String, direction: int) -> bool:
	if not items.has(item_id) or direction == 0:
		return false
	var ordered := ordered_items()
	var current_index := ordered.find(item_id)
	if current_index < 0:
		return false
	var target_index := clampi(current_index + direction, 0, ordered.size() - 1)
	if target_index == current_index:
		return false
	ordered.remove_at(current_index)
	ordered.insert(target_index, item_id)
	item_order = ordered
	EventBus.inventory_changed.emit()
	return true


func move_item_to_index(item_id: String, target_index: int) -> bool:
	if not items.has(item_id):
		return false
	var ordered := ordered_items()
	var current_index := ordered.find(item_id)
	if current_index < 0:
		return false
	ordered.remove_at(current_index)
	ordered.insert(clampi(target_index, 0, ordered.size()), item_id)
	item_order = ordered
	EventBus.inventory_changed.emit()
	return true


func move_storage_item_to_index(item_id: String, target_index: int) -> bool:
	if not storage_items.has(item_id):
		return false
	var ordered := ordered_storage_items()
	var current_index := ordered.find(item_id)
	if current_index < 0:
		return false
	ordered.remove_at(current_index)
	ordered.insert(clampi(target_index, 0, ordered.size()), item_id)
	storage_order = ordered
	EventBus.inventory_changed.emit()
	return true


func _apply_backpack_limits() -> void:
	var data := DataCatalog.item(equipped_backpack_id)
	if data.is_empty():
		backpack_slot_capacity = 6
		max_weight = 22.0
		_recalculate_capacity()
		return
	backpack_slot_capacity = int(data.get("capacity_slots", 6))
	max_weight = float(data.get("max_weight", 22.0))
	_recalculate_capacity()


func usable_item(item_id: String) -> bool:
	var data := DataCatalog.item(item_id)
	return not data.is_empty() and data.has("effects") and int(items.get(item_id, 0)) > 0


func combat_item_action_points(item_id: String) -> int:
	var data := DataCatalog.item(item_id)
	if data.is_empty() or not data.has("effects"):
		return 0
	var category := str(data.get("category", ""))
	var effects: Dictionary = data.get("effects", {})
	var cost := 2
	if category == "Nahrung" or category == "Getraenk":
		cost = 1
	if float(effects.get("health", 0.0)) >= 18.0 or float(effects.get("infection", 0.0)) < 0.0:
		cost = maxi(cost, 2)
	return clampi(cost, 1, 3)


func use_item(item_id: String) -> String:
	var data := DataCatalog.item(item_id)
	if data.is_empty() or not remove_item(item_id, 1):
		return "Gegenstand nicht verfuegbar."
	var effects: Dictionary = data.get("effects", {})
	for stat_name in effects:
		GameState.change_stat(stat_name, float(effects[stat_name]))
	if item_id == "antibiotics":
		GameState.status_effects.erase("infected_wound")
		GameState.status_effects.erase("food_poisoning")
	if item_id == "antiseptic":
		GameState.status_effects.erase("infected_wound")
	if item_id == "cleansing_salt":
		GameState.status_effects.erase("demonic_taint")
	if item_id == "dried_meat" and not GameState.status_effects.has("well_fed"):
		GameState.status_effects.append("well_fed")
	if item_id == "herbal_tea" and not GameState.status_effects.has("well_rested"):
		GameState.status_effects.append("well_rested")
	if item_id == "canned_beans" and TimeSystem.current_day % 11 == 0 and not GameState.status_effects.has("food_poisoning"):
		GameState.status_effects.append("food_poisoning")
	return str(data.get("use_text", data.get("name", item_id) + " verwendet."))


func serialize() -> Dictionary:
	return {
		"items": items,
		"equipped_backpack_id": equipped_backpack_id,
		"slot_capacity": slot_capacity,
		"backpack_slot_capacity": backpack_slot_capacity,
		"clothing_slot_capacity": clothing_slot_capacity,
		"max_weight": max_weight,
		"money": money,
		"equipment": equipment,
		"item_order": item_order,
		"item_condition": item_condition,
		"storage_items": storage_items,
		"storage_order": storage_order,
		"quick_slots": quick_slots
	}


func restore(data: Dictionary) -> void:
	items = data.get("items", {}).duplicate(true)
	equipped_backpack_id = str(data.get("equipped_backpack_id", "small_backpack"))
	money = maxi(0, int(data.get("money", money)))
	_apply_backpack_limits()
	equipment = _empty_equipment()
	var saved_equipment: Dictionary = data.get("equipment", {})
	for slot in saved_equipment:
		if equipment.has(slot):
			equipment[slot] = str(saved_equipment[slot])
	_recalculate_capacity()
	item_order.clear()
	for item_id in data.get("item_order", []):
		item_order.append(str(item_id))
	storage_items = data.get("storage_items", {}).duplicate(true)
	storage_order.clear()
	for item_id in data.get("storage_order", []):
		storage_order.append(str(item_id))
	quick_slots.clear()
	for item_id in data.get("quick_slots", []):
		quick_slots.append(str(item_id))
	while quick_slots.size() < QUICK_SLOT_COUNT:
		quick_slots.append("")
	item_condition = data.get("item_condition", {}).duplicate(true)
	for item_id in items:
		_ensure_condition(str(item_id))
	for item_id in storage_items:
		_ensure_condition(str(item_id))
	for slot in equipment:
		var equipped_id := str(equipment[slot])
		if not equipped_id.is_empty():
			_ensure_condition(equipped_id)
	ordered_items()
	ordered_storage_items()
	_sanitize_quick_slots()
	EventBus.inventory_changed.emit()


func _empty_equipment() -> Dictionary:
	var result := {}
	for slot in EQUIPMENT_SLOTS:
		result[slot] = ""
	return result


func _add_item_direct(item_id: String, amount: int) -> void:
	if not items.has(item_id):
		item_order.append(item_id)
	items[item_id] = int(items.get(item_id, 0)) + amount
	_ensure_condition(item_id)


func _add_storage_direct(item_id: String, amount: int) -> void:
	if not storage_items.has(item_id):
		storage_order.append(item_id)
	storage_items[item_id] = int(storage_items.get(item_id, 0)) + amount
	_ensure_condition(item_id)


func _remove_storage_direct(item_id: String, amount: int) -> bool:
	if int(storage_items.get(item_id, 0)) < amount:
		return false
	storage_items[item_id] = int(storage_items[item_id]) - amount
	if int(storage_items[item_id]) <= 0:
		storage_items.erase(item_id)
		storage_order.erase(item_id)
	return true


func _empty_quick_slots() -> Array[String]:
	var result: Array[String] = []
	for _index in range(QUICK_SLOT_COUNT):
		result.append("")
	return result


func _sanitize_quick_slots() -> void:
	while quick_slots.size() < QUICK_SLOT_COUNT:
		quick_slots.append("")
	for index in range(quick_slots.size()):
		var item_id := str(quick_slots[index])
		if item_id.is_empty():
			continue
		if int(items.get(item_id, 0)) <= 0 or not usable_item(item_id):
			quick_slots[index] = ""


func _ensure_condition(item_id: String) -> void:
	var max_value := max_condition(item_id)
	if max_value <= 0:
		return
	if not item_condition.has(item_id):
		item_condition[item_id] = max_value
	else:
		item_condition[item_id] = clampi(int(item_condition[item_id]), 0, max_value)


func _recalculate_capacity() -> void:
	clothing_slot_capacity = _clothing_capacity_excluding("")
	slot_capacity = maxi(1, backpack_slot_capacity + clothing_slot_capacity)
	max_weight = float(backpack_data().get("max_weight", max_weight)) + _clothing_weight_bonus("")


func _capacity_without_slot(slot_to_ignore: String) -> int:
	return maxi(1, backpack_slot_capacity + _clothing_capacity_excluding(slot_to_ignore))


func _max_weight_without_slot(slot_to_ignore: String) -> float:
	return float(backpack_data().get("max_weight", max_weight)) + _clothing_weight_bonus(slot_to_ignore)


func _clothing_capacity_excluding(slot_to_ignore: String) -> int:
	var total := 0
	for slot in CLOTHING_CONTAINER_SLOTS:
		if slot == slot_to_ignore:
			continue
		var item_id := equipped_item(slot)
		if item_id.is_empty():
			continue
		total += int(DataCatalog.item(item_id).get("pocket_slots", 0))
	return total


func _clothing_weight_bonus(slot_to_ignore: String) -> float:
	var total := 0.0
	for slot in CLOTHING_CONTAINER_SLOTS:
		if slot == slot_to_ignore:
			continue
		var item_id := equipped_item(slot)
		if item_id.is_empty():
			continue
		total += float(DataCatalog.item(item_id).get("carry_weight_bonus", 0.0))
	return total


func _is_stat_bonus_key(key: String) -> bool:
	return key in [
		"damage_bonus", "armor", "shield", "stamina_bonus", "max_stamina_bonus",
		"accuracy", "crafting_bonus", "infection_resist", "strength", "dexterity",
		"intelligence", "vitality", "willpower", "physical_resistance",
		"pierce_resistance", "slash_resistance", "ranged_resistance", "explosive_resistance",
		"magic_resistance", "fire_resistance", "frost_resistance", "lightning_resistance",
		"poison_resistance", "acid_resistance", "bleed_resistance", "light_resistance",
		"shadow_resistance", "soul_resistance", "chaos_resistance", "critical_chance",
		"critical_damage", "critical_resist", "critical_protection", "life_steal",
		"mana_steal", "thorns", "luck", "cooldown_reduction", "buff_power",
		"debuff_power", "armor_pierce", "magic_pierce", "shield_strength",
		"healing_power", "area_damage_bonus"
	]


func _item_sort_key(item_id: String) -> String:
	var data := DataCatalog.item(item_id)
	var category := str(data.get("category", ""))
	var category_order := int(SORT_CATEGORY_ORDER.get(category, 999))
	var rarity_order := 9 - int(data.get("rarity_rank", 1))
	return "%03d_%03d_%s" % [category_order, rarity_order, str(data.get("name", item_id))]


func _default_repair_cost(item_id: String) -> Dictionary:
	var data := DataCatalog.item(item_id)
	var category := str(data.get("category", ""))
	if category == "Fernkampf" or category == "Pistole" or category == "Maschinenpistole" or category == "Sniper":
		return {"metal": 2, "electronics": 1}
	if category == "Wurfgegenstand":
		return {"metal": 1, "powder": 1}
	return {"metal": 1, "cloth": 1}
