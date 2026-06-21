# Purpose: Reusable loot confirmation popup for containers and exploration hotspots.
# Public API: present_loot() and the loot_taken signal.
# Dependencies: InventorySystem and DataCatalog.
extends Control

signal loot_taken(item_id: String, amount: int)

var item_id := ""
var amount := 0
var description: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 300)
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiFactory.title_label("GEFUNDEN", 30))
	description = UiFactory.body_label("Leerer Behaelter.", 20)
	box.add_child(description)
	box.add_child(UiFactory.button("Einpacken", _take, 440))
	box.add_child(UiFactory.button("Schliessen", queue_free, 440))


func present_loot(new_item_id: String, new_amount: int) -> void:
	item_id = new_item_id
	amount = new_amount
	if is_instance_valid(description):
		description.text = "%s x%d" % [DataCatalog.item(item_id).get("name", item_id), amount]


func _take() -> void:
	if InventorySystem.add_item(item_id, amount):
		loot_taken.emit(item_id, amount)
		queue_free()
