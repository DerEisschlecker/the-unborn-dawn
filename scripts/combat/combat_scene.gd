# Purpose: Turn-based combat with visible active actor, class ability, equipment-aware attacks, sounds, animation, and loot return.
# Public API: Player actions resolve one turn, then the enemy visibly takes its turn.
# Dependencies: DataCatalog, GameState, InventorySystem, TimeSystem.
extends GameplayScreen

const InventorySlotScript := preload("res://scripts/ui/inventory_slot.gd")
const EnemySpawnService := preload("res://scripts/world/enemy_spawn_service.gd")
const TurnLogic := preload("res://scripts/combat/combat_turn_logic.gd")
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
const COMBAT_ATTACK_ICON := "res://assets/ui/icons/combat_attack.svg"
const COMBAT_DEFEND_ICON := "res://assets/ui/icons/shield.png"
const COMBAT_HEAL_ICON := "res://assets/items/medical/bandage.svg"
const COMBAT_FLEE_ICON := "res://assets/ui/icons/combat_flee.svg"
const SUMMARY_COLOR_DAMAGE := "#f26a6a"
const SUMMARY_COLOR_HEAL := "#6fcf7a"
const SUMMARY_COLOR_BUFF := "#5da8ff"
const SUMMARY_COLOR_DEBUFF := "#b56cff"
const SUMMARY_COLOR_NEUTRAL := "#d0d8e4"
const SUMMARY_COLOR_HEADING := "#e8c87a"
const COMBAT_STATUS_LABELS := {
	"demonic_taint": "Daemonische Verunreinigung",
	"infected_wound": "Entzuendete Wunde",
	"food_poisoning": "Vergiftung",
}
const COMBAT_STATUS_DESCRIPTIONS := {
	"demonic_taint": "Daemonische Essenz in der Wunde. -3 Leben pro Tag, bis mit Reinigungssalz behandelt.",
	"infected_wound": "Entzuendete Wunde. -8 Ausdauer pro Tag, bis mit Antiseptikum oder Antibiotika behandelt.",
	"food_poisoning": "Vergiftung. -5 Leben pro Tag, bis mit Antibiotika behandelt.",
}

var enemy_id: String
var enemy: Dictionary
var enemy_max_health: float
var enemy_health: float
var turn := 1
var turn_state := "player"
var active_actor_id := "player"
var turn_order: Array[String] = []
var turn_order_index := 0
var turn_order_initiatives: Dictionary = {}
var turn_order_strip: HBoxContainer
var party_action_points: Dictionary = {}
var companion_combat_health := 0.0
var companion_combat_max_health := 0.0
var companion_combat_active := false
var companion_art_path := ""
var actor_ability_cooldowns: Dictionary = {}
var player_action_points := PLAYER_ACTION_POINTS_PER_TURN
var ability_cooldowns: Dictionary = {}
var defending := false
var defending_actor_id := ""
var defense_multiplier := 1.0
var enemy_art_path := ""
var player_art_path := ""
var enemy_label: Label
var player_label: Label
var log_label: RichTextLabel
var combat_summary_label: RichTextLabel
var combat_overview_box: VBoxContainer
var combat_debuff_row: HFlowContainer
var combat_events: Array[String] = []
var combat_totals := {
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"healing": 0.0,
	"shield_gained": 0.0,
	"shield_absorbed": 0.0,
}
var combat_buffs: Array[String] = []
var combat_debuffs: Array[String] = []
var turn_label: Label
var round_label: Label
var actor_card_portrait: TextureRect
var actor_summary_label: Label
var active_avatar: TextureRect
var attack_button: Button
var defend_button: Button
var bandage_button: Button
var flee_button: Button
var player_art: Control
var enemy_art: TextureRect
var combat_effect_layer: Control
var player_health_bar: ProgressBar
var enemy_health_bar: ProgressBar
var enemy_health_bar_entry: Dictionary = {}
var combat_enemy_damage_preview := -1.0
var combat_enemy_hit_chance := -1.0
var player_turn_badge: Label
var enemy_turn_badge: Label
var backpack_grid: GridContainer
var backpack_status_label: Label
var equipment_grid: GridContainer
var ability_bar: GridContainer
var ability_buttons: Dictionary = {}
var player_stat_bars: Dictionary = {}
var combat_preview_deltas: Dictionary = {}
var combat_preview_source := ""
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
var inventory_button: Button
var heal_item_bar: PanelContainer
var heal_item_row: HBoxContainer
var action_host: VBoxContainer
var ability_class_label: Label


func _combat_layout_metrics() -> Dictionary:
	var viewport := UiFactory.viewport_size(self)
	var compact := UiFactory.is_compact_screen(self)
	return {
		"overlay_height": clampf(viewport.y * (0.27 if compact else 0.25), 188.0, 248.0),
		"stage_width": clampf(viewport.x * (0.17 if compact else 0.19), 180.0, 360.0),
		"stage_height": clampf(viewport.y * (0.24 if compact else 0.27), 170.0, 290.0),
		"portrait": 48.0 if compact else 56.0,
		"ability_square": Vector2(54, 54) if compact else Vector2(60, 60),
		"action_square": Vector2(50, 50) if compact else Vector2(56, 56),
		"font_action": 10 if compact else 11,
		"font_ability": 9 if compact else 10,
		"font_stats": 11 if compact else 12,
		"log_font": 16 if compact else 18,
		"log_heading_font": 17 if compact else 19,
		"slot_size": Vector2(40, 40) if compact else Vector2(44, 44),
		"compact": compact,
	}


func _short_label(text: String, max_chars: int = 10) -> String:
	var clean := text.strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s." % clean.substr(0, maxi(1, max_chars - 1))


func _ready() -> void:
	AudioManager.play_scene_music("combat")
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -5.0, 0.92)
	enemy_id = str(GameState.quest_flags.get("current_enemy", "demon_basic"))
	enemy = DataCatalog.enemy(enemy_id)
	var combat_location := DataCatalog.location(GameState.current_location)
	var player_level := int(GameState.player_stats.get("level", 1))
	enemy_max_health = EnemySpawnService.scale_health(
		float(enemy.get("health", 30)),
		combat_location,
		player_level,
		TimeSystem.current_day,
		TimeSystem.enemy_strength_multiplier()
	)
	enemy_health = enemy_max_health
	if GameState.has_companion():
		companion_combat_active = true
		companion_art_path = GameState.companion_appearance_portrait_path()
		companion_combat_max_health = float(GameState.effective_companion_stats().get("max_health", 100.0))
		companion_combat_health = float(GameState.companion_stats().get("health", companion_combat_max_health))
	party_action_points = {"player": PLAYER_ACTION_POINTS_PER_TURN}
	actor_ability_cooldowns = {"player": {}}
	if companion_combat_active:
		party_action_points["companion"] = PLAYER_ACTION_POINTS_PER_TURN
		actor_ability_cooldowns["companion"] = {}
	player_art_path = GameState.player_appearance_portrait_path()
	enemy_art_path = "res://assets/enemies/%s/%s.svg" % [enemy_id, enemy_id]
	var root := _setup_combat_screen()
	attach_hud()
	_build_arena(root)
	_build_bottom_overlay(root)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.stats_changed.connect(_refresh)
	set_process(true)
	_reset_combat_summary()
	_set_combat_log("Der %s tritt aus dem Schatten." % enemy.get("name", "Gegner"))
	_build_turn_order()
	_begin_actor_turn(turn_order[0])


func _process(delta: float) -> void:
	combat_anim_time += delta
	_update_combat_idle()


func _setup_combat_screen() -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	clear_dynamic_children()
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
	top_vignette.offset_bottom = 88
	top_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_vignette)
	var bottom_vignette := ColorRect.new()
	bottom_vignette.color = Color(0, 0, 0, 0.62)
	bottom_vignette.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_vignette.offset_top = -280 - UiFactory.hud_height(self)
	bottom_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_vignette)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := UiFactory.screen_margins(self, UiFactory.is_compact_screen(self))
	margin.add_theme_constant_override("margin_left", margins.left)
	margin.add_theme_constant_override("margin_right", margins.right)
	margin.add_theme_constant_override("margin_top", margins.top)
	margin.add_theme_constant_override("margin_bottom", UiFactory.hud_bottom_inset(self))
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
	var metrics: Dictionary = _combat_layout_metrics()
	_build_combat_header(root, metrics)
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.size_flags_stretch_ratio = 1
	arena.add_theme_constant_override("separation", 10)
	root.add_child(arena)
	arena.add_child(_stage_side(
		GameState.player_name.to_upper(),
		"#263746",
		player_art_path,
		"player",
		metrics
	))
	var center := Control.new()
	center.custom_minimum_size.x = 24
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1
	arena.add_child(center)
	arena.add_child(_stage_side(
		str(enemy.get("name", "FEIND")).to_upper(),
		str(enemy.get("color", "#8b3e3e")),
		enemy_art_path,
		"enemy",
		metrics
	))


func _build_combat_header(root: VBoxContainer, metrics: Dictionary) -> void:
	var header_wrap := CenterContainer.new()
	header_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header_wrap)
	var header_column := VBoxContainer.new()
	header_column.alignment = BoxContainer.ALIGNMENT_CENTER
	header_column.add_theme_constant_override("separation", 8)
	header_wrap.add_child(header_column)
	round_label = UiFactory.ornate_heading("RUNDE %d" % turn, 22 if metrics.compact else 26)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_column.add_child(round_label)
	turn_order_strip = HBoxContainer.new()
	turn_order_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_order_strip.add_theme_constant_override("separation", 6)
	header_column.add_child(turn_order_strip)


func _actor_portrait_path(actor_id: String) -> String:
	match actor_id:
		"player":
			return player_art_path
		"companion":
			return companion_art_path if not companion_art_path.is_empty() else player_art_path
		"enemy":
			return enemy_art_path
	return player_art_path


func _refresh_turn_order_strip() -> void:
	if not is_instance_valid(turn_order_strip):
		return
	UiFactory.clear_container(turn_order_strip)
	var metrics: Dictionary = _combat_layout_metrics()
	var slot_index := 0
	for actor_id in turn_order:
		if actor_id == "companion" and (not companion_combat_active or companion_combat_health <= 0.0):
			continue
		if slot_index > 0:
			turn_order_strip.add_child(_turn_order_arrow())
		var is_active := actor_id == active_actor_id
		turn_order_strip.add_child(_turn_order_slot(actor_id, is_active, metrics))
		slot_index += 1


func _turn_order_arrow() -> Label:
	var arrow := UiFactory.ornate_muted_label(">", 16, false)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.modulate = Color(0.72, 0.58, 0.34, 0.85)
	return arrow


func _turn_order_slot(actor_id: String, is_active: bool, metrics: Dictionary) -> PanelContainer:
	var portrait_size: float = float(metrics.portrait) + (10.0 if is_active else 0.0)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(portrait_size + 20.0, portrait_size + 34.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	if is_active:
		style.border_color = Color(0.92, 0.72, 0.28, 1.0)
		style.shadow_color = Color(0.92, 0.72, 0.28, 0.4)
		style.shadow_size = 6
	else:
		style.border_color = Color(0.32, 0.36, 0.44, 0.75)
	panel.add_theme_stylebox_override("panel", style)
	if not is_active:
		panel.modulate = Color(1.0, 1.0, 1.0, 0.68)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var portrait := TextureRect.new()
	portrait.texture = load(_actor_portrait_path(actor_id))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	var name_label := UiFactory.ornate_muted_label(_short_label(_actor_name(actor_id), 9), metrics.font_stats - 1, false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_active:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 1.0))
	column.add_child(name_label)
	if turn_order_initiatives.has(actor_id):
		var init_label := UiFactory.ornate_muted_label("Init %d" % int(turn_order_initiatives[actor_id]), metrics.font_stats - 2, false)
		init_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(init_label)
	if is_active:
		var badge := UiFactory.ornate_muted_label("AM ZUG", metrics.font_stats - 1, true)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 1.0))
		column.add_child(badge)
	panel.tooltip_text = _actor_name(actor_id)
	return panel


func _stage_side(text: String, color: String, texture_path: String, role: String, metrics: Dictionary) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_stretch_ratio = 2
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(spacer)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(metrics.stage_width, metrics.stage_height)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var art := _create_stage_art(texture_path, role, metrics)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_top = 4
	art.offset_bottom = -36
	if art is CanvasItem:
		(art as CanvasItem).modulate = Color(1, 1, 1, 0.95)
	if art is Control:
		(art as Control).pivot_offset = Vector2(metrics.stage_width * 0.5, metrics.stage_height * 0.55)
	stage.add_child(art)
	if role == "player":
		player_art = art
	elif role == "enemy":
		enemy_art = art
	var nameplate := Label.new()
	nameplate.text = text
	nameplate.add_theme_font_size_override("font_size", 18 if role == "player" else 17)
	nameplate.add_theme_color_override("font_color", Color(0.78, 0.58, 0.32, 1.0) if role == "player" else Color(0.82, 0.38, 0.32, 1.0))
	nameplate.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.01, 0.98))
	nameplate.add_theme_constant_override("outline_size", 2)
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
	var label := UiFactory.body_label("", 13, Color("#d8dde8"))
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
		var enemy_color := Color("#c8342f")
		UiFactory.apply_stat_bar(health_bar, enemy_color)
		var health_preview := ProgressBar.new()
		health_preview.show_percentage = false
		health_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_preview.visible = false
		health_preview.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		health_preview.offset_left = 70
		health_preview.offset_right = -70
		health_preview.offset_top = -44
		health_preview.offset_bottom = -20
		UiFactory.apply_stat_bar(health_preview, enemy_color.darkened(0.28))
		health_preview.modulate = Color(1.0, 1.0, 1.0, 0.48)
		stage.add_child(health_preview)
		stage.move_child(health_preview, health_bar.get_index())
		enemy_health_bar_entry = {"bar": health_bar, "preview": health_preview, "color": enemy_color}
	return wrapper


func _build_bottom_overlay(root: VBoxContainer) -> void:
	var metrics: Dictionary = _combat_layout_metrics()
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = metrics.overlay_height
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	var player_column := VBoxContainer.new()
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_column.size_flags_stretch_ratio = 3
	player_column.add_theme_constant_override("separation", 4)
	_build_actor_card(player_column, metrics)
	row.add_child(UiFactory.framed_column("SPIELER", player_column, true))
	var backpack_column := VBoxContainer.new()
	backpack_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_column.size_flags_stretch_ratio = 2
	backpack_column.add_theme_constant_override("separation", 4)
	_build_backpack_panel(backpack_column, metrics)
	row.add_child(UiFactory.framed_column("RUCKSACK", backpack_column, true))
	var turn_column := VBoxContainer.new()
	turn_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_column.size_flags_stretch_ratio = 4
	turn_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	turn_column.add_theme_constant_override("separation", 4)
	_build_turn_panel(turn_column, metrics)
	row.add_child(UiFactory.framed_column("KAMPFLOG", turn_column, true))


func _build_actor_card(parent: VBoxContainer, metrics: Dictionary) -> void:
	var box := parent
	box.add_theme_constant_override("separation", 6)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var portrait := TextureRect.new()
	portrait.texture = load(player_art_path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(metrics.portrait, metrics.portrait)
	header.add_child(portrait)
	actor_card_portrait = portrait
	var header_right := VBoxContainer.new()
	header_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_right.add_theme_constant_override("separation", 3)
	header.add_child(header_right)
	actor_summary_label = UiFactory.ornate_muted_label("", 13, true)
	actor_summary_label.add_theme_font_size_override("font_size", metrics.font_stats + 1)
	actor_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_right.add_child(actor_summary_label)
	_add_resource_bar(header_right, "health", "Leben", UiFactory.stat_bar_color("health"), metrics)
	_add_resource_bar(header_right, "stamina", "Ausdauer", UiFactory.stat_bar_color("stamina"), metrics)
	_add_resource_bar(header_right, "ap", "Aktionspunkte", Color("#58a6ff"), metrics)
	_add_resource_bar(header_right, "xp", "Erfahrung", UiFactory.stat_bar_color("xp"), metrics)
	box.add_child(UiFactory.ornate_section_label("AKTIONEN"))
	_build_action_buttons(box, metrics)


func _build_action_buttons(parent: VBoxContainer, metrics: Dictionary) -> void:
	action_host = VBoxContainer.new()
	action_host.add_theme_constant_override("separation", 6)
	parent.add_child(action_host)
	heal_item_bar = PanelContainer.new()
	heal_item_bar.visible = false
	heal_item_bar.add_theme_stylebox_override("panel", UiFactory.ornate_panel_style(true))
	action_host.add_child(heal_item_bar)
	var heal_margin := MarginContainer.new()
	heal_margin.add_theme_constant_override("margin_left", 8)
	heal_margin.add_theme_constant_override("margin_right", 8)
	heal_margin.add_theme_constant_override("margin_top", 6)
	heal_margin.add_theme_constant_override("margin_bottom", 6)
	heal_item_bar.add_child(heal_margin)
	heal_item_row = HBoxContainer.new()
	heal_item_row.add_theme_constant_override("separation", 6)
	heal_margin.add_child(heal_item_row)
	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 10)
	action_host.add_child(actions_row)
	attack_button = _create_action_slot(actions_row, COMBAT_ATTACK_ICON, "Angreifen", ATTACK_AP_COST, _attack, metrics, CombatUiStyles.GOLD_BORDER, {"ap": -ATTACK_AP_COST}, Callable(self, "_estimate_attack_damage_on_hit"))
	action_buttons.append(attack_button)
	defend_button = _create_action_slot(actions_row, COMBAT_DEFEND_ICON, "Deckung", DEFEND_AP_COST, _defend, metrics, CombatUiStyles.GOLD_BORDER, {"ap": -DEFEND_AP_COST, "stamina": -4.0})
	action_buttons.append(defend_button)
	bandage_button = _create_action_slot(actions_row, COMBAT_HEAL_ICON, "Heilen", BANDAGE_AP_COST, _toggle_heal_item_bar, metrics, Color("#79d36b"), {"ap": -BANDAGE_AP_COST})
	action_buttons.append(bandage_button)
	flee_button = _create_action_slot(actions_row, COMBAT_FLEE_ICON, "Flucht", FLEE_AP_COST, _flee, metrics, Color("#d9685f"), {"ap": -FLEE_AP_COST, "stamina": -18.0, "health": -5.0})
	action_buttons.append(flee_button)


func _create_action_slot(
	parent: HBoxContainer,
	icon_path: String,
	label: String,
	ap_cost: int,
	callback: Callable,
	metrics: Dictionary,
	accent: Color = CombatUiStyles.GOLD_BORDER,
	preview_deltas: Dictionary = {},
	enemy_damage_resolver: Callable = Callable()
) -> Button:
	var slot_stack := VBoxContainer.new()
	slot_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_stack.add_theme_constant_override("separation", 3)
	parent.add_child(slot_stack)
	var hover_zone := Control.new()
	hover_zone.custom_minimum_size = metrics.action_square
	hover_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	hover_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot_stack.add_child(hover_zone)
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "%s (%d AP)" % [label, ap_cost]
	button.icon = load(icon_path) as Texture2D
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", int(metrics.action_square.x) - 12)
	button.add_theme_constant_override("icon_max_height", int(metrics.action_square.y) - 12)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CombatUiStyles.apply_square_slot_button(button, accent)
	var preview_source := "action_%s" % label
	_wire_combat_preview_hover(hover_zone, preview_source, preview_deltas.duplicate(), enemy_damage_resolver)
	hover_zone.gui_input.connect(func(event: InputEvent) -> void:
		if button.disabled:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_button_click()
			callback.call()
			hover_zone.accept_event()
	)
	hover_zone.add_child(button)
	var ap_badge := Label.new()
	ap_badge.text = "%d AP" % ap_cost
	ap_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap_badge.add_theme_font_size_override("font_size", metrics.font_action)
	ap_badge.add_theme_color_override("font_color", Color("#d8b36a"))
	slot_stack.add_child(ap_badge)
	var caption := UiFactory.ornate_muted_label(label, metrics.font_action, false)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_stack.add_child(caption)
	return button


func _wire_combat_preview_hover(
	target: Control,
	source: String,
	deltas: Dictionary,
	enemy_damage_resolver: Callable = Callable()
) -> void:
	target.mouse_entered.connect(func() -> void:
		var enemy_damage := -1.0
		var hit_chance := -1.0
		if enemy_damage_resolver.is_valid():
			var hit: Dictionary = enemy_damage_resolver.call()
			enemy_damage = float(hit.get("damage", -1.0))
			hit_chance = float(hit.get("chance", -1.0))
		_set_combat_preview(source, deltas, enemy_damage, hit_chance)
	)
	target.mouse_exited.connect(func() -> void:
		_clear_combat_preview(source)
	)


func _toggle_heal_item_bar() -> void:
	if not _is_party_turn():
		return
	if not is_instance_valid(heal_item_bar):
		return
	if heal_item_bar.visible:
		_hide_heal_item_bar()
		return
	_refresh_heal_item_bar()
	if heal_item_row.get_child_count() == 0:
		_set_combat_log("Keine heilenden Gegenstaende im Rucksack.")
		return
	heal_item_bar.visible = true


func _hide_heal_item_bar() -> void:
	if is_instance_valid(heal_item_bar):
		heal_item_bar.visible = false


func _refresh_heal_item_bar() -> void:
	if not is_instance_valid(heal_item_row):
		return
	UiFactory.clear_container(heal_item_row)
	var metrics: Dictionary = _combat_layout_metrics()
	for item_id in InventorySystem.healing_combat_items():
		var data: Dictionary = DataCatalog.item(item_id)
		var amount: int = InventorySystem.backpack_count(item_id)
		var cost: int = InventorySystem.combat_item_action_points(item_id)
		var slot := _create_heal_item_slot(
			str(data.get("icon", COMBAT_HEAL_ICON)),
			"%s x%d (%d AP)" % [data.get("name", item_id), amount, cost],
			cost,
			item_id,
			metrics
		)
		heal_item_row.add_child(slot)


func _create_heal_item_slot(icon_path: String, tooltip: String, ap_cost: int, item_id: String, metrics: Dictionary) -> Control:
	var slot_root := Control.new()
	slot_root.custom_minimum_size = Vector2(metrics.action_square.x - 4.0, metrics.action_square.y - 4.0)
	slot_root.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.disabled = player_action_points < ap_cost
	button.icon = load(icon_path) as Texture2D
	button.expand_icon = true
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CombatUiStyles.apply_square_slot_button(button, Color("#79d36b"))
	var preview_source := "heal_%s" % item_id
	_wire_combat_preview_hover(slot_root, preview_source, _item_preview_deltas(item_id))
	slot_root.gui_input.connect(func(event: InputEvent) -> void:
		if button.disabled:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_button_click()
			_hide_heal_item_bar()
			_use_inventory_item_in_combat(item_id)
			slot_root.accept_event()
	)
	slot_root.add_child(button)
	return slot_root


func _has_healing_items() -> bool:
	return not InventorySystem.healing_combat_items().is_empty()


func _refresh_action_bar() -> void:
	if is_instance_valid(attack_button):
		var weapon_id := InventorySystem.preferred_weapon()
		var weapon_data := DataCatalog.item(weapon_id)
		if not weapon_data.is_empty():
			attack_button.icon = load(str(weapon_data.get("icon", COMBAT_ATTACK_ICON))) as Texture2D
		else:
			attack_button.icon = load(COMBAT_ATTACK_ICON) as Texture2D
	_refresh_heal_item_bar()
	if is_instance_valid(heal_item_bar) and heal_item_bar.visible and heal_item_row.get_child_count() == 0:
		_hide_heal_item_bar()


func _add_resource_bar(parent: VBoxContainer, key: String, title: String, color: Color, metrics: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	if UiFactory.STAT_ICON_PATHS.has(key):
		var icon := TextureRect.new()
		icon.texture = load(UiFactory.stat_icon_path(key))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		icon.tooltip_text = title
		row.add_child(icon)
	else:
		var label := UiFactory.body_label(title, metrics.font_stats, UiFactory.COLOR_MUTED)
		label.custom_minimum_size.x = 74
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(label)
	var value_label := UiFactory.body_label("", metrics.font_stats, Color("#d8dde8"))
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 12)
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
	var entry := {"bar": bar, "label": value_label, "color": color}
	var wrapped := UiFactory.attach_stat_bar_preview(bar, color)
	entry["preview"] = wrapped.get("preview")
	entry["layer"] = wrapped.get("layer")
	player_stat_bars[key] = entry


func _ui_actor_id() -> String:
	return "companion" if active_actor_id == "companion" else "player"


func _stats_for_actor(actor_id: String) -> Dictionary:
	if actor_id == "companion":
		return GameState.effective_companion_stats()
	return GameState.effective_player_stats()


func _combat_bar_current(key: String) -> float:
	var actor_id := _ui_actor_id()
	match key:
		"ap":
			return float(player_action_points)
		"xp":
			if actor_id == "companion":
				return float(GameState.companion_stats().get("xp", 0.0))
			return float(GameState.player_stats.get("xp", 0.0))
		"health":
			if actor_id == "companion":
				return companion_combat_health
			return float(GameState.player_stats.get("health", 0.0))
		"stamina", "energy":
			if actor_id == "companion":
				return float(GameState.companion_stats().get(key, 0.0))
			return float(GameState.player_stats.get(key, 0.0))
		_:
			if actor_id == "companion":
				return float(GameState.companion_stats().get(key, 0.0))
			return float(GameState.player_stats.get(key, 0.0))


func _combat_bar_maximum(key: String, current: float) -> float:
	var actor_id := _ui_actor_id()
	match key:
		"ap":
			return float(PLAYER_ACTION_POINTS_PER_TURN)
		"xp":
			if actor_id == "companion":
				return float(GameState.companion_stats().get("next_xp", 60.0))
			return float(GameState.player_stats.get("next_xp", 60.0))
		"health", "stamina", "energy":
			if actor_id == "companion":
				var effective := GameState.effective_companion_stats()
				if key == "health":
					return float(effective.get("max_health", 100.0))
				return maxf(float(effective.get("max_%s" % key, 100.0)), current)
			return maxf(GameState.max_resource(key), current)
		_:
			return maxf(current, 1.0)


func _project_combat_value(key: String, current: float, maximum: float) -> float:
	if not combat_preview_deltas.has(key):
		return -1.0
	var projected := current + float(combat_preview_deltas[key])
	if key == "ap":
		return clampf(projected, 0.0, maximum)
	return clampf(projected, 0.0, maximum)


func _set_combat_preview(
	source: String,
	deltas: Dictionary,
	enemy_damage: float = -1.0,
	hit_chance: float = -1.0
) -> void:
	if not _is_party_turn():
		return
	combat_preview_source = source
	combat_preview_deltas = deltas.duplicate()
	combat_enemy_damage_preview = enemy_damage
	combat_enemy_hit_chance = hit_chance
	var hud_deltas := deltas.duplicate()
	hud_deltas.erase("ap")
	if hud_deltas.is_empty():
		_hud_stat_preview().clear()
	else:
		_hud_stat_preview().apply_deltas(hud_deltas)
	_refresh_combat_bar_previews()
	_refresh_enemy_health_preview()


func _clear_combat_preview(source: String) -> void:
	if not source.is_empty() and combat_preview_source != source:
		return
	combat_preview_source = ""
	combat_preview_deltas = {}
	combat_enemy_damage_preview = -1.0
	combat_enemy_hit_chance = -1.0
	_hud_stat_preview().clear()
	_refresh_combat_bar_previews()
	_refresh_enemy_health_preview()


func _hud_stat_preview() -> HudStatPreviewNode:
	return get_node("/root/HudStatPreview") as HudStatPreviewNode


func _refresh_combat_bar_previews() -> void:
	for key in player_stat_bars:
		var entry: Dictionary = player_stat_bars[key]
		var current := _combat_bar_current(key)
		var maximum := _combat_bar_maximum(key, current)
		var projected := _project_combat_value(key, current, maximum)
		UiFactory.update_stat_bar_preview(entry, current, maximum, projected)


func _item_preview_deltas(item_id: String) -> Dictionary:
	var deltas := {"ap": -float(InventorySystem.combat_item_action_points(item_id))}
	var effects: Dictionary = DataCatalog.item(item_id).get("effects", {})
	for stat_name in effects:
		deltas[str(stat_name)] = float(effects[stat_name])
	return deltas


func _ability_preview_deltas(ability_id: String) -> Dictionary:
	var data := _ability_data(ability_id)
	if data.is_empty():
		return {}
	var deltas := {
		"ap": -float(_ability_ap_cost(ability_id)),
		"stamina": -float(data.get("stamina_cost", 0.0)),
		"energy": -float(data.get("energy_cost", 0.0)),
	}
	var effect := str(data.get("effect", ""))
	var power := _ability_value(data)
	if effect in ["heal", "cleanse_heal", "heal_shield", "triage"]:
		deltas["health"] = power
	elif effect == "damage_heal":
		deltas["health"] = power * float(data.get("heal_ratio", 0.45))
	if effect in ["heal_shield", "shield", "shield_defend", "damage_shield_defend", "cleanse_shield"]:
		deltas["shield"] = float(data.get("shield", power * 0.5))
	return deltas


func _estimate_attack_damage_on_hit() -> Dictionary:
	for item_id in InventorySystem.attack_candidates():
		var data := DataCatalog.item(item_id)
		if data.is_empty():
			continue
		var ammo_id := str(data.get("ammo", ""))
		var ranged := not ammo_id.is_empty()
		var ammo_cost := int(data.get("ammo_cost", 1))
		if ranged and not InventorySystem.has_items({ammo_id: ammo_cost}):
			continue
		var attacker_stats := _active_stats()
		var defender_stats := RpgRules.enemy_stats(enemy)
		var damage := float(data.get("damage", 7.0)) * (0.62 + InventorySystem.condition_ratio(item_id) * 0.38)
		damage += float(attacker_stats.get("ranged_power" if ranged else "melee_power", 0.0))
		var damage_type := str(data.get("damage_type", "ranged" if ranged else "physical"))
		var damage_result := RpgRules.calculate_damage(damage, damage_type, attacker_stats, defender_stats, {
			"resistance_pierce": float(data.get("armor_pierce", 0.0)) + float(attacker_stats.get("armor_pierce", 0.0))
		})
		damage = float(damage_result.get("damage", damage))
		var chance := _success_chance("ranged" if ranged else "melee", data)
		return {"damage": damage, "chance": chance}
	var fallback := 5.0 + float(_active_stats().get("melee_power", 0.0))
	return {"damage": fallback, "chance": _success_chance("melee")}


func _estimate_ability_damage_on_hit(ability_id: String) -> Dictionary:
	var data := _ability_data(ability_id)
	if data.is_empty():
		return {"damage": -1.0, "chance": -1.0}
	var effect := str(data.get("effect", ""))
	if effect not in ["damage", "damage_defend", "snare", "material_damage", "damage_heal", "damage_shield_defend"]:
		return {"damage": -1.0, "chance": -1.0}
	var value := _ability_value(data)
	if effect == "material_damage":
		var item_cost: Dictionary = data.get("item_cost", {})
		if not item_cost.is_empty() and InventorySystem.has_items(item_cost):
			value += float(data.get("bonus_power", 0.0))
	var damage_type := str(data.get("damage_type", "explosive" if effect == "material_damage" else "physical"))
	var damage_result := RpgRules.calculate_damage(
		value,
		damage_type,
		_active_stats(),
		RpgRules.enemy_stats(enemy)
	)
	return {
		"damage": float(damage_result.get("damage", value)),
		"chance": _success_chance("ability", data),
	}


func _refresh_enemy_health_preview() -> void:
	if not is_instance_valid(enemy_health_bar):
		return
	var current := maxf(0.0, enemy_health)
	var maximum := enemy_max_health
	var projected := -1.0
	if combat_enemy_damage_preview >= 0.0:
		projected = maxf(0.0, current - combat_enemy_damage_preview)
	if not enemy_health_bar_entry.is_empty():
		UiFactory.update_stat_bar_preview(enemy_health_bar_entry, current, maximum, projected)
	else:
		enemy_health_bar.max_value = maximum
		enemy_health_bar.value = current
	var enemy_name := str(enemy.get("name", "Gegner"))
	if projected >= 0.0 and combat_enemy_damage_preview > 0.0:
		var tip := "%s: %.0f -> %.0f / %.0f" % [enemy_name, current, projected, maximum]
		if combat_enemy_hit_chance >= 0.0:
			tip += "\nBei Treffer (%s): -%.0f Schaden" % [_chance_text(combat_enemy_hit_chance), combat_enemy_damage_preview]
		else:
			tip += "\nBei Treffer: -%.0f Schaden" % combat_enemy_damage_preview
		enemy_health_bar.tooltip_text = tip
		if is_instance_valid(enemy_label):
			enemy_label.text = "Leben %.0f -> %.0f  |  -%.0f Schaden  |  Treffer %s" % [
				current,
				projected,
				combat_enemy_damage_preview,
				_chance_text(combat_enemy_hit_chance) if combat_enemy_hit_chance >= 0.0 else "?"
			]
	else:
		enemy_health_bar.tooltip_text = "%s: %.0f / %.0f" % [enemy_name, current, maximum]


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
	var projected := _project_combat_value(key, value, maximum)
	if projected >= 0.0 and not is_equal_approx(value, projected):
		label.text = "%.0f -> %.0f" % [value, projected] if key != "ap" else "%d -> %d" % [int(value), int(projected)]
	UiFactory.update_stat_bar_preview(entry, value, maximum, projected)


func _pulse_resource_bar(key: String) -> void:
	if not player_stat_bars.has(key):
		return
	var bar := player_stat_bars[key].get("bar") as ProgressBar
	if not is_instance_valid(bar):
		return
	var tween := create_tween()
	tween.tween_property(bar, "scale", Vector2(1.018, 1.28), 0.07)
	tween.tween_property(bar, "scale", Vector2.ONE, 0.12)


func _build_backpack_panel(parent: VBoxContainer, metrics: Dictionary) -> void:
	var box := parent
	box.add_theme_constant_override("separation", 6)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	inventory_button = Button.new()
	inventory_button.custom_minimum_size = Vector2(40, 40)
	inventory_button.icon = load("res://assets/items/backpacks/small_backpack.svg")
	inventory_button.expand_icon = true
	inventory_button.focus_mode = Control.FOCUS_NONE
	inventory_button.tooltip_text = "Inventar oeffnen (I)"
	inventory_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CombatUiStyles.apply_icon_button(inventory_button)
	UiFactory.wire_button_sound(inventory_button)
	inventory_button.pressed.connect(open_inventory)
	header.add_child(inventory_button)
	backpack_status_label = UiFactory.ornate_muted_label("", 12, true)
	backpack_status_label.add_theme_font_size_override("font_size", metrics.font_stats)
	backpack_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(backpack_status_label)
	box.add_child(UiFactory.ornate_section_label("SCHNELLZUGRIFF"))
	backpack_grid = GridContainer.new()
	backpack_grid.columns = 8
	backpack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_grid.add_theme_constant_override("h_separation", 4)
	backpack_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(backpack_grid)
	ability_class_label = UiFactory.ornate_muted_label("%s — Faehigkeiten 1-9" % GameState.player_class_name(), metrics.font_stats + 1, false)
	ability_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ability_class_label)
	ability_bar = GridContainer.new()
	ability_bar.columns = 9
	ability_bar.add_theme_constant_override("h_separation", 4)
	ability_bar.add_theme_constant_override("v_separation", 4)
	box.add_child(ability_bar)


func _new_combat_log_rich_label(metrics: Dictionary) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", metrics.log_font)
	label.add_theme_font_size_override("bold_font_size", metrics.log_heading_font)
	label.add_theme_constant_override("line_separation", 5)
	label.add_theme_color_override("default_color", Color("#e2e8f2"))
	return label


func _build_turn_panel(parent: VBoxContainer, metrics: Dictionary) -> void:
	var box := parent
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	active_avatar = TextureRect.new()
	active_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	active_avatar.custom_minimum_size = Vector2(metrics.portrait, metrics.portrait)
	row.add_child(active_avatar)
	turn_label = UiFactory.ornate_heading("", 16)
	turn_label.add_theme_font_size_override("font_size", 15 if metrics.compact else 16)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(turn_label)
	combat_summary_label = _new_combat_log_rich_label(metrics)
	combat_summary_label.name = "CombatSummary"
	combat_overview_box = VBoxContainer.new()
	combat_overview_box.add_theme_constant_override("separation", 6)
	combat_overview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_overview_box.add_child(combat_summary_label)
	combat_debuff_row = HFlowContainer.new()
	combat_debuff_row.add_theme_constant_override("h_separation", 6)
	combat_debuff_row.add_theme_constant_override("v_separation", 4)
	combat_debuff_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_debuff_row.visible = false
	combat_overview_box.add_child(combat_debuff_row)
	var overview_frame := UiFactory.framed_column("KAMPFUEBERSICHT", combat_overview_box, true)
	overview_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(overview_frame)
	log_label = _new_combat_log_rich_label(metrics)
	log_label.name = "CombatLog"
	var log_scroll := UiFactory.scroll_wrap_fill(log_label)
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.custom_minimum_size.y = 72
	var feed_frame := UiFactory.framed_column("VERLAUF", log_scroll, true)
	feed_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(feed_frame)
	var hint := UiFactory.ornate_muted_label("Leertaste: Runde | 1-9: Skills | I: Inventar | B/K/Esc: Menues", 10, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


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
	if is_instance_valid(inventory_button):
		inventory_button.tooltip_text = "Inventar (I)\n%d/%d Plaetze\n%.1f / %.1f kg" % [
			InventorySystem.used_slots(),
			InventorySystem.slot_capacity,
			InventorySystem.current_weight(),
			InventorySystem.max_weight
		]
	UiFactory.clear_container(backpack_grid)
	var visible_slots := InventorySystem.QUICK_SLOT_COUNT
	backpack_grid.columns = visible_slots
	for index in range(visible_slots):
		backpack_grid.add_child(_combat_slot_frame(index))
	_refresh_ability_bar()


func _refresh_actor_overlay() -> void:
	var ui_actor := _ui_actor_id()
	if is_instance_valid(actor_card_portrait):
		actor_card_portrait.texture = load(_actor_portrait_path(ui_actor))
	if is_instance_valid(actor_summary_label):
		if ui_actor == "companion":
			actor_summary_label.text = "%s\n%s  Level %d" % [
				_actor_name("companion"),
				GameState.companion_class_name(),
				int(GameState.companion_stats().get("level", 1))
			]
		else:
			actor_summary_label.text = "%s\n%s  Level %d" % [
				GameState.player_name,
				GameState.player_class_name(),
				int(GameState.player_stats.get("level", 1))
			]
	var effective := _stats_for_actor(ui_actor)
	var health := companion_combat_health if ui_actor == "companion" else float(GameState.player_stats.get("health", 0.0))
	var max_health := float(effective.get("max_health", 100.0))
	var stamina := float(GameState.companion_stats().get("stamina", 0.0)) if ui_actor == "companion" else float(GameState.player_stats.get("stamina", 0.0))
	var max_stamina := float(effective.get("max_stamina", 100.0))
	var xp := float(GameState.player_stats.get("xp", 0.0))
	var next_xp := float(GameState.player_stats.get("next_xp", 60.0))
	if ui_actor == "companion":
		xp = float(GameState.companion_stats().get("xp", 0.0))
		next_xp = float(GameState.companion_stats().get("next_xp", 60.0))
	_set_resource_bar("health", health, max_health, "%.0f/%.0f" % [health, max_health])
	_set_resource_bar("stamina", stamina, max_stamina, "%.0f/%.0f" % [stamina, max_stamina])
	_set_resource_bar("ap", float(player_action_points), float(PLAYER_ACTION_POINTS_PER_TURN), "%d/%d" % [player_action_points, PLAYER_ACTION_POINTS_PER_TURN])
	_set_resource_bar("xp", xp, next_xp, "%d/%d" % [int(xp), int(next_xp)])
	_refresh_combat_bar_previews()


func _refresh_equipment_grid() -> void:
	if not is_instance_valid(equipment_grid):
		return
	UiFactory.clear_container(equipment_grid)
	for slot in ["firearm", "melee", "tool", "throwable", "shield", "head", "vest", "jacket", "pants", "gloves", "shoes", "mask", "backpack_slot"]:
		if slot == "backpack_slot":
			equipment_grid.add_child(_backpack_slot_frame())
		else:
			equipment_grid.add_child(_equipment_slot_frame(slot))


func _backpack_slot_frame() -> PanelContainer:
	var item_id := InventorySystem.equipped_backpack_id
	var metrics: Dictionary = _combat_layout_metrics()
	var panel: PanelContainer = InventorySlotScript.new()
	panel.custom_minimum_size = metrics.slot_size
	panel.configure("backpack_slot", "backpack", item_id, true, false)
	panel.item_dropped.connect(_on_combat_item_dropped)
	panel.decorate(1, false, "Rucksack")
	panel.tooltip_text = "Rucksack: %s" % InventorySystem.backpack_data().get("name", item_id)
	return panel


func _equipment_slot_frame(slot: String) -> PanelContainer:
	var item_id := InventorySystem.equipped_item(slot)
	var blocked := InventorySystem.is_slot_blocked(slot)
	var metrics: Dictionary = _combat_layout_metrics()
	return _inventory_slot("equipment", slot, item_id, metrics.slot_size, 1, blocked)


func _combat_slot_frame(index: int) -> PanelContainer:
	var ids := InventorySystem.quick_slot_items()
	var item_id := str(ids[index]) if index < ids.size() else ""
	var amount := int(InventorySystem.items.get(item_id, 1)) if not item_id.is_empty() else 0
	var metrics: Dictionary = _combat_layout_metrics()
	var quick_size := Vector2(metrics.slot_size.x + 4.0, metrics.slot_size.y + 4.0)
	return _inventory_slot("combat_quick", str(index), item_id, quick_size, amount)


func _inventory_slot(source: String, key: String, item_id: String, panel_size: Vector2, amount: int = 1, blocked: bool = false) -> PanelContainer:
	var panel: PanelContainer = InventorySlotScript.new()
	panel.custom_minimum_size = panel_size
	panel.configure(source, key, item_id, not blocked, not item_id.is_empty() and not blocked)
	panel.item_dropped.connect(_on_combat_item_dropped)
	panel.slot_clicked.connect(_on_combat_slot_clicked)
	if item_id.is_empty():
		if source == "equipment":
			var slot_name := str(InventorySystem.EQUIPMENT_SLOTS.get(key, {}).get("name", key))
			panel.tooltip_text = InventorySystem.slot_block_reason(key) if blocked else "%s: leer" % slot_name
			if blocked:
				panel.add_theme_stylebox_override("panel", _blocked_slot_style())
		elif source in ["combat_quick", "loot_backpack"]:
			panel.tooltip_text = "Schnellzugriff %s" % (str(int(key) + 1) if source == "combat_quick" else "leer")
		return panel
	panel.decorate(amount, false, str(InventorySystem.EQUIPMENT_SLOTS.get(key, {}).get("name", key)) if source == "equipment" else "Kampf")
	if source in ["combat_quick", "loot_backpack"] and not item_id.is_empty():
		_add_combat_condition_strip(panel, item_id)
	return panel


func _blocked_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.011, 0.013, 0.72)
	style.border_color = Color(0.29, 0.30, 0.33, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _on_combat_item_dropped(target_source: String, target_key: String, item_id: String, source: String, source_key: String) -> void:
	if item_id.is_empty():
		return
	var message := ItemDragDrop.apply_drop(target_source, target_key, ItemDragDrop.make_payload(source, source_key, item_id))
	if not message.is_empty() and is_instance_valid(loot_feedback_label):
		loot_feedback_label.text = message
		enemy_loot = GameState.transient_loot.duplicate(true)
		_refresh_loot_menu()
	_refresh()


func _on_combat_slot_clicked(source: String, _key: String, item_id: String, event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or item_id.is_empty():
		return
	if source == "combat_quick":
		_use_inventory_item_in_combat(item_id)
	elif source == "enemy_loot" and event.double_click:
		_take_enemy_loot(item_id, 1)


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
	if is_instance_valid(ability_class_label):
		if active_actor_id == "companion":
			ability_class_label.text = "%s — Faehigkeiten 1-9" % GameState.companion_class_name()
		else:
			ability_class_label.text = "%s — Faehigkeiten 1-9" % GameState.player_class_name()
	UiFactory.clear_container(ability_bar)
	ability_buttons.clear()
	for index in range(GameState.MAX_EQUIPPED_ABILITIES):
		var ability_id := _equipped_ability_id(index)
		ability_bar.add_child(_ability_slot_button(index, ability_id))


func _ability_slot_button(index: int, ability_id: String) -> Control:
	var metrics: Dictionary = _combat_layout_metrics()
	var data := _ability_data(ability_id)
	var cooldown_left := int(ability_cooldowns.get(ability_id, 0)) if not ability_id.is_empty() else 0
	var disabled := ability_id.is_empty() or not _is_party_turn() or not _can_pay_ability(ability_id)
	var on_cooldown := cooldown_left > 0
	var frame := Control.new()
	frame.custom_minimum_size = metrics.ability_square
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.tooltip_text = _ability_tooltip_with_state(ability_id) if not ability_id.is_empty() else "Slot %d — leer" % (index + 1)
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.disabled = disabled or on_cooldown
	if data.is_empty():
		CombatUiStyles.apply_square_slot_button(button, CombatUiStyles.GOLD_BORDER, true, false)
	else:
		var accent := Color(str(data.get("color", "#c8a060")))
		var texture := load(str(data.get("icon", ""))) as Texture2D
		if texture:
			button.icon = texture
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", int(metrics.ability_square.x) - 10)
			button.add_theme_constant_override("icon_max_height", int(metrics.ability_square.y) - 10)
		CombatUiStyles.apply_square_slot_button(button, accent, disabled, on_cooldown)
		ability_buttons[ability_id] = button
	frame.add_child(button)
	var key_label := Label.new()
	key_label.text = str(index + 1)
	key_label.add_theme_font_size_override("font_size", metrics.font_ability + 1)
	key_label.add_theme_color_override("font_color", Color("#f0c890"))
	key_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.01, 0.95))
	key_label.add_theme_constant_override("outline_size", 2)
	key_label.position = Vector2(5, 3)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(key_label)
	if on_cooldown:
		var cd_label := Label.new()
		cd_label.text = "CD %d" % cooldown_left
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", metrics.font_ability)
		cd_label.add_theme_color_override("font_color", Color("#d8a8ff"))
		cd_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		cd_label.offset_top = -16
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(cd_label)
	if not ability_id.is_empty():
		_wire_combat_preview_hover(
			frame,
			"ability_%s" % ability_id,
			_ability_preview_deltas(ability_id),
			func() -> Dictionary: return _estimate_ability_damage_on_hit(ability_id)
		)
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if button.disabled:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_button_click()
			_use_hotbar_ability(index)
			frame.accept_event()
	)
	return frame


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
	GameState.transient_loot = enemy_loot.duplicate(true)
	if is_instance_valid(loot_overlay):
		loot_overlay.queue_free()
	loot_overlay = ColorRect.new()
	loot_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	loot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(loot_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact := UiFactory.is_compact_screen(self)
	var margins := UiFactory.screen_margins(self, compact)
	margin.add_theme_constant_override("margin_left", margins.left)
	margin.add_theme_constant_override("margin_right", margins.right)
	margin.add_theme_constant_override("margin_top", margins.top)
	margin.add_theme_constant_override("margin_bottom", margins.bottom)
	loot_overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiFactory.ornate_panel_style(true))
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := UiFactory.ornate_heading("%s BESIEGT" % str(enemy.get("name", "GEGNER")).to_upper(), 28 if not compact else 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var take_all := UiFactory.button("Alles nehmen", _take_all_enemy_loot, 170)
	header.add_child(take_all)
	var close := UiFactory.button("Weiter", _finish_loot_and_leave, 130, AudioManager.UiClickKind.CONFIRM)
	header.add_child(close)
	loot_feedback_label = UiFactory.ornate_muted_label("Waehle Beute aus. Bei Ausruestung siehst du vorher/nachher sofort.", 14, true)
	root.add_child(loot_feedback_label)
	root.add_child(UiFactory.rarity_legend())
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10 if compact else 12)
	root.add_child(body)
	body.add_child(UiFactory.framed_column("RUCKSACK", _build_loot_backpack_side(), true))
	body.add_child(UiFactory.framed_column("GEGNER-BEUTE", _build_loot_enemy_side(), true))
	body.add_child(UiFactory.framed_column("VERGLEICH", _build_loot_compare_side(), true))
	_refresh_loot_menu()


func _build_loot_backpack_side() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 300.0 if UiFactory.is_compact_screen(self) else 330.0
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
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
	loot_backpack_status_label = UiFactory.ornate_muted_label("", 14, true)
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
	box.custom_minimum_size.x = 340.0 if UiFactory.is_compact_screen(self) else 390.0
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	enemy_loot_grid = VBoxContainer.new()
	enemy_loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_loot_grid.add_theme_constant_override("separation", 8)
	var loot_scroll := UiFactory.scroll_wrap_fill(enemy_loot_grid)
	loot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(loot_scroll)
	return box


func _build_loot_compare_side() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 260.0 if UiFactory.is_compact_screen(self) else 300.0
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	loot_compare_label = RichTextLabel.new()
	loot_compare_label.bbcode_enabled = true
	loot_compare_label.fit_content = false
	loot_compare_label.scroll_active = true
	loot_compare_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_compare_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_compare_label.custom_minimum_size = Vector2(UiFactory.viewport_size(self).x * 0.16, UiFactory.viewport_size(self).y * 0.28)
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
		var item_id := str(item_ids[index]) if index < item_ids.size() else ""
		var amount := int(InventorySystem.items.get(item_id, 1)) if not item_id.is_empty() else 0
		var slot := _inventory_slot("loot_backpack", str(index), item_id, Vector2(54, 54), amount)
		if not item_id.is_empty():
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
	row.add_child(_inventory_slot("enemy_loot", item_id, item_id, Vector2(52, 52), amount))
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
	AudioManager.play_button_click(AudioManager.UiClickKind.CONFIRM)
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
	GameState.transient_loot = enemy_loot.duplicate(true)


func _finish_loot_and_leave() -> void:
	GameState.transient_loot.clear()
	if is_instance_valid(loot_overlay):
		loot_overlay.queue_free()
	TimeSystem.advance(1)
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		go_to(GameState.return_scene)


func _close_scene_popup() -> bool:
	if is_instance_valid(loot_overlay):
		_finish_loot_and_leave()
		return true
	return false


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


func _is_party_turn() -> bool:
	return active_actor_id in ["player", "companion"] and turn_state != "ended"


func _active_stats() -> Dictionary:
	if active_actor_id == "companion":
		return GameState.effective_companion_stats()
	return GameState.effective_player_stats()


func _ability_data(ability_id: String) -> Dictionary:
	if active_actor_id == "companion":
		return GameState.companion_ability(ability_id)
	return GameState.ability(ability_id)


func _ability_ap_cost(ability_id: String) -> int:
	if active_actor_id == "companion":
		return GameState.companion_ability_action_points(ability_id)
	return GameState.ability_action_points(ability_id)


func _actor_stamina() -> float:
	if active_actor_id == "companion":
		return float(GameState.companion_stats().get("stamina", 0.0))
	return float(GameState.player_stats.get("stamina", 0.0))


func _actor_energy() -> float:
	if active_actor_id == "companion":
		return float(GameState.companion_stats().get("energy", 0.0))
	return float(GameState.player_stats.get("energy", 0.0))


func _change_actor_stat(stat_name: String, amount: float) -> void:
	if active_actor_id == "companion":
		GameState.companion_change_stat(stat_name, amount)
	else:
		GameState.change_stat(stat_name, amount)


func _equipped_ability_id(index: int) -> String:
	if active_actor_id == "companion":
		return GameState.companion_ability_slot_id(index)
	return GameState.ability_slot_id(index)


func _actor_name(actor_id: String) -> String:
	match actor_id:
		"player":
			return GameState.player_name
		"companion":
			return str(GameState.companion.get("name", "Begleiter"))
		"enemy":
			return str(enemy.get("name", "Gegner"))
	return actor_id


func _roll_initiative(stats: Dictionary) -> int:
	return TurnLogic.roll_initiative(stats)


func _build_turn_order() -> void:
	var built := TurnLogic.build_turn_order(
		companion_combat_active,
		companion_combat_health > 0.0,
		GameState.effective_player_stats(),
		GameState.effective_companion_stats(),
		enemy
	)
	turn_order = built.turn_order
	turn_order_initiatives = built.initiatives
	turn_order_index = 0
	var summary: Array[String] = []
	for actor_id in turn_order:
		summary.append("%s (%d)" % [_actor_name(actor_id), int(turn_order_initiatives.get(actor_id, 0))])
	_push_combat_event("Initiative: %s" % ", ".join(summary), "neutral")
	_refresh_turn_order_strip()


func _begin_actor_turn(actor_id: String) -> void:
	if turn_state == "ended":
		return
	active_actor_id = actor_id
	if actor_id == "enemy":
		_begin_enemy_turn()
		return
	turn_state = actor_id
	player_action_points = PLAYER_ACTION_POINTS_PER_TURN
	party_action_points[actor_id] = player_action_points
	ability_cooldowns = actor_ability_cooldowns.get(actor_id, {})
	_tick_ability_cooldowns()
	actor_ability_cooldowns[actor_id] = ability_cooldowns
	_set_active_actor_for_id(actor_id)
	_set_actions_enabled(true)
	_refresh()
	_refresh_turn_order_strip()


func _advance_turn_queue() -> void:
	if turn_state == "ended" or turn_order.is_empty():
		return
	var next := TurnLogic.next_actor(
		turn_order,
		turn_order_index,
		companion_combat_active,
		companion_combat_health
	)
	var next_id := str(next.get("actor_id", ""))
	if next_id.is_empty():
		return
	turn_order_index = int(next.get("index", turn_order_index))
	if bool(next.get("new_round", false)):
		turn += 1
	_begin_actor_turn(next_id)


func _pick_enemy_target() -> String:
	return TurnLogic.pick_enemy_target(
		companion_combat_active,
		companion_combat_health,
		float(GameState.player_stats.get("health", 0.0))
	)


func _set_active_actor_for_id(actor_id: String) -> void:
	var portrait_path := player_art_path
	if actor_id == "companion":
		portrait_path = companion_art_path
	elif actor_id == "enemy":
		portrait_path = enemy_art_path
	active_avatar.texture = load(portrait_path)
	if is_instance_valid(player_art) and actor_id in ["player", "companion"]:
		if player_art.has_method("setup"):
			if actor_id == "player":
				player_art.call(
					"setup",
					GameState.player_gender,
					GameState.player_appearance,
					CharacterVisualContext.Context.COMBAT
				)
			elif GameState.has_companion():
				player_art.call(
					"setup",
					str(GameState.companion.get("gender", "female")),
					str(GameState.companion.get("appearance", "priest")),
					CharacterVisualContext.Context.COMBAT
				)
		elif player_art is TextureRect:
			(player_art as TextureRect).texture = load(
				player_art_path if actor_id == "player" else companion_art_path
			)
	_refresh_turn_text()
	_refresh_turn_badges(actor_id in ["player", "companion"])
	_pulse_turn_banner()
	_refresh_turn_order_strip()


func _begin_player_turn() -> void:
	_begin_actor_turn("player")


func _begin_enemy_turn() -> void:
	_hide_heal_item_bar()
	_hide_skip_turn_confirm()
	active_actor_id = "enemy"
	turn_state = "enemy"
	_set_actions_enabled(false)
	_set_active_actor_for_id("enemy")
	await get_tree().create_timer(0.65).timeout
	if turn_state != "enemy" or not is_inside_tree():
		return
	_enemy_action()
	if turn_state == "enemy":
		_advance_turn_queue()


func _set_active_actor(player_active: bool) -> void:
	_set_active_actor_for_id("player" if player_active else "enemy")


func _set_actions_enabled(enabled: bool) -> void:
	if not enabled:
		_clear_combat_preview("")
	if is_instance_valid(attack_button):
		attack_button.disabled = not enabled or player_action_points < ATTACK_AP_COST
	if is_instance_valid(defend_button):
		defend_button.disabled = not enabled or player_action_points < DEFEND_AP_COST
	if is_instance_valid(bandage_button):
		bandage_button.disabled = not enabled or not _has_healing_items()
	if is_instance_valid(flee_button):
		flee_button.disabled = not enabled or player_action_points < FLEE_AP_COST
	_refresh_ability_bar()


func _spend_combat_action_points(cost: int) -> bool:
	if not _is_party_turn() or player_action_points < cost:
		return false
	player_action_points = maxi(0, player_action_points - cost)
	party_action_points[active_actor_id] = player_action_points
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
	if ability_id.is_empty():
		return ""
	var data := _ability_data(ability_id)
	if data.is_empty():
		return "Unbekannte Faehigkeit"
	var text := GameState.ability_tooltip_text(ability_id, active_actor_id == "companion")
	text += "\nAktuelle Erfolgschance: %s" % _chance_text(_success_chance("ability", data))
	var cooldown_left := int(ability_cooldowns.get(ability_id, 0))
	if cooldown_left > 0:
		text += "\nBereit in: %d Runde(n)" % cooldown_left
	if player_action_points < _ability_ap_cost(ability_id):
		text += "\nNicht genug AP in diesem Zug."
	return text


func _ability_unavailable_text(ability_id: String, data: Dictionary) -> String:
	var cooldown_left := int(ability_cooldowns.get(ability_id, 0))
	if cooldown_left > 0:
		return "%s ist noch %d Runde(n) auf Abklingzeit." % [data.get("name", ability_id), cooldown_left]
	if player_action_points < _ability_ap_cost(ability_id):
		return "Dafuer fehlen Aktionspunkte."
	if _actor_stamina() < float(data.get("stamina_cost", 0.0)):
		return "Dafuer fehlt Ausdauer."
	if _actor_energy() < float(data.get("energy_cost", 0.0)):
		return "Dafuer fehlt Energie."
	return "Diese Faehigkeit ist gerade nicht verfuegbar."


func _success_chance(action_type: String, data: Dictionary = {}) -> float:
	var attacker_stats := _active_stats()
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
			modifier -= float(_ability_ap_cost(str(data.get("id", ""))) - 1) * 2.5
		"defend":
			modifier += float(attacker_stats.get("block_power", 0.0)) * 1.1
		"item":
			modifier += float(attacker_stats.get("willpower", 0.0)) * 0.7
		"flee":
			modifier += float(attacker_stats.get("dexterity", 0.0)) * 1.4 + _actor_stamina() * 0.2
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
	if _is_party_turn():
		var actor_label := GameState.player_class_name() if active_actor_id == "player" else GameState.companion_class_name()
		turn_label.text = "ZUG: %s - %s\nAP %d/%d - Faehigkeiten mit 1-9 oder Klick." % [
			_actor_name(active_actor_id),
			actor_label,
			player_action_points,
			PLAYER_ACTION_POINTS_PER_TURN
		]
	elif turn_state == "enemy":
		turn_label.text = "GEGNER AM ZUG - %s\nDer Gegner antwortet nach deinen Aktionen." % enemy.get("name", "Gegner")
	else:
		turn_label.text = "KAMPF BEENDET"


func _attack() -> void:
	if not _is_party_turn():
		return
	if not _spend_combat_action_points(ATTACK_AP_COST):
		_set_combat_log("Dafuer fehlen Aktionspunkte.")
		_refresh()
		return
	var result := _player_damage()
	_play_player_attack_feedback(result)
	enemy_health -= float(result.damage)
	if float(result.damage) > 0.0:
		_record_damage_dealt(float(result.damage))
		_push_combat_event(str(result.text), "damage")
	else:
		_push_combat_event(str(result.text), "neutral")
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
		var attacker_stats := _active_stats()
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
	if not _is_party_turn():
		return
	if not _spend_combat_action_points(DEFEND_AP_COST):
		_set_combat_log("Dafuer fehlen Aktionspunkte.")
		_refresh()
		return
	var roll := _roll_success("defend")
	if not bool(roll.get("success", false)):
		_change_actor_stat("stamina", -4.0)
		AudioManager.play_button_click(AudioManager.UiClickKind.DANGER)
		_pulse_art(player_art, Color(0.9, 0.42, 0.34, 0.88), 1.02)
		_set_combat_log("Die Deckung misslingt. Erfolgschance: %s." % _chance_text(float(roll.get("chance", 0.0))))
		_finish_player_action()
		return
	defending = true
	defending_actor_id = active_actor_id
	defense_multiplier = 0.42
	_change_actor_stat("stamina", -4.0)
	AudioManager.play_sfx("res://assets/audio/sfx/environment/wave_warning.wav", -10.0, 1.35)
	_pulse_art(player_art, Color(0.65, 0.82, 1.0, 0.95), 1.035)
	_record_buff("Deckung")
	var defender_name := _actor_name(active_actor_id)
	_push_combat_event("%s geht in Deckung. Erfolgschance: %s." % [defender_name, _chance_text(float(roll.get("chance", 0.0)))], "buff")
	_finish_player_action()


func _use_bandage() -> void:
	_toggle_heal_item_bar()


func _use_inventory_item_in_combat(item_id: String) -> void:
	if not _is_party_turn():
		return
	_hide_heal_item_bar()
	var data := DataCatalog.item(item_id)
	if data.is_empty() or not InventorySystem.usable_item(item_id):
		_set_combat_log("Dieser Gegenstand kann im Kampf nicht benutzt werden.")
		_refresh()
		return
	var cost := InventorySystem.combat_item_action_points(item_id)
	if not _spend_combat_action_points(cost):
		_set_combat_log("Dafuer fehlen Aktionspunkte.")
		_refresh()
		return
	var roll := _roll_success("item")
	if not bool(roll.get("success", false)):
		AudioManager.play_button_click(AudioManager.UiClickKind.DANGER)
		_pulse_art(player_art, Color(0.9, 0.42, 0.34, 0.88), 1.02)
		_set_combat_log("%s misslingt. Erfolgschance: %s." % [data.get("name", item_id), _chance_text(float(roll.get("chance", 0.0)))])
		_finish_player_action()
		return
	var effects: Dictionary = data.get("effects", {})
	var planned_health := maxf(0.0, float(effects.get("health", 0.0)))
	var health_before := float(GameState.player_stats.get("health", 0.0))
	var shield_before := float(GameState.player_stats.get("shield", 0.0))
	var use_text := ""
	if active_actor_id == "companion":
		if not InventorySystem.remove_item(item_id, 1):
			_set_combat_log("Gegenstand nicht verfuegbar.")
			_refresh()
			return
		health_before = companion_combat_health
		shield_before = float(GameState.companion_stats().get("shield", 0.0))
		use_text = _apply_combat_item_to_companion(item_id, effects)
	else:
		use_text = str(InventorySystem.use_item(item_id))
	var health_gain := _track_health_healing(health_before, planned_health) if active_actor_id != "companion" else maxf(0.0, companion_combat_health - health_before)
	var shield_gain := maxf(0.0, (
		float(GameState.companion_stats().get("shield", 0.0)) if active_actor_id == "companion"
		else float(GameState.player_stats.get("shield", 0.0))
	) - shield_before)
	if shield_gain > 0.0:
		_record_shield_gained(shield_gain)
	var heal_category := "heal" if health_gain > 0.0 else "neutral"
	if health_gain > 0.0:
		_push_combat_event("+%.0f Leben geheilt (%s)" % [health_gain, data.get("name", item_id)], "heal")
	_push_combat_event("%s\nKosten: %d AP. Erfolgschance: %s." % [
		use_text,
		cost,
		_chance_text(float(roll.get("chance", 0.0)))
	], heal_category)
	AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -9.0, 1.2)
	_pulse_art(player_art, Color(0.72, 1.0, 0.78, 0.95), 1.03)
	_finish_player_action()


func _use_hotbar_ability(index: int) -> void:
	if not _is_party_turn() or index < 0 or index >= GameState.MAX_EQUIPPED_ABILITIES:
		return
	_use_ability(_equipped_ability_id(index))


func _use_ability(ability_id: String) -> void:
	var data := _ability_data(ability_id)
	if data.is_empty():
		return
	if not _pay_ability_cost(ability_id, data):
		_set_combat_log(_ability_unavailable_text(ability_id, data))
		_refresh_ability_bar()
		return
	var roll := _roll_success("ability", data)
	if not bool(roll.get("success", false)):
		_set_combat_log("%s misslingt. Erfolgschance: %s." % [
			data.get("name", ability_id),
			_chance_text(float(roll.get("chance", 0.0)))
		])
		AudioManager.play_button_click(AudioManager.UiClickKind.DANGER)
		_pulse_art(player_art, Color(0.9, 0.42, 0.34, 0.88), 1.02)
		_finish_player_action()
		return
	var result := _apply_ability_effect(data)
	_record_ability_totals(result, data)
	var ability_category := "damage" if float(result.get("damage", 0.0)) > 0.0 else ("heal" if float(result.get("heal", 0.0)) > 0.0 else "buff")
	_push_combat_event("%s\nErfolgschance: %s." % [
		str(result.get("text", "")),
		_chance_text(float(roll.get("chance", 0.0)))
	], ability_category)
	_play_ability_feedback(data, float(result.get("damage", 0.0)), float(result.get("heal", 0.0)), float(result.get("shield", 0.0)))
	_finish_player_action()


func _can_pay_ability(ability_id: String) -> bool:
	var data := _ability_data(ability_id)
	if data.is_empty():
		return false
	return int(ability_cooldowns.get(ability_id, 0)) <= 0 and player_action_points >= _ability_ap_cost(ability_id) and _actor_stamina() >= float(data.get("stamina_cost", 0.0)) and _actor_energy() >= float(data.get("energy_cost", 0.0))


func _pay_ability_cost(ability_id: String, data: Dictionary) -> bool:
	if int(ability_cooldowns.get(ability_id, 0)) > 0:
		return false
	if not _spend_combat_action_points(_ability_ap_cost(ability_id)):
		return false
	if _actor_stamina() < float(data.get("stamina_cost", 0.0)):
		player_action_points += _ability_ap_cost(ability_id)
		return false
	if _actor_energy() < float(data.get("energy_cost", 0.0)):
		player_action_points += _ability_ap_cost(ability_id)
		return false
	_change_actor_stat("stamina", -float(data.get("stamina_cost", 0.0)))
	_change_actor_stat("energy", -float(data.get("energy_cost", 0.0)))
	ability_cooldowns[ability_id] = GameState.companion_ability_cooldown(ability_id) if active_actor_id == "companion" else GameState.ability_cooldown(ability_id)
	return true


func _apply_combat_item_to_companion(item_id: String, effects: Dictionary) -> String:
	for stat_name in effects:
		if stat_name == "health":
			companion_combat_health = minf(
				companion_combat_max_health,
				companion_combat_health + float(effects.get("health", 0.0))
			)
		else:
			_change_actor_stat(stat_name, float(effects[stat_name]))
	if item_id == "antibiotics":
		GameState.status_effects.erase("infected_wound")
		GameState.status_effects.erase("food_poisoning")
	if item_id == "antiseptic":
		GameState.status_effects.erase("infected_wound")
	if item_id == "cleansing_salt":
		GameState.status_effects.erase("demonic_taint")
	var data := DataCatalog.item(item_id)
	return str(data.get("use_text", data.get("name", item_id) + " verwendet."))


func _ability_value(data: Dictionary) -> float:
	var stat := str(data.get("scale_stat", ""))
	var base_stats := GameState.companion_stats() if active_actor_id == "companion" else GameState.player_stats
	return float(data.get("power", 0.0)) + float(base_stats.get(stat, 0.0)) * float(data.get("scale", 0.0))


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
		var damage_result := RpgRules.calculate_damage(damage, damage_type, _active_stats(), RpgRules.enemy_stats(enemy))
		damage = float(damage_result.get("damage", damage))
		enemy_health -= damage
		lines.append("%.0f %s-Schaden." % [damage, RpgRules.damage_type_data(damage_type).get("name", damage_type)])
	if heal > 0.0:
		if active_actor_id == "companion":
			var before := companion_combat_health
			companion_combat_health = minf(companion_combat_max_health, companion_combat_health + heal)
			heal = companion_combat_health - before
		else:
			var health_before := float(GameState.player_stats.get("health", 0.0))
			GameState.change_stat("health", heal)
			heal = _track_health_healing(health_before, heal)
		if heal > 0.0:
			lines.append("%.0f Leben wiederhergestellt." % heal)
	if shield > 0.0:
		_change_actor_stat("shield", shield)
		lines.append("%.0f Schild aufgebaut." % shield)
	if recover > 0.0:
		_change_actor_stat("stamina", recover)
		_change_actor_stat("energy", recover * 0.55)
		lines.append("%.0f Ausdauer und %.0f Energie zurueck." % [recover, recover * 0.55])
	if effect.contains("cleanse"):
		_clear_one_status()
		lines.append("Eine Verunreinigung wurde entfernt, falls vorhanden.")
	if effect.contains("defend") or data.has("defense_multiplier"):
		defending = true
		defending_actor_id = active_actor_id
		defense_multiplier = float(data.get("defense_multiplier", 0.55))
		lines.append("Naechster Schaden: %.0f%%." % (defense_multiplier * 100.0))
	return {"text": "\n".join(lines), "damage": damage, "heal": heal, "shield": shield}


func _clear_one_status() -> void:
	for status in ["infected_wound", "food_poisoning", "demonic_taint"]:
		if GameState.status_effects.has(status):
			GameState.status_effects.erase(status)
			return


func _finish_player_action() -> void:
	actor_ability_cooldowns[active_actor_id] = ability_cooldowns
	_refresh()
	if enemy_health <= 0.0:
		_victory()
		return
	if player_action_points <= 0:
		_advance_turn_queue()
	else:
		_push_combat_event("Noch %d/%d AP uebrig." % [player_action_points, PLAYER_ACTION_POINTS_PER_TURN], "neutral")
		_set_actions_enabled(_is_party_turn())
		_refresh_turn_text()


func _request_end_turn() -> void:
	if not _is_party_turn():
		return
	if player_action_points > 0 and AudioManager.should_confirm_skip_turn_with_ap():
		_show_skip_turn_confirm()
		return
	_end_player_turn()


func _end_player_turn() -> void:
	_hide_heal_item_bar()
	_hide_skip_turn_confirm()
	if not _is_party_turn():
		return
	player_action_points = 0
	_set_combat_log("Du beendest deine Runde.")
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
	panel.custom_minimum_size = UiFactory.overlay_panel_size(self, 0.40, 0.22)
	panel.add_theme_stylebox_override("panel", UiFactory.ornate_panel_style(true))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiFactory.ornate_heading("RUNDE BEENDEN?", 26))
	box.add_child(UiFactory.ornate_muted_label("Du hast noch %d Aktionspunkte. Trotzdem zum Gegnerzug wechseln?" % player_action_points, 16, true))
	box.add_child(UiFactory.ornate_muted_label("Diese Nachfrage kannst du unter ESC > Allgemein aendern.", 13, true))
	var actions := UiFactory.horizontal_actions()
	box.add_child(actions)
	actions.add_child(UiFactory.button("Runde beenden", _end_player_turn, 220, AudioManager.UiClickKind.CONFIRM))
	actions.add_child(UiFactory.button("Weiter kaempfen", _hide_skip_turn_confirm, 220))


func _hide_skip_turn_confirm() -> void:
	if is_instance_valid(skip_turn_confirm):
		skip_turn_confirm.queue_free()
	skip_turn_confirm = null


func _enemy_action() -> void:
	var combat_location := DataCatalog.location(GameState.current_location)
	var player_level := int(GameState.player_stats.get("level", 1))
	var raw_damage := EnemySpawnService.scale_damage(
		float(enemy.get("damage", 6)),
		combat_location,
		player_level,
		TimeSystem.current_day,
		TimeSystem.enemy_strength_multiplier()
	)
	raw_damage += maxf(0.0, float(enemy.get("speed", 1)) - 2.0)
	var target_id := _pick_enemy_target()
	if defending and defending_actor_id == target_id:
		raw_damage *= defense_multiplier
	defending = false
	defending_actor_id = ""
	defense_multiplier = 1.0
	var target_stats := _stats_for_actor(target_id)
	var damage_type := str(enemy.get("damage_type", "physical"))
	var damage_result := RpgRules.calculate_damage(raw_damage, damage_type, RpgRules.enemy_stats(enemy), target_stats, {"allow_critical": false})
	var damage := float(damage_result.get("damage", raw_damage))
	if target_id == "companion":
		damage = maxf(0.0, damage - float(target_stats.get("defense", 0.0)) * 0.45)
	else:
		damage = maxf(0.0, damage - InventorySystem.armor_value() * 0.22 - float(target_stats.get("defense", 0.0)) * 0.45)
	var absorbed := 0.0
	if target_id == "companion":
		var shield := float(GameState.companion_stats().get("shield", 0.0))
		if shield > 0.0:
			absorbed = minf(shield, damage)
			_change_actor_stat("shield", -absorbed)
			damage -= absorbed
		if damage > 0.0:
			companion_combat_health = maxf(0.0, companion_combat_health - damage)
			_record_damage_taken(damage)
			if companion_combat_health <= 0.0:
				companion_combat_active = false
				_push_combat_event("%s ist kampfunfaehig." % _actor_name("companion"), "debuff")
	else:
		var shield := float(GameState.player_stats.shield)
		if shield > 0.0:
			absorbed = minf(shield, damage)
			GameState.player_stats.shield = shield - absorbed
			damage -= absorbed
		if absorbed > 0.0:
			_record_shield_absorbed(absorbed)
		if damage > 0.0:
			GameState.change_stat("health", -damage)
			_record_damage_taken(damage)
	_play_enemy_attack_feedback(damage + absorbed, target_id)
	var total_hit := damage + absorbed
	if total_hit > 0.0:
		_push_combat_event("%s trifft %s fuer %.0f Schaden." % [enemy.get("name", "Gegner"), _actor_name(target_id), total_hit], "damage")
	if absorbed > 0.0:
		_push_combat_event("%.0f Schaden vom Schild absorbiert." % absorbed, "buff")
	if turn == 3 and enemy_id == "demon_basic" and target_id == "player" and not GameState.status_effects.has("demonic_taint"):
		GameState.status_effects.append("demonic_taint")
		_record_debuff("Daemonische Verunreinigung")
		_push_combat_event("Daemonische Verunreinigung — kalte Schwaerze in der Wunde.", "debuff")
	if turn == 2 and enemy_id == "demon_brute" and target_id == "player" and not GameState.status_effects.has("infected_wound"):
		GameState.status_effects.append("infected_wound")
		_record_debuff("Entzuendete Wunde")
		_push_combat_event("Die tiefe Wunde entzuendet sich.", "debuff")
	if target_id == "player":
		GameState.change_stat("stamina", -5.0)
	_refresh()


func _victory() -> void:
	turn_state = "ended"
	_set_actions_enabled(false)
	if companion_combat_active:
		var stats: Dictionary = GameState.companion.stats
		stats.health = companion_combat_health
		GameState.companion.stats = stats
	elif GameState.has_companion() and companion_combat_health <= 0.0:
		GameState.dismiss_companion()
		EventBus.post_message("Dein Begleiter ist im Kampf gefallen und hat das Team verlassen.")
	GameState.run_statistics.enemies_defeated = int(GameState.run_statistics.enemies_defeated) + 1
	GameState.grant_xp(int(enemy.get("xp", 25)), "Kampf gewonnen")
	AudioManager.play_sfx("res://assets/audio/sfx/weapons/melee_hit.wav", -6.0, 0.62)
	_fade_art(enemy_art)
	enemy_loot = _generate_enemy_loot()
	_push_combat_event("%s bricht zusammen. Durchsuche die Beute." % enemy.get("name", "Der Gegner"), "neutral")
	_refresh()
	_show_enemy_loot_menu()


func _flee() -> void:
	if not _is_party_turn():
		return
	if not _spend_combat_action_points(FLEE_AP_COST):
		_set_combat_log("Dafuer fehlen Aktionspunkte.")
		_refresh()
		return
	var roll := _roll_success("flee")
	if not bool(roll.get("success", false)):
		AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -7.0, 1.15)
		GameState.change_stat("stamina", -10.0)
		_set_combat_log("Der Rueckzug misslingt. Erfolgschance: %s." % _chance_text(float(roll.get("chance", 0.0))))
		_finish_player_action()
		return
	turn_state = "ended"
	_set_actions_enabled(false)
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -7.0, 1.15)
	GameState.change_stat("stamina", -18.0)
	GameState.change_stat("health", -5.0)
	_record_damage_taken(5.0)
	_try_play_hit_animation("player")
	_set_combat_log("Du entkommst knapp, verlierst aber 5 Leben.")
	TimeSystem.advance(1, "Du entkommst knapp.")
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		var target := GameState.return_scene if not GameState.return_scene.is_empty() else "res://scenes/world_map/world_map.tscn"
		go_to(target)


func _refresh() -> void:
	var max_health := float(GameState.player_stats.get("max_health", 100.0))
	if is_instance_valid(player_health_bar):
		player_health_bar.max_value = max_health
		player_health_bar.value = clampf(float(GameState.player_stats.health), 0.0, max_health)
		player_health_bar.tooltip_text = "Dein Leben: %.0f / %.0f" % [float(GameState.player_stats.health), max_health]
	if is_instance_valid(enemy_health_bar):
		_refresh_enemy_health_preview()
	if is_instance_valid(round_label):
		round_label.text = "RUNDE %d" % turn
	_refresh_turn_order_strip()
	player_label.text = "Leben %.0f - Schutz %.0f - Ruestung %.0f - Ausdauer %.0f" % [
		float(GameState.player_stats.health),
		float(GameState.player_stats.shield),
		InventorySystem.armor_value(),
		float(GameState.player_stats.stamina)
	]
	if companion_combat_active and is_instance_valid(player_label):
		player_label.text += " | %s %.0f/%.0f" % [
			_actor_name("companion"),
			companion_combat_health,
			companion_combat_max_health
		]
	if is_instance_valid(enemy_label) and combat_enemy_damage_preview < 0.0:
		enemy_label.text = "Leben %.0f - Schaden %d - Tempo %d" % [
			maxf(0.0, enemy_health),
			int(enemy.get("damage", 0)),
			int(enemy.get("speed", 1))
		]
	_refresh_turn_text()
	_refresh_actor_overlay()
	_refresh_backpack_overlay()
	_refresh_action_bar()
	_refresh_turn_badges(_is_party_turn())
	_set_actions_enabled(_is_party_turn())
	_refresh_combat_summary()


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
	if ranged:
		_spawn_projectile(data)
	if bool(result.get("hit", true)):
		_shake_art(enemy_art, Color(1.0, 0.46, 0.38, 0.95))
	else:
		_pulse_art(enemy_art, Color(0.72, 0.74, 0.78, 0.72), 1.015)


func _play_enemy_attack_feedback(damage: float, target_id: String = "player") -> void:
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -8.0, 0.92)
	if damage > 0.0:
		AudioManager.play_sfx("res://assets/audio/sfx/weapons/melee_hit.wav", -9.0, 0.72)
		_try_play_hit_animation(target_id)
	_shake_art(player_art, Color(0.92, 0.38, 0.34, 0.95))
	_pulse_art(enemy_art, Color(1.0, 0.58, 0.42, 0.92), 1.055)


func _try_play_hit_animation(target_id: String) -> void:
	if not is_instance_valid(player_art) or not player_art.has_method("play_hit"):
		return
	var appearance := GameState.player_appearance
	if target_id == "companion":
		if not GameState.has_companion():
			return
		appearance = str(GameState.companion.get("appearance", "priest"))
	if not GameState.appearance_has_hit_animation(appearance):
		return
	player_art.call("play_hit")


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


func _create_stage_art(texture_path: String, role: String, _metrics: Dictionary) -> Control:
	if role == "player":
		var visual: PlayerCharacterVisual = PlayerCharacterVisual.new()
		visual.setup(
			GameState.player_gender,
			GameState.player_appearance,
			CharacterVisualContext.Context.COMBAT
		)
		return visual
	var art := TextureRect.new()
	art.texture = load(texture_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _pulse_art(art: Control, tint: Color, scale_to: float) -> void:
	if not is_instance_valid(art):
		return
	var tween := create_tween()
	tween.tween_property(art, "scale", Vector2(scale_to, scale_to), 0.08)
	tween.parallel().tween_property(art, "modulate", tint, 0.08)
	tween.tween_property(art, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(art, "modulate", Color(1, 1, 1, 0.9), 0.14)


func _shake_art(art: Control, tint: Color) -> void:
	if not is_instance_valid(art):
		return
	var origin: Vector2 = art.position
	var tween := create_tween()
	tween.tween_property(art, "position", origin + Vector2(10, 0), 0.04)
	tween.parallel().tween_property(art, "modulate", tint, 0.04)
	tween.tween_property(art, "position", origin + Vector2(-8, 0), 0.04)
	tween.tween_property(art, "position", origin, 0.05)
	tween.parallel().tween_property(art, "modulate", Color(1, 1, 1, 0.9), 0.08)


func _fade_art(art: Control) -> void:
	if not is_instance_valid(art):
		return
	var tween := create_tween()
	tween.tween_property(art, "modulate", Color(0.35, 0.35, 0.35, 0.28), 0.18)


func _reset_combat_summary() -> void:
	combat_totals = {
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"healing": 0.0,
		"shield_gained": 0.0,
		"shield_absorbed": 0.0,
	}
	combat_buffs.clear()
	combat_debuffs.clear()
	combat_events.clear()


func _combat_event_color(category: String) -> String:
	match category:
		"damage":
			return SUMMARY_COLOR_DAMAGE
		"heal":
			return SUMMARY_COLOR_HEAL
		"buff":
			return SUMMARY_COLOR_BUFF
		"debuff":
			return SUMMARY_COLOR_DEBUFF
		_:
			return SUMMARY_COLOR_NEUTRAL


func _format_combat_event(text: String, category: String = "neutral") -> String:
	return "[color=%s]%s[/color]" % [_combat_event_color(category), text]


func _push_combat_event(text: String, category: String = "neutral") -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	combat_events.append(_format_combat_event(clean, category))
	_refresh_combat_summary()


func _record_damage_dealt(amount: float) -> void:
	if amount <= 0.0:
		return
	combat_totals["damage_dealt"] = float(combat_totals.get("damage_dealt", 0.0)) + amount


func _record_damage_taken(amount: float) -> void:
	if amount <= 0.0:
		return
	combat_totals["damage_taken"] = float(combat_totals.get("damage_taken", 0.0)) + amount


func _record_healing(amount: float) -> void:
	if amount <= 0.0:
		return
	combat_totals["healing"] = float(combat_totals.get("healing", 0.0)) + amount
	_refresh_combat_overview()


func _track_health_healing(health_before: float, _planned: float = 0.0) -> float:
	var gain := maxf(0.0, float(GameState.player_stats.get("health", 0.0)) - health_before)
	if gain > 0.0:
		_record_healing(gain)
	return gain


func _planned_health_heal_from_effects(effects: Dictionary) -> float:
	return maxf(0.0, float(effects.get("health", 0.0)))


func _combat_debuff_tooltip(status_id: String, label: String) -> String:
	if COMBAT_STATUS_DESCRIPTIONS.has(status_id):
		return COMBAT_STATUS_DESCRIPTIONS[status_id]
	for key in COMBAT_STATUS_LABELS:
		if COMBAT_STATUS_LABELS[key] == label and COMBAT_STATUS_DESCRIPTIONS.has(key):
			return COMBAT_STATUS_DESCRIPTIONS[key]
	return "Negativer Effekt: %s" % label


func _active_combat_debuff_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Array[String] = []
	for debuff_name in combat_debuffs:
		var label := debuff_name.strip_edges()
		if label.is_empty() or label in seen:
			continue
		entries.append({
			"id": "",
			"label": label,
			"tooltip": _combat_debuff_tooltip("", label),
		})
		seen.append(label)
	for status in GameState.status_effects:
		var status_id := str(status)
		var label := _combat_status_display_name(status_id)
		if label in seen:
			continue
		entries.append({
			"id": status_id,
			"label": label,
			"tooltip": _combat_debuff_tooltip(status_id, label),
		})
		seen.append(label)
	return entries


func _create_debuff_chip(label_text: String, tooltip: String, metrics: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_HELP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.16, 0.92)
	style.border_color = Color.html(SUMMARY_COLOR_DEBUFF)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	chip.add_theme_stylebox_override("panel", style)
	var text := UiFactory.ornate_muted_label(label_text, metrics.log_font - 1, false)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color", Color.html(SUMMARY_COLOR_DEBUFF))
	chip.add_child(text)
	return chip


func _rebuild_combat_debuff_row(metrics: Dictionary) -> void:
	if not is_instance_valid(combat_debuff_row):
		return
	UiFactory.clear_container(combat_debuff_row)
	var entries := _active_combat_debuff_entries()
	combat_debuff_row.visible = not entries.is_empty()
	if entries.is_empty():
		return
	var title := UiFactory.ornate_muted_label("Debuffs:", metrics.log_font, false)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color.html(SUMMARY_COLOR_DEBUFF))
	combat_debuff_row.add_child(title)
	for entry in entries:
		combat_debuff_row.add_child(_create_debuff_chip(str(entry.get("label", "")), str(entry.get("tooltip", "")), metrics))


func _record_shield_gained(amount: float) -> void:
	if amount <= 0.0:
		return
	combat_totals["shield_gained"] = float(combat_totals.get("shield_gained", 0.0)) + amount


func _record_shield_absorbed(amount: float) -> void:
	if amount <= 0.0:
		return
	combat_totals["shield_absorbed"] = float(combat_totals.get("shield_absorbed", 0.0)) + amount


func _record_buff(buff_name: String) -> void:
	var clean := buff_name.strip_edges()
	if clean.is_empty() or clean in combat_buffs:
		return
	combat_buffs.append(clean)
	_push_combat_event("Buff: %s" % clean, "buff")


func _record_debuff(debuff_name: String) -> void:
	var clean := debuff_name.strip_edges()
	if clean.is_empty() or clean in combat_debuffs:
		return
	combat_debuffs.append(clean)


func _record_ability_totals(result: Dictionary, data: Dictionary) -> void:
	if float(result.get("damage", 0.0)) > 0.0:
		_record_damage_dealt(float(result.get("damage", 0.0)))
	if float(result.get("shield", 0.0)) > 0.0:
		_record_shield_gained(float(result.get("shield", 0.0)))
	var effect := str(data.get("effect", ""))
	if effect.contains("defend"):
		_record_buff(str(data.get("name", "Verteidigung")))
	if effect.contains("cleanse"):
		_record_buff("Reinigung")
	if effect == "snare":
		_record_buff("Gegner gefesselt")


func _set_combat_log(text: String, category: String = "neutral") -> void:
	for line in text.strip_edges().split("\n", false):
		if not line.strip_edges().is_empty():
			_push_combat_event(line.strip_edges(), category)


func _append_combat_log_line(text: String, category: String = "neutral") -> void:
	_set_combat_log(text, category)


func _combat_status_display_name(status_id: String) -> String:
	return str(COMBAT_STATUS_LABELS.get(status_id, status_id.capitalize().replace("_", " ")))


func _summary_total_line(label: String, value: float, color: String, heading_font: int) -> String:
	if value > 0.0:
		return "[font_size=%d][color=%s]%s %.0f[/color][/font_size]" % [heading_font, color, label, value]
	return "[font_size=%d][color=#7a8494]%s 0[/color][/font_size]" % [heading_font, label]


func _refresh_combat_summary() -> void:
	_refresh_combat_overview()
	_refresh_combat_feed()


func _refresh_combat_overview() -> void:
	if not is_instance_valid(combat_summary_label):
		return
	var metrics: Dictionary = _combat_layout_metrics()
	var body_font: int = metrics.log_font
	var lines: PackedStringArray = []
	lines.append(_summary_total_line("Schaden verursacht:", float(combat_totals.get("damage_dealt", 0.0)), SUMMARY_COLOR_DAMAGE, body_font))
	lines.append(_summary_total_line("Schaden erlitten:", float(combat_totals.get("damage_taken", 0.0)), SUMMARY_COLOR_DAMAGE, body_font))
	lines.append(_summary_total_line("Heilung:", float(combat_totals.get("healing", 0.0)), SUMMARY_COLOR_HEAL, body_font))
	var shield_gained := float(combat_totals.get("shield_gained", 0.0))
	var shield_absorbed := float(combat_totals.get("shield_absorbed", 0.0))
	var shield_parts: PackedStringArray = []
	if shield_gained > 0.0:
		shield_parts.append("[font_size=%d][color=%s]+%.0f Schild[/color][/font_size]" % [body_font, SUMMARY_COLOR_BUFF, shield_gained])
	else:
		shield_parts.append("[font_size=%d][color=#7a8494]+0 Schild[/color][/font_size]" % body_font)
	if shield_absorbed > 0.0:
		shield_parts.append("[font_size=%d][color=%s]%.0f absorbiert[/color][/font_size]" % [body_font, SUMMARY_COLOR_BUFF, shield_absorbed])
	else:
		shield_parts.append("[font_size=%d][color=#7a8494]0 absorbiert[/color][/font_size]" % body_font)
	lines.append(" | ".join(shield_parts))
	if not combat_buffs.is_empty():
		lines.append("[font_size=%d][color=%s]Buffs: %s[/color][/font_size]" % [body_font, SUMMARY_COLOR_BUFF, ", ".join(combat_buffs)])
	combat_summary_label.text = "\n".join(lines)
	_rebuild_combat_debuff_row(metrics)


func _refresh_combat_feed() -> void:
	if not is_instance_valid(log_label):
		return
	var metrics: Dictionary = _combat_layout_metrics()
	var body_font: int = metrics.log_font
	var lines: PackedStringArray = []
	if combat_events.is_empty():
		lines.append("[font_size=%d][color=#7a8494]Noch keine Kampfereignisse.[/color][/font_size]" % body_font)
	else:
		for event in combat_events:
			lines.append("[font_size=%d]%s[/font_size]" % [body_font, event])
	log_label.text = "\n".join(lines)
	call_deferred("_scroll_combat_log_to_end")


func _scroll_combat_log_to_end() -> void:
	if not is_instance_valid(log_label):
		return
	var parent := log_label.get_parent()
	if parent is ScrollContainer:
		var scroll := parent as ScrollContainer
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
