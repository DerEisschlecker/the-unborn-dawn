# Purpose: Organized crafting workshop with recipe browser, material sources, and inventory panels.
# Public API: Crafts recipe outputs using backpack-only or backpack+storage materials.
# Dependencies: DataCatalog, InventorySystem, GameState, TimeSystem, UiFactory, OrnateUiStyles.
extends GameplayScreen

const SORT_NAME_ASC := 0
const SORT_NAME_DESC := 1
const SORT_LEVEL_ASC := 2
const SORT_LEVEL_DESC := 3
const SORT_CRAFTABLE_FIRST := 4

const TAB_ALL := 0
const TAB_WEAPONS := 1
const TAB_EQUIPMENT := 2
const TAB_MEDICAL := 3
const TAB_AMMO := 4
const TAB_MATERIALS := 5
const TAB_OTHER := 6

const TAB_LABELS: Array[String] = [
	"Alles",
	"Waffen",
	"Ausruestung",
	"Medizin",
	"Munition",
	"Materialien",
	"Sonstiges",
]

var recipe_list_box: VBoxContainer
var detail_name: Label
var detail_output_icon: TextureRect
var detail_desc: RichTextLabel
var detail_materials: RichTextLabel
var craft_button: Button
var backpack_list_box: VBoxContainer
var storage_list_box: PanelContainer
var storage_body: VBoxContainer
var feedback: Label
var context_label: Label
var sort_option: OptionButton
var recipe_tab: TabBar
var backpack_tab: TabBar
var storage_tab: TabBar
var selected_recipe_id := ""
var recipe_sort_mode: int = SORT_NAME_ASC
var recipe_tab_filter: int = TAB_ALL
var inventory_tab_filter: int = TAB_ALL
var _refreshing: bool = false


func _ready() -> void:
	AudioManager.play_scene_music("crafting")
	content = setup_gameplay("HANDWERK", "")
	_build_layout()
	EventBus.inventory_changed.connect(_refresh)
	call_deferred("_refresh")


func _build_layout() -> void:
	UiFactory.clear_container(content)
	content.add_child(UiFactory.ornate_heading("HANDWERK", 34))
	context_label = UiFactory.ornate_muted_label("", 13, true)
	context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(context_label)
	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 12)
	content.add_child(main_row)
	main_row.add_child(UiFactory.framed_column("REZEPTE", _build_recipe_column(), true))
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 8)
	detail_name = UiFactory.ornate_heading("", 20)
	detail_column.add_child(detail_name)
	var output_row := HBoxContainer.new()
	output_row.alignment = BoxContainer.ALIGNMENT_CENTER
	output_row.add_theme_constant_override("separation", 10)
	detail_column.add_child(output_row)
	detail_output_icon = TextureRect.new()
	detail_output_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_output_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_output_icon.custom_minimum_size = Vector2(56, 56)
	output_row.add_child(detail_output_icon)
	detail_desc = RichTextLabel.new()
	detail_desc.bbcode_enabled = true
	detail_desc.fit_content = true
	detail_desc.scroll_active = false
	detail_desc.custom_minimum_size = Vector2(0, 36)
	detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(detail_desc)
	detail_materials = RichTextLabel.new()
	detail_materials.bbcode_enabled = true
	detail_materials.fit_content = true
	detail_materials.scroll_active = false
	detail_materials.custom_minimum_size = Vector2(0, 72)
	detail_column.add_child(detail_materials)
	craft_button = UiFactory.button("HERSTELLEN", _craft_selected, 220, AudioManager.UiClickKind.CONFIRM)
	craft_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_column.add_child(craft_button)
	main_row.add_child(UiFactory.framed_column("REZEPT", detail_column, true))
	backpack_list_box = VBoxContainer.new()
	backpack_list_box.add_theme_constant_override("separation", 3)
	main_row.add_child(_build_inventory_column("RUCKSACK", backpack_list_box, true))
	storage_body = VBoxContainer.new()
	storage_body.add_theme_constant_override("separation", 3)
	storage_list_box = _build_inventory_column("LAGER", storage_body, false)
	main_row.add_child(storage_list_box)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	feedback = UiFactory.ornate_muted_label("", 13, true)
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(feedback)
	sort_option = OptionButton.new()
	sort_option.custom_minimum_size.x = 220
	sort_option.add_item("Name A-Z", SORT_NAME_ASC)
	sort_option.add_item("Name Z-A", SORT_NAME_DESC)
	sort_option.add_item("Werkbank aufsteigend", SORT_LEVEL_ASC)
	sort_option.add_item("Werkbank absteigend", SORT_LEVEL_DESC)
	sort_option.add_item("Machbare zuerst", SORT_CRAFTABLE_FIRST)
	sort_option.item_selected.connect(_on_sort_changed)
	footer.add_child(sort_option)
	footer.add_child(UiFactory.button("ZURUECK", _return, 180))


func _build_recipe_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	recipe_list_box = VBoxContainer.new()
	recipe_list_box.add_theme_constant_override("separation", 4)
	recipe_tab = _build_craft_tab_bar()
	column.add_child(recipe_tab)
	column.add_child(UiFactory.scroll_wrap_fill(recipe_list_box))
	recipe_tab.tab_changed.connect(_on_recipe_tab_changed)
	column.custom_minimum_size = Vector2(250, 300)
	return column


func _build_inventory_column(title: String, body: VBoxContainer, is_backpack: bool) -> PanelContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var tab := _build_craft_tab_bar()
	column.add_child(tab)
	column.add_child(UiFactory.scroll_wrap_fill(body))
	if is_backpack:
		backpack_tab = tab
		tab.tab_changed.connect(_on_backpack_tab_changed)
	else:
		storage_tab = tab
		tab.tab_changed.connect(_on_storage_tab_changed)
	column.custom_minimum_size = Vector2(190, 300)
	return UiFactory.framed_column(title, column)


func _build_craft_tab_bar() -> TabBar:
	var tab := TabBar.new()
	for label in TAB_LABELS:
		tab.add_tab(label)
	return tab


func _on_recipe_tab_changed(tab_index: int) -> void:
	recipe_tab_filter = tab_index
	_refresh_recipe_list()
	_refresh_detail_panel()


func _on_backpack_tab_changed(tab_index: int) -> void:
	inventory_tab_filter = tab_index
	_refresh_inventory_panels()


func _on_storage_tab_changed(tab_index: int) -> void:
	inventory_tab_filter = tab_index
	_refresh_inventory_panels()


func _on_sort_changed(index: int) -> void:
	recipe_sort_mode = sort_option.get_item_id(index)
	_refresh()


func _refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	_update_context_banner()
	_refresh_recipe_list()
	_refresh_detail_panel()
	call_deferred("_deferred_inventory_refresh")


func _deferred_inventory_refresh() -> void:
	_refresh_inventory_panels()
	_refreshing = false


func _update_context_banner() -> void:
	var workshop: int = _effective_workbench_level()
	if InventorySystem.crafting_uses_storage():
		context_label.text = "Werkbank %d · Materialien aus Rucksack und Lager verfuegbar." % workshop
	else:
		context_label.text = "Werkbank %d · Unterwegs: nur Rucksack-Materialien werden verwendet." % workshop
	if is_instance_valid(storage_list_box):
		storage_list_box.visible = InventorySystem.crafting_uses_storage()
	feedback.text = "Rucksack %d/%d Plaetze · %.1f/%.1f kg" % [
		InventorySystem.used_slots(),
		InventorySystem.slot_capacity,
		InventorySystem.current_weight(),
		InventorySystem.max_weight
	]
	if InventorySystem.crafting_uses_storage():
		feedback.text += " | Lager %d/%d · %.1f/%.1f kg" % [
			InventorySystem.storage_used_slots(),
			InventorySystem.storage_slot_capacity(),
			InventorySystem.storage_current_weight(),
			InventorySystem.storage_max_weight()
		]


func _refresh_recipe_list() -> void:
	if not is_instance_valid(recipe_list_box):
		return
	UiFactory.clear_container(recipe_list_box)
	var recipe_ids: Array = _sorted_recipe_ids()
	if recipe_ids.is_empty():
		selected_recipe_id = ""
		recipe_list_box.add_child(UiFactory.ornate_muted_label("Keine Rezepte in dieser Kategorie.", 12, true))
		return
	if selected_recipe_id.is_empty() or not recipe_ids.has(selected_recipe_id):
		selected_recipe_id = str(recipe_ids[0])
	for recipe_id in recipe_ids:
		recipe_list_box.add_child(_recipe_row(str(recipe_id)))


func _recipe_row(recipe_id: String) -> Button:
	var recipe: Dictionary = DataCatalog.recipe(recipe_id)
	var output: Dictionary = DataCatalog.item(str(recipe.get("output", "")))
	var craftable: bool = _recipe_craftable(recipe_id)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s  ->  %s x%d" % [
		str(recipe.get("name", recipe_id)),
		str(output.get("name", recipe.get("output", ""))),
		int(recipe.get("amount", 1))
	]
	button.tooltip_text = "Werkbank %d" % int(recipe.get("level", 0))
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFactory.wire_button_sound(button)
	var highlighted: bool = recipe_id == selected_recipe_id
	button.add_theme_stylebox_override("normal", OrnateUiStyles.list_button_style(highlighted, not craftable))
	button.add_theme_stylebox_override("hover", OrnateUiStyles.list_button_style(true, false))
	button.add_theme_stylebox_override("pressed", OrnateUiStyles.list_button_style(true, false))
	if craftable:
		button.add_theme_color_override("font_color", Color(0.90, 0.88, 0.84, 1.0))
	else:
		button.add_theme_color_override("font_color", Color(0.55, 0.52, 0.50, 0.88))
	button.pressed.connect(_select_recipe.bind(recipe_id))
	return button


func _select_recipe(recipe_id: String) -> void:
	selected_recipe_id = recipe_id
	_refresh_recipe_list()
	_refresh_detail_panel()


func _refresh_detail_panel() -> void:
	if selected_recipe_id.is_empty():
		detail_name.text = "REZEPT WAEHLEN"
		detail_output_icon.texture = null
		detail_desc.text = ""
		detail_materials.text = ""
		craft_button.disabled = true
		return
	var recipe: Dictionary = DataCatalog.recipe(selected_recipe_id)
	var output: Dictionary = DataCatalog.item(str(recipe.get("output", "")))
	detail_name.text = str(recipe.get("name", selected_recipe_id)).to_upper()
	detail_output_icon.texture = load(str(output.get("icon", "res://icon.svg")))
	detail_desc.text = "[color=#b8a890]%s x%d[/color]\n[color=#8e8274]Werkbank-Stufe %d[/color]" % [
		output.get("name", recipe.get("output", "")),
		int(recipe.get("amount", 1)),
		int(recipe.get("level", 0))
	]
	detail_materials.text = _materials_bbcode(recipe.get("inputs", {}))
	var craftable: bool = _recipe_craftable(selected_recipe_id)
	craft_button.disabled = not craftable
	craft_button.text = "HERSTELLEN" if craftable else "MATERIALIEN FEHLEN"


func _materials_bbcode(inputs: Dictionary) -> String:
	if inputs.is_empty():
		return "[color=#8e8274]Keine Materialien[/color]"
	var use_storage: bool = InventorySystem.crafting_uses_storage()
	var lines: PackedStringArray = PackedStringArray(["[color=#c8a060]BENOETIGT[/color]"])
	for item_id in inputs:
		var key: String = str(item_id)
		var required: int = int(inputs[item_id])
		var available: int = InventorySystem.available_craft_count(key, use_storage)
		var item_name: String = str(DataCatalog.item(key).get("name", key))
		var color: String = "#78d888" if available >= required else "#e07060"
		var line: String = "[color=%s]%s %d/%d[/color]" % [color, item_name, mini(available, required), required]
		if available < required:
			line += " [color=#e07060](-%d)[/color]" % (required - available)
		if use_storage:
			line += "\n   [color=#7a746c]Rucksack %d · Lager %d[/color]" % [
				InventorySystem.backpack_count(key),
				InventorySystem.storage_count(key)
			]
		else:
			line += "\n   [color=#7a746c]Rucksack %d[/color]" % InventorySystem.backpack_count(key)
		lines.append(line)
	return "\n".join(lines)


func _refresh_inventory_panels() -> void:
	if not is_instance_valid(backpack_list_box):
		return
	_populate_item_panel(backpack_list_box, InventorySystem.sorted_items_for_layout(), false)
	if not is_instance_valid(storage_body):
		return
	UiFactory.clear_container(storage_body)
	if not InventorySystem.crafting_uses_storage():
		storage_body.add_child(UiFactory.ornate_muted_label("Lager nur in der Basis verfuegbar.", 12, true))
		return
	_populate_item_panel(storage_body, InventorySystem.sorted_storage_items_for_layout(), true)


func _populate_item_panel(container: VBoxContainer, item_ids: Array, storage: bool) -> void:
	UiFactory.clear_container(container)
	var filtered: Array = []
	for item_id in item_ids:
		var key: String = str(item_id)
		if _item_matches_tab(key, inventory_tab_filter):
			filtered.append(key)
	if filtered.is_empty():
		container.add_child(UiFactory.ornate_muted_label("Leer", 12))
		return
	for item_id in filtered:
		var amount: int = InventorySystem.storage_count(item_id) if storage else InventorySystem.backpack_count(item_id)
		container.add_child(_inventory_row(item_id, amount))


func _inventory_row(item_id: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = load(str(DataCatalog.item(item_id).get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	row.add_child(icon)
	var label := UiFactory.ornate_muted_label("%s x%d" % [DataCatalog.item(item_id).get("name", item_id), amount], 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _sorted_recipe_ids() -> Array:
	var ids: Array = []
	for recipe_id in DataCatalog.recipes:
		var key: String = str(recipe_id)
		var recipe: Dictionary = DataCatalog.recipe(key)
		var output_id: String = str(recipe.get("output", ""))
		if _recipe_matches_tab(output_id, recipe_tab_filter):
			ids.append(key)
	match recipe_sort_mode:
		SORT_NAME_DESC:
			ids.sort_custom(_sort_recipe_name_desc)
		SORT_LEVEL_ASC:
			ids.sort_custom(_sort_recipe_level_asc)
		SORT_LEVEL_DESC:
			ids.sort_custom(_sort_recipe_level_desc)
		SORT_CRAFTABLE_FIRST:
			ids.sort_custom(_sort_recipe_craftable_first)
		_:
			ids.sort_custom(_sort_recipe_name_asc)
	return ids


func _recipe_matches_tab(output_id: String, tab_index: int) -> bool:
	if tab_index == TAB_ALL:
		return true
	return _craft_tab_for_item(output_id) == tab_index


func _item_matches_tab(item_id: String, tab_index: int) -> bool:
	if tab_index == TAB_ALL:
		return true
	return _craft_tab_for_item(item_id) == tab_index


func _craft_tab_for_item(item_id: String) -> int:
	var category: String = str(DataCatalog.item(item_id).get("category", ""))
	match category:
		"Waffe", "Pistole", "Maschinenpistole", "Sniper", "Fernkampf", "Nahkampf", "Zweihand", "Wurfgegenstand":
			return TAB_WEAPONS
		"Ruestung", "Kleidung", "Maske", "Helm", "Schuhe", "Handschuhe", "Ring", "Guertel", "Amulett", "Schild", "Rucksack":
			return TAB_EQUIPMENT
		"Medizin":
			return TAB_MEDICAL
		"Munition":
			return TAB_AMMO
		"Material":
			return TAB_MATERIALS
		_:
			return TAB_OTHER


func _sort_recipe_name_asc(a: String, b: String) -> bool:
	return str(DataCatalog.recipe(a).get("name", a)) < str(DataCatalog.recipe(b).get("name", b))


func _sort_recipe_name_desc(a: String, b: String) -> bool:
	return str(DataCatalog.recipe(a).get("name", a)) > str(DataCatalog.recipe(b).get("name", b))


func _sort_recipe_level_asc(a: String, b: String) -> bool:
	return int(DataCatalog.recipe(a).get("level", 0)) < int(DataCatalog.recipe(b).get("level", 0))


func _sort_recipe_level_desc(a: String, b: String) -> bool:
	return int(DataCatalog.recipe(a).get("level", 0)) > int(DataCatalog.recipe(b).get("level", 0))


func _sort_recipe_craftable_first(a: String, b: String) -> bool:
	var a_ok: bool = _recipe_craftable(a)
	var b_ok: bool = _recipe_craftable(b)
	if a_ok != b_ok:
		return a_ok and not b_ok
	return str(DataCatalog.recipe(a).get("name", a)) < str(DataCatalog.recipe(b).get("name", b))


func _recipe_craftable(recipe_id: String) -> bool:
	var recipe: Dictionary = DataCatalog.recipe(recipe_id)
	if _effective_workbench_level() < int(recipe.get("level", 0)):
		return false
	return InventorySystem.has_craft_materials(recipe.get("inputs", {}), InventorySystem.crafting_uses_storage())


func _craft_selected() -> void:
	if selected_recipe_id.is_empty():
		return
	_craft(selected_recipe_id)


func _craft(recipe_id: String) -> void:
	var recipe: Dictionary = DataCatalog.recipe(recipe_id)
	var use_storage: bool = InventorySystem.crafting_uses_storage()
	if _effective_workbench_level() < int(recipe.get("level", 0)):
		feedback.text = "Werkbank-Stufe zu niedrig."
		return
	var plan: Dictionary = InventorySystem.take_craft_materials(recipe.get("inputs", {}), use_storage)
	if plan.is_empty():
		feedback.text = "Materialien fehlen."
		_refresh()
		return
	var output_id: String = str(recipe.get("output", ""))
	var amount: int = int(recipe.get("amount", 1))
	if not InventorySystem.add_item(output_id, amount):
		InventorySystem.restore_craft_materials(plan)
		feedback.text = "Der Rucksack ist zu schwer oder voll. Materialien wurden zurueckgelegt."
		_refresh()
		return
	GameState.run_statistics.items_crafted = int(GameState.run_statistics.items_crafted) + amount
	AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -4.0)
	GameState.spend_for_action(4.0, 3.0)
	feedback.text = "%s x%d hergestellt." % [DataCatalog.item(output_id).get("name", output_id), amount]
	_refresh()


func _return() -> void:
	call_deferred("return_to_previous", "res://scenes/base/base_scene.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		accept_event()
		_return()
		return
	super._unhandled_input(event)


func _effective_workbench_level() -> int:
	return int(GameState.base_state.structures.get("workbench", 0)) + int(GameState.player_stats.get("crafting", 0)) + int(InventorySystem.total_equipment_bonus("crafting_bonus"))
