# Purpose: Data-driven crafting screen with twelve starter recipes and workbench requirements.
# Public API: Crafts recipe outputs after consuming ingredients.
# Dependencies: DataCatalog, InventorySystem, GameState, TimeSystem.
extends GameplayScreen

var list_box: GridContainer
var feedback: Label


func _ready() -> void:
	var root := setup_gameplay("CRAFTING", "Improvisieren heißt, morgen noch etwas zu haben.")
	feedback = UiFactory.body_label(_workbench_text(), 18, UiFactory.COLOR_MUTED)
	root.add_child(feedback)
	list_box = GridContainer.new()
	list_box.columns = 2
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("h_separation", 10)
	list_box.add_theme_constant_override("v_separation", 10)
	root.add_child(list_box)
	root.add_child(UiFactory.button("Zurück", _return, 240))
	_refresh()


func _refresh() -> void:
	feedback.text = _workbench_text()
	UiFactory.clear_container(list_box)
	var workshop_level := _effective_workbench_level()
	for recipe_id in DataCatalog.recipes:
		var recipe := DataCatalog.recipe(str(recipe_id))
		var output := DataCatalog.item(str(recipe.get("output", "")))
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
		list_box.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(str(output.get("icon", "res://icon.svg")))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(46, 46)
		row.add_child(icon)
		var label := UiFactory.body_label("%s → %s ×%d\nBenötigt: %s · Werkbank %d" % [
			recipe.get("name", recipe_id),
			output.get("name", recipe.get("output", "")),
			int(recipe.get("amount", 1)),
			UiFactory.cost_text(recipe.get("inputs", {})),
			int(recipe.get("level", 0))
		], 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := UiFactory.button("Herstellen", func() -> void: _craft(str(recipe_id)), 170)
		button.custom_minimum_size = Vector2(150, 42)
		button.disabled = workshop_level < int(recipe.get("level", 0)) or not InventorySystem.has_items(recipe.get("inputs", {}))
		row.add_child(button)


func _craft(recipe_id: String) -> void:
	var recipe := DataCatalog.recipe(recipe_id)
	if not InventorySystem.consume_cost(recipe.get("inputs", {})):
		feedback.text = "Materialien fehlen."
		return
	var output_id := str(recipe.get("output", ""))
	var amount := int(recipe.get("amount", 1))
	if not InventorySystem.add_item(output_id, amount):
		for item_id in recipe.get("inputs", {}):
			InventorySystem.add_item(str(item_id), int(recipe.inputs[item_id]))
		feedback.text = "Der Rucksack ist zu schwer. Materialien wurden zurückgegeben."
		return
	GameState.run_statistics.items_crafted = int(GameState.run_statistics.items_crafted) + amount
	AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -4.0)
	GameState.spend_for_action(4.0, 3.0)
	feedback.text = "%s ×%d hergestellt." % [DataCatalog.item(output_id).get("name", output_id), amount]
	_refresh()


func _return() -> void:
	go_to(GameState.return_scene if not GameState.return_scene.is_empty() else "res://scenes/base/base_scene.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		accept_event()
		_return()


func _workbench_text() -> String:
	return "Werkbank-Stufe: %d - Effektiv mit Handwerk: %d - Rucksack: %d/%d Plaetze, %.1f/%.1f kg" % [
		int(GameState.base_state.structures.get("workbench", 0)),
		_effective_workbench_level(),
		InventorySystem.used_slots(),
		InventorySystem.slot_capacity,
		InventorySystem.current_weight(),
		InventorySystem.max_weight
	]


func _effective_workbench_level() -> int:
	return int(GameState.base_state.structures.get("workbench", 0)) + int(GameState.player_stats.get("crafting", 0)) + int(InventorySystem.total_equipment_bonus("crafting_bonus"))
