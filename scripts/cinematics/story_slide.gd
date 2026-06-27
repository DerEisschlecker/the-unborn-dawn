# Purpose: Reusable static illustrated story sequence for prologue, act transitions, game over, and the ending.
# Public API: Continue through the data-driven slide list (Space / Enter / button).
# Dependencies: DataCatalog, GameState, OrnateUiStyles.
extends Control

const DEFAULT_BACKGROUND := "res://assets/environments/backgrounds/menu_ruins.png"

var story_id: String
var story: Dictionary
var slides: Array
var slide_index := 0
var background: TextureRect
var heading: Label
var body: Label
var continue_hint: Label
var continue_button: Button


func _ready() -> void:
	AudioManager.play_scene_music("story")
	theme = UiFactory.DARK_THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_id = GameState.pending_story if not GameState.pending_story.is_empty() else "prologue"
	story = DataCatalog.story(story_id)
	slides = story.get("slides", [])
	_build_scene()
	_show_slide()


func _build_scene() -> void:
	background = TextureRect.new()
	background.name = "Background"
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var vignette := ColorRect.new()
	vignette.color = Color(0.02, 0.0, 0.0, 0.28)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var overlay := MarginContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var compact := UiFactory.is_compact_screen(self)
	var margins := UiFactory.screen_margins(self, compact)
	overlay.add_theme_constant_override("margin_left", margins.left)
	overlay.add_theme_constant_override("margin_right", margins.right)
	overlay.add_theme_constant_override("margin_top", margins.top)
	overlay.add_theme_constant_override("margin_bottom", margins.bottom)
	add_child(overlay)

	var overlay_box := VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 12)
	overlay.add_child(overlay_box)

	var title := Label.new()
	title.text = str(story.get("title", "LAST LIGHT")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22 if compact else 26)
	title.add_theme_color_override("font_color", Color(0.78, 0.58, 0.32, 0.92))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.01, 0.98))
	title.add_theme_constant_override("outline_size", 3)
	overlay_box.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_box.add_child(spacer)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _narrative_panel_style())
	overlay_box.add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 18)
	panel_margin.add_theme_constant_override("margin_right", 18)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(panel_margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel_margin.add_child(box)

	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24 if compact else 28)
	heading.add_theme_color_override("font_color", Color(0.86, 0.68, 0.36, 1.0))
	heading.add_theme_color_override("font_outline_color", Color(0.10, 0.02, 0.01, 0.95))
	heading.add_theme_constant_override("outline_size", 2)
	box.add_child(heading)

	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 17 if compact else 19)
	body.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72, 0.96))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)

	continue_hint = Label.new()
	continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_hint.add_theme_font_size_override("font_size", 13)
	continue_hint.add_theme_color_override("font_color", Color(0.58, 0.54, 0.52, 0.88))
	footer.add_child(continue_hint)

	continue_button = Button.new()
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.custom_minimum_size = Vector2(160, 40)
	continue_button.add_theme_font_size_override("font_size", 14)
	continue_button.add_theme_color_override("font_color", Color("#e8ecf2"))
	continue_button.add_theme_color_override("font_hover_color", Color("#c48a5a"))
	continue_button.add_theme_color_override("font_pressed_color", Color("#e0a070"))
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFactory.wire_button_sound(continue_button, AudioManager.UiClickKind.CONFIRM)
	OrnateUiStyles.apply_button_theme(continue_button)
	continue_button.pressed.connect(_continue)
	footer.add_child(continue_button)


func _narrative_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.006, 0.010, 0.88)
	style.border_color = Color(0.42, 0.18, 0.12, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _show_slide() -> void:
	if slides.is_empty():
		_finish()
		return
	var slide: Dictionary = slides[slide_index]
	background.texture = _load_texture(str(slide.get("image", DEFAULT_BACKGROUND)))
	heading.text = str(slide.get("heading", ""))
	body.text = str(slide.get("text", ""))
	if story_id == "game_over":
		body.text += "\n\n" + str(GameState.quest_flags.get("game_over_reason", ""))
	if story_id == "finale" and slide_index == slides.size() - 1:
		body.text += "\n\n" + _statistics_text()
	var is_last := slide_index == slides.size() - 1
	continue_button.text = "Abschluss" if is_last else "Weiter"
	continue_hint.text = "Leertaste — %s" % ("Abschluss" if is_last else "Weiter")


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported:
			return imported
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return _load_texture(DEFAULT_BACKGROUND) if path != DEFAULT_BACKGROUND else null


func _continue() -> void:
	slide_index += 1
	if slide_index >= slides.size():
		_finish()
	else:
		_show_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		accept_event()
		_continue()


func _finish() -> void:
	var target := GameState.story_return_scene
	GameState.pending_story = ""
	if story_id == "finale" or story_id == "game_over":
		GameState.game_active = false
		target = "res://scenes/main_menu/main_menu.tscn"
	get_tree().change_scene_to_file(target)


func _statistics_text() -> String:
	var stats := GameState.run_statistics
	return "STATISTIK\nWellen überlebt: %d · Gegner besiegt: %d · Loot: %d\nGebaut: %d · Hergestellt: %d · Reisen: %d" % [
		int(stats.waves_survived),
		int(stats.enemies_defeated),
		int(stats.loot_collected),
		int(stats.structures_built),
		int(stats.items_crafted),
		int(stats.locations_visited)
	]
