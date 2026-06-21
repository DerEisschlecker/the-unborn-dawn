# Purpose: Reusable static illustrated story sequence for prologue, act transitions, game over, and the ending.
# Public API: Continue through the data-driven slide list.
# Dependencies: DataCatalog, GameState.
extends Control

var story_id: String
var story: Dictionary
var slides: Array
var slide_index := 0
var heading: Label
var body: Label
var continue_button: Button
var illustration: TextureRect


func _ready() -> void:
	AudioManager.play_music("res://assets/audio/music/menu/menu_embers.wav", -11.0)
	story_id = GameState.pending_story if not GameState.pending_story.is_empty() else "prologue"
	story = DataCatalog.story(story_id)
	slides = story.get("slides", [])
	var root := UiFactory.prepare_screen(self, str(story.get("title", "LAST LIGHT")), "Statische Story-Sequenz")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1280, 680)
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	illustration = TextureRect.new()
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.custom_minimum_size = Vector2(1180, 360)
	box.add_child(illustration)
	heading = UiFactory.title_label("", 32)
	box.add_child(heading)
	body = UiFactory.body_label("", 23)
	body.custom_minimum_size.y = 110
	box.add_child(body)
	continue_button = UiFactory.button("Weiter", _continue, 300)
	box.add_child(continue_button)
	_show_slide()


func _show_slide() -> void:
	if slides.is_empty():
		_finish()
		return
	var slide: Dictionary = slides[slide_index]
	illustration.texture = load(str(slide.get("image", "res://assets/environments/backgrounds/menu_ruins.png")))
	heading.text = str(slide.get("heading", ""))
	body.text = str(slide.get("text", ""))
	if story_id == "game_over":
		body.text += "\n\n" + str(GameState.quest_flags.get("game_over_reason", ""))
	if story_id == "finale" and slide_index == slides.size() - 1:
		body.text += "\n\n" + _statistics_text()
	continue_button.text = "Abschluss" if slide_index == slides.size() - 1 else "Weiter"


func _continue() -> void:
	slide_index += 1
	if slide_index >= slides.size():
		_finish()
	else:
		_show_slide()


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
