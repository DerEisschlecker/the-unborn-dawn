# Purpose: Central refuge screen with interactive bunker map, room unlocks, and surface defense placement.
# Public API: Opens sub-systems, handles room/surface clicks on BaseVisual.
# Dependencies: GameplayScreen, GameState, TimeSystem, InventorySystem, BaseVisual.
extends GameplayScreen

const BASE_VISUAL := preload("res://scripts/base/base_visual.gd")

var status_label: Label
var action_label: Label
var action_box: VBoxContainer
var base_art: BaseVisual
var selected_zone := ""


func _ready() -> void:
	GameState.current_location = "base"
	var compact_screen := UiFactory.is_compact_screen()
	AudioManager.play_music(
		"res://assets/audio/music/ambient_night/below_the_walls.wav" if TimeSystem.is_night()
		else "res://assets/audio/music/ambient_day/fragile_morning.wav",
		-11.0
	)
	var root := setup_gameplay("ZUFLUCHT MORGENROT", "Klicke Raeume zum Freischalten. Oben: Verteidigungsanlagen platzieren.")
	if compact_screen:
		_compact_root_typography(root)
	var overview := UiFactory.section("Bunker & Oberflaeche")
	overview.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(overview.get_parent())
	base_art = BASE_VISUAL.new()
	base_art.name = "BaseVisual"
	overview.add_child(base_art)
	base_art.room_selected.connect(_on_room_selected)
	base_art.surface_selected.connect(_on_surface_selected)
	EventBus.stats_changed.connect(_refresh)
	EventBus.inventory_changed.connect(_refresh)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 8 if compact_screen else 14)
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(lower)
	var report := UiFactory.section("Lagebericht")
	report.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(report.get_parent())
	status_label = UiFactory.body_label(_status_text(), 12 if compact_screen else 18)
	report.add_child(status_label)
	action_label = UiFactory.body_label("Klicke einen ausgegrauten Raum oder ein Vorfeld.", 11 if compact_screen else 16, UiFactory.COLOR_MUTED)
	report.add_child(action_label)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	report.add_child(action_box)
	var actions := UiFactory.section("Schnellaktionen")
	actions.get_parent().custom_minimum_size.x = 420 if compact_screen else 500
	lower.add_child(actions.get_parent())
	var action_parent: Control = actions
	if compact_screen:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 5)
		actions.add_child(grid)
		action_parent = grid
	_add_action_button(action_parent, "Bauplan (alt)", func() -> void: go_to("res://scenes/base/build_menu.tscn"), compact_screen)
	_add_action_button(action_parent, "Crafting", open_crafting, compact_screen)
	_add_action_button(action_parent, "Inventar", open_inventory, compact_screen)
	_add_action_button(action_parent, "Ausruestung", open_equipment, compact_screen)
	_add_action_button(action_parent, "Elena", func() -> void: go_to("res://scenes/characters/elena.tscn"), compact_screen)
	_add_action_button(action_parent, "Schlafen", _sleep, compact_screen)
	_add_action_button(action_parent, "Karte", func() -> void: go_to("res://scenes/world_map/world_map.tscn"), compact_screen)
	_refresh()


func _compact_root_typography(root: VBoxContainer) -> void:
	root.add_theme_constant_override("separation", 6)
	var label_index := 0
	for child in root.get_children():
		if child is Label:
			var label := child as Label
			label.add_theme_font_size_override("font_size", 28 if label_index == 0 else 12)
			label_index += 1
		elif child is HSeparator:
			child.custom_minimum_size.y = 2


func _add_action_button(parent: Control, text: String, callback: Callable, compact_screen: bool) -> void:
	var button := UiFactory.button(text, callback, 200 if compact_screen else 230)
	if compact_screen:
		button.custom_minimum_size.y = 34
	parent.add_child(button)


func _on_room_selected(room_id: String) -> void:
	selected_zone = room_id
	_refresh_action_panel()


func _on_surface_selected(slot_id: String) -> void:
	selected_zone = slot_id
	_refresh_action_panel()


func _refresh_action_panel() -> void:
	UiFactory.clear_container(action_box)
	if selected_zone.is_empty():
		action_label.text = "Klicke einen ausgegrauten Raum oder ein Vorfeld."
		return
	var data := DataCatalog.base_room(selected_zone)
	if data.is_empty():
		return
	var zone_name := str(data.get("name", selected_zone))
	if not GameState.is_room_unlocked(selected_zone):
		action_label.text = "%s ist gesperrt.\n%s\nKosten: %s" % [
			zone_name,
			data.get("description", ""),
			UiFactory.cost_text(data.get("unlock_cost", {}))
		]
		var unlock := UiFactory.button("Freischalten", func() -> void: _unlock_selected(), 220)
		unlock.disabled = not InventorySystem.has_items(data.get("unlock_cost", {}))
		action_box.add_child(unlock)
		return
	if str(data.get("zone", "")) == "surface":
		var placed := GameState.surface_placement(selected_zone)
		action_label.text = "%s\n%s\n%s" % [
			zone_name,
			data.get("description", ""),
			"Platziert: %s" % (DataCatalog.structure(placed).get("name", "leer") if not placed.is_empty() else "leer")
		]
		var allowed: Array = data.get("allowed_structures", [])
		for structure_id in allowed:
			var structure := DataCatalog.structure(str(structure_id))
			if structure.is_empty():
				continue
			var button := UiFactory.button("Platzieren: %s" % structure.get("name", structure_id), func() -> void: _place_structure(str(structure_id)), 260)
			button.disabled = not GameState.can_place_on_surface(selected_zone, str(structure_id))
			action_box.add_child(button)
		if not placed.is_empty():
			action_box.add_child(UiFactory.button("Anlage abbauen", func() -> void: _remove_surface(), 220))
		return
	action_label.text = "%s ist aktiv.\n%s" % [zone_name, data.get("description", "")]
	var linked := str(data.get("structure_id", ""))
	if not linked.is_empty():
		var level := int(GameState.base_state.structures.get(linked, 0))
		action_box.add_child(UiFactory.body_label("Gebundene Anlage: %s (Stufe %d)" % [DataCatalog.structure(linked).get("name", linked), level], 14, UiFactory.COLOR_GOLD))


func _unlock_selected() -> void:
	if GameState.unlock_room(selected_zone):
		GameState.spend_for_action(6.0, 4.0)
		TimeSystem.advance(1)
		_refresh()


func _place_structure(structure_id: String) -> void:
	if GameState.place_surface_defense(selected_zone, structure_id):
		GameState.spend_for_action(8.0, 6.0)
		TimeSystem.advance(1)
		_refresh()


func _remove_surface() -> void:
	if GameState.remove_surface_defense(selected_zone):
		_refresh()


func _status_text() -> String:
	var surface := GameState.surface_defense_damage()
	return "Basis %.0f%%  |  Elena %.0f/%.0f (Stress %.0f)  |  Tag %d %s\nDawn-Credits: %d  |  Oberflaechen-Schaden: %.0f  |  Welle: %s" % [
		float(GameState.base_state.integrity),
		float(GameState.elena.health),
		float(GameState.elena.max_health),
		float(GameState.elena.stress),
		TimeSystem.current_day,
		TimeSystem.current_phase(),
		InventorySystem.money,
		surface,
		"heute Nacht" if WaveManager.is_wave_day(TimeSystem.current_day) else "spaeter"
	]


func _refresh() -> void:
	status_label.text = _status_text()
	_refresh_action_panel()
	if is_instance_valid(base_art):
		base_art.queue_redraw()


func _sleep() -> void:
	TimeSystem.advance_to_morning()
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		get_tree().reload_current_scene()
