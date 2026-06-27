# Purpose: Drag-and-drop basket for the trader screen.
# Public API: configure(), set_title(), set_accepts().
# Dependencies: UiFactory.
extends PanelContainer

var zone := ""
var accepted_sources: Array = []
var drop_callback: Callable
var title_label: Label
var grid: GridContainer


func configure(new_zone: String, sources: Array, callback: Callable) -> void:
	zone = new_zone
	accepted_sources = sources.duplicate()
	drop_callback = callback
	_build()


func set_title(value: String) -> void:
	if is_instance_valid(title_label):
		title_label.text = value


func set_accepts(sources: Array) -> void:
	accepted_sources = sources.duplicate()


func _build() -> void:
	UiFactory.clear_container(self)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiFactory._panel_style()
	style.bg_color = Color(0.025, 0.03, 0.038, 0.95)
	style.border_color = Color(0.46, 0.38, 0.24, 0.86)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	title_label = UiFactory.body_label("", 15, UiFactory.COLOR_GOLD)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(grid)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if ItemDragDrop.is_item_payload(data):
		var payload: Dictionary = data
		if zone == "sell":
			return str(payload.get("source", "")) in ["backpack", "storage", "equipment", "quick", "combat_quick", "player"]
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	return str(payload.get("kind", "")) == "trade_item" and accepted_sources.has(str(payload.get("source", "")))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if ItemDragDrop.is_item_payload(data):
		var payload: Dictionary = data
		if drop_callback.is_valid():
			drop_callback.call(zone, str(payload.get("item_id", "")), str(payload.get("source", "")))
		return
	if not _can_drop_data(_at_position, data):
		return
	var payload: Dictionary = data
	if drop_callback.is_valid():
		drop_callback.call(zone, str(payload.get("item_id", "")), str(payload.get("source", "")))
