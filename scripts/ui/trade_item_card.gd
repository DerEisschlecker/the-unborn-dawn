# Purpose: Compact draggable trade item card with icon, amount, price, rarity frame, and tooltip.
# Public API: configure().
# Dependencies: DataCatalog, UiFactory.
extends PanelContainer

var item_id := ""
var source := ""
var amount := 0
var unit_price := 0
var cart_amount := 0
var click_callback: Callable
var drop_callback: Callable
var _click_armed := false
var _drag_started := false


func configure(
	new_item_id: String,
	new_amount: int,
	new_source: String,
	new_price: int,
	new_callback: Callable,
	new_cart_amount: int = 0,
	new_drop_callback: Callable = Callable()
) -> void:
	item_id = new_item_id
	amount = new_amount
	source = new_source
	unit_price = new_price
	cart_amount = new_cart_amount
	click_callback = new_callback
	drop_callback = new_drop_callback
	_build()


func _build() -> void:
	UiFactory.clear_container(self)
	custom_minimum_size = Vector2(96, 70)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var data := DataCatalog.item(item_id)
	var in_cart := cart_amount > 0 or source in ["buy", "sell"]
	UiFactory.apply_item_rarity_frame(self, item_id, in_cart, Color(0.025, 0.028, 0.034, 0.95), 5)
	UiFactory.attach_item_tooltip(self, item_id, amount, unit_price, _tooltip_context())
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(88, 62)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if cart_amount > 0 and source == "player":
		amount_label.text = "x%d (%d)" % [amount, cart_amount]
	elif source in ["buy", "sell"]:
		amount_label.text = "x%d" % amount
	else:
		amount_label.text = "x%d" % amount
	amount_label.add_theme_font_size_override("font_size", 11)
	amount_label.add_theme_color_override("font_color", Color.WHITE if cart_amount <= 0 else UiFactory.COLOR_GOLD)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(amount_label)
	var price := Label.new()
	price.text = "%d DC" % unit_price
	price.add_theme_font_size_override("font_size", 11)
	price.add_theme_color_override("font_color", UiFactory.COLOR_GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	price.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(price)


func _tooltip_context() -> String:
	match source:
		"trader", "buy":
			return "Kaufen (Links +1, Rechts alle)"
		"player", "sell":
			return "Verkaufen (Links +1, Rechts alle)"
	return "Handel"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_armed = true
			_drag_started = false
		elif _click_armed and click_callback.is_valid():
			_click_armed = false
			if not _drag_started:
				accept_event()
				click_callback.call(item_id, source, event)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or amount <= 0:
		return null
	_drag_started = true
	_click_armed = false
	if source == "player":
		var preview := ItemDragDrop.create_drag_preview(item_id)
		set_drag_preview(preview)
		return ItemDragDrop.make_payload("backpack", item_id, item_id)
	if source not in ["trader", "buy", "sell"]:
		return null
	var preview := TextureRect.new()
	preview.texture = load(str(DataCatalog.item(item_id).get("icon", "res://icon.svg")))
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(52, 52)
	set_drag_preview(preview)
	return {"kind": "trade_item", "item_id": item_id, "source": source}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drop_callback.is_valid() and _accepts_drop(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _accepts_drop(data):
		return
	var payload: Dictionary = data
	if drop_callback.is_valid():
		drop_callback.call(str(payload.get("item_id", "")), str(payload.get("source", "")))


func _accepts_drop(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	if ItemDragDrop.is_item_payload(data):
		match source:
			"sell":
				return str(payload.get("source", "")) in ["player", "backpack", "trader"]
			"buy":
				return str(payload.get("source", "")) in ["trader", "backpack"]
		return false
	if str(payload.get("kind", "")) != "trade_item":
		return false
	match source:
		"sell":
			return str(payload.get("source", "")) in ["player", "backpack", "trader"]
		"buy":
			return str(payload.get("source", "")) in ["trader", "backpack"]
	return false
