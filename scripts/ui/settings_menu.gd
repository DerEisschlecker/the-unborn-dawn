# Purpose: Pause overlay for audio, graphics, save/load slots, and leaving the game.
# Public API: close_menu().
# Dependencies: AudioManager, SaveSystem, GameState.
extends Control

var slot_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	get_tree().paused = true
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 760)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UiFactory.title_label("PAUSE & EINSTELLUNGEN", 38))
	column.add_child(UiFactory.body_label("ESC schließt dieses Menü.", 17, UiFactory.COLOR_MUTED))
	var general_section := UiFactory.section("Allgemein")
	column.add_child(general_section.get_parent())
	var confirm_skip := CheckButton.new()
	confirm_skip.text = "Nachfragen, wenn eine Runde mit offenen Aktionspunkten beendet wird"
	confirm_skip.button_pressed = AudioManager.should_confirm_skip_turn_with_ap()
	confirm_skip.toggled.connect(func(enabled: bool) -> void: AudioManager.set_confirm_skip_turn_with_ap(enabled))
	general_section.add_child(confirm_skip)
	var audio_section := UiFactory.section("Audio")
	column.add_child(audio_section.get_parent())
	for bus_name in AudioManager.BUS_NAMES:
		var row := HBoxContainer.new()
		audio_section.add_child(row)
		var label := UiFactory.body_label(bus_name, 18)
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.value = AudioManager.get_bus_volume(bus_name)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float) -> void: AudioManager.set_bus_volume(bus_name, value))
		row.add_child(slider)
	var graphics := UiFactory.horizontal_actions()
	column.add_child(graphics)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Vollbild"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(_toggle_fullscreen)
	graphics.add_child(fullscreen)
	var vsync := CheckButton.new()
	vsync.text = "V-Sync"
	vsync.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vsync.toggled.connect(_toggle_vsync)
	graphics.add_child(vsync)
	slot_box = VBoxContainer.new()
	column.add_child(slot_box)
	_refresh_slots()
	var actions := UiFactory.horizontal_actions()
	column.add_child(actions)
	actions.add_child(UiFactory.button("Zurück", close_menu, 180))
	actions.add_child(UiFactory.button("Hauptmenü", _main_menu, 180))
	actions.add_child(UiFactory.button("Spiel beenden", func() -> void: get_tree().quit(), 180))


func _refresh_slots() -> void:
	UiFactory.clear_container(slot_box)
	slot_box.add_child(UiFactory.title_label("Spielstände", 27))
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		var info := SaveSystem.slot_info(slot)
		var row := HBoxContainer.new()
		slot_box.add_child(row)
		var text := "Slot %d · Tag %d" % [slot, info.get("day", 1)] if info.get("exists", false) else "Slot %d · leer" % slot
		var label := UiFactory.body_label(text, 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var save_button := UiFactory.button("Speichern", func() -> void: SaveSystem.save_game(slot); _refresh_slots(), 130)
		save_button.disabled = not GameState.game_active
		row.add_child(save_button)
		var load_button := UiFactory.button("Laden", func() -> void: _load_slot(slot), 110)
		load_button.disabled = not info.get("exists", false)
		row.add_child(load_button)
		var delete_button := UiFactory.button("Löschen", func() -> void: SaveSystem.delete_slot(slot); _refresh_slots(), 110)
		delete_button.disabled = not info.get("exists", false)
		row.add_child(delete_button)


func _toggle_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioManager.save_settings()


func _toggle_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	AudioManager.save_settings()


func _load_slot(slot: int) -> void:
	if SaveSystem.load_game(slot):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/world_map/world_map.tscn")


func close_menu() -> void:
	AudioManager.save_settings()
	get_tree().paused = false
	queue_free()


func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		close_menu()
