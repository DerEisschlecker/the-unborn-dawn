# Purpose: Displays day, phase, wave warning, and all core player and Elena status values.
# Public API: refresh().
# Dependencies: GameState, TimeSystem, WaveManager, EventBus.
extends Control

const ClockFaceScript := preload("res://scripts/ui/clock_face.gd")

var clock_face: Control
var day_label: Label
var phase_label: Label
var warning_label: Label
var pack_label: Label
var xp_bar: ProgressBar
var inventory_button: Button
var stat_bars: Dictionary = {}
var compact_hud := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	compact_hud = UiFactory.is_compact_screen()
	offset_bottom = 102 if compact_hud else 122
	theme = UiFactory.DARK_THEME
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	EventBus.stats_changed.connect(refresh)
	EventBus.inventory_changed.connect(refresh)
	EventBus.time_changed.connect(func(_day: int, _phase: String) -> void: refresh())
	refresh()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := UiFactory._panel_style()
	panel_style.bg_color = Color(0.018, 0.022, 0.030, 0.88)
	panel_style.border_color = Color(0.34, 0.39, 0.46, 0.58)
	panel_style.content_margin_left = 0
	panel_style.content_margin_right = 0
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14 if compact_hud else 22)
	margin.add_theme_constant_override("margin_right", 14 if compact_hud else 22)
	margin.add_theme_constant_override("margin_top", 7 if compact_hud else 9)
	margin.add_theme_constant_override("margin_bottom", 7 if compact_hud else 9)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if compact_hud else 16)
	margin.add_child(row)
	var time_row := HBoxContainer.new()
	time_row.custom_minimum_size.x = 250 if compact_hud else 300
	time_row.add_theme_constant_override("separation", 8)
	row.add_child(time_row)
	clock_face = ClockFaceScript.new()
	clock_face.custom_minimum_size = Vector2(46 if compact_hud else 56, 46 if compact_hud else 56)
	time_row.add_child(clock_face)
	var time_box := VBoxContainer.new()
	time_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_box.add_theme_constant_override("separation", 1)
	time_row.add_child(time_box)
	day_label = UiFactory.title_label("", 16 if compact_hud else 18)
	phase_label = UiFactory.body_label("", 12 if compact_hud else 13, UiFactory.COLOR_MUTED)
	warning_label = UiFactory.body_label("", 11 if compact_hud else 12, UiFactory.COLOR_DANGER)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(162 if compact_hud else 190, 12 if compact_hud else 14)
	xp_bar.show_percentage = false
	time_box.add_child(day_label)
	time_box.add_child(phase_label)
	time_box.add_child(warning_label)
	time_box.add_child(xp_bar)
	for stat_name in ["health", "shield", "hunger", "thirst", "stamina", "energy"]:
		_add_stat(row, stat_name)
	var elena_box := VBoxContainer.new()
	elena_box.custom_minimum_size.x = 128 if compact_hud else 160
	row.add_child(elena_box)
	elena_box.add_child(UiFactory.body_label("ELENA", 11 if compact_hud else 13, UiFactory.COLOR_GOLD))
	var elena_health := ProgressBar.new()
	elena_health.name = "elena_health"
	elena_health.custom_minimum_size = Vector2(120 if compact_hud else 150, 13 if compact_hud else 15)
	elena_health.show_percentage = false
	elena_box.add_child(elena_health)
	stat_bars.elena_health = elena_health
	var elena_stress := ProgressBar.new()
	elena_stress.name = "elena_stress"
	elena_stress.custom_minimum_size = Vector2(120 if compact_hud else 150, 13 if compact_hud else 15)
	elena_stress.show_percentage = false
	elena_box.add_child(elena_stress)
	stat_bars.elena_stress = elena_stress
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 130 if compact_hud else 150
	actions.add_theme_constant_override("separation", 3)
	row.add_child(actions)
	pack_label = UiFactory.body_label("", 11 if compact_hud else 12, UiFactory.COLOR_GOLD)
	pack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	actions.add_child(pack_label)
	inventory_button = Button.new()
	inventory_button.custom_minimum_size = Vector2(58 if compact_hud else 66, 40 if compact_hud else 46)
	inventory_button.icon = load("res://assets/items/backpacks/small_backpack.svg")
	inventory_button.expand_icon = true
	inventory_button.tooltip_text = "Inventar oeffnen (I)"
	inventory_button.pressed.connect(_open_inventory)
	actions.add_child(inventory_button)


func _add_stat(row: HBoxContainer, stat_name: String) -> void:
	var names := {
		"health": "LEB", "shield": "SCH", "hunger": "HUN",
		"thirst": "WAS", "stamina": "AUS", "energy": "ENE"
	}
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 76 if compact_hud else 96
	row.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/icons/%s.svg" % stat_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(14 if compact_hud else 16, 14 if compact_hud else 16)
	header.add_child(icon)
	var title := UiFactory.body_label(names[stat_name], 9 if compact_hud else 10, UiFactory.COLOR_MUTED)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = 44 if compact_hud else 58
	header.add_child(title)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(72 if compact_hud else 90, 15 if compact_hud else 17)
	bar.show_percentage = false
	box.add_child(bar)
	stat_bars[stat_name] = bar


func refresh() -> void:
	if not is_instance_valid(day_label):
		return
	if is_instance_valid(clock_face):
		clock_face.call("set_hour", TimeSystem.current_hour())
	day_label.text = "TAG %d / %d" % [TimeSystem.current_day, GameState.MAX_DAY]
	phase_label.text = TimeSystem.current_phase()
	warning_label.text = "Heute Nacht: Angriff" if WaveManager.is_wave_day(TimeSystem.current_day) else ""
	pack_label.text = "%d Dawn-Credits  |  Lvl %d  R %02d/24" % [
		InventorySystem.money,
		int(GameState.player_stats.get("level", 1)),
		TimeSystem.current_hour() + 1
	]
	pack_label.tooltip_text = "Dawn-Credits: %d" % InventorySystem.money
	xp_bar.max_value = float(GameState.player_stats.get("next_xp", 60))
	xp_bar.value = float(GameState.player_stats.get("xp", 0))
	xp_bar.tooltip_text = "Erfahrung: %d / %d" % [
		int(GameState.player_stats.get("xp", 0)),
		int(GameState.player_stats.get("next_xp", 60))
	]
	if is_instance_valid(inventory_button):
		inventory_button.text = "%d/%d" % [InventorySystem.used_slots(), InventorySystem.slot_capacity]
		inventory_button.tooltip_text = "Inventar (I)\n%d/%d Plaetze\n%.1f / %.1f kg" % [
			InventorySystem.used_slots(),
			InventorySystem.slot_capacity,
			InventorySystem.current_weight(),
			InventorySystem.max_weight
		]
	for stat_name in ["health", "shield", "hunger", "thirst", "stamina", "energy"]:
		var bar: ProgressBar = stat_bars[stat_name]
		bar.max_value = GameState.max_resource(stat_name) if stat_name in ["health", "stamina", "energy"] else float(GameState.player_stats.get("max_" + stat_name, 100.0))
		bar.value = float(GameState.player_stats.get(stat_name, 0.0))
	stat_bars.elena_health.value = float(GameState.elena.get("health", 0.0))
	stat_bars.elena_stress.value = float(GameState.elena.get("stress", 0.0))
	stat_bars.elena_health.tooltip_text = "Elenas Leben: %.0f" % float(GameState.elena.get("health", 0.0))
	stat_bars.elena_stress.tooltip_text = "Elenas Stress: %.0f" % float(GameState.elena.get("stress", 0.0))


func _open_inventory() -> void:
	var current := get_tree().current_scene
	if current and current.has_method("open_inventory"):
		current.call("open_inventory")
