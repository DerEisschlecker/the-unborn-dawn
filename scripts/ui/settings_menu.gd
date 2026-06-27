# Purpose: Pause overlay or main-menu submenu for audio, graphics, save/load slots, and leaving the game.
# Public API: close_menu(), embedded_mode for main-menu panel embedding.
# Dependencies: AudioManager, DisplayManager, SaveSystem, GameState, UiFactory, OrnateUiStyles.
extends VBoxContainer

var embedded_mode := false
var slot_box: VBoxContainer
var monitor_option: OptionButton
var resolution_option: OptionButton
var window_mode_option: OptionButton
var _was_paused := false
var _syncing_graphics := false


func _ready() -> void:
	theme = UiFactory.DARK_THEME
	if embedded_mode:
		process_mode = Node.PROCESS_MODE_INHERIT
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		add_theme_constant_override("separation", 0)
		_build_embedded()
	else:
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_was_paused = get_tree().paused
		if GameState.game_active:
			get_tree().paused = true
		_build_overlay()
	EventBus.display_settings_changed.connect(_on_display_settings_changed)


func _exit_tree() -> void:
	if EventBus.display_settings_changed.is_connected(_on_display_settings_changed):
		EventBus.display_settings_changed.disconnect(_on_display_settings_changed)
	if embedded_mode:
		AudioManager.save_settings()
		DisplayManager.save_settings()


func _embedded_tab_height() -> int:
	return 360 if UiFactory.is_compact_screen(self) else 420


func _build_embedded() -> void:
	var tabs := _make_tab_container(false)
	tabs.custom_minimum_size = Vector2(0.0, float(_embedded_tab_height()))
	add_child(tabs)


func _build_overlay() -> void:
	var overlay_root := Control.new()
	overlay_root.name = "OverlayRoot"
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(shade)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_margins := UiFactory.overlay_screen_margins(self, UiFactory.is_compact_screen(self))
	frame.add_theme_constant_override("margin_left", overlay_margins.left)
	frame.add_theme_constant_override("margin_right", overlay_margins.right)
	frame.add_theme_constant_override("margin_top", overlay_margins.top)
	frame.add_theme_constant_override("margin_bottom", overlay_margins.bottom)
	overlay_root.add_child(frame)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UiFactory.menu_panel_size(self).x, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiFactory.menu_panel_style())
	center.add_child(panel)
	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	panel.add_child(shell)
	var compact := UiFactory.is_compact_screen(self)
	shell.add_child(UiFactory.ornate_heading("PAUSE & EINSTELLUNGEN", 28 if compact else 32))
	var hint := UiFactory.ornate_muted_label("ESC schliesst dieses Menue.", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell.add_child(hint)
	shell.add_child(UiFactory.menu_divider())
	var tabs := _make_tab_container(true)
	shell.add_child(tabs)
	var actions := UiFactory.horizontal_actions()
	shell.add_child(actions)
	actions.add_child(UiFactory.ornate_action_button("Zurueck", close_menu, 170))
	if GameState.game_active:
		actions.add_child(UiFactory.ornate_action_button("Hauptmenue", _main_menu, 170))
	actions.add_child(UiFactory.ornate_action_button("Spiel beenden", func() -> void: get_tree().quit(), 170, AudioManager.UiClickKind.DANGER))


func _make_tab_container(expand_vertical: bool) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand_vertical else Control.SIZE_SHRINK_BEGIN
	tabs.mouse_filter = Control.MOUSE_FILTER_STOP
	UiFactory.apply_ornate_tabs(tabs)
	tabs.add_child(_build_general_tab())
	tabs.set_tab_title(0, "Allgemein")
	tabs.add_child(_build_audio_tab())
	tabs.set_tab_title(1, "Audio")
	tabs.add_child(_build_graphics_tab())
	tabs.set_tab_title(2, "Grafik")
	tabs.add_child(_build_save_tab())
	tabs.set_tab_title(3, "Spielstaende")
	return tabs


func _build_page_shell() -> Dictionary:
	var page := MarginContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("margin_left", 4)
	page.add_theme_constant_override("margin_right", 4)
	page.add_theme_constant_override("margin_top", 6)
	page.add_theme_constant_override("margin_bottom", 6)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	page.add_child(column)
	return {"page": page, "column": column}


func _build_general_tab() -> Control:
	var shell := _build_page_shell()
	var page: MarginContainer = shell.page
	var column: VBoxContainer = shell.column
	var section := UiFactory.ornate_settings_section("Spielverhalten")
	column.add_child(section.get_parent())
	var confirm_skip := CheckButton.new()
	confirm_skip.text = "Runde automatisch beenden."
	confirm_skip.button_pressed = not AudioManager.should_confirm_skip_turn_with_ap()
	confirm_skip.toggled.connect(func(enabled: bool) -> void: AudioManager.set_confirm_skip_turn_with_ap(not enabled))
	UiFactory.apply_ornate_check(confirm_skip)
	UiFactory.wire_toggle_sound(confirm_skip)
	section.add_child(confirm_skip)
	return page


func _build_audio_tab() -> Control:
	var shell := _build_page_shell()
	var page: MarginContainer = shell.page
	var column: VBoxContainer = shell.column
	var section := UiFactory.ornate_settings_section("Lautstaerke")
	column.add_child(section.get_parent())
	for bus_name in AudioManager.BUS_NAMES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		section.add_child(row)
		row.add_child(UiFactory.ornate_field_label(bus_name, 130.0))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.value = AudioManager.get_bus_volume(bus_name)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiFactory.apply_ornate_slider(slider)
		slider.value_changed.connect(func(value: float) -> void: AudioManager.set_bus_volume(bus_name, value))
		row.add_child(slider)
	return page


func _build_graphics_tab() -> Control:
	var shell := _build_page_shell()
	var page: MarginContainer = shell.page
	var column: VBoxContainer = shell.column
	var section := UiFactory.ornate_settings_section("Anzeige")
	column.add_child(section.get_parent())
	section.add_child(_graphics_row("Monitor", _make_monitor_option()))
	section.add_child(_graphics_row("Aufloesung", _make_resolution_option()))
	section.add_child(_graphics_row("Fenstermodus", _make_window_mode_option()))
	var vsync_row := HBoxContainer.new()
	vsync_row.add_theme_constant_override("separation", 12)
	vsync_row.add_child(UiFactory.ornate_field_label("V-Sync", 130.0))
	var vsync := CheckButton.new()
	vsync.text = "Aktiviert"
	vsync.button_pressed = DisplayManager.vsync_enabled
	vsync.toggled.connect(_toggle_vsync)
	UiFactory.apply_ornate_check(vsync)
	UiFactory.wire_toggle_sound(vsync)
	vsync_row.add_child(vsync)
	section.add_child(vsync_row)
	var detect_row := HBoxContainer.new()
	detect_row.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(detect_row)
	detect_row.add_child(UiFactory.ornate_action_button("Automatisch erkennen", _auto_detect_display, 240, AudioManager.UiClickKind.CONFIRM))
	var note := UiFactory.ornate_muted_label(
		"Monitor und Aufloesung werden beim ersten Start automatisch gesetzt. Aenderungen gelten sofort.",
		13,
		true
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(note)
	return page


func _build_save_tab() -> Control:
	var shell := _build_page_shell()
	var page: MarginContainer = shell.page
	var column: VBoxContainer = shell.column
	var section := UiFactory.ornate_settings_section("Speicherplaetze")
	column.add_child(section.get_parent())
	slot_box = VBoxContainer.new()
	slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_box.add_theme_constant_override("separation", 8)
	section.add_child(slot_box)
	_refresh_slots()
	return page


func _graphics_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiFactory.ornate_field_label(label_text, 130.0))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _configure_option_button(option: OptionButton) -> OptionButton:
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(220.0, 40.0)
	option.fit_to_longest_item = true
	option.clip_text = true
	UiFactory.apply_ornate_option(option)
	return option


func _make_monitor_option() -> OptionButton:
	monitor_option = _configure_option_button(OptionButton.new())
	_populate_monitor_options()
	monitor_option.item_selected.connect(_on_monitor_selected)
	return monitor_option


func _make_resolution_option() -> OptionButton:
	resolution_option = _configure_option_button(OptionButton.new())
	_populate_resolution_options()
	resolution_option.item_selected.connect(_on_resolution_selected)
	return resolution_option


func _make_window_mode_option() -> OptionButton:
	window_mode_option = _configure_option_button(OptionButton.new())
	for mode in [
		DisplayManager.WindowMode.WINDOWED,
		DisplayManager.WindowMode.FULLSCREEN,
		DisplayManager.WindowMode.BORDERLESS,
		DisplayManager.WindowMode.MAXIMIZED,
	]:
		window_mode_option.add_item(str(DisplayManager.WINDOW_MODE_LABELS.get(mode, mode)), int(mode))
	window_mode_option.select(DisplayManager.window_mode)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	return window_mode_option


func _populate_monitor_options() -> void:
	if not is_instance_valid(monitor_option):
		return
	monitor_option.clear()
	for index in range(DisplayManager.get_screen_count()):
		monitor_option.add_item(DisplayManager.get_screen_label(index), index)
	monitor_option.select(clampi(DisplayManager.screen_index, 0, maxi(0, monitor_option.item_count - 1)))


func _populate_resolution_options() -> void:
	if not is_instance_valid(resolution_option):
		return
	resolution_option.clear()
	var selected := -1
	var options: Array[Vector2i] = DisplayManager.get_available_resolutions(DisplayManager.screen_index)
	for index in range(options.size()):
		var res_size: Vector2i = options[index]
		resolution_option.add_item("%d x %d" % [res_size.x, res_size.y], index)
		resolution_option.set_item_metadata(index, res_size)
		if res_size == DisplayManager.resolution:
			selected = index
	if selected < 0 and options.size() > 0:
		selected = options.size() - 1
	if selected >= 0:
		resolution_option.select(selected)


func _on_monitor_selected(index: int) -> void:
	if _syncing_graphics:
		return
	DisplayManager.set_screen(int(monitor_option.get_item_id(index)))
	_sync_graphics_controls()


func _on_resolution_selected(index: int) -> void:
	if _syncing_graphics:
		return
	var res_size: Variant = resolution_option.get_item_metadata(index)
	if typeof(res_size) != TYPE_VECTOR2I:
		return
	DisplayManager.set_resolution(res_size)
	_sync_graphics_controls()


func _on_window_mode_selected(index: int) -> void:
	if _syncing_graphics:
		return
	DisplayManager.set_window_mode(window_mode_option.get_item_id(index))


func _toggle_vsync(enabled: bool) -> void:
	DisplayManager.set_vsync(enabled)


func _auto_detect_display() -> void:
	DisplayManager.auto_detect()
	DisplayManager.apply_settings()
	DisplayManager.save_settings()
	_sync_graphics_controls()


func _sync_graphics_controls() -> void:
	_syncing_graphics = true
	_populate_monitor_options()
	_populate_resolution_options()
	if is_instance_valid(window_mode_option):
		window_mode_option.select(DisplayManager.window_mode)
	_syncing_graphics = false


func _on_display_settings_changed() -> void:
	_sync_graphics_controls()


func _refresh_slots() -> void:
	if not is_instance_valid(slot_box):
		return
	UiFactory.clear_container(slot_box)
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		var info := SaveSystem.slot_info(slot)
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		slot_box.add_child(row)
		var text := "Slot %d · Tag %d" % [slot, info.get("day", 1)] if info.get("exists", false) else "Slot %d · leer" % slot
		var label := UiFactory.ornate_muted_label(text, 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var save_button := UiFactory.ornate_action_button("Speichern", func() -> void: SaveSystem.save_game(slot); _refresh_slots(), 108, AudioManager.UiClickKind.CONFIRM)
		save_button.disabled = not GameState.game_active
		if save_button.disabled:
			OrnateUiStyles.apply_button_theme(save_button, false, true)
		row.add_child(save_button)
		var load_button := UiFactory.ornate_action_button("Laden", func() -> void: _load_slot(slot), 96, AudioManager.UiClickKind.CONFIRM)
		load_button.disabled = not info.get("exists", false)
		if load_button.disabled:
			OrnateUiStyles.apply_button_theme(load_button, false, true)
		row.add_child(load_button)
		var delete_button := UiFactory.ornate_action_button("Loeschen", func() -> void: SaveSystem.delete_slot(slot); _refresh_slots(), 96, AudioManager.UiClickKind.DANGER)
		delete_button.disabled = not info.get("exists", false)
		if delete_button.disabled:
			OrnateUiStyles.apply_button_theme(delete_button, false, true)
		row.add_child(delete_button)


func _load_slot(slot: int) -> void:
	if SaveSystem.load_game(slot):
		get_tree().paused = false
		get_tree().change_scene_to_file(GameState.resume_scene_after_load())


func close_menu() -> void:
	AudioManager.save_settings()
	DisplayManager.save_settings()
	get_tree().paused = _was_paused
	queue_free()


func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if embedded_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		close_menu()
