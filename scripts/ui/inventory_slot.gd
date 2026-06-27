# Purpose: Reusable inventory slot with click, drag-and-drop (left-hold), and drop signals.
# Public API: configure(), decorate().
# Dependencies: DataCatalog, UiFactory, ItemDragDrop.
extends PanelContainer

signal slot_clicked(source: String, slot_key: String, item_id: String, event: InputEventMouseButton)
signal item_dropped(target_source: String, target_key: String, item_id: String, source: String, source_key: String)

var source_id := ""
var slot_key := ""
var item_id := ""
var accepts_items := true
var drag_enabled := true
var _click_armed := false
var _drag_started := false


func configure(new_source: String, new_key: String, new_item_id: String, accepts_drop: bool = true, can_drag: bool = true) -> void:
	source_id = new_source
	slot_key = new_key
	item_id = new_item_id
	accepts_items = accepts_drop
	drag_enabled = can_drag and not new_item_id.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP


func decorate(amount: int = 0, selected: bool = false, tooltip_context: String = "") -> void:
	UiFactory.clear_container(self)
	if item_id.is_empty():
		return
	var data := DataCatalog.item(item_id)
	UiFactory.apply_item_rarity_frame(self, item_id, selected, Color(0.018, 0.021, 0.026, 0.94), 4)
	var context := tooltip_context if not tooltip_context.is_empty() else source_id.capitalize()
	UiFactory.attach_item_tooltip(self, item_id, maxi(1, amount), -1, context)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -10 if amount > 1 else -3
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	if amount > 1:
		var count := Label.new()
		count.text = str(amount)
		count.add_theme_font_size_override("font_size", 11)
		count.add_theme_color_override("font_color", Color.WHITE)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -4
		count.offset_bottom = -2
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(count)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_armed = true
			_drag_started = false
		elif _click_armed:
			_click_armed = false
			if not _drag_started:
				slot_clicked.emit(source_id, slot_key, item_id, event)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or not drag_enabled:
		return null
	_drag_started = true
	_click_armed = false
	var preview := ItemDragDrop.create_drag_preview(item_id, custom_minimum_size)
	preview.z_index = 4096
	set_drag_preview(preview)
	return ItemDragDrop.make_payload(source_id, slot_key, item_id)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_items and ItemDragDrop.is_item_payload(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var payload: Dictionary = data
	item_dropped.emit(
		source_id,
		slot_key,
		str(payload.get("item_id", "")),
		str(payload.get("source", "")),
		str(payload.get("source_key", ""))
	)
