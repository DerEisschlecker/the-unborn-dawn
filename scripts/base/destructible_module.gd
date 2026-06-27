# Purpose: Single destructible base piece (wall, door, prop) with HP and visual stages.
# Public API: apply_damage(), repair(), sync_from_state(), register with GameState.
# Dependencies: GameState, EventBus, DataCatalog.
class_name DestructibleModule
extends Node3D

signal damaged(amount: float, remaining: float)
signal destroyed(module_id: String)

@export var module_id: String = ""
@export var room_id: String = ""
@export var piece_type: String = "bunker_wall"
@export var category: String = "wall"
@export var defense_weight: float = 1.0

var max_hp: float = 100.0
var current_hp: float = 100.0
var is_destroyed := false

var _visual: MeshInstance3D
var _rubble: MeshInstance3D
var _collision: StaticBody3D


func setup(
	p_module_id: String,
	p_room_id: String,
	p_piece_type: String,
	p_category: String,
	visual: MeshInstance3D,
	p_defense_weight: float = 1.0
) -> void:
	module_id = p_module_id
	room_id = p_room_id
	piece_type = p_piece_type
	category = p_category
	defense_weight = p_defense_weight
	_visual = visual
	add_child(visual)
	var spec := DataCatalog.modular_piece(piece_type)
	max_hp = float(spec.get("max_hp", 100.0))
	defense_weight = float(spec.get("defense_weight", defense_weight))
	_build_collision(visual)
	_build_rubble(visual)
	sync_from_state()


func setup_visual_root(
	p_module_id: String,
	p_room_id: String,
	p_piece_type: String,
	p_category: String,
	visual_root: Node3D,
	p_max_hp: float,
	p_defense_weight: float = 1.0
) -> void:
	module_id = p_module_id
	room_id = p_room_id
	piece_type = p_piece_type
	category = p_category
	defense_weight = p_defense_weight
	max_hp = p_max_hp
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	var bounds := _node_local_bounds(visual_root)
	_build_collision_box(bounds)
	_build_rubble_box(bounds)
	sync_from_state()


func _build_collision(visual: MeshInstance3D) -> void:
	var shape_size := Vector3.ONE
	if visual.mesh is BoxMesh:
		shape_size = (visual.mesh as BoxMesh).size
	elif visual.mesh is CylinderMesh:
		var cyl := visual.mesh as CylinderMesh
		shape_size = Vector3(cyl.top_radius * 2.0, cyl.height, cyl.top_radius * 2.0)
	_build_collision_box({"size": shape_size, "center": visual.position})


func _build_collision_box(bounds: Dictionary) -> void:
	_collision = StaticBody3D.new()
	_collision.name = "Collision"
	add_child(_collision)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.get("size", Vector3.ONE)
	shape.shape = box
	shape.position = bounds.get("center", Vector3.ZERO)
	_collision.add_child(shape)


func _build_rubble(visual: MeshInstance3D) -> void:
	var rubble_size := Vector3(0.8, 0.25, 0.8)
	if visual.mesh is BoxMesh:
		rubble_size = (visual.mesh as BoxMesh).size * Vector3(0.85, 0.35, 0.85)
	_build_rubble_box({"size": rubble_size, "center": visual.position + Vector3(0, -0.12, 0)})


func _build_rubble_box(bounds: Dictionary) -> void:
	_rubble = MeshInstance3D.new()
	_rubble.name = "Rubble"
	var rubble_mesh := BoxMesh.new()
	rubble_mesh.size = bounds.get("size", Vector3(0.8, 0.25, 0.8))
	_rubble.mesh = rubble_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.16, 0.14)
	mat.roughness = 0.95
	_rubble.material_override = mat
	_rubble.position = bounds.get("center", Vector3(0, -0.12, 0))
	_rubble.visible = false
	add_child(_rubble)


func _node_local_bounds(root: Node3D) -> Dictionary:
	var state := {
		"min": Vector3(INF, INF, INF),
		"max": Vector3(-INF, -INF, -INF),
	}
	_collect_bounds(root, root, state)
	var min_v: Vector3 = state["min"]
	var max_v: Vector3 = state["max"]
	if min_v.x == INF:
		return {"size": Vector3.ONE, "center": Vector3.ZERO}
	var size := max_v - min_v
	return {"size": size, "center": min_v + size * 0.5}


func _collect_bounds(root: Node3D, node: Node, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var local_pos := root.to_local(mesh_node.global_position)
		var half := Vector3(0.5, 0.5, 0.5)
		if mesh_node.mesh is BoxMesh:
			half = (mesh_node.mesh as BoxMesh).size * 0.5
		elif mesh_node.mesh is CylinderMesh:
			var cyl := mesh_node.mesh as CylinderMesh
			half = Vector3(cyl.top_radius, cyl.height * 0.5, cyl.top_radius)
		var min_v: Vector3 = state["min"]
		var max_v: Vector3 = state["max"]
		min_v.x = minf(min_v.x, local_pos.x - half.x)
		min_v.y = minf(min_v.y, local_pos.y - half.y)
		min_v.z = minf(min_v.z, local_pos.z - half.z)
		max_v.x = maxf(max_v.x, local_pos.x + half.x)
		max_v.y = maxf(max_v.y, local_pos.y + half.y)
		max_v.z = maxf(max_v.z, local_pos.z + half.z)
		state["min"] = min_v
		state["max"] = max_v
	for child in node.get_children():
		_collect_bounds(root, child, state)


func apply_damage(amount: float) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0
	var applied := GameState.damage_module(module_id, amount, max_hp)
	current_hp = GameState.module_health(module_id, max_hp)
	damaged.emit(applied, current_hp)
	_update_visual_stage()
	if current_hp <= 0.0:
		_mark_destroyed()
	return applied


func repair(amount: float = -1.0) -> void:
	GameState.repair_module(module_id, amount, max_hp)
	current_hp = GameState.module_health(module_id, max_hp)
	is_destroyed = GameState.is_module_destroyed(module_id)
	var visual_root := get_node_or_null("VisualRoot")
	if visual_root:
		visual_root.visible = not is_destroyed
	elif _visual:
		_visual.visible = not is_destroyed
	if _rubble:
		_rubble.visible = is_destroyed
	_update_visual_stage()


func sync_from_state() -> void:
	current_hp = GameState.module_health(module_id, max_hp)
	is_destroyed = GameState.is_module_destroyed(module_id)
	var visual_root := get_node_or_null("VisualRoot")
	if visual_root:
		visual_root.visible = not is_destroyed
	elif _visual:
		_visual.visible = not is_destroyed
	if _rubble:
		_rubble.visible = is_destroyed
	_update_visual_stage()


func _update_visual_stage() -> void:
	if is_destroyed:
		return
	var ratio: float = current_hp / max_hp if max_hp > 0.0 else 0.0
	var visual_root := get_node_or_null("VisualRoot")
	if visual_root:
		_tint_node_materials(visual_root, ratio)
	elif _visual and _visual.material_override is StandardMaterial3D:
		var mat := _visual.material_override as StandardMaterial3D
		mat.albedo_color = mat.albedo_color.lerp(Color(0.12, 0.08, 0.06), 1.0 - ratio)


func _tint_node_materials(node: Node, ratio: float) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).material_override is StandardMaterial3D:
		var mesh_node := node as MeshInstance3D
		var mat := mesh_node.material_override as StandardMaterial3D
		mat.albedo_color = mat.albedo_color.lerp(Color(0.12, 0.08, 0.06), 1.0 - ratio)
	for child in node.get_children():
		_tint_node_materials(child, ratio)


func _mark_destroyed() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	GameState.mark_module_destroyed(module_id)
	var visual_root := get_node_or_null("VisualRoot")
	if visual_root:
		visual_root.visible = false
	elif _visual:
		_visual.visible = false
	if _rubble:
		_rubble.visible = true
	destroyed.emit(module_id)
	EventBus.stats_changed.emit()
