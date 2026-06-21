# Purpose: Turn-based combat with visible active actor, class ability, equipment-aware attacks, sounds, animation, and loot return.
# Public API: Player actions resolve one turn, then the enemy visibly takes its turn.
# Dependencies: DataCatalog, GameState, InventorySystem, TimeSystem.
extends GameplayScreen

const PLAYER_ACTION_POINTS_PER_TURN := 4
const ATTACK_AP_COST := 2
const DEFEND_AP_COST := 1
const BANDAGE_AP_COST := 2
const FLEE_AP_COST := 4
const MIN_SUCCESS_CHANCE := 0.18
const MAX_SUCCESS_CHANCE := 0.95
const LOOT_STAT_ROWS := [
	{"key": "damage", "label": "Schaden"},
	{"key": "armor", "label": "Ruestung"},
	{"key": "shield", "label": "Schutz"},
	{"key": "stamina_bonus", "label": "Ausdauer"},
	{"key": "max_stamina_bonus", "label": "Max Ausdauer"},
	{"key": "accuracy", "label": "Genauigkeit"},
	{"key": "crafting_bonus", "label": "Handwerk"},
	{"key": "infection_resist", "label": "Filter"},
	{"key": "capacity_slots", "label": "Plaetze"},
	{"key": "max_weight", "label": "Traglast"}
]

var enemy_id: String
var enemy: Dictionary
var enemy_max_health: float
var enemy_health: float
var turn := 1
var turn_state := "player"
var player_action_points := PLAYER_ACTION_POINTS_PER_TURN
var ability_cooldowns: Dictionary = {}
var defending := false
var defense_multiplier := 1.0
var enemy_art_path := ""
var player_art_path := ""
var enemy_label: Label
var player_label: Label
var log_label: Label
var turn_label: Label
var round_label: Label
var actor_summary_label: Label
var combat_stats_label: Label
var active_avatar: TextureRect
var attack_button: Button
var defend_button: Button
var bandage_button: Button
var flee_button: Button
var player_art: TextureRect
var enemy_art: TextureRect
var player_weapon_art: TextureRect
var combat_effect_layer: Control
var player_health_bar: ProgressBar
var enemy_health_bar: ProgressBar
var player_turn_badge: Label
var enemy_turn_badge: Label
var backpack_grid: GridContainer
var backpack_status_label: Label
var equipment_grid: GridContainer
var ability_bar: GridContainer
var ability_buttons: Dictionary = {}
var player_stat_bars: Dictionary = {}
var combat_anim_time := 0.0
var action_buttons: Array[Button] = []
var enemy_loot: Dictionary = {}
var loot_overlay: Control
var loot_feedback_label: Label
var loot_backpack_status_label: Label
var loot_slot_bar: ProgressBar
var loot_slot_value_label: Label
var loot_weight_bar: ProgressBar
var loot_weight_value_label: Label
var player_loot_grid: GridContainer
var enemy_loot_grid: VBoxContainer
var loot_compare_label: RichTextLabel
var skip_turn_confirm: Control


func _ready() -> void:
	AudioManager.play_music("res://assets/audio/music/combat/hold_the_line.wav", -7.0)
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -5.0, 0.92)
	enemy_id = str(GameState.quest_flags.get("current_enemy", "demon_basic"))
	enemy = DataCatalog.enemy(enemy_id)
	enemy_max_health = (float(enemy.get("health", 30)) + TimeSystem.current_day * 0.18) * TimeSystem.enemy_strength_multiplier()
	enemy_health = enemy_max_health
	player_art_path = GameState.player_appearance_path()
	enemy_art_path = "res://assets/enemies/%s/%s.svg" % [enemy_id, enemy_id]
	var root := _setup_combat_screen()
	_build_arena(root)
	_build_bottom_overlay(root)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.stats_changed.connect(_refresh)
	set_process(true)
	_begin_player_turn()


func _process(delta: float) -> void:
	combat_anim_time += delta
	_update_combat_idle()


func _setup_combat_screen() -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var location := DataCatalog.location(GameState.current_location)
	var background_path := str(location.get("background", "res://assets/environments/backgrounds/menu_ruins.png"))
	var background := TextureRect.new()
	background.texture = load(background_path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = TimeSystem.scene_light_color()
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.022, 0.42 + (1.0 - TimeSystem.light_multiplier()) * 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var top_vignette := ColorRect.new()
	top_vignette.color = Color(0, 0, 0, 0.50)
	top_vignette.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_vignette.offset_bottom = 96
	top_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_vignette)
	var bottom_vignette := ColorRect.new()
	bottom_vignette.color = Color(0, 0, 0, 0.70)
	bottom_vignette.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_vignette.offset_top = -356
	bottom_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_vignette)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	content = root
	combat_effect_layer = Control.new()
	combat_effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combat_effect_layer)
	return root


func _build_arena(root: VBoxContainer) -> void:
	var round_strip := HBoxContainer.new()
	round_strip.add_theme_constant_override("separation", 14)
	root.add_child(round_strip)
	var left_title := UiFactory.body_label("KAMPF", 17, UiFactory.COLOR_GOLD)
	left_title.custom_minimum_size.x = 140
	round_strip.add_child(left_title)
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_strip.add_child(line)
	round_label = UiFactory.body_label("RUNDE %d" % turn, 18, UiFactory.COLOR_GOLD)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.custom_minimum_size.x = 128
	round_strip.add_child(round_label)
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 28)
	root.add_child(arena)
	arena.add_child(_stage_side(
		GameState.player_name.to_upper(),
		"#263746",
		player_art_path,
		"player"
	))
	var center := Control.new()
	center.custom_minimum_size.x = 60
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.add_child(center)
	arena.add_child(_stage_side(
		str(enemy.get("name", "FEIND")).to_upper(),
		str(enemy.get("color", "#8b3e3e")),
		enemy_art_path,
		"enemy"
	))


func _stage_side(text: String, color: String, texture_path: String, role: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(spacer)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(420, 380)
	wrapper.add_child(stage)
	var glow := ColorRect.new()
	var glow_color := Color(color)
	glow_color.a = 0.24
	glow.color = glow_color
	glow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	glow.offset_left = 24
	glow.offset_right = -24
	glow.offset_top = -126
	glow.offset_bottom = -18
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	var art := TextureRect.new()
	art.texture = load(texture_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_top = 8
	art.offset_bottom = -44
	art.modulate = Color(1, 1, 1, 0.95)
	art.pivot_offset = Vector2(210, 190)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)
	if role == "player":
		player_art = art
		_add_player_weapon_art(stage)
	elif role == "enemy":
		enemy_art = art
	var nameplate := Label.new()
	nameplate.text = text
	nameplate.add_theme_font_size_override("font_size", 24)
	nameplate.add_theme_color_override("font_color", UiFactory.COLOR_GOLD if role == "player" else UiFactory.COLOR_DANGER)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nameplate.offset_left = 36
	nameplate.offset_right = -36
	nameplate.offset_top = -84
	nameplate.offset_bottom = -52
	stage.add_child(nameplate)
	var badge := UiFactory.body_label("", 15, UiFactory.COLOR_GOLD)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	badge.offset_left = 70
	badge.offset_right = -70
	badge.offset_top = 18
	badge.offset_bottom = 44
	stage.add_child(badge)
	var health_bar := ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	health_bar.offset_left = 70
	health_bar.offset_right = -70
	health_bar.offset_top = -44
	health_bar.offset_bottom = -20
	stage.add_child(health_bar)
	var label := UiFactory.body_label("", 15, Color("#d8dde8"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 24
	label.offset_right = -24
	label.offset_top = -18
	label.offset_bottom = 18
	stage.add_child(label)
	if role == "player":
		player_health_bar = health_bar
		player_turn_badge = badge
		player_label = label
	elif role == "enemy":
		enemy_health_bar = health_bar
		enemy_turn_badge = badge
		enemy_label = label
	return wrapper


func _build_bottom_overlay(root: VBoxContainer) -> void:
	var overlay := PanelContainer.new()
	overlay.custom_minimum_size.y = 350
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UiFactory._panel_style()
	style.bg_color = Color(0.015, 0.018, 0.023, 0.92)
	style.border_color = Color(0.50, 0.42, 0.28, 0.86)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	overlay.add_theme_stylebox_override("panel", style)
	root.add_child(overlay)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	overlay.add_child(row)
	_build_actor_card(row)
	_build_backpack_panel(row)
	_build_turn_panel(row)


func _build_actor_card(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var portrait := TextureRect.new()
	portrait.texture = load(player_art_path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(86, 86)
	header.add_child(portrait)
	var header_right := VBoxContainer.new()
	header_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_right.add_theme_constant_override("separation", 5)
	header.add_child(header_right)
	actor_summary_label = UiFactory.body_label("", 17, Color("#d8dde8"))
	actor_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_right.add_child(actor_summary_label)
	_add_resource_bar(header_right, "health", "Leben", Color("#b72f2d"))
	_add_resource_bar(header_right, "stamina", "Ausdauer", Color("#d09b3d"))
	_add_resource_bar(header_right, "ap", "Aktionspunkte", Color("#58a6ff"))
	_add_resource_bar(header_right, "xp", "Erfahrung", Color("#7ccf6b"))
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	box.add_child(detail_row)
	combat_stats_label = UiFactory.body_label("", 14, Color("#d8dde8"))
	combat_stats_label.custom_minimum_size.x = 190
	detail_row.add_child(combat_stats_label)
	equipment_grid = GridContainer.new()
	equipment_grid.columns = 6
	equipment_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_grid.add_theme_constant_override("h_separation", 5)
	equipment_grid.add_theme_constant_override("v_separation", 5)
	detail_row.add_child(equipment_grid)
	_build_action_buttons(box)


func _build_action_buttons(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	attack_button = UiFactory.button("Angreifen (%d AP)" % ATTACK_AP_COST, _attack, 190)
	grid.add_child(attack_button)
	action_buttons.append(attack_button)
	defend_button = UiFactory.button("Verteidigen (%d AP)" % DEFEND_AP_COST, _defend, 190)
	grid.add_child(defend_button)
	action_buttons.append(defend_button)
	bandage_button = UiFactory.button("Bandage (%d AP)" % BANDAGE_AP_COST, _use_bandage, 190)
	grid.add_child(bandage_button)
	action_buttons.append(bandage_button)
	flee_button = UiFactory.button("Fliehen (%d AP)" % FLEE_AP_COST, _flee, 190)
	grid.add_child(flee_button)
	action_buttons.append(flee_button)


func _add_resource_bar(parent: VBoxContainer, key: String, title: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := UiFactory.body_label(title, 12, UiFactory.COLOR_MUTED)
	label.custom_minimum_size.x = 86
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var value_label := UiFactory.body_label("", 12, Color("#d8dde8"))
	value_label.custom_minimum_size.x = 72
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(210, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.04, 0.048, 0.95)
	background.border_color = Color(0.32, 0.28, 0.22, 0.8)
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	row.add_child(bar)
	player_stat_bars[key] = {"bar": bar, "label": value_label, "color": color}


func _set_resource_bar(key: String, value: float, maximum: float, text: String) -> void:
	if not player_stat_bars.has(key):
		return
	var entry: Dictionary = player_stat_bars[key]
	var bar := entry.get("bar") as ProgressBar
	var label := entry.get("label") as Label
	if not is_instance_valid(bar) or not is_instance_valid(label):
		return
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(value, 0.0, maxf(1.0, maximum))
	label.text = text


func _pulse_resource_bar(key: String) -> void:
	if not player_stat_bars.has(key):
		return
	var bar := player_stat_bars[key].get("bar") as ProgressBar
	if not is_instance_valid(bar):
		return
	var tween := create_tween()
	tween.tween_property(bar, "scale", Vector2(1.018, 1.28), 0.07)
	tween.tween_property(bar, "scale", Vector2.ONE, 0.12)


func _build_backpack_panel(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var backpack_icon := TextureRect.new()
	var backpack := InventorySystem.backpack_data()
	backpack_icon.texture = load(str(backpack.get("icon", "res://assets/items/backpacks/small_backpack.svg")))
	backpack_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backpack_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	backpack_icon.custom_minimum_size = Vector2(42, 42)
	header.add_child(backpack_icon)
	backpack_status_label = UiFactory.body_label("", 16, UiFactory.COLOR_GOLD)
	backpack_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(backpack_status_label)
	backpack_grid = GridContainer.new()
	backpack_grid.columns = 8
	backpack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_grid.add_theme_constant_override("h_separation", 6)
	backpack_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(backpack_grid)
	ability_bar = GridContainer.new()
	ability_bar.columns = 9
	ability_bar.add_theme_constant_override("h_separation", 6)
	ability_bar.add_theme_constant_override("v_separation", 6)
	box.add_child(ability_bar)


func _build_turn_panel(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 430
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	active_avatar = TextureRect.new()
	active_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	active_avatar.custom_minimum_size = Vector2(78, 78)
	row.add_child(active_avatar)
	turn_label = UiFactory.title_label("", 23)
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(turn_label)
	log_label = UiFactory.body_label("Der %s tritt aus dem Schatten." % enemy.get("name", "Gegner"), 17)
	log_label.custom_minimum_size.y = 112
	box.add_child(log_label)


func _refresh_backpack_overlay() -> void:
	if not is_instance_valid(backpack_grid):
		return
	var backpack := InventorySystem.backpack_data()
	backpack_status_label.text = "Schnellzugriff aus %s  %d/%d Plaetze  %.1f/%.1f kg" % [
		backpack.get("name", "Rucksack"),
		InventorySystem.used_slots(),
		InventorySystem.slot_capacity,
		InventorySystem.current_weight(),
		InventorySystem.max_weight
	]
	UiFactory.clear_container(backpack_grid)
	var item_ids := InventorySystem.quick_slot_items()
	var visible_slots := InventorySystem.QUICK_SLOT_COUNT
	backpack_grid.columns = visible_slots
	for index in range(visible_slots):
		var slot := _combat_slot_frame(index)
		if index < item_ids.size() and not str(item_ids[index]).is_empty():
			_fill_combat_slot(slot, str(item_ids[index]))
		backpack_grid.add_child(slot)
	_refresh_ability_bar()
	_refresh_player_weapon_art()


func _refresh_actor_overlay() -> void:
	if is_instance_valid(actor_summary_label):
		actor_summary_label.text = "%s\n%s  Level %d" % [
			GameState.player_name,
			GameState.player_class_name(),
			int(GameState.player_stats.get("level", 1))
		]
	var effective := GameState.effective_player_stats()
	var health := float(GameState.player_stats.get("health", 0.0))
	var max_health := float(effective.get("max_health", 100.0))
	var stamina := float(GameState.player_stats.get("stamina", 0.0))
	var max_stamina := float(effective.get("max_stamina", 100.0))
	var xp := float(GameState.player_stats.get("xp", 0.0))
	var next_xp := float(GameState.player_stats.get("next_xp", 60.0))
	_set_resource_bar("health", health, max_health, "%.0f/%.0f" % [health, max_health])
	_set_resource_bar("stamina", stamina, max_stamina, "%.0f/%.0f" % [stamina, max_stamina])
	_set_resource_bar("ap", float(player_action_points), float(PLAYER_ACTION_POINTS_PER_TURN), "%d/%d" % [player_action_points, PLAYER_ACTION_POINTS_PER_TURN])
	_set_resource_bar("xp", xp, next_xp, "%d/%d" % [int(xp), int(next_xp)])
	if is_instance_valid(combat_stats_label):
		var base_hit := _success_chance("ranged" if not InventorySystem.preferred_weapon().is_empty() and not str(DataCatalog.item(InventorySystem.preferred_weapon()).get("ammo", "")).is_empty() else "melee")
		combat_stats_label.text = "STR %.0f  DEX %.0f\nGEN  %.0f\nTRF  %s\nSCH  %.0f\nAUSW %.0f\nPROT %.0f\nTEM  %.0f" % [
			float(effective.get("strength", 0.0)),
			float(effective.get("dexterity", 0.0)),
			float(effective.get("precision", 0.0)),
			_chance_text(base_hit),
			_player_damage_preview(),
			float(effective.get("evasion", 0.0)),
			InventorySystem.armor_value(),
			float(GameState.player_stats.get("stamina", 0.0)) / 20.0
		]
	_refresh_equipment_grid()


func _refresh_equipment_grid() -> void:
	if not is_instance_valid(equipment_grid):
		return
	UiFactory.clear_container(equipment_grid)
	for slot in ["firearm", "melee", "tool", "throwable", "head", "vest", "jacket", "pants", "gloves", "shoes", "mask"]:
		equipment_grid.add_child(_equipment_slot_frame(slot))


func _equipment_slot_frame(slot: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.028, 0.034, 0.9)
	style.border_color = Color(0.45, 0.38, 0.27, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var item_id := InventorySystem.equipped_item(slot)
	var slot_name := str(InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot))
	if item_id.is_empty():
		panel.tooltip_text = "%s: leer" % slot_name
		var empty := UiFactory.body_label(slot_name.substr(0, 2).to_upper(), 11, UiFactory.COLOR_MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(empty)
		return panel
	var data := DataCatalog.item(item_id)
	UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.025, 0.028, 0.034, 0.9), 3)
	UiFactory.attach_item_tooltip(panel, item_id, 1, -1, slot_name)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return panel


func _player_damage_preview() -> float:
	var weapon_id := InventorySystem.preferred_weapon()
	var data := DataCatalog.item(weapon_id)
	if data.is_empty():
		return 5.0 + float(GameState.effective_player_stats().get("melee_power", 0.0))
	var ranged := not str(data.get("ammo", "")).is_empty()
	var effective := GameState.effective_player_stats()
	return float(data.get("damage", 0.0)) + float(effective.get("ranged_power" if ranged else "melee_power", 0.0)) + InventorySystem.total_equipment_bonus("damage_bonus")


func _refresh_ability_bar() -> void:
	if not is_instance_valid(ability_bar):
		return
	UiFactory.clear_container(ability_bar)
	ability_buttons.clear()
	for index in range(GameState.MAX_EQUIPPED_ABILITIES):
		var ability_id := ""
		if index < GameState.equipped_abilities.size():
			ability_id = str(GameState.equipped_abilities[index])
		ability_bar.add_child(_ability_slot_button(index, ability_id))


func _ability_slot_button(index: int, ability_id: String) -> Button:
	var data := GameState.ability(ability_id)
	var label := "%d" % (index + 1)
	if not data.is_empty():
		var cooldown_left := int(ability_cooldowns.get(ability_id, 0))
		label = "%d\n%s" % [index + 1, str(data.get("name", ability_id))]
		if cooldown_left > 0:
			label += "\nCD %d" % cooldown_left
	var button := UiFactory.button(label, func() -> void: _use_hotbar_ability(index), 82)
	button.custom_minimum_size = Vector2(82, 60)
	button.tooltip_text = _ability_tooltip_with_state(ability_id) if not ability_id.is_empty() else "Leerer Faehigkeitsslot"
	button.disabled = ability_id.is_empty() or turn_state != "player" or not _can_pay_ability(ability_id)
	if not data.is_empty():
		var texture := load(str(data.get("icon", ""))) as Texture2D
		if texture:
			button.icon = texture
			button.expand_icon = true
		ability_buttons[ability_id] = button
	return button


func _combat_slot_frame(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(54, 54)
	panel.tooltip_text = "Schnellzugriff %d" % (index + 1)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.028, 0.034, 0.88)
	style.border_color = Color(0.45, 0.38, 0.27, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _fill_combat_slot(slot: PanelContainer, item_id: String) -> void:
	var data := DataCatalog.item(item_id)
	UiFactory.apply_item_rarity_frame(slot, item_id, false, Color(0.025, 0.028, 0.034, 0.88), 3)
	var usage := ""
	if InventorySystem.usable_item(item_id):
		usage = "\nLinksklick: benutzen (%d AP, kann misslingen)" % InventorySystem.combat_item_action_points(item_id)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				slot.accept_event()
				_use_inventory_item_in_combat(item_id)
		)
	UiFactory.attach_item_tooltip(slot, item_id, int(InventorySystem.items.get(item_id, 1)), -1, "Kampf%s" % usage.replace("\n", " | "))
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(46, 46)
	slot.add_child(stack)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://assets/items/backpacks/small_backpack.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	var count := Label.new()
	count.text = str(InventorySystem.items.get(item_id, 0))
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(count)
	_add_combat_condition_strip(stack, item_id)


func _add_combat_condition_strip(parent: Control, item_id: String) -> void:
	if not InventorySystem.is_durable(item_id):
		return
	var strip := ColorRect.new()
	strip.color = UiFactory.condition_color(InventorySystem.condition_ratio(item_id))
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 3
	strip.offset_right = -3
	strip.offset_top = -5
	strip.offset_bottom = -1
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(strip)


func _generate_enemy_loot() -> Dictionary:
	var result := {}
	var pool: Array = enemy.get("loot", [])
	if pool.is_empty():
		pool = ["cloth", "powder", "metal"]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(enemy_id.hash() + TimeSystem.current_day * 101 + turn * 37 + int(enemy_health_max_seed()))
	var rolls := 1
	if enemy_id == "demon_runner":
		rolls = 2
	elif enemy_id == "demon_brute":
		rolls = 3
	elif enemy_id == "demon_boss":
		rolls = 4
	for index in range(rolls):
		var item_id := str(pool[rng.randi_range(0, pool.size() - 1)])
		var data := DataCatalog.item(item_id)
		if data.is_empty():
			continue
		var amount := _enemy_loot_amount(data, rng)
		result[item_id] = int(result.get(item_id, 0)) + amount
	if result.is_empty():
		result["cloth"] = 1
	return result


func enemy_health_max_seed() -> float:
	return floorf(enemy_max_health * 10.0)


func _enemy_loot_amount(data: Dictionary, rng: RandomNumberGenerator) -> int:
	var category := str(data.get("category", ""))
	if category == "Munition":
		return rng.randi_range(2, 6)
	if category == "Material":
		return rng.randi_range(1, 3)
	return 1


func _show_enemy_loot_menu() -> void:
	if is_instance_valid(loot_overlay):
		loot_overlay.queue_free()
	loot_overlay = ColorRect.new()
	loot_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	loot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(loot_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact := UiFactory.is_compact_screen()
	margin.add_theme_constant_override("margin_left", 22 if compact else 42)
	margin.add_theme_constant_override("margin_right", 22 if compact else 42)
	margin.add_theme_constant_override("margin_top", 18 if compact else 34)
	margin.add_theme_constant_override("margin_bottom", 18 if compact else 34)
	loot_overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := UiFactory._panel_style()
	style.bg_color = Color(0.018, 0.021, 0.027, 0.97)
	style.border_color = Color(0.62, 0.47, 0.25, 0.96)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := UiFactory.title_label("%s BESIEGT" % str(enemy.get("name", "GEGNER")).to_upper(), 31)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var take_all := UiFactory.button("Alles nehmen", _take_all_enemy_loot, 170)
	header.add_child(take_all)
	var close := UiFactory.button("Weiter", _finish_loot_and_leave, 130)
	header.add_child(close)
	loot_feedback_label = UiFactory.body_label("Waehle Beute aus. Bei Ausruestung siehst du vorher/nachher sofort.", 15, UiFactory.COLOR_MUTED)
	root.add_child(loot_feedback_label)
	root.add_child(UiFactory.rarity_legend())
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10 if compact else 14)
	root.add_child(body)
	body.add_child(_build_loot_backpack_side())
	body.add_child(_build_loot_enemy_side())
	body.add_child(_build_loot_compare_side())
	_refresh_loot_menu()


func _build_loot_backpack_side() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 330
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiFactory.title_label("DEIN RUCKSACK", 23))
	var backpack := InventorySystem.backpack_data()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(backpack.get("icon", "res://assets/items/backpacks/small_backpack.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(54, 54)
	row.add_child(icon)
	loot_backpack_status_label = UiFactory.body_label("", 15, Color("#d8dde8"))
	loot_backpack_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(loot_backpack_status_label)
	var slot_usage := _add_loot_usage_bar(box, "Plaetze", Color("#d8b36a"))
	loot_slot_value_label = slot_usage.get("label") as Label
	loot_slot_bar = slot_usage.get("bar") as ProgressBar
	var weight_usage := _add_loot_usage_bar(box, "Gewicht", Color("#7ccf6b"))
	loot_weight_value_label = weight_usage.get("label") as Label
	loot_weight_bar = weight_usage.get("bar") as ProgressBar
	player_loot_grid = GridContainer.new()
	player_loot_grid.columns = 6
	player_loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_loot_grid.add_theme_constant_override("h_separation", 6)
	player_loot_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(player_loot_grid)
	return box


func _build_loot_enemy_side() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 390
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiFactory.title_label("GEGNER-INVENTAR", 23))
	enemy_loot_grid = VBoxContainer.new()
	enemy_loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_loot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_loot_grid.add_theme_constant_override("separation", 8)
	box.add_child(enemy_loot_grid)
	return box


func _build_loot_compare_side() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 300
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiFactory.title_label("WERTE", 23))
	loot_compare_label = RichTextLabel.new()
	loot_compare_label.bbcode_enabled = true
	loot_compare_label.fit_content = false
	loot_compare_label.scroll_active = true
	loot_compare_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_compare_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_compare_label.custom_minimum_size = Vector2(290, 300)
	loot_compare_label.add_theme_font_size_override("normal_font_size", 15)
	loot_compare_label.add_theme_color_override("default_color", Color("#d8dde8"))
	box.add_child(loot_compare_label)
	return box


func _add_loot_usage_bar(parent: VBoxContainer, label_text: String, color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	var title := UiFactory.body_label(label_text, 12, UiFactory.COLOR_MUTED)
	title.custom_minimum_size.x = 58
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	var value := UiFactory.body_label("", 12, Color("#d8dde8"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 13)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.024, 0.03, 0.95)
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return {"label": value, "bar": bar}


func _refresh_loot_menu() -> void:
	if not is_instance_valid(loot_overlay):
		return
	_refresh_loot_backpack_grid()
	_refresh_enemy_loot_grid()
	if is_instance_valid(loot_compare_label) and loot_compare_label.text.is_empty():
		loot_compare_label.text = "[color=#8e9aab]Bewege die Maus ueber Ausruestung, um alte und neue Werte zu vergleichen.[/color]"
	_refresh_backpack_overlay()
	_refresh_actor_overlay()


func _refresh_loot_backpack_grid() -> void:
	if not is_instance_valid(player_loot_grid):
		return
	if is_instance_valid(loot_backpack_status_label):
		loot_backpack_status_label.text = "%s\nFreie Plaetze: %d" % [InventorySystem.backpack_data().get("name", "Rucksack"), InventorySystem.free_slots()]
	_set_loot_usage_bar(loot_slot_bar, loot_slot_value_label, InventorySystem.used_slots(), InventorySystem.slot_capacity, "%d/%d" % [InventorySystem.used_slots(), InventorySystem.slot_capacity])
	_set_loot_usage_bar(loot_weight_bar, loot_weight_value_label, InventorySystem.current_weight(), InventorySystem.max_weight, "%.1f/%.1f kg" % [InventorySystem.current_weight(), InventorySystem.max_weight])
	UiFactory.clear_container(player_loot_grid)
	var item_ids := InventorySystem.ordered_items()
	var visible_slots := InventorySystem.slot_capacity
	player_loot_grid.columns = 6 if visible_slots <= 12 else 7
	for index in range(visible_slots):
		var slot := _combat_slot_frame(index)
		if index < item_ids.size():
			_fill_combat_slot(slot, str(item_ids[index]))
			var item_id := str(item_ids[index])
			slot.mouse_entered.connect(func() -> void:
				_show_loot_comparison(item_id)
			)
		player_loot_grid.add_child(slot)


func _refresh_enemy_loot_grid() -> void:
	if not is_instance_valid(enemy_loot_grid):
		return
	UiFactory.clear_container(enemy_loot_grid)
	if enemy_loot.is_empty():
		var empty := UiFactory.body_label("Nichts Brauchbares mehr.", 17, UiFactory.COLOR_MUTED)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		enemy_loot_grid.add_child(empty)
		return
	var ids := enemy_loot.keys()
	ids.sort()
	for item_key in ids:
		var item_id := str(item_key)
		var amount := int(enemy_loot.get(item_id, 0))
		if amount > 0:
			enemy_loot_grid.add_child(_enemy_loot_row(item_id, amount))


func _enemy_loot_row(item_id: String, amount: int) -> PanelContainer:
	var data := DataCatalog.item(item_id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_entered.connect(func() -> void:
		_show_loot_comparison(item_id)
	)
	UiFactory.apply_item_rarity_frame(panel, item_id, false, Color(0.035, 0.038, 0.047, 0.94), 4)
	UiFactory.attach_item_tooltip(panel, item_id, amount, -1, "Loot")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://assets/items/backpacks/small_backpack.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var title := UiFactory.body_label("%s x%d" % [data.get("name", item_id), amount], 17, Color("#f0dca9"))
	text_box.add_child(title)
	var description := UiFactory.body_label(str(data.get("description", "")), 13, UiFactory.COLOR_MUTED)
	description.custom_minimum_size.y = 34
	text_box.add_child(description)
	var meta := UiFactory.body_label("%s - %.1f kg - %s" % [
		UiFactory.rarity_label(data),
		float(data.get("weight", 0.0)) * amount,
		"anlegbar" if _can_equip_from_loot(item_id) else "mitnehmen"
	], 12, UiFactory.rarity_color(data))
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(meta)
	var take_button := UiFactory.button("Nehmen", func() -> void:
		_take_enemy_loot(item_id, 1)
	, 116)
	take_button.custom_minimum_size.y = 42
	row.add_child(take_button)
	if _can_equip_from_loot(item_id):
		var equip_button := UiFactory.button("Anlegen", func() -> void:
			_equip_enemy_loot(item_id)
		, 116)
		equip_button.custom_minimum_size.y = 42
		row.add_child(equip_button)
	return panel


func _item_tooltip_text(item_id: String, amount: int) -> String:
	var data := DataCatalog.item(item_id)
	var condition := InventorySystem.condition_text(item_id)
	return "%s x%d\nSeltenheit: %s\n%s%s" % [
		data.get("name", item_id),
		amount,
		UiFactory.rarity_label(data),
		data.get("description", ""),
		"\n" + condition if not condition.is_empty() else ""
	]


func _set_loot_usage_bar(bar: ProgressBar, label: Label, value: float, maximum: float, text: String) -> void:
	if is_instance_valid(bar):
		bar.max_value = maxf(maximum, 1.0)
		bar.value = clampf(value, 0.0, bar.max_value)
		bar.tooltip_text = text
	if is_instance_valid(label):
		label.text = text
		label.tooltip_text = text


func _can_equip_from_loot(item_id: String) -> bool:
	var data := DataCatalog.item(item_id)
	return InventorySystem.EQUIPMENT_SLOTS.has(str(data.get("equip_slot", ""))) or int(data.get("capacity_slots", 0)) > 0


func _take_enemy_loot(item_id: String, amount: int) -> bool:
	if int(enemy_loot.get(item_id, 0)) <= 0:
		return false
	var moved := InventorySystem.add_item(item_id, amount)
	if not moved:
		loot_feedback_label.text = "Kein Platz oder zu schwer: %s bleibt beim Gegner." % DataCatalog.item(item_id).get("name", item_id)
		return false
	_remove_enemy_loot_item(item_id, amount)
	loot_feedback_label.text = "%s genommen." % DataCatalog.item(item_id).get("name", item_id)
	AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -8.0, 1.05)
	_show_loot_comparison(item_id)
	_refresh_loot_menu()
	return true


func _take_all_enemy_loot() -> void:
	var moved_any := false
	for item_key in enemy_loot.keys().duplicate():
		var item_id := str(item_key)
		while int(enemy_loot.get(item_id, 0)) > 0:
			if not _take_enemy_loot(item_id, 1):
				loot_feedback_label.text = "Alles Moegliche wurde genommen. Fuer den Rest fehlt Platz oder Traglast."
				_refresh_loot_menu()
				return
			moved_any = true
	if moved_any:
		loot_feedback_label.text = "Beute gesichert."
	else:
		loot_feedback_label.text = "Keine Beute mehr vorhanden."
	_refresh_loot_menu()


func _equip_enemy_loot(item_id: String) -> void:
	if int(enemy_loot.get(item_id, 0)) <= 0:
		return
	_show_loot_comparison(item_id)
	if not InventorySystem.add_item(item_id, 1):
		loot_feedback_label.text = "Zum Anlegen muss zuerst ein Platz im Rucksack frei sein."
		return
	_remove_enemy_loot_item(item_id, 1)
	var data := DataCatalog.item(item_id)
	var equipped := false
	if int(data.get("capacity_slots", 0)) > 0:
		equipped = InventorySystem.equip_backpack(item_id)
	else:
		equipped = InventorySystem.equip_item(item_id)
	if not equipped:
		loot_feedback_label.text = "%s wurde genommen, aber nicht angelegt." % data.get("name", item_id)
	else:
		loot_feedback_label.text = "%s angelegt." % data.get("name", item_id)
		AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -8.0, 1.0)
	_refresh_loot_menu()


func _remove_enemy_loot_item(item_id: String, amount: int) -> void:
	enemy_loot[item_id] = maxi(0, int(enemy_loot.get(item_id, 0)) - amount)
	if int(enemy_loot.get(item_id, 0)) <= 0:
		enemy_loot.erase(item_id)


func _finish_loot_and_leave() -> void:
	if is_instance_valid(loot_overlay):
		loot_overlay.queue_free()
	TimeSystem.advance(1)
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		go_to(GameState.return_scene)


func _show_loot_comparison(item_id: String) -> void:
	if not is_instance_valid(loot_compare_label):
		return
	loot_compare_label.text = _comparison_text(item_id)


func _comparison_text(item_id: String) -> String:
	var data := DataCatalog.item(item_id)
	if data.is_empty():
		return "[color=#8e9aab]Unbekannter Gegenstand.[/color]"
	var lines: Array[String] = []
	lines.append("[color=#f0dca9]%s[/color]" % data.get("name", item_id))
	lines.append("[color=%s]Seltenheit: %s[/color]" % [UiFactory.rarity_color(data).to_html(false), UiFactory.rarity_label(data)])
	lines.append("[color=#8e9aab]%s[/color]" % data.get("description", ""))
	var slot := str(data.get("equip_slot", ""))
	if int(data.get("capacity_slots", 0)) > 0:
		lines.append("")
		lines.append("[color=#d8b36a]Rucksack-Vergleich[/color]")
		var old_backpack_data := InventorySystem.backpack_data()
		_append_stat_comparison(lines, "capacity_slots", "Plaetze", old_backpack_data, data)
		_append_stat_comparison(lines, "max_weight", "Traglast", old_backpack_data, data)
		return "\n".join(lines)
	if slot.is_empty() or not InventorySystem.EQUIPMENT_SLOTS.has(slot):
		lines.append("")
		lines.append("[color=#8e9aab]Nicht anlegbar. Kann nur genommen oder benutzt werden.[/color]")
		return "\n".join(lines)
	var old_id := InventorySystem.equipped_item(slot)
	var old_data := DataCatalog.item(old_id)
	lines.append("")
	lines.append("[color=#d8b36a]%s: %s -> %s[/color]" % [
		InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot),
		old_data.get("name", "leer") if not old_data.is_empty() else "leer",
		data.get("name", item_id)
	])
	var changed := false
	for row in LOOT_STAT_ROWS:
		var key := str(row.get("key", ""))
		if key in ["capacity_slots", "max_weight"]:
			continue
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
		marker = "[color=#79d36b]▲ +%s[/color]" % _stat_value_text(diff)
	elif diff < 0.0:
		marker = "[color=#d9685f]▼ %s[/color]" % _stat_value_text(diff)
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


func _rarity_color(data: Dictionary) -> Color:
	return UiFactory.rarity_color(data)


func _update_combat_idle() -> void:
	if is_instance_valid(player_art):
		player_art.position.y = sin(combat_anim_time * 1.8) * 4.0
	if is_instance_valid(enemy_art):
		enemy_art.position.y = cos(combat_anim_time * 1.55) * 4.5


func _begin_player_turn() -> void:
	turn_state = "player"
	player_action_points = PLAYER_ACTION_POINTS_PER_TURN
	_tick_ability_cooldowns()
	_set_active_actor(true)
	_set_actions_enabled(true)
	_refresh()


func _begin_enemy_turn() -> void:
	_hide_skip_turn_confirm()
	turn_state = "enemy"
	_set_actions_enabled(false)
	_set_active_actor(false)
	await get_tree().create_timer(0.65).timeout
	if turn_state != "enemy" or not is_inside_tree():
		return
	_enemy_action()
	if turn_state == "enemy":
		_begin_player_turn()


func _set_active_actor(player_active: bool) -> void:
	active_avatar.texture = load(player_art_path if player_active else enemy_art_path)
	_refresh_turn_text()
	_refresh_turn_badges(player_active)
	_pulse_turn_banner()


func _set_actions_enabled(enabled: bool) -> void:
	if is_instance_valid(attack_button):
		attack_button.disabled = not enabled or player_action_points < ATTACK_AP_COST
	if is_instance_valid(defend_button):
		defend_button.disabled = not enabled or player_action_points < DEFEND_AP_COST
	if is_instance_valid(bandage_button):
		bandage_button.disabled = not enabled or player_action_points < BANDAGE_AP_COST
	if is_instance_valid(flee_button):
		flee_button.disabled = not enabled or player_action_points < FLEE_AP_COST
	_refresh_ability_bar()


func _spend_combat_action_points(cost: int) -> bool:
	if turn_state != "player" or player_action_points < cost:
		return false
	player_action_points = maxi(0, player_action_points - cost)
	_pulse_resource_bar("ap")
	return true


func _tick_ability_cooldowns() -> void:
	var ids := ability_cooldowns.keys()
	for ability_id in ids:
		var remaining := int(ability_cooldowns[ability_id]) - 1
		if remaining <= 0:
			ability_cooldowns.erase(ability_id)
		else:
			ability_cooldowns[ability_id] = remaining


func _ability_tooltip_with_state(ability_id: String) -> String:
	var text := GameState.ability_tooltip_text(ability_id)
	text += "\nAktuelle Erfolgschance: %s" % _chance_text(_success_chance("ability", GameState.ability(ability_id)))
	var cooldown_left := int(ability_cooldowns.get(ability_id, 0))
	if cooldown_left > 0:
		text += "\nBereit in: %d Runde(n)" % cooldown_left
	if player_action_points < GameState.ability_action_points(ability_id):
		text += "\nNicht genug AP in diesem Zug."
	return text


func _ability_unavailable_text(ability_id: String, data: Dictionary) -> String:
	var cooldown_left := int(ability_cooldowns.get(ability_id, 0))
	if cooldown_left > 0:
		return "%s ist noch %d Runde(n) auf Abklingzeit." % [data.get("name", ability_id), cooldown_left]
	if player_action_points < GameState.ability_action_points(ability_id):
		return "Dafuer fehlen Aktionspunkte."
	if float(GameState.player_stats.get("stamina", 0.0)) < float(data.get("stamina_cost", 0.0)):
		return "Dafuer fehlt Ausdauer."
	if float(GameState.player_stats.get("energy", 0.0)) < float(data.get("energy_cost", 0.0)):
		return "Dafuer fehlt Energie."
	return "Diese Faehigkeit ist gerade nicht verfuegbar."


func _success_chance(action_type: String, data: Dictionary = {}) -> float:
	var attacker_stats := GameState.effective_player_stats()
	var defender_stats := RpgRules.enemy_stats(enemy)
	var modifier := 0.0
	match action_type:
		"melee":
			modifier += float(attacker_stats.get("melee_power", 0.0)) * 0.8
		"ranged":
			modifier += float(attacker_stats.get("ranged_power", 0.0)) * 0.8
		"ability":
			var scale_stat := str(data.get("scale_stat", ""))
			modifier += float(attacker_stats.get(scale_stat, 0.0)) * 0.6
			modifier -= float(GameState.ability_action_points(str(data.get("id", ""))) - 1) * 2.5
		"defend":
			modifier += float(attacker_stats.get("block_power", 0.0)) * 1.1
		"item":
			modifier += float(attacker_stats.get("willpower", 0.0)) * 0.7
		"flee":
			modifier += float(attacker_stats.get("dexterity", 0.0)) * 1.4 + float(GameState.player_stats.get("stamina", 0.0)) * 0.2
	modifier -= float(enemy.get("speed", 1)) * 2.0
	return clampf(RpgRules.hit_chance(attacker_stats, defender_stats, modifier), MIN_SUCCESS_CHANCE, MAX_SUCCESS_CHANCE)


func _roll_success(action_type: String, data: Dictionary = {}) -> Dictionary:
	var chance := _success_chance(action_type, data)
	var roll := randf()
	return {"success": roll <= chance, "chance": chance, "roll": roll}


func _chance_text(chance: float) -> String:
	return "%.0f%%" % (chance * 100.0)


func _refresh_turn_text() -> void:
	if not is_instance_valid(turn_label):
		return
	if turn_state == "player":
		turn_label.text = "DEIN ZUG - %s\nAP %d/%d - Faehigkeiten mit 1-9 oder Klick." % [
			GameState.player_class_name(),
			player_action_points,
			PLAYER_ACTION_POINTS_PER_TURN
		]
	elif turn_state == "enemy":
		turn_label.text = "GEGNER AM ZUG - %s\nDer Gegner antwortet nach deinen Aktionen." % enemy.get("name", "Gegner")
	else:
		turn_label.text = "KAMPF BEENDET"


func _attack() -> void:
	if turn_state != "player":
		return
	if not _spend_combat_action_points(ATTACK_AP_COST):
		log_label.text = "Dafuer fehlen Aktionspunkte."
		_refresh()
		return
	var result := _player_damage()
	_play_player_attack_feedback(result)
	enemy_health -= float(result.damage)
	log_label.text = str(result.text)
	_finish_player_action()


func _player_damage() -> Dictionary:
	for item_id in InventorySystem.attack_candidates():
		var data := DataCatalog.item(item_id)
		if data.is_empty():
			continue
		var ammo_id := str(data.get("ammo", ""))
		var ranged := not ammo_id.is_empty()
		var ammo_cost := int(data.get("ammo_cost", 1))
		if ranged and not InventorySystem.has_items({ammo_id: ammo_cost}):
			continue
		if ranged:
			InventorySystem.consume_cost({ammo_id: ammo_cost})
		var roll := _roll_success("ranged" if ranged else "melee", data)
		var attacker_stats := GameState.effective_player_stats()
		var defender_stats := RpgRules.enemy_stats(enemy)
		var damage := float(data.get("damage", 7.0)) * (0.62 + InventorySystem.condition_ratio(item_id) * 0.38)
		damage += float(attacker_stats.get("ranged_power" if ranged else "melee_power", 0.0))
		var damage_type := str(data.get("damage_type", "ranged" if ranged else "physical"))
		var damage_result := RpgRules.calculate_damage(damage, damage_type, attacker_stats, defender_stats, {
			"resistance_pierce": float(data.get("armor_pierce", 0.0)) + float(attacker_stats.get("armor_pierce", 0.0))
		})
		damage = float(damage_result.get("damage", damage))
		if bool(data.get("consume_on_attack", false)):
			InventorySystem.consume_equipped_or_inventory(item_id)
		else:
			InventorySystem.damage_item(item_id, int(data.get("durability_loss", 2 if not ranged else 4)))
		if not bool(roll.get("success", false)):
			return {
				"damage": 0.0,
				"ranged": ranged,
				"hit": false,
				"item_id": item_id,
				"weapon_type": str(data.get("weapon_type", "ranged" if ranged else "melee")),
				"text": "%s verfehlt. Trefferchance: %s." % [data.get("name", item_id), _chance_text(float(roll.get("chance", 0.0)))]
			}
		var crit_text := " Kritisch." if bool(damage_result.get("critical", false)) else ""
		return {
			"damage": damage,
			"ranged": ranged,
			"hit": true,
			"item_id": item_id,
			"weapon_type": str(data.get("weapon_type", "ranged" if ranged else "melee")),
			"text": "%s trifft. %.0f %s-Schaden.%s Trefferchance: %s." % [data.get("name", item_id), damage, RpgRules.damage_type_data(damage_type).get("name", damage_type), crit_text, _chance_text(float(roll.get("chance", 0.0)))]
		}
	var fallback := 5.0 + float(GameState.effective_player_stats().get("melee_power", 0.0))
	var fallback_roll := _roll_success("melee")
	if not bool(fallback_roll.get("success", false)):
		return {"damage": 0.0, "ranged": false, "hit": false, "text": "Du greifst improvisiert an und verfehlst. Trefferchance: %s." % _chance_text(float(fallback_roll.get("chance", 0.0)))}
	return {"damage": fallback, "ranged": false, "hit": true, "text": "Du greifst improvisiert an. %.0f Schaden. Trefferchance: %s." % [fallback, _chance_text(float(fallback_roll.get("chance", 0.0)))]}


func _defend() -> void:
	if turn_state != "player":
		return
	if not _spend_combat_action_points(DEFEND_AP_COST):
		log_label.text = "Dafuer fehlen Aktionspunkte."
		_refresh()
		return
	var roll := _roll_success("defend")
	if not bool(roll.get("success", false)):
		GameState.change_stat("stamina", -4.0)
		AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -8.0, 0.7)
		_pulse_art(player_art, Color(0.9, 0.42, 0.34, 0.88), 1.02)
		log_label.text = "Die Deckung misslingt. Erfolgschance: %s." % _chance_text(float(roll.get("chance", 0.0)))
		_finish_player_action()
		return
	defending = true
	defense_multiplier = 0.42
	GameState.change_stat("stamina", -4.0)
	AudioManager.play_sfx("res://assets/audio/sfx/environment/wave_warning.wav", -10.0, 1.35)
	_pulse_art(player_art, Color(0.65, 0.82, 1.0, 0.95), 1.035)
	log_label.text = "Du gehst hinter deiner Deckung in Stellung. Erfolgschance: %s." % _chance_text(float(roll.get("chance", 0.0)))
	_finish_player_action()


func _use_bandage() -> void:
	_use_inventory_item_in_combat("bandage")


func _use_inventory_item_in_combat(item_id: String) -> void:
	if turn_state != "player":
		return
	var data := DataCatalog.item(item_id)
	if data.is_empty() or not InventorySystem.usable_item(item_id):
		log_label.text = "Dieser Gegenstand kann im Kampf nicht benutzt werden."
		_refresh()
		return
	var cost := InventorySystem.combat_item_action_points(item_id)
	if not _spend_combat_action_points(cost):
		log_label.text = "Dafuer fehlen Aktionspunkte."
		_refresh()
		return
	var roll := _roll_success("item")
	if not bool(roll.get("success", false)):
		AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -8.0, 0.72)
		_pulse_art(player_art, Color(0.9, 0.42, 0.34, 0.88), 1.02)
		log_label.text = "%s misslingt. Erfolgschance: %s." % [data.get("name", item_id), _chance_text(float(roll.get("chance", 0.0)))]
		_finish_player_action()
		return
	log_label.text = "%s\nKosten: %d AP. Erfolgschance: %s." % [
		InventorySystem.use_item(item_id),
		cost,
		_chance_text(float(roll.get("chance", 0.0)))
	]
	AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -9.0, 1.2)
	_pulse_art(player_art, Color(0.72, 1.0, 0.78, 0.95), 1.03)
	_finish_player_action()


func _use_hotbar_ability(index: int) -> void:
	if turn_state != "player" or index < 0 or index >= GameState.equipped_abilities.size():
		return
	_use_ability(str(GameState.equipped_abilities[index]))


func _use_ability(ability_id: String) -> void:
	var data := GameState.ability(ability_id)
	if data.is_empty():
		return
	if not _pay_ability_cost(ability_id, data):
		log_label.text = _ability_unavailable_text(ability_id, data)
		_refresh_ability_bar()
		return
	var roll := _roll_success("ability", data)
	if not bool(roll.get("success", false)):
		log_label.text = "%s misslingt. Erfolgschance: %s." % [
			data.get("name", ability_id),
			_chance_text(float(roll.get("chance", 0.0)))
		]
		AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -8.0, 0.72)
		_pulse_art(player_art, Color(0.9, 0.42, 0.34, 0.88), 1.02)
		_finish_player_action()
		return
	var result := _apply_ability_effect(data)
	log_label.text = "%s\nErfolgschance: %s." % [
		str(result.get("text", "")),
		_chance_text(float(roll.get("chance", 0.0)))
	]
	_play_ability_feedback(data, float(result.get("damage", 0.0)), float(result.get("heal", 0.0)), float(result.get("shield", 0.0)))
	_finish_player_action()


func _can_pay_ability(ability_id: String) -> bool:
	var data := GameState.ability(ability_id)
	if data.is_empty():
		return false
	return int(ability_cooldowns.get(ability_id, 0)) <= 0 and player_action_points >= GameState.ability_action_points(ability_id) and float(GameState.player_stats.get("stamina", 0.0)) >= float(data.get("stamina_cost", 0.0)) and float(GameState.player_stats.get("energy", 0.0)) >= float(data.get("energy_cost", 0.0))


func _pay_ability_cost(ability_id: String, data: Dictionary) -> bool:
	if int(ability_cooldowns.get(ability_id, 0)) > 0:
		return false
	if not _spend_combat_action_points(GameState.ability_action_points(ability_id)):
		return false
	if float(GameState.player_stats.get("stamina", 0.0)) < float(data.get("stamina_cost", 0.0)):
		player_action_points += GameState.ability_action_points(ability_id)
		return false
	if float(GameState.player_stats.get("energy", 0.0)) < float(data.get("energy_cost", 0.0)):
		player_action_points += GameState.ability_action_points(ability_id)
		return false
	GameState.change_stat("stamina", -float(data.get("stamina_cost", 0.0)))
	GameState.change_stat("energy", -float(data.get("energy_cost", 0.0)))
	ability_cooldowns[ability_id] = GameState.ability_cooldown(ability_id)
	return true


func _ability_value(data: Dictionary) -> float:
	var stat := str(data.get("scale_stat", ""))
	return float(data.get("power", 0.0)) + float(GameState.player_stats.get(stat, 0.0)) * float(data.get("scale", 0.0))


func _apply_ability_effect(data: Dictionary) -> Dictionary:
	var effect := str(data.get("effect", "damage"))
	var value := _ability_value(data)
	var damage := 0.0
	var heal := 0.0
	var shield := 0.0
	var recover := 0.0
	var lines: Array[String] = [str(data.get("name", "Faehigkeit"))]
	match effect:
		"damage", "damage_defend", "snare":
			damage = value
		"material_damage":
			damage = value
			var item_cost: Dictionary = data.get("item_cost", {})
			if not item_cost.is_empty() and InventorySystem.consume_cost(item_cost):
				damage += float(data.get("bonus_power", 0.0))
				lines.append("Material knallt auseinander.")
			elif not item_cost.is_empty():
				lines.append("Ohne Material bleibt nur die kleine Ladung.")
		"damage_heal":
			damage = value
			heal = damage * float(data.get("heal_ratio", 0.35))
		"heal", "cleanse_heal":
			heal = value
		"cleanse_shield":
			heal = value
			shield = float(data.get("shield", 0.0))
		"heal_shield":
			heal = value
			shield = float(data.get("shield", value * 0.5))
		"shield", "shield_defend":
			shield = value + float(data.get("shield", 0.0))
		"damage_shield_defend":
			damage = value
			shield = float(data.get("shield", 0.0))
		"recover", "recover_defend":
			recover = value
		"shield_recover", "shield_recover_defend":
			shield = value
			recover = value * 0.7
		"defend":
			shield = value * 0.4
	if damage > 0.0:
		var damage_type := str(data.get("damage_type", "explosive" if effect == "material_damage" else "physical"))
		var damage_result := RpgRules.calculate_damage(damage, damage_type, GameState.effective_player_stats(), RpgRules.enemy_stats(enemy))
		damage = float(damage_result.get("damage", damage))
		enemy_health -= damage
		lines.append("%.0f %s-Schaden." % [damage, RpgRules.damage_type_data(damage_type).get("name", damage_type)])
	if heal > 0.0:
		GameState.change_stat("health", heal)
		lines.append("%.0f Leben wiederhergestellt." % heal)
	if shield > 0.0:
		GameState.change_stat("shield", shield)
		lines.append("%.0f Schild aufgebaut." % shield)
	if recover > 0.0:
		GameState.change_stat("stamina", recover)
		GameState.change_stat("energy", recover * 0.55)
		lines.append("%.0f Ausdauer und %.0f Energie zurueck." % [recover, recover * 0.55])
	if effect.contains("cleanse"):
		_clear_one_status()
		lines.append("Eine Verunreinigung wurde entfernt, falls vorhanden.")
	if effect.contains("defend") or data.has("defense_multiplier"):
		defending = true
		defense_multiplier = float(data.get("defense_multiplier", 0.55))
		lines.append("Naechster Schaden: %.0f%%." % (defense_multiplier * 100.0))
	return {"text": "\n".join(lines), "damage": damage, "heal": heal, "shield": shield}


func _clear_one_status() -> void:
	for status in ["infected_wound", "food_poisoning", "demonic_taint"]:
		if GameState.status_effects.has(status):
			GameState.status_effects.erase(status)
			return


func _finish_player_action() -> void:
	_refresh()
	if enemy_health <= 0.0:
		_victory()
		return
	if player_action_points <= 0:
		_begin_enemy_turn()
	else:
		log_label.text += "\nNoch %d/%d AP uebrig." % [player_action_points, PLAYER_ACTION_POINTS_PER_TURN]
		_set_actions_enabled(turn_state == "player")
		_refresh_turn_text()


func _request_end_turn() -> void:
	if turn_state != "player":
		return
	if player_action_points > 0 and AudioManager.should_confirm_skip_turn_with_ap():
		_show_skip_turn_confirm()
		return
	_end_player_turn()


func _end_player_turn() -> void:
	_hide_skip_turn_confirm()
	if turn_state != "player":
		return
	player_action_points = 0
	log_label.text = "Du beendest deine Runde."
	_finish_player_action()


func _show_skip_turn_confirm() -> void:
	if is_instance_valid(skip_turn_confirm):
		return
	skip_turn_confirm = Control.new()
	skip_turn_confirm.name = "SkipTurnConfirm"
	skip_turn_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_turn_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(skip_turn_confirm)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_turn_confirm.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_turn_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 240)
	panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiFactory.title_label("RUNDE BEENDEN?", 28))
	box.add_child(UiFactory.body_label("Du hast noch %d Aktionspunkte. Trotzdem zum Gegnerzug wechseln?" % player_action_points, 18, Color("#d8dde8")))
	box.add_child(UiFactory.body_label("Diese Nachfrage kannst du unter ESC > Allgemein aendern.", 15, UiFactory.COLOR_MUTED))
	var actions := UiFactory.horizontal_actions()
	box.add_child(actions)
	actions.add_child(UiFactory.button("Runde beenden", _end_player_turn, 220))
	actions.add_child(UiFactory.button("Weiter kaempfen", _hide_skip_turn_confirm, 220))


func _hide_skip_turn_confirm() -> void:
	if is_instance_valid(skip_turn_confirm):
		skip_turn_confirm.queue_free()
	skip_turn_confirm = null


func _enemy_action() -> void:
	var raw_damage := (float(enemy.get("damage", 6)) + floorf(float(TimeSystem.current_day) / 45.0)) * TimeSystem.enemy_strength_multiplier()
	raw_damage += maxf(0.0, float(enemy.get("speed", 1)) - 2.0)
	if defending:
		raw_damage *= defense_multiplier
		defending = false
		defense_multiplier = 1.0
	var damage_type := str(enemy.get("damage_type", "physical"))
	var damage_result := RpgRules.calculate_damage(raw_damage, damage_type, RpgRules.enemy_stats(enemy), GameState.effective_player_stats(), {"allow_critical": false})
	var damage := float(damage_result.get("damage", raw_damage))
	damage = maxf(0.0, damage - InventorySystem.armor_value() * 0.22 - float(GameState.player_stats.get("defense", 0.0)) * 0.45)
	var shield := float(GameState.player_stats.shield)
	if shield > 0.0:
		var absorbed := minf(shield, damage)
		GameState.player_stats.shield = shield - absorbed
		damage -= absorbed
	if damage > 0.0:
		GameState.change_stat("health", -damage)
	_play_enemy_attack_feedback(damage)
	log_label.text += "\n%s ist am Zug und verursacht %.0f Schaden." % [enemy.get("name", "Gegner"), damage]
	if turn == 3 and enemy_id == "demon_basic" and not GameState.status_effects.has("demonic_taint"):
		GameState.status_effects.append("demonic_taint")
		log_label.text += "\nEine kalte Schwaerze bleibt in der Wunde: Daemonische Verunreinigung."
	if turn == 2 and enemy_id == "demon_brute" and not GameState.status_effects.has("infected_wound"):
		GameState.status_effects.append("infected_wound")
		log_label.text += "\nDie tiefe Wunde entzuendet sich."
	turn += 1
	GameState.change_stat("stamina", -5.0)
	_refresh()


func _victory() -> void:
	turn_state = "ended"
	_set_actions_enabled(false)
	GameState.run_statistics.enemies_defeated = int(GameState.run_statistics.enemies_defeated) + 1
	GameState.grant_xp(int(enemy.get("xp", 25)), "Kampf gewonnen")
	AudioManager.play_sfx("res://assets/audio/sfx/weapons/melee_hit.wav", -6.0, 0.62)
	_fade_art(enemy_art)
	enemy_loot = _generate_enemy_loot()
	log_label.text += "\n%s bricht zusammen. Durchsuche die Beute." % enemy.get("name", "Der Gegner")
	_refresh()
	_show_enemy_loot_menu()


func _flee() -> void:
	if turn_state != "player":
		return
	if not _spend_combat_action_points(FLEE_AP_COST):
		log_label.text = "Dafuer fehlen Aktionspunkte."
		_refresh()
		return
	var roll := _roll_success("flee")
	if not bool(roll.get("success", false)):
		AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -7.0, 1.15)
		GameState.change_stat("stamina", -10.0)
		log_label.text = "Der Rueckzug misslingt. Erfolgschance: %s." % _chance_text(float(roll.get("chance", 0.0)))
		_finish_player_action()
		return
	turn_state = "ended"
	_set_actions_enabled(false)
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -7.0, 1.15)
	GameState.change_stat("stamina", -18.0)
	GameState.change_stat("health", -5.0)
	TimeSystem.advance(1, "Du entkommst knapp.")
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		go_to("res://scenes/world_map/world_map.tscn")


func _refresh() -> void:
	var max_health := float(GameState.player_stats.get("max_health", 100.0))
	if is_instance_valid(player_health_bar):
		player_health_bar.max_value = max_health
		player_health_bar.value = clampf(float(GameState.player_stats.health), 0.0, max_health)
		player_health_bar.tooltip_text = "Dein Leben: %.0f / %.0f" % [float(GameState.player_stats.health), max_health]
	if is_instance_valid(enemy_health_bar):
		enemy_health_bar.max_value = enemy_max_health
		enemy_health_bar.value = clampf(enemy_health, 0.0, enemy_max_health)
		enemy_health_bar.tooltip_text = "%s: %.0f / %.0f" % [enemy.get("name", "Gegner"), maxf(0.0, enemy_health), enemy_max_health]
	if is_instance_valid(round_label):
		round_label.text = "RUNDE %d" % turn
	player_label.text = "Leben %.0f - Schutz %.0f - Ruestung %.0f - Ausdauer %.0f" % [
		float(GameState.player_stats.health),
		float(GameState.player_stats.shield),
		InventorySystem.armor_value(),
		float(GameState.player_stats.stamina)
	]
	enemy_label.text = "Leben %.0f - Schaden %d - Tempo %d" % [
		maxf(0.0, enemy_health),
		int(enemy.get("damage", 0)),
		int(enemy.get("speed", 1))
	]
	_refresh_turn_text()
	_refresh_actor_overlay()
	_refresh_backpack_overlay()
	_refresh_turn_badges(turn_state == "player")
	_set_actions_enabled(turn_state == "player")


func _refresh_turn_badges(player_active: bool) -> void:
	if turn_state == "ended":
		var victory := enemy_health <= 0.0
		if is_instance_valid(player_turn_badge):
			player_turn_badge.text = "SIEG" if victory else "ENDE"
			player_turn_badge.modulate = Color(1.0, 1.0, 1.0, 0.95)
		if is_instance_valid(enemy_turn_badge):
			enemy_turn_badge.text = "BESIEGT" if victory else "WARTET"
			enemy_turn_badge.modulate = Color(1.0, 1.0, 1.0, 0.35)
		return
	if is_instance_valid(player_turn_badge):
		player_turn_badge.text = "AM ZUG" if player_active else "BEREIT"
		player_turn_badge.modulate = Color(1.0, 1.0, 1.0, 1.0 if player_active else 0.55)
	if is_instance_valid(enemy_turn_badge):
		enemy_turn_badge.text = "AM ZUG" if not player_active else "WARTET"
		enemy_turn_badge.modulate = Color(1.0, 1.0, 1.0, 1.0 if not player_active else 0.55)


func _play_player_attack_feedback(result: Dictionary) -> void:
	var data := DataCatalog.item(str(result.get("item_id", "")))
	var ranged := bool(result.get("ranged", false)) or str(result.get("weapon_type", "")) == "throwable"
	var sound_path := str(data.get("sound", "res://assets/audio/sfx/weapons/gunshot.wav" if ranged else "res://assets/audio/sfx/weapons/melee_hit.wav"))
	AudioManager.play_sfx(sound_path, -3.0, 1.0 if ranged else 0.92)
	_pulse_art(player_art, Color(1.0, 0.92, 0.65, 0.95), 1.07 if not ranged else 1.04)
	_pulse_art(player_weapon_art, Color(1.0, 0.92, 0.65, 0.95), 1.08)
	if ranged:
		_spawn_projectile(data)
	if bool(result.get("hit", true)):
		_shake_art(enemy_art, Color(1.0, 0.46, 0.38, 0.95))
	else:
		_pulse_art(enemy_art, Color(0.72, 0.74, 0.78, 0.72), 1.015)


func _play_enemy_attack_feedback(damage: float) -> void:
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -8.0, 0.92)
	if damage > 0.0:
		AudioManager.play_sfx("res://assets/audio/sfx/weapons/melee_hit.wav", -9.0, 0.72)
	_shake_art(player_art, Color(0.92, 0.38, 0.34, 0.95))
	_pulse_art(enemy_art, Color(1.0, 0.58, 0.42, 0.92), 1.055)


func _play_ability_feedback(data: Dictionary, damage: float, heal: float, shield: float) -> void:
	var sound_path := str(data.get("sound", "res://assets/audio/sfx/ui/craft.wav"))
	AudioManager.play_sfx(sound_path, -6.0, 1.0)
	var tint := Color(str(data.get("color", "#f0d17a")))
	tint.a = 0.96
	_pulse_art(player_art, tint, 1.06)
	if damage > 0.0:
		_shake_art(enemy_art, Color(1.0, 0.46, 0.34, 0.95))
		if sound_path.contains("gunshot"):
			_spawn_projectile(data)
	if heal > 0.0 or shield > 0.0:
		_pulse_art(player_art, Color(0.65, 1.0, 0.78, 0.95), 1.04)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			accept_event()
			_request_end_turn()
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			accept_event()
			_use_hotbar_ability(int(event.keycode - KEY_1))
			return
	super._unhandled_input(event)


func _add_player_weapon_art(stage: Control) -> void:
	player_weapon_art = TextureRect.new()
	player_weapon_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_weapon_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_weapon_art.custom_minimum_size = Vector2(118, 82)
	player_weapon_art.position = Vector2(250, 176)
	player_weapon_art.rotation_degrees = -8.0
	player_weapon_art.modulate = Color(1, 1, 1, 0.92)
	player_weapon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(player_weapon_art)
	_refresh_player_weapon_art()


func _refresh_player_weapon_art() -> void:
	if not is_instance_valid(player_weapon_art):
		return
	var item_id := InventorySystem.preferred_weapon()
	var data := DataCatalog.item(item_id)
	if data.is_empty():
		player_weapon_art.texture = null
		player_weapon_art.visible = false
		return
	player_weapon_art.visible = true
	player_weapon_art.texture = load(str(data.get("icon", "res://icon.svg")))
	var weapon_type := str(data.get("weapon_type", "melee"))
	player_weapon_art.position = Vector2(262, 178)
	player_weapon_art.rotation_degrees = -8.0
	if weapon_type == "melee":
		player_weapon_art.position = Vector2(252, 160)
		player_weapon_art.rotation_degrees = -28.0
	elif weapon_type == "throwable":
		player_weapon_art.position = Vector2(276, 158)
		player_weapon_art.rotation_degrees = -14.0


func _spawn_projectile(data: Dictionary) -> void:
	if not is_instance_valid(combat_effect_layer) or not is_instance_valid(player_art) or not is_instance_valid(enemy_art):
		return
	var layer_origin := combat_effect_layer.get_global_rect().position
	var start: Vector2 = player_art.get_global_rect().get_center() + Vector2(76, -20) - layer_origin
	var target: Vector2 = enemy_art.get_global_rect().get_center() + Vector2(-70, -18) - layer_origin
	var projectile := ColorRect.new()
	var weapon_type := str(data.get("weapon_type", "ranged"))
	projectile.color = Color("#ffd36c") if weapon_type != "throwable" else Color("#ff8f4c")
	projectile.size = Vector2(24, 5) if weapon_type != "throwable" else Vector2(16, 16)
	projectile.position = start
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_effect_layer.add_child(projectile)
	var tween := create_tween()
	tween.tween_property(projectile, "position", target, 0.16 if weapon_type != "throwable" else 0.32)
	tween.finished.connect(func() -> void:
		if is_instance_valid(projectile):
			projectile.queue_free()
	)


func _pulse_turn_banner() -> void:
	if not is_instance_valid(active_avatar):
		return
	var tween := create_tween()
	tween.tween_property(active_avatar, "scale", Vector2(1.06, 1.06), 0.08)
	tween.tween_property(active_avatar, "scale", Vector2.ONE, 0.12)


func _pulse_art(art: TextureRect, tint: Color, scale_to: float) -> void:
	if not is_instance_valid(art):
		return
	var tween := create_tween()
	tween.tween_property(art, "scale", Vector2(scale_to, scale_to), 0.08)
	tween.parallel().tween_property(art, "modulate", tint, 0.08)
	tween.tween_property(art, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(art, "modulate", Color(1, 1, 1, 0.9), 0.14)


func _shake_art(art: TextureRect, tint: Color) -> void:
	if not is_instance_valid(art):
		return
	var origin := art.position
	var tween := create_tween()
	tween.tween_property(art, "position", origin + Vector2(10, 0), 0.04)
	tween.parallel().tween_property(art, "modulate", tint, 0.04)
	tween.tween_property(art, "position", origin + Vector2(-8, 0), 0.04)
	tween.tween_property(art, "position", origin, 0.05)
	tween.parallel().tween_property(art, "modulate", Color(1, 1, 1, 0.9), 0.08)


func _fade_art(art: TextureRect) -> void:
	if not is_instance_valid(art):
		return
	var tween := create_tween()
	tween.tween_property(art, "modulate", Color(0.35, 0.35, 0.35, 0.28), 0.18)
