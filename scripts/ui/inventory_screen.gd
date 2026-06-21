# Purpose: Popup inventory overlay with backpack, equipment, quick access, and base storage.
# Public API: Drag/drop items, split stacks, quick transfer, use/equip, and close with Escape.
# Dependencies: InventorySystem, DataCatalog, GameState, UiFactory, InventorySlot.
extends Control

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const GRID_COLUMNS := 7
const GRID_ROWS := 8
const GRID_SLOT_COUNT := GRID_COLUMNS * GRID_ROWS

var slot_size := Vector2(44, 44)
var compact_screen := false
var backpack_grid: GridContainer
var storage_grid: GridContainer
var quick_grid: GridContainer
var equipment_layer: Control
var backpack_weight_bar: ProgressBar
var storage_weight_bar: ProgressBar
var backpack_weight_label: Label
var storage_weight_label: Label
var backpack_title: Label
var storage_title: Label
var status_label: Label
var action_row: HBoxContainer
var selected_item_id := ""
var selected_source := ""
var selected_key := ""


func _ready() -> void:
	compact_screen = UiFactory.is_compact_screen()
	slot_size = Vector2(32, 32) if compact_screen else Vector2(44, 44)
	_build_screen()
	EventBus.inventory_changed.connect(_refresh)
	EventBus.stats_changed.connect(_refresh)
	_refresh()


func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var visible_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		minf(visible_size.x * (0.86 if compact_screen else 0.74), 1280.0),
		minf(visible_size.y * (0.82 if compact_screen else 0.78), 820.0)
	)
	panel.add_theme_stylebox_override("panel", _main_panel_style())
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8 if compact_screen else 14)
	panel.add_child(root)
	var title := UiFactory.title_label("INVENTAR", 28 if compact_screen else 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12 if compact_screen else 24)
	root.add_child(body)
	_build_backpack_panel(body)
	_build_center_panel(body)
	_build_storage_panel(body)
	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 6 if compact_screen else 10)
	root.add_child(action_row)
	status_label = UiFactory.body_label("Shift + Rechtsklick: Stapel teilen   |   Strg + Rechtsklick: schnell uebertragen   |   ESC: Schliessen", 11 if compact_screen else 15, UiFactory.COLOR_MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root.add_child(status_label)


func _build_backpack_panel(parent: HBoxContainer) -> void:
	var box := _section_panel("RUCKSACK", "Trage deine Gegenstaende bei dir.")
	parent.add_child(box.get_parent())
	backpack_title = box.get_node("Title") as Label
	backpack_grid = _grid()
	box.add_child(backpack_grid)
	var footer := _weight_footer("Gewicht", true)
	box.add_child(footer)


func _build_storage_panel(parent: HBoxContainer) -> void:
	var box := _section_panel("LAGER", "Verstau hier deine Gegenstaende.")
	parent.add_child(box.get_parent())
	storage_title = box.get_node("Title") as Label
	storage_grid = _grid()
	box.add_child(storage_grid)
	var footer := _weight_footer("Gewicht", false)
	box.add_child(footer)


func _build_center_panel(parent: HBoxContainer) -> void:
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 270 if compact_screen else 380
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10 if compact_screen else 16)
	parent.add_child(center)
	var equipment_panel := PanelContainer.new()
	equipment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_panel.add_theme_stylebox_override("panel", _section_style())
	center.add_child(equipment_panel)
	var equipment_box := VBoxContainer.new()
	equipment_box.add_theme_constant_override("separation", 8 if compact_screen else 12)
	equipment_panel.add_child(equipment_box)
	var equipment_title := UiFactory.body_label("AUSRUESTUNG", 13 if compact_screen else 17, UiFactory.COLOR_GOLD)
	equipment_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	equipment_box.add_child(equipment_title)
	equipment_layer = Control.new()
	equipment_layer.custom_minimum_size = Vector2(250, 310) if compact_screen else Vector2(340, 420)
	equipment_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_box.add_child(equipment_layer)
	var quick_panel := PanelContainer.new()
	quick_panel.add_theme_stylebox_override("panel", _section_style())
	center.add_child(quick_panel)
	var quick_box := VBoxContainer.new()
	quick_box.add_theme_constant_override("separation", 7)
	quick_panel.add_child(quick_box)
	var quick_title := UiFactory.body_label("SCHNELLZUGRIFF", 13 if compact_screen else 16, UiFactory.COLOR_GOLD)
	quick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_box.add_child(quick_title)
	quick_grid = GridContainer.new()
	quick_grid.columns = InventorySystem.QUICK_SLOT_COUNT
	quick_grid.add_theme_constant_override("h_separation", 4)
	quick_grid.add_theme_constant_override("v_separation", 4)
	quick_box.add_child(quick_grid)


func _section_panel(title: String, subtitle: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _section_style())
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8 if compact_screen else 12)
	panel.add_child(box)
	var title_label := UiFactory.body_label(title, 17 if compact_screen else 22, UiFactory.COLOR_GOLD)
	title_label.name = "Title"
	box.add_child(title_label)
	box.add_child(UiFactory.body_label(subtitle, 10 if compact_screen else 14, UiFactory.COLOR_MUTED))
	return box


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4 if compact_screen else 6)
	grid.add_theme_constant_override("v_separation", 4 if compact_screen else 6)
	return grid


func _weight_footer(label_text: String, backpack: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := UiFactory.body_label("B", 14, UiFactory.COLOR_GOLD)
	icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	icon.custom_minimum_size.x = 18
	row.add_child(icon)
	var label := UiFactory.body_label(label_text, 12 if compact_screen else 15, Color("#d8dde8"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 58 if compact_screen else 76
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(120, 10 if compact_screen else 14)
	bar.add_theme_stylebox_override("background", _bar_bg())
	bar.add_theme_stylebox_override("fill", _bar_fill(Color("#7ccf6b")))
	row.add_child(bar)
	var value := UiFactory.body_label("", 11 if compact_screen else 14, Color("#d8dde8"))
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.custom_minimum_size.x = 96 if compact_screen else 126
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	if backpack:
		backpack_weight_bar = bar
		backpack_weight_label = value
	else:
		storage_weight_bar = bar
		storage_weight_label = value
	return row


func _refresh() -> void:
	_validate_selection()
	_refresh_grids()
	_refresh_equipment()
	_refresh_quick_slots()
	_refresh_weight()
	_refresh_actions()


func _refresh_grids() -> void:
	UiFactory.clear_container(backpack_grid)
	UiFactory.clear_container(storage_grid)
	var backpack_items := InventorySystem.sorted_items_for_layout()
	var storage_items := InventorySystem.sorted_storage_items_for_layout()
	var backpack_active := mini(GRID_SLOT_COUNT, InventorySystem.slot_capacity)
	var storage_active := mini(GRID_SLOT_COUNT, InventorySystem.storage_slot_capacity())
	for index in range(GRID_SLOT_COUNT):
		var item_id := str(backpack_items[index]) if index < backpack_items.size() else ""
		backpack_grid.add_child(_slot("backpack", str(index), item_id, index < backpack_active, int(InventorySystem.items.get(item_id, 0))))
	for index in range(GRID_SLOT_COUNT):
		var item_id := str(storage_items[index]) if index < storage_items.size() else ""
		storage_grid.add_child(_slot("storage", str(index), item_id, index < storage_active, int(InventorySystem.storage_items.get(item_id, 0))))


func _refresh_equipment() -> void:
	UiFactory.clear_container(equipment_layer)
	var w := 250.0 if compact_screen else 340.0
	var h := 310.0 if compact_screen else 420.0
	var specs := [
		{"slot": "head", "pos": Vector2(0.40, 0.02), "size": Vector2(0.20, 0.17)},
		{"slot": "firearm", "pos": Vector2(0.05, 0.26), "size": Vector2(0.22, 0.28)},
		{"slot": "vest", "pos": Vector2(0.40, 0.23), "size": Vector2(0.20, 0.17)},
		{"slot": "shield", "pos": Vector2(0.73, 0.26), "size": Vector2(0.22, 0.28)},
		{"slot": "pants", "pos": Vector2(0.40, 0.44), "size": Vector2(0.20, 0.17)},
		{"slot": "gloves", "pos": Vector2(0.20, 0.66), "size": Vector2(0.18, 0.16)},
		{"slot": "shoes", "pos": Vector2(0.42, 0.66), "size": Vector2(0.18, 0.16)},
		{"slot": "ring", "pos": Vector2(0.64, 0.66), "size": Vector2(0.18, 0.16)},
		{"slot": "belt", "pos": Vector2(0.32, 0.86), "size": Vector2(0.19, 0.13)},
		{"slot": "amulet", "pos": Vector2(0.55, 0.86), "size": Vector2(0.19, 0.13)}
	]
	for spec in specs:
		var rect := Rect2(Vector2(w, h) * spec.get("pos", Vector2.ZERO), Vector2(w, h) * spec.get("size", Vector2(0.18, 0.15)))
		var panel := _equipment_slot(str(spec.get("slot", "")), rect)
		equipment_layer.add_child(panel)


func _refresh_quick_slots() -> void:
	UiFactory.clear_container(quick_grid)
	var ids := InventorySystem.quick_slot_items()
	for index in range(InventorySystem.QUICK_SLOT_COUNT):
		var item_id := str(ids[index]) if index < ids.size() else ""
		var slot := _slot("quick", str(index), item_id, true, int(InventorySystem.items.get(item_id, 0)), true)
		var number := Label.new()
		number.text = str(index + 1)
		number.add_theme_font_size_override("font_size", 10)
		number.add_theme_color_override("font_color", Color("#e7d5aa"))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number.offset_right = -4
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(number)
		quick_grid.add_child(slot)


func _refresh_weight() -> void:
	var backpack := InventorySystem.backpack_data()
	backpack_title.text = "RUCKSACK - %s" % backpack.get("name", "Rucksack")
	storage_title.text = "LAGER - Truhen %d" % int(GameState.base_state.get("structures", {}).get("storage_chest", 0))
	_set_bar(backpack_weight_bar, backpack_weight_label, InventorySystem.current_weight(), InventorySystem.max_weight)
	_set_bar(storage_weight_bar, storage_weight_label, InventorySystem.storage_current_weight(), InventorySystem.storage_max_weight())


func _slot(source: String, key: String, item_id: String, active: bool, amount: int = 0, quick: bool = false) -> PanelContainer:
	var panel: PanelContainer = InventorySlotScript.new()
	panel.custom_minimum_size = slot_size
	panel.configure(source, key, item_id, active, not item_id.is_empty())
	panel.slot_clicked.connect(_on_slot_clicked)
	panel.item_dropped.connect(_on_item_dropped)
	panel.add_theme_stylebox_override("panel", _slot_style(active, item_id == selected_item_id and not item_id.is_empty()))
	if not active:
		panel.tooltip_text = "Durch groesseren Rucksack oder Lagerausbau freischalten."
		return panel
	if item_id.is_empty():
		panel.tooltip_text = "Leer"
		return panel
	var data := DataCatalog.item(item_id)
	UiFactory.apply_item_rarity_frame(panel, item_id, item_id == selected_item_id, Color(0.018, 0.021, 0.026, 0.94), 4)
	UiFactory.attach_item_tooltip(panel, item_id, amount, -1, "Schnellzugriff" if quick else source.capitalize())
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -10 if amount > 1 else -3
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	if amount > 1:
		var count := Label.new()
		count.text = str(amount)
		count.add_theme_font_size_override("font_size", 10 if compact_screen else 12)
		count.add_theme_color_override("font_color", Color.WHITE)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -4
		count.offset_bottom = -2
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)
	return panel


func _equipment_slot(slot_id: String, rect: Rect2) -> PanelContainer:
	var item_id := InventorySystem.equipped_item(slot_id)
	var panel: PanelContainer = InventorySlotScript.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	panel.configure("equipment", slot_id, item_id, true, not item_id.is_empty())
	panel.slot_clicked.connect(_on_slot_clicked)
	panel.item_dropped.connect(_on_item_dropped)
	panel.add_theme_stylebox_override("panel", _equipment_style(item_id == selected_item_id and not item_id.is_empty()))
	if item_id.is_empty():
		panel.tooltip_text = str(InventorySystem.EQUIPMENT_SLOTS.get(slot_id, {}).get("name", slot_id))
		_add_empty_equipment_preview(panel, slot_id)
		return panel
	var data := DataCatalog.item(item_id)
	UiFactory.apply_item_rarity_frame(panel, item_id, item_id == selected_item_id, Color(0.018, 0.021, 0.026, 0.94), 5)
	UiFactory.attach_item_tooltip(panel, item_id, 1, -1, str(InventorySystem.EQUIPMENT_SLOTS.get(slot_id, {}).get("name", slot_id)))
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return panel


func _add_empty_equipment_preview(panel: PanelContainer, slot_id: String) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var label := UiFactory.body_label(_slot_preview_text(slot_id), 7 if compact_screen else 10, Color(0.52, 0.55, 0.60, 0.92))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	var icon := TextureRect.new()
	icon.texture = load(_slot_preview_icon(slot_id))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(0.58, 0.61, 0.66, 0.28)
	icon.custom_minimum_size = Vector2(26, 26) if compact_screen else Vector2(38, 38)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)


func _equipped_backpack_slot(rect: Rect2) -> PanelContainer:
	var panel: PanelContainer = InventorySlotScript.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	panel.configure("backpack_slot", "backpack", InventorySystem.equipped_backpack_id, true, false)
	panel.slot_clicked.connect(_on_slot_clicked)
	panel.item_dropped.connect(_on_item_dropped)
	UiFactory.apply_item_rarity_frame(panel, InventorySystem.equipped_backpack_id, false, Color(0.018, 0.021, 0.026, 0.94), 5)
	UiFactory.attach_item_tooltip(panel, InventorySystem.equipped_backpack_id, 1, -1, "Ausgeruesteter Rucksack")
	var icon := TextureRect.new()
	icon.texture = load(str(InventorySystem.backpack_data().get("icon", "res://assets/items/backpacks/small_backpack.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return panel


func _on_slot_clicked(source: String, key: String, item_id: String, event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not item_id.is_empty():
			_set_selection(source, key, item_id)
			status_label.text = _selected_text(item_id, source)
			if event.double_click:
				_primary_action(source, key, item_id)
			_refresh()
		return
	if event.button_index != MOUSE_BUTTON_RIGHT:
		return
	_set_selection(source, key, item_id)
	if event.shift_pressed:
		_split_stack(source, item_id)
	elif event.ctrl_pressed:
		_quick_transfer(source, key, item_id)
	else:
		_primary_action(source, key, item_id)
	_refresh()


func _on_item_dropped(target_source: String, target_key: String, item_id: String, source: String, source_key: String) -> void:
	if item_id.is_empty():
		return
	if target_source == "backpack":
		_drop_to_backpack(item_id, source, source_key, target_key)
	elif target_source == "storage":
		_drop_to_storage(item_id, source, source_key, target_key)
	elif target_source == "equipment":
		_equip_from_source(item_id, source, target_key)
	elif target_source == "quick":
		_assign_quick_from_source(item_id, source, int(target_key))
	elif target_source == "backpack_slot":
		_equip_backpack_from_source(item_id, source)
	_refresh()


func _primary_action(source: String, key: String, item_id: String) -> void:
	if item_id.is_empty():
		return
	if source == "equipment":
		if InventorySystem.unequip_slot(key):
			status_label.text = "Ausrustung abgelegt."
		return
	if source == "quick":
		InventorySystem.clear_quick_slot(int(key))
		status_label.text = "Schnellzugriff geleert."
		return
	if source == "storage":
		InventorySystem.transfer_to_backpack(item_id)
		status_label.text = "In den Rucksack uebertragen."
		return
	var data := DataCatalog.item(item_id)
	if data.has("effects"):
		status_label.text = InventorySystem.use_item(item_id)
	elif data.has("capacity_slots"):
		_equip_backpack_from_source(item_id, source)
	elif data.has("equip_slot"):
		_equip_from_source(item_id, source, str(data.get("equip_slot", "")))
	else:
		status_label.text = _selected_text(item_id, source)


func _split_stack(source: String, item_id: String) -> void:
	if item_id.is_empty():
		return
	if InventorySystem.split_stack_to_other_container(item_id, source):
		status_label.text = "Stapel geteilt."
	else:
		status_label.text = "Stapel konnte nicht geteilt werden."


func _quick_transfer(source: String, key: String, item_id: String) -> void:
	if item_id.is_empty():
		return
	if source == "backpack":
		InventorySystem.transfer_to_storage(item_id)
	elif source == "storage":
		InventorySystem.transfer_to_backpack(item_id)
	elif source == "equipment":
		InventorySystem.unequip_slot(key)
	elif source == "quick":
		InventorySystem.clear_quick_slot(int(key))
	status_label.text = "Schnell uebertragen."


func _drop_to_backpack(item_id: String, source: String, source_key: String, target_key: String) -> void:
	if source == "storage":
		InventorySystem.transfer_to_backpack(item_id)
	elif source == "equipment":
		InventorySystem.unequip_slot(source_key)
	elif source == "quick":
		InventorySystem.clear_quick_slot(int(source_key))
	elif source == "backpack":
		InventorySystem.move_item_to_index(item_id, int(target_key))


func _drop_to_storage(item_id: String, source: String, source_key: String, target_key: String) -> void:
	if source == "backpack":
		InventorySystem.transfer_to_storage(item_id)
	elif source == "equipment":
		var slot_item := InventorySystem.equipped_item(source_key)
		if InventorySystem.unequip_slot(source_key):
			InventorySystem.transfer_to_storage(slot_item)
	elif source == "quick":
		InventorySystem.clear_quick_slot(int(source_key))
	elif source == "storage":
		InventorySystem.move_storage_item_to_index(item_id, int(target_key))


func _equip_from_source(item_id: String, source: String, target_slot: String) -> void:
	var data := DataCatalog.item(item_id)
	if str(data.get("equip_slot", "")) != target_slot:
		status_label.text = "Dieser Gegenstand passt nicht in diesen Ausruestungsslot."
		return
	if source == "storage" and not InventorySystem.transfer_to_backpack(item_id, 1):
		return
	if InventorySystem.equip_item(item_id):
		status_label.text = "%s angelegt." % data.get("name", item_id)


func _equip_backpack_from_source(item_id: String, source: String) -> void:
	var data := DataCatalog.item(item_id)
	if not data.has("capacity_slots"):
		status_label.text = "Das ist kein Rucksack."
		return
	if source == "storage" and not InventorySystem.transfer_to_backpack(item_id, 1):
		return
	if InventorySystem.equip_backpack(item_id):
		status_label.text = "%s ausgeruestet." % data.get("name", item_id)


func _assign_quick_from_source(item_id: String, source: String, index: int) -> void:
	if source == "storage" and not InventorySystem.transfer_to_backpack(item_id, 1):
		return
	if InventorySystem.set_quick_slot(index, item_id):
		status_label.text = "%s auf Schnellzugriff %d gelegt." % [DataCatalog.item(item_id).get("name", item_id), index + 1]


func _selected_text(item_id: String, source: String) -> String:
	var data := DataCatalog.item(item_id)
	return "%s - %s - %.2f kg - %s" % [
		data.get("name", item_id),
		source.capitalize(),
		float(data.get("weight", 0.0)),
		str(data.get("description", ""))
	]


func _refresh_actions() -> void:
	if not is_instance_valid(action_row):
		return
	UiFactory.clear_container(action_row)
	var summary := UiFactory.body_label("Item auswaehlen", 10 if compact_screen else 13, UiFactory.COLOR_MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.custom_minimum_size.x = 180 if compact_screen else 260
	action_row.add_child(summary)
	if selected_item_id.is_empty():
		return
	var data := DataCatalog.item(selected_item_id)
	summary.text = "%s | %s" % [data.get("name", selected_item_id), selected_source.capitalize()]
	if selected_source == "backpack":
		if data.has("effects"):
			action_row.add_child(_action_button("Verwenden", func() -> void: _use_selected()))
		if data.has("capacity_slots") or data.has("equip_slot"):
			action_row.add_child(_action_button("Anlegen", func() -> void: _equip_selected()))
		action_row.add_child(_action_button("Ins Lager", func() -> void: _transfer_selected()))
		action_row.add_child(_action_button("Entsorgen", func() -> void: _discard_selected(), true))
	elif selected_source == "storage":
		action_row.add_child(_action_button("Nehmen", func() -> void: _transfer_selected()))
		action_row.add_child(_action_button("Teilen", func() -> void: _split_selected()))
		action_row.add_child(_action_button("Entsorgen", func() -> void: _discard_selected(), true))
	elif selected_source == "equipment":
		action_row.add_child(_action_button("Ablegen", func() -> void: _unequip_selected()))
	elif selected_source == "quick":
		if data.has("effects"):
			action_row.add_child(_action_button("Verwenden", func() -> void: _use_selected()))
		action_row.add_child(_action_button("Leeren", func() -> void: _clear_quick_selected()))


func _action_button(text: String, callback: Callable, danger: bool = false) -> Button:
	var button := UiFactory.button(text, callback, 78 if compact_screen else 110)
	button.custom_minimum_size = Vector2(78 if compact_screen else 110, 30 if compact_screen else 36)
	button.add_theme_font_size_override("font_size", 10 if compact_screen else 13)
	if danger:
		button.add_theme_color_override("font_color", Color("#f2b3ac"))
	return button


func _set_selection(source: String, key: String, item_id: String) -> void:
	selected_item_id = item_id
	selected_source = source
	selected_key = key


func _validate_selection() -> void:
	if selected_item_id.is_empty():
		return
	if DataCatalog.item(selected_item_id).is_empty():
		_clear_selection()
		return
	if selected_source == "backpack" and int(InventorySystem.items.get(selected_item_id, 0)) <= 0:
		_clear_selection()
	elif selected_source == "storage" and int(InventorySystem.storage_items.get(selected_item_id, 0)) <= 0:
		_clear_selection()
	elif selected_source == "equipment" and InventorySystem.equipped_item(selected_key) != selected_item_id:
		_clear_selection()
	elif selected_source == "quick" and InventorySystem.quick_slot_item(int(selected_key)) != selected_item_id:
		_clear_selection()


func _clear_selection() -> void:
	selected_item_id = ""
	selected_source = ""
	selected_key = ""


func _use_selected() -> void:
	if selected_item_id.is_empty():
		return
	status_label.text = InventorySystem.use_item(selected_item_id)
	_refresh()


func _equip_selected() -> void:
	if selected_item_id.is_empty():
		return
	var data := DataCatalog.item(selected_item_id)
	if data.has("capacity_slots"):
		_equip_backpack_from_source(selected_item_id, selected_source)
	elif data.has("equip_slot"):
		_equip_from_source(selected_item_id, selected_source, str(data.get("equip_slot", "")))
	_refresh()


func _transfer_selected() -> void:
	if selected_item_id.is_empty():
		return
	if selected_source == "backpack":
		InventorySystem.transfer_to_storage(selected_item_id)
	elif selected_source == "storage":
		InventorySystem.transfer_to_backpack(selected_item_id)
	_refresh()


func _split_selected() -> void:
	_split_stack(selected_source, selected_item_id)
	_refresh()


func _discard_selected() -> void:
	if selected_item_id.is_empty():
		return
	if selected_source == "backpack":
		InventorySystem.discard_item(selected_item_id, 1)
	elif selected_source == "storage":
		InventorySystem.discard_storage_item(selected_item_id, 1)
	_refresh()


func _unequip_selected() -> void:
	if selected_source == "equipment" and InventorySystem.unequip_slot(selected_key):
		status_label.text = "Ausrustung abgelegt."
	_refresh()


func _clear_quick_selected() -> void:
	if selected_source == "quick" and InventorySystem.clear_quick_slot(int(selected_key)):
		status_label.text = "Schnellzugriff geleert."
	_refresh()


func _set_bar(bar: ProgressBar, label: Label, value: float, maximum: float) -> void:
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(value, 0.0, bar.max_value)
	label.text = "%.1f / %.1f kg" % [value, maximum]
	var ratio := value / maxf(1.0, maximum)
	bar.add_theme_stylebox_override("fill", _bar_fill(Color("#d9685f") if ratio > 0.92 else (Color("#d8b36a") if ratio > 0.72 else Color("#7ccf6b"))))


func _slot_preview_text(slot_id: String) -> String:
	match slot_id:
		"head":
			return "Helm"
		"mask":
			return "Maske"
		"jacket":
			return "Jacke"
		"vest":
			return "Brust"
		"pants":
			return "Beine"
		"gloves":
			return "Handschuhe"
		"shoes":
			return "Stiefel"
		"shield":
			return "Schild"
		"tool":
			return "Axt"
		"melee":
			return "Nahkampf"
		"firearm":
			return "Waffe"
		"throwable":
			return "Wurf"
		"ring":
			return "Ring"
		"belt":
			return "Guertel"
		"amulet":
			return "Amulett"
	return str(InventorySystem.EQUIPMENT_SLOTS.get(slot_id, {}).get("name", slot_id))


func _slot_preview_icon(slot_id: String) -> String:
	match slot_id:
		"head":
			return "res://assets/items/armor/scrap_helmet.svg"
		"vest", "jacket":
			return "res://assets/items/armor/leather_vest.svg"
		"pants":
			return "res://assets/items/armor/reinforced_pants.svg"
		"gloves":
			return "res://assets/items/armor/work_gloves.svg"
		"shoes":
			return "res://assets/items/armor/work_boots.svg"
		"shield":
			return "res://assets/ui/icons/shield.svg"
		"tool":
			return "res://assets/items/weapons/melee/fire_axe.svg"
		"melee":
			return "res://assets/items/weapons/melee/machete.svg"
		"firearm":
			return "res://assets/items/weapons/ranged/old_revolver.svg"
		"throwable":
			return "res://assets/items/weapons/ranged/frag_grenade.svg"
		"ring":
			return "res://assets/items/accessories/ring.svg"
		"belt":
			return "res://assets/items/accessories/belt.svg"
		"amulet":
			return "res://assets/items/accessories/amulet.svg"
	return "res://icon.svg"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			accept_event()
			_return()


func _return() -> void:
	queue_free()


func _main_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.021, 0.026, 0.92)
	style.border_color = Color(0.43, 0.35, 0.23, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 16 if compact_screen else 28
	style.content_margin_right = 16 if compact_screen else 28
	style.content_margin_top = 12 if compact_screen else 22
	style.content_margin_bottom = 12 if compact_screen else 22
	return style


func _section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.015, 0.020, 0.72)
	style.border_color = Color(0.36, 0.37, 0.40, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12 if compact_screen else 20
	style.content_margin_right = 12 if compact_screen else 20
	style.content_margin_top = 10 if compact_screen else 16
	style.content_margin_bottom = 10 if compact_screen else 16
	return style


func _slot_style(active: bool, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.021, 0.026, 0.92) if active else Color(0.012, 0.012, 0.014, 0.44)
	style.border_color = UiFactory.COLOR_GOLD if selected else (Color(0.33, 0.35, 0.38, 0.74) if active else Color(0.18, 0.19, 0.21, 0.50))
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _equipment_style(selected: bool = false) -> StyleBoxFlat:
	var style := _slot_style(true, selected)
	style.bg_color = Color(0.014, 0.017, 0.021, 0.66)
	style.border_color = UiFactory.COLOR_GOLD if selected else Color(0.41, 0.42, 0.45, 0.72)
	return style


func _bar_bg() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.039, 0.046, 0.95)
	style.set_corner_radius_all(4)
	return style


func _bar_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
