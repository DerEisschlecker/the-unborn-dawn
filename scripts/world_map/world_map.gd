# Purpose: Regional world map with travel popup, stat costs, and animated location nodes.
# Public API: Click a location to open travel popup, enter after arrival.
# Dependencies: GameplayScreen, DataCatalog, InventorySystem, TimeSystem, GameState.
extends GameplayScreen

const MAP_TEXTURE := "res://assets/environments/map_overview/world_main_map.jpg"
const MAP_SIZE_FALLBACK := Vector2(6688, 3764)
const MAP_ZOOM_MAX := 2.5
const MAP_PAN_SPEED := 1100.0
const MAP_DRAG_THRESHOLD := 5.0
const DETAIL_PANEL_TEXTURE := "res://assets/environments/map_overview/route_detail_reference.png"
const REST_CAMP_SCENE := "res://scenes/world_map/rest_camp_scene.tscn"
const NODE_SIZE := Vector2(52, 52)
const TRAVEL_BAR_ANIM_SEC := 0.24
const TRAVEL_HOURS_PER_TIER := 4
const TRAVEL_PREVIEW_ALPHA := 0.95

const MAP_NODES := {
	"base": {"kind": "Basis", "pos": Vector2(0.830, 0.885), "neighbors": ["ruined_town", "forest", "ash_market", "grave_crossroads", "black_forge"], "phase": 0.0},
	"harbor_pier": {"kind": "Event", "pos": Vector2(0.240, 0.850), "neighbors": ["drowned_quay", "ruined_town", "withered_gate"], "phase": 0.25},
	"drowned_quay": {"kind": "Zone", "pos": Vector2(0.180, 0.280), "neighbors": ["radio_tower", "factory", "harbor_pier"], "phase": 0.5},
	"radio_tower": {"kind": "Event", "pos": Vector2(0.060, 0.140), "neighbors": ["drowned_quay", "factory"], "phase": 0.85, "requires": {"flag": "discovered_radio", "text": "Hinweis aus der Altstadt"}},
	"ruined_town": {"kind": "Zone", "pos": Vector2(0.310, 0.350), "neighbors": ["base", "withered_gate", "harbor_pier", "ash_market", "grave_crossroads"], "phase": 1.15},
	"withered_gate": {"kind": "Taverne", "pos": Vector2(0.280, 0.670), "neighbors": ["ruined_town", "harbor_pier", "black_forge"], "phase": 1.45},
	"ash_market": {"kind": "Haendler", "pos": Vector2(0.330, 0.380), "neighbors": ["base", "ruined_town", "factory", "cinder_works"], "phase": 1.75},
	"factory": {"kind": "Zone", "pos": Vector2(0.390, 0.330), "neighbors": ["drowned_quay", "ash_market", "cinder_works", "forest"], "phase": 2.05, "repair": {"flag": "bridge_repaired", "cost": {"wood": 2, "nails": 2, "metal": 1}, "text": "Bruecke zum Werk reparieren"}},
	"cinder_works": {"kind": "Zone", "pos": Vector2(0.470, 0.320), "neighbors": ["ash_market", "factory", "forest", "chapel"], "phase": 2.35},
	"chapel": {"kind": "Dungeon", "pos": Vector2(0.520, 0.280), "neighbors": ["cinder_works", "silent_monastery", "hospital"], "phase": 2.7, "requires": {"flag": "discovered_chapel", "text": "Spur aus dem Wald"}},
	"silent_monastery": {"kind": "Event", "pos": Vector2(0.550, 0.240), "neighbors": ["chapel", "forest", "hospital", "military"], "phase": 3.05},
	"forest": {"kind": "Zone", "pos": Vector2(0.510, 0.400), "neighbors": ["base", "factory", "cinder_works", "silent_monastery", "military", "grave_crossroads"], "phase": 3.35},
	"grave_crossroads": {"kind": "Event", "pos": Vector2(0.610, 0.400), "neighbors": ["ruined_town", "base", "black_forge"], "phase": 3.65},
	"black_forge": {"kind": "Dungeon", "pos": Vector2(0.310, 0.840), "neighbors": ["base", "withered_gate", "collapsed_bridge", "signal_observatory"], "phase": 4.0, "requires": {"level": 2}, "repair": {"flag": "forge_gate_open", "cost": {"metal": 2, "fuel": 1, "nails": 2}, "text": "Schmiedetor oeffnen"}},
	"collapsed_bridge": {"kind": "Event", "pos": Vector2(0.400, 0.600), "neighbors": ["black_forge", "signal_observatory", "sealed_metro"], "phase": 4.35},
	"signal_observatory": {"kind": "Event", "pos": Vector2(0.470, 0.880), "neighbors": ["collapsed_bridge", "old_bunker"], "phase": 4.7, "requires": {"flag": "discovered_radio", "text": "Funkfrequenz"}},
	"hospital": {"kind": "Zone", "pos": Vector2(0.560, 0.350), "neighbors": ["chapel", "silent_monastery", "military", "cathedral_gate"], "phase": 5.05},
	"cathedral_gate": {"kind": "Dungeon", "pos": Vector2(0.750, 0.170), "neighbors": ["hospital", "eastern_pass"], "phase": 5.35, "requires": {"level": 3}},
	"military": {"kind": "Zone", "pos": Vector2(0.670, 0.560), "neighbors": ["forest", "silent_monastery", "hospital", "old_bunker", "watchtower"], "phase": 5.7, "requires": {"level": 2}},
	"old_bunker": {"kind": "Dungeon", "pos": Vector2(0.610, 0.640), "neighbors": ["military", "signal_observatory", "south_roadblock"], "phase": 6.05, "requires": {"flag": "bunker_code", "text": "Bunkercode aus dem Observatorium", "level": 4}},
	"eastern_pass": {"kind": "Event", "pos": Vector2(0.440, 0.220), "neighbors": ["cathedral_gate", "watchtower"], "phase": 6.4, "requires": {"level": 3}},
	"watchtower": {"kind": "Zone", "pos": Vector2(0.880, 0.550), "neighbors": ["eastern_pass", "military", "south_roadblock"], "phase": 6.75, "requires": {"flag": "watchtower_key", "text": "Schluessel vom Kontrollpunkt"}},
	"south_roadblock": {"kind": "Event", "pos": Vector2(0.680, 0.740), "neighbors": ["watchtower", "old_bunker", "sealed_metro"], "phase": 7.1},
	"sealed_metro": {"kind": "Dungeon", "pos": Vector2(0.730, 0.870), "neighbors": ["collapsed_bridge", "south_roadblock"], "phase": 7.8, "requires": {"level": 5}, "repair": {"flag": "metro_power_restored", "cost": {"electronics": 2, "fuel": 2, "metal": 2}, "text": "Metro-Tor mit Strom versorgen"}}
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
var map_viewport: Control
var map_camera_root: Control
var map_content: Control
var map_drag_layer: ColorRect
var map_popup_layer: CanvasLayer
var travel_overlay: ColorRect
var travel_close_catcher: Control
var current_badge: Label
var node_buttons: Dictionary = {}
var node_labels: Dictionary = {}
var travel_bars: Dictionary = {}
var consumable_rows: VBoxContainer
var consumable_hint: Label
var consumable_pick_counts: Dictionary = {}
var _consumable_row_labels: Dictionary = {}
var selected_node_id := ""
var map_anim_time := 0.0
var map_texture_size := MAP_SIZE_FALLBACK
var map_zoom := 1.0
var map_offset := Vector2.ZERO
var _map_dragging := false
var _map_drag_active := false
var _map_drag_last := Vector2.ZERO
var event_choice_box: VBoxContainer
var pending_event_id := ""
var pending_travel_event := false
var travel_popup_open := false
var _travel_bar_state: Dictionary = {}
var _travel_bar_tweens: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	clear_dynamic_children()
	AudioManager.play_scene_music("world_map")
	set_process(true)
	if not MAP_NODES.has(GameState.current_location):
		GameState.current_location = "base"
	call_deferred("_finish_ready")


func _finish_ready() -> void:
	_build_map(self)
	_build_travel_overlay(self)
	_build_side(self)
	attach_hud()
	_restore_pending_map_event()
	_refresh_map()
	call_deferred("_initialize_map_camera")


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	var cover_zoom := _map_cover_zoom()
	if map_zoom < cover_zoom:
		map_zoom = cover_zoom
	_clamp_map_offset()
	_apply_map_camera()


func _ensure_map_popup_layer() -> CanvasLayer:
	if map_popup_layer == null:
		map_popup_layer = CanvasLayer.new()
		map_popup_layer.layer = 10
		map_popup_layer.name = "MapPopupLayer"
		add_child(map_popup_layer)
	return map_popup_layer


func _build_travel_overlay(_parent: Control) -> void:
	var layer := _ensure_map_popup_layer()
	travel_overlay = ColorRect.new()
	travel_overlay.color = Color(0.02, 0.03, 0.04, 0.62)
	travel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_overlay.visible = false
	travel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_overlay.z_index = 0
	layer.add_child(travel_overlay)
	travel_close_catcher = Control.new()
	travel_close_catcher.name = "TravelCloseCatcher"
	travel_close_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_close_catcher.visible = false
	travel_close_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	travel_close_catcher.z_index = 1
	travel_close_catcher.gui_input.connect(_on_travel_close_catcher_input)
	layer.add_child(travel_close_catcher)


func _process(delta: float) -> void:
	map_anim_time += delta
	if not travel_popup_open:
		_handle_map_pan_keyboard(delta)
	_position_nodes()
	_animate_nodes()


func _draw() -> void:
	pass


func _build_map(parent: Control) -> void:
	map_viewport = Control.new()
	map_viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_viewport.clip_contents = true
	map_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	map_viewport.z_index = 0
	map_viewport.gui_input.connect(_on_map_viewport_input)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.045, 0.05, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_viewport.add_child(backdrop)
	parent.add_child(map_viewport)
	map_camera_root = Control.new()
	map_viewport.add_child(map_camera_root)
	map_content = Control.new()
	map_camera_root.add_child(map_content)
	var map_texture := _load_map_texture(MAP_TEXTURE)
	map_texture_size = _resolve_map_size(map_texture)
	map_content.custom_minimum_size = map_texture_size
	map_content.size = map_texture_size
	var art := TextureRect.new()
	art.texture = map_texture
	art.custom_minimum_size = map_texture_size
	art.size = map_texture_size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.03, 0.08)
	shade.custom_minimum_size = map_texture_size
	shade.size = map_texture_size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(shade)
	map_drag_layer = ColorRect.new()
	map_drag_layer.color = Color(0.0, 0.0, 0.0, 0.0)
	map_drag_layer.custom_minimum_size = map_texture_size
	map_drag_layer.size = map_texture_size
	map_drag_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	map_drag_layer.gui_input.connect(_on_map_drag_input)
	map_content.add_child(map_drag_layer)
	_build_nodes()
	current_badge = Label.new()
	current_badge.text = "DU BIST HIER"
	current_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_badge.add_theme_font_size_override("font_size", 14)
	current_badge.add_theme_color_override("font_color", Color("#ffe08a"))
	current_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	current_badge.add_theme_constant_override("shadow_offset_x", 2)
	current_badge.add_theme_constant_override("shadow_offset_y", 2)
	current_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_badge.visible = false
	map_content.add_child(current_badge)


func _build_nodes() -> void:
	for node_id in MAP_NODES:
		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.pivot_offset = NODE_SIZE * 0.5
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.z_index = 0
		button.mouse_entered.connect(func() -> void: _preview_node(str(node_id)))
		button.mouse_exited.connect(func() -> void: _clear_preview(str(node_id)))
		button.pressed.connect(func() -> void: _open_travel_popup(str(node_id)))
		UiFactory.wire_button_sound(button)
		map_content.add_child(button)
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
		name_label.z_index = 0
		map_content.add_child(name_label)
		node_labels[str(node_id)] = name_label


func _load_map_texture(path: String) -> Texture2D:
	var imported_texture := load(path) as Texture2D
	if imported_texture:
		return imported_texture
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null


func _resolve_map_size(texture: Texture2D) -> Vector2:
	if texture != null:
		var size := texture.get_size()
		if size.x > 0.0 and size.y > 0.0:
			return size
	return MAP_SIZE_FALLBACK


func _build_side(_parent: Control) -> void:
	var layer := _ensure_map_popup_layer()
	var compact := UiFactory.is_compact_screen(self)
	side_panel = PanelContainer.new()
	var panel_style := UiFactory._panel_style()
	panel_style.bg_color = Color(0.01, 0.012, 0.016, 0.91)
	panel_style.border_color = Color(0.55, 0.45, 0.26, 0.82)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	side_panel.z_index = 2
	side_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(side_panel)
	side_box = VBoxContainer.new()
	side_box.custom_minimum_size.x = 332 if compact else 360
	side_box.add_theme_constant_override("separation", 5)
	side_panel.add_child(side_box)

	var header_art := TextureRect.new()
	header_art.texture = _load_map_texture(DETAIL_PANEL_TEXTURE)
	header_art.custom_minimum_size = Vector2(0, 46 if compact else 54)
	header_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header_art.modulate = Color(1.0, 0.92, 0.78, 0.48)
	header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_box.add_child(header_art)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	side_box.add_child(title_row)
	var route_icon := TextureRect.new()
	route_icon.texture = load("res://assets/items/armor/work_boots.svg")
	route_icon.custom_minimum_size = Vector2(26, 26)
	route_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	route_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(route_icon)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 1)
	title_row.add_child(title_column)
	title_column.add_child(UiFactory.title_label("REISE", 20 if compact else 22))
	message_label = UiFactory.body_label("Klicke einen Ort auf der Karte.", 12, UiFactory.COLOR_MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_column.add_child(message_label)

	travel_label = UiFactory.body_label("", 14, UiFactory.COLOR_GOLD)
	side_box.add_child(travel_label)
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style := UiFactory._panel_style()
	preview_style.bg_color = Color(0.015, 0.017, 0.022, 0.90)
	preview_style.border_color = Color(0.40, 0.32, 0.19, 0.88)
	preview_style.content_margin_left = 10
	preview_style.content_margin_right = 10
	preview_style.content_margin_top = 8
	preview_style.content_margin_bottom = 8
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	side_box.add_child(preview_panel)
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 5)
	preview_panel.add_child(preview_box)
	preview_label = UiFactory.body_label("", 13, Color("#f0dca9"))
	preview_label.custom_minimum_size.y = 34
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(preview_label)
	_add_travel_bar(preview_box, "duration", "Zeit", Color("#d4b84a"), "res://assets/items/armor/work_boots.svg")
	_add_travel_bar(preview_box, "stamina", "Ausdauer", UiFactory.stat_bar_color("stamina"), UiFactory.stat_icon_path("stamina"))
	_add_travel_bar(preview_box, "energy", "Energie", UiFactory.stat_bar_color("energy"), UiFactory.stat_icon_path("energy"))
	_add_travel_bar(preview_box, "hunger", "Nahrung", UiFactory.stat_bar_color("hunger"), UiFactory.stat_icon_path("hunger"))
	_add_travel_bar(preview_box, "thirst", "Wasser", UiFactory.stat_bar_color("thirst"), UiFactory.stat_icon_path("thirst"))
	var consumable_panel := PanelContainer.new()
	consumable_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var consumable_style := UiFactory._panel_style()
	consumable_style.bg_color = Color(0.01, 0.012, 0.016, 0.86)
	consumable_style.content_margin_left = 8
	consumable_style.content_margin_right = 8
	consumable_style.content_margin_top = 6
	consumable_style.content_margin_bottom = 6
	consumable_panel.add_theme_stylebox_override("panel", consumable_style)
	preview_box.add_child(consumable_panel)
	var consumable_box := VBoxContainer.new()
	consumable_box.add_theme_constant_override("separation", 4)
	consumable_panel.add_child(consumable_box)
	consumable_box.add_child(UiFactory.body_label("Proviant", 11, UiFactory.COLOR_GOLD))
	consumable_hint = UiFactory.body_label("Nahrung und Getraenke waehlen.", 10, UiFactory.COLOR_MUTED)
	consumable_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	consumable_box.add_child(consumable_hint)
	consumable_rows = VBoxContainer.new()
	consumable_rows.add_theme_constant_override("separation", 4)
	consumable_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consumable_box.add_child(consumable_rows)
	detail_panel = PanelContainer.new()
	detail_panel.visible = false
	var detail_style := UiFactory._panel_style()
	detail_style.bg_color = Color(0.01, 0.012, 0.016, 0.86)
	detail_style.border_color = Color(0.33, 0.28, 0.18, 0.88)
	detail_style.content_margin_left = 10
	detail_style.content_margin_right = 10
	detail_style.content_margin_top = 8
	detail_style.content_margin_bottom = 8
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	side_box.add_child(detail_panel)
	detail_label = UiFactory.body_label("", 12, Color("#d8dde8"))
	detail_label.custom_minimum_size.y = 0
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(detail_label)

	event_choice_box = VBoxContainer.new()
	event_choice_box.visible = false
	event_choice_box.add_theme_constant_override("separation", 6)
	side_box.add_child(event_choice_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	side_box.add_child(actions)
	travel_button = _side_button("Reisen", _confirm_travel, "res://assets/items/misc/signal_flare.svg", "Reise starten und Verbrauch anwenden.")
	actions.add_child(travel_button)
	enter_button = _side_button("Betreten", _enter_current_location, _kind_icon("Basis"), "Aktuellen Ort betreten.")
	enter_button.visible = false
	actions.add_child(enter_button)
	side_panel.visible = false


func _refresh_map() -> void:
	_refresh_node_buttons()
	_refresh_side()


func _refresh_node_buttons() -> void:
	for node_id in node_buttons:
		var button := node_buttons[node_id] as Button
		var node: Dictionary = MAP_NODES[node_id]
		var location := DataCatalog.location(str(node_id))
		var kind := str(node.get("kind", "Ort"))
		var current := str(node_id) == GameState.current_location
		var neighbor := _is_neighbor(GameState.current_location, str(node_id)) or GameState.is_admin_godmode()
		var blocker := _effective_travel_blocker(str(node_id))
		var locked := not blocker.is_empty()
		var selected := travel_popup_open and str(node_id) == selected_node_id
		var location_name := str(location.get("name", node_id))
		var label := node_labels.get(str(node_id)) as Label
		if is_instance_valid(label):
			label.text = _map_label_text(location_name)
			label.tooltip_text = _node_tooltip(str(node_id), blocker)
			label.modulate = Color(1, 1, 1, 0.56 if locked else 0.92)
			label.add_theme_color_override("font_color", Color("#ffe08a") if current else (_kind_color(kind).lightened(0.22) if selected else Color("#f4e1b8")))
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
			style.bg_color = Color(0.12, 0.10, 0.05, 0.96)
			style.border_color = Color("#ffe08a")
			style.set_border_width_all(4)
			style.shadow_color = Color("#ffe08a")
			style.shadow_size = 18
		elif selected:
			style.bg_color = Color(0.06, 0.09, 0.12, 0.94)
			style.border_color = Color("#58a6ff")
			style.set_border_width_all(3)
			style.shadow_color = Color("#58a6ff")
			style.shadow_size = 10
		elif locked:
			style.bg_color = Color(0.035, 0.025, 0.025, 0.82)
			style.border_color = Color("#9b3c35")
			button.modulate = Color(0.72, 0.72, 0.72, 0.88)
		elif not neighbor and not current:
			button.modulate = Color(0.86, 0.86, 0.86, 0.82)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_color_override("font_color", Color("#ffe08a") if current else Color("#d8dde8"))
	_position_nodes()
	_update_current_badge()


func _side_button(text: String, callback: Callable, icon_path: String = "", tooltip: String = "") -> Button:
	var button := UiFactory.button(text, callback, 104)
	button.custom_minimum_size = Vector2(104, 40)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	if not icon_path.is_empty():
		button.icon = load(icon_path)
	if not tooltip.is_empty():
		button.tooltip_text = tooltip
	return button


func _position_nodes() -> void:
	if not is_instance_valid(map_content):
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
	return Rect2(Vector2.ZERO, map_texture_size)


func _map_point_to_canvas(pos: Vector2) -> Vector2:
	return Vector2(pos.x * map_texture_size.x, pos.y * map_texture_size.y)


func _initialize_map_camera() -> void:
	if not is_instance_valid(map_viewport):
		return
	_fit_map_initial()
	_center_on_location(GameState.current_location)
	_apply_map_camera()


func _fit_map_initial() -> void:
	if not is_instance_valid(map_viewport) or map_viewport.size.x <= 0.0:
		return
	map_zoom = _map_cover_zoom()


func _map_cover_zoom() -> float:
	if not is_instance_valid(map_viewport) or map_viewport.size.x <= 0.0:
		return 0.2
	var view := map_viewport.size
	return maxf(view.x / map_texture_size.x, view.y / map_texture_size.y)


func _map_min_zoom() -> float:
	return _map_cover_zoom()


func _center_on_location(location_id: String) -> void:
	if not MAP_NODES.has(location_id):
		location_id = "base"
	var point := _map_point_to_canvas(MAP_NODES[location_id].get("pos", Vector2(0.5, 0.5)))
	_center_on_map_point(point)


func _center_on_map_point(map_point: Vector2) -> void:
	if not is_instance_valid(map_viewport):
		return
	var view := map_viewport.size
	map_offset = view * 0.5 - map_point * map_zoom
	_clamp_map_offset()


func _apply_map_camera() -> void:
	if not is_instance_valid(map_camera_root):
		return
	map_camera_root.position = map_offset
	map_camera_root.scale = Vector2(map_zoom, map_zoom)


func _clamp_map_offset() -> void:
	if not is_instance_valid(map_viewport):
		return
	var view := map_viewport.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var scaled := map_texture_size * map_zoom
	map_offset.x = clampf(map_offset.x, view.x - scaled.x, 0.0)
	map_offset.y = clampf(map_offset.y, view.y - scaled.y, 0.0)


func _zoom_map(factor: float, focus_screen: Vector2) -> void:
	var old_zoom := map_zoom
	map_zoom = clampf(map_zoom * factor, _map_min_zoom(), MAP_ZOOM_MAX)
	if is_equal_approx(old_zoom, map_zoom):
		return
	var map_focus := (focus_screen - map_offset) / old_zoom
	map_offset = focus_screen - map_focus * map_zoom
	_clamp_map_offset()
	_apply_map_camera()


func _pan_map(delta: Vector2) -> void:
	map_offset += delta
	_clamp_map_offset()
	_apply_map_camera()


func _handle_map_pan_keyboard(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move.y += 1.0
	if Input.is_key_pressed(KEY_S):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_A):
		move.x += 1.0
	if Input.is_key_pressed(KEY_D):
		move.x -= 1.0
	if move == Vector2.ZERO:
		return
	_pan_map(move.normalized() * MAP_PAN_SPEED * delta)


func _on_map_viewport_input(event: InputEvent) -> void:
	if travel_popup_open:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_map(1.12, mouse.position)
				get_viewport().set_input_as_handled()
			elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_map(0.89, mouse.position)
				get_viewport().set_input_as_handled()


func _on_map_drag_input(event: InputEvent) -> void:
	if travel_popup_open:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_map_dragging = true
			_map_drag_active = false
			_map_drag_last = mouse.position
		else:
			_map_dragging = false
			_map_drag_active = false
	elif event is InputEventMouseMotion and _map_dragging:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _map_drag_last
		if not _map_drag_active and delta.length() > MAP_DRAG_THRESHOLD:
			_map_drag_active = true
		if _map_drag_active:
			_pan_map(delta)
			_map_drag_last = motion.position
			get_viewport().set_input_as_handled()


func _animate_nodes() -> void:
	for node_id in node_buttons:
		var button := node_buttons[node_id] as Button
		var node: Dictionary = MAP_NODES[node_id]
		var phase := float(node.get("phase", 0.0))
		var pulse := (sin(map_anim_time * 2.1 + phase) + 1.0) * 0.5
		var current := str(node_id) == GameState.current_location
		var locked := not _requirement_blocker(str(node_id)).is_empty()
		var scale_to := 1.0 + pulse * (0.08 if current else 0.025)
		button.scale = Vector2(scale_to, scale_to)
		if locked:
			button.self_modulate.a = lerpf(0.70, 0.92, pulse)
		else:
			button.self_modulate.a = 1.0


func _refresh_side() -> void:
	_position_travel_popup()
	if is_instance_valid(travel_overlay):
		travel_overlay.visible = travel_popup_open
	if is_instance_valid(travel_close_catcher):
		travel_close_catcher.visible = travel_popup_open
	if is_instance_valid(side_panel):
		side_panel.visible = travel_popup_open
	travel_label.text = "Zeit: Tag %d, %s" % [TimeSystem.current_day, TimeSystem.current_phase()]
	if GameState.is_admin_godmode():
		travel_label.text += "   |   GODMODE"
	if is_instance_valid(detail_panel):
		detail_panel.visible = travel_popup_open and not pending_event_id.is_empty()
	detail_label.visible = is_instance_valid(detail_panel) and detail_panel.visible
	detail_label.text = _selected_location_text()
	_refresh_consumable_rows()
	_refresh_travel_preview()
	_refresh_map_marker_visibility()


func _close_scene_popup() -> bool:
	if travel_popup_open:
		_close_travel_popup()
		return true
	return false


func _on_pause_menu_opened() -> void:
	_refresh_map_marker_visibility()


func _on_pause_menu_closed() -> void:
	_refresh_map_marker_visibility()


func _refresh_map_marker_visibility() -> void:
	var hide_markers := travel_popup_open or _is_pause_menu_open()
	for node_id in node_buttons:
		var button := node_buttons[node_id] as Button
		if is_instance_valid(button):
			button.visible = not hide_markers
		var label := node_labels.get(str(node_id)) as Label
		if is_instance_valid(label):
			label.visible = not hide_markers
	if is_instance_valid(current_badge):
		current_badge.visible = not hide_markers and MAP_NODES.has(GameState.current_location)


func _position_travel_popup() -> void:
	if not is_instance_valid(side_panel):
		return
	var compact := UiFactory.is_compact_screen(self)
	var panel_width := 348.0 if compact else 378.0
	var panel_height := 430.0 if compact else 462.0
	side_panel.set_anchors_preset(Control.PRESET_CENTER)
	side_panel.offset_left = -panel_width * 0.5
	side_panel.offset_right = panel_width * 0.5
	side_panel.offset_top = -panel_height * 0.5
	side_panel.offset_bottom = panel_height * 0.5


func _add_travel_bar(parent: VBoxContainer, key: String, label_text: String, color: Color, icon_path: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(26, 26)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.04, 0.04, 0.045, 0.88)
	icon_style.border_color = color.darkened(0.25)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(2)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = load(icon_path) if not icon_path.is_empty() else null
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1.0, 0.93, 0.75, 0.92)
	icon_frame.add_child(icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	var top_row := HBoxContainer.new()
	column.add_child(top_row)
	var label := UiFactory.body_label(label_text, 10, UiFactory.COLOR_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(label)
	var value := UiFactory.body_label("", 10, Color("#d8dde8"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 88
	top_row.add_child(value)
	var layer := Control.new()
	layer.custom_minimum_size = Vector2(0, 11)
	layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(layer)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.01, 0.012, 0.015, 0.98)
	background.border_color = Color(0.22, 0.20, 0.16, 0.88)
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	var preview_bar := ProgressBar.new()
	preview_bar.show_percentage = false
	preview_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_bar.add_theme_stylebox_override("background", background)
	preview_bar.visible = false
	layer.add_child(preview_bar)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	layer.add_child(bar)
	travel_bars[key] = {"bar": bar, "preview": preview_bar, "value": value, "color": color}


func _refresh_travel_preview() -> void:
	if not is_instance_valid(preview_label):
		return
	var stamina := float(GameState.player_stats.get("stamina", 0.0))
	var energy := float(GameState.player_stats.get("energy", 0.0))
	var hunger := float(GameState.player_stats.get("hunger", 0.0))
	var thirst := float(GameState.player_stats.get("thirst", 0.0))
	var target_id := selected_node_id
	var cost := 0
	var stamina_after := stamina
	var energy_after := energy
	var hunger_after := hunger
	var thirst_after := thirst
	var preview_text := "Klicke einen Ort auf der Karte."
	var button_text := "Reisen"
	var button_disabled := true
	var consumable_bonus := _selected_consumable_effects()
	if travel_popup_open and not target_id.is_empty() and MAP_NODES.has(target_id):
		var location := DataCatalog.location(target_id)
		var at_destination := target_id == GameState.current_location
		if GameState.is_admin_godmode():
			if at_destination:
				preview_text = "%s\nDu bist hier. Du kannst den Ort betreten." % location.get("name", target_id)
			else:
				preview_text = "%s\nGodmode: Teleport ohne Kosten." % location.get("name", target_id)
				button_text = "Teleport"
				button_disabled = false
				hunger_after = _project_stat_after(hunger, 0.0, consumable_bonus, "hunger")
				thirst_after = _project_stat_after(thirst, 0.0, consumable_bonus, "thirst")
		elif at_destination:
			preview_text = "%s\nDu befindest dich hier. Betreten ist moeglich." % location.get("name", target_id)
			hunger_after = _project_stat_after(hunger, 0.0, consumable_bonus, "hunger")
			thirst_after = _project_stat_after(thirst, 0.0, consumable_bonus, "thirst")
		elif not _is_neighbor(GameState.current_location, target_id):
			preview_text = "%s\nKein direkter Weg. Reise ueber einen Nachbarort." % location.get("name", target_id)
			hunger_after = _project_stat_after(hunger, 0.0, consumable_bonus, "hunger")
			thirst_after = _project_stat_after(thirst, 0.0, consumable_bonus, "thirst")
		else:
			cost = _route_cost(target_id)
			stamina_after = _project_stat_after(stamina, _travel_stamina_cost(cost), consumable_bonus, "stamina")
			energy_after = _project_stat_after(energy, _travel_energy_cost(cost), consumable_bonus, "energy")
			hunger_after = _project_stat_after(hunger, _travel_hunger_cost(cost), consumable_bonus, "hunger")
			thirst_after = _project_stat_after(thirst, _travel_thirst_cost(cost), consumable_bonus, "thirst")
			var blocker := _requirement_blocker(target_id)
			if not blocker.is_empty():
				preview_text = "%s\n%s" % [location.get("name", target_id), blocker]
				if _can_repair_requirement(target_id):
					button_text = "Reparieren"
					button_disabled = false
			else:
				preview_text = "%s\nAnkunft: %s" % [
					location.get("name", target_id),
					_arrival_text(cost)
				]
				button_disabled = false
	preview_label.text = preview_text
	var at_destination := travel_popup_open and not target_id.is_empty() and target_id == GameState.current_location
	if is_instance_valid(travel_button):
		travel_button.visible = travel_popup_open and not at_destination
		travel_button.text = button_text
		travel_button.disabled = button_disabled or not travel_popup_open
	if is_instance_valid(enter_button):
		enter_button.visible = at_destination
		enter_button.disabled = not travel_popup_open
	_set_travel_bar(
		"duration",
		0.0,
		float(cost),
		float(TimeSystem.HOURS_PER_DAY),
		_format_travel_hours(cost),
		"Reisezeit in Stunden (24h-Massstab).",
		true
	)
	_set_travel_bar("stamina", stamina, stamina_after, _resource_max_for_bar("stamina", stamina), "%.0f -> %.0f" % [stamina, stamina_after], "Ausdauer nach Reise und Proviant.")
	_set_travel_bar("energy", energy, energy_after, _resource_max_for_bar("energy", energy), "%.0f -> %.0f" % [energy, energy_after], "Energie nach Reise und Proviant.")
	_set_travel_bar("hunger", hunger, hunger_after, 100.0, "%.0f -> %.0f" % [hunger, hunger_after], "Nahrung nach Reise und Proviant.")
	_set_travel_bar("thirst", thirst, thirst_after, 100.0, "%.0f -> %.0f" % [thirst, thirst_after], "Wasser nach Reise und Proviant.")
	_sync_hud_travel_preview(target_id, stamina_after, energy_after, hunger_after, thirst_after)


func _sync_hud_travel_preview(target_id: String, stamina_after: float, energy_after: float, hunger_after: float, thirst_after: float) -> void:
	if GameState.is_admin_godmode():
		HudStatPreview.clear()
		return
	if target_id.is_empty():
		HudStatPreview.clear()
		return
	if target_id == GameState.current_location:
		HudStatPreview.clear()
		return
	if not _is_neighbor(GameState.current_location, target_id):
		HudStatPreview.clear()
		return
	if not _requirement_blocker(target_id).is_empty() and not _can_repair_requirement(target_id):
		HudStatPreview.clear()
		return
	HudStatPreview.set_projected({
		"stamina": stamina_after,
		"energy": energy_after,
		"hunger": hunger_after,
		"thirst": thirst_after,
	})


func _set_travel_bar(
	key: String,
	current: float,
	after: float,
	maximum: float,
	text: String,
	tooltip: String = "",
	duration_mode: bool = false
) -> void:
	var entry: Dictionary = travel_bars.get(key, {})
	if entry.is_empty():
		return
	var label := entry.get("value") as Label
	if is_instance_valid(label):
		label.text = text
		label.tooltip_text = tooltip
	var prev_state: Dictionary = _travel_bar_state.get(key, {"current": current, "after": after})
	var from_current := float(prev_state.get("current", current))
	var from_after := float(prev_state.get("after", after))
	var should_animate := travel_popup_open and (
		absf(from_current - current) > 0.01 or absf(from_after - after) > 0.01
	)
	if not should_animate:
		_apply_travel_bar_visual(key, current, after, maximum, tooltip, duration_mode)
		_travel_bar_state[key] = {"current": current, "after": after}
		return
	if _travel_bar_tweens.has(key):
		var old_tween: Tween = _travel_bar_tweens[key]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	_travel_bar_tweens[key] = tween
	tween.tween_method(
		func(t: float) -> void:
			var c_current := lerpf(from_current, current, t)
			var c_after := lerpf(from_after, after, t)
			_apply_travel_bar_visual(key, c_current, c_after, maximum, tooltip, duration_mode),
		0.0, 1.0, TRAVEL_BAR_ANIM_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_travel_bar_state[key] = {"current": current, "after": after}
		_apply_travel_bar_visual(key, current, after, maximum, tooltip, duration_mode)
	)


func _apply_travel_bar_visual(
	key: String,
	current: float,
	after: float,
	maximum: float,
	tooltip: String,
	duration_mode: bool
) -> void:
	var entry: Dictionary = travel_bars.get(key, {})
	if entry.is_empty():
		return
	var bar := entry.get("bar") as ProgressBar
	var preview_bar := entry.get("preview") as ProgressBar
	var fill_color: Color = entry.get("color", UiFactory.COLOR_MUTED)
	if not is_instance_valid(bar):
		return
	var max_val := maxf(maximum, 1.0)
	var clamped_current := clampf(current, 0.0, max_val)
	var clamped_after := clampf(after, 0.0, max_val)
	if duration_mode:
		if is_instance_valid(preview_bar):
			preview_bar.visible = false
		bar.modulate = Color.WHITE
		bar.max_value = max_val
		bar.value = clamped_after
		UiFactory.apply_stat_bar(bar, fill_color if clamped_after > 0.01 else fill_color.darkened(0.35))
	else:
		_apply_travel_stat_preview(entry, clamped_current, max_val, clamped_after)
	bar.tooltip_text = tooltip


func _apply_travel_stat_preview(entry: Dictionary, current: float, maximum: float, projected: float) -> void:
	var preview_bar: ProgressBar = entry.get("preview")
	var bar: ProgressBar = entry.get("bar")
	var fill_color: Color = entry.get("color", UiFactory.COLOR_MUTED)
	if not is_instance_valid(preview_bar) or not is_instance_valid(bar):
		return
	if is_equal_approx(current, projected):
		preview_bar.visible = false
		bar.modulate = Color.WHITE
		bar.max_value = maximum
		bar.value = current
		UiFactory.apply_stat_bar(bar, fill_color)
		return
	var is_gain := projected > current
	var preview_color := fill_color.lightened(0.18)
	UiFactory.apply_stat_bar(preview_bar, preview_color)
	preview_bar.modulate = Color(1.0, 1.0, 1.0, TRAVEL_PREVIEW_ALPHA if not is_gain else 0.78)
	preview_bar.max_value = maximum
	preview_bar.value = current if not is_gain else projected
	preview_bar.visible = true
	_travel_bar_transparent_background(bar)
	UiFactory.apply_stat_bar(bar, fill_color)
	bar.modulate = Color.WHITE
	bar.max_value = maximum
	bar.value = projected if not is_gain else current


func _travel_bar_transparent_background(bar: ProgressBar) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	background.draw_center = false
	background.set_border_width_all(0)
	bar.add_theme_stylebox_override("background", background)


func _resource_max_for_bar(resource_id: String, current_value: float) -> float:
	return maxf(maxf(GameState.max_resource(resource_id), current_value), 1.0)


func _format_travel_hours(hours: int) -> String:
	if hours <= 0:
		return "—"
	return "%d Std." % hours


func _arrival_text(hours: int) -> String:
	var total_hours := ((TimeSystem.current_day - 1) * TimeSystem.HOURS_PER_DAY) + TimeSystem.current_hour() + hours
	var arrival_day := floori(float(total_hours) / float(TimeSystem.HOURS_PER_DAY)) + 1
	var arrival_hour := total_hours % TimeSystem.HOURS_PER_DAY
	return "Tag %d, %02d:00" % [arrival_day, arrival_hour]


func _reset_travel_bar_animation() -> void:
	for key in _travel_bar_tweens.keys():
		var tween: Tween = _travel_bar_tweens[key]
		if tween != null and tween.is_valid():
			tween.kill()
	_travel_bar_tweens.clear()
	_travel_bar_state.clear()


func _open_travel_popup(node_id: String) -> void:
	if _map_drag_active:
		return
	if not MAP_NODES.has(node_id):
		return
	selected_node_id = node_id
	travel_popup_open = true
	_reset_travel_bar_animation()
	var location := DataCatalog.location(node_id)
	if node_id == GameState.current_location:
		message_label.text = "%s — dein aktueller Standort." % location.get("name", node_id)
	elif GameState.is_admin_godmode():
		message_label.text = "%s — Godmode-Reiseziel." % location.get("name", node_id)
	else:
		message_label.text = str(location.get("name", node_id))
	_refresh_map()


func _close_travel_popup() -> void:
	if not travel_popup_open:
		return
	travel_popup_open = false
	selected_node_id = ""
	consumable_pick_counts.clear()
	_consumable_row_labels.clear()
	message_label.text = "Klicke einen Ort auf der Karte."
	HudStatPreview.clear()
	_reset_travel_bar_animation()
	_refresh_map()


func _on_travel_close_catcher_input(event: InputEvent) -> void:
	if not travel_popup_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_travel_popup()


func _preview_node(node_id: String) -> void:
	if travel_popup_open:
		return
	if not MAP_NODES.has(node_id):
		return
	var location := DataCatalog.location(node_id)
	if node_id == GameState.current_location:
		message_label.text = "%s — du bist hier." % location.get("name", node_id)
	else:
		message_label.text = "%s — Linksklick oeffnet Reise." % location.get("name", node_id)


func _clear_preview(node_id: String) -> void:
	if travel_popup_open or not is_instance_valid(message_label):
		return
	var location_name := str(DataCatalog.location(node_id).get("name", node_id))
	if location_name.is_empty():
		return
	if message_label.text.contains(location_name):
		message_label.text = "Klicke einen Ort auf der Karte."


func _confirm_travel() -> void:
	if not pending_event_id.is_empty():
		message_label.text = "Loese zuerst das aktuelle Ereignis."
		_refresh_map()
		return
	var node_id := selected_node_id
	if node_id.is_empty() or not MAP_NODES.has(node_id):
		message_label.text = "Waehle zuerst ein Ziel auf der Karte."
		_refresh_map()
		return
	if node_id == GameState.current_location:
		message_label.text = "Du bist bereits hier. Nutze Ort betreten."
		_refresh_map()
		return
	if GameState.is_admin_godmode():
		_teleport_to_node(node_id, true)
		return
	if not _is_neighbor(GameState.current_location, node_id):
		message_label.text = "Kein direkter Pfad. Du musst ueber verbundene Orte reisen."
		_refresh_map()
		return
	var blocker := _effective_travel_blocker(node_id)
	if not blocker.is_empty():
		if _try_unlock_requirement(node_id):
			_refresh_map()
			return
		message_label.text = blocker
		_refresh_map()
		return
	var cost := _route_cost(node_id)
	_apply_selected_consumables()
	_teleport_to_node(node_id, false, cost)


func _teleport_to_node(node_id: String, godmode: bool, cost: int = 0) -> void:
	if not godmode:
		GameState.spend_for_action(
			_travel_stamina_cost(cost),
			_travel_energy_cost(cost),
			_travel_hunger_cost(cost),
			_travel_thirst_cost(cost)
		)
		TimeSystem.advance(cost, "Du erreichst %s." % DataCatalog.location(node_id).get("name", node_id))
		message_label.text = "Angekommen: %s. Du kannst den Ort jetzt betreten." % DataCatalog.location(node_id).get("name", node_id)
	else:
		message_label.text = "Godmode: %s erreicht." % DataCatalog.location(node_id).get("name", node_id)
	GameState.current_location = node_id
	GameState.run_statistics.locations_visited = int(GameState.run_statistics.locations_visited) + 1
	_handle_arrival_flags(node_id)
	if not godmode:
		_try_random_travel_event()
	selected_node_id = node_id
	travel_popup_open = true
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		_refresh_map()


func _enter_current_location() -> void:
	if selected_node_id != GameState.current_location:
		message_label.text = "Du musst zuerst am Ziel ankommen."
		_refresh_map()
		return
	var node_id := GameState.current_location
	var node: Dictionary = MAP_NODES.get(node_id, {})
	var kind := str(node.get("kind", "Zone"))
	if node_id == "base":
		go_to("res://scenes/base/base_scene.tscn")
		return
	if kind == "Haendler":
		_visit_trader()
		return
	if kind == "Taverne":
		_visit_tavern()
		return
	if kind == "Event":
		_start_map_event(node_id)
		return
	GameState.return_scene = scene_file_path
	go_to("res://scenes/exploration/exploration_scene.tscn")


func _visit_trader() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/trader_screen.tscn")


func _visit_tavern() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/tavern_screen.tscn")


func _start_map_event(node_id: String) -> void:
	var data := DataCatalog.map_event(node_id)
	if data.is_empty():
		_resolve_legacy_event(node_id)
		return
	_set_pending_event(node_id, false, data)
	message_label.text = str(data.get("title", "Ereignis"))
	detail_label.text = str(data.get("intro", ""))
	_show_event_choices(data.get("choices", []))


func _try_random_travel_event() -> void:
	if not pending_event_id.is_empty():
		return
	if randf() > 0.16:
		return
	var data := DataCatalog.random_travel_event()
	if data.is_empty():
		return
	_set_pending_event("travel", true, data)
	message_label.text = "Unterwegs: %s" % data.get("title", "Ereignis")
	detail_label.text = str(data.get("intro", ""))
	_show_event_choices(data.get("choices", []))
	AudioManager.play_sfx("res://assets/audio/sfx/environment/wave_warning.wav", -10.0, 0.9)


func _set_pending_event(event_id: String, travel: bool, data: Dictionary) -> void:
	pending_event_id = event_id
	pending_travel_event = travel
	GameState.pending_map_event_id = event_id
	GameState.pending_map_travel_event = travel
	GameState.pending_map_event_data = data.duplicate(true)


func _restore_pending_map_event() -> void:
	if GameState.pending_map_event_id.is_empty():
		return
	var data: Dictionary = GameState.pending_map_event_data
	if data.is_empty():
		_clear_event_choices()
		return
	pending_event_id = GameState.pending_map_event_id
	pending_travel_event = GameState.pending_map_travel_event
	if pending_travel_event:
		message_label.text = "Unterwegs: %s" % data.get("title", "Ereignis")
	else:
		message_label.text = str(data.get("title", "Ereignis"))
	detail_label.text = str(data.get("intro", ""))
	_show_event_choices(data.get("choices", []))


func _show_event_choices(choices: Array) -> void:
	UiFactory.clear_container(event_choice_box)
	event_choice_box.visible = not choices.is_empty()
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = choice
		var button := UiFactory.button(str(data.get("label", "Option")), Callable(self, "_pick_event_choice").bind(data.duplicate(true)), 420)
		button.custom_minimum_size.y = 36
		event_choice_box.add_child(button)


func _clear_event_choices() -> void:
	UiFactory.clear_container(event_choice_box)
	event_choice_box.visible = false
	pending_event_id = ""
	pending_travel_event = false
	GameState.pending_map_event_id = ""
	GameState.pending_map_travel_event = false
	GameState.pending_map_event_data = {}


func _pick_event_choice(choice: Dictionary) -> void:
	if not _can_take_event_choice(choice):
		message_label.text = "Dafuer fehlen Materialien oder Kraft."
		_refresh_map()
		return
	if float(choice.get("danger_roll", 0.0)) > 0.0 and randf() < float(choice.get("danger_roll", 0.0)):
		_apply_event_damage(float(choice.get("damage", 10.0)))
		message_label.text = str(choice.get("fail_message", "Es geht schief."))
	else:
		_apply_event_choice(choice)
		message_label.text = str(choice.get("message", "Ereignis abgeschlossen."))
	_clear_event_choices()
	TimeSystem.advance(1, "Ereignis auf der Route.")
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		_refresh_map()


func _can_take_event_choice(choice: Dictionary) -> bool:
	var cost: Dictionary = choice.get("cost", {})
	var item_cost := {}
	for key in cost:
		if str(key) in ["stamina", "energy", "health", "hunger", "thirst", "shield"]:
			if float(GameState.player_stats.get(str(key), 0.0)) < float(cost[key]):
				return false
		else:
			item_cost[str(key)] = int(cost[key])
	if not item_cost.is_empty() and not InventorySystem.has_items(item_cost):
		return false
	return true


func _apply_event_choice(choice: Dictionary) -> void:
	var cost: Dictionary = choice.get("cost", {})
	var item_cost := {}
	for key in cost:
		if str(key) in ["stamina", "energy", "health", "hunger", "thirst", "shield"]:
			GameState.change_stat(str(key), -float(cost[key]))
		else:
			item_cost[str(key)] = int(cost[key])
	if not item_cost.is_empty():
		InventorySystem.consume_cost(item_cost)
	var reward: Dictionary = choice.get("reward", {})
	var reward_items: Dictionary = reward.get("items", {})
	for item_id in reward_items:
		InventorySystem.add_item(str(item_id), int(reward_items[item_id]))
	if reward.has("money"):
		InventorySystem.add_money(int(reward.money))
		AudioManager.play_coin_sfx(2)
	for stat_name in reward.get("stats", {}):
		GameState.change_stat(str(stat_name), float(reward.stats[stat_name]))
	var flags: Dictionary = choice.get("flags", {})
	for flag_name in flags:
		GameState.quest_flags[str(flag_name)] = bool(flags[flag_name])
	if float(choice.get("damage", 0.0)) > 0.0:
		_apply_event_damage(float(choice.damage))
	if float(choice.get("stress", 0.0)) > 0.0:
		GameState.elena.stress = minf(100.0, float(GameState.elena.stress) + float(choice.stress))
	EventBus.stats_changed.emit()
	EventBus.inventory_changed.emit()


func _apply_event_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	GameState.change_stat("health", -amount)
	if amount >= 6.0:
		AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -8.0, 0.85)


func _resolve_legacy_event(node_id: String) -> void:
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


func _open_rest_camp() -> void:
	GameState.return_scene = scene_file_path
	go_to(REST_CAMP_SCENE)


func _rest_on_map() -> void:
	_open_rest_camp()


func rest_action() -> void:
	_open_rest_camp()


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
		"%s - Gefahr %d - %d Std. Reise" % [
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
		"%s | %s | Gefahr %d | %d Std." % [location.get("name", node_id), kind, int(location.get("danger", 0)), _route_cost(node_id)],
		_short_text(str(location.get("description", "")), 106),
		"Nachbarn: %s" % _short_text(_neighbor_names(node_id), 110)
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


func _effective_travel_blocker(node_id: String) -> String:
	if GameState.is_admin_godmode():
		return ""
	return _requirement_blocker(node_id)


func _is_neighbor(from_id: String, to_id: String) -> bool:
	if from_id == to_id:
		return true
	if not MAP_NODES.has(from_id) or not MAP_NODES.has(to_id):
		return false
	return MAP_NODES[from_id].get("neighbors", []).has(to_id) or MAP_NODES[to_id].get("neighbors", []).has(from_id)


func _route_cost(node_id: String) -> int:
	if node_id == "base":
		return 0
	var tier := clampi(int(DataCatalog.location(node_id).get("travel", 1)), 1, 3)
	return tier * TRAVEL_HOURS_PER_TIER


func _travel_stamina_cost(hours: int) -> float:
	return float(hours) * 2.5


func _travel_energy_cost(hours: int) -> float:
	return float(hours) * 1.75


func _travel_hunger_cost(hours: int) -> float:
	return float(hours) * 1.0


func _travel_thirst_cost(hours: int) -> float:
	return float(hours) * 1.5


func _consumable_qty_button(symbol: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = symbol
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(7, 7)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 7)
	button.add_theme_color_override("font_color", Color("#e8dcc0"))
	button.add_theme_color_override("font_hover_color", Color("#ffe08a"))
	button.add_theme_color_override("font_pressed_color", Color("#f0c878"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.06, 0.07, 0.96)
	normal.border_color = Color(0.42, 0.36, 0.24, 0.95)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(1)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	var hover := normal.duplicate()
	hover.bg_color = Color(0.10, 0.09, 0.08, 0.98)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.14, 0.11, 0.08, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", normal)
	UiFactory.wire_button_sound(button)
	button.pressed.connect(callback)
	return button


func _consumable_qty_frame(button: Button) -> CenterContainer:
	var frame := CenterContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(8, 8)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_END
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(button)
	return frame


func _refresh_consumable_rows() -> void:
	if not is_instance_valid(consumable_rows):
		return
	for child in consumable_rows.get_children():
		child.queue_free()
	_consumable_row_labels.clear()
	var items := InventorySystem.travel_food_drink_items()
	_prune_consumable_picks(items)
	if items.is_empty():
		if is_instance_valid(consumable_hint):
			consumable_hint.text = "Kein Proviant im Inventar."
		return
	if is_instance_valid(consumable_hint):
		consumable_hint.text = "Nahrung und Getraenke waehlen."
	for item_id in items:
		_build_consumable_row(item_id)


func _prune_consumable_picks(valid_items: Array[String]) -> void:
	for item_id in consumable_pick_counts.keys():
		var owned := int(InventorySystem.items.get(item_id, 0))
		var picked := int(consumable_pick_counts.get(item_id, 0))
		if not valid_items.has(item_id) or owned <= 0:
			consumable_pick_counts.erase(item_id)
		elif picked > owned:
			consumable_pick_counts[item_id] = owned


func _build_consumable_row(item_id: String) -> void:
	var data := DataCatalog.item(item_id)
	var owned := int(InventorySystem.items.get(item_id, 0))
	if owned <= 0:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.custom_minimum_size.y = 24
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	consumable_rows.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(22, 22)
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.04, 0.04, 0.045, 0.88)
	icon_style.border_color = Color(0.30, 0.27, 0.20, 0.88)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(2)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)
	var icon := TextureRect.new()
	if data.has("icon"):
		var icon_path := str(data.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(icon)
	var name_label := UiFactory.body_label(str(data.get("name", item_id)), 10, Color("#d8dde8"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_stretch_ratio = 1.0
	row.add_child(name_label)
	var picked := int(consumable_pick_counts.get(item_id, 0))
	var count_label := UiFactory.body_label("%d/%d" % [picked, owned], 10, UiFactory.COLOR_MUTED)
	count_label.custom_minimum_size.x = 34
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(count_label)
	var qty_box := HBoxContainer.new()
	qty_box.add_theme_constant_override("separation", 1)
	qty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	qty_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(qty_box)
	var plus_button := _consumable_qty_button("+", _adjust_consumable_pick.bind(item_id, 1))
	qty_box.add_child(_consumable_qty_frame(plus_button))
	var minus_button := _consumable_qty_button("-", _adjust_consumable_pick.bind(item_id, -1))
	qty_box.add_child(_consumable_qty_frame(minus_button))
	_consumable_row_labels[item_id] = count_label


func _adjust_consumable_pick(item_id: String, delta: int) -> void:
	var owned := int(InventorySystem.items.get(item_id, 0))
	if owned <= 0:
		consumable_pick_counts.erase(item_id)
		_refresh_consumable_rows()
		_refresh_travel_preview()
		return
	var picked := int(consumable_pick_counts.get(item_id, 0)) + delta
	picked = clampi(picked, 0, owned)
	if picked <= 0:
		consumable_pick_counts.erase(item_id)
	else:
		consumable_pick_counts[item_id] = picked
	var count_label: Label = _consumable_row_labels.get(item_id)
	if is_instance_valid(count_label):
		count_label.text = "%d/%d" % [picked, owned]
	_refresh_travel_preview()


func _selected_consumable_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in consumable_pick_counts.keys():
		if int(consumable_pick_counts.get(item_id, 0)) > 0:
			result.append(str(item_id))
	return result


func _selected_consumable_effects() -> Dictionary:
	var totals := {}
	for item_id in consumable_pick_counts.keys():
		var count := int(consumable_pick_counts.get(item_id, 0))
		if count <= 0:
			continue
		var effects := InventorySystem.item_effect_preview(item_id)
		for stat_name in effects:
			totals[stat_name] = float(totals.get(stat_name, 0.0)) + float(effects[stat_name]) * float(count)
	return totals


func _project_stat_after(current: float, travel_cost: float, bonuses: Dictionary, stat_name: String) -> float:
	var maximum := 100.0
	if stat_name in ["stamina", "energy", "health"]:
		maximum = maxf(GameState.max_resource(stat_name), current)
	var bonus := float(bonuses.get(stat_name, 0.0))
	return clampf(current - travel_cost + bonus, 0.0, maximum)


func _apply_selected_consumables() -> void:
	for item_id in consumable_pick_counts.keys():
		var count := int(consumable_pick_counts.get(item_id, 0))
		for _i in range(count):
			InventorySystem.use_item(item_id)
	consumable_pick_counts.clear()


func _update_current_badge() -> void:
	if not is_instance_valid(current_badge):
		return
	var current_id := GameState.current_location
	if not MAP_NODES.has(current_id):
		current_badge.visible = false
		return
	current_badge.visible = true
	var point := _map_point_to_canvas(MAP_NODES[current_id].get("pos", Vector2(0.5, 0.5)))
	current_badge.position = point + Vector2(-72, -62)
	current_badge.size = Vector2(144, 26)


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
		"Taverne":
			return Color("#d9a06a")
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
		return UiFactory.stat_icon_path("shield")
	match kind:
		"Basis":
			return "res://assets/items/backpacks/small_backpack.svg"
		"Haendler":
			return "res://assets/items/drinks/clean_water.svg"
		"Taverne":
			return "res://assets/items/drinks/rainwater.svg"
		"Event":
			return "res://assets/items/misc/radio_parts.svg"
		"Dungeon":
			return "res://assets/items/medical/cleansing_salt.svg"
		_:
			return "res://assets/items/misc/flashlight_battery.svg"


func _map_label_text(value: String) -> String:
	var words := value.split(" ", false)
	if words.size() <= 1:
		return value
	if words.size() == 2:
		return "\n".join(words)
	return "%s\n%s" % [words[0], " ".join(words.slice(1))]
