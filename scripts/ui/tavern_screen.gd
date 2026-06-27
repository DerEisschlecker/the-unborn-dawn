# Purpose: Recruit a combat companion from available starter classes at the tavern.
# Public API: Opened from the world map tavern location.
# Dependencies: GameplayScreen, GameState, DataCatalog, UiFactory.
extends GameplayScreen

var feedback_label: Label
var roster_box: VBoxContainer


func _ready() -> void:
	AudioManager.play_scene_music("trader")
	var root := setup_gameplay(
		"ROSTIGE TAVERNE",
		"Waehle einen Begleiter. Verfuegbar sind nur Klassen, die du nicht spielst und die noch nicht im Team sind."
	)
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	root.add_child(layout)
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size.x = 320
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	info_panel.add_child(info_box)
	info_box.add_child(UiFactory.title_label("Begleiter", 28))
	if GameState.has_companion():
		info_box.add_child(UiFactory.body_label(
			"Aktuell: %s (%s)" % [str(GameState.companion.get("name", "")), GameState.companion_class_name()],
			18,
			UiFactory.COLOR_GOLD
		))
		info_box.add_child(UiFactory.button("Begleiter entlassen", _dismiss_companion, 300))
	else:
		info_box.add_child(UiFactory.body_label("Noch kein Begleiter im Team.", 18, UiFactory.COLOR_MUTED))
	info_box.add_child(UiFactory.body_label(
		"Begleiter kaempfen im Kampf mit eigener Initiative und den gleichen Klassenfaehigkeiten wie beim Start.",
		17
	))
	feedback_label = UiFactory.body_label("", 17, UiFactory.COLOR_GOLD)
	info_box.add_child(feedback_label)
	info_box.add_child(UiFactory.button("Zurueck zur Karte", _return_to_map, 300))
	var roster_panel := PanelContainer.new()
	roster_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(roster_panel)
	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 10)
	roster_panel.add_child(roster_box)
	_refresh_roster()


func _refresh_roster() -> void:
	UiFactory.clear_container(roster_box)
	roster_box.add_child(UiFactory.title_label("Verfuegbare Klassen", 26))
	var classes := GameState.available_companion_classes()
	if classes.is_empty():
		roster_box.add_child(UiFactory.body_label("Keine weiteren Klassen verfuegbar.", 18, UiFactory.COLOR_MUTED))
		return
	var classes_data: Dictionary = DataCatalog.player_config().get("classes", {})
	for class_id in classes:
		var data: Dictionary = classes_data.get(class_id, {})
		var preset: Dictionary = GameState.COMPANION_PRESETS.get(class_id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		roster_box.add_child(row)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 4)
		row.add_child(text_box)
		text_box.add_child(UiFactory.body_label("%s — %s" % [str(data.get("name", class_id)), str(preset.get("name", "Unbekannt"))], 18, UiFactory.COLOR_GOLD))
		text_box.add_child(UiFactory.body_label(str(data.get("description", "")), 16))
		var recruit_button := UiFactory.button("Anheuern", func() -> void: _recruit(class_id), 180)
		row.add_child(recruit_button)


func _recruit(class_id: String) -> void:
	if GameState.recruit_companion(class_id):
		var name := str(GameState.companion.get("name", ""))
		feedback_label.text = "%s (%s) schliesst sich deinem Team an." % [name, GameState.companion_class_name()]
		_refresh_roster()
	else:
		feedback_label.text = "Diese Klasse kann gerade nicht angeheuert werden."


func _dismiss_companion() -> void:
	GameState.dismiss_companion()
	feedback_label.text = "Der Begleiter hat die Taverne verlassen."
	_refresh_roster()


func _return_to_map() -> void:
	go_to("res://scenes/world_map/world_map.tscn")
