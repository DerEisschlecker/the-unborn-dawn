# Purpose: Hotbar ability button that accepts dropped abilities.
# Public API: configure_hotbar(), ability_dropped signal.
# Dependencies: AbilityDragButton.
class_name AbilityHotbarButton
extends AbilityDragButton

signal ability_dropped(ability_id: String, target_slot: int)

var target_slot := -1


func configure_hotbar(id: String, slot_index: int, enabled: bool = true, preview_text: String = "") -> void:
	target_slot = slot_index
	configure_drag(id, slot_index, enabled, preview_text)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "ability" and not str(data.get("ability_id", "")).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ability_dropped.emit(str(data.get("ability_id", "")), target_slot)
