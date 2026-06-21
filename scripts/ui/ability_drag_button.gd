# Purpose: Draggable ability button used by the level screen.
# Public API: configure_drag().
# Dependencies: UiFactory.
class_name AbilityDragButton
extends Button

var ability_id := ""
var source_slot := -1
var drag_enabled := false
var drag_preview_text := ""


func configure_drag(id: String, source: int = -1, enabled: bool = true, preview_text: String = "") -> void:
	ability_id = id
	source_slot = source
	drag_enabled = enabled
	drag_preview_text = preview_text


func _get_drag_data(_at_position: Vector2) -> Variant:
	if ability_id.is_empty() or not drag_enabled or disabled:
		return null
	var preview := PanelContainer.new()
	var style := UiFactory._panel_style()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.94)
	style.border_color = UiFactory.COLOR_GOLD
	preview.add_theme_stylebox_override("panel", style)
	var label := UiFactory.body_label(drag_preview_text if not drag_preview_text.is_empty() else text.replace("\n", " "), 15, UiFactory.COLOR_GOLD)
	label.custom_minimum_size = Vector2(190, 42)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"kind": "ability", "ability_id": ability_id, "source_slot": source_slot}
