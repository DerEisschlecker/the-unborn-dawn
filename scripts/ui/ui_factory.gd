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
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
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


static func visible_screen_size() -> Vector2:
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		return window_size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)


static func is_compact_screen() -> bool:
	var size := visible_screen_size()
	return size.x < 1500.0 or size.y < 860.0


static func button(text: String, callback: Callable, minimum_width: float = 260.0) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(minimum_width, 52)
	control.pressed.connect(func() -> void:
		AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -7.0)
		callback.call()
	)
	return control


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
