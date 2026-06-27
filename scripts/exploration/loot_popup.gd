# Purpose: Reusable loot confirmation popup for containers and exploration hotspots.
# Public API: present_loot() and the loot_taken signal.
# Dependencies: InventorySystem, DataCatalog, ItemDragDrop, InventorySlot.
extends Control

signal loot_taken(item_id: String, amount: int)

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")

var item_id := ""
var amount := 0
var description: Label
var feedback_label: Label
var drag_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_margins := UiFactory.overlay_screen_margins(self, UiFactory.is_compact_screen(self))
	frame.add_theme_constant_override("margin_left", overlay_margins.left)
	frame.add_theme_constant_override("margin_right", overlay_margins.right)
	frame.add_theme_constant_override("margin_top", overlay_margins.top)
	frame.add_theme_constant_override("margin_bottom", overlay_margins.bottom)
	add_child(frame)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UiFactory.menu_panel_size(self).x, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiFactory.title_label("GEFUNDEN", 30))
	description = UiFactory.body_label("Leerer Behaelter.", 20)
	box.add_child(description)
	drag_row = HBoxContainer.new()
	drag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	drag_row.add_theme_constant_override("separation", 16)
	box.add_child(drag_row)
	feedback_label = UiFactory.body_label("Linksklick halten und in den Rucksack ziehen.", 14, UiFactory.COLOR_MUTED)
	box.add_child(feedback_label)
	box.add_child(UiFactory.button("Einpacken", _take, 440, AudioManager.UiClickKind.CONFIRM))
	box.add_child(UiFactory.button("Schliessen", _close, 440))
	_rebuild_drag_slots()


func present_loot(new_item_id: String, new_amount: int) -> void:
	item_id = new_item_id
	amount = new_amount
	GameState.transient_loot = {item_id: amount}
	_rebuild_drag_slots()
	if is_instance_valid(description):
		description.text = "%s x%d" % [DataCatalog.item(item_id).get("name", item_id), amount]


func _rebuild_drag_slots() -> void:
	if not is_instance_valid(drag_row):
		return
	UiFactory.clear_container(drag_row)
	if item_id.is_empty():
		return
	var loot_slot := _make_slot("enemy_loot", item_id, item_id, true)
	drag_row.add_child(loot_slot)
	var arrow := UiFactory.body_label("→", 28, UiFactory.COLOR_GOLD)
	arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	drag_row.add_child(arrow)
	var backpack_slot := _make_slot("backpack", "0", "", false)
	backpack_slot.tooltip_text = "In den Rucksack ziehen"
	drag_row.add_child(backpack_slot)


func _make_slot(source: String, key: String, slot_item_id: String, can_drag: bool) -> PanelContainer:
	var panel: PanelContainer = InventorySlotScript.new()
	panel.custom_minimum_size = Vector2(64, 64)
	panel.configure(source, key, slot_item_id, source == "backpack", can_drag)
	panel.item_dropped.connect(_on_item_dropped)
	if not slot_item_id.is_empty():
		panel.decorate(amount, false, "Gefunden")
	return panel


func _on_item_dropped(target_source: String, target_key: String, dropped_item_id: String, source: String, source_key: String) -> void:
	if dropped_item_id.is_empty():
		return
	var message := ItemDragDrop.apply_drop(target_source, target_key, ItemDragDrop.make_payload(source, source_key, dropped_item_id))
	if message.is_empty():
		return
	if is_instance_valid(feedback_label):
		feedback_label.text = message
	if int(GameState.transient_loot.get(dropped_item_id, 0)) <= 0:
		loot_taken.emit(dropped_item_id, amount)
		queue_free()
	else:
		amount = int(GameState.transient_loot.get(dropped_item_id, amount))
		_rebuild_drag_slots()


func _take() -> void:
	if InventorySystem.add_item(item_id, amount):
		GameState.transient_loot.clear()
		loot_taken.emit(item_id, amount)
		queue_free()
	elif is_instance_valid(feedback_label):
		feedback_label.text = "Kein Platz oder zu schwer."


func _close() -> void:
	GameState.transient_loot.clear()
	queue_free()


func close_with_escape() -> void:
	_close()
