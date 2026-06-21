# Purpose: Reusable dialogue panel for survivor, Elena, radio, and lore text.
# Public API: show_line() and dialogue_finished signal.
# Dependencies: UiFactory.
extends Control

signal dialogue_finished

var speaker_label: Label
var text_label: Label


func _ready() -> void:
	theme = UiFactory.DARK_THEME
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -260
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	speaker_label = UiFactory.title_label("", 26)
	text_label = UiFactory.body_label("", 20)
	box.add_child(speaker_label)
	box.add_child(text_label)
	box.add_child(UiFactory.button("Weiter", func() -> void: dialogue_finished.emit(), 200))


func show_line(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	text_label.text = text

