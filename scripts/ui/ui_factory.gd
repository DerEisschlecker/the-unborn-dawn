# Purpose: Builds the shared container-based dark interface used by every screen.
# Public API: prepare_screen(), title_label(), body_label(), button(), section(), cost_text().
# Dependencies: res://ui/themes/dark_theme.tres.
class_name UiFactory
extends RefCounted

const DARK_THEME := preload("res://ui/themes/dark_theme.tres")
const COLOR_BACKGROUND := Color("#080c13")
const COLOR_GOLD := Color("#d8b36a")
const COLOR_MUTED := Color("#8e9aab")
const COLOR_DANGER := Color("#c36155")
const RARITY_NORMAL := Color("#858b94")
const RARITY_RARE := Color("#4fa7ff")
const RARITY_EPIC := Color("#b56cff")
const RARITY_LEGENDARY := Color("#f0b84c")

const STAT_ICON_PATHS := {
	"health": "res://assets/ui/icons/health.png",
	"stamina": "res://assets/ui/icons/stamina.png",
	"energy": "res://assets/ui/icons/energy.png",
	"shield": "res://assets/ui/icons/shield.png",
	"hunger": "res://assets/ui/icons/hunger.png",
	"thirst": "res://assets/ui/icons/thirst.png",
	"day": "res://assets/ui/icons/day.png",
}

const HUD_ACTION_ICON_PATHS := {
	"abilities": "res://assets/ui/icons/abilities.png",
	"rest": "res://assets/ui/icons/rest.png",
	"backpack": "res://assets/ui/icons/backpack.png",
}

const STAT_BAR_COLORS := {
	"health": Color("#c8342f"),
	"hunger": Color("#8b5a32"),
	"stamina": Color("#4caf50"),
	"thirst": Color("#6ec8ff"),
	"energy": Color("#5ecf6a"),
	"shield": Color("#4a8fd4"),
	"xp": Color("#d8b36a"),
}


static func stat_icon_path(stat_name: String) -> String:
	return str(STAT_ICON_PATHS.get(stat_name, "res://assets/ui/icons/%s.svg" % stat_name))


static func hud_action_icon_path(action_name: String) -> String:
	return str(HUD_ACTION_ICON_PATHS.get(action_name, ""))


static func stat_bar_color(stat_name: String) -> Color:
	return STAT_BAR_COLORS.get(stat_name, COLOR_MUTED) as Color


static func apply_stat_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.025, 0.035, 0.92)
	background.border_color = fill_color.darkened(0.35)
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)


static func attach_stat_bar_preview(bar: ProgressBar, fill_color: Color) -> Dictionary:
	var parent := bar.get_parent()
	if parent == null:
		return {"bar": bar, "preview": null, "color": fill_color}
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.custom_minimum_size = bar.custom_minimum_size
	layer.size_flags_horizontal = bar.size_flags_horizontal
	layer.size_flags_vertical = bar.size_flags_vertical
	var index := bar.get_index()
	parent.remove_child(bar)
	parent.add_child(layer)
	parent.move_child(layer, index)
	var preview := ProgressBar.new()
	preview.show_percentage = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.visible = false
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_stat_bar(preview, fill_color.darkened(0.28))
	preview.modulate = Color(1.0, 1.0, 1.0, 0.62)
	layer.add_child(preview)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bar)
	return {"bar": bar, "preview": preview, "layer": layer, "color": fill_color}


static func sync_stat_bar_layer_size(entry: Dictionary, size: Vector2) -> void:
	var layer: Control = entry.get("layer")
	if is_instance_valid(layer):
		layer.custom_minimum_size = size


static func update_stat_bar_preview(entry: Dictionary, current: float, maximum: float, projected: float = -1.0) -> void:
	var preview: ProgressBar = entry.get("preview")
	var bar: ProgressBar = entry.get("bar")
	if not is_instance_valid(preview) or not is_instance_valid(bar):
		return
	var max_val := maxf(1.0, maximum)
	var clamped_current := clampf(current, 0.0, max_val)
	var fill_color: Color = entry.get("color", COLOR_MUTED)
	if projected < 0.0 or is_equal_approx(clamped_current, projected):
		bar.max_value = max_val
		bar.value = clamped_current
		apply_stat_bar(bar, fill_color)
		preview.visible = false
		return
	var clamped_projected := clampf(projected, 0.0, max_val)
	var is_gain := clamped_projected > clamped_current
	# Kosten: heller Restwert vorne, verblasster Ist-Wert dahinter.
	# Gewinn: heller Ist-Wert vorne, verblasster Zielwert dahinter.
	apply_stat_bar(preview, fill_color.darkened(0.22) if not is_gain else fill_color.lightened(0.12))
	preview.modulate = Color(1.0, 1.0, 1.0, 0.48 if not is_gain else 0.58)
	preview.max_value = max_val
	preview.value = clamped_current if not is_gain else clamped_projected
	preview.visible = true
	apply_stat_bar(bar, fill_color if not is_gain else fill_color)
	bar.max_value = max_val
	bar.value = clamped_projected if not is_gain else clamped_current


static func stat_preview_tooltip(label: String, current: float, maximum: float, projected: float = -1.0) -> String:
	if projected < 0.0 or is_equal_approx(current, projected):
		return "%s: %.0f / %.0f" % [label, current, maximum]
	return "%s: %.0f -> %.0f / %.0f" % [label, current, projected, maximum]


static func hud_height(node: Node = null) -> int:
	var compact := is_compact_screen(node)
	return 128 if compact else 142


static func hud_bar_texture() -> Texture2D:
	return load(OrnateUiStyles.HUD_TOP_BAR_PATH) as Texture2D


static func configure_hud_bar_background(bar: NinePatchRect) -> void:
	OrnateUiStyles.configure_hud_bar_patch(bar)


static func hud_bottom_inset(node: Node = null, gap: int = 8) -> int:
	return hud_height(node) + gap


static func gameplay_hud_clearance(node: Node, gap: int = 14) -> int:
	var current: Node = node
	while current:
		var hud := current.get_node_or_null("HUD")
		if hud is Control:
			var control := hud as Control
			return roundi(maxf(control.size.y, float(hud_height(node)))) + gap
		current = current.get_parent()
	return hud_bottom_inset(node, gap)


static func prepare_screen(
	root: Control,
	title: String,
	subtitle: String = "",
	background_path: String = "",
	background_alpha: float = 0.38
) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = DARK_THEME
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	if not background_path.is_empty():
		var artwork := TextureRect.new()
		artwork.texture = load(background_path)
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(artwork)
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND if background_path.is_empty() else Color(0.02, 0.03, 0.05, background_alpha)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := screen_margins(root, is_compact_screen(root))
	margin.add_theme_constant_override("margin_left", margins.left)
	margin.add_theme_constant_override("margin_right", margins.right)
	margin.add_theme_constant_override("margin_top", margins.top)
	margin.add_theme_constant_override("margin_bottom", margins.bottom)
	root.add_child(margin)
	var content_center := CenterContainer.new()
	content_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content_center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = content_max_width(root)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	content_center.add_child(column)
	var heading := title_label(title, 46)
	column.add_child(heading)
	if not subtitle.is_empty():
		var subheading := body_label(subtitle, 18, COLOR_MUTED)
		column.add_child(subheading)
	var separator := HSeparator.new()
	column.add_child(separator)
	return column


static func title_label(text: String, size: int = 34) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func body_label(text: String, size: int = 21, color: Color = Color("#d8dde8")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func viewport_size(node: Node = null) -> Vector2:
	if node != null and node.is_inside_tree():
		var size := node.get_viewport().get_visible_rect().size
		if size.x > 0.0 and size.y > 0.0:
			return size
	var manager := _display_manager()
	if manager != null:
		return manager.design_size()
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)


static func visible_screen_size(node: Node = null) -> Vector2:
	return viewport_size(node)


static func design_size() -> Vector2:
	var manager := _display_manager()
	if manager != null:
		return manager.design_size()
	return Vector2(1920.0, 1080.0)


static func _display_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/DisplayManager")
	return null


static func ui_scale(node: Node = null) -> float:
	var design := design_size()
	var size := viewport_size(node)
	return clampf(minf(size.x / design.x, size.y / design.y), 0.65, 1.25)


static func is_compact_screen(node: Node = null) -> bool:
	var size := viewport_size(node)
	var design := design_size()
	return size.x < design.x * 0.78 or size.y < design.y * 0.78


const MENU_MAX_WIDTH := 820.0
const MENU_MAX_HEIGHT := 760.0
const CONTENT_MAX_WIDTH := 1240.0


static func overlay_safe_height(node: Node = null, top_gap: int = -1, bottom_gap: int = -1) -> float:
	var size := viewport_size(node)
	var top := float(top_gap) if top_gap >= 0 else (14.0 if is_compact_screen(node) else 20.0)
	var bottom := float(bottom_gap) if bottom_gap >= 0 else float(hud_bottom_inset(node, 8))
	return maxf(260.0, size.y - top - bottom)


static func overlay_screen_margins(node: Node = null, compact: bool = false) -> Dictionary:
	var edge := 10 if compact else 18
	return {
		"left": edge,
		"right": edge,
		"top": edge,
		"bottom": hud_bottom_inset(node, 8)
	}


static func menu_panel_size(node: Node = null) -> Vector2:
	var size := viewport_size(node)
	var safe_height := overlay_safe_height(node)
	return Vector2(
		minf(size.x * 0.52, MENU_MAX_WIDTH),
		minf(safe_height * 0.92, minf(MENU_MAX_HEIGHT, safe_height))
	)


static func overlay_panel_size(node: Node = null, width_ratio: float = 0.76, height_ratio: float = 0.80) -> Vector2:
	var size := viewport_size(node)
	var safe_height := overlay_safe_height(node)
	return Vector2(
		minf(size.x * width_ratio, 1540.0),
		minf(safe_height * height_ratio, minf(880.0, safe_height))
	)


static func content_max_width(node: Node = null) -> float:
	return minf(viewport_size(node).x * 0.88, CONTENT_MAX_WIDTH)


static func menu_button(text: String, callback: Callable, width: float = 280.0, click_kind: AudioManager.UiClickKind = AudioManager.UiClickKind.DEFAULT) -> Button:
	var control := button(text, callback, width, click_kind)
	control.custom_minimum_size.y = 40
	return control


static func screen_margins(node: Node = null, compact: bool = false) -> Dictionary:
	var scale := ui_scale(node)
	if compact:
		return {
			"left": roundi(24.0 * scale),
			"right": roundi(24.0 * scale),
			"top": roundi(20.0 * scale),
			"bottom": roundi(16.0 * scale)
		}
	return {
		"left": roundi(42.0 * scale),
		"right": roundi(42.0 * scale),
		"top": roundi(34.0 * scale),
		"bottom": roundi(28.0 * scale)
	}


static func scroll_wrap(content: Control, horizontal: bool = false) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


static func button(text: String, callback: Callable, minimum_width: float = 260.0, click_kind: AudioManager.UiClickKind = AudioManager.UiClickKind.DEFAULT) -> Button:
	var control := Button.new()
	control.text = text
	control.flat = false
	control.custom_minimum_size = Vector2(minimum_width, 54)
	wire_button_sound(control, click_kind)
	control.pressed.connect(callback)
	return control


static func line_edit(placeholder: String = "", minimum_width: float = 220.0) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size = Vector2(minimum_width, 40)
	return input


static func wire_button_sound(control: BaseButton, click_kind: AudioManager.UiClickKind = AudioManager.UiClickKind.DEFAULT) -> void:
	if control.has_meta(&"ui_click_wired"):
		return
	control.set_meta(&"ui_click_wired", true)
	control.pressed.connect(func() -> void:
		AudioManager.play_button_click(click_kind)
	)


static func wire_toggle_sound(control: BaseButton, click_kind: AudioManager.UiClickKind = AudioManager.UiClickKind.TOGGLE) -> void:
	if control.has_meta(&"ui_toggle_wired"):
		return
	control.set_meta(&"ui_toggle_wired", true)
	control.toggled.connect(func(_enabled: bool) -> void:
		AudioManager.play_button_click(click_kind)
	)


static func section(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(title_label(title, 27))
	return box


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.105, 0.78)
	style.border_color = Color(0.38, 0.43, 0.50, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


static func menu_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.006, 0.010, 0.86)
	style.border_color = Color(0.42, 0.18, 0.12, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 16
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func menu_divider() -> HSeparator:
	var line := HSeparator.new()
	line.modulate = Color(0.72, 0.56, 0.28, 0.55)
	return line


static func ornate_panel_style(darker: bool = false) -> StyleBoxFlat:
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


static func ornate_heading(text: String, size: int = 28) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.78, 0.58, 0.32, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.01, 0.98))
	label.add_theme_constant_override("outline_size", 3)
	return label


static func ornate_section_label(text: String, size: int = 11) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.68, 0.42, 0.28, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.01, 0.01, 0.9))
	label.add_theme_constant_override("outline_size", 1)
	return label


static func ornate_muted_label(text: String, size: int = 13, should_wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.58, 0.54, 0.52, 0.88))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if should_wrap else TextServer.AUTOWRAP_OFF
	return label


static func framed_column(title: String, body: Control, darker: bool = false) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", ornate_panel_style(darker))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	frame.add_child(column)
	column.add_child(ornate_section_label(title))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	return frame


static func ornate_settings_section(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ornate_panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := ornate_section_label(title.to_upper())
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(heading)
	panel.set_meta(&"content_box", box)
	return box


static func apply_ornate_tabs(tabs: TabContainer) -> void:
	var compact := is_compact_screen(tabs)
	tabs.add_theme_font_size_override("font_size", 12 if compact else 14)
	tabs.add_theme_color_override("font_selected_color", Color(0.86, 0.68, 0.36, 1.0))
	tabs.add_theme_color_override("font_unselected_color", Color(0.58, 0.54, 0.52, 0.88))
	tabs.add_theme_color_override("font_hovered_color", Color(0.78, 0.58, 0.32, 1.0))
	tabs.add_theme_stylebox_override("panel", ornate_panel_style(true))
	tabs.add_theme_stylebox_override("tab_selected", _ornate_tab_style(true))
	tabs.add_theme_stylebox_override("tab_unselected", _ornate_tab_style(false))
	tabs.add_theme_stylebox_override("tab_hovered", _ornate_tab_style(false, true))
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("side_margin", 6)


static func _ornate_tab_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.065, 0.048, 0.034, 0.98)
	elif hovered:
		style.bg_color = Color(0.055, 0.042, 0.032, 0.96)
	else:
		style.bg_color = Color(0.035, 0.028, 0.024, 0.90)
	style.border_color = Color(0.58, 0.40, 0.18, 0.88) if selected else Color(0.42, 0.18, 0.12, 0.55)
	style.set_border_width_all(2)
	style.border_width_bottom = 0 if selected else 2
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func apply_ornate_slider(slider: Range) -> void:
	slider.custom_minimum_size.y = 22
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.018, 0.021, 0.026, 0.92)
	track.border_color = Color(0.42, 0.18, 0.12, 0.55)
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.78, 0.58, 0.32, 1.0)
	grabber.border_color = Color(0.42, 0.18, 0.12, 0.85)
	grabber.set_border_width_all(1)
	grabber.set_corner_radius_all(5)
	grabber.content_margin_left = 5
	grabber.content_margin_right = 5
	grabber.content_margin_top = 5
	grabber.content_margin_bottom = 5
	slider.add_theme_stylebox_override("grabber_area", track.duplicate())
	slider.add_theme_stylebox_override("grabber_area_highlight", track.duplicate())
	slider.add_theme_stylebox_override("grabber", grabber)


static func apply_ornate_check(check: CheckButton) -> void:
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 14)
	check.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72, 0.96))
	check.add_theme_color_override("font_hover_color", Color(0.86, 0.68, 0.36, 1.0))
	check.add_theme_color_override("font_pressed_color", Color(0.78, 0.58, 0.32, 1.0))
	check.add_theme_color_override("icon_normal_color", Color(0.58, 0.40, 0.18, 0.88))
	check.add_theme_color_override("icon_pressed_color", Color(0.86, 0.68, 0.36, 1.0))
	check.add_theme_color_override("icon_hover_color", Color(0.78, 0.58, 0.32, 1.0))


static func apply_ornate_option(option: OptionButton) -> void:
	option.focus_mode = Control.FOCUS_NONE
	option.add_theme_font_size_override("font_size", 14)
	option.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82, 1.0))
	option.add_theme_color_override("font_hover_color", Color(0.86, 0.68, 0.36, 1.0))
	option.add_theme_color_override("font_pressed_color", Color(0.78, 0.58, 0.32, 1.0))
	OrnateUiStyles.apply_button_theme(option)


static func ornate_action_button(
	text: String,
	callback: Callable,
	minimum_width: float = 170.0,
	click_kind: AudioManager.UiClickKind = AudioManager.UiClickKind.DEFAULT
) -> Button:
	var button := button(text, callback, minimum_width, click_kind)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#e8ecf2"))
	button.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	button.add_theme_color_override("font_pressed_color", Color("#e0a070"))
	button.add_theme_color_override("font_disabled_color", Color("#5a616b"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	OrnateUiStyles.apply_button_theme(button)
	return button


static func ornate_field_label(text: String, width: float = 130.0) -> Label:
	var label := ornate_muted_label(text, 15)
	label.custom_minimum_size.x = width
	return label


static func scroll_wrap_fill(body: Control, horizontal: bool = false) -> ScrollContainer:
	var scroll := scroll_wrap(body, horizontal)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	return scroll


static func rarity_color(data: Dictionary) -> Color:
	match str(data.get("rarity", "normal")).to_lower():
		"selten", "rare":
			return RARITY_RARE
		"episch", "epic":
			return RARITY_EPIC
		"legendaer", "legendär", "legendary":
			return RARITY_LEGENDARY
		_:
			return RARITY_NORMAL


static func rarity_label(data: Dictionary) -> String:
	match str(data.get("rarity", "normal")).to_lower():
		"selten", "rare":
			return "Selten"
		"episch", "epic":
			return "Episch"
		"legendaer", "legendär", "legendary":
			return "Legendaer"
		_:
			return "Normal"


static func rarity_legend() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(body_label("R:", 11, COLOR_MUTED))
	for entry in [
		{"label": "N", "tooltip": "Normal", "color": RARITY_NORMAL},
		{"label": "S", "tooltip": "Selten", "color": RARITY_RARE},
		{"label": "E", "tooltip": "Episch", "color": RARITY_EPIC},
		{"label": "L", "tooltip": "Legendaer", "color": RARITY_LEGENDARY}
	]:
		row.add_child(_rarity_chip(str(entry["label"]), entry["color"], str(entry["tooltip"])))
	return row


static func _rarity_chip(text: String, color: Color, tooltip: String = "") -> PanelContainer:
	var chip := PanelContainer.new()
	chip.tooltip_text = tooltip
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.72)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	var label := body_label(text, 10, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(label)
	return chip


static func condition_color(ratio: float) -> Color:
	if ratio >= 0.66:
		return Color("#79d36b")
	if ratio >= 0.33:
		return Color("#d8b36a")
	return Color("#d9685f")


static func rarity_style(data: Dictionary, selected: bool = false, base_bg: Color = Color(0.025, 0.028, 0.034, 0.92), corner_radius: int = 4) -> StyleBoxFlat:
	var color := rarity_color(data)
	var legendary := _is_legendary(data)
	var style := StyleBoxFlat.new()
	style.bg_color = base_bg
	style.border_color = color
	style.set_border_width_all(3 if selected or legendary else 2)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = color
	style.shadow_size = 12 if selected and legendary else (7 if selected else (8 if legendary else 3))
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func apply_item_rarity_frame(panel: PanelContainer, item_id: String, selected: bool = false, base_bg: Color = Color(0.025, 0.028, 0.034, 0.92), corner_radius: int = 4) -> void:
	var data := DataCatalog.item(item_id)
	var style := rarity_style(data, selected, base_bg, corner_radius)
	panel.add_theme_stylebox_override("panel", style)
	if _is_legendary(data):
		_animate_legendary_frame(panel, style)


static func attach_item_tooltip(control: Control, item_id: String, amount: int = 1, price: int = -1, context: String = "") -> void:
	if control == null or item_id.is_empty():
		return
	control.tooltip_text = ""
	control.mouse_entered.connect(func() -> void:
		var tooltip := control.get_tree().root.get_node_or_null("ItemTooltip")
		if tooltip:
			tooltip.call("show_item_delayed", control, item_id, amount, price, context)
	)
	control.mouse_exited.connect(func() -> void:
		var tooltip := control.get_tree().root.get_node_or_null("ItemTooltip")
		if tooltip:
			tooltip.call("hide_tooltip")
	)
	control.tree_exiting.connect(func() -> void:
		var tooltip := control.get_tree().root.get_node_or_null("ItemTooltip")
		if tooltip:
			tooltip.call("hide_tooltip")
	)


static func _is_legendary(data: Dictionary) -> bool:
	var rarity := str(data.get("rarity", "normal")).to_lower()
	return rarity in ["legendaer", "legendär", "legendary"]


static func _animate_legendary_frame(panel: PanelContainer, style: StyleBoxFlat) -> void:
	if not is_instance_valid(panel):
		return
	var tween := panel.create_tween()
	tween.set_loops()
	tween.tween_property(style, "border_color", Color("#ffe7a1"), 0.65)
	tween.parallel().tween_property(style, "shadow_size", 14, 0.65)
	tween.tween_property(style, "border_color", RARITY_LEGENDARY, 0.65)
	tween.parallel().tween_property(style, "shadow_size", 7, 0.65)


static func horizontal_actions() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	return row


static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in cost:
		var item := DataCatalog.item(str(item_id))
		parts.append("%s ×%d" % [item.get("name", item_id), int(cost[item_id])])
	return ", ".join(parts)


static func clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
