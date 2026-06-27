# Purpose: Hinged destructible door with open/close animation for bunker entrances.
# Public API: setup_door(), open_door(), close_door(), toggle_door().
class_name DestructibleDoor
extends DestructibleModule

@export var open_angle := -92.0

var _hinge: Node3D
var _is_open := false
var _tween: Tween


func setup_door(
	p_module_id: String,
	p_room_id: String,
	visual: MeshInstance3D,
	p_open_angle: float,
	p_defense_weight: float = 2.0
) -> void:
	open_angle = p_open_angle
	module_id = p_module_id
	room_id = p_room_id
	piece_type = "metal_door"
	category = "door"
	defense_weight = p_defense_weight
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	add_child(_hinge)
	_visual = visual
	visual.position = Vector3.ZERO
	_hinge.add_child(visual)
	var spec := DataCatalog.modular_piece(piece_type)
	max_hp = float(spec.get("max_hp", 120.0))
	defense_weight = float(spec.get("defense_weight", p_defense_weight))
	_build_collision(visual)
	_build_rubble(visual)
	sync_from_state()


func open_door(duration: float = 0.55) -> void:
	if is_destroyed or _is_open or _hinge == null:
		return
	_is_open = true
	_animate_door(open_angle, duration)


func close_door(duration: float = 0.45) -> void:
	if is_destroyed or not _is_open or _hinge == null:
		return
	_is_open = false
	_animate_door(0.0, duration)


func toggle_door() -> void:
	if _is_open:
		close_door()
	else:
		open_door()


func _mark_destroyed() -> void:
	_is_open = false
	super._mark_destroyed()


func _animate_door(angle: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hinge, "rotation_degrees:y", angle, duration)
