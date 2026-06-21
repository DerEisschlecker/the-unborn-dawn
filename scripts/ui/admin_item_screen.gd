# Purpose: Admin item browser opened with F6 for quick testing and balancing.
# Public API: Lists every catalog item with icon, description, and grant buttons.
# Dependencies: GameplayScreen, DataCatalog, InventorySystem.
extends GameplayScreen

const ADMIN_ITEMS_PER_PAGE := 18

var feedback_label: Label
var search_input: LineEdit
var tabs: TabContainer


func _ready() -> void:
	var root := setup_gameplay("ADMIN-LAGER", "F6 schliesst die Liste. Items werden direkt in den Rucksack gelegt.")
	var search_row := HBoxContainer.new()
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_theme_constant_override("separation", 10)
	root.add_child(search_row)
	var search_label := UiFactory.body_label("Suche", 16 if UiFactory.is_compact_screen() else 18, UiFactory.COLOR_GOLD)
	search_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	search_label.custom_minimum_size.x = 78
	search_row.add_child(search_label)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Name, Kategorie, Seltenheit oder Beschreibung"
	search_input.clear_button_enabled = true
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size.y = 36
	search_input.text_changed.connect(_on_search_changed)
	search_row.add_child(search_input)
	feedback_label = UiFactory.body_label("", 15 if UiFactory.is_compact_screen() else 18, UiFactory.COLOR_MUTED)
	root.add_child(feedback_label)
	root.add_child(UiFactory.rarity_legend())
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_refresh_tabs()


func _refresh_tabs() -> void:
	if not is_instance_valid(tabs):
		return
	UiFactory.clear_container(tabs)
	var query := search_input.text.strip_edges().to_lower() if is_instance_valid(search_input) else ""
	if not query.is_empty():
		var matches := _matching_items(query)
		feedback_label.text = "%d Treffer fuer \"%s\". +1 nimmt ein Item, der zweite Knopf nimmt einen Stapel." % [matches.size(), query]
		_add_paged_tabs("Suche", matches)
		return
	var categories := _items_by_category()
	var category_names := categories.keys()
	category_names.sort()
	var total := 0
	for category in category_names:
		var category_items: Array = categories[category]
		total += category_items.size()
		_add_paged_tabs(str(category), category_items)
	feedback_label.text = "%d Gegenstaende aus dem aktuellen Item-Katalog geladen." % total


func _add_paged_tabs(base_name: String, item_ids: Array) -> void:
	if item_ids.is_empty():
		tabs.add_child(_category_tab(base_name, item_ids))
		return
	var page_count := ceili(float(item_ids.size()) / float(ADMIN_ITEMS_PER_PAGE))
	for page in range(page_count):
		var start := page * ADMIN_ITEMS_PER_PAGE
		var end := mini(start + ADMIN_ITEMS_PER_PAGE, item_ids.size())
		var page_ids := item_ids.slice(start, end)
		var tab_name := base_name if page_count == 1 else "%s %d/%d" % [base_name, page + 1, page_count]
		tabs.add_child(_category_tab(tab_name, page_ids))


func _items_by_category() -> Dictionary:
	var result := {}
	for item_id in DataCatalog.all_admin_items():
		var data := DataCatalog.item(item_id)
		var category := str(data.get("category", "Sonstiges"))
		if not result.has(category):
			result[category] = []
		result[category].append(item_id)
	for category in result:
		result[category].sort_custom(func(a: String, b: String) -> bool:
			var item_a := DataCatalog.item(a)
			var item_b := DataCatalog.item(b)
			var rarity_a := int(item_a.get("rarity_rank", 0))
			var rarity_b := int(item_b.get("rarity_rank", 0))
			if rarity_a == rarity_b:
				return str(item_a.get("name", a)) < str(item_b.get("name", b))
			return rarity_a < rarity_b
		)
	return result


func _category_tab(category: String, item_ids: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = category
	grid.columns = 3 if UiFactory.is_compact_screen() else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	if item_ids.is_empty():
		var empty := UiFactory.body_label("Keine passenden Items gefunden.", 18, UiFactory.COLOR_MUTED)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(empty)
		return grid
	for item_id in item_ids:
		grid.add_child(_item_card(str(item_id)))
	return grid


func _item_card(item_id: String) -> PanelContainer:
	var data := DataCatalog.item(item_id)
	var panel := PanelContainer.new()
	UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.055, 0.075, 0.105, 0.78), 6)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFactory.attach_item_tooltip(panel, item_id, 1, DataCatalog.item_value(item_id), "Admin-Lager")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(34, 34) if UiFactory.is_compact_screen() else Vector2(38, 38)
	row.add_child(icon)
	var label := UiFactory.body_label("%s\n%s | %s | %d C" % [
		data.get("name", item_id),
		data.get("category", "Item"),
		UiFactory.rarity_label(data),
		DataCatalog.item_value(item_id)
	], 10 if UiFactory.is_compact_screen() else 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	row.add_child(actions)
	var grant_one := UiFactory.button("+1", func() -> void: _grant(item_id, 1), 82)
	grant_one.custom_minimum_size = Vector2(44, 30)
	grant_one.add_theme_font_size_override("font_size", 11)
	actions.add_child(grant_one)
	var bulk_amount := 10 if str(data.get("category", "")) in ["Munition", "Material"] else 3
	var grant_bulk := UiFactory.button("+%d" % bulk_amount, func() -> void: _grant(item_id, bulk_amount), 82)
	grant_bulk.custom_minimum_size = Vector2(44, 30)
	grant_bulk.add_theme_font_size_override("font_size", 11)
	actions.add_child(grant_bulk)
	return panel


func _detail_text(item_id: String) -> String:
	var data := DataCatalog.item(item_id)
	var lines: Array[String] = [
		str(data.get("name", item_id)),
		"%s  %.2f kg" % [data.get("category", "Gegenstand"), float(data.get("weight", 0.0))],
		"Seltenheit: %s" % UiFactory.rarity_label(data)
	]
	var condition := InventorySystem.condition_text(item_id)
	if not condition.is_empty():
		lines.append(condition)
	if data.has("damage"):
		var weapon_line := "Schaden %d" % int(data.get("damage", 0))
		if not str(data.get("ammo", "")).is_empty():
			weapon_line += " | Munition: %s" % DataCatalog.item(str(data.get("ammo", ""))).get("name", data.get("ammo", ""))
		lines.append(weapon_line)
	if data.has("equip_slot"):
		var slot := str(data.get("equip_slot", ""))
		lines.append("Slot: %s" % InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot))
	if not str(data.get("description", "")).is_empty():
		lines.append(str(data.get("description", "")))
	return "\n".join(lines)


func _grant(item_id: String, amount: int) -> void:
	if InventorySystem.admin_grant_item(item_id, amount):
		feedback_label.text = "%s x%d genommen." % [DataCatalog.item(item_id).get("name", item_id), amount]
	else:
		feedback_label.text = "Konnte Item nicht nehmen."


func _on_search_changed(_new_text: String) -> void:
	_refresh_tabs()


func _matching_items(query: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in DataCatalog.all_admin_items():
		var data := DataCatalog.item(item_id)
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		accept_event()
		go_to(GameState.return_scene if not GameState.return_scene.is_empty() else "res://scenes/world_map/world_map.tscn")
