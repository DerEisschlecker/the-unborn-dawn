# Purpose: Reusable logical loot container with a one-time search state.
# Public API: search() returns an item entry from its assigned loot table.
# Dependencies: DataCatalog location loot entries.
extends Node

@export var loot_table: Array[String] = []
var searched := false


func search(seed_value: int = 0) -> Dictionary:
	if searched or loot_table.is_empty():
		return {}
	searched = true
	var item_id := loot_table[absi(seed_value) % loot_table.size()]
	return {"item_id": item_id, "amount": 1 + absi(seed_value) % 2}

