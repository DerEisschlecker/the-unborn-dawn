# Purpose: Admin item browser opened with F6 for quick testing and balancing.
# Public API: Lists every catalog item with icon, description, grant buttons, and godmode toggle.
# Dependencies: GameplayScreen, DataCatalog, InventorySystem, OrnateUiStyles.
extends GameplayScreen

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const ADMIN_ITEMS_PER_PAGE := 12
const MENU_BACKGROUND := "res://assets/environments/backgrounds/menu_ruins.png"

const TAB_GROUPS: Dictionary = {
	"Waffen": ["Nahkampf", "Zweihand", "Pistole", "Fernkampf", "Maschinenpistole", "Sniper", "Wurfgegenstand"],
	"Ausruestung": ["Ruestung", "Kleidung", "Helm", "Schuhe", "Handschuhe", "Maske", "Schild", "Rucksack", "Ring", "Guertel", "Amulett"],
	"Verbrauch": ["Nahrung", "Getraenk", "Medizin", "Munition"],
	"Material": ["Material"],
}

var feedback_label: Label
var search_input: LineEdit
var godmode_checkbox: CheckBox
var tabs: TabContainer
var backpack_grid: GridContainer
var compact_screen := false
var _catalog_grids: Dictionary = {}
var _catalog_page_labels: Dictionary = {}
var _catalog_pages: Dictionary = {}
var _catalog_items: Dictionary = {}
var _search_mode := false


func _ready() -> void:
	DataCatalog.reload_all()
	compact_screen = UiFactory.is_compact_screen(self)
	_build_shell()
	EventBus.inventory_changed.connect(_refresh_backpack_grid)
	_refresh_backpack_grid()
	_refresh_catalog()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	clear_dynamic_children()
	var background := TextureRect.new()
	background.texture = load(MENU_BACKGROUND) as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := UiFactory.screen_margins(self, compact_screen)
	margin.add_theme_constant_override("margin_left", margins.left)
	margin.add_theme_constant_override("margin_right", margins.right)
	margin.add_theme_constant_override("margin_top", margins.top)
	margin.add_theme_constant_override("margin_bottom", UiFactory.hud_bottom_inset(self))
	add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var shell_panel := PanelContainer.new()
	shell_panel.custom_minimum_size = Vector2(
		clampf(UiFactory.viewport_size(self).x * 0.92, 760.0, 1180.0),
		0.0
	)
	shell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_panel.add_theme_stylebox_override("panel", UiFactory.menu_panel_style())
	center.add_child(shell_panel)
	var shell_margin := MarginContainer.new()
	shell_margin.add_theme_constant_override("margin_left", 18)
	shell_margin.add_theme_constant_override("margin_right", 18)
	shell_margin.add_theme_constant_override("margin_top", 16)
	shell_margin.add_theme_constant_override("margin_bottom", 14)
	shell_panel.add_child(shell_margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	shell_margin.add_child(content)
	attach_hud()
	_build_layout()


func _build_layout() -> void:
	UiFactory.clear_container(content)
	content.add_child(UiFactory.ornate_heading("ADMIN-LAGER", 30 if compact_screen else 34))
	content.add_child(UiFactory.ornate_muted_label(
		"Esc oder F6 schliesst die Liste. Ziehe Icons in den Rucksack oder nutze +1 / +Stapel.",
		13 if compact_screen else 14,
		true
	))
	content.add_child(UiFactory.menu_divider())
	var options_row := HBoxContainer.new()
	options_row.add_theme_constant_override("separation", 12)
	content.add_child(options_row)
	godmode_checkbox = CheckBox.new()
	godmode_checkbox.text = "Godmode — freie Kartenreise ohne Kosten oder Sperren"
	godmode_checkbox.button_pressed = GameState.is_admin_godmode()
	godmode_checkbox.add_theme_font_size_override("font_size", 13 if compact_screen else 14)
	godmode_checkbox.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82, 1.0))
	godmode_checkbox.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	godmode_checkbox.toggled.connect(_on_godmode_toggled)
	options_row.add_child(godmode_checkbox)
	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 12)
	content.add_child(main_row)
	_build_backpack_column(main_row)
	_build_catalog_column(main_row)
	var back := _menu_button("Zurück", _return)
	back.custom_minimum_size = Vector2(180 if compact_screen else 240, 40 if compact_screen else 44)
	content.add_child(back)


func _build_backpack_column(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300 if compact_screen else 340
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiFactory.menu_panel_style())
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiFactory.ornate_section_label("RUCKSACK"))
	box.add_child(UiFactory.ornate_muted_label("Items hierher ziehen", 12))
	backpack_grid = GridContainer.new()
	backpack_grid.columns = 6 if compact_screen else 8
	backpack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_grid.add_theme_constant_override("h_separation", 6)
	backpack_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(backpack_grid)
	box.add_child(UiFactory.rarity_legend())


func _build_catalog_column(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiFactory.menu_panel_style())
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiFactory.ornate_section_label("KATALOG"))
	var search_row := HBoxContainer.new()
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_theme_constant_override("separation", 8)
	box.add_child(search_row)
	search_row.add_child(UiFactory.ornate_muted_label("Suche", 14))
	search_input = UiFactory.line_edit("Name, Kategorie, Seltenheit", 280.0)
	OrnateUiStyles.apply_input_theme(search_input)
	search_input.clear_button_enabled = true
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_search_changed)
	search_row.add_child(search_input)
	feedback_label = UiFactory.ornate_muted_label("", 13 if compact_screen else 14, true)
	box.add_child(feedback_label)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(_on_tab_changed)
	if compact_screen:
		tabs.add_theme_font_size_override("font_size", 12)
	box.add_child(tabs)


func _menu_button(label: String, callback: Callable) -> Button:
	var button := UiFactory.button(label, callback, 180)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15 if compact_screen else 16)
	button.add_theme_color_override("font_color", Color("#e8ecf2"))
	button.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	button.add_theme_color_override("font_pressed_color", Color("#e0a070"))
	OrnateUiStyles.apply_button_theme(button)
	return button


func _on_godmode_toggled(enabled: bool) -> void:
	GameState.set_admin_godmode(enabled)
	feedback_label.text = "Godmode aktiv: freie Teleport-Reise auf der Karte." if enabled else "Godmode deaktiviert."


func _refresh_backpack_grid() -> void:
	if not is_instance_valid(backpack_grid):
		return
	UiFactory.clear_container(backpack_grid)
	var item_ids := InventorySystem.ordered_items()
	var visible_slots := mini(InventorySystem.slot_capacity, 16 if compact_screen else 20)
	backpack_grid.columns = mini(visible_slots, 8)
	for index in range(visible_slots):
		var item_id := str(item_ids[index]) if index < item_ids.size() else ""
		var amount := int(InventorySystem.items.get(item_id, 1)) if not item_id.is_empty() else 0
		backpack_grid.add_child(_backpack_slot(str(index), item_id, amount))


func _backpack_slot(key: String, item_id: String, amount: int) -> PanelContainer:
	var panel: PanelContainer = InventorySlotScript.new()
	var icon_dim := 40.0 if compact_screen else 44.0
	panel.custom_minimum_size = Vector2(icon_dim, icon_dim)
	panel.configure("backpack", key, item_id, true, not item_id.is_empty())
	panel.item_dropped.connect(_on_admin_item_dropped)
	if not item_id.is_empty():
		panel.decorate(amount)
	return panel


func _on_admin_item_dropped(target_source: String, target_key: String, item_id: String, source: String, source_key: String) -> void:
	if item_id.is_empty():
		return
	var message := ItemDragDrop.apply_drop(target_source, target_key, ItemDragDrop.make_payload(source, source_key, item_id))
	if not message.is_empty():
		feedback_label.text = message
	_refresh_backpack_grid()


func _refresh_catalog() -> void:
	if not is_instance_valid(tabs):
		return
	UiFactory.clear_container(tabs)
	_catalog_grids.clear()
	_catalog_page_labels.clear()
	_catalog_pages.clear()
	_catalog_items.clear()
	var query := search_input.text.strip_edges().to_lower() if is_instance_valid(search_input) else ""
	_search_mode = not query.is_empty()
	if _search_mode:
		var matches := _matching_items(query)
		_catalog_items["Suche"] = matches
		_catalog_pages["Suche"] = 0
		feedback_label.text = "%d Treffer fuer \"%s\"." % [matches.size(), query]
		tabs.add_child(_build_catalog_page("Suche", matches))
		return
	var grouped := _items_by_group()
	var total := 0
	for group_name in _sorted_group_names(grouped):
		var item_ids: Array = grouped[group_name]
		total += item_ids.size()
		_catalog_items[group_name] = item_ids
		_catalog_pages[group_name] = 0
		tabs.add_child(_build_catalog_page(group_name, item_ids))
	feedback_label.text = "%d Gegenstaende geladen (inkl. neue Waffen)." % total
	_paint_active_catalog_page()


func _build_catalog_page(tab_name: String, item_ids: Array) -> Control:
	var page := VBoxContainer.new()
	page.name = tab_name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	var grid := GridContainer.new()
	grid.columns = 2 if compact_screen else 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var scroll := UiFactory.scroll_wrap_fill(grid)
	scroll.custom_minimum_size.y = 280 if compact_screen else 360
	page.add_child(scroll)
	_catalog_grids[tab_name] = grid
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", 8)
	page.add_child(pager)
	var previous := _menu_button("<", func() -> void: _change_catalog_page(tab_name, -1))
	previous.custom_minimum_size = Vector2(52, 32)
	pager.add_child(previous)
	var page_label := UiFactory.ornate_muted_label("", 13)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pager.add_child(page_label)
	_catalog_page_labels[tab_name] = page_label
	var next := _menu_button(">", func() -> void: _change_catalog_page(tab_name, 1))
	next.custom_minimum_size = Vector2(52, 32)
	pager.add_child(next)
	_paint_catalog_page(tab_name, item_ids)
	return page


func _paint_active_catalog_page() -> void:
	var tab_name := _active_tab_name()
	if tab_name.is_empty():
		return
	_paint_catalog_page(tab_name, _catalog_items.get(tab_name, []))


func _paint_catalog_page(tab_name: String, item_ids: Array) -> void:
	var grid: GridContainer = _catalog_grids.get(tab_name, null)
	var page_label: Label = _catalog_page_labels.get(tab_name, null)
	if grid == null or page_label == null:
		return
	UiFactory.clear_container(grid)
	var pages := maxi(1, ceili(float(item_ids.size()) / float(ADMIN_ITEMS_PER_PAGE)))
	var page := clampi(int(_catalog_pages.get(tab_name, 0)), 0, pages - 1)
	_catalog_pages[tab_name] = page
	page_label.text = "%d / %d  (%d Items)" % [page + 1, pages, item_ids.size()]
	if item_ids.is_empty():
		var empty := UiFactory.ornate_muted_label("Keine passenden Items gefunden.", 16)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(empty)
		return
	var start := page * ADMIN_ITEMS_PER_PAGE
	for index in range(start, mini(start + ADMIN_ITEMS_PER_PAGE, item_ids.size())):
		var item_id := str(item_ids[index])
		if DataCatalog.item(item_id).is_empty():
			continue
		grid.add_child(_item_card(item_id))


func _change_catalog_page(tab_name: String, delta: int) -> void:
	if not _catalog_items.has(tab_name):
		return
	var item_ids: Array = _catalog_items[tab_name]
	var pages := maxi(1, ceili(float(item_ids.size()) / float(ADMIN_ITEMS_PER_PAGE)))
	_catalog_pages[tab_name] = clampi(int(_catalog_pages.get(tab_name, 0)) + delta, 0, pages - 1)
	_paint_catalog_page(tab_name, item_ids)


func _on_tab_changed(_tab: int) -> void:
	_paint_active_catalog_page()


func _active_tab_name() -> String:
	if not is_instance_valid(tabs) or tabs.get_tab_count() == 0:
		return ""
	return tabs.get_tab_title(tabs.current_tab)


func _items_by_group() -> Dictionary:
	var grouped := {}
	for group_name in TAB_GROUPS:
		grouped[group_name] = []
	grouped["Sonstiges"] = []
	for item_id in DataCatalog.all_admin_items():
		var data := DataCatalog.item(item_id)
		if data.is_empty():
			continue
		var category := str(data.get("category", "Sonstiges"))
		var placed := false
		for group_name in TAB_GROUPS:
			var categories: Array = TAB_GROUPS[group_name]
			if categories.has(category):
				grouped[group_name].append(item_id)
				placed = true
				break
		if not placed:
			grouped["Sonstiges"].append(item_id)
	for group_name in grouped:
		grouped[group_name] = _sort_item_ids(grouped[group_name])
	return grouped


func _sorted_group_names(grouped: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for group_name in TAB_GROUPS:
		if not grouped.get(group_name, []).is_empty():
			names.append(str(group_name))
	if not grouped.get("Sonstiges", []).is_empty():
		names.append("Sonstiges")
	return names


func _item_card(item_id: String) -> PanelContainer:
	var data := DataCatalog.item(item_id)
	var panel := PanelContainer.new()
	UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.045, 0.036, 0.030, 0.94), 6)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 54 if compact_screen else 58
	UiFactory.attach_item_tooltip(panel, item_id, 1, DataCatalog.item_value(item_id), "Admin-Lager")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	row.add_child(_admin_drag_slot(item_id))
	var lines: Array[String] = [
		str(data.get("name", item_id)),
		"%s | %s | %d C" % [data.get("category", "Item"), UiFactory.rarity_label(data), DataCatalog.item_value(item_id)]
	]
	if data.has("damage"):
		var weapon_line := "Schaden %d" % int(data.get("damage", 0))
		if not str(data.get("ammo", "")).is_empty():
			weapon_line += " | %s" % DataCatalog.item(str(data.get("ammo", ""))).get("name", data.get("ammo", ""))
		lines.append(weapon_line)
	var label := UiFactory.ornate_muted_label("\n".join(lines), 10 if compact_screen else 11, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	row.add_child(actions)
	var grant_one := _menu_button("+1", func() -> void: _grant(item_id, 1))
	grant_one.custom_minimum_size = Vector2(44, 24)
	grant_one.add_theme_font_size_override("font_size", 10)
	actions.add_child(grant_one)
	var bulk_amount := 10 if str(data.get("category", "")) in ["Munition", "Material"] else 3
	var grant_bulk := _menu_button("+%d" % bulk_amount, func() -> void: _grant(item_id, bulk_amount))
	grant_bulk.custom_minimum_size = Vector2(44, 24)
	grant_bulk.add_theme_font_size_override("font_size", 10)
	actions.add_child(grant_bulk)
	return panel


func _admin_drag_slot(item_id: String) -> PanelContainer:
	var panel: PanelContainer = InventorySlotScript.new()
	var icon_dim := 34.0 if compact_screen else 38.0
	panel.custom_minimum_size = Vector2(icon_dim, icon_dim)
	panel.configure("admin", item_id, item_id, false, true)
	panel.decorate(1, false, "Admin-Lager")
	return panel


func _grant(item_id: String, amount: int) -> void:
	if InventorySystem.admin_grant_item(item_id, amount):
		feedback_label.text = "%s x%d genommen." % [DataCatalog.item(item_id).get("name", item_id), amount]
	else:
		feedback_label.text = "Konnte Item nicht nehmen."


func _on_search_changed(_new_text: String) -> void:
	_refresh_catalog()


func _matching_items(query: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in DataCatalog.all_admin_items():
		var data := DataCatalog.item(item_id)
		if data.is_empty():
			continue
		var haystack := " ".join([
			item_id,
			str(data.get("name", "")),
			str(data.get("category", "")),
			UiFactory.rarity_label(data),
			str(data.get("rarity", "")),
			str(data.get("description", ""))
		]).to_lower()
		if haystack.contains(query):
			result.append(item_id)
	return _sort_item_ids(result)


func _sort_item_ids(item_ids: Array) -> Array[String]:
	var sorted: Array[String] = []
	for item_id in item_ids:
		sorted.append(str(item_id))
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var item_a := DataCatalog.item(a)
		var item_b := DataCatalog.item(b)
		var category_a := str(item_a.get("category", ""))
		var category_b := str(item_b.get("category", ""))
		if category_a == category_b:
			var rarity_a := int(item_a.get("rarity_rank", 0))
			var rarity_b := int(item_b.get("rarity_rank", 0))
			if rarity_a == rarity_b:
				return str(item_a.get("name", a)) < str(item_b.get("name", b))
			return rarity_a < rarity_b
		return category_a < category_b
	)
	return sorted


func _return() -> void:
	call_deferred("return_to_previous")


func _input(event: InputEvent) -> void:
	if not _is_close_input(event):
		return
	get_viewport().set_input_as_handled()
	_return()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_close_input(event):
		return
	get_viewport().set_input_as_handled()
	_return()


func _is_close_input(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	return event.is_action("ui_cancel") or event.keycode == KEY_ESCAPE or event.keycode == KEY_F6
