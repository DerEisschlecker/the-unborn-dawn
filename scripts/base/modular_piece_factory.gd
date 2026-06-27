# Purpose: Factory for reusable 3D base kit pieces (walls, doors, props, lights).
# Public API: material(), mesh_box(), mesh_cylinder(), create_module(), create_light().
# Dependencies: DestructibleModule, DataCatalog.
class_name ModularPieceFactory
extends RefCounted

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.88) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


static func mesh_box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	return node


static func mesh_cylinder(radius: float, height: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = mat
	return node


const DestructibleModuleScript := preload("res://scripts/base/destructible_module.gd")
const DestructibleDoorScript := preload("res://scripts/base/destructible_door.gd")
const StructureVisualFactoryScript := preload("res://scripts/base/structure_visual_factory.gd")

static func create_module(
	parent: Node3D,
	module_id: String,
	room_id: String,
	piece_type: String,
	category: String,
	visual: MeshInstance3D,
	defense_weight: float = 1.0
) -> Node:
	var module: Node = DestructibleModuleScript.new()
	module.name = module_id
	module.position = visual.position
	visual.position = Vector3.ZERO
	module.setup(module_id, room_id, piece_type, category, visual, defense_weight)
	parent.add_child(module)
	return module


static func create_door(
	parent: Node3D,
	module_id: String,
	room_id: String,
	visual: MeshInstance3D,
	open_angle: float,
	defense_weight: float = 2.0
) -> Node:
	var door: Node = DestructibleDoorScript.new()
	door.name = module_id
	door.position = visual.position
	parent.add_child(door)
	door.setup_door(module_id, room_id, visual, open_angle, defense_weight)
	return door


static func create_structure_module(
	parent: Node3D,
	module_id: String,
	room_id: String,
	structure_id: String,
	position: Vector3
) -> Node:
	var structure: Dictionary = DataCatalog.structure(structure_id)
	var category: String = str(structure.get("category", "prop")).to_lower()
	if category == "mauer":
		category = "wall"
	elif category == "falle":
		category = "prop"
	elif category == "turm":
		category = "structure"
	var visual_root: Node3D = StructureVisualFactoryScript.build_structure(structure_id)
	var module: Node = DestructibleModuleScript.new()
	module.name = module_id
	module.position = position
	parent.add_child(module)
	module.setup_visual_root(
		module_id,
		room_id,
		structure_id,
		category,
		visual_root,
		maxf(40.0, float(structure.get("defense", 1)) * 15.0),
		float(structure.get("defense", 1))
	)
	return module


static func add_spot_light(
	parent: Node3D,
	position: Vector3,
	rotation_deg: Vector3,
	energy: float,
	color: Color,
	spot_angle: float = 28.0
) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = position
	light.rotation_degrees = rotation_deg
	light.light_energy = energy
	light.light_color = color
	light.spot_range = 18.0
	light.spot_angle = spot_angle
	light.shadow_enabled = true
	parent.add_child(light)
	return light


static func add_omni_light(parent: Node3D, position: Vector3, energy: float, color: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = position
	light.light_energy = energy
	light.light_color = color
	light.omni_range = 9.0
	light.shadow_enabled = true
	parent.add_child(light)
	return light
