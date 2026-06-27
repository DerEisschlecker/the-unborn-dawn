# Purpose: Popup inventory overlay with backpack, equipment, quick access, and base storage.
# Public API: Drag/drop items, split stacks, quick transfer, use/equip, and close with Escape.
# Dependencies: InventorySystem, DataCatalog, GameState, UiFactory, InventorySlot.
extends Control

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const GRID_COLUMNS := 7
const GRID_ROWS := 8
const GRID_SLOT_COUNT := GRID_COLUMNS * GRID_ROWS
const COLOR_STAT_BETTER := Color("#79d36b")
const COLOR_STAT_WORSE := Color("#d9685f")
const COLOR_EQUIPPED_FILL := Color("#5a9a62")
const COLOR_SLOT_BLOCKED := Color("#4a4d52")

const EQUIPMENT_SLOT_COUNT := 15
const EQUIPMENT_EXTRA_SLOTS := ["mask", "jacket", "melee", "throwable", "tool"]

var slot_size := Vector2(44, 44)
var compact_screen := false
var grid_rows := GRID_ROWS
var equipment_scale := 1.0
var backpack_grid: GridContainer
var storage_grid: GridContainer
var quick_grid: GridContainer
var equipment_layer: VBoxContainer
var stats_box: VBoxContainer
var stat_value_labels: Dictionary = {}
var stat_delta_labels: Dictionary = {}
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
var hover_compare_mode := ""
var hover_compare_slot := ""
var hover_compare_item_id := ""


func _ready() -> void:
	compact_screen = UiFactory.is_compact_screen(self)
	_resolve_overlay_layout()
	_build_screen()
	EventBus.inventory_changed.connect(_refresh)
	EventBus.stats_changed.connect(_refresh)
	_refresh()


func _hud_clearance() -> int:
	return UiFactory.gameplay_hud_clearance(self, 20)


func _resolve_overlay_layout() -> void:
	var metrics := _compute_overlay_metrics()
	slot_size = metrics.get("slot_size", Vector2(32.0, 32.0))
	grid_rows = int(metrics.get("grid_rows", GRID_ROWS))
	equipment_scale = float(metrics.get("equipment_scale", 1.0))


func _compute_overlay_metrics() -> Dictionary:
	var bottom_gap := _hud_clearance()
	var safe_h := UiFactory.overlay_safe_height(self, 12, bottom_gap)
	var chrome_h := 168.0 if compact_screen else 210.0
	var body_budget := maxf(200.0, safe_h - chrome_h)
	var best_rows := 5
	var best_slot := 24.0
	var best_scale := 0.5
	var best_score := 0.0
	var slot_options: Array[int] = [44, 40, 38, 36, 34, 32, 30, 28, 26, 24]
	var scale_options: Array[float] = [1.0, 0.9, 0.82, 0.74, 0.66, 0.58, 0.5]
	for try_rows in range(GRID_ROWS, 4, -1):
		for try_slot in slot_options:
			var slot_value := float(try_slot)
			for try_scale in scale_options:
				if _estimate_body_height(try_rows, slot_value, try_scale) > body_budget:
					continue
				var score: float = float(try_rows) * 1000.0 + slot_value * 10.0 + try_scale
				if score > best_score:
					best_score = score
					best_rows = try_rows
					best_slot = slot_value
					best_scale = try_scale
	return {
		"slot_size": Vector2(best_slot, best_slot),
		"grid_rows": best_rows,
		"equipment_scale": best_scale,
	}


func _estimate_body_height(rows: int, slot: float, equip_scale: float) -> float:
	var gap := 4.0 if compact_screen else 6.0
	var grid_h := float(rows) * slot + float(maxi(rows - 1, 0)) * gap
	var section_header := 50.0 if compact_screen else 64.0
	var weight_footer := 22.0 if compact_screen else 26.0
	var side_h := section_header + grid_h + weight_footer
	var cell := (50.0 if compact_screen else 64.0) * equip_scale
	var equip_gap := float(_equipment_gap())
	var equip_h := 36.0 + cell * 4.2 + equip_gap * 3.0
	var stat_row_count := _stat_display_rows().size()
	if equip_scale < 0.8:
		stat_row_count = mini(stat_row_count, 7)
	var stats_h := 34.0 + float(stat_row_count) * (11.0 if compact_screen else 13.0)
	var quick_h := slot + (36.0 if compact_screen else 42.0)
	var center_h := 34.0 + equip_h + stats_h + quick_h
	return maxf(side_h, center_h)


func _grid_slot_count() -> int:
	return GRID_COLUMNS * grid_rows


func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
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
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := 8 if compact_screen else 14
	frame.add_theme_constant_override("margin_left", edge)
	frame.add_theme_constant_override("margin_right", edge)
	frame.add_theme_constant_override("margin_top", edge)
	frame.add_theme_constant_override("margin_bottom", _hud_clearance())
	add_child(frame)
	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 6 if compact_screen else 8)
	frame.add_child(shell)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _main_panel_style())
	shell.add_child(panel)
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
	action_row.size_flags_vertical = Control.SIZE_SHRINK_END
	action_row.add_theme_constant_override("separation", 6 if compact_screen else 10)
	root.add_child(action_row)
	status_label = UiFactory.body_label("Shift + Rechtsklick: Stapel teilen   |   Strg + Rechtsklick: schnell uebertragen   |   ESC: Schliessen", 11 if compact_screen else 15, UiFactory.COLOR_MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.size_flags_vertical = Control.SIZE_SHRINK_END
	shell.add_child(status_label)


func _build_backpack_panel(parent: HBoxContainer) -> void:
	var box := _section_panel("RUCKSACK")
	parent.add_child(box.get_parent())
	backpack_title = box.get_node("Title") as Label
	backpack_grid = _grid()
	box.add_child(backpack_grid)
	var footer := _weight_footer("Gewicht", true)
	box.add_child(footer)


func _build_storage_panel(parent: HBoxContainer) -> void:
	var box := _section_panel("LAGER")
	parent.add_child(box.get_parent())
	storage_title = box.get_node("Title") as Label
	storage_grid = _grid()
	box.add_child(storage_grid)
	var footer := _weight_footer("Gewicht", false)
	box.add_child(footer)


func _build_center_panel(parent: HBoxContainer) -> void:
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 300 if compact_screen else 420
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8 if compact_screen else 12)
	parent.add_child(center)
	var equipment_panel := PanelContainer.new()
	equipment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	equipment_panel.add_theme_stylebox_override("panel", _section_style())
	center.add_child(equipment_panel)
	var equipment_box := VBoxContainer.new()
	equipment_box.add_theme_constant_override("separation", 6)
	equipment_panel.add_child(equipment_box)
	equipment_box.add_child(UiFactory.body_label("AUSRÜSTUNG", 13 if compact_screen else 17, UiFactory.COLOR_GOLD))
	equipment_layer = VBoxContainer.new()
	equipment_layer.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment_layer.add_theme_constant_override("separation", _equipment_gap())
	equipment_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_box.add_child(equipment_layer)
	_build_quick_bar(center)
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_stylebox_override("panel", _section_style())
	center.add_child(stats_panel)
	var stats_outer := VBoxContainer.new()
	stats_outer.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_outer)
	stats_outer.add_child(UiFactory.body_label("AUSRUESTUNGSWERTE", 13 if compact_screen else 16, UiFactory.COLOR_GOLD))
	stats_box = VBoxContainer.new()
	stats_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_box.add_theme_constant_override("separation", 2)
	stats_outer.add_child(stats_box)
	_build_stat_rows()


func _build_quick_bar(parent: VBoxContainer) -> void:
	var quick_panel := PanelContainer.new()
	quick_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	quick_panel.custom_minimum_size.y = slot_size.y + (30.0 if compact_screen else 36.0)
	quick_panel.add_theme_stylebox_override("panel", _section_style())
	parent.add_child(quick_panel)
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


func _section_panel(title: String, subtitle: String = "") -> VBoxContainer:
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
	if not subtitle.is_empty():
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


func _stat_display_rows() -> Array:
	var rows: Array = [
		{"key": "armor_display", "label": "Ruestung"},
		{"key": "magic_resistance", "label": "%sresistenz" % str(RpgRules.DAMAGE_TYPES.magic.get("name", "Magie"))},
		{"key": "max_health", "label": "Max. %s" % str(RpgRules.SECONDARY_STATS.health.get("name", "Leben")).replace("spunkte", "").strip_edges()},
		{"key": "max_stamina", "label": str(RpgRules.SECONDARY_STATS.stamina.get("name", "Ausdauer"))},
		{"key": "strength", "label": str(RpgRules.PRIMARY_ATTRIBUTES.strength.get("name", "Staerke"))},
		{"key": "dexterity", "label": str(RpgRules.PRIMARY_ATTRIBUTES.dexterity.get("name", "Geschicklichkeit"))},
		{"key": "intelligence", "label": str(RpgRules.PRIMARY_ATTRIBUTES.intelligence.get("name", "Intelligenz"))}
	]
	for damage_id in ["poison", "fire", "frost", "lightning"]:
		var data: Dictionary = RpgRules.DAMAGE_TYPES[damage_id]
		var resist_key := str(data.get("resistance", ""))
		var element := str(data.get("name", damage_id))
		rows.append({"key": resist_key, "label": "Widerstand gegen %s" % element, "percent": true})
	return rows


func _build_stat_rows() -> void:
	if not is_instance_valid(stats_box):
		return
	UiFactory.clear_container(stats_box)
	stat_value_labels.clear()
	stat_delta_labels.clear()
	var rows: Array = _stat_display_rows()
	if equipment_scale < 0.8:
		rows = rows.slice(0, 7)
	for row_variant in rows:
		var row: Dictionary = row_variant if row_variant is Dictionary else {}
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		stats_box.add_child(line)
		var key := str(row.get("key", ""))
		var name_label := UiFactory.body_label(str(row.get("label", key)), 10 if compact_screen else 12, Color("#c8cdd8"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(name_label)
		var value_label := UiFactory.body_label("0", 10 if compact_screen else 12, Color.WHITE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size.x = 40
		line.add_child(value_label)
		var delta_label := UiFactory.body_label("", 10 if compact_screen else 12, UiFactory.COLOR_MUTED)
		delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		delta_label.custom_minimum_size.x = 44
		line.add_child(delta_label)
		stat_value_labels[key] = value_label
		stat_delta_labels[key] = delta_label


func _compare_context() -> Dictionary:
	if hover_compare_mode == "equip" and not hover_compare_item_id.is_empty():
		var equip_data := DataCatalog.item(hover_compare_item_id)
		var slot := str(equip_data.get("equip_slot", ""))
		if not slot.is_empty():
			return {"mode": "equip", "slot": slot, "item_id": hover_compare_item_id}
	if hover_compare_mode == "unequip" and not hover_compare_slot.is_empty():
		return {"mode": "unequip", "slot": hover_compare_slot, "item_id": ""}
	if selected_source in ["backpack", "storage"] and not selected_item_id.is_empty():
		var data := DataCatalog.item(selected_item_id)
		if data.has("equip_slot"):
			return {"mode": "equip", "slot": str(data.get("equip_slot", "")), "item_id": selected_item_id}
	if selected_source == "equipment" and not selected_key.is_empty() and not InventorySystem.equipped_item(selected_key).is_empty():
		return {"mode": "unequip", "slot": selected_key, "item_id": ""}
	return {}


func _projected_stats(slot: String, item_id: String) -> Dictionary:
	return RpgRules.effective_stats(
		GameState.player_stats,
		InventorySystem.projected_equipment_stat_bonuses(slot, item_id)
	)


func _refresh_stats() -> void:
	var context := _compare_context()
	var compare_mode := str(context.get("mode", ""))
	var compare_slot := str(context.get("slot", ""))
	var compare_id := str(context.get("item_id", ""))
	var has_compare := not compare_mode.is_empty() and not compare_slot.is_empty()
	var compare_data := DataCatalog.item(compare_id)
	var current := GameState.effective_player_stats()
	var projected := current
	if has_compare:
		projected = _projected_stats(compare_slot, compare_id)
	if is_instance_valid(status_label) and has_compare:
		if compare_mode == "equip" and not compare_data.is_empty():
			var slot_name := str(InventorySystem.EQUIPMENT_SLOTS.get(compare_slot, {}).get("name", compare_slot))
			var old_id := InventorySystem.equipped_item(compare_slot)
			var old_name: String = str(DataCatalog.item(old_id).get("name", "leer")) if not old_id.is_empty() else "leer"
			status_label.text = "%s -> %s (%s)" % [old_name, compare_data.get("name", compare_id), slot_name]
		elif compare_mode == "unequip":
			var slot_name := str(InventorySystem.EQUIPMENT_SLOTS.get(compare_slot, {}).get("name", compare_slot))
			var old_id := InventorySystem.equipped_item(compare_slot)
			status_label.text = "Ablegen: %s (%s)" % [
				DataCatalog.item(old_id).get("name", old_id) if not old_id.is_empty() else slot_name,
				slot_name
			]
	for row in _stat_display_rows():
		var key := str(row.get("key", ""))
		if not stat_value_labels.has(key):
			continue
		var value_label: Label = stat_value_labels[key]
		var delta_label: Label = stat_delta_labels[key]
		var current_value := InventorySystem.armor_value() if key == "armor_display" else float(current.get(key, 0.0))
		var projected_value := current_value
		if has_compare:
			projected_value = InventorySystem.projected_armor_value(compare_slot, compare_id) if key == "armor_display" else float(projected.get(key, 0.0))
		var diff := projected_value - current_value if has_compare else 0.0
		if bool(row.get("percent", false)):
			value_label.text = "%d%%" % int(roundf(current_value))
		else:
			value_label.text = _stat_value_text(current_value)
		if not has_compare or absf(diff) < 0.05:
			value_label.add_theme_color_override("font_color", Color.WHITE)
			delta_label.text = ""
			delta_label.remove_theme_color_override("font_color")
		elif diff > 0.0:
			var delta_text := "+%d%%" % int(roundf(diff)) if bool(row.get("percent", false)) else "+%s" % _stat_value_text(diff)
			delta_label.text = delta_text
			delta_label.add_theme_color_override("font_color", COLOR_STAT_BETTER)
			value_label.add_theme_color_override("font_color", COLOR_STAT_BETTER if compare_mode == "equip" else Color.WHITE)
		else:
			var delta_text := "%d%%" % int(roundf(diff)) if bool(row.get("percent", false)) else _stat_value_text(diff)
			delta_label.text = delta_text
			delta_label.add_theme_color_override("font_color", COLOR_STAT_WORSE)
			value_label.add_theme_color_override("font_color", COLOR_STAT_WORSE if compare_mode == "equip" else Color.WHITE)


func _stat_value_text(value: float) -> String:
	if absf(value - roundf(value)) < 0.05:
		return "%d" % int(roundf(value))
	return "%.1f" % value


func _set_compare_equip(item_id: String) -> void:
	if item_id.is_empty() or not DataCatalog.item(item_id).has("equip_slot"):
		return
	hover_compare_mode = "equip"
	hover_compare_item_id = item_id
	hover_compare_slot = ""
	_refresh_stats()


func _set_compare_unequip(slot_id: String) -> void:
	if slot_id.is_empty() or InventorySystem.equipped_item(slot_id).is_empty():
		return
	hover_compare_mode = "unequip"
	hover_compare_slot = slot_id
	hover_compare_item_id = ""
	_refresh_stats()


func _clear_hover_compare() -> void:
	if hover_compare_mode.is_empty():
		return
	hover_compare_mode = ""
	hover_compare_slot = ""
	hover_compare_item_id = ""
	_refresh_stats()


func _refresh() -> void:
	_validate_selection()
	_refresh_grids()
	_refresh_equipment()
	_refresh_stats()
	_refresh_quick_slots()
	_refresh_weight()
	_refresh_actions()


func _refresh_grids() -> void:
	UiFactory.clear_container(backpack_grid)
	UiFactory.clear_container(storage_grid)
	var backpack_items := InventorySystem.sorted_items_for_layout()
	var storage_items := InventorySystem.sorted_storage_items_for_layout()
	var backpack_active := mini(_grid_slot_count(), InventorySystem.slot_capacity)
	var storage_active := mini(_grid_slot_count(), InventorySystem.storage_slot_capacity())
	for index in range(_grid_slot_count()):
		var item_id := str(backpack_items[index]) if index < backpack_items.size() else ""
		backpack_grid.add_child(_slot("backpack", str(index), item_id, index < backpack_active, int(InventorySystem.items.get(item_id, 0))))
	for index in range(_grid_slot_count()):
		var item_id := str(storage_items[index]) if index < storage_items.size() else ""
		storage_grid.add_child(_slot("storage", str(index), item_id, index < storage_active, int(InventorySystem.storage_items.get(item_id, 0))))


func _refresh_equipment() -> void:
	UiFactory.clear_container(equipment_layer)
	var gap := _equipment_gap()
	var cell := _equipment_cell_size()
	var tall_h := cell * 2.0 + gap
	if not InventorySystem.equipped_item("mask").is_empty():
		var mask_row := CenterContainer.new()
		mask_row.add_child(_equipment_slot("mask", Vector2(cell, cell)))
		equipment_layer.add_child(mask_row)
	var helm_row := CenterContainer.new()
	helm_row.add_child(_equipment_slot("head", Vector2(cell, cell)))
	equipment_layer.add_child(helm_row)
	var body_row := HBoxContainer.new()
	body_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body_row.add_theme_constant_override("separation", gap)
	body_row.add_child(_equipment_weapon_column(cell, tall_h, gap))
	var torso := VBoxContainer.new()
	torso.add_theme_constant_override("separation", gap)
	torso.add_child(_equipment_slot("vest", Vector2(cell, cell), "Brust"))
	if not InventorySystem.equipped_item("jacket").is_empty():
		torso.add_child(_equipment_slot("jacket", Vector2(cell, cell)))
	torso.add_child(_equipment_slot("pants", Vector2(cell, cell), "Beine"))
	body_row.add_child(torso)
	body_row.add_child(_equipment_slot("shield", Vector2(cell, tall_h), "Schild", InventorySystem.is_slot_blocked("shield")))
	equipment_layer.add_child(body_row)
	var hands_row := HBoxContainer.new()
	hands_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hands_row.add_theme_constant_override("separation", gap)
	hands_row.add_child(_equipment_slot("gloves", Vector2(cell, cell), "Handschuhe"))
	hands_row.add_child(_equipment_slot("shoes", Vector2(cell, cell), "Stiefel"))
	hands_row.add_child(_equipment_slot("ring", Vector2(cell, cell), "Ring"))
	if not InventorySystem.equipped_item("throwable").is_empty():
		hands_row.add_child(_equipment_slot("throwable", Vector2(cell, cell)))
	equipment_layer.add_child(hands_row)
	var waist_row := HBoxContainer.new()
	waist_row.alignment = BoxContainer.ALIGNMENT_CENTER
	waist_row.add_theme_constant_override("separation", gap)
	waist_row.add_child(_equipment_slot("belt", Vector2(cell, cell), "Gürtel"))
	waist_row.add_child(_backpack_equipment_slot(Vector2(cell, cell)))
	if not InventorySystem.equipped_item("tool").is_empty():
		waist_row.add_child(_equipment_slot("tool", Vector2(cell, cell)))
	waist_row.add_child(_equipment_slot("amulet", Vector2(cell, cell), "Amulett"))
	equipment_layer.add_child(waist_row)


func _equipment_gap() -> int:
	return 4 if compact_screen else 6


func _equipment_cell_size() -> float:
	return (50.0 if compact_screen else 64.0) * equipment_scale


func _equipment_weapon_column(cell: float, tall_h: float, gap: int) -> Control:
	var two_handed_id := InventorySystem.equipped_two_handed_weapon()
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(cell, tall_h)
	column.add_theme_constant_override("separation", gap)
	var split_h := maxf(cell, (tall_h - gap) * 0.5)
	if not two_handed_id.is_empty():
		var two_hand_slot := str(DataCatalog.item(two_handed_id).get("equip_slot", "firearm"))
		var primary_h := maxf(cell, tall_h - cell - gap)
		if two_hand_slot == "firearm":
			column.add_child(_equipment_slot("firearm", Vector2(cell, primary_h), "Fernkampf"))
			column.add_child(_equipment_slot("melee", Vector2(cell, cell), "Nahkampf", InventorySystem.is_slot_blocked("melee")))
		else:
			column.add_child(_equipment_slot("firearm", Vector2(cell, cell), "Fernkampf", InventorySystem.is_slot_blocked("firearm")))
			column.add_child(_equipment_slot("melee", Vector2(cell, primary_h), "Nahkampf"))
		return column
	column.add_child(_equipment_slot("firearm", Vector2(cell, split_h), "Fernkampf", InventorySystem.is_slot_blocked("firearm")))
	column.add_child(_equipment_slot("melee", Vector2(cell, split_h), "Nahkampf", InventorySystem.is_slot_blocked("melee")))
	return column


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
	panel.decorate(amount, item_id == selected_item_id, "Schnellzugriff" if quick else source.capitalize())
	if DataCatalog.item(item_id).has("equip_slot"):
		panel.mouse_entered.connect(func() -> void: _set_compare_equip(item_id))
		panel.mouse_exited.connect(_clear_hover_compare)
	return panel


func _equipment_slot(slot_id: String, panel_size: Vector2, empty_label: String = "", blocked: bool = false) -> PanelContainer:
	var item_id := InventorySystem.equipped_item(slot_id)
	var filled := not item_id.is_empty()
	var panel: PanelContainer = InventorySlotScript.new()
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.configure("equipment", slot_id, item_id, not blocked, filled and not blocked)
	panel.slot_clicked.connect(_on_slot_clicked)
	panel.item_dropped.connect(_on_item_dropped)
	panel.add_theme_stylebox_override("panel", _equipment_style(item_id == selected_item_id and filled, filled, blocked))
	var slot_label := empty_label if not empty_label.is_empty() else str(InventorySystem.EQUIPMENT_SLOTS.get(slot_id, {}).get("name", slot_id))
	if blocked and not filled:
		panel.tooltip_text = InventorySystem.slot_block_reason(slot_id)
		_add_empty_equipment_preview(panel, slot_id, panel_size, empty_label if not empty_label.is_empty() else "Blockiert", true)
		return panel
	panel.tooltip_text = slot_label if not filled else "%s: %s" % [slot_label, DataCatalog.item(item_id).get("name", item_id)]
	if not filled:
		_add_empty_equipment_preview(panel, slot_id, panel_size, empty_label)
		return panel
	panel.decorate(1, item_id == selected_item_id, slot_label)
	panel.mouse_entered.connect(func() -> void: _set_compare_unequip(slot_id))
	panel.mouse_exited.connect(_clear_hover_compare)
	return panel


func _backpack_equipment_slot(panel_size: Vector2) -> PanelContainer:
	var item_id := InventorySystem.equipped_backpack_id
	var data := InventorySystem.backpack_data()
	var panel: PanelContainer = InventorySlotScript.new()
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.configure("backpack_slot", "backpack", item_id, true, false)
	panel.slot_clicked.connect(_on_slot_clicked)
	panel.item_dropped.connect(_on_item_dropped)
	panel.add_theme_stylebox_override("panel", _equipment_style(item_id == selected_item_id, true))
	panel.tooltip_text = "Rucksack: %s (%d Plaetze, %.1f kg)" % [
		data.get("name", item_id),
		int(data.get("capacity_slots", InventorySystem.slot_capacity)),
		float(data.get("max_weight", InventorySystem.max_weight))
	]
	panel.decorate(1, item_id == selected_item_id and selected_source == "backpack_slot", "Rucksack")
	return panel


func _add_empty_equipment_preview(panel: PanelContainer, slot_id: String, panel_size: Vector2, empty_label: String = "", blocked: bool = false) -> void:
	var label_text := empty_label if not empty_label.is_empty() else _slot_preview_text(slot_id)
	var tall := panel_size.y > panel_size.x * 1.2
	var icon_size := minf(panel_size.x, panel_size.y) * (0.46 if tall else 0.52)
	var label_color := Color(0.42, 0.43, 0.46, 0.82) if blocked else Color(0.62, 0.64, 0.68, 0.96)
	var label := UiFactory.body_label(label_text, 7 if compact_screen else 9, label_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 4 if compact_screen else 6
	label.custom_minimum_size.y = 12 if compact_screen else 14
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	var icon := TextureRect.new()
	icon.texture = load(_slot_preview_icon(slot_id, empty_label))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(0.32, 0.33, 0.36, 0.28) if blocked else Color(0.50, 0.53, 0.58, 0.38)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_top = 8 if compact_screen else 10
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)



func _on_slot_clicked(source: String, key: String, item_id: String, event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if source == "backpack_slot":
			_set_selection(source, key, InventorySystem.equipped_backpack_id)
			status_label.text = "Rucksack: %s" % InventorySystem.backpack_data().get("name", InventorySystem.equipped_backpack_id)
			_refresh()
			return
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
	var message := ItemDragDrop.apply_drop(target_source, target_key, ItemDragDrop.make_payload(source, source_key, item_id))
	if not message.is_empty():
		status_label.text = message
	_refresh()


func _primary_action(source: String, key: String, item_id: String) -> void:
	if item_id.is_empty():
		return
	if source == "equipment":
		if InventorySystem.is_slot_blocked(key):
			status_label.text = InventorySystem.slot_block_reason(key)
			return
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


func _equip_from_source(item_id: String, source: String, target_slot: String) -> void:
	var data := DataCatalog.item(item_id)
	if str(data.get("equip_slot", "")) != target_slot:
		status_label.text = "Dieser Gegenstand passt nicht in diesen Ausruestungsslot."
		return
	if not InventorySystem.item_fits_equipment_slot(item_id, target_slot):
		status_label.text = InventorySystem.slot_mismatch_message(item_id, target_slot)
		return
	if InventorySystem.is_slot_blocked(target_slot):
		status_label.text = InventorySystem.slot_block_reason(target_slot)
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
	elif selected_source == "backpack_slot":
		action_row.add_child(_action_button("Rucksack wechseln", func() -> void: status_label.text = "Ziehe einen anderen Rucksack auf den Rucksack-Slot."))
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
	_refresh_stats()


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
	elif selected_source == "backpack_slot" and InventorySystem.equipped_backpack_id != selected_item_id:
		_clear_selection()
	elif selected_source == "quick" and InventorySystem.quick_slot_item(int(selected_key)) != selected_item_id:
		_clear_selection()


func _clear_selection() -> void:
	selected_item_id = ""
	selected_source = ""
	selected_key = ""
	hover_compare_mode = ""
	hover_compare_slot = ""
	hover_compare_item_id = ""
	_refresh_stats()


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
			return "Fernkampf"
		"throwable":
			return "Wurf"
		"ring":
			return "Ring"
		"belt":
			return "Gürtel"
		"amulet":
			return "Amulett"
	return str(InventorySystem.EQUIPMENT_SLOTS.get(slot_id, {}).get("name", slot_id))


func _slot_preview_icon(slot_id: String, _empty_label: String = "") -> String:
	match slot_id:
		"head":
			return "res://assets/items/armor/scrap_helmet.svg"
		"mask":
			return "res://assets/items/armor/respirator_mask.svg"
		"vest", "jacket":
			return "res://assets/items/armor/leather_vest.svg"
		"pants":
			return "res://assets/items/armor/reinforced_pants.svg"
		"gloves":
			return "res://assets/items/armor/work_gloves.svg"
		"shoes":
			return "res://assets/items/armor/work_boots.svg"
		"shield":
			return UiFactory.stat_icon_path("shield")
		"tool":
			return "res://assets/items/weapons/melee/fire_axe.svg"
		"melee":
			return "res://assets/items/weapons/melee/machete.svg"
		"firearm":
			return "res://assets/items/weapons/ranged/hunting_rifle.svg"
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


func _equipment_style(selected: bool, filled: bool = false, blocked: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if blocked:
		style.bg_color = Color(0.010, 0.011, 0.013, 0.72)
		style.border_color = COLOR_SLOT_BLOCKED
		style.set_border_width_all(1)
	elif filled:
		style.bg_color = Color(0.018, 0.020, 0.024, 0.88)
	else:
		style.bg_color = Color(0.014, 0.016, 0.020, 0.82)
	style.set_corner_radius_all(10 if not compact_screen else 8)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if selected:
		style.border_color = UiFactory.COLOR_GOLD
		style.set_border_width_all(2)
	elif blocked:
		pass
	elif filled:
		style.border_color = COLOR_EQUIPPED_FILL
		style.set_border_width_all(2)
	else:
		style.border_color = Color(0.36, 0.38, 0.42, 0.88)
		style.set_border_width_all(1)
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
