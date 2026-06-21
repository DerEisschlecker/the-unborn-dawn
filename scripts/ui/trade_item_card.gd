# Purpose: Compact draggable trade item card with icon, amount, price, rarity frame, and tooltip.
# Public API: configure().
# Dependencies: DataCatalog, UiFactory.
extends PanelContainer

var item_id := ""
var source := ""
var amount := 0
var unit_price := 0
var click_callback: Callable


func configure(new_item_id: String, new_amount: int, new_source: String, new_price: int, new_callback: Callable) -> void:
	item_id = new_item_id
	amount = new_amount
	source = new_source
	unit_price = new_price
	click_callback = new_callback
	_build()


func _build() -> void:
	UiFactory.clear_container(self)
	custom_minimum_size = Vector2(96, 70)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var data := DataCatalog.item(item_id)
	UiFactory.apply_item_rarity_frame(self, item_id, false, Color(0.025, 0.028, 0.034, 0.95), 5)
	UiFactory.attach_item_tooltip(self, item_id, amount, unit_price, "Kaufen" if source == "trader" or source == "buy" else "Verkaufen")
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(88, 62)
	add_child(stack)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -20
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	var amount_label := Label.new()
	amount_label.text = "x%d" % amount
	amount_label.add_theme_font_size_override("font_size", 11)
	amount_label.add_theme_color_override("font_color", Color.WHITE)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(amount_label)
	var price := Label.new()
	price.text = "%d C" % unit_price
	price.add_theme_font_size_override("font_size", 11)
	price.add_theme_color_override("font_color", UiFactory.COLOR_GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	price.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(price)


func _tooltip(data: Dictionary) -> String:
	var lines: Array[String] = [
		str(data.get("name", item_id)),
		"%s - %s" % [data.get("category", "Item"), UiFactory.rarity_label(data)],
		"Wert: %d C   Preis: %d C" % [DataCatalog.item_value(item_id), unit_price]
	]
	if not str(data.get("description", "")).is_empty():
		lines.append(str(data.get("description", "")))
	if data.has("effects"):
		var effect_parts: Array[String] = []
		var effects: Dictionary = data.get("effects", {})
		for stat_name in effects:
			effect_parts.append("%s %+d" % [str(stat_name).capitalize(), int(effects[stat_name])])
		lines.append("Benutzen: %s" % ", ".join(effect_parts))
	if data.has("damage"):
		lines.append("Schaden: %d" % int(data.get("damage", 0)))
	if data.has("armor"):
		lines.append("Ruestung: %d" % int(data.get("armor", 0)))
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click_callback.is_valid():
			click_callback.call(item_id, source)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or amount <= 0:
		return null
	var preview := TextureRect.new()
	preview.texture = load(str(DataCatalog.item(item_id).get("icon", "res://icon.svg")))
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(52, 52)
	set_drag_preview(preview)
	return {"kind": "trade_item", "item_id": item_id, "source": source}
