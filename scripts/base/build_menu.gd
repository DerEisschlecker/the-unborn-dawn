# Purpose: Data-driven base construction menu covering walls, towers, traps, infrastructure, and Elena's shelter.
# Public API: Builds or upgrades structures after checking material costs.
# Dependencies: DataCatalog, GameState, InventorySystem.
extends GameplayScreen

var list_box: GridContainer
var feedback: Label


func _ready() -> void:
	GameState.return_scene = "res://scenes/base/base_scene.tscn"
	var root := setup_gameplay("BAUPLAN", "Jede Struktur kann mehrfach ausgebaut werden. Kosten bleiben leicht lesbar in den Daten-Dateien.")
	feedback = UiFactory.body_label("Wähle ein Bauprojekt.", 18, UiFactory.COLOR_MUTED)
	root.add_child(feedback)
	list_box = GridContainer.new()
	list_box.columns = 2
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("h_separation", 10)
	list_box.add_theme_constant_override("v_separation", 10)
	root.add_child(list_box)
	root.add_child(UiFactory.button("Zurück zur Basis", func() -> void: go_to("res://scenes/base/base_scene.tscn"), 260))
	_refresh()


func _refresh() -> void:
	UiFactory.clear_container(list_box)
	for structure_id in DataCatalog.structures:
		var data := DataCatalog.structure(str(structure_id))
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
		list_box.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var level := int(GameState.base_state.structures.get(structure_id, 0))
		var label := UiFactory.body_label("%s · Stufe %d\n%s\nKosten: %s" % [
			data.get("name", structure_id),
			level,
			data.get("description", ""),
			UiFactory.cost_text(data.get("cost", {}))
		], 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := UiFactory.button("Bauen", func() -> void: _build(str(structure_id)), 150)
		button.custom_minimum_size = Vector2(130, 42)
		button.disabled = not InventorySystem.has_items(data.get("cost", {}))
		row.add_child(button)


func _build(structure_id: String) -> void:
	if GameState.build_structure(structure_id):
		feedback.text = "%s wurde errichtet oder verstärkt." % DataCatalog.structure(structure_id).get("name", structure_id)
		GameState.spend_for_action(8.0, 6.0)
		TimeSystem.advance(1)
		if not WaveManager.pending_wave and GameState.pending_story.is_empty():
			_refresh()
	else:
		feedback.text = "Dafür fehlen Materialien."
