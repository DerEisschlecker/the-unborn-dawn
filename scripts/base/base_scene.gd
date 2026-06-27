# Purpose: Central refuge screen with full-screen bunker cutaway and floating UI panels.
# Public API: Opens sub-systems, handles room/surface clicks on the 3D fortress view.
# Dependencies: GameplayScreen, GameState, TimeSystem, InventorySystem, BaseFortressView.
extends GameplayScreen

const BASE_VIEW := preload("res://scripts/base/base_fortress_view.gd")

var status_label: Label
var action_label: Label
var action_box: VBoxContainer
var base_art: Control
var report_panel: PanelContainer
var actions_panel: PanelContainer
var hint_label: Label
var hotspot_layer: Control
var selected_zone := ""


func _ready() -> void:
	GameState.current_location = "base"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	clear_dynamic_children()
	AudioManager.play_scene_music("base")
	_build_canvas()
	attach_hud()
	_build_report_panel()
	_build_actions_panel()
	_build_hint_label()
	_position_panels()
	EventBus.stats_changed.connect(_refresh)
	EventBus.inventory_changed.connect(_refresh)
	base_art.room_selected.connect(_on_room_selected)
	base_art.surface_selected.connect(_on_surface_selected)
	_refresh()
	call_deferred("_position_panels")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_position_panels()
		_position_hotspots()


func _build_canvas() -> void:
	base_art = BASE_VIEW.new()
	base_art.name = "BaseFortressView"
	base_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base_art.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(base_art)
	move_child(base_art, 0)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.024, 0.06)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_child(shade, 1)
	hotspot_layer = Control.new()
	hotspot_layer.name = "HotspotLayer"
	hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hotspot_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hotspot_layer)
	move_child(hotspot_layer, 2)


func _build_report_panel() -> void:
	var compact := UiFactory.is_compact_screen(self)
	report_panel = PanelContainer.new()
	report_panel.name = "ReportPanel"
	report_panel.add_theme_stylebox_override("panel", _glass_panel_style())
	add_child(report_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if compact else 8)
	report_panel.add_child(box)
	box.add_child(UiFactory.title_label("ZUFLUCHT MORGENROT", 22 if compact else 28))
	box.add_child(UiFactory.body_label("Oberflaeche: Tuerme & Vorfelder. Unten: Bunkerraeume.", 11 if compact else 13, UiFactory.COLOR_MUTED))
	status_label = UiFactory.body_label(_status_text(), 11 if compact else 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	action_label = UiFactory.body_label("Klicke einen Raum oder ein Vorfeld.", 11 if compact else 13, UiFactory.COLOR_MUTED)
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(action_label)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	box.add_child(action_box)


func _build_actions_panel() -> void:
	var compact := UiFactory.is_compact_screen(self)
	actions_panel = PanelContainer.new()
	actions_panel.name = "ActionsPanel"
	actions_panel.add_theme_stylebox_override("panel", _glass_panel_style())
	add_child(actions_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5 if compact else 6)
	actions_panel.add_child(box)
	box.add_child(UiFactory.title_label("Schnellaktionen", 18 if compact else 22))
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	if OS.is_debug_build():
		_add_action_button(grid, "Bauplan (alt)", func() -> void: go_to("res://scenes/base/build_menu.tscn"), compact)
	_add_action_button(grid, "Crafting", open_crafting, compact)
	_add_action_button(grid, "Inventar", open_inventory, compact)
	_add_action_button(grid, "Elena", func() -> void: go_to("res://scenes/characters/elena.tscn"), compact)
	_add_action_button(grid, "Schlafen", _sleep, compact)
	_add_action_button(grid, "Karte", func() -> void: go_to("res://scenes/world_map/world_map.tscn"), compact)
	_build_scene_hotspots()


func _build_hint_label() -> void:
	hint_label = UiFactory.body_label("Klicke Raeume zum Freischalten. Oben: Verteidigungsanlagen.", 12, UiFactory.COLOR_MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)


func _build_scene_hotspots() -> void:
	_add_hotspot("workshop", "Crafting", open_crafting, GameState.is_room_unlocked("workshop"))
	_add_hotspot("storage_room", "Lager", open_inventory, GameState.is_room_unlocked("storage_room"))
	_add_hotspot("elena_quarters", "Elena", func() -> void: go_to("res://scenes/characters/elena.tscn"), GameState.is_room_unlocked("elena_quarters"))
	_add_hotspot("shaft_room", "Karte", func() -> void: go_to("res://scenes/world_map/world_map.tscn"), true)
	_add_hotspot("command_post", "Schlafen", _sleep, GameState.is_room_unlocked("command_post"))


func _add_hotspot(room_id: String, label: String, callback: Callable, hotspot_visible: bool) -> void:
	var data := DataCatalog.base_room(room_id)
	if data.is_empty():
		return
	var button := UiFactory.button(label, callback, 96)
	button.name = "Hotspot_%s" % room_id
	button.visible = hotspot_visible
	button.modulate = Color(1.0, 1.0, 1.0, 0.88)
	button.add_theme_font_size_override("font_size", 10)
	button.custom_minimum_size = Vector2(88, 28)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.set_meta("room_id", room_id)
	hotspot_layer.add_child(button)


func _position_panels() -> void:
	var compact := UiFactory.is_compact_screen(self)
	var top := 96.0 if compact else 118.0
	var bottom_inset := float(UiFactory.hud_bottom_inset(self, 14 if compact else 18))
	var margin := 14.0 if compact else 18.0
	var report_width := 360.0 if compact else 410.0
	var actions_width := 170.0 if compact else 196.0
	if is_instance_valid(report_panel):
		report_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		report_panel.offset_left = margin
		report_panel.offset_right = margin + report_width
		report_panel.offset_top = top
		report_panel.offset_bottom = -bottom_inset
	if is_instance_valid(actions_panel):
		actions_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		actions_panel.offset_left = -actions_width - margin
		actions_panel.offset_right = -margin
		actions_panel.offset_top = top
		actions_panel.offset_bottom = -bottom_inset
	if is_instance_valid(hint_label):
		hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		hint_label.offset_top = top - (28 if compact else 34)
		hint_label.offset_bottom = top - 4
		hint_label.offset_left = report_width + margin * 2.0
		hint_label.offset_right = -(actions_width + margin * 2.0)
	_position_hotspots()


func _position_hotspots() -> void:
	if not is_instance_valid(base_art):
		return
	var canvas := base_art.size
	if canvas.x <= 1.0 or canvas.y <= 1.0:
		canvas = UiFactory.viewport_size(self)
	for child in hotspot_layer.get_children():
		if not child.name.begins_with("Hotspot_"):
			continue
		var room_id := str(child.get_meta("room_id", ""))
		var data := DataCatalog.base_room(room_id)
		if data.is_empty():
			continue
		var rect := _room_rect(data, canvas)
		child.position = rect.position + Vector2((rect.size.x - child.size.x) * 0.5, rect.size.y - child.custom_minimum_size.y - 6.0)
		child.visible = _hotspot_visible(room_id)


func _hotspot_visible(room_id: String) -> bool:
	match room_id:
		"workshop":
			return GameState.is_room_unlocked("workshop")
		"storage_room":
			return GameState.is_room_unlocked("storage_room")
		"elena_quarters":
			return GameState.is_room_unlocked("elena_quarters")
		"command_post":
			return GameState.is_room_unlocked("command_post")
		"shaft_room":
			return true
	return false


func _room_rect(data: Dictionary, canvas: Vector2) -> Rect2:
	var rect: Dictionary = data.get("rect", {})
	return Rect2(
		float(rect.get("x", 0.0)) * canvas.x,
		float(rect.get("y", 0.0)) * canvas.y,
		float(rect.get("w", 0.1)) * canvas.x,
		float(rect.get("h", 0.1)) * canvas.y
	)


func _glass_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.014, 0.018, 0.48)
	style.border_color = Color(0.62, 0.48, 0.26, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _add_action_button(parent: Control, text: String, callback: Callable, compact_screen: bool) -> void:
	var button := UiFactory.button(text, callback, 160 if compact_screen else 176)
	if compact_screen:
		button.custom_minimum_size.y = 32
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
		action_label.text = "Klicke einen Raum oder ein Vorfeld."
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
	_position_hotspots()


func _sleep() -> void:
	TimeSystem.advance_to_morning()
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		get_tree().reload_current_scene()
