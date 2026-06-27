# Purpose: Displays day, phase, wave warning, and all core player and Elena status values.
# Public API: refresh().
# Dependencies: GameState, TimeSystem, WaveManager, EventBus.
# Layout: Edit icons and spacing live in res://scenes/ui/hud.tscn (drag nodes in the Godot editor).
extends Control

const HUD_STATS := ["health", "hunger", "stamina", "thirst", "energy", "shield"]

@onready var bar_background: NinePatchRect = %BarBackground
@onready var clock_face: Control = %ClockFace
@onready var day_icon: TextureRect = %DayIcon
@onready var day_label: Label = %DayLabel
@onready var phase_label: Label = %PhaseLabel
@onready var warning_label: Label = %WarningLabel
@onready var pack_label: Label = %PackLabel
@onready var abilities_button: TextureButton = %AbilitiesButton
@onready var rest_button: TextureButton = %RestButton
@onready var backpack_button: TextureButton = %BackpackButton
@onready var margin: MarginContainer = $Margin

var stat_bars: Dictionary = {}
var stat_icons: Dictionary = {}
var stat_bar_entries: Dictionary = {}
var preview_values: Dictionary = {}
var compact_hud := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	z_index = 120
	compact_hud = UiFactory.is_compact_screen(self)
	offset_top = -UiFactory.hud_height(self)
	theme = UiFactory.DARK_THEME
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bind_stat_nodes()
	_apply_metrics()
	_apply_bar_styles()
	_wrap_stat_bars_for_preview()
	_wire_actions()
	if Engine.is_editor_hint():
		_apply_editor_preview()
		return
	EventBus.stats_changed.connect(refresh)
	EventBus.inventory_changed.connect(refresh)
	EventBus.stat_preview_changed.connect(_on_stat_preview_changed)
	EventBus.stat_preview_cleared.connect(_on_stat_preview_cleared)
	EventBus.time_changed.connect(func(_day: int, _phase: String) -> void: refresh())
	refresh()


func _hud_metrics() -> Dictionary:
	var icon_size := 68 if compact_hud else 76
	return {
		"icon_size": icon_size,
		"stat_bar_w": icon_size + 2,
		"stat_bar_h": 12 if compact_hud else 14,
		"stat_col_w": icon_size + 4,
		"time_col_w": icon_size * 2 + 14,
		"font_pack": 10 if compact_hud else 11,
	}


func _icon_box(icon_size: int) -> Vector2:
	return Vector2(icon_size, icon_size)


func _bind_stat_nodes() -> void:
	var icon_names := {
		"health": %HealthIcon,
		"hunger": %HungerIcon,
		"stamina": %StaminaIcon,
		"thirst": %ThirstIcon,
		"energy": %EnergyIcon,
		"shield": %ShieldIcon,
	}
	var bar_names := {
		"health": %HealthBar,
		"hunger": %HungerBar,
		"stamina": %StaminaBar,
		"thirst": %ThirstBar,
		"energy": %EnergyBar,
		"shield": %ShieldBar,
	}
	for stat_name in HUD_STATS:
		stat_icons[stat_name] = icon_names[stat_name]
		stat_bars[stat_name] = bar_names[stat_name]
	stat_bars.elena_health = %ElenaHealth
	stat_bars.elena_stress = %ElenaStress


func _apply_metrics() -> void:
	var metrics: Dictionary = _hud_metrics()
	if is_instance_valid(bar_background):
		UiFactory.configure_hud_bar_background(bar_background)
	if is_instance_valid(margin):
		margin.add_theme_constant_override("margin_left", 18 if compact_hud else 24)
		margin.add_theme_constant_override("margin_right", 18 if compact_hud else 24)
		margin.add_theme_constant_override("margin_top", 2 if compact_hud else 4)
		margin.add_theme_constant_override("margin_bottom", 4 if compact_hud else 6)
	if is_instance_valid(clock_face):
		clock_face.custom_minimum_size = _icon_box(metrics.icon_size)
	if is_instance_valid(day_icon):
		day_icon.custom_minimum_size = _icon_box(metrics.icon_size)
	for stat_name in HUD_STATS:
		var icon: TextureRect = stat_icons[stat_name]
		var bar: ProgressBar = stat_bars[stat_name]
		icon.custom_minimum_size = _icon_box(metrics.icon_size)
		bar.custom_minimum_size = Vector2(metrics.stat_bar_w, metrics.stat_bar_h)
		var entry: Dictionary = stat_bar_entries.get(stat_name, {})
		UiFactory.sync_stat_bar_layer_size(entry, bar.custom_minimum_size)
	if is_instance_valid(pack_label):
		pack_label.add_theme_font_size_override("font_size", metrics.font_pack)
	for button in [abilities_button, rest_button, backpack_button]:
		if is_instance_valid(button):
			button.custom_minimum_size = _icon_box(metrics.icon_size)


func _apply_bar_styles() -> void:
	for stat_name in HUD_STATS:
		UiFactory.apply_stat_bar(stat_bars[stat_name], UiFactory.stat_bar_color(stat_name))
	UiFactory.apply_stat_bar(stat_bars.elena_health, UiFactory.stat_bar_color("health"))
	UiFactory.apply_stat_bar(stat_bars.elena_stress, Color("#b56cff"))


func _wrap_stat_bars_for_preview() -> void:
	for stat_name in HUD_STATS:
		var color := UiFactory.stat_bar_color(stat_name)
		stat_bar_entries[stat_name] = UiFactory.attach_stat_bar_preview(stat_bars[stat_name], color)


func _on_stat_preview_changed(projected: Dictionary) -> void:
	preview_values = projected.duplicate()
	_apply_stat_previews()


func _on_stat_preview_cleared() -> void:
	preview_values = {}
	_apply_stat_previews()


func _apply_stat_previews() -> void:
	for stat_name in HUD_STATS:
		var maximum := GameState.max_resource(stat_name) if stat_name in ["health", "stamina", "energy"] else float(GameState.player_stats.get("max_" + stat_name, 100.0))
		var current := float(GameState.player_stats.get(stat_name, 0.0))
		var projected := float(preview_values.get(stat_name, -1.0)) if preview_values.has(stat_name) else -1.0
		var entry: Dictionary = stat_bar_entries.get(stat_name, {})
		UiFactory.update_stat_bar_preview(entry, current, maximum, projected)
		var tip := UiFactory.stat_preview_tooltip(_stat_label(stat_name), current, maximum, projected)
		stat_bars[stat_name].tooltip_text = tip
		if stat_icons.has(stat_name):
			stat_icons[stat_name].tooltip_text = tip


func _wire_actions() -> void:
	UiFactory.wire_button_sound(abilities_button)
	UiFactory.wire_button_sound(rest_button)
	UiFactory.wire_button_sound(backpack_button)
	abilities_button.pressed.connect(_open_abilities)
	rest_button.pressed.connect(_trigger_rest)
	backpack_button.pressed.connect(_open_inventory)
	rest_button.mouse_entered.connect(_preview_rest)
	rest_button.mouse_exited.connect(_clear_rest_preview)


func _preview_rest() -> void:
	_hud_stat_preview().set_projected({
		"stamina": GameState.max_resource("stamina"),
		"energy": GameState.max_resource("energy"),
	})


func _clear_rest_preview() -> void:
	_hud_stat_preview().clear()


func _hud_stat_preview() -> HudStatPreviewNode:
	return get_node("/root/HudStatPreview") as HudStatPreviewNode


func _apply_editor_preview() -> void:
	if is_instance_valid(clock_face) and clock_face.has_method("set_hour"):
		clock_face.call("set_hour", 14)
	pack_label.text = "120 DC  |  Lvl 3  |  14:00"
	backpack_button.tooltip_text = "Rucksack / Inventar (I)\n12/24 Plaetze\n8.5 / 20.0 kg"


func refresh() -> void:
	if not is_instance_valid(day_icon):
		return
	if is_instance_valid(clock_face):
		clock_face.call("set_hour", TimeSystem.current_hour())
	var day_text := "TAG %d / %d" % [TimeSystem.current_day, GameState.MAX_DAY]
	var phase_text := TimeSystem.current_phase()
	var warning_text := "Heute Nacht: Angriff" if WaveManager.is_wave_day(TimeSystem.current_day) else ""
	var is_night := TimeSystem.is_night()
	day_icon.modulate = Color(0.42, 0.48, 0.72, 0.72) if is_night else Color(1.0, 0.96, 0.82, 1.0)
	day_icon.tooltip_text = "%s\n%s" % ["Nacht" if is_night else "Tag", day_text]
	if is_instance_valid(day_label):
		day_label.text = day_text
	if is_instance_valid(phase_label):
		phase_label.text = phase_text
	if is_instance_valid(warning_label):
		warning_label.text = warning_text
	if is_instance_valid(clock_face):
		clock_face.tooltip_text = "%s\n%s" % [phase_text, day_text]
	pack_label.text = "%d DC  |  Lvl %d  |  %02d:00" % [
		InventorySystem.money,
		int(GameState.player_stats.get("level", 1)),
		TimeSystem.current_hour()
	]
	pack_label.tooltip_text = "Dawn-Credits: %d\nErfahrung: %d / %d" % [
		InventorySystem.money,
		int(GameState.player_stats.get("xp", 0)),
		int(GameState.player_stats.get("next_xp", 60))
	]
	if is_instance_valid(backpack_button):
		backpack_button.tooltip_text = "Rucksack / Inventar (I)\n%d/%d Plaetze\n%.1f / %.1f kg" % [
			InventorySystem.used_slots(),
			InventorySystem.slot_capacity,
			InventorySystem.current_weight(),
			InventorySystem.max_weight
		]
	for stat_name in HUD_STATS:
		var bar: ProgressBar = stat_bars[stat_name]
		var maximum := GameState.max_resource(stat_name) if stat_name in ["health", "stamina", "energy"] else float(GameState.player_stats.get("max_" + stat_name, 100.0))
		var current := float(GameState.player_stats.get(stat_name, 0.0))
		bar.max_value = maximum
		bar.value = current
	_apply_stat_previews()
	stat_bars.elena_health.value = float(GameState.elena.get("health", 0.0))
	stat_bars.elena_stress.value = float(GameState.elena.get("stress", 0.0))
	stat_bars.elena_health.tooltip_text = "Elenas Leben: %.0f" % float(GameState.elena.get("health", 0.0))
	stat_bars.elena_stress.tooltip_text = "Elenas Stress: %.0f" % float(GameState.elena.get("stress", 0.0))


func _stat_label(stat_name: String) -> String:
	match stat_name:
		"health": return "Leben"
		"shield": return "Schutz"
		"hunger": return "Hunger"
		"thirst": return "Durst"
		"stamina": return "Ausdauer"
		"energy": return "Energie"
		_: return stat_name


func _open_inventory() -> void:
	var current := get_tree().current_scene
	if current and current.has_method("open_inventory"):
		current.call("open_inventory")


func _open_abilities() -> void:
	var current := get_tree().current_scene
	if current and current.has_method("open_level"):
		current.call("open_level")


func _trigger_rest() -> void:
	var current := get_tree().current_scene
	if current and current.has_method("rest_action"):
		current.call("rest_action")
