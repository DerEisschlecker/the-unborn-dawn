# Purpose: Character sheet for level progress, skill points, class ability, and equipment slots.
# Public API: Opened from GameplayScreen with C, supports equip, unequip, and skill spending.
# Dependencies: GameState, InventorySystem, DataCatalog, UiFactory.
extends GameplayScreen

const EQUIPMENT_COMPARE_ROWS := [
	{"key": "damage", "label": "Schaden"},
	{"key": "armor", "label": "Ruestung"},
	{"key": "shield", "label": "Schutz"},
	{"key": "strength", "label": "STR"},
	{"key": "dexterity", "label": "DEX"},
	{"key": "intelligence", "label": "INT"},
	{"key": "vitality", "label": "VIT"},
	{"key": "willpower", "label": "WIL"},
	{"key": "stamina_bonus", "label": "Ausdauer"},
	{"key": "max_stamina_bonus", "label": "Max Ausdauer"},
	{"key": "accuracy", "label": "Genauigkeit"},
	{"key": "crafting_bonus", "label": "Handwerk"},
	{"key": "infection_resist", "label": "Filter"},
	{"key": "pocket_slots", "label": "Taschen"},
	{"key": "carry_weight_bonus", "label": "Traglast"},
	{"key": "chaos_resistance", "label": "Chaosresistenz"},
	{"key": "shadow_resistance", "label": "Schattenresistenz"},
	{"key": "light_resistance", "label": "Lichtresistenz"},
	{"key": "block_chance", "label": "Blocken"}
]

var summary_label: Label
var feedback_label: Label
var equipment_box: VBoxContainer
var skills_box: VBoxContainer
var abilities_box: VBoxContainer
var item_box: VBoxContainer
var avatar: TextureRect
var compare_label: RichTextLabel
var compare_labels: Array[RichTextLabel] = []
var compact_screen := false


func _ready() -> void:
	compact_screen = UiFactory.is_compact_screen()
	var root := setup_gameplay("CHARAKTER & AUSRUESTUNG", "Skillpunkte, Kleidung, Waffen und Werkzeuge.")
	if compact_screen:
		_compact_root_typography(root)
	root.add_child(_build_header())
	if compact_screen:
		_build_compact_content(root)
	else:
		root.add_child(UiFactory.rarity_legend())
		_build_wide_content(root)
	var back_button := UiFactory.button("Zurueck", _return, 240 if not compact_screen else 180)
	if compact_screen:
		back_button.custom_minimum_size.y = 36
	root.add_child(back_button)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.stats_changed.connect(_refresh)
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


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10 if compact_screen else 18)
	avatar = TextureRect.new()
	avatar.texture = load(GameState.player_appearance_path())
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(62, 62) if compact_screen else Vector2(118, 118)
	header.add_child(avatar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3 if compact_screen else 7)
	header.add_child(info)
	summary_label = UiFactory.body_label("", 12 if compact_screen else 19, UiFactory.COLOR_GOLD)
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(summary_label)
	feedback_label = UiFactory.body_label("", 12 if compact_screen else 18, UiFactory.COLOR_MUTED)
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(feedback_label)
	return header


func _build_wide_content(root: VBoxContainer) -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var equipment_panel := UiFactory.section("Ausrustung")
	equipment_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(equipment_panel.get_parent())
	equipment_box = VBoxContainer.new()
	equipment_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_panel.add_child(equipment_box)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 560
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var skills_panel := UiFactory.section("Level & Skills")
	right.add_child(skills_panel.get_parent())
	skills_box = VBoxContainer.new()
	skills_panel.add_child(skills_box)
	var abilities_panel := UiFactory.section("Faehigkeiten")
	right.add_child(abilities_panel.get_parent())
	abilities_box = VBoxContainer.new()
	abilities_panel.add_child(abilities_box)
	var compare_panel := UiFactory.section("Vergleich")
	right.add_child(compare_panel.get_parent())
	compare_label = _create_compare_label(Vector2(520, 150))
	compare_panel.add_child(compare_label)
	var items_panel := UiFactory.section("Im Rucksack")
	items_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(items_panel.get_parent())
	item_box = VBoxContainer.new()
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_panel.add_child(item_box)


func _build_compact_content(root: VBoxContainer) -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 12)
	root.add_child(tabs)

	var equipment_page := HSplitContainer.new()
	equipment_page.name = "Ausrustung"
	equipment_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(equipment_page)
	var equipment_panel := UiFactory.section("Slots")
	_tighten_section_box(equipment_panel)
	equipment_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_page.add_child(equipment_panel.get_parent())
	equipment_box = VBoxContainer.new()
	equipment_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_panel.add_child(equipment_box)
	var compare_panel := UiFactory.section("Vergleich")
	_tighten_section_box(compare_panel)
	compare_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_page.add_child(compare_panel.get_parent())
	compare_label = _create_compare_label(Vector2(330, 210))
	compare_panel.add_child(compare_label)

	var skills_page := VBoxContainer.new()
	skills_page.name = "Skills"
	skills_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(skills_page)
	var skills_panel := UiFactory.section("Passive Punkte")
	_tighten_section_box(skills_panel)
	skills_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_page.add_child(skills_panel.get_parent())
	skills_box = VBoxContainer.new()
	skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_panel.add_child(skills_box)

	var abilities_page := VBoxContainer.new()
	abilities_page.name = "Faehigkeiten"
	abilities_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilities_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(abilities_page)
	var abilities_panel := UiFactory.section("Faehigkeiten")
	_tighten_section_box(abilities_panel)
	abilities_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilities_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	abilities_page.add_child(abilities_panel.get_parent())
	abilities_box = VBoxContainer.new()
	abilities_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilities_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	abilities_panel.add_child(abilities_box)

	var pack_page := HSplitContainer.new()
	pack_page.name = "Rucksack"
	pack_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(pack_page)
	var items_panel := UiFactory.section("Anlegbare Items")
	_tighten_section_box(items_panel)
	items_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	pack_page.add_child(items_panel.get_parent())
	item_box = VBoxContainer.new()
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_panel.add_child(item_box)
	var pack_compare_panel := UiFactory.section("Werte")
	_tighten_section_box(pack_compare_panel)
	pack_compare_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_compare_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	pack_page.add_child(pack_compare_panel.get_parent())
	compare_label = _create_compare_label(Vector2(330, 210))
	pack_compare_panel.add_child(compare_label)
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		_sync_tab_pages(tabs, tab_index)
	)
	call_deferred("_sync_tab_pages", tabs, 0)


func _sync_tab_pages(tabs: TabContainer, tab_index: int) -> void:
	if not is_instance_valid(tabs):
		return
	for index in range(tabs.get_child_count()):
		var child := tabs.get_child(index) as Control
		if child:
			child.visible = index == tab_index


func _tighten_section_box(box: VBoxContainer) -> void:
	if not compact_screen:
		return
	box.add_theme_constant_override("separation", 5)
	var panel := box.get_parent() as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel", _compact_panel_style())
	if box.get_child_count() > 0 and box.get_child(0) is Label:
		var title := box.get_child(0) as Label
		title.add_theme_font_size_override("font_size", 17)


func _compact_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.105, 0.78)
	style.border_color = Color(0.38, 0.43, 0.50, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _create_compare_label(minimum_size: Vector2) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.custom_minimum_size = minimum_size
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 12 if compact_screen else 15)
	label.add_theme_color_override("default_color", Color("#d8dde8"))
	compare_labels.append(label)
	return label


func _set_compare_text(text: String) -> void:
	for label in compare_labels:
		if is_instance_valid(label):
			label.text = text


func _refresh() -> void:
	_refresh_summary()
	_refresh_equipment()
	_refresh_skills()
	_refresh_abilities()
	_refresh_items()
	_show_compare_hint()


func _refresh_summary() -> void:
	var effective := GameState.effective_player_stats()
	if compact_screen:
		summary_label.text = "%s - %s | Lvl %d | XP %d/%d | Punkte %d | Picks %d\nHP %.0f/%.0f  AUS %.0f/%.0f  ENE %.0f/%.0f  AP-Leiste %d/%d  Ruestung %.0f\nSTR %.0f  DEX %.0f  INT %.0f  VIT %.0f  WIL %.0f  Genauigkeit %.0f" % [
			GameState.player_name,
			GameState.player_class_name(),
			int(GameState.player_stats.get("level", 1)),
			int(GameState.player_stats.get("xp", 0)),
			int(GameState.player_stats.get("next_xp", 60)),
			int(GameState.player_stats.get("skill_points", 0)),
			GameState.pending_ability_picks,
			float(GameState.player_stats.get("health", 0.0)),
			float(effective.get("max_health", 100.0)),
			float(GameState.player_stats.get("stamina", 0.0)),
			float(effective.get("max_stamina", 100.0)),
			float(GameState.player_stats.get("energy", 0.0)),
			float(effective.get("max_energy", 100.0)),
			GameState.equipped_ability_count(),
			GameState.MAX_EQUIPPED_ABILITIES,
			InventorySystem.armor_value(),
			float(effective.get("strength", 0.0)),
			float(effective.get("dexterity", 0.0)),
			float(effective.get("intelligence", 0.0)),
			float(effective.get("vitality", 0.0)),
			float(effective.get("willpower", 0.0)),
			float(effective.get("precision", 0.0))
		]
		return
	summary_label.text = "%s - %s\nLevel %d   XP %d / %d   Passive Punkte %d   Faehigkeitspicks %d\nSTR %.0f  DEX %.0f  INT %.0f  VIT %.0f  WIL %.0f\nLeben %.0f/%.0f  Mana %.0f/%.0f  Ausdauer %.0f/%.0f  Energie %.0f/%.0f\nPraezision %.0f  Ausweichen %.0f  Krit %.0f%%  Kontrolle %.0f\nLeiste: %d/%d Faehigkeiten\nAusrustungsruestung: %.0f" % [
		GameState.player_name,
		GameState.player_class_name(),
		int(GameState.player_stats.get("level", 1)),
		int(GameState.player_stats.get("xp", 0)),
		int(GameState.player_stats.get("next_xp", 60)),
		int(GameState.player_stats.get("skill_points", 0)),
		GameState.pending_ability_picks,
		float(effective.get("strength", 0.0)),
		float(effective.get("dexterity", 0.0)),
		float(effective.get("intelligence", 0.0)),
		float(effective.get("vitality", 0.0)),
		float(effective.get("willpower", 0.0)),
		float(GameState.player_stats.get("health", 0.0)),
		float(effective.get("max_health", 100.0)),
		float(GameState.player_stats.get("mana", 0.0)),
		float(effective.get("max_mana", 100.0)),
		float(GameState.player_stats.get("stamina", 0.0)),
		float(effective.get("max_stamina", 100.0)),
		float(GameState.player_stats.get("energy", 0.0)),
		float(effective.get("max_energy", 100.0)),
		float(effective.get("precision", 0.0)),
		float(effective.get("evasion", 0.0)),
		float(effective.get("critical_chance", 0.0)),
		float(effective.get("control_resist", 0.0)),
		GameState.equipped_ability_count(),
		GameState.MAX_EQUIPPED_ABILITIES,
		InventorySystem.armor_value()
	]


func _refresh_equipment() -> void:
	UiFactory.clear_container(equipment_box)
	var slots := InventorySystem.EQUIPMENT_SLOTS.keys()
	slots.sort_custom(func(a: String, b: String) -> bool:
		return int(InventorySystem.EQUIPMENT_SLOTS[a].get("order", 0)) < int(InventorySystem.EQUIPMENT_SLOTS[b].get("order", 0))
	)
	if compact_screen:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		equipment_box.add_child(grid)
		for slot in slots:
			grid.add_child(_slot_card(str(slot)))
		return
	for slot in slots:
		equipment_box.add_child(_slot_row(str(slot)))


func _slot_card(slot: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _compact_panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(150, 66)
	var item_id := InventorySystem.equipped_item(slot)
	var data := DataCatalog.item(item_id)
	if not item_id.is_empty():
		UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.055, 0.075, 0.105, 0.78), 5)
		UiFactory.attach_item_tooltip(panel, item_id, 1, -1, str(InventorySystem.EQUIPMENT_SLOTS[slot].get("name", slot)))
		panel.mouse_entered.connect(func() -> void: _show_equipped_detail(slot, item_id))
	else:
		panel.mouse_entered.connect(func() -> void: _show_slot_hint(slot))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg"))) if not item_id.is_empty() else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 30)
	row.add_child(icon)
	var slot_name := str(InventorySystem.EQUIPMENT_SLOTS[slot].get("name", slot))
	var item_name := str(data.get("name", "Leer")) if not item_id.is_empty() else "Leer"
	var label := UiFactory.body_label("%s\n%s" % [slot_name, _short_line(item_name, 20)], 11)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var button := UiFactory.button("Ab", func() -> void: _unequip(slot), 46)
	button.custom_minimum_size.y = 26
	button.disabled = item_id.is_empty()
	button.tooltip_text = "Ausrustung ablegen."
	row.add_child(button)
	if not item_id.is_empty() and InventorySystem.is_durable(item_id):
		box.add_child(_condition_bar(item_id, 120))
	return panel


func _slot_row(slot: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var item_id := InventorySystem.equipped_item(slot)
	var data := DataCatalog.item(item_id)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg"))) if not item_id.is_empty() else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(68, 68)
	row.add_child(icon)
	var slot_name := str(InventorySystem.EQUIPMENT_SLOTS[slot].get("name", slot))
	var text := "%s\nLeer" % slot_name
	if not item_id.is_empty():
		var condition := InventorySystem.condition_text(item_id)
		UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.055, 0.075, 0.105, 0.78), 6)
		UiFactory.attach_item_tooltip(panel, item_id, 1, -1, slot_name)
		panel.mouse_entered.connect(func() -> void: _show_equipped_detail(slot, item_id))
		text = "%s\n%s\n%s%s" % [
			slot_name,
			data.get("name", item_id),
			_bonus_text(data),
			"\n" + condition if not condition.is_empty() else ""
		]
	else:
		panel.mouse_entered.connect(func() -> void: _show_slot_hint(slot))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)
	var label := UiFactory.body_label(text, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(label)
	if not item_id.is_empty() and InventorySystem.is_durable(item_id):
		text_box.add_child(_condition_bar(item_id, 220))
	var button := UiFactory.button("Ablegen", func() -> void: _unequip(slot), 150)
	button.disabled = item_id.is_empty()
	row.add_child(button)
	if not item_id.is_empty() and InventorySystem.is_durable(item_id):
		var repair := UiFactory.button("Reparieren", func() -> void: _repair(item_id), 150)
		repair.tooltip_text = "Benoetigt: %s" % InventorySystem.repair_cost_text(item_id)
		repair.disabled = InventorySystem.condition(item_id) >= InventorySystem.max_condition(item_id)
		row.add_child(repair)
	return panel


func _refresh_skills() -> void:
	UiFactory.clear_container(skills_box)
	var points := int(GameState.player_stats.get("skill_points", 0))
	skills_box.add_child(UiFactory.body_label("Passive Punkte: %d" % points, 14 if compact_screen else 18, UiFactory.COLOR_GOLD))
	if compact_screen:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 5)
		skills_box.add_child(grid)
		for stat_name in ["strength", "dexterity", "intelligence", "vitality", "willpower", "max_health", "max_mana", "max_stamina", "max_energy", "melee", "ranged", "accuracy", "defense", "crafting", "critical_chance", "armor_pierce", "control_resist"]:
			grid.add_child(_skill_row(str(stat_name), points))
		return
	for stat_name in ["strength", "dexterity", "intelligence", "vitality", "willpower", "max_health", "max_mana", "max_stamina", "max_energy", "melee", "ranged", "accuracy", "defense", "crafting", "critical_chance", "armor_pierce", "control_resist"]:
		skills_box.add_child(_skill_row(str(stat_name), points))


func _skill_row(stat_name: String, points: int) -> HBoxContainer:
	var data: Dictionary = GameState.SKILL_UPGRADES[stat_name]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6 if compact_screen else 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := UiFactory.body_label("%s +%s" % [data.get("name", stat_name), data.get("amount", 1)], 12 if compact_screen else 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.tooltip_text = "%s verbessern" % data.get("name", stat_name)
	row.add_child(label)
	var button := UiFactory.button("+", func() -> void: _spend(stat_name), 42 if compact_screen else 64)
	button.custom_minimum_size.y = 28 if compact_screen else 52
	button.disabled = points <= 0
	button.tooltip_text = "%s verbessern" % data.get("name", stat_name)
	row.add_child(button)
	return row


func _refresh_abilities() -> void:
	UiFactory.clear_container(abilities_box)
	abilities_box.add_child(UiFactory.body_label("Ausgeruestet: %d/%d   Neue Wahlpunkte: %d" % [
		GameState.equipped_ability_count(),
		GameState.MAX_EQUIPPED_ABILITIES,
		GameState.pending_ability_picks
	], 13 if compact_screen else 17, UiFactory.COLOR_GOLD))
	if compact_screen:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		abilities_box.add_child(grid)
		for data in GameState.class_abilities():
			grid.add_child(_ability_row(data))
		return
	for data in GameState.class_abilities():
		abilities_box.add_child(_ability_row(data))


func _ability_row(data: Dictionary) -> PanelContainer:
	var ability_id := str(data.get("id", ""))
	var learned := GameState.learned_abilities.has(ability_id)
	var equipped := GameState.equipped_abilities.has(ability_id)
	var unlocked := GameState.ability_unlocked_for_level(ability_id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _compact_panel_style() if compact_screen else UiFactory._panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact_screen:
		panel.custom_minimum_size = Vector2(430, 50)
	panel.tooltip_text = GameState.ability_tooltip_text(ability_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7 if compact_screen else 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://assets/ui/icons/energy.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32) if compact_screen else Vector2(46, 46)
	row.add_child(icon)
	var status := "  [Leiste]" if equipped else ("  [Gelernt]" if learned else ("  [Level %d]" % GameState.ability_unlock_level(ability_id)))
	var details := "AP %d | CD %d | AUS %d | ENE %d" % [
		GameState.ability_action_points(ability_id),
		GameState.ability_cooldown(ability_id),
		int(data.get("stamina_cost", 0)),
		int(data.get("energy_cost", 0))
	]
	var visible_text := "%s%s\n%s" % [
		data.get("name", ability_id),
		status,
		details if compact_screen else data.get("description", "")
	]
	var label := UiFactory.body_label(visible_text, 11 if compact_screen else 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact_screen:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.tooltip_text = GameState.ability_tooltip_text(ability_id)
	row.add_child(label)
	var button_text := "Lernen"
	var callback := func() -> void: _learn_ability(ability_id)
	if learned and equipped:
		button_text = "Ablegen"
		callback = func() -> void: _unequip_ability(ability_id)
	elif learned:
		button_text = "Ausruesten"
		callback = func() -> void: _equip_ability(ability_id)
	var button := UiFactory.button("+" if compact_screen and button_text == "Lernen" else ("Ein" if compact_screen and button_text == "Ausruesten" else ("Ab" if compact_screen else button_text)), callback, 58 if compact_screen else 128)
	button.custom_minimum_size.y = 28 if compact_screen else 52
	button.tooltip_text = button_text
	if not learned:
		button.disabled = GameState.pending_ability_picks <= 0 or not unlocked
	elif not equipped:
		button.disabled = GameState.equipped_ability_count() >= GameState.MAX_EQUIPPED_ABILITIES
	row.add_child(button)
	return panel


func _refresh_items() -> void:
	UiFactory.clear_container(item_box)
	var item_ids := InventorySystem.items.keys()
	item_ids.sort()
	var any_item := false
	var target: Node = item_box
	if compact_screen:
		var grid := GridContainer.new()
		grid.columns = 1
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		item_box.add_child(grid)
		target = grid
	for item_id in item_ids:
		var data := DataCatalog.item(str(item_id))
		if not data.has("equip_slot"):
			continue
		any_item = true
		target.add_child(_inventory_row(str(item_id), data))
	if not any_item:
		item_box.add_child(UiFactory.body_label("Keine anlegbare Ausruestung im Rucksack.", 17, UiFactory.COLOR_MUTED))


func _inventory_row(item_id: String, data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.055, 0.075, 0.105, 0.78), 6)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact_screen:
		panel.custom_minimum_size = Vector2(430, 50)
	panel.mouse_entered.connect(func() -> void: _show_equipment_comparison(item_id))
	UiFactory.attach_item_tooltip(panel, item_id, int(InventorySystem.items.get(item_id, 1)), -1, "Anlegen")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7 if compact_screen else 12)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(34, 34) if compact_screen else Vector2(58, 58)
	row.add_child(icon)
	var slot := str(data.get("equip_slot", ""))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)
	var text := ""
	if compact_screen:
		text = "%s x%d\n%s" % [
			data.get("name", item_id),
			int(InventorySystem.items[item_id]),
			InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot)
		]
	else:
		text = "%s x%d\nSlot: %s\n%s" % [
			data.get("name", item_id),
			int(InventorySystem.items[item_id]),
			InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot),
			_bonus_text(data) + ("\n" + InventorySystem.condition_text(item_id) if not InventorySystem.condition_text(item_id).is_empty() else "")
		]
	var label := UiFactory.body_label(text, 11 if compact_screen else 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact_screen:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(label)
	if InventorySystem.is_durable(item_id):
		text_box.add_child(_condition_bar(item_id, 110 if compact_screen else 200))
	var button := UiFactory.button("An" if compact_screen else "Anlegen", func() -> void: _equip(item_id), 52 if compact_screen else 150)
	button.custom_minimum_size.y = 28 if compact_screen else 52
	row.add_child(button)
	return panel


func _condition_bar(item_id: String, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 12)
	bar.max_value = maxf(1.0, float(InventorySystem.max_condition(item_id)))
	bar.value = float(InventorySystem.condition(item_id))
	bar.tooltip_text = "Zustand: %d / %d" % [InventorySystem.condition(item_id), InventorySystem.max_condition(item_id)]
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiFactory.condition_color(InventorySystem.condition_ratio(item_id))
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.04, 0.048, 0.95)
	background.border_color = Color(0.32, 0.28, 0.22, 0.8)
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	return bar


func _show_compare_hint() -> void:
	if not is_instance_valid(compare_label):
		return
	_set_compare_text("[color=#8e9aab]Bewege die Maus ueber ein Ausruestungsteil, um alte und neue Werte zu vergleichen.[/color]")


func _show_slot_hint(slot: String) -> void:
	if not is_instance_valid(compare_label):
		return
	var slot_name := str(InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot))
	_set_compare_text("[color=#d8b36a]%s[/color]\n[color=#8e9aab]Dieser Slot ist leer. Passende Teile aus dem Rucksack werden rechts angezeigt.[/color]" % slot_name)


func _show_equipped_detail(slot: String, item_id: String) -> void:
	if not is_instance_valid(compare_label):
		return
	var data := DataCatalog.item(item_id)
	if data.is_empty():
		_show_slot_hint(slot)
		return
	var lines: Array[String] = []
	lines.append("[color=#f0dca9]%s[/color]" % data.get("name", item_id))
	lines.append("[color=%s]Seltenheit: %s[/color]" % [UiFactory.rarity_color(data).to_html(false), UiFactory.rarity_label(data)])
	lines.append("[color=#8e9aab]Aktuell angelegt in: %s[/color]" % InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot))
	if not str(data.get("description", "")).is_empty():
		lines.append(str(data.get("description", "")))
	var condition := InventorySystem.condition_text(item_id)
	if not condition.is_empty():
		lines.append(condition)
	for row in EQUIPMENT_COMPARE_ROWS:
		var key := str(row.get("key", ""))
		if data.has(key):
			lines.append("%s: %s" % [row.get("label", key), _stat_value_text(float(data.get(key, 0.0)))])
	_set_compare_text("\n".join(lines))


func _show_equipment_comparison(item_id: String) -> void:
	if not is_instance_valid(compare_label):
		return
	_set_compare_text(_equipment_compare_text(item_id))


func _equipment_compare_text(item_id: String) -> String:
	var data := DataCatalog.item(item_id)
	if data.is_empty():
		return "[color=#8e9aab]Unbekannter Gegenstand.[/color]"
	var lines: Array[String] = []
	lines.append("[color=#f0dca9]%s[/color]" % data.get("name", item_id))
	lines.append("[color=%s]Seltenheit: %s[/color]" % [UiFactory.rarity_color(data).to_html(false), UiFactory.rarity_label(data)])
	if not str(data.get("description", "")).is_empty():
		lines.append("[color=#8e9aab]%s[/color]" % data.get("description", ""))
	var slot := str(data.get("equip_slot", ""))
	if slot.is_empty() or not InventorySystem.EQUIPMENT_SLOTS.has(slot):
		lines.append("[color=#8e9aab]Nicht anlegbar.[/color]")
		return "\n".join(lines)
	var old_id := InventorySystem.equipped_item(slot)
	var old_data := DataCatalog.item(old_id)
	lines.append("")
	lines.append("[color=#d8b36a]%s: %s -> %s[/color]" % [
		InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot),
		old_data.get("name", "leer") if not old_data.is_empty() else "leer",
		data.get("name", item_id)
	])
	var condition := InventorySystem.condition_text(item_id)
	if not condition.is_empty():
		lines.append(condition)
	var changed := false
	for row in EQUIPMENT_COMPARE_ROWS:
		var key := str(row.get("key", ""))
		if old_data.has(key) or data.has(key):
			_append_stat_comparison(lines, key, str(row.get("label", key)), old_data, data)
			changed = true
	if not changed:
		lines.append("[color=#8e9aab]Keine direkten Werteveraenderungen.[/color]")
	return "\n".join(lines)


func _append_stat_comparison(lines: Array[String], key: String, label: String, old_data: Dictionary, new_data: Dictionary) -> void:
	var before := float(old_data.get(key, 0.0))
	var after := float(new_data.get(key, 0.0))
	var diff := after - before
	var marker := "[color=#8e9aab]-[/color]"
	if diff > 0.0:
		marker = "[color=#79d36b]^ +%s[/color]" % _stat_value_text(diff)
	elif diff < 0.0:
		marker = "[color=#d9685f]v %s[/color]" % _stat_value_text(diff)
	lines.append("%s: %s -> %s  %s" % [
		label,
		_stat_value_text(before),
		_stat_value_text(after),
		marker
	])


func _stat_value_text(value: float) -> String:
	if absf(value - roundf(value)) < 0.05:
		return "%d" % int(roundf(value))
	return "%.1f" % value


func _short_line(value: String, max_length: int) -> String:
	return value if value.length() <= max_length else value.substr(0, max_length - 1) + "."


func _plain_item_tooltip(item_id: String) -> String:
	var data := DataCatalog.item(item_id)
	if data.is_empty():
		return ""
	var lines: Array[String] = [
		str(data.get("name", item_id)),
		"Seltenheit: %s" % UiFactory.rarity_label(data),
		str(data.get("description", ""))
	]
	var condition := InventorySystem.condition_text(item_id)
	if not condition.is_empty():
		lines.append(condition)
	return "\n".join(lines)


func _bonus_text(data: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["damage", "armor", "shield", "strength", "dexterity", "intelligence", "vitality", "willpower", "stamina_bonus", "crafting_bonus", "infection_resist", "pocket_slots", "carry_weight_bonus", "chaos_resistance", "shadow_resistance", "light_resistance", "block_chance"]:
		if data.has(key):
			parts.append("%s +%s" % [_bonus_name(key), data[key]])
	return " / ".join(parts) if not parts.is_empty() else str(data.get("description", ""))


func _bonus_name(key: String) -> String:
	match key:
		"damage":
			return "Schaden"
		"armor":
			return "Ruestung"
		"shield":
			return "Schutz"
		"strength":
			return "STR"
		"dexterity":
			return "DEX"
		"intelligence":
			return "INT"
		"vitality":
			return "VIT"
		"willpower":
			return "WIL"
		"stamina_bonus":
			return "Ausdauer"
		"crafting_bonus":
			return "Handwerk"
		"infection_resist":
			return "Filter"
		"pocket_slots":
			return "Taschen"
		"carry_weight_bonus":
			return "Traglast"
		"chaos_resistance":
			return "Chaos"
		"shadow_resistance":
			return "Schatten"
		"light_resistance":
			return "Licht"
		"block_chance":
			return "Blocken"
	return key


func _equip(item_id: String) -> void:
	if InventorySystem.equip_item(item_id):
		feedback_label.text = "%s angelegt." % DataCatalog.item(item_id).get("name", item_id)
	_refresh()


func _unequip(slot: String) -> void:
	if InventorySystem.unequip_slot(slot):
		feedback_label.text = "Slot geleert."
	_refresh()


func _repair(item_id: String) -> void:
	if InventorySystem.repair_item(item_id):
		feedback_label.text = "%s repariert." % DataCatalog.item(item_id).get("name", item_id)
	else:
		feedback_label.text = "Reparatur nicht moeglich."
	_refresh()


func _spend(stat_name: String) -> void:
	if GameState.spend_skill_point(stat_name):
		feedback_label.text = "%s verbessert." % GameState.SKILL_UPGRADES[stat_name].get("name", stat_name)
	else:
		feedback_label.text = "Keine Skillpunkte verfuegbar."
	_refresh()


func _learn_ability(ability_id: String) -> void:
	if GameState.learn_ability(ability_id):
		feedback_label.text = "%s gelernt." % GameState.ability(ability_id).get("name", ability_id)
	else:
		feedback_label.text = "Keine Faehigkeitswahl verfuegbar."
	_refresh()


func _equip_ability(ability_id: String) -> void:
	if GameState.equip_ability(ability_id):
		feedback_label.text = "%s in die Leiste gelegt." % GameState.ability(ability_id).get("name", ability_id)
	else:
		feedback_label.text = "Die Faehigkeitenleiste ist voll."
	_refresh()


func _unequip_ability(ability_id: String) -> void:
	if GameState.unequip_ability(ability_id):
		feedback_label.text = "%s aus der Leiste genommen." % GameState.ability(ability_id).get("name", ability_id)
	_refresh()


func _return() -> void:
	go_to(GameState.return_scene if not GameState.return_scene.is_empty() else "res://scenes/world_map/world_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		accept_event()
		_return()
