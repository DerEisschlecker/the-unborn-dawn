# Purpose: Reusable inventory slot with click, drag, and drop signals.
# Public API: configure(), set_slot_style().
# Dependencies: DataCatalog and UiFactory.
extends PanelContainer

signal slot_clicked(source: String, slot_key: String, item_id: String, event: InputEventMouseButton)
signal item_dropped(target_source: String, target_key: String, item_id: String, source: String, source_key: String)

var source_id := ""
var slot_key := ""
var item_id := ""
var accepts_items := true
var drag_enabled := true


func configure(new_source: String, new_key: String, new_item_id: String, accepts_drop: bool = true, can_drag: bool = true) -> void:
	source_id = new_source
	slot_key = new_key
	item_id = new_item_id
	accepts_items = accepts_drop
	drag_enabled = can_drag
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(source_id, slot_key, item_id, event)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or not drag_enabled:
		return null
	var data := DataCatalog.item(item_id)
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(58, 58)
	UiFactory.apply_item_rarity_frame(preview, item_id, false, Color(0.02, 0.023, 0.028, 0.96), 5)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	preview.add_child(icon)
	set_drag_preview(preview)
	return {
		"kind": "inventory_item",
		"item_id": item_id,
		"source": source_id,
		"source_key": slot_key
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_items and typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "inventory_item"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	item_dropped.emit(
		source_id,
		slot_key,
		str(data.get("item_id", "")),
		str(data.get("source", "")),
		str(data.get("source_key", ""))
	)
