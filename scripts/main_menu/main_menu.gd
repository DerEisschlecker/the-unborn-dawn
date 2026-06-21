# Purpose: Main entry screen with new game, character creation, load slots, settings, and exit.
# Public API: Starts a campaign or restores one of three save slots.
# Dependencies: GameState, SaveSystem, SettingsMenu, StorySlide.
extends Control

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const CLASS_ORDER: Array[String] = ["scout", "medic", "guardian", "tinker"]
const APPEARANCE_ORDER: Array[String] = ["wanderer", "mechanic", "medic", "guardian"]

var menu_column: VBoxContainer
var name_input: LineEdit
var selected_gender := "female"
var selected_class := "scout"
var selected_appearance := "wanderer"
var class_summary: Label
var appearance_summary: Label
var preview_texture: TextureRect
var gender_buttons: Dictionary = {}
var class_buttons: Dictionary = {}
var appearance_buttons: Dictionary = {}
var menu_title: Label
var menu_background: TextureRect
var ember_glow: ColorRect
var lightning_flash: ColorRect
var menu_panel: PanelContainer
var ash_nodes: Array[ColorRect] = []
var smoke_nodes: Array[ColorRect] = []
var menu_anim_time := 0.0
var next_lightning_at := 8.0
var lightning_alpha := 0.0
var compact_character_menu := false


func _ready() -> void:
	randomize()
	set_process(true)
	AudioManager.play_music("res://assets/audio/music/menu/menu_embers.wav", -9.0)
	_show_main_menu()


func _process(delta: float) -> void:
	menu_anim_time += delta
	_update_menu_animation(delta)
	if ash_nodes.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	for ash in ash_nodes:
		if not is_instance_valid(ash):
			continue
		var speed := float(ash.get_meta("speed", 20.0))
		var drift := float(ash.get_meta("drift", 0.0))
		ash.position += Vector2(drift, -speed) * delta
		if ash.position.y < -16.0 or ash.position.x < -24.0 or ash.position.x > viewport_size.x + 24.0:
			ash.position = Vector2(randf_range(0.0, viewport_size.x), viewport_size.y + randf_range(8.0, 120.0))
	for smoke in smoke_nodes:
		if not is_instance_valid(smoke):
			continue
		var smoke_speed := float(smoke.get_meta("speed", 10.0))
		smoke.position.x += smoke_speed * delta
		if smoke.position.x > viewport_size.x + 120.0:
			smoke.position.x = -smoke.size.x - randf_range(40.0, 180.0)


func _show_main_menu() -> void:
	menu_column = _prepare_menu_shell("LAST LIGHT", "Beschuetze Elena. Befestige die Zuflucht. Ueberlebe bis Tag 260.")
	menu_column.add_child(UiFactory.body_label("Die Sonne ist fort. In der Ferne brennt noch ein Fenster.", 22, UiFactory.COLOR_MUTED))
	menu_column.add_child(UiFactory.button("Neues Spiel", _show_character_select, 520))
	menu_column.add_child(UiFactory.button("Spiel laden", _show_load_slots, 520))
	menu_column.add_child(UiFactory.button("Einstellungen", _open_settings, 520))
	menu_column.add_child(UiFactory.button("Spiel beenden", func() -> void: get_tree().quit(), 520))
	var footer := UiFactory.body_label("Maussteuerung - I Inventar - C Ausruestung - K Level - B Crafting - ESC Pause", 16, UiFactory.COLOR_MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(footer)


func _prepare_menu_shell(title: String, subtitle: String) -> VBoxContainer:
	var compact := _compact_menu()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	ash_nodes.clear()
	smoke_nodes.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := TextureRect.new()
	background.texture = load("res://assets/environments/backgrounds/menu_ruins.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color(0.82, 0.74, 0.66, 1.0)
	background.scale = Vector2(1.03, 1.03)
	background.pivot_offset = Vector2(960, 540)
	menu_background = background
	menu_anim_time = 0.0
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.024, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	ember_glow = ColorRect.new()
	ember_glow.color = Color(0.55, 0.08, 0.02, 0.12)
	ember_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ember_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ember_glow)
	var horizon_fire := ColorRect.new()
	horizon_fire.color = Color(0.75, 0.19, 0.04, 0.13)
	horizon_fire.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	horizon_fire.offset_top = -230
	horizon_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horizon_fire)
	_spawn_ash()
	_spawn_smoke()
	lightning_flash = ColorRect.new()
	lightning_flash.color = Color(0.72, 0.82, 1.0, 0.0)
	lightning_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lightning_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lightning_flash)
	next_lightning_at = menu_anim_time + randf_range(4.0, 9.0)
	lightning_alpha = 0.0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38 if compact else 76)
	margin.add_theme_constant_override("margin_right", 38 if compact else 76)
	margin.add_theme_constant_override("margin_top", 30 if compact else 58)
	margin.add_theme_constant_override("margin_bottom", 24 if compact else 58)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(layout)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 760 if compact else 920
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8 if compact else 16)
	layout.add_child(left)
	menu_title = UiFactory.title_label(title, 44 if compact else 72)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(menu_title)
	var subtitle_label := UiFactory.body_label(subtitle, 15 if compact else 21, Color("#d8dde8"))
	subtitle_label.custom_minimum_size.x = 600 if compact else 650
	left.add_child(subtitle_label)
	if not compact:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(spacer)
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(760, 430) if compact else Vector2(900, 560)
	var panel_style := UiFactory._panel_style()
	panel_style.bg_color = Color(0.018, 0.022, 0.030, 0.88)
	panel_style.border_color = Color(0.68, 0.51, 0.28, 0.86)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 18
	if compact:
		panel_style.content_margin_left = 12
		panel_style.content_margin_right = 12
		panel_style.content_margin_top = 10
		panel_style.content_margin_bottom = 10
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	left.add_child(menu_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7 if compact else 12)
	menu_panel.add_child(column)
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(right_spacer)
	return column


func _compact_menu() -> bool:
	return UiFactory.is_compact_screen()


func _spawn_ash() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	for index in range(44):
		var ash := ColorRect.new()
		var ash_size := randf_range(2.0, 5.0)
		ash.size = Vector2(ash_size, ash_size)
		ash.position = Vector2(randf_range(0.0, viewport_size.x), randf_range(0.0, viewport_size.y))
		ash.color = Color(1.0, randf_range(0.45, 0.78), randf_range(0.22, 0.38), randf_range(0.22, 0.58))
		ash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ash.set_meta("speed", randf_range(12.0, 46.0))
		ash.set_meta("drift", randf_range(-10.0, 16.0))
		ash_nodes.append(ash)
		add_child(ash)


func _spawn_smoke() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	for index in range(9):
		var smoke := ColorRect.new()
		smoke.size = Vector2(randf_range(180.0, 420.0), randf_range(30.0, 82.0))
		smoke.position = Vector2(randf_range(-140.0, viewport_size.x), viewport_size.y - randf_range(86.0, 260.0))
		smoke.color = Color(0.04, 0.045, 0.052, randf_range(0.18, 0.34))
		smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		smoke.set_meta("speed", randf_range(6.0, 22.0))
		smoke_nodes.append(smoke)
		add_child(smoke)


func _update_menu_animation(delta: float) -> void:
	var slow_pulse := (sin(menu_anim_time * 0.45) + 1.0) * 0.5
	var ember_pulse := (sin(menu_anim_time * 2.1) + 1.0) * 0.5
	if is_instance_valid(menu_background):
		var scale_value := lerpf(1.03, 1.07, slow_pulse)
		menu_background.scale = Vector2(scale_value, scale_value)
		menu_background.position.x = sin(menu_anim_time * 0.18) * 7.0
		menu_background.position.y = cos(menu_anim_time * 0.13) * 4.0
	if is_instance_valid(ember_glow):
		ember_glow.color = Color(
			lerpf(0.20, 0.65, ember_pulse),
			lerpf(0.025, 0.10, ember_pulse),
			lerpf(0.01, 0.02, ember_pulse),
			lerpf(0.09, 0.23, ember_pulse)
		)
	if is_instance_valid(menu_title):
		menu_title.modulate = Color(
			lerpf(0.88, 1.0, ember_pulse),
			lerpf(0.76, 0.88, ember_pulse),
			lerpf(0.52, 0.58, ember_pulse),
			1.0
		)
	if is_instance_valid(menu_panel):
		menu_panel.modulate = Color(1.0, 0.96 + ember_pulse * 0.04, 0.90 + ember_pulse * 0.06, 1.0)
	if menu_anim_time >= next_lightning_at:
		_trigger_lightning()
	lightning_alpha = maxf(0.0, lightning_alpha - delta * 2.9)
	if is_instance_valid(lightning_flash):
		lightning_flash.color = Color(0.72, 0.82, 1.0, lightning_alpha)


func _trigger_lightning() -> void:
	lightning_alpha = randf_range(0.16, 0.32)
	next_lightning_at = menu_anim_time + randf_range(8.0, 16.0)
	AudioManager.play_sfx("res://assets/audio/sfx/environment/thunder.wav", -17.0, randf_range(0.82, 1.08))


func _show_character_select() -> void:
	UiFactory.clear_container(menu_column)
	compact_character_menu = _compact_menu()
	selected_gender = "female"
	selected_class = "scout"
	selected_appearance = "wanderer"
	gender_buttons.clear()
	class_buttons.clear()
	appearance_buttons.clear()
	menu_column.add_child(UiFactory.title_label("Charakter erstellen", 24 if compact_character_menu else 31))
	menu_column.add_child(UiFactory.body_label("Waehle, wer Elena durch die lange Nacht bringt.", 13 if compact_character_menu else 18, UiFactory.COLOR_MUTED))
	var creation_row := HBoxContainer.new()
	creation_row.add_theme_constant_override("separation", 16)
	menu_column.add_child(creation_row)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 5 if compact_character_menu else 10)
	creation_row.add_child(controls)
	name_input = LineEdit.new()
	name_input.text = "Morgan"
	name_input.placeholder_text = "Name"
	name_input.custom_minimum_size = Vector2(390, 36) if compact_character_menu else Vector2(500, 52)
	controls.add_child(name_input)
	var gender_row := UiFactory.horizontal_actions()
	gender_row.add_theme_constant_override("separation", 6 if compact_character_menu else 12)
	controls.add_child(gender_row)
	for gender_data in [["female", "Weiblich"], ["male", "Maennlich"]]:
		var button := UiFactory.button(str(gender_data[1]), Callable(self, "_select_gender").bind(str(gender_data[0])), 190 if compact_character_menu else 240)
		button.custom_minimum_size.y = 36 if compact_character_menu else 52
		gender_row.add_child(button)
		gender_buttons[str(gender_data[0])] = button
	var appearance_grid := GridContainer.new()
	appearance_grid.columns = 4 if compact_character_menu else 2
	appearance_grid.add_theme_constant_override("h_separation", 6 if compact_character_menu else 10)
	appearance_grid.add_theme_constant_override("v_separation", 6 if compact_character_menu else 10)
	controls.add_child(appearance_grid)
	for appearance_id in APPEARANCE_ORDER:
		var data: Dictionary = GameState.APPEARANCE_OPTIONS.get(appearance_id, {})
		var button := UiFactory.button(str(data.get("name", appearance_id)), Callable(self, "_select_appearance").bind(appearance_id), 92 if compact_character_menu else 240)
		button.custom_minimum_size.y = 36 if compact_character_menu else 52
		button.tooltip_text = str(data.get("description", ""))
		appearance_grid.add_child(button)
		appearance_buttons[appearance_id] = button
	var class_grid := GridContainer.new()
	class_grid.columns = 2
	class_grid.add_theme_constant_override("h_separation", 6 if compact_character_menu else 12)
	class_grid.add_theme_constant_override("v_separation", 6 if compact_character_menu else 12)
	controls.add_child(class_grid)
	var classes: Dictionary = _class_catalog()
	for class_id in CLASS_ORDER:
		var data: Dictionary = classes.get(class_id, {})
		var label_text := str(data.get("name", class_id)) if compact_character_menu else "%s\n%s" % [
			data.get("name", class_id),
			data.get("description", "")
		]
		var button := UiFactory.button(label_text, Callable(self, "_select_class").bind(class_id), 190 if compact_character_menu else 240)
		button.custom_minimum_size.y = 42 if compact_character_menu else 94
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = str(data.get("description", ""))
		class_grid.add_child(button)
		class_buttons[class_id] = button
	class_summary = UiFactory.body_label("", 12 if compact_character_menu else 18)
	class_summary.custom_minimum_size.y = 46 if compact_character_menu else 0
	controls.add_child(class_summary)
	var preview_panel := UiFactory.section("Vorschau")
	preview_panel.get_parent().custom_minimum_size.x = 190 if compact_character_menu else 250
	creation_row.add_child(preview_panel.get_parent())
	preview_texture = TextureRect.new()
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.custom_minimum_size = Vector2(170, 165) if compact_character_menu else Vector2(220, 260)
	preview_panel.add_child(preview_texture)
	appearance_summary = UiFactory.body_label("", 12 if compact_character_menu else 16, UiFactory.COLOR_MUTED)
	appearance_summary.custom_minimum_size.x = 160 if compact_character_menu else 220
	preview_panel.add_child(appearance_summary)
	var actions := UiFactory.horizontal_actions()
	actions.add_theme_constant_override("separation", 8 if compact_character_menu else 12)
	menu_column.add_child(actions)
	var start_button := UiFactory.button("Starten", _start_new_game, 260 if compact_character_menu else 360)
	start_button.custom_minimum_size.y = 38 if compact_character_menu else 52
	actions.add_child(start_button)
	var back_button := UiFactory.button("Zurueck", _show_main_menu, 180 if compact_character_menu else 260)
	back_button.custom_minimum_size.y = 38 if compact_character_menu else 52
	actions.add_child(back_button)
	_refresh_character_select()


func _class_catalog() -> Dictionary:
	return DataCatalog.player_config().get("classes", {})


func _select_gender(gender: String) -> void:
	selected_gender = gender
	_refresh_character_select()


func _select_class(class_id: String) -> void:
	selected_class = class_id
	_refresh_character_select()


func _select_appearance(appearance_id: String) -> void:
	selected_appearance = appearance_id
	_refresh_character_select()


func _refresh_character_select() -> void:
	for gender in gender_buttons:
		var button: Button = gender_buttons[gender]
		button.disabled = str(gender) == selected_gender
	for class_id in class_buttons:
		var button: Button = class_buttons[class_id]
		button.disabled = str(class_id) == selected_class
	for appearance_id in appearance_buttons:
		var button: Button = appearance_buttons[appearance_id]
		button.disabled = str(appearance_id) == selected_appearance
	var data: Dictionary = _class_catalog().get(selected_class, {})
	var appearance: Dictionary = GameState.APPEARANCE_OPTIONS.get(selected_appearance, {})
	var stats: Dictionary = data.get("stat_bonus", {})
	var stat_parts: Array[String] = []
	for stat_name in stats:
		stat_parts.append("%s %+d" % [_stat_display_name(str(stat_name)), int(stats[stat_name])])
	var inventory: Dictionary = data.get("starting_inventory", {})
	if compact_character_menu:
		class_summary.text = "%s | %s\n%s" % [
			data.get("name", selected_class),
			appearance.get("name", selected_appearance),
			", ".join(stat_parts) if not stat_parts.is_empty() else "keine Boni"
		]
	else:
		class_summary.text = "%s\nAussehen: %s\nWerte: %s\nStartausruestung: %s" % [
			data.get("name", selected_class),
			appearance.get("name", selected_appearance),
			", ".join(stat_parts) if not stat_parts.is_empty() else "keine Boni",
			UiFactory.cost_text(inventory) if not inventory.is_empty() else "keine Extras"
		]
	if is_instance_valid(preview_texture):
		preview_texture.texture = load(GameState.player_appearance_path(selected_gender, selected_appearance))
	if is_instance_valid(appearance_summary):
		appearance_summary.text = str(appearance.get("name", selected_appearance)) if compact_character_menu else "%s\n%s" % [
			appearance.get("name", selected_appearance),
			appearance.get("description", "")
		]


func _stat_display_name(stat_name: String) -> String:
	match stat_name:
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
		"max_health":
			return "Max LEB"
		"max_mana":
			return "Max MAN"
		"max_stamina":
			return "Max AUS"
		"max_energy":
			return "Max ENE"
		"health":
			return "LEB"
		"stamina":
			return "AUS"
		"energy":
			return "ENE"
		"melee":
			return "Nahkampf"
		"ranged":
			return "Schuss"
		"accuracy":
			return "Genauigkeit"
		"defense":
			return "Verteidigung"
		"crafting":
			return "Handwerk"
	return stat_name.replace("_", " ")


func _show_load_slots() -> void:
	UiFactory.clear_container(menu_column)
	menu_column.add_child(UiFactory.title_label("Spiel laden", 31))
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		var info := SaveSystem.slot_info(slot)
		var text := "Slot %d - Tag %d - %s" % [slot, info.get("day", 1), info.get("saved_at", "")] if info.get("exists", false) else "Slot %d - leer" % slot
		var button := UiFactory.button(text, func() -> void: _load_game(slot), 520)
		button.disabled = not info.get("exists", false)
		menu_column.add_child(button)
	menu_column.add_child(UiFactory.button("Zurueck", _show_main_menu, 520))


func _start_new_game() -> void:
	GameState.new_game(selected_gender, selected_class, name_input.text if name_input else "Morgan", selected_appearance)
	GameState.pending_story = "prologue"
	GameState.story_return_scene = "res://scenes/world_map/world_map.tscn"
	get_tree().change_scene_to_file("res://scenes/cinematics/story_slide.tscn")


func _load_game(slot: int) -> void:
	if SaveSystem.load_game(slot):
		get_tree().change_scene_to_file("res://scenes/world_map/world_map.tscn")


func _open_settings() -> void:
	var menu := SETTINGS_SCENE.instantiate()
	add_child(menu)
