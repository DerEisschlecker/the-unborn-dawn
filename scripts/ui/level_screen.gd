# Purpose: Focused level screen for passive stat points, ability unlocks, and hotbar slot assignment.
# Public API: Opened from GameplayScreen with K; click learned abilities and hotbar slots to assign 1-9.
# Dependencies: GameState, UiFactory, EventBus.
extends GameplayScreen

const AbilityDragButtonScript := preload("res://scripts/ui/ability_drag_button.gd")
const AbilityHotbarButtonScript := preload("res://scripts/ui/ability_hotbar_button.gd")
const AbilityTreeOverlayScript := preload("res://scripts/ui/ability_tree_overlay.gd")

var summary_label: Label
var feedback_label: Label
var ability_detail_label: Label
var ability_detail_icon: TextureRect
var xp_bar: ProgressBar
var skill_box: VBoxContainer
var hotbar_grid: GridContainer
var learned_box: VBoxContainer
var locked_box: VBoxContainer
var tree_overlay: Control
var selected_ability_id := ""
var preview_ability_id := ""
var compact_screen := false


func _ready() -> void:
	compact_screen = UiFactory.is_compact_screen()
	var root := setup_gameplay("LEVEL & FAEHIGKEITEN", "Passive Punkte, Hauptfaehigkeiten und Belegung der Leiste 1-9.")
	if compact_screen:
		_compact_root_typography(root)
	feedback_label = UiFactory.body_label("", 17, UiFactory.COLOR_MUTED)
	root.add_child(feedback_label)
	if compact_screen:
		_build_compact_layout(root)
	else:
		_build_wide_layout(root)
	var back := UiFactory.button("Zurueck", _return, 180 if compact_screen else 240)
	if compact_screen:
		back.custom_minimum_size.y = 36
	root.add_child(back)
	EventBus.stats_changed.connect(_refresh)
	_refresh()


func _build_wide_layout(root: VBoxContainer) -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 520
	left.add_theme_constant_override("separation", 12)
	split.add_child(left)
	var summary_panel := UiFactory.section("Charakter")
	left.add_child(summary_panel.get_parent())
	summary_label = UiFactory.body_label("", 17, Color("#d8dde8"))
	summary_panel.add_child(summary_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(420, 24)
	xp_bar.show_percentage = true
	summary_panel.add_child(xp_bar)
	var skill_panel := UiFactory.section("Passive Punkte")
	skill_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(skill_panel.get_parent())
	skill_box = VBoxContainer.new()
	skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_panel.add_child(skill_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	split.add_child(right)
	var hotbar_panel := UiFactory.section("Faehigkeitenleiste 1-9")
	right.add_child(hotbar_panel.get_parent())
	hotbar_grid = GridContainer.new()
	hotbar_grid.columns = 9
	hotbar_grid.add_theme_constant_override("h_separation", 7)
	hotbar_grid.add_theme_constant_override("v_separation", 7)
	hotbar_panel.add_child(hotbar_grid)
	var detail_panel := UiFactory.section("Ausgewaehlte Faehigkeit")
	right.add_child(detail_panel.get_parent())
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_row)
	ability_detail_icon = TextureRect.new()
	ability_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ability_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ability_detail_icon.custom_minimum_size = Vector2(58, 58)
	detail_row.add_child(ability_detail_icon)
	ability_detail_label = UiFactory.body_label("", 15, Color("#d8dde8"))
	ability_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_child(ability_detail_label)
	var tree_panel := UiFactory.section("Faehigkeitsbaum")
	tree_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(tree_panel.get_parent())
	tree_overlay = AbilityTreeOverlayScript.new()
	tree_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_overlay.ability_selected.connect(_select_ability)
	tree_overlay.ability_previewed.connect(_preview_ability)
	tree_overlay.learn_requested.connect(_learn_ability)
	tree_panel.add_child(tree_overlay)


func _build_compact_layout(root: VBoxContainer) -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 12)
	root.add_child(tabs)

	var points_page := HSplitContainer.new()
	points_page.name = "Punkte"
	points_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(points_page)
	var summary_panel := UiFactory.section("Charakter")
	_tighten_section_box(summary_panel)
	summary_panel.get_parent().custom_minimum_size.x = 280
	points_page.add_child(summary_panel.get_parent())
	summary_label = UiFactory.body_label("", 12, Color("#d8dde8"))
	summary_panel.add_child(summary_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(250, 16)
	xp_bar.show_percentage = true
	summary_panel.add_child(xp_bar)
	var skill_panel := UiFactory.section("Passive Punkte")
	_tighten_section_box(skill_panel)
	skill_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	points_page.add_child(skill_panel.get_parent())
	skill_box = VBoxContainer.new()
	skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_panel.add_child(skill_box)

	var bar_page := VBoxContainer.new()
	bar_page.name = "Leiste"
	bar_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_page.add_theme_constant_override("separation", 8)
	tabs.add_child(bar_page)
	var hotbar_panel := UiFactory.section("Faehigkeitenleiste 1-9")
	_tighten_section_box(hotbar_panel)
	bar_page.add_child(hotbar_panel.get_parent())
	hotbar_grid = GridContainer.new()
	hotbar_grid.columns = 9
	hotbar_grid.add_theme_constant_override("h_separation", 5)
	hotbar_grid.add_theme_constant_override("v_separation", 5)
	hotbar_panel.add_child(hotbar_grid)
	var detail_panel := UiFactory.section("Ausgewaehlte Faehigkeit")
	_tighten_section_box(detail_panel)
	bar_page.add_child(detail_panel.get_parent())
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_row)
	ability_detail_icon = TextureRect.new()
	ability_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ability_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ability_detail_icon.custom_minimum_size = Vector2(42, 42)
	detail_row.add_child(ability_detail_icon)
	ability_detail_label = UiFactory.body_label("", 12, Color("#d8dde8"))
	ability_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_child(ability_detail_label)

	var tree_page := VBoxContainer.new()
	tree_page.name = "Baum"
	tree_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(tree_page)
	var tree_panel := UiFactory.section("Faehigkeitsbaum")
	_tighten_section_box(tree_panel)
	tree_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_page.add_child(tree_panel.get_parent())
	tree_overlay = AbilityTreeOverlayScript.new()
	tree_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_overlay.ability_selected.connect(_select_ability)
	tree_overlay.ability_previewed.connect(_preview_ability)
	tree_overlay.learn_requested.connect(_learn_ability)
	tree_panel.add_child(tree_overlay)
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		_sync_tab_pages(tabs, tab_index)
	)
	call_deferred("_sync_tab_pages", tabs, 0)


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


func _sync_tab_pages(tabs: TabContainer, tab_index: int) -> void:
	if not is_instance_valid(tabs):
		return
	for index in range(tabs.get_child_count()):
		var child := tabs.get_child(index) as Control
		if child:
			child.visible = index == tab_index


func _refresh() -> void:
	_refresh_summary()
	_refresh_skills()
	_refresh_hotbar()
	_refresh_ability_detail()
	_refresh_abilities()


func _refresh_summary() -> void:
	var effective := GameState.effective_player_stats()
	if compact_screen:
		summary_label.text = "%s - %s\nLvl %d | Punkte %d | Wahl %d\nNext: %s\nSTR %.0f DEX %.0f INT %.0f\nVIT %.0f WIL %.0f | AP %d/%d" % [
			GameState.player_name,
			GameState.player_class_name(),
			int(GameState.player_stats.get("level", 1)),
			int(GameState.player_stats.get("skill_points", 0)),
			GameState.pending_ability_picks,
			_next_unlock_text(),
			float(effective.get("strength", 0.0)),
			float(effective.get("dexterity", 0.0)),
			float(effective.get("intelligence", 0.0)),
			float(effective.get("vitality", 0.0)),
			float(effective.get("willpower", 0.0)),
			GameState.equipped_ability_count(),
			GameState.MAX_EQUIPPED_ABILITIES
		]
		xp_bar.max_value = float(GameState.player_stats.get("next_xp", 60))
		xp_bar.value = float(GameState.player_stats.get("xp", 0))
		xp_bar.tooltip_text = "Erfahrung: %d / %d" % [
			int(GameState.player_stats.get("xp", 0)),
			int(GameState.player_stats.get("next_xp", 60))
		]
		return
	summary_label.text = "%s - %s\nLevel %d   Passive Punkte %d   Faehigkeitswahl %d\nNaechste Freischaltung: %s\nSTR %.0f  DEX %.0f  INT %.0f  VIT %.0f  WIL %.0f\nPraezision %.0f  Ausweichen %.0f  Krit %.0f%%  AP-Leiste %d/%d" % [
		GameState.player_name,
		GameState.player_class_name(),
		int(GameState.player_stats.get("level", 1)),
		int(GameState.player_stats.get("skill_points", 0)),
		GameState.pending_ability_picks,
		_next_unlock_text(),
		float(effective.get("strength", 0.0)),
		float(effective.get("dexterity", 0.0)),
		float(effective.get("intelligence", 0.0)),
		float(effective.get("vitality", 0.0)),
		float(effective.get("willpower", 0.0)),
		float(effective.get("precision", 0.0)),
		float(effective.get("evasion", 0.0)),
		float(effective.get("critical_chance", 0.0)),
		GameState.equipped_ability_count(),
		GameState.MAX_EQUIPPED_ABILITIES
	]
	xp_bar.max_value = float(GameState.player_stats.get("next_xp", 60))
	xp_bar.value = float(GameState.player_stats.get("xp", 0))
	xp_bar.tooltip_text = "Erfahrung: %d / %d" % [
		int(GameState.player_stats.get("xp", 0)),
		int(GameState.player_stats.get("next_xp", 60))
	]


func _refresh_skills() -> void:
	UiFactory.clear_container(skill_box)
	var points := int(GameState.player_stats.get("skill_points", 0))
	skill_box.add_child(UiFactory.body_label("Verfuegbar: %d" % points, 13 if compact_screen else 17, UiFactory.COLOR_GOLD))
	if compact_screen:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 5)
		skill_box.add_child(grid)
		for group in [
			["strength", "dexterity", "intelligence", "vitality", "willpower"],
			["accuracy", "melee", "ranged", "defense", "crafting"],
			["max_health", "max_mana", "max_stamina", "max_energy", "critical_chance", "armor_pierce", "control_resist"]
		]:
			for stat_name in group:
				grid.add_child(_skill_row(stat_name, points))
		return
	for group in [
		["strength", "dexterity", "intelligence", "vitality", "willpower"],
		["accuracy", "melee", "ranged", "defense", "crafting"],
		["max_health", "max_mana", "max_stamina", "max_energy", "critical_chance", "armor_pierce", "control_resist"]
	]:
		for stat_name in group:
			skill_box.add_child(_skill_row(stat_name, points))


func _skill_row(stat_name: String, points: int) -> Control:
	var data: Dictionary = GameState.SKILL_UPGRADES[stat_name]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5 if compact_screen else 8)
	row.custom_minimum_size = Vector2(205, 26) if compact_screen else Vector2.ZERO
	var label := UiFactory.body_label("%s +%s" % [data.get("name", stat_name), data.get("amount", 1)], 10 if compact_screen else 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.tooltip_text = str(data.get("name", stat_name))
	row.add_child(label)
	var value := UiFactory.body_label("%.0f" % float(GameState.player_stats.get(stat_name, 0.0)), 10 if compact_screen else 15, UiFactory.COLOR_GOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 30 if compact_screen else 54
	row.add_child(value)
	var button := UiFactory.button("+", func() -> void: _spend(stat_name), 34 if compact_screen else 58)
	button.custom_minimum_size.y = 26 if compact_screen else 52
	button.disabled = points <= 0
	row.add_child(button)
	return row


func _refresh_hotbar() -> void:
	UiFactory.clear_container(hotbar_grid)
	for index in range(GameState.MAX_EQUIPPED_ABILITIES):
		hotbar_grid.add_child(_hotbar_slot(index))


func _hotbar_slot(index: int) -> Button:
	var ability_id := GameState.ability_slot_id(index)
	var data := GameState.ability(ability_id)
	var label := "%d\nLeer" % (index + 1)
	if not data.is_empty():
		label = "%d\n%s\n%s" % [index + 1, data.get("name", ability_id), _short_cost_text(ability_id, data)]
	var button = AbilityHotbarButtonScript.new()
	button.text = label
	button.custom_minimum_size = Vector2(80, 58) if compact_screen else Vector2(92, 72)
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -7.0)
		_hotbar_clicked(index)
	)
	button.configure_hotbar(ability_id, index, not ability_id.is_empty(), str(data.get("name", ability_id)))
	button.ability_dropped.connect(_ability_dropped_on_slot)
	button.tooltip_text = "Leerer Slot. Ziehe eine gelernte Faehigkeit hierher." if ability_id.is_empty() else GameState.ability_tooltip_text(ability_id) + "\nZiehen: auf anderen Slot legen\nLinksklick: aufnehmen/tauschen\nRechtsklick: Slot leeren"
	if not data.is_empty():
		var texture := load(str(data.get("icon", ""))) as Texture2D
		if texture:
			button.icon = texture
			button.expand_icon = true
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			button.accept_event()
			_clear_hotbar_slot(index)
	)
	return button


func _refresh_abilities() -> void:
	if is_instance_valid(tree_overlay):
		tree_overlay.refresh_tree(selected_ability_id)


func _refresh_ability_detail() -> void:
	if not is_instance_valid(ability_detail_label) or not is_instance_valid(ability_detail_icon):
		return
	var ability_id := selected_ability_id
	if ability_id.is_empty() and not preview_ability_id.is_empty():
		ability_id = preview_ability_id
	if ability_id.is_empty() and not GameState.equipped_abilities.is_empty():
		ability_id = GameState.ability_slot_id(0)
	var data := GameState.ability(ability_id)
	if data.is_empty():
		ability_detail_icon.texture = null
		ability_detail_label.text = "Waehle eine gelernte Faehigkeit oder ziehe sie direkt auf einen Slot."
		return
	ability_detail_icon.texture = load(str(data.get("icon", "res://assets/ui/icons/energy.svg")))
	var learned := GameState.learned_abilities.has(ability_id)
	var equipped_slot := GameState.equipped_abilities.find(ability_id)
	var status := "Gelernt" if learned else "Nicht gelernt"
	if not learned and GameState.ability_unlocked_for_level(ability_id) and GameState.pending_ability_picks > 0:
		status = "Kann gelernt werden"
	elif not learned:
		status = "Gesperrt"
	if equipped_slot >= 0:
		status += " | Taste %d" % (equipped_slot + 1)
	if compact_screen:
		ability_detail_label.text = "%s\n%s | Level %d | %s" % [
			data.get("name", ability_id),
			status,
			GameState.ability_unlock_level(ability_id),
			_short_cost_text(ability_id, data)
		]
		ability_detail_label.tooltip_text = GameState.ability_tooltip_text(ability_id)
		return
	ability_detail_label.text = "%s\n%s | Freischaltung Level %d\n%s\n%s" % [
		data.get("name", ability_id),
		status,
		GameState.ability_unlock_level(ability_id),
		data.get("description", ""),
		_short_cost_text(ability_id, data)
	]


func _ability_card(data: Dictionary) -> PanelContainer:
	var ability_id := str(data.get("id", ""))
	var learned := GameState.learned_abilities.has(ability_id)
	var unlocked := GameState.ability_unlocked_for_level(ability_id)
	var selected := selected_ability_id == ability_id
	var panel := PanelContainer.new()
	var style := UiFactory._panel_style()
	style.bg_color = Color(0.09, 0.10, 0.12, 0.92) if selected else Color(0.045, 0.055, 0.072, 0.84)
	style.border_color = Color(str(data.get("color", "#d8b36a"))) if selected else Color(0.38, 0.43, 0.50, 0.75)
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = GameState.ability_tooltip_text(ability_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://assets/ui/icons/energy.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(46, 46)
	row.add_child(icon)
	var text := "%s%s\n%s\n%s" % [
		data.get("name", ability_id),
		"  [gewaehlt]" if selected else ("  [gelernt]" if learned else ""),
		data.get("description", ""),
		"Level %d  |  %s" % [GameState.ability_unlock_level(ability_id), _short_cost_text(ability_id, data)]
	]
	var label := UiFactory.body_label(text, 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button_text := "Auswaehlen"
	var callback := func() -> void: _select_ability(ability_id)
	if not learned:
		button_text = "Lernen"
		callback = func() -> void: _learn_ability(ability_id)
	var button
	if learned:
		button = AbilityDragButtonScript.new()
		button.text = button_text
		button.custom_minimum_size = Vector2(126, 52)
		button.pressed.connect(func() -> void:
			AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -7.0)
			callback.call()
		)
		button.configure_drag(ability_id, -1, true, str(data.get("name", ability_id)))
	else:
		button = UiFactory.button(button_text, callback, 126)
	button.disabled = (not learned and (not unlocked or GameState.pending_ability_picks <= 0))
	if not learned and not unlocked:
		button.text = "Level %d" % GameState.ability_unlock_level(ability_id)
	row.add_child(button)
	return panel


func _short_cost_text(ability_id: String, data: Dictionary) -> String:
	var parts: Array[String] = ["AP %d" % GameState.ability_action_points(ability_id), "CD %d" % GameState.ability_cooldown(ability_id)]
	if float(data.get("stamina_cost", 0.0)) > 0.0:
		parts.append("AUS %.0f" % float(data.get("stamina_cost", 0.0)))
	if float(data.get("energy_cost", 0.0)) > 0.0:
		parts.append("ENE %.0f" % float(data.get("energy_cost", 0.0)))
	return " / ".join(parts)


func _next_unlock_text() -> String:
	var level := int(GameState.player_stats.get("level", 1))
	for unlock_level in GameState.ABILITY_UNLOCK_LEVELS:
		if level < unlock_level:
			return "Level %d" % unlock_level
	return "alle Wahllevel erreicht"


func _select_ability(ability_id: String) -> void:
	if not GameState.learned_abilities.has(ability_id):
		feedback_label.text = "Diese Faehigkeit muss zuerst gelernt werden."
		preview_ability_id = ability_id
		_refresh_ability_detail()
		return
	selected_ability_id = ability_id
	preview_ability_id = ""
	feedback_label.text = "%s ausgewaehlt. Klicke einen Slot 1-9, um sie dort abzulegen." % GameState.ability(ability_id).get("name", ability_id)
	_refresh()


func _preview_ability(ability_id: String) -> void:
	if ability_id == selected_ability_id:
		return
	preview_ability_id = ability_id
	_refresh_ability_detail()


func _hotbar_clicked(index: int) -> void:
	var current := GameState.ability_slot_id(index)
	if not selected_ability_id.is_empty():
		if GameState.set_ability_slot(selected_ability_id, index):
			feedback_label.text = "%s liegt jetzt auf Taste %d." % [GameState.ability(selected_ability_id).get("name", selected_ability_id), index + 1]
			selected_ability_id = ""
		else:
			feedback_label.text = "Dieser Slot kann gerade nicht belegt werden."
		_refresh()
		return
	if current.is_empty():
		feedback_label.text = "Waehle zuerst eine gelernte Faehigkeit."
	else:
		selected_ability_id = current
		feedback_label.text = "%s aufgenommen. Klicke einen Zielslot zum Tauschen." % GameState.ability(current).get("name", current)
	_refresh()


func _ability_dropped_on_slot(ability_id: String, index: int) -> void:
	if GameState.set_ability_slot(ability_id, index):
		feedback_label.text = "%s liegt jetzt auf Taste %d." % [GameState.ability(ability_id).get("name", ability_id), index + 1]
		selected_ability_id = ""
	else:
		feedback_label.text = "Diese Faehigkeit kann hier nicht abgelegt werden."
	_refresh()


func _clear_hotbar_slot(index: int) -> void:
	if GameState.clear_ability_slot(index):
		feedback_label.text = "Slot %d geleert." % (index + 1)
		selected_ability_id = ""
	_refresh()


func _spend(stat_name: String) -> void:
	if GameState.spend_skill_point(stat_name):
		feedback_label.text = "%s verbessert." % GameState.SKILL_UPGRADES[stat_name].get("name", stat_name)
	else:
		feedback_label.text = "Keine passiven Punkte verfuegbar."
	_refresh()


func _learn_ability(ability_id: String) -> void:
	if GameState.learn_ability(ability_id):
		selected_ability_id = ability_id
		feedback_label.text = "%s gelernt. Klicke einen Slot 1-9, wenn du sie umlegen willst." % GameState.ability(ability_id).get("name", ability_id)
	else:
		feedback_label.text = "Diese Faehigkeit ist noch nicht verfuegbar."
	_refresh()


func _return() -> void:
	go_to(GameState.return_scene if not GameState.return_scene.is_empty() else "res://scenes/world_map/world_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		accept_event()
		_return()
