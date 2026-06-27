# Purpose: Delayed custom item tooltip with icon, rarity, value, effects, stats, and condition.
# Public API: show_item_delayed(), hide_tooltip().
# Dependencies: DataCatalog, InventorySystem, UiFactory.
extends CanvasLayer

const SHOW_DELAY := 1.0
const OFFSET := Vector2(24, 18)
const MAX_WIDTH := 360.0

var timer: Timer
var popup: PanelContainer
var icon_frame: PanelContainer
var icon: TextureRect
var title_label: Label
var meta_label: Label
var description_label: Label
var stats_label: RichTextLabel
var pending_control: Control
var pending_item_id := ""
var pending_amount := 1
var pending_price := -1
var pending_context := ""


func _ready() -> void:
	layer = 90
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = SHOW_DELAY
	timer.timeout.connect(_show_pending_tooltip)
	add_child(timer)
	_build_popup()
	hide_tooltip()


func show_item_delayed(control: Control, item_id: String, amount: int = 1, price: int = -1, context: String = "") -> void:
	if item_id.is_empty() or DataCatalog.item(item_id).is_empty():
		hide_tooltip()
		return
	pending_control = control
	pending_item_id = item_id
	pending_amount = maxi(1, amount)
	pending_price = price
	pending_context = context
	popup.visible = false
	timer.start(SHOW_DELAY)


func hide_tooltip() -> void:
	if is_instance_valid(timer):
		timer.stop()
	if is_instance_valid(popup):
		popup.visible = false
	pending_control = null
	pending_item_id = ""


func _build_popup() -> void:
	popup = PanelContainer.new()
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	popup.add_theme_stylebox_override("panel", _tooltip_style())
	add_child(popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	popup.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	icon_frame = PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(76, 76)
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(icon_frame)
	icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(66, 66)
	icon_frame.add_child(icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 3)
	top.add_child(title_box)
	title_label = UiFactory.body_label("", 18, UiFactory.COLOR_GOLD)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title_label)
	meta_label = UiFactory.body_label("", 12, UiFactory.COLOR_MUTED)
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(meta_label)
	var separator := HSeparator.new()
	box.add_child(separator)
	description_label = UiFactory.body_label("", 13, Color("#d8dde8"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description_label)
	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false
	stats_label.custom_minimum_size = Vector2(MAX_WIDTH - 34, 0)
	stats_label.add_theme_font_size_override("normal_font_size", 12)
	stats_label.add_theme_color_override("default_color", Color("#d8dde8"))
	box.add_child(stats_label)


func _show_pending_tooltip() -> void:
	if pending_item_id.is_empty() or not is_instance_valid(pending_control):
		hide_tooltip()
		return
	if not pending_control.get_global_rect().has_point(pending_control.get_global_mouse_position()):
		hide_tooltip()
		return
	_fill_item(pending_item_id, pending_amount, pending_price, pending_context)
	popup.visible = true
	await get_tree().process_frame
	_position_popup()


func _fill_item(item_id: String, amount: int, price: int, context: String) -> void:
	var data := DataCatalog.item(item_id)
	var rarity_color := UiFactory.rarity_color(data)
	icon.texture = load(str(data.get("icon", "res://icon.svg")))
	icon_frame.add_theme_stylebox_override("panel", UiFactory.rarity_style(data, true, Color(0.018, 0.019, 0.023, 0.95), 4))
	title_label.text = "%s x%d" % [data.get("name", item_id), amount]
	title_label.add_theme_color_override("font_color", rarity_color)
	var meta_parts: Array[String] = [
		str(data.get("category", "Gegenstand")),
		UiFactory.rarity_label(data),
		"%.2f kg" % float(data.get("weight", 0.0)),
		"Wert %d C" % DataCatalog.item_value(item_id)
	]
	if price >= 0:
		meta_parts.append("Preis %d C" % price)
	if not context.is_empty():
		meta_parts.append(context)
	meta_label.text = " | ".join(meta_parts)
	description_label.text = str(data.get("description", "Keine Beschreibung."))
	stats_label.text = _stats_text(item_id, data)
	_apply_tooltip_rarity_frame(data)


func _stats_text(item_id: String, data: Dictionary) -> String:
	var lines: Array[String] = []
	var condition := InventorySystem.condition_text(item_id)
	if not condition.is_empty():
		lines.append("[color=#d8b36a]%s[/color]" % condition)
	if data.has("equip_slot"):
		var slot := str(data.get("equip_slot", ""))
		lines.append("[color=#8e9aab]Slot:[/color] %s" % InventorySystem.EQUIPMENT_SLOTS.get(slot, {}).get("name", slot))
	if bool(data.get("two_handed", false)):
		lines.append("[color=#d8a070]Zweihand[/color] — blockiert Schild und zweite Waffe")
	for key in ["damage", "armor", "shield", "strength", "dexterity", "intelligence", "vitality", "willpower", "accuracy", "stamina_bonus", "max_stamina_bonus", "pocket_slots", "carry_weight_bonus"]:
		if data.has(key):
			lines.append("%s: [color=#f0dca9]%s[/color]" % [_stat_name(key), _value_text(float(data.get(key, 0.0)))])
	if data.has("ammo") and not str(data.get("ammo", "")).is_empty():
		var ammo_id := str(data.get("ammo", ""))
		lines.append("Munition: %s x%d" % [DataCatalog.item(ammo_id).get("name", ammo_id), int(data.get("ammo_cost", 1))])
	if data.has("effects"):
		var effect_parts: Array[String] = []
		var effects: Dictionary = data.get("effects", {})
		for stat_name in effects:
			effect_parts.append("%s %+d" % [_stat_name(str(stat_name)), int(effects[stat_name])])
		lines.append("[color=#7ccf6b]Benutzen:[/color] %s" % ", ".join(effect_parts))
	if data.has("capacity_slots"):
		lines.append("Rucksack: [color=#f0dca9]%d Plaetze[/color], %.1f kg" % [int(data.get("capacity_slots", 0)), float(data.get("max_weight", 0.0))])
	return "\n".join(lines)


func _position_popup() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var target_size := popup.size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = popup.custom_minimum_size
	var pos := get_viewport().get_mouse_position() + OFFSET
	if pos.x + target_size.x > viewport_size.x - 12.0:
		pos.x = get_viewport().get_mouse_position().x - target_size.x - OFFSET.x
	if pos.y + target_size.y > viewport_size.y - 12.0:
		pos.y = viewport_size.y - target_size.y - 12.0
	pos.x = clampf(pos.x, 12.0, maxf(12.0, viewport_size.x - target_size.x - 12.0))
	pos.y = clampf(pos.y, 12.0, maxf(12.0, viewport_size.y - target_size.y - 12.0))
	popup.position = pos


func _apply_tooltip_rarity_frame(data: Dictionary) -> void:
	var style := _tooltip_style()
	var color := UiFactory.rarity_color(data)
	style.border_color = color.darkened(0.15)
	style.shadow_color = color
	style.shadow_size = 10 if str(data.get("rarity", "")).to_lower() in ["legendary", "legendaer", "legendär"] else 5
	popup.add_theme_stylebox_override("panel", style)


func _tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.013, 0.016, 0.97)
	style.border_color = Color(0.42, 0.34, 0.22, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 16
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _stat_name(key: String) -> String:
	match key:
		"health":
			return "Leben"
		"hunger":
			return "Hunger"
		"thirst":
			return "Durst"
		"stamina", "stamina_bonus":
			return "Ausdauer"
		"max_stamina_bonus":
			return "Max Ausdauer"
		"energy":
			return "Energie"
		"mana":
			return "Mana"
		"infection":
			return "Infektion"
		"damage":
			return "Schaden"
		"armor":
			return "Ruestung"
		"shield":
			return "Schutz"
		"strength":
			return "STR"
		"dexterity":
			return "DEX"
		"intelligence":
			return "INT"
		"vitality":
			return "VIT"
		"willpower":
			return "WIL"
		"accuracy":
			return "Genauigkeit"
		"pocket_slots":
			return "Taschen"
		"carry_weight_bonus":
			return "Traglast"
	return key.replace("_", " ")


func _value_text(value: float) -> String:
	if absf(value - roundf(value)) < 0.05:
		return "%+d" % int(roundf(value))
	return "%+.1f" % value
