# Purpose: Transparent 3D overlay for placed surface defenses (GLB or procedural) aligned to cutaway rects.
# Public API: sync_placements(canvas_size).
class_name BaseStructureOverlay
extends Control

const StructureVisualFactoryScript := preload("res://scripts/base/structure_visual_factory.gd")

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_viewport()


func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.size = Vector2i(1920, 1080)
	container.add_child(viewport)
	stage = Node3D.new()
	stage.name = "PlacementStage"
	viewport.add_child(stage)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 24)
	camera.rotation_degrees = Vector3.ZERO
	camera.current = true
	stage.add_child(camera)


func sync_placements(canvas: Vector2) -> void:
	if stage == null or canvas.x <= 1.0:
		return
	for child in stage.get_children():
		if child != camera:
			child.queue_free()
	camera.size = canvas.y * 0.52
	for slot_id in DataCatalog.surface_slots():
		var structure_id: String = GameState.surface_placement(str(slot_id))
		if structure_id.is_empty():
			continue
		var data: Dictionary = DataCatalog.base_room(str(slot_id))
		if data.is_empty():
			continue
		var rect: Rect2 = _room_rect(data, canvas)
		var center: Vector2 = rect.get_center()
		var visual: Node3D = StructureVisualFactoryScript.build_structure(structure_id)
		visual.position = Vector3(center.x - canvas.x * 0.5, canvas.y * 0.5 - center.y, 0)
		var visual_scale: float = clampf(minf(rect.size.x, rect.size.y) / 90.0, 0.55, 1.35)
		visual.scale = Vector3.ONE * visual_scale
		stage.add_child(visual)
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _room_rect(data: Dictionary, canvas: Vector2) -> Rect2:
	var rect: Dictionary = data.get("rect", {})
	return Rect2(
		float(rect.get("x", 0.0)) * canvas.x,
		float(rect.get("y", 0.0)) * canvas.y,
		float(rect.get("w", 0.1)) * canvas.x,
		float(rect.get("h", 0.1)) * canvas.y
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if viewport:
			viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
		sync_placements(size)
