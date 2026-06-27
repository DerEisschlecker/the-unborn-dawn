# Purpose: Elena's dedicated care screen with health, pregnancy stress, portrait phase, and non-combat interactions.
# Public API: Talk, bring food, or provide medicine.
# Dependencies: GameState, InventorySystem, TimeSystem.
extends GameplayScreen

var status_label: Label
var message_label: Label


func _ready() -> void:
	AudioManager.play_scene_music("elena")
	var root := setup_gameplay("ELENA", "Sie ist keine Kämpferin. Ihr Zustand ist die wichtigste Ressource der Zuflucht.")
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var portrait_panel := PanelContainer.new()
	portrait_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(portrait_panel)
	var portrait_box := VBoxContainer.new()
	portrait_panel.add_child(portrait_box)
	var viewport := UiFactory.viewport_size(self)
	var portrait_art := TextureRect.new()
	portrait_art.texture = load("res://assets/environments/backgrounds/elena_story_painted.png")
	portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_art.custom_minimum_size = Vector2(viewport.x * 0.38, viewport.y * 0.42)
	portrait_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_box.add_child(portrait_art)
	var phase := "Späte Schwangerschaft" if TimeSystem.current_day >= 200 else "Schwangerschaft"
	portrait_box.add_child(UiFactory.title_label("ELENA · " + phase, 25))
	var actions := UiFactory.section("Fürsorge")
	actions.get_parent().custom_minimum_size.x = viewport.x * 0.28
	split.add_child(actions.get_parent())
	status_label = UiFactory.body_label("", 22)
	actions.add_child(status_label)
	message_label = UiFactory.body_label("Elena sieht zur verriegelten Tür.", 18, UiFactory.COLOR_MUTED)
	actions.add_child(message_label)
	actions.add_child(UiFactory.button("Mit Elena sprechen", func() -> void: _care("talk"), 450))
	actions.add_child(UiFactory.button("Nahrung bringen", func() -> void: _care("food"), 450))
	actions.add_child(UiFactory.button("Bandage / Medizin geben", func() -> void: _care("medicine"), 450))
	actions.add_child(UiFactory.button("Zurück zur Basis", func() -> void: go_to("res://scenes/base/base_scene.tscn"), 450))
	_refresh()


func _care(kind: String) -> void:
	message_label.text = GameState.care_for_elena(kind)
	if kind != "medicine" or message_label.text != "Du hast keine Bandage.":
		GameState.spend_for_action(2.0, 1.0, 0.0, 1.0)
	_refresh()


func _refresh() -> void:
	status_label.text = "Leben: %.0f / %.0f\nSchwangerschaftsstress: %.0f / 100\nTag der Schwangerschaft: %d / 260" % [
		float(GameState.elena.health),
		float(GameState.elena.max_health),
		float(GameState.elena.stress),
		TimeSystem.current_day
	]
	EventBus.stats_changed.emit()
