# Purpose: Path-based regional map with route points, locks, events, traders, dungeons, and animated location nodes.
# Public API: Click connected map nodes, rest to refill route points, enter the current location.
# Dependencies: GameplayScreen, DataCatalog, InventorySystem, TimeSystem, GameState.
extends GameplayScreen

const MapPathLayerScript := preload("res://scripts/world_map/map_path_layer.gd")
const MAP_TEXTURE := "res://assets/environments/map_overview/player_region_map.png"
const DETAIL_PANEL_TEXTURE := "res://assets/environments/map_overview/route_detail_reference.png"
const MAX_ROUTE_POINTS := 4
const NODE_SIZE := Vector2(52, 52)

const MAP_NODES := {
	"base": {"kind": "Basis", "pos": Vector2(0.4938, 0.6281), "neighbors": ["ruined_town", "forest", "ash_market", "grave_crossroads", "black_forge"], "phase": 0.0},
	"harbor_pier": {"kind": "Event", "pos": Vector2(0.2170, 0.8421), "neighbors": ["drowned_quay", "ruined_town", "withered_gate"], "phase": 0.25},
	"drowned_quay": {"kind": "Zone", "pos": Vector2(0.1489, 0.4220), "neighbors": ["radio_tower", "factory", "harbor_pier"], "phase": 0.5},
	"radio_tower": {"kind": "Event", "pos": Vector2(0.0884, 0.3162), "neighbors": ["drowned_quay", "factory"], "phase": 0.85, "requires": {"flag": "discovered_radio", "text": "Hinweis aus der Altstadt"}},
	"ruined_town": {"kind": "Zone", "pos": Vector2(0.3073, 0.6865), "neighbors": ["base", "withered_gate", "harbor_pier", "ash_market", "grave_crossroads"], "phase": 1.15},
	"withered_gate": {"kind": "Event", "pos": Vector2(0.2525, 0.7351), "neighbors": ["ruined_town", "harbor_pier", "black_forge"], "phase": 1.45},
	"ash_market": {"kind": "Haendler", "pos": Vector2(0.3011, 0.2664), "neighbors": ["base", "ruined_town", "factory", "cinder_works"], "phase": 1.75},
	"factory": {"kind": "Zone", "pos": Vector2(0.3275, 0.4148), "neighbors": ["drowned_quay", "ash_market", "cinder_works", "forest"], "phase": 2.05, "repair": {"flag": "bridge_repaired", "cost": {"wood": 2, "nails": 2, "metal": 1}, "text": "Bruecke zum Werk reparieren"}},
	"cinder_works": {"kind": "Zone", "pos": Vector2(0.4599, 0.3325), "neighbors": ["ash_market", "factory", "forest", "chapel"], "phase": 2.35},
	"chapel": {"kind": "Dungeon", "pos": Vector2(0.4946, 0.2117), "neighbors": ["cinder_works", "silent_monastery", "hospital"], "phase": 2.7, "requires": {"flag": "discovered_chapel", "text": "Spur aus dem Wald"}},
	"silent_monastery": {"kind": "Event", "pos": Vector2(0.5637, 0.3024), "neighbors": ["chapel", "forest", "hospital", "military"], "phase": 3.05},
	"forest": {"kind": "Zone", "pos": Vector2(0.5257, 0.4040), "neighbors": ["base", "factory", "cinder_works", "silent_monastery", "military", "grave_crossroads"], "phase": 3.35},
	"grave_crossroads": {"kind": "Event", "pos": Vector2(0.2593, 0.5426), "neighbors": ["ruined_town", "base", "black_forge"], "phase": 3.65},
	"black_forge": {"kind": "Dungeon", "pos": Vector2(0.4775, 0.8110), "neighbors": ["base", "withered_gate", "collapsed_bridge", "signal_observatory"], "phase": 4.0, "requires": {"level": 2}, "repair": {"flag": "forge_gate_open", "cost": {"metal": 2, "fuel": 1, "nails": 2}, "text": "Schmiedetor oeffnen"}},
	"collapsed_bridge": {"kind": "Event", "pos": Vector2(0.4352, 0.7490), "neighbors": ["black_forge", "signal_observatory", "sealed_metro"], "phase": 4.35},
	"signal_observatory": {"kind": "Event", "pos": Vector2(0.5792, 0.9135), "neighbors": ["collapsed_bridge", "old_bunker"], "phase": 4.7, "requires": {"flag": "discovered_radio", "text": "Funkfrequenz"}},
	"hospital": {"kind": "Zone", "pos": Vector2(0.7082, 0.4227), "neighbors": ["chapel", "silent_monastery", "military", "cathedral_gate"], "phase": 5.05},
	"cathedral_gate": {"kind": "Dungeon", "pos": Vector2(0.7131, 0.2667), "neighbors": ["hospital", "eastern_pass"], "phase": 5.35, "requires": {"level": 3}},
	"military": {"kind": "Zone", "pos": Vector2(0.6577, 0.6805), "neighbors": ["forest", "silent_monastery", "hospital", "old_bunker", "watchtower"], "phase": 5.7, "requires": {"level": 2}},
	"old_bunker": {"kind": "Dungeon", "pos": Vector2(0.7080, 0.5377), "neighbors": ["military", "signal_observatory", "south_roadblock"], "phase": 6.05, "requires": {"flag": "bunker_code", "text": "Bunkercode aus dem Observatorium", "level": 4}},
	"eastern_pass": {"kind": "Event", "pos": Vector2(0.9108, 0.3871), "neighbors": ["cathedral_gate", "watchtower"], "phase": 6.4, "requires": {"level": 3}},
	"watchtower": {"kind": "Zone", "pos": Vector2(0.8914, 0.5898), "neighbors": ["eastern_pass", "military", "south_roadblock"], "phase": 6.75, "requires": {"flag": "watchtower_key", "text": "Schluessel vom Kontrollpunkt"}},
	"south_roadblock": {"kind": "Event", "pos": Vector2(0.8082, 0.7065), "neighbors": ["watchtower", "old_bunker", "sealed_metro"], "phase": 7.1},
	"sealed_metro": {"kind": "Dungeon", "pos": Vector2(0.7268, 0.8457), "neighbors": ["collapsed_bridge", "south_roadblock"], "phase": 7.8, "requires": {"level": 5}, "repair": {"flag": "metro_power_restored", "cost": {"electronics": 2, "fuel": 2, "metal": 2}, "text": "Metro-Tor mit Strom versorgen"}}
}

var message_label: Label
var side_panel: PanelContainer
var side_box: VBoxContainer
var travel_label: Label
var preview_label: Label
var detail_label: Label
var detail_panel: PanelContainer
var travel_button: Button
var enter_button: Button
var map_canvas: Control
var path_layer: Control
var node_buttons: Dictionary = {}
var node_labels: Dictionary = {}
var travel_bars: Dictionary = {}
var preview_node_id := ""
var selected_node_id := ""
var map_anim_time := 0.0
var map_texture_size := Vector2(1536, 1024)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	for child in get_children():
		remove_child(child)
		child.queue_free()
	AudioManager.play_music(
		"res://assets/audio/music/ambient_night/below_the_walls.wav" if TimeSystem.is_night()
		else "res://assets/audio/music/ambient_day/fragile_morning.wav",
		-10.0
	)
	set_process(true)
	_sync_route_points()
	if not MAP_NODES.has(GameState.current_location):
		GameState.current_location = "base"
	_build_map(self)
	_build_side(self)
	add_child(HUD_SCENE.instantiate())
	_refresh_map()


func _process(delta: float) -> void:
	map_anim_time += delta
	_position_nodes()
	_animate_nodes()
	if is_instance_valid(path_layer):
		path_layer.queue_redraw()


func _draw() -> void:
	pass


func _build_map(parent: Control) -> void:
	map_canvas = Control.new()
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(map_canvas)
	var art := TextureRect.new()
	art.texture = _load_map_texture(MAP_TEXTURE)
	if art.texture:
		map_texture_size = art.texture.get_size()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.96, 0.96, 0.92, 0.98)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.03, 0.10)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(shade)
	path_layer = MapPathLayerScript.new()
	path_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(path_layer)
	_build_nodes()


func _build_nodes() -> void:
	for node_id in MAP_NODES:
		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.pivot_offset = NODE_SIZE * 0.5
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.mouse_entered.connect(func() -> void: _preview_node(str(node_id)))
		button.mouse_exited.connect(func() -> void: _clear_preview(str(node_id)))
		button.pressed.connect(func() -> void: _select_node(str(node_id)))
		map_canvas.add_child(button)
		node_buttons[str(node_id)] = button
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color("#f4e1b8"))
		name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		name_label.add_theme_constant_override("shadow_offset_x", 2)
		name_label.add_theme_constant_override("shadow_offset_y", 2)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map_canvas.add_child(name_label)
		node_labels[str(node_id)] = name_label


func _load_map_texture(path: String) -> Texture2D:
	var imported_texture := load(path) as Texture2D
	if imported_texture:
		return imported_texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _build_side(parent: Control) -> void:
	var compact := UiFactory.is_compact_screen()
	side_panel = PanelContainer.new()
	_position_side_panel()
	var panel_style := UiFactory._panel_style()
	panel_style.bg_color = Color(0.01, 0.012, 0.016, 0.91)
	panel_style.border_color = Color(0.55, 0.45, 0.26, 0.82)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	side_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(side_panel)
	side_box = VBoxContainer.new()
	side_box.custom_minimum_size.x = 398 if compact else 442
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 7)
	side_panel.add_child(side_box)

	var header_art := TextureRect.new()
	header_art.texture = _load_map_texture(DETAIL_PANEL_TEXTURE)
	header_art.custom_minimum_size = Vector2(0, 82 if compact else 104)
	header_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header_art.modulate = Color(1.0, 0.92, 0.78, 0.48)
	header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_box.add_child(header_art)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	side_box.add_child(title_row)
	var route_icon := TextureRect.new()
	route_icon.texture = load("res://assets/items/backpacks/small_backpack.svg")
	route_icon.custom_minimum_size = Vector2(34, 34)
	route_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	route_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(route_icon)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 1)
	title_row.add_child(title_column)
	title_column.add_child(UiFactory.title_label("REISE", 24 if compact else 28))
	message_label = UiFactory.body_label("Zeige auf einen Ort oder klicke ihn an.", 14, UiFactory.COLOR_MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_column.add_child(message_label)

	travel_label = UiFactory.body_label("", 17, UiFactory.COLOR_GOLD)
	side_box.add_child(travel_label)
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_style := UiFactory._panel_style()
	preview_style.bg_color = Color(0.015, 0.017, 0.022, 0.90)
	preview_style.border_color = Color(0.40, 0.32, 0.19, 0.88)
	preview_style.content_margin_left = 12
	preview_style.content_margin_right = 12
	preview_style.content_margin_top = 10
	preview_style.content_margin_bottom = 10
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	side_box.add_child(preview_panel)
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_box)
	preview_label = UiFactory.body_label("", 15, Color("#f0dca9"))
	preview_label.custom_minimum_size.y = 48
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(preview_label)
	_add_travel_bar(preview_box, "route", "Reisepunkte", Color("#d8b36a"), "res://assets/items/backpacks/small_backpack.svg")
	_add_travel_bar(preview_box, "duration", "Reisedauer", Color("#5f95e8"), "res://assets/items/armor/work_boots.svg")
	_add_travel_bar(preview_box, "stamina", "Ausdauer", Color("#d09b3d"), "res://assets/ui/icons/stamina.svg")
	_add_travel_bar(preview_box, "energy", "Energie", Color("#77c7ff"), "res://assets/ui/icons/energy.svg")
	_add_travel_bar(preview_box, "hunger", "Nahrung", Color("#7ccf6b"), "res://assets/ui/icons/hunger.svg")
	_add_travel_bar(preview_box, "thirst", "Wasser", Color("#69a7ff"), "res://assets/ui/icons/thirst.svg")
	_build_map_legend(side_box)
	detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_style := UiFactory._panel_style()
	detail_style.bg_color = Color(0.01, 0.012, 0.016, 0.86)
	detail_style.border_color = Color(0.33, 0.28, 0.18, 0.88)
	detail_style.content_margin_left = 10
	detail_style.content_margin_right = 10
	detail_style.content_margin_top = 8
	detail_style.content_margin_bottom = 8
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	side_box.add_child(detail_panel)
	detail_label = UiFactory.body_label("", 14, Color("#d8dde8"))
	detail_label.custom_minimum_size.y = 70
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(detail_label)

	var actions := GridContainer.new()
	actions.columns = 3
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	side_box.add_child(actions)
	travel_button = _side_button("Ziel", _confirm_travel, "res://assets/items/misc/signal_flare.svg", "Gewaehltes Ziel bereisen oder gesperrten Pfad reparieren.")
	actions.add_child(travel_button)
	enter_button = _side_button("Betreten", _enter_current_location, _kind_icon("Basis"), "Aktuellen Ort betreten.")
	actions.add_child(enter_button)
	actions.add_child(_side_button("Rasten", _rest_on_map, "res://assets/items/medical/bandage.svg", "Vier Stunden rasten und Reisepunkte auffuellen."))
	actions.add_child(_side_button("Char", open_equipment, "res://assets/ui/icons/shield.svg", "Ausrichtung und Charakterwerte oeffnen."))
	actions.add_child(_side_button("Craft", open_crafting, "res://assets/items/materials/metal.svg", "Crafting-Menue oeffnen."))
	actions.add_child(_side_button("Level", open_level, "res://assets/ui/icons/energy.svg", "Level- und Faehigkeitsmenue oeffnen."))


func _refresh_map() -> void:
	_sync_route_points()
	_refresh_node_buttons()
	_refresh_side()
	_refresh_paths()


func _refresh_node_buttons() -> void:
	for node_id in node_buttons:
		var button := node_buttons[node_id] as Button
		var node: Dictionary = MAP_NODES[node_id]
		var location := DataCatalog.location(str(node_id))
		var kind := str(node.get("kind", "Ort"))
		var current := str(node_id) == GameState.current_location
		var neighbor := _is_neighbor(GameState.current_location, str(node_id))
		var blocker := _requirement_blocker(str(node_id))
		var locked := not blocker.is_empty()
		var selected := str(node_id) == selected_node_id
		var previewed := str(node_id) == preview_node_id and selected_node_id.is_empty()
		var location_name := str(location.get("name", node_id))
		var label := node_labels.get(str(node_id)) as Label
		if is_instance_valid(label):
			label.text = _map_label_text(location_name)
			label.tooltip_text = _node_tooltip(str(node_id), blocker)
			label.modulate = Color(1, 1, 1, 0.56 if locked else 0.92)
			label.add_theme_color_override("font_color", Color("#f0b84c") if current else (_kind_color(kind).lightened(0.22) if selected or previewed else Color("#f4e1b8")))
		button.text = ""
		button.icon = load(_kind_icon(kind, locked))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.tooltip_text = _node_tooltip(str(node_id), blocker)
		button.disabled = false
		button.modulate = Color(1, 1, 1, 1.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.045, 0.058, 0.86)
		style.border_color = _kind_color(kind)
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		if current:
			style.bg_color = Color(0.08, 0.10, 0.13, 0.94)
			style.border_color = Color("#f0b84c")
			style.set_border_width_all(3)
			style.shadow_color = Color("#f0b84c")
			style.shadow_size = 12
		elif selected:
			style.bg_color = Color(0.06, 0.09, 0.12, 0.94)
			style.border_color = Color("#58a6ff")
			style.set_border_width_all(3)
			style.shadow_color = Color("#58a6ff")
			style.shadow_size = 10
		elif previewed:
			style.bg_color = Color(0.055, 0.065, 0.075, 0.90)
			style.border_color = Color("#d8b36a")
			style.shadow_color = Color("#d8b36a")
			style.shadow_size = 6
		elif locked:
			style.bg_color = Color(0.035, 0.025, 0.025, 0.82)
			style.border_color = Color("#9b3c35")
			button.modulate = Color(0.72, 0.72, 0.72, 0.88)
		elif not neighbor:
			button.modulate = Color(0.80, 0.80, 0.80, 0.70)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_color_override("font_color", Color("#f2dfb8") if current else Color("#d8dde8"))
	_position_nodes()


func _build_map_legend(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UiFactory._panel_style()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	for entry in [
		{"label": "Basis", "kind": "Basis"},
		{"label": "Zone", "kind": "Zone"},
		{"label": "Event", "kind": "Event"},
		{"label": "Haendler", "kind": "Haendler"},
		{"label": "Dungeon", "kind": "Dungeon"},
		{"label": "Gesperrt", "kind": "Gesperrt"}
	]:
		grid.add_child(_legend_chip(str(entry["label"]), str(entry["kind"])))


func _legend_chip(text: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(13, 13)
	marker.color = _kind_color(kind)
	row.add_child(marker)
	var label := UiFactory.body_label(text, 11, UiFactory.COLOR_MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	return row


func _side_button(text: String, callback: Callable, icon_path: String = "", tooltip: String = "") -> Button:
	var button := UiFactory.button(text, callback, 126)
	button.custom_minimum_size = Vector2(126, 46)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	if not icon_path.is_empty():
		button.icon = load(icon_path)
	if not tooltip.is_empty():
		button.tooltip_text = tooltip
	return button


func _position_nodes() -> void:
	if not is_instance_valid(map_canvas):
		return
	for node_id in node_buttons:
		var button := node_buttons[node_id] as Button
		var node: Dictionary = MAP_NODES[node_id]
		var pos: Vector2 = node.get("pos", Vector2(0.5, 0.5))
		var point := _map_point_to_canvas(pos)
		button.position = point - NODE_SIZE * 0.5
		var label := node_labels.get(str(node_id)) as Label
		if is_instance_valid(label):
			label.custom_minimum_size = Vector2(148, 34)
			label.size = label.custom_minimum_size
			label.position = point + Vector2(-74, 28)


func _map_image_rect() -> Rect2:
	if not is_instance_valid(map_canvas):
		return Rect2(Vector2.ZERO, map_texture_size)
	var canvas_size := map_canvas.size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		canvas_size = map_canvas.custom_minimum_size
	return Rect2(Vector2.ZERO, canvas_size)


func _map_point_to_canvas(pos: Vector2) -> Vector2:
	var rect := _map_image_rect()
	return rect.position + Vector2(pos.x * rect.size.x, pos.y * rect.size.y)


func _map_point_to_canvas_norm(pos: Vector2) -> Vector2:
	if not is_instance_valid(map_canvas) or map_canvas.size.x <= 0.0 or map_canvas.size.y <= 0.0:
		return pos
	var point := _map_point_to_canvas(pos)
	return Vector2(point.x / map_canvas.size.x, point.y / map_canvas.size.y)


func _visible_map_nodes() -> Dictionary:
	var transformed := {}
	for node_id in MAP_NODES:
		var data: Dictionary = MAP_NODES[node_id].duplicate(true)
		data["pos"] = _map_point_to_canvas_norm(data.get("pos", Vector2(0.5, 0.5)))
		transformed[node_id] = data
	return transformed


func _animate_nodes() -> void:
	for node_id in node_buttons:
		var button := node_buttons[node_id] as Button
		var node: Dictionary = MAP_NODES[node_id]
		var phase := float(node.get("phase", 0.0))
		var pulse := (sin(map_anim_time * 2.1 + phase) + 1.0) * 0.5
		var current := str(node_id) == GameState.current_location
		var locked := not _requirement_blocker(str(node_id)).is_empty()
		var scale_to := 1.0 + pulse * (0.045 if current else 0.025)
		button.scale = Vector2(scale_to, scale_to)
		if locked:
			button.self_modulate.a = lerpf(0.70, 0.92, pulse)
		else:
			button.self_modulate.a = 1.0


func _refresh_side() -> void:
	_position_side_panel()
	if is_instance_valid(side_panel):
		side_panel.visible = not _active_target_id().is_empty()
	travel_label.text = "Reisepunkte: %d/%d   Zeit: Tag %d, %s" % [
		_route_points_left(),
		MAX_ROUTE_POINTS,
		TimeSystem.current_day,
		TimeSystem.current_phase()
	]
	if is_instance_valid(detail_panel):
		detail_panel.visible = not selected_node_id.is_empty()
	detail_label.visible = not selected_node_id.is_empty()
	detail_label.text = _selected_location_text()
	_refresh_travel_preview()


func _position_side_panel() -> void:
	if not is_instance_valid(side_panel):
		return
	var compact := UiFactory.is_compact_screen()
	var panel_width := 420.0 if compact else 468.0
	var top := 98.0 if compact else 122.0
	var target_id := _active_target_id()
	var target_pos := Vector2(0.0, 0.0)
	if MAP_NODES.has(target_id):
		target_pos = MAP_NODES[target_id].get("pos", Vector2(0.0, 0.0))
	var show_on_left := target_pos.x > 0.62
	if show_on_left:
		side_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		side_panel.offset_left = 18
		side_panel.offset_right = 18 + panel_width
	else:
		side_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		side_panel.offset_left = -panel_width - 18
		side_panel.offset_right = -18
	side_panel.offset_top = top
	side_panel.offset_bottom = -18


func _add_travel_bar(parent: VBoxContainer, key: String, label_text: String, color: Color, icon_path: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(34, 34)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.04, 0.04, 0.045, 0.88)
	icon_style.border_color = color.darkened(0.25)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(2)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = load(icon_path) if not icon_path.is_empty() else null
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1.0, 0.93, 0.75, 0.92)
	icon_frame.add_child(icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var top_row := HBoxContainer.new()
	column.add_child(top_row)
	var label := UiFactory.body_label(label_text, 11, UiFactory.COLOR_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(label)
	var value := UiFactory.body_label("", 11, Color("#d8dde8"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 104
	top_row.add_child(value)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 15)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.01, 0.012, 0.015, 0.98)
	background.border_color = Color(0.22, 0.20, 0.16, 0.88)
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	travel_bars[key] = {"bar": bar, "value": value}


func _refresh_travel_preview() -> void:
	if not is_instance_valid(preview_label):
		return
	var route_points := _route_points_left()
	var stamina := float(GameState.player_stats.get("stamina", 0.0))
	var energy := float(GameState.player_stats.get("energy", 0.0))
	var hunger := float(GameState.player_stats.get("hunger", 0.0))
	var thirst := float(GameState.player_stats.get("thirst", 0.0))
	var target_id := _active_target_id()
	var cost := 0
	var route_after := route_points
	var stamina_after := stamina
	var energy_after := energy
	var hunger_after := hunger
	var thirst_after := thirst
	var preview_text := "Waehle einen verbundenen Ort auf der Karte."
	var button_text := "Waehlen"
	var button_disabled := true
	if not target_id.is_empty() and MAP_NODES.has(target_id):
		var location := DataCatalog.location(target_id)
		cost = _route_cost(target_id)
		route_after = maxi(0, route_points - cost)
		stamina_after = maxf(0.0, stamina - _travel_stamina_cost(cost))
		energy_after = maxf(0.0, energy - _travel_energy_cost(cost))
		hunger_after = maxf(0.0, hunger - _travel_hunger_cost(cost))
		thirst_after = maxf(0.0, thirst - _travel_thirst_cost(cost))
		if target_id == GameState.current_location:
			preview_text = "%s\nAktueller Ort. Du kannst ihn betreten." % location.get("name", target_id)
		elif not _is_neighbor(GameState.current_location, target_id):
			preview_text = "%s\nKein direkter Pfad. Nutze die verbundenen Wege." % location.get("name", target_id)
		else:
			var blocker := _requirement_blocker(target_id)
			if not blocker.is_empty():
				preview_text = "%s\n%s" % [location.get("name", target_id), blocker]
				if selected_node_id == target_id and _can_repair_requirement(target_id):
					button_text = "Reparieren"
					button_disabled = false
			elif route_points < cost:
				preview_text = "%s\nZu wenig Reisepunkte. Raste zuerst." % location.get("name", target_id)
			else:
				preview_text = "%s\nAnkunft: %s\nKosten: %d Reisepunkt(e)" % [
					location.get("name", target_id),
					_arrival_text(cost),
					cost
				]
				if selected_node_id == target_id:
					button_text = "Reisen"
					button_disabled = false
				else:
					button_text = "Anklicken"
					button_disabled = true
	preview_label.text = preview_text
	if is_instance_valid(travel_button):
		travel_button.text = button_text
		travel_button.disabled = button_disabled
	_set_travel_bar("route", route_after, MAX_ROUTE_POINTS, "%d -> %d" % [route_points, route_after], "Verbleibende Reisepunkte nach der Reise.")
	_set_travel_bar("duration", cost, MAX_ROUTE_POINTS, "%d Runde(n)" % cost, "Eine Runde entspricht einer Stunde.")
	_set_travel_bar("stamina", stamina_after, _resource_max_for_bar("stamina", stamina), "%.0f -> %.0f" % [stamina, stamina_after], "Ausdauer nach Bewegung, Wetter und Zeitverbrauch.")
	_set_travel_bar("energy", energy_after, _resource_max_for_bar("energy", energy), "%.0f -> %.0f" % [energy, energy_after], "Energie nach Reise und Zeitverbrauch.")
	_set_travel_bar("hunger", hunger_after, 100.0, "%.0f -> %.0f" % [hunger, hunger_after], "Nahrungssaettigung nach der Reise.")
	_set_travel_bar("thirst", thirst_after, 100.0, "%.0f -> %.0f" % [thirst, thirst_after], "Wasserversorgung nach der Reise.")


func _set_travel_bar(key: String, value: float, maximum: float, text: String, tooltip: String = "") -> void:
	var entry: Dictionary = travel_bars.get(key, {})
	if entry.is_empty():
		return
	var bar := entry.get("bar") as ProgressBar
	var label := entry.get("value") as Label
	if is_instance_valid(bar):
		bar.max_value = maxf(maximum, 1.0)
		bar.value = clampf(value, 0.0, bar.max_value)
		bar.tooltip_text = tooltip
	if is_instance_valid(label):
		label.text = text
		label.tooltip_text = tooltip


func _resource_max_for_bar(resource_id: String, current_value: float) -> float:
	return maxf(maxf(GameState.max_resource(resource_id), current_value), 1.0)


func _arrival_text(cost: int) -> String:
	var total_hours := ((TimeSystem.current_day - 1) * TimeSystem.HOURS_PER_DAY) + TimeSystem.current_hour() + cost
	var arrival_day := floori(float(total_hours) / float(TimeSystem.HOURS_PER_DAY)) + 1
	var arrival_hour := total_hours % TimeSystem.HOURS_PER_DAY
	return "Tag %d, %02d:00" % [arrival_day, arrival_hour]


func _refresh_paths() -> void:
	if not is_instance_valid(path_layer):
		return
	var states := {}
	for node_id in MAP_NODES:
		for neighbor in MAP_NODES[node_id].get("neighbors", []):
			var target := str(neighbor)
			if not MAP_NODES.has(target):
				continue
			var key := _edge_key(str(node_id), target)
			if states.has(key):
				continue
			states[key] = _edge_state(str(node_id), target)
	path_layer.configure(_visible_map_nodes(), states)


func _select_node(node_id: String) -> void:
	if not MAP_NODES.has(node_id):
		return
	preview_node_id = node_id
	selected_node_id = node_id
	if node_id == GameState.current_location:
		message_label.text = "Aktueller Ort markiert. Nutze Ort betreten."
		_refresh_map()
		return
	if not _is_neighbor(GameState.current_location, node_id):
		message_label.text = "Ziel markiert, aber kein direkter Pfad fuehrt dorthin."
		_refresh_map()
		return
	var blocker := _requirement_blocker(node_id)
	if not blocker.is_empty():
		message_label.text = blocker
		_refresh_map()
		return
	message_label.text = "%s als Reiseziel markiert. Pruefe die Werte rechts." % DataCatalog.location(node_id).get("name", node_id)
	_refresh_map()


func _preview_node(node_id: String) -> void:
	if not MAP_NODES.has(node_id):
		return
	preview_node_id = node_id
	var location := DataCatalog.location(node_id)
	if node_id == GameState.current_location:
		message_label.text = "%s ist dein aktueller Ort." % location.get("name", node_id)
	elif not _is_neighbor(GameState.current_location, node_id):
		message_label.text = "%s ist nur ueber Zwischenstationen erreichbar." % location.get("name", node_id)
	else:
		message_label.text = "%s: Verbrauch wird rechts angezeigt." % location.get("name", node_id)
	_refresh_map()


func _clear_preview(node_id: String) -> void:
	if selected_node_id.is_empty() and preview_node_id == node_id:
		preview_node_id = ""
		message_label.text = "Zeige auf einen Ort oder klicke ihn an."
		_refresh_map()


func _confirm_travel() -> void:
	var node_id := selected_node_id
	if node_id.is_empty() or not MAP_NODES.has(node_id):
		message_label.text = "Waehle zuerst ein Ziel auf der Karte."
		_refresh_map()
		return
	if node_id == GameState.current_location:
		message_label.text = "Du bist bereits hier. Nutze Ort betreten."
		_refresh_map()
		return
	if not _is_neighbor(GameState.current_location, node_id):
		message_label.text = "Kein direkter Pfad. Du musst ueber verbundene Orte reisen."
		_refresh_map()
		return
	var blocker := _requirement_blocker(node_id)
	if not blocker.is_empty():
		if _try_unlock_requirement(node_id):
			_refresh_map()
			return
		message_label.text = blocker
		_refresh_map()
		return
	var cost := _route_cost(node_id)
	if _route_points_left() < cost:
		message_label.text = "Du bist zu weit gereist. Raste, bevor du weitergehst."
		_refresh_map()
		return
	_set_route_points(_route_points_left() - cost)
	GameState.current_location = node_id
	GameState.run_statistics.locations_visited = int(GameState.run_statistics.locations_visited) + 1
	GameState.spend_for_action(cost * 6.0, cost * 4.0)
	TimeSystem.advance(cost, "Du erreichst %s." % DataCatalog.location(node_id).get("name", node_id))
	message_label.text = "Angekommen: %s." % DataCatalog.location(node_id).get("name", node_id)
	_handle_arrival_flags(node_id)
	selected_node_id = ""
	preview_node_id = ""
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		_refresh_map()


func _enter_current_location() -> void:
	var node_id := GameState.current_location
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var kind := str(node.get("kind", "Zone"))
	if node_id == "base":
		go_to("res://scenes/base/base_scene.tscn")
		return
	if kind == "Haendler":
		_visit_trader()
		return
	if kind == "Event":
		_resolve_event(node_id)
		return
	GameState.return_scene = scene_file_path
	go_to("res://scenes/exploration/exploration_scene.tscn")


func _visit_trader() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/trader_screen.tscn")


func _resolve_event(node_id: String) -> void:
	if node_id == "collapsed_bridge":
		GameState.quest_flags["bridge_scouted"] = true
		message_label.text = "Du markierst tragende Stellen. Mit Material kann der Pfad zum Werk repariert werden."
	elif node_id == "harbor_pier":
		GameState.quest_flags["harbor_route_mapped"] = true
		message_label.text = "Am Kai findest du eine sichere Linie durch die versunkenen Strassen."
	elif node_id == "withered_gate":
		GameState.quest_flags["bridge_scouted"] = true
		message_label.text = "Das verrostete Tor zeigt dir, wo der suedliche Pfad wieder tragfaehig wird."
	elif node_id == "grave_crossroads":
		GameState.quest_flags["discovered_radio"] = true
		message_label.text = "Zwischen den Kreuzen liegt eine Funknotiz. Der Turm ist nun markiert."
	elif node_id == "radio_tower":
		GameState.quest_flags["bunker_code"] = true
		message_label.text = "Im Rauschen liegt ein Bunkercode. Ein tieferer Ort ist nun erreichbar."
	elif node_id == "silent_monastery":
		GameState.quest_flags["discovered_chapel"] = true
		message_label.text = "Die Mauerinschrift weist zur versunkenen Kapelle."
	elif node_id == "signal_observatory":
		GameState.quest_flags["discovered_chapel"] = true
		GameState.quest_flags["bunker_code"] = true
		message_label.text = "Die Sternwarte trianguliert zwei Signale: Kapelle und Bunker."
	elif node_id == "eastern_pass":
		GameState.quest_flags["east_route_mapped"] = true
		message_label.text = "Du markierst den Ostpass. Der Rueckweg ist knapp, aber lesbar."
	elif node_id == "south_roadblock":
		GameState.quest_flags["watchtower_key"] = true
		message_label.text = "Im Kontrollkasten liegt ein Wachtturmschluessel."
	else:
		message_label.text = "Du sicherst Spuren und markierst den Ort auf der Karte."
	TimeSystem.advance(1, "Event abgeschlossen.")
	_refresh_map()


func _rest_on_map() -> void:
	TimeSystem.advance(4, "Du rastest, pruefst Ausruestung und wartest auf bessere Sicht.")
	GameState.rest_player()
	_set_route_points(MAX_ROUTE_POINTS)
	message_label.text = "Du bist ausgeruht. Die Route ist wieder frei planbar."
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		_refresh_map()


func _handle_arrival_flags(node_id: String) -> void:
	if node_id == "ruined_town" or node_id == "grave_crossroads":
		GameState.quest_flags["discovered_radio"] = true
	if node_id == "forest" or node_id == "silent_monastery":
		GameState.quest_flags["discovered_chapel"] = true
	if node_id == "military":
		GameState.quest_flags["watchtower_key"] = true


func _try_unlock_requirement(node_id: String) -> bool:
	if not _access_requirement_blocker(node_id).is_empty():
		return false
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var repair: Dictionary = node.get("repair", {})
	if repair.is_empty():
		return false
	var flag := str(repair.get("flag", ""))
	if flag.is_empty() or bool(GameState.quest_flags.get(flag, false)):
		return false
	var cost: Dictionary = repair.get("cost", {})
	if not InventorySystem.has_items(cost):
		return false
	if InventorySystem.consume_cost(cost):
		GameState.quest_flags[flag] = true
		message_label.text = "%s abgeschlossen. Der Pfad ist jetzt offen." % repair.get("text", "Reparatur")
		AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -8.0)
		return true
	return false


func _requirement_blocker(node_id: String) -> String:
	var access_blocker := _access_requirement_blocker(node_id)
	if not access_blocker.is_empty():
		return access_blocker
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var repair: Dictionary = node.get("repair", {})
	if not repair.is_empty() and not bool(GameState.quest_flags.get(str(repair.get("flag", "")), false)):
		var cost: Dictionary = repair.get("cost", {})
		return "Gesperrt: %s (%s)." % [repair.get("text", "Reparatur"), UiFactory.cost_text(cost)]
	return ""


func _access_requirement_blocker(node_id: String) -> String:
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var requires: Dictionary = node.get("requires", {})
	if not requires.is_empty():
		var level_required := int(requires.get("level", 0))
		if level_required > 0 and int(GameState.player_stats.get("level", 1)) < level_required:
			return "Gesperrt: benoetigt Level %d." % level_required
		var flag := str(requires.get("flag", ""))
		if not flag.is_empty() and not bool(GameState.quest_flags.get(flag, false)):
			return "Gesperrt: %s fehlt." % requires.get("text", flag)
		var item_id := str(requires.get("item", ""))
		if not item_id.is_empty() and int(InventorySystem.items.get(item_id, 0)) <= 0:
			return "Gesperrt: %s wird benoetigt." % DataCatalog.item(item_id).get("name", item_id)
	return ""


func _can_repair_requirement(node_id: String) -> bool:
	if not _access_requirement_blocker(node_id).is_empty():
		return false
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var repair: Dictionary = node.get("repair", {})
	if repair.is_empty():
		return false
	var flag := str(repair.get("flag", ""))
	if flag.is_empty() or bool(GameState.quest_flags.get(flag, false)):
		return false
	return InventorySystem.has_items(repair.get("cost", {}))


func _node_tooltip(node_id: String, blocker: String) -> String:
	var location := DataCatalog.location(node_id)
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var lines: Array[String] = [
		str(location.get("name", node_id)),
		"%s - Gefahr %d - Kosten %d Reisepunkt(e)" % [
			node.get("kind", location.get("type", "Ort")),
			int(location.get("danger", 0)),
			_route_cost(node_id)
		],
		str(location.get("description", ""))
	]
	if not blocker.is_empty():
		lines.append(blocker)
	elif not _is_neighbor(GameState.current_location, node_id) and node_id != GameState.current_location:
		lines.append("Nicht direkt verbunden.")
	return "\n".join(lines)


func _selected_location_text() -> String:
	if selected_node_id.is_empty() or not MAP_NODES.has(selected_node_id):
		return ""
	var node_id := selected_node_id
	var location := DataCatalog.location(node_id)
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var kind := str(node.get("kind", location.get("type", "Ort")))
	var lines: Array[String] = [
		"%s | %s | Gefahr %d | %d RP" % [location.get("name", node_id), kind, int(location.get("danger", 0)), _route_cost(node_id)],
		_short_text(str(location.get("description", "")), 106),
		"Pfade: %s" % _short_text(_neighbor_names(node_id), 110)
	]
	var blocker := _requirement_blocker(node_id)
	if not blocker.is_empty():
		lines.append(_short_text(blocker, 110))
	return "\n".join(lines)


func _short_text(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return value.substr(0, maxi(0, max_chars - 3)) + "..."


func _neighbor_names(node_id: String) -> String:
	var names: Array[String] = []
	for neighbor in MAP_NODES.get(node_id, {}).get("neighbors", []):
		var id := str(neighbor)
		names.append(str(DataCatalog.location(id).get("name", id)))
	return ", ".join(names)


func _edge_state(a: String, b: String) -> String:
	var current := GameState.current_location
	var active := _active_target_id()
	if not active.is_empty() and _edge_key(a, b) == _edge_key(current, active):
		if _is_neighbor(current, active) and _requirement_blocker(active).is_empty():
			return "selected"
	if a == current or b == current:
		var target := b if a == current else a
		if not _requirement_blocker(target).is_empty():
			return "locked"
		if _route_points_left() >= _route_cost(target):
			return "available"
		return "current"
	if not _requirement_blocker(a).is_empty() or not _requirement_blocker(b).is_empty():
		return "locked"
	return "distant"


func _is_neighbor(from_id: String, to_id: String) -> bool:
	if from_id == to_id:
		return true
	if not MAP_NODES.has(from_id) or not MAP_NODES.has(to_id):
		return false
	return MAP_NODES[from_id].get("neighbors", []).has(to_id) or MAP_NODES[to_id].get("neighbors", []).has(from_id)


func _route_cost(node_id: String) -> int:
	var location := DataCatalog.location(node_id)
	return clampi(int(location.get("travel", 1)), 1, 3) if node_id != "base" else 0


func _travel_stamina_cost(cost: int) -> float:
	return float(cost) * 10.0


func _travel_energy_cost(cost: int) -> float:
	return float(cost) * 7.0


func _travel_hunger_cost(cost: int) -> float:
	return float(cost) * 4.0


func _travel_thirst_cost(cost: int) -> float:
	return float(cost) * 6.0


func _sync_route_points() -> void:
	if int(GameState.quest_flags.get("route_day", 0)) != TimeSystem.current_day:
		GameState.quest_flags["route_day"] = TimeSystem.current_day
		GameState.quest_flags["route_points"] = MAX_ROUTE_POINTS


func _route_points_left() -> int:
	_sync_route_points()
	return clampi(int(GameState.quest_flags.get("route_points", MAX_ROUTE_POINTS)), 0, MAX_ROUTE_POINTS)


func _set_route_points(value: int) -> void:
	GameState.quest_flags["route_day"] = TimeSystem.current_day
	GameState.quest_flags["route_points"] = clampi(value, 0, MAX_ROUTE_POINTS)


func _campaign_summary() -> String:
	return "Basis: %.0f%%\nElenas Stress: %.0f%%\nUeberlebende: %d\nReisen: %d" % [
		float(GameState.base_state.integrity),
		float(GameState.elena.stress),
		GameState.survivors.size(),
		int(GameState.run_statistics.locations_visited)
	]


func _kind_color(kind: String) -> Color:
	match kind:
		"Basis":
			return Color("#7ccf6b")
		"Haendler":
			return Color("#f0b84c")
		"Event":
			return Color("#58a6ff")
		"Dungeon":
			return Color("#c36155")
		"Gesperrt":
			return Color("#9b3c35")
		_:
			return Color("#d8b36a")


func _kind_icon(kind: String, locked: bool = false) -> String:
	if locked:
		return "res://assets/ui/icons/shield.svg"
	match kind:
		"Basis":
			return "res://assets/items/backpacks/small_backpack.svg"
		"Haendler":
			return "res://assets/items/drinks/clean_water.svg"
		"Event":
			return "res://assets/items/misc/radio_parts.svg"
		"Dungeon":
			return "res://assets/items/medical/cleansing_salt.svg"
		_:
			return "res://assets/items/misc/flashlight_battery.svg"


func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func _active_target_id() -> String:
	return selected_node_id if not selected_node_id.is_empty() else preview_node_id


func _map_label_text(value: String) -> String:
	var words := value.split(" ", false)
	if words.size() <= 1:
		return value
	if words.size() == 2:
		return "\n".join(words)
	return "%s\n%s" % [words[0], " ".join(words.slice(1))]
