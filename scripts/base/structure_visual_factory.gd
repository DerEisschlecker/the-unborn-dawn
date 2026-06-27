# Purpose: Builds 3D visuals for placed surface structures (procedural or optional scene_path).
# Public API: build_structure(), anchor_for_slot().
class_name StructureVisualFactory
extends RefCounted

const SLOT_ANCHORS := {
	"surface_west_tower": Vector3(-14, 0, -11),
	"surface_east_tower": Vector3(14, 0, -11),
	"surface_gate": Vector3(0, 0.4, -6.8),
	"surface_yard_left": Vector3(-8, 0, -3),
	"surface_yard_center": Vector3(0, 0, -2),
	"surface_yard_right": Vector3(10, 0, -3),
}


static func anchor_for_slot(slot_id: String) -> Vector3:
	return SLOT_ANCHORS.get(slot_id, Vector3.ZERO)


static func build_structure(structure_id: String) -> Node3D:
	var data: Dictionary = DataCatalog.structure(structure_id)
	var scene_path: String = str(data.get("scene_path", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed:
			var instance: Node = packed.instantiate()
			if instance is Node3D:
				return instance as Node3D
	var preset: String = str(data.get("mesh_preset", structure_id))
	return _build_preset(preset, data)


static func _build_preset(preset: String, _data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Structure_%s" % preset
	match preset:
		"wood_wall":
			_add_segments(root, 3, Vector3(1.4, 1.4, 0.35), ModularPieceFactory.material(Color(0.34, 0.24, 0.14)), 1.5)
		"metal_fence":
			for i in range(4):
				var post := ModularPieceFactory.mesh_cylinder(0.08, 1.6, ModularPieceFactory.material(Color(0.42, 0.44, 0.46), 0.55, 0.45))
				post.position = Vector3(-2.1 + i * 1.4, 0.8, 0)
				root.add_child(post)
			var rail := ModularPieceFactory.mesh_box(Vector3(4.5, 0.12, 0.12), ModularPieceFactory.material(Color(0.38, 0.40, 0.42), 0.5, 0.4))
			rail.position = Vector3(0, 1.35, 0)
			root.add_child(rail)
		"watchtower":
			var leg := ModularPieceFactory.mesh_box(Vector3(0.35, 2.5, 0.35), ModularPieceFactory.material(Color(0.30, 0.22, 0.13)))
			leg.position = Vector3(0, 1.25, 0)
			root.add_child(leg)
			var top := ModularPieceFactory.mesh_box(Vector3(1.8, 1.2, 1.8), ModularPieceFactory.material(Color(0.28, 0.20, 0.12)))
			top.position = Vector3(0, 2.8, 0)
			root.add_child(top)
		"spike_trap":
			for i in range(5):
				var spike := ModularPieceFactory.mesh_box(Vector3(0.12, 0.7, 0.12), ModularPieceFactory.material(Color(0.35, 0.35, 0.38), 0.65, 0.35))
				spike.position = Vector3(-1.2 + i * 0.6, 0.35, 0)
				spike.rotation_degrees.z = 18.0
				root.add_child(spike)
		"noise_trap":
			var box := ModularPieceFactory.mesh_box(Vector3(1.2, 0.5, 1.2), ModularPieceFactory.material(Color(0.25, 0.28, 0.32), 0.4, 0.5))
			box.position = Vector3(0, 0.25, 0)
			root.add_child(box)
		"shrapnel_trap":
			var barrel := ModularPieceFactory.mesh_cylinder(0.45, 0.8, ModularPieceFactory.material(Color(0.32, 0.22, 0.14)))
			barrel.position = Vector3(0, 0.4, 0)
			root.add_child(barrel)
			var charge := ModularPieceFactory.mesh_box(Vector3(0.5, 0.35, 0.5), ModularPieceFactory.material(Color(0.48, 0.12, 0.08)))
			charge.position = Vector3(0, 0.95, 0)
			root.add_child(charge)
		_:
			var fallback := ModularPieceFactory.mesh_box(Vector3(1.2, 1.0, 1.2), ModularPieceFactory.material(Color(0.4, 0.38, 0.35)))
			fallback.position = Vector3(0, 0.5, 0)
			root.add_child(fallback)
	return root


static func _add_segments(root: Node3D, count: int, size: Vector3, mat: StandardMaterial3D, spacing: float) -> void:
	for i in range(count):
		var seg := ModularPieceFactory.mesh_box(size, mat)
		seg.position = Vector3((float(i) - (count - 1) * 0.5) * spacing, size.y * 0.5, 0)
		root.add_child(seg)
