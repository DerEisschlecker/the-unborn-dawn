# Purpose: Visual ability tree overlay with connected unlock nodes for the level screen.
# Public API: refresh_tree(), ability_selected, learn_requested.
# Dependencies: GameState, UiFactory, AbilityDragButton.
class_name AbilityTreeOverlay
extends Control

signal ability_selected(ability_id: String)
signal ability_previewed(ability_id: String)
signal learn_requested(ability_id: String)

const AbilityDragButtonScript := preload("res://scripts/ui/ability_drag_button.gd")

var selected_ability_id := ""
var node_positions: Dictionary = {}
var node_size := Vector2(172, 116)


func refresh_tree(selected_id: String = "") -> void:
	selected_ability_id = selected_id
	UiFactory.clear_container(self)
	node_positions.clear()
	if UiFactory.is_compact_screen():
		_refresh_compact_tree()
		return
	var levels := _tree_levels()
	var rows_by_level := _rows_by_level(levels)
	custom_minimum_size = Vector2(maxf(980.0, float(levels.size()) * 184.0 + 80.0), 500.0)
	for level_index in range(levels.size()):
		var unlock_level := int(levels[level_index])
		var abilities: Array = rows_by_level.get(unlock_level, [])
		_add_level_label(level_index, unlock_level)
		for row_index in range(abilities.size()):
			var data: Dictionary = abilities[row_index]
			_add_ability_node(data, level_index, row_index)
	queue_redraw()


func _refresh_compact_tree() -> void:
	node_size = Vector2(220, 64)
	var columns := 4 if UiFactory.visible_screen_size().x >= 1040.0 else 3
	var pool := GameState.class_abilities()
	var rows := ceili(float(pool.size()) / float(columns))
	custom_minimum_size = Vector2(0, maxf(245.0, 8.0 + float(rows) * 78.0))
	for index in range(pool.size()):
		_add_compact_ability_node(pool[index], index, columns)
	queue_redraw()


func _draw() -> void:
	var pool := GameState.class_abilities()
	for index in range(pool.size() - 1):
		var from_id := str(pool[index].get("id", ""))
		var to_id := str(pool[index + 1].get("id", ""))
		if not node_positions.has(from_id) or not node_positions.has(to_id):
			continue
		var from_pos: Vector2 = node_positions[from_id] + Vector2(node_size.x, node_size.y * 0.5)
		var to_pos: Vector2 = node_positions[to_id] + Vector2(0, node_size.y * 0.5)
		var learned := GameState.learned_abilities.has(from_id) and GameState.learned_abilities.has(to_id)
		var color := Color("#d8b36a", 0.82) if learned else Color("#596272", 0.52)
		draw_line(from_pos, to_pos, color, 3.0, true)
		draw_circle(from_pos, 4.0, color)
		draw_circle(to_pos, 4.0, color)


func _tree_levels() -> Array[int]:
	var levels: Array[int] = [1]
	for unlock_level in GameState.ABILITY_UNLOCK_LEVELS:
		levels.append(int(unlock_level))
	return levels


func _rows_by_level(levels: Array[int]) -> Dictionary:
	var rows := {}
	for level in levels:
		rows[level] = []
	for data in GameState.class_abilities():
		var ability_id := str(data.get("id", ""))
		var unlock_level := GameState.ability_unlock_level(ability_id)
		if not rows.has(unlock_level):
			rows[unlock_level] = []
		rows[unlock_level].append(data)
	return rows


func _add_level_label(level_index: int, unlock_level: int) -> void:
	var label := UiFactory.body_label("LVL %d" % unlock_level, 15, UiFactory.COLOR_GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(30 + level_index * 184, 4)
	label.size = Vector2(node_size.x, 28)
	add_child(label)


func _add_ability_node(data: Dictionary, level_index: int, row_index: int) -> void:
	var ability_id := str(data.get("id", ""))
	var learned := GameState.learned_abilities.has(ability_id)
	var unlocked := GameState.ability_unlocked_for_level(ability_id)
	var selected := selected_ability_id == ability_id
	var panel := PanelContainer.new()
	panel.position = Vector2(30 + level_index * 184, 42 + row_index * 144 + (level_index % 2) * 18)
	panel.size = node_size
	panel.custom_minimum_size = node_size
	panel.tooltip_text = GameState.ability_tooltip_text(ability_id)
	panel.mouse_entered.connect(func() -> void:
		ability_previewed.emit(ability_id)
	)
	var style := UiFactory._panel_style()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.94) if learned else Color(0.035, 0.04, 0.052, 0.86)
	style.border_color = Color(str(data.get("color", "#d8b36a"))) if learned else Color("#596272")
	if selected:
		style.border_color = UiFactory.COLOR_GOLD
		style.shadow_color = UiFactory.COLOR_GOLD
		style.shadow_size = 10
	style.set_border_width_all(3 if selected or learned else 1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	node_positions[ability_id] = panel.position
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://assets/ui/icons/energy.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(34, 34)
	icon.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.42)
	top.add_child(icon)
	var title := UiFactory.body_label(str(data.get("name", ability_id)), 13, Color("#f1dfb4") if unlocked else UiFactory.COLOR_MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var info := UiFactory.body_label("AP %d  CD %d  AUS %.0f" % [
		GameState.ability_action_points(ability_id),
		GameState.ability_cooldown(ability_id),
		float(data.get("stamina_cost", 0.0))
	], 11, UiFactory.COLOR_MUTED)
	box.add_child(info)
	var status_text := "GELERNT" if learned else ("BEREIT" if unlocked and GameState.pending_ability_picks > 0 else "LEVEL %d" % GameState.ability_unlock_level(ability_id))
	var status_color := UiFactory.COLOR_GOLD if learned else (Color("#7ccf6b") if unlocked and GameState.pending_ability_picks > 0 else UiFactory.COLOR_MUTED)
	var status := UiFactory.body_label(status_text, 11, status_color)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(status)
	var action: Button
	if learned:
		action = AbilityDragButtonScript.new()
		action.text = "Auswaehlen / Ziehen"
		action.custom_minimum_size = Vector2(140, 30)
		action.pressed.connect(func() -> void:
			AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -7.0)
			ability_selected.emit(ability_id)
		)
		action.configure_drag(ability_id, -1, true, str(data.get("name", ability_id)))
	else:
		action = UiFactory.button("Lernen" if unlocked else "Gesperrt", func() -> void: learn_requested.emit(ability_id), 140)
		action.custom_minimum_size = Vector2(140, 30)
		action.disabled = not unlocked or GameState.pending_ability_picks <= 0
	box.add_child(action)


func _add_compact_ability_node(data: Dictionary, ability_index: int, columns: int) -> void:
	var ability_id := str(data.get("id", ""))
	var learned := GameState.learned_abilities.has(ability_id)
	var unlocked := GameState.ability_unlocked_for_level(ability_id)
	var selected := selected_ability_id == ability_id
	var column := ability_index % columns
	var row_index := int(floorf(float(ability_index) / float(columns)))
	var step_x := node_size.x + 12.0
	var step_y := node_size.y + 14.0
	var panel := PanelContainer.new()
	panel.position = Vector2(10 + float(column) * step_x, 8 + float(row_index) * step_y)
	panel.size = node_size
	panel.custom_minimum_size = node_size
	panel.tooltip_text = GameState.ability_tooltip_text(ability_id)
	panel.mouse_entered.connect(func() -> void:
		ability_previewed.emit(ability_id)
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.94) if learned else Color(0.035, 0.04, 0.052, 0.86)
	style.border_color = Color(str(data.get("color", "#d8b36a"))) if learned else Color("#596272")
	if selected:
		style.border_color = UiFactory.COLOR_GOLD
		style.shadow_color = UiFactory.COLOR_GOLD
		style.shadow_size = 8
	style.set_border_width_all(2 if selected or learned else 1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	node_positions[ability_id] = panel.position
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(str(data.get("icon", "res://assets/ui/icons/energy.svg")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.42)
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	var title := UiFactory.body_label(str(data.get("name", ability_id)), 10, Color("#f1dfb4") if unlocked else UiFactory.COLOR_MUTED)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.tooltip_text = GameState.ability_tooltip_text(ability_id)
	text_box.add_child(title)
	var info := UiFactory.body_label("Lvl %d | AP %d CD %d AUS %.0f" % [
		GameState.ability_unlock_level(ability_id),
		GameState.ability_action_points(ability_id),
		GameState.ability_cooldown(ability_id),
		float(data.get("stamina_cost", 0.0))
	], 9, UiFactory.COLOR_MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(info)
	var action: Button
	if learned:
		action = AbilityDragButtonScript.new()
		action.text = "OK"
		action.custom_minimum_size = Vector2(46, 26)
		action.pressed.connect(func() -> void:
			AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -7.0)
			ability_selected.emit(ability_id)
		)
		action.configure_drag(ability_id, -1, true, str(data.get("name", ability_id)))
	else:
		action = UiFactory.button("Lern" if unlocked else "Lvl", func() -> void: learn_requested.emit(ability_id), 46)
		action.custom_minimum_size = Vector2(46, 26)
		action.disabled = not unlocked or GameState.pending_ability_picks <= 0
	row.add_child(action)
