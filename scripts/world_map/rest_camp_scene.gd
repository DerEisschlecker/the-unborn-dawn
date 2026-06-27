# Purpose: Map rest camp with campfire interaction and hour-based recovery.
# Public API: open_rest_dialog(), rest_action().
# Dependencies: GameplayScreen, GameState, TimeSystem, AudioManager.
extends GameplayScreen

const BACKGROUND_PATH := "res://assets/environments/backgrounds/rest_camp_painted.jpg"
const CAMPFIRE_RECT := Rect2(0.40, 0.66, 0.20, 0.18)
const MAX_ROUTE_POINTS := 4

var message_label: Label
var dialog_layer: Control
var preview_label: Label
var hotspot_layer: Control
var selected_hours := 4
var hour_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiFactory.DARK_THEME
	clear_dynamic_children()
	AudioManager.play_scene_music("world_map")
	_build_scene()
	attach_hud()
	call_deferred("_position_campfire_hotspot")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_position_campfire_hotspot()


func _build_scene() -> void:
	var canvas := Control.new()
	canvas.name = "Canvas"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = _load_background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.10)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)

	var overlay := MarginContainer.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var compact := UiFactory.is_compact_screen(self)
	var margins := UiFactory.screen_margins(self, compact)
	overlay.add_theme_constant_override("margin_left", margins.left)
	overlay.add_theme_constant_override("margin_right", margins.right)
	overlay.add_theme_constant_override("margin_top", margins.top)
	overlay.add_theme_constant_override("margin_bottom", UiFactory.hud_bottom_inset(self))
	canvas.add_child(overlay)

	var overlay_box := VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 10)
	overlay.add_child(overlay_box)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 12)
	overlay_box.add_child(header_row)

	var title := UiFactory.title_label("RASTLAGER", 26 if compact else 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var back_button := UiFactory.button("Zurueck zur Karte", _return_to_map, 220, AudioManager.UiClickKind.MENU)
	header_row.add_child(back_button)

	var hint := UiFactory.body_label("Klicke auf das Lagerfeuer, um auszuruhen.", 14, Color("#f0e2c0"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_child(hint)

	message_label = UiFactory.body_label("", 13, Color("#d8e6ff"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_child(message_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_box.add_child(spacer)

	hotspot_layer = Control.new()
	hotspot_layer.name = "HotspotLayer"
	hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hotspot_layer)

	var campfire := Button.new()
	campfire.name = "CampfireButton"
	campfire.flat = true
	campfire.text = ""
	campfire.focus_mode = Control.FOCUS_NONE
	campfire.mouse_filter = Control.MOUSE_FILTER_STOP
	campfire.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	campfire.tooltip_text = "Am Lagerfeuer rasten"
	_apply_campfire_hotspot_style(campfire)
	campfire.pressed.connect(_open_rest_dialog)
	UiFactory.wire_button_sound(campfire, AudioManager.UiClickKind.CONFIRM)
	hotspot_layer.add_child(campfire)

	dialog_layer = Control.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.visible = false
	dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog_layer)
	_build_rest_dialog()


func _load_background_texture() -> Texture2D:
	var imported := load(BACKGROUND_PATH) as Texture2D
	if imported:
		return imported
	var image := Image.new()
	if image.load(BACKGROUND_PATH) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _apply_campfire_hotspot_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_corner_radius_all(14)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.58, 0.18, 0.20)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1.0, 0.45, 0.08, 0.32)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)


func _build_rest_dialog() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "RestDialog"
	panel.custom_minimum_size = Vector2(500, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.10, 0.97)
	panel_style.border_color = Color("#d8b36a")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiFactory.title_label("Rast am Lagerfeuer", 24))
	box.add_child(UiFactory.body_label(
		"Waehle die Rastdauer in Stunden (max. %d)." % GameState.REST_MAX_HOURS,
		14,
		UiFactory.COLOR_MUTED
	))

	var hours_label := UiFactory.body_label("Stunden:", 15)
	hours_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hours_label)

	var hour_grid := GridContainer.new()
	hour_grid.columns = 5
	hour_grid.add_theme_constant_override("h_separation", 8)
	hour_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(hour_grid)
	hour_buttons.clear()
	for hour in range(1, GameState.REST_MAX_HOURS + 1):
		var hour_button := _make_hour_button(hour)
		hour_grid.add_child(hour_button)
		hour_buttons[hour] = hour_button
	_select_hour(4)

	preview_label = UiFactory.body_label(_rest_preview_text(4), 13, Color("#bfe0ff"))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	actions.add_child(UiFactory.button("Rasten", _confirm_rest, 170, AudioManager.UiClickKind.CONFIRM))
	actions.add_child(UiFactory.button("Abbrechen", _close_rest_dialog, 170, AudioManager.UiClickKind.MENU))


func _make_hour_button(hour: int) -> Button:
	var button := Button.new()
	button.text = str(hour)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(72, 40)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	normal.border_color = Color("#5a6475")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color("#d8b36a")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.16, 0.20, 0.12, 0.98)
	pressed.border_color = Color("#d8b36a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#e8edf5"))
	button.add_theme_color_override("font_hover_color", Color("#f0e2c0"))
	button.add_theme_color_override("font_pressed_color", Color("#f0e2c0"))
	button.pressed.connect(func() -> void: _select_hour(hour))
	UiFactory.wire_button_sound(button, AudioManager.UiClickKind.TOGGLE)
	return button


func _select_hour(hour: int) -> void:
	selected_hours = clampi(hour, 1, GameState.REST_MAX_HOURS)
	for value in hour_buttons:
		var button: Button = hour_buttons[value]
		button.set_pressed_no_signal(value == selected_hours)
	_refresh_rest_preview()


func _position_campfire_hotspot() -> void:
	var campfire := hotspot_layer.get_node_or_null("CampfireButton") as Control
	if not is_instance_valid(campfire):
		return
	var viewport_size := get_viewport_rect().size
	var rect := Rect2(
		viewport_size.x * CAMPFIRE_RECT.position.x,
		viewport_size.y * CAMPFIRE_RECT.position.y,
		viewport_size.x * CAMPFIRE_RECT.size.x,
		viewport_size.y * CAMPFIRE_RECT.size.y
	)
	campfire.position = rect.position
	campfire.size = rect.size


func _open_rest_dialog() -> void:
	dialog_layer.visible = true
	_select_hour(selected_hours if selected_hours > 0 else 4)


func _close_rest_dialog() -> void:
	dialog_layer.visible = false


func _close_scene_popup() -> bool:
	if is_instance_valid(dialog_layer) and dialog_layer.visible:
		_close_rest_dialog()
		return true
	return false


func _refresh_rest_preview() -> void:
	if preview_label:
		preview_label.text = _rest_preview_text(selected_hours)


func _rest_preview_text(hours: int) -> String:
	var gains := GameState.preview_rest_gains(hours)
	var route := GameState.preview_rest_route_points(hours, MAX_ROUTE_POINTS)
	return "Erwartet: +%.0f Ausdauer, +%.0f Energie, +%.0f Leben.\nReisepunkte: %d -> %d." % [
		gains.stamina,
		gains.energy,
		gains.health,
		route.current,
		route.next,
	]


func _confirm_rest() -> void:
	var hours := clampi(selected_hours, 1, GameState.REST_MAX_HOURS)
	var gains := GameState.rest_for_hours(hours)
	TimeSystem.advance_rest(hours, "Du rastest %d Stunde(n) am Lagerfeuer." % hours)
	var route_after := GameState.apply_rest_route_points(hours, MAX_ROUTE_POINTS)
	_close_rest_dialog()
	message_label.text = "Du hast %d Stunde(n) gerastet: +%.0f Ausdauer, +%.0f Energie, +%.0f Leben. Reisepunkte: %d." % [
		hours,
		gains.stamina,
		gains.energy,
		gains.health,
		route_after,
	]
	AudioManager.play_sfx("res://assets/audio/sfx/ui/craft.wav", -8.0, 0.9)
	HudStatPreview.clear()
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("refresh"):
		hud.call("refresh")


func _return_to_map() -> void:
	go_to("res://scenes/world_map/world_map.tscn")


func rest_action() -> void:
	_open_rest_dialog()
