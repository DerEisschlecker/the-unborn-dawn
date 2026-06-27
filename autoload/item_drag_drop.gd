# Purpose: Shared drag-and-drop payload and inventory move logic for all gameplay scenes.
# Public API: make_payload(), is_item_payload(), apply_drop(), create_drag_preview().
# Dependencies: InventorySystem, DataCatalog, GameState, UiFactory.
extends Node

const KIND := "inventory_item"


func make_payload(source: String, source_key: String, item_id: String) -> Dictionary:
	return {
		"kind": KIND,
		"item_id": item_id,
		"source": source,
		"source_key": source_key
	}


func is_item_payload(data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == KIND


func create_drag_preview(item_id: String, size: Vector2 = Vector2(52, 52)) -> Control:
	var preview := PanelContainer.new()
	preview.z_index = 4096
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = size + Vector2(6, 6)
	UiFactory.apply_item_rarity_frame(preview, item_id, false, Color(0.02, 0.023, 0.028, 0.96), 5)
	var icon := TextureRect.new()
	icon.texture = load(str(DataCatalog.item(item_id).get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = size
	preview.add_child(icon)
	return preview


func apply_drop(target_source: String, target_key: String, payload: Dictionary) -> String:
	if not is_item_payload(payload):
		return ""
	var item_id := str(payload.get("item_id", ""))
	var source := str(payload.get("source", ""))
	var source_key := str(payload.get("source_key", ""))
	if item_id.is_empty():
		return ""
	match target_source:
		"backpack", "loot_backpack":
			return _drop_to_backpack(item_id, source, source_key, target_key)
		"storage":
			return _drop_to_storage(item_id, source, source_key, target_key)
		"equipment":
			return _equip_from_source(item_id, source, source_key, target_key)
		"quick", "combat_quick":
			return _assign_quick_from_source(item_id, source, source_key, int(target_key))
		"backpack_slot":
			return _equip_backpack_from_source(item_id, source, source_key)
		"sell":
			return _drop_to_trader_sell(item_id, source)
	return ""


func _drop_to_backpack(item_id: String, source: String, source_key: String, target_key: String) -> String:
	if source == "enemy_loot":
		return _take_transient_loot(item_id, 1)
	if source == "admin":
		if InventorySystem.admin_grant_item(item_id, 1):
			return "%s erhalten." % DataCatalog.item(item_id).get("name", item_id)
		return "Kein Platz im Rucksack."
	if source == "storage":
		if InventorySystem.transfer_to_backpack(item_id):
			return "In den Rucksack uebertragen."
		return "Transfer fehlgeschlagen."
	if source == "equipment":
		if InventorySystem.unequip_slot(source_key):
			return "Ausruestung abgelegt."
		return "Ablegen fehlgeschlagen."
	if source in ["quick", "combat_quick"]:
		InventorySystem.clear_quick_slot(int(source_key))
		return "Schnellzugriff geleert."
	if source in ["backpack", "loot_backpack"]:
		if InventorySystem.move_item_to_index(item_id, int(target_key)):
			return "Im Rucksack verschoben."
	return ""


func _drop_to_storage(item_id: String, source: String, source_key: String, target_key: String) -> String:
	if source == "enemy_loot":
		if _take_transient_loot(item_id, 1).is_empty():
			return "Beute konnte nicht genommen werden."
		if InventorySystem.transfer_to_storage(item_id):
			return "Ins Lager gelegt."
		return "Lager voll oder zu schwer."
	if source == "backpack":
		if InventorySystem.transfer_to_storage(item_id):
			return "Ins Lager gelegt."
		return "Lager voll oder zu schwer."
	if source == "equipment":
		var slot_item := InventorySystem.equipped_item(source_key)
		if InventorySystem.unequip_slot(source_key):
			InventorySystem.transfer_to_storage(slot_item)
			return "Ausruestung ins Lager gelegt."
		return "Ablegen fehlgeschlagen."
	if source in ["quick", "combat_quick"]:
		InventorySystem.clear_quick_slot(int(source_key))
		return "Schnellzugriff geleert."
	if source == "storage":
		if InventorySystem.move_storage_item_to_index(item_id, int(target_key)):
			return "Im Lager verschoben."
	return ""


func _equip_from_source(item_id: String, source: String, source_key: String, target_slot: String) -> String:
	var data := DataCatalog.item(item_id)
	if str(data.get("equip_slot", "")) != target_slot:
		return "Passt nicht in diesen Slot."
	if not InventorySystem.item_fits_equipment_slot(item_id, target_slot):
		return InventorySystem.slot_mismatch_message(item_id, target_slot)
	if InventorySystem.is_slot_blocked(target_slot):
		return InventorySystem.slot_block_reason(target_slot)
	if source == "enemy_loot":
		if _take_transient_loot(item_id, 1).is_empty():
			return "Beute konnte nicht genommen werden."
	elif source == "storage" and not InventorySystem.transfer_to_backpack(item_id, 1):
		return "Transfer fehlgeschlagen."
	elif source == "admin" and not InventorySystem.admin_grant_item(item_id, 1):
		return "Kein Platz im Rucksack."
	elif source in ["quick", "combat_quick"]:
		InventorySystem.clear_quick_slot(int(source_key))
	if InventorySystem.equip_item(item_id):
		return "%s angelegt." % data.get("name", item_id)
	return "Anlegen fehlgeschlagen."


func _equip_backpack_from_source(item_id: String, source: String, source_key: String) -> String:
	var data := DataCatalog.item(item_id)
	if not data.has("capacity_slots"):
		return "Kein Rucksack."
	if source == "enemy_loot":
		if _take_transient_loot(item_id, 1).is_empty():
			return "Beute konnte nicht genommen werden."
	elif source == "storage" and not InventorySystem.transfer_to_backpack(item_id, 1):
		return "Transfer fehlgeschlagen."
	elif source == "admin" and not InventorySystem.admin_grant_item(item_id, 1):
		return "Kein Platz im Rucksack."
	elif source in ["quick", "combat_quick"]:
		InventorySystem.clear_quick_slot(int(source_key))
	if InventorySystem.equip_backpack(item_id):
		return "%s ausgeruestet." % data.get("name", item_id)
	return "Rucksackwechsel fehlgeschlagen."


func _assign_quick_from_source(item_id: String, source: String, source_key: String, index: int) -> String:
	if source == "enemy_loot":
		if _take_transient_loot(item_id, 1).is_empty():
			return "Beute konnte nicht genommen werden."
	elif source == "storage" and not InventorySystem.transfer_to_backpack(item_id, 1):
		return "Transfer fehlgeschlagen."
	elif source == "admin" and not InventorySystem.admin_grant_item(item_id, 1):
		return "Kein Platz im Rucksack."
	if source in ["quick", "combat_quick"]:
		var from_index := int(source_key)
		if from_index == index:
			return ""
		var swapped := InventorySystem.quick_slot_item(index)
		InventorySystem.clear_quick_slot(from_index)
		if not InventorySystem.set_quick_slot(index, item_id):
			InventorySystem.set_quick_slot(from_index, item_id)
			return "Schnellzugriff fehlgeschlagen."
		if not swapped.is_empty() and swapped != item_id:
			InventorySystem.set_quick_slot(from_index, swapped)
		return "%s auf Schnellzugriff %d." % [DataCatalog.item(item_id).get("name", item_id), index + 1]
	if InventorySystem.set_quick_slot(index, item_id):
		return "%s auf Schnellzugriff %d." % [DataCatalog.item(item_id).get("name", item_id), index + 1]
	return "Schnellzugriff fehlgeschlagen."


func _drop_to_trader_sell(item_id: String, source: String) -> String:
	if source not in ["backpack", "storage", "equipment", "quick", "combat_quick", "player"]:
		return ""
	return "sell:%s" % item_id


func _take_transient_loot(item_id: String, amount: int) -> String:
	var loot: Dictionary = GameState.transient_loot
	if int(loot.get(item_id, 0)) <= 0:
		return ""
	if not InventorySystem.add_item(item_id, amount):
		return ""
	loot[item_id] = int(loot.get(item_id, 0)) - amount
	if int(loot[item_id]) <= 0:
		loot.erase(item_id)
	GameState.transient_loot = loot
	EventBus.inventory_changed.emit()
	return "%s genommen." % DataCatalog.item(item_id).get("name", item_id)
