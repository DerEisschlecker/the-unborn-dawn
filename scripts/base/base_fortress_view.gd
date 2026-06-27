# Purpose: Bunker cutaway host — concept art (BaseVisual) + 3D placement overlay.
# Public API: room_selected, surface_selected signals (compatible with BaseVisual / BaseScene).
# Dependencies: BaseVisual, BaseStructureOverlay, GameState.
class_name BaseFortressView
extends Control

signal room_selected(room_id: String)
signal surface_selected(slot_id: String)

const BaseVisualScript := preload("res://scripts/base/base_visual.gd")
const BaseStructureOverlayScript := preload("res://scripts/base/base_structure_overlay.gd")

var cutaway: Control
var structure_overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layers()
	if not EventBus.stats_changed.is_connected(_on_stats_changed):
		EventBus.stats_changed.connect(_on_stats_changed)
	call_deferred("_sync_overlay")


func _build_layers() -> void:
	cutaway = BaseVisualScript.new()
	cutaway.name = "Cutaway"
	cutaway.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutaway.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cutaway)
	cutaway.room_selected.connect(func(room_id: String) -> void: room_selected.emit(room_id))
	cutaway.surface_selected.connect(func(slot_id: String) -> void: surface_selected.emit(slot_id))
	structure_overlay = BaseStructureOverlayScript.new()
	structure_overlay.name = "StructureOverlay"
	add_child(structure_overlay)


func _sync_overlay() -> void:
	if is_instance_valid(structure_overlay) and size.x > 1.0:
		structure_overlay.sync_placements(size)


func _on_stats_changed() -> void:
	_sync_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_overlay()
