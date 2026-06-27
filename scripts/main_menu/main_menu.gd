# Purpose: Fullscreen bunker main menu with centered apocalyptic UI and atmosphere effects.
# Public API: New game, continue, load slots, settings, and quit.
# Dependencies: GameState, SaveSystem, SettingsMenu, StorySlide, AudioManager.
extends Control

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const CLASS_ORDER: Array[String] = ["scout", "medic", "guardian", "tinker"]
const MENU_BACKGROUND_PATH := "res://assets/environments/backgrounds/main_menu_bunker.png"
const MENU_ITEMS := [
	{"id": "continue", "label": "WEITERSPIELEN"},
	{"id": "new_game", "label": "NEUES SPIEL"},
	{"id": "load", "label": "SPIEL LADEN"},
	{"id": "settings", "label": "EINSTELLUNGEN"},
	{"id": "quit", "label": "BEENDEN"},
]

var menu_column: VBoxContainer
var menu_root: CenterContainer
var menu_panel: PanelContainer
var menu_button_box: VBoxContainer
var submenu_center: CenterContainer
var submenu_panel: PanelContainer
var name_input: LineEdit
var selected_class := "medic"
var class_summary: Label
var character_summary: Label
var hero_profile_panel: PanelContainer
var hero_class_label: Label
var hero_desc_label: Label
var hero_stats_grid: GridContainer
var hero_loadout_label: Label
var preview_visual_host: Control
var hero_showcase_frame: PanelContainer
var class_buttons: Dictionary = {}
var menu_background: TextureRect
var horror_tint: ColorRect
var vignette_shade: ColorRect
var lightning_flash: ColorRect
var title_label: Label
var menu_buttons: Dictionary = {}
var rain_nodes: Array[ColorRect] = []
var ash_nodes: Array[ColorRect] = []
var smoke_nodes: Array[ColorRect] = []
var menu_anim_time := 0.0
var next_lightning_at := 8.0
var lightning_alpha := 0.0
var compact_character_menu := false
var is_character_panel := false
var is_settings_panel := false
var selected_menu_id := "continue"


func _ready() -> void:
	randomize()
	set_process(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_menu_ambience()
	_build_atmosphere()
	_build_center_menu()
	_show_main_menu()


func _exit_tree() -> void:
	AudioManager.stop_menu_ambience()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_layout_menu_panels")


func _process(delta: float) -> void:
	menu_anim_time += delta
	_update_menu_animation(delta)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	for drop in rain_nodes:
		if not is_instance_valid(drop):
			continue
		var speed := float(drop.get_meta("speed", 420.0))
		var wind := float(drop.get_meta("wind", -18.0))
		drop.position += Vector2(wind, speed) * delta
		if drop.position.y > viewport_size.y + 48.0 or drop.position.x < -96.0:
			drop.position = Vector2(
				randf_range(-96.0, viewport_size.x + 96.0),
				randf_range(-160.0, -24.0)
			)
	for ash in ash_nodes:
		if not is_instance_valid(ash):
			continue
		var ash_speed := float(ash.get_meta("speed", 20.0))
		var drift := float(ash.get_meta("drift", 0.0))
		ash.position += Vector2(drift, -ash_speed) * delta
		if ash.position.y < -16.0 or ash.position.x < -24.0 or ash.position.x > viewport_size.x + 24.0:
			ash.position = Vector2(randf_range(0.0, viewport_size.x), viewport_size.y + randf_range(8.0, 120.0))
	for smoke in smoke_nodes:
		if not is_instance_valid(smoke):
			continue
		var smoke_speed := float(smoke.get_meta("speed", 10.0))
		var lift := float(smoke.get_meta("lift", 0.0))
		var gust := sin(menu_anim_time * 0.42 + float(smoke.get_instance_id()) * 0.001) * 18.0
		smoke.position.x += (smoke_speed + gust) * delta
		smoke.position.y += lift * delta
		if smoke.position.x > viewport_size.x + 140.0:
			smoke.position.x = -smoke.size.x - randf_range(60.0, 220.0)
			smoke.position.y = randf_range(viewport_size.y * 0.12, viewport_size.y * 0.78)


func _show_main_menu() -> void:
	_hide_submenu()
	if is_instance_valid(menu_root):
		menu_root.visible = true
	_refresh_menu_buttons()
	if SaveSystem.any_save_exists():
		_set_selected_menu("continue")
	else:
		_set_selected_menu("new_game")


func _refresh_menu_buttons() -> void:
	var has_save: bool = SaveSystem.any_save_exists()
	var latest: Dictionary = SaveSystem.latest_save_info()
	var has_manual_save := _any_manual_save_exists()
	for item in MENU_ITEMS:
		var id := str(item.id)
		if not menu_buttons.has(id):
			continue
		var button: Button = menu_buttons[id]
		match id:
			"continue":
				button.disabled = not has_save
				if has_save:
					button.text = "WEITERSPIELEN — Tag %d" % int(latest.get("day", 1))
				else:
					button.text = "WEITERSPIELEN"
			"load":
				button.disabled = not has_manual_save
			_:
				button.disabled = false
	_update_menu_button_styles()


func _any_manual_save_exists() -> bool:
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		if SaveSystem.slot_info(slot).get("exists", false):
			return true
	return false


func _build_atmosphere() -> void:
	var viewport := UiFactory.viewport_size(self)
	theme = UiFactory.DARK_THEME
	ash_nodes.clear()
	smoke_nodes.clear()
	rain_nodes.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := TextureRect.new()
	background.texture = _background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color(0.68, 0.70, 0.74, 1.0)
	background.scale = Vector2(1.04, 1.04)
	background.pivot_offset = viewport * 0.5
	menu_background = background
	menu_anim_time = 0.0
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	vignette_shade = ColorRect.new()
	vignette_shade.color = Color(0.02, 0.0, 0.0, 0.22)
	vignette_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette_shade)
	_spawn_rain(viewport)
	_spawn_ash()
	_spawn_smoke()
	horror_tint = ColorRect.new()
	horror_tint.color = Color(0.12, 0.02, 0.01, 0.06)
	horror_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	horror_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horror_tint)
	lightning_flash = ColorRect.new()
	lightning_flash.color = Color(0.72, 0.82, 1.0, 0.0)
	lightning_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lightning_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lightning_flash)
	next_lightning_at = menu_anim_time + randf_range(4.0, 9.0)
	lightning_alpha = 0.0


func _background_texture() -> Texture2D:
	if ResourceLoader.exists(MENU_BACKGROUND_PATH):
		var tex := load(MENU_BACKGROUND_PATH) as Texture2D
		if tex != null:
			return tex
	return null


func _build_center_menu() -> void:
	menu_root = CenterContainer.new()
	menu_root.name = "MenuRoot"
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(menu_root)
	menu_panel = PanelContainer.new()
	menu_panel.name = "MenuPanel"
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_theme_stylebox_override("panel", _menu_panel_style())
	menu_root.add_child(menu_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	menu_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	title_label = Label.new()
	title_label.text = "LAST LIGHT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 46 if not _compact_menu() else 38)
	title_label.add_theme_color_override("font_color", Color(0.78, 0.58, 0.32, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.01, 0.98))
	title_label.add_theme_constant_override("outline_size", 4)
	column.add_child(title_label)
	var tagline := Label.new()
	tagline.text = "Die lange Nacht wartet."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14 if not _compact_menu() else 12)
	tagline.add_theme_color_override("font_color", Color(0.58, 0.54, 0.52, 0.78))
	column.add_child(tagline)
	var divider := HSeparator.new()
	divider.modulate = Color(0.72, 0.56, 0.28, 0.55)
	column.add_child(divider)
	menu_button_box = VBoxContainer.new()
	menu_button_box.add_theme_constant_override("separation", 6)
	column.add_child(menu_button_box)
	menu_buttons.clear()
	for item in MENU_ITEMS:
		var id := str(item.id)
		var button := _create_menu_button(id, str(item.label), _menu_callback(id))
		menu_buttons[id] = button
		menu_button_box.add_child(button)
	submenu_center = CenterContainer.new()
	submenu_center.name = "SubmenuCenter"
	submenu_center.visible = false
	submenu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	submenu_center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(submenu_center)
	submenu_panel = PanelContainer.new()
	submenu_panel.name = "SubmenuPanel"
	submenu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	submenu_panel.add_theme_stylebox_override("panel", _submenu_panel_style())
	submenu_center.add_child(submenu_panel)
	call_deferred("_layout_menu_panels")


func _layout_menu_panels() -> void:
	var viewport := UiFactory.viewport_size(self)
	var panel_width := clampf(viewport.x * 0.28, 360.0, 460.0)
	if is_instance_valid(menu_panel):
		menu_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	if is_instance_valid(submenu_panel):
		if is_character_panel:
			_layout_character_panel(viewport)
		elif is_settings_panel:
			submenu_panel.custom_minimum_size = Vector2(clampf(viewport.x * 0.62, 640.0, 860.0), 0.0)
		else:
			submenu_panel.custom_minimum_size = Vector2(clampf(viewport.x * 0.38, 380.0, 520.0), 0.0)


func _layout_character_panel(viewport: Vector2) -> void:
	var safe_h := UiFactory.overlay_safe_height(self, 28, 28)
	var panel_w := clampf(viewport.x * 0.72, 660.0, 880.0)
	var panel_h := minf(safe_h * 0.92, safe_h)
	if is_instance_valid(submenu_panel):
		submenu_panel.custom_minimum_size = Vector2(panel_w, panel_h)
		submenu_panel.clip_contents = true
	var showcase_w := clampf(panel_w * 0.55, 340.0, 460.0)
	var showcase_h := clampf(panel_h * 0.46, 320.0, 420.0)
	if is_instance_valid(hero_showcase_frame):
		hero_showcase_frame.custom_minimum_size = Vector2(showcase_w, showcase_h)
	if is_instance_valid(preview_visual_host):
		preview_visual_host.custom_minimum_size = Vector2(showcase_w - 24.0, showcase_h - 64.0)


func _menu_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.006, 0.010, 0.86)
	style.border_color = Color(0.42, 0.18, 0.12, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 16
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _menu_callback(id: String) -> Callable:
	match id:
		"continue":
			return _continue_autosave
		"new_game":
			return _show_character_select
		"load":
			return _show_load_menu
		"settings":
			return _open_settings
		"quit":
			return func() -> void: get_tree().quit()
	push_warning("MainMenu: unknown menu id '%s'" % id)
	return func() -> void: pass


func _create_menu_button(id: String, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 48 if not _compact_menu() else 42
	button.add_theme_font_size_override("font_size", 17 if not _compact_menu() else 15)
	button.add_theme_color_override("font_color", Color("#e8ecf2"))
	button.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	button.add_theme_color_override("font_pressed_color", Color("#e0a070"))
	button.add_theme_color_override("font_disabled_color", Color("#5a616b"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var click_kind := AudioManager.UiClickKind.MENU
	if id == "quit":
		click_kind = AudioManager.UiClickKind.DANGER
	UiFactory.wire_button_sound(button, click_kind)
	button.pressed.connect(callback)
	button.mouse_entered.connect(func() -> void: _set_selected_menu(id))
	OrnateUiStyles.apply_button_theme(button)
	return button


func _submenu_panel_style() -> StyleBoxFlat:
	return _menu_panel_style()


func _horror_heading(text: String, font_size: int = 28) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size if not compact_character_menu else font_size - 4)
	label.add_theme_color_override("font_color", Color(0.78, 0.58, 0.32, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.01, 0.98))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _horror_muted_label(text: String, font_size: int = 13, should_wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.58, 0.54, 0.52, 0.88))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if should_wrap else TextServer.AUTOWRAP_OFF
	return label


func _ornate_frame_style(darker: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.024, 0.96) if darker else Color(0.045, 0.036, 0.030, 0.94)
	style.border_color = Color(0.58, 0.40, 0.18, 0.88)
	style.set_border_width_all(2)
	style.border_width_bottom = 3
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 10
	style.set_corner_radius_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _ornate_divider() -> HSeparator:
	var line := HSeparator.new()
	line.modulate = Color(0.55, 0.38, 0.18, 0.55)
	return line


func _framed_column(title: String, content: Control) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _ornate_frame_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	frame.add_child(column)
	column.add_child(_section_label(title))
	column.add_child(content)
	return frame


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11 if compact_character_menu else 12)
	label.add_theme_color_override("font_color", Color(0.68, 0.42, 0.28, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.01, 0.01, 0.9))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _style_name_input(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82, 1.0))
	input.add_theme_color_override("font_placeholder_color", Color(0.45, 0.40, 0.38, 0.7))
	input.add_theme_color_override("caret_color", Color(0.82, 0.52, 0.32, 1.0))
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.custom_minimum_size.y = 40


func _preview_frame_style() -> StyleBoxFlat:
	return _ornate_frame_style(true)


func _create_choice_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96, 40)
	button.add_theme_font_size_override("font_size", 12 if compact_character_menu else 13)
	button.add_theme_color_override("font_color", Color("#e8ecf2"))
	button.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	button.add_theme_color_override("font_pressed_color", Color("#e0a070"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFactory.wire_button_sound(button, AudioManager.UiClickKind.MENU)
	button.pressed.connect(callback)
	OrnateUiStyles.apply_button_theme(button)
	return button


func _create_footer_button(label: String, callback: Callable, click_kind: AudioManager.UiClickKind = AudioManager.UiClickKind.MENU) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(160, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#e8ecf2"))
	button.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	button.add_theme_color_override("font_pressed_color", Color("#e0a070"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFactory.wire_button_sound(button, click_kind)
	button.pressed.connect(callback)
	OrnateUiStyles.apply_button_theme(button)
	return button


func _refresh_choice_group(buttons: Dictionary, selected: String) -> void:
	for key in buttons:
		var button: Button = buttons[key]
		var highlighted: bool = str(key) == selected
		button.disabled = false
		button.add_theme_stylebox_override("normal", OrnateUiStyles.menu_button_style(highlighted))


func _set_selected_menu(id: String) -> void:
	selected_menu_id = id
	_update_menu_button_styles()


func _update_menu_button_styles() -> void:
	for id in menu_buttons:
		var button: Button = menu_buttons[id]
		var highlighted: bool = id == selected_menu_id and not button.disabled
		button.add_theme_stylebox_override("normal", OrnateUiStyles.menu_button_style(highlighted, button.disabled))


func _hide_submenu() -> void:
	is_character_panel = false
	is_settings_panel = false
	if is_instance_valid(submenu_center):
		submenu_center.visible = false
	if is_instance_valid(submenu_panel):
		for child in submenu_panel.get_children():
			submenu_panel.remove_child(child)
			child.queue_free()


func _show_submenu(title: String) -> VBoxContainer:
	_hide_submenu()
	is_character_panel = false
	if is_instance_valid(menu_root):
		menu_root.visible = false
	submenu_center.visible = true
	submenu_panel.add_theme_stylebox_override("panel", _menu_panel_style())
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	submenu_panel.add_child(shell)
	shell.add_child(_horror_heading(title, 24 if not _compact_menu() else 20))
	menu_column = VBoxContainer.new()
	menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_column.add_theme_constant_override("separation", 6)
	shell.add_child(menu_column)
	var back_row := CenterContainer.new()
	shell.add_child(back_row)
	back_row.add_child(_create_footer_button("ZURUECK", _show_main_menu))
	call_deferred("_layout_menu_panels")
	return menu_column


func _show_load_menu() -> void:
	menu_column = _show_submenu("SPIEL LADEN")
	var hint := _horror_muted_label("Waehle einen Speicherplatz.", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(hint)
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		var info := SaveSystem.slot_info(slot)
		var label := "Slot %d — leer" % slot
		if info.get("exists", false):
			label = "Slot %d — Tag %d  (%s)" % [slot, int(info.get("day", 1)), str(info.get("saved_at", ""))]
		var button := _create_choice_button(label, Callable(self, "_load_save_slot").bind(slot))
		button.custom_minimum_size = Vector2(320, 40)
		button.disabled = not info.get("exists", false)
		if button.disabled:
			button.add_theme_color_override("font_color", Color("#5a616b"))
			button.add_theme_stylebox_override("normal", OrnateUiStyles.menu_button_style(false, true))
		menu_column.add_child(button)


func _load_save_slot(slot: int) -> void:
	if SaveSystem.load_game(slot):
		get_tree().change_scene_to_file(GameState.resume_scene_after_load())


func _compact_menu() -> bool:
	return UiFactory.is_compact_screen(self)


func _spawn_ash() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	for index in range(34):
		var ash := ColorRect.new()
		var ash_size := randf_range(1.0, 2.8)
		ash.size = Vector2(ash_size, ash_size)
		ash.position = Vector2(
			randf_range(0.0, viewport_size.x),
			randf_range(viewport_size.y * 0.45, viewport_size.y * 0.95)
		)
		ash.color = Color(0.28, 0.26, 0.24, randf_range(0.10, 0.28))
		ash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ash.set_meta("speed", randf_range(8.0, 24.0))
		ash.set_meta("drift", randf_range(-8.0, 12.0))
		ash_nodes.append(ash)
		add_child(ash)


func _spawn_rain(viewport_size: Vector2) -> void:
	for index in range(220):
		var drop := ColorRect.new()
		var length := randf_range(12.0, 34.0)
		drop.size = Vector2(randf_range(1.0, 2.0), length)
		drop.color = Color(0.52, 0.56, 0.64, randf_range(0.08, 0.24))
		drop.rotation = deg_to_rad(randf_range(-84.0, -76.0))
		drop.position = Vector2(
			randf_range(-120.0, viewport_size.x + 120.0),
			randf_range(-viewport_size.y * 0.2, viewport_size.y)
		)
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drop.set_meta("speed", randf_range(360.0, 680.0))
		drop.set_meta("wind", randf_range(-34.0, -14.0))
		rain_nodes.append(drop)
		add_child(drop)


func _spawn_smoke() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	for index in range(18):
		var smoke := ColorRect.new()
		smoke.size = Vector2(randf_range(220.0, 520.0), randf_range(24.0, 72.0))
		smoke.position = Vector2(randf_range(-180.0, viewport_size.x), randf_range(viewport_size.y * 0.18, viewport_size.y * 0.72))
		smoke.color = Color(0.02, 0.022, 0.028, randf_range(0.18, 0.38))
		smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		smoke.set_meta("speed", randf_range(10.0, 34.0))
		smoke.set_meta("lift", randf_range(-6.0, 4.0))
		smoke_nodes.append(smoke)
		add_child(smoke)


func _update_menu_animation(delta: float) -> void:
	var slow_pulse := (sin(menu_anim_time * 0.38) + 1.0) * 0.5
	var dread_pulse := (sin(menu_anim_time * 1.6) + 1.0) * 0.5
	var gust := sin(menu_anim_time * 0.31) * sin(menu_anim_time * 0.09)
	if is_instance_valid(menu_background):
		var scale_value := lerpf(1.06, 1.10, slow_pulse)
		menu_background.scale = Vector2(scale_value, scale_value)
		menu_background.position.x = gust * 22.0 + sin(menu_anim_time * 0.17) * 8.0
		menu_background.position.y = cos(menu_anim_time * 0.11) * 7.0
		menu_background.modulate = Color(
			lerpf(0.58, 0.66, dread_pulse),
			lerpf(0.60, 0.66, dread_pulse),
			lerpf(0.64, 0.70, dread_pulse),
			1.0
		)
	if is_instance_valid(horror_tint):
		var flicker := 1.0
		if randf() < delta * 2.4:
			flicker = randf_range(0.55, 1.0)
		horror_tint.color = Color(
			lerpf(0.14, 0.22, dread_pulse),
			lerpf(0.01, 0.04, dread_pulse),
			lerpf(0.0, 0.02, dread_pulse),
			lerpf(0.05, 0.12, dread_pulse) * flicker
		)
	if is_instance_valid(vignette_shade):
		vignette_shade.color = Color(
			0.02,
			0.0,
			0.0,
			lerpf(0.18, 0.30, slow_pulse)
		)
	if is_instance_valid(title_label):
		var title_flicker := 1.0
		if randf() < delta * 1.2:
			title_flicker = randf_range(0.72, 1.0)
		title_label.modulate = Color(
			lerpf(0.82, 1.0, dread_pulse) * title_flicker,
			lerpf(0.62, 0.78, dread_pulse) * title_flicker,
			lerpf(0.42, 0.58, dread_pulse) * title_flicker,
			1.0
		)
	if is_instance_valid(menu_panel):
		menu_panel.modulate = Color(
			lerpf(0.92, 1.0, dread_pulse),
			lerpf(0.90, 0.96, dread_pulse),
			lerpf(0.88, 0.94, dread_pulse),
			1.0
		)
	if is_instance_valid(submenu_panel) and submenu_center.visible:
		submenu_panel.modulate = Color(
			lerpf(0.90, 1.0, dread_pulse),
			lerpf(0.88, 0.96, dread_pulse),
			lerpf(0.86, 0.94, dread_pulse),
			1.0
		)
	if menu_anim_time >= next_lightning_at:
		_trigger_lightning()
	lightning_alpha = maxf(0.0, lightning_alpha - delta * 2.8)
	if is_instance_valid(lightning_flash):
		lightning_flash.color = Color(0.62, 0.70, 0.92, lightning_alpha)


func _trigger_lightning() -> void:
	lightning_alpha = randf_range(0.28, 0.52)
	next_lightning_at = menu_anim_time + randf_range(4.0, 10.0)
	if ResourceLoader.exists("res://assets/audio/sfx/environment/thunder.wav"):
		AudioManager.play_sfx("res://assets/audio/sfx/environment/thunder.wav", randf_range(-20.0, -14.0), randf_range(0.82, 1.08))
	if randf() < 0.35 and ResourceLoader.exists("res://assets/audio/sfx/weapons/gunshot.wav"):
		AudioManager.play_sfx("res://assets/audio/sfx/weapons/gunshot.wav", randf_range(-32.0, -26.0), randf_range(0.68, 0.92))


func _show_character_select() -> void:
	_hide_submenu()
	is_character_panel = true
	compact_character_menu = _compact_menu()
	if is_instance_valid(menu_root):
		menu_root.visible = false
	submenu_center.visible = true
	submenu_panel.add_theme_stylebox_override("panel", _menu_panel_style())
	selected_class = "medic"
	class_buttons.clear()
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8 if compact_character_menu else 10)
	submenu_panel.add_child(shell)
	shell.add_child(_horror_heading("NEUES SPIEL"))
	var hint := _horror_muted_label("Wer bringt Elena durch die lange Nacht?", 13 if compact_character_menu else 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell.add_child(hint)
	var name_center := CenterContainer.new()
	shell.add_child(name_center)
	var name_frame := PanelContainer.new()
	name_frame.custom_minimum_size.x = 340
	name_frame.add_theme_stylebox_override("panel", _ornate_frame_style())
	name_center.add_child(name_frame)
	var name_inner := VBoxContainer.new()
	name_inner.add_theme_constant_override("separation", 6)
	name_frame.add_child(name_inner)
	name_inner.add_child(_section_label("CHARAKTERNAME"))
	name_input = LineEdit.new()
	name_input.text = "Morgan"
	name_input.placeholder_text = "Survivor-Name"
	name_input.custom_minimum_size = Vector2(300, 38)
	_style_name_input(name_input)
	name_inner.add_child(name_input)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(body)
	var showcase_column := VBoxContainer.new()
	showcase_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase_column.size_flags_stretch_ratio = 1.55
	body.add_child(showcase_column)
	hero_showcase_frame = PanelContainer.new()
	hero_showcase_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_showcase_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_showcase_frame.add_theme_stylebox_override("panel", _preview_frame_style())
	hero_showcase_frame.custom_minimum_size = Vector2(360, 400)
	showcase_column.add_child(hero_showcase_frame)
	var showcase_inner := VBoxContainer.new()
	showcase_inner.add_theme_constant_override("separation", 8)
	hero_showcase_frame.add_child(showcase_inner)
	showcase_inner.add_child(_section_label("CHARAKTER"))
	preview_visual_host = Control.new()
	preview_visual_host.custom_minimum_size = Vector2(336, 340)
	preview_visual_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_visual_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_inner.add_child(preview_visual_host)
	character_summary = _horror_muted_label("", 12, true)
	character_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	showcase_inner.add_child(character_summary)
	var class_grid := GridContainer.new()
	class_grid.columns = 2
	class_grid.add_theme_constant_override("h_separation", 8)
	class_grid.add_theme_constant_override("v_separation", 8)
	var classes: Dictionary = _class_catalog()
	for class_id in CLASS_ORDER:
		var class_data: Dictionary = classes.get(class_id, {})
		var class_button := _create_choice_button(
			str(class_data.get("name", class_id)),
			Callable(self, "_select_class").bind(class_id)
		)
		class_button.tooltip_text = str(class_data.get("description", ""))
		class_button.custom_minimum_size = Vector2(132, 36 if compact_character_menu else 40)
		class_grid.add_child(class_button)
		class_buttons[class_id] = class_button
	body.add_child(_framed_column("KLASSE", class_grid))
	hero_profile_panel = PanelContainer.new()
	hero_profile_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero_profile_panel.add_theme_stylebox_override("panel", _ornate_frame_style(true))
	shell.add_child(hero_profile_panel)
	var profile_inner := VBoxContainer.new()
	profile_inner.add_theme_constant_override("separation", 5 if compact_character_menu else 6)
	hero_profile_panel.add_child(profile_inner)
	profile_inner.add_child(_section_label("HELDENPROFIL"))
	hero_class_label = Label.new()
	hero_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_class_label.add_theme_font_size_override("font_size", 16 if not compact_character_menu else 14)
	hero_class_label.add_theme_color_override("font_color", Color(0.86, 0.68, 0.36, 1.0))
	hero_class_label.add_theme_color_override("font_outline_color", Color(0.10, 0.02, 0.01, 0.95))
	hero_class_label.add_theme_constant_override("outline_size", 2)
	profile_inner.add_child(hero_class_label)
	hero_desc_label = _horror_muted_label("", 11 if compact_character_menu else 12, true)
	hero_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_inner.add_child(hero_desc_label)
	profile_inner.add_child(_ornate_divider())
	var stats_header := HBoxContainer.new()
	stats_header.add_theme_constant_override("separation", 0)
	profile_inner.add_child(stats_header)
	var stat_title := _horror_muted_label("ATTRIBUT", 11)
	stat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_header.add_child(stat_title)
	var bonus_title := _horror_muted_label("BONUS", 11)
	bonus_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bonus_title.custom_minimum_size.x = 72
	stats_header.add_child(bonus_title)
	hero_stats_grid = GridContainer.new()
	hero_stats_grid.columns = 2
	hero_stats_grid.add_theme_constant_override("h_separation", 10)
	hero_stats_grid.add_theme_constant_override("v_separation", 2 if compact_character_menu else 3)
	profile_inner.add_child(hero_stats_grid)
	profile_inner.add_child(_ornate_divider())
	var loadout_title := _section_label("STARTAUSRÜSTUNG")
	profile_inner.add_child(loadout_title)
	hero_loadout_label = _horror_muted_label("", 12, true)
	hero_loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_inner.add_child(hero_loadout_label)
	class_summary = hero_loadout_label
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	shell.add_child(actions)
	actions.add_child(_create_footer_button("ZURUECK", _show_main_menu))
	var start_button := _create_footer_button("STARTEN", _start_new_game, AudioManager.UiClickKind.CONFIRM)
	start_button.custom_minimum_size = Vector2(148, 40 if compact_character_menu else 44)
	actions.add_child(start_button)
	call_deferred("_layout_menu_panels")
	_refresh_character_select()


func _class_catalog() -> Dictionary:
	return DataCatalog.player_config().get("classes", {})


func _select_class(class_id: String) -> void:
	selected_class = class_id
	_refresh_character_select()


func _refresh_character_select() -> void:
	_refresh_choice_group(class_buttons, selected_class)
	var data: Dictionary = _class_catalog().get(selected_class, {})
	var appearance_id := GameState.appearance_for_class(selected_class)
	var appearance: Dictionary = GameState.APPEARANCE_OPTIONS.get(appearance_id, {})
	var stats: Dictionary = data.get("stat_bonus", {})
	var inventory: Dictionary = data.get("starting_inventory", {})
	if is_instance_valid(hero_class_label):
		hero_class_label.text = str(data.get("name", selected_class)).to_upper()
	if is_instance_valid(hero_desc_label):
		hero_desc_label.text = str(data.get("description", ""))
	if is_instance_valid(hero_stats_grid):
		for child in hero_stats_grid.get_children():
			hero_stats_grid.remove_child(child)
			child.queue_free()
		var stat_names := _ordered_stat_names(stats)
		if stat_names.is_empty():
			hero_stats_grid.add_child(_profile_stat_name("Keine Klassenboni"))
			hero_stats_grid.add_child(_profile_stat_value("—"))
		else:
			for stat_name in stat_names:
				var value := int(stats[stat_name])
				hero_stats_grid.add_child(_profile_stat_name(_stat_display_name(stat_name)))
				hero_stats_grid.add_child(_profile_stat_value("%+d" % value, value))
	if is_instance_valid(hero_loadout_label):
		hero_loadout_label.text = UiFactory.cost_text(inventory) if not inventory.is_empty() else "Keine Zusatzausrüstung"
	if is_instance_valid(preview_visual_host):
		for child in preview_visual_host.get_children():
			preview_visual_host.remove_child(child)
			child.queue_free()
		var visual: PlayerCharacterVisual = PlayerCharacterVisual.new()
		visual.setup(GameState.player_gender, appearance_id, CharacterVisualContext.Context.SHOWCASE)
		visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_visual_host.add_child(visual)
	if is_instance_valid(character_summary):
		character_summary.text = str(appearance.get("description", ""))
	call_deferred("_layout_menu_panels")


func _ordered_stat_names(stats: Dictionary) -> Array[String]:
	var order := [
		"strength", "dexterity", "intelligence", "vitality", "willpower",
		"max_health", "health", "max_stamina", "stamina", "max_energy", "energy",
		"shield", "melee", "ranged", "accuracy", "defense", "crafting"
	]
	var names: Array[String] = []
	for stat_name in order:
		if stats.has(stat_name):
			names.append(stat_name)
	for stat_name in stats:
		if not names.has(str(stat_name)):
			names.append(str(stat_name))
	return names


func _profile_stat_name(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66, 0.92))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _profile_stat_value(text: String, value: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size.x = 72
	label.add_theme_font_size_override("font_size", 12)
	if value > 0:
		label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.58, 1.0))
	elif value < 0:
		label.add_theme_color_override("font_color", Color(0.88, 0.52, 0.46, 1.0))
	else:
		label.add_theme_color_override("font_color", Color(0.58, 0.56, 0.54, 0.9))
	return label


func _stat_display_name(stat_name: String) -> String:
	return _stat_profile_name(stat_name)


func _stat_profile_name(stat_name: String) -> String:
	match stat_name:
		"strength":
			return "Stärke"
		"dexterity":
			return "Beweglichkeit"
		"intelligence":
			return "Intelligenz"
		"vitality":
			return "Vitalität"
		"willpower":
			return "Willenskraft"
		"max_health":
			return "Max. Leben"
		"max_mana":
			return "Max. Mana"
		"max_stamina":
			return "Max. Ausdauer"
		"max_energy":
			return "Max. Energie"
		"health":
			return "Leben"
		"stamina":
			return "Ausdauer"
		"energy":
			return "Energie"
		"shield":
			return "Schild"
		"melee":
			return "Nahkampf"
		"ranged":
			return "Schusswaffe"
		"accuracy":
			return "Genauigkeit"
		"defense":
			return "Verteidigung"
		"crafting":
			return "Handwerk"
	return stat_name.replace("_", " ").capitalize()


func _start_new_game() -> void:
	GameState.new_game(selected_class, name_input.text if name_input else "Morgan")
	GameState.pending_story = "prologue"
	GameState.story_return_scene = "res://scenes/world_map/world_map.tscn"
	get_tree().change_scene_to_file("res://scenes/cinematics/story_slide.tscn")


func _continue_autosave() -> void:
	if SaveSystem.load_latest_save():
		get_tree().change_scene_to_file(GameState.resume_scene_after_load())


func _open_settings() -> void:
	_hide_submenu()
	is_settings_panel = true
	if is_instance_valid(menu_root):
		menu_root.visible = false
	submenu_center.visible = true
	submenu_panel.add_theme_stylebox_override("panel", _menu_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	submenu_panel.add_child(margin)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)
	shell.add_child(_horror_heading("EINSTELLUNGEN", 24 if not _compact_menu() else 20))
	var hint := _horror_muted_label("Audio, Grafik und Spielverhalten.", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell.add_child(hint)
	var settings := SETTINGS_SCENE.instantiate()
	settings.embedded_mode = true
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell.add_child(settings)
	var back_row := CenterContainer.new()
	shell.add_child(back_row)
	back_row.add_child(_create_footer_button("ZURUECK", _show_main_menu))
	call_deferred("_layout_menu_panels")
