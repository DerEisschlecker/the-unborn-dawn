# Purpose: Lightweight data holder for a recruited survivor and their passive base role.
# Public API: configure() and daily_contribution().
# Dependencies: GameState and InventorySystem.
extends Node

var survivor_id := ""
var display_name := ""
var role := "waechter"


func configure(id: String, name_text: String, assigned_role: String) -> void:
	survivor_id = id
	display_name = name_text
	role = assigned_role


func daily_contribution() -> String:
	match role:
		"sammler":
			InventorySystem.add_item("wood", 1)
			return "%s bringt Holz zurueck." % display_name
		"arzt":
			GameState.elena.health = minf(float(GameState.elena.max_health), float(GameState.elena.health) + 3.0)
			return "%s behandelt Elenas Beschwerden." % display_name
		_:
			return "%s uebernimmt die Nachtwache." % display_name
