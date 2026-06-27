# Purpose: Procedural 3D fortress matching the Morgenrot bunker concept (surface + cutaway bunker).
# Public API: build(), get_modules(), refresh_from_state(), apply_wave_damage().
# Dependencies: ModularPieceFactory, DestructibleModule, BaseRoomZone, GameState.
class_name BaseFortress3D
extends Node3D

const ModularPieceFactoryScript := preload("res://scripts/base/modular_piece_factory.gd")
const DestructibleModuleScript := preload("res://scripts/base/destructible_module.gd")
const DestructibleDoorScript := preload("res://scripts/base/destructible_door.gd")
const BaseRoomZoneScript := preload("res://scripts/base/base_room_zone.gd")
const StructureVisualFactoryScript := preload("res://scripts/base/structure_visual_factory.gd")

signal module_destroyed(module_id: String)

var modules: Dictionary = {}
var room_zones: Dictionary = {}
var surface_root: Node3D
var bunker_root: Node3D
var props_root: Node3D
var placements_root: Node3D
var _placement_ids: Array[String] = []


func _ready() -> void:
	if not EventBus.stats_changed.is_connected(refresh_from_state):
		EventBus.stats_changed.connect(refresh_from_state)
	call_deferred("build")


func build() -> void:
	_clear_children()
	modules.clear()
	room_zones.clear()
	surface_root = Node3D.new()
	surface_root.name = "Surface"
	add_child(surface_root)
	bunker_root = Node3D.new()
	bunker_root.name = "Bunker"
	add_child(bunker_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	placements_root = Node3D.new()
	placements_root.name = "Placements"
	surface_root.add_child(placements_root)
	_build_environment()
	_build_surface()
	_build_bunker()
	_build_room_zones()
	refresh_from_state()
	_refresh_surface_placements()


func refresh_from_state() -> void:
	for module_id in modules:
		var module: Node = modules[module_id]
		module.call("sync_from_state")
	_refresh_surface_placements()
	_update_gate_doors()
	_update_room_visibility()


func apply_wave_damage(amount: float) -> void:
	var surface_modules: Array = []
	for module_id in modules:
		var module: Node = modules[module_id]
		if str(module.get("room_id")).begins_with("surface"):
			surface_modules.append(module)
	if surface_modules.is_empty():
		return
	var total_weight: float = 0.0
	for module in surface_modules:
		if not bool(module.get("is_destroyed")):
			total_weight += float(module.get("defense_weight"))
	if total_weight <= 0.0:
		return
	for module in surface_modules:
		if bool(module.get("is_destroyed")):
			continue
		var share: float = amount * (float(module.get("defense_weight")) / total_weight)
		module.call("apply_damage", share)


func get_modules() -> Dictionary:
	return modules


func pick_room_at(world_pos: Vector3) -> String:
	var best_id: String = ""
	var best_dist: float = INF
	for room_id in room_zones:
		var zone: Node = room_zones[room_id]
		var local: Vector3 = zone.to_local(world_pos)
		var shape_node: CollisionShape3D = zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node and shape_node.shape is BoxShape3D:
			var half: Vector3 = (shape_node.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				var dist: float = global_position.distance_to(zone.global_position)
				if dist < best_dist:
					best_dist = dist
					best_id = room_id
	return best_id


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


func _build_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.05, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18, 0.16, 0.14)
	environment.ambient_light_energy = 0.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.11, 0.10)
	environment.fog_density = 0.018
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 0.55
	sun.light_color = Color(0.75, 0.70, 0.62)
	sun.shadow_enabled = true
	add_child(sun)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-20, 140, 0)
	moon.light_energy = 0.18
	moon.light_color = Color(0.45, 0.50, 0.62)
	add_child(moon)


func _build_surface() -> void:
	var ground_mat: StandardMaterial3D = ModularPieceFactoryScript.material(Color(0.16, 0.14, 0.11), 0.0, 0.98)
	var ground: MeshInstance3D = ModularPieceFactoryScript.mesh_box(Vector3(48, 0.35, 34), ground_mat)
	ground.position = Vector3(0, -0.18, -4)
	surface_root.add_child(ground)
	_build_palisade()
	_build_watchtower("surface_west_tower", Vector3(-14, 0, -11), true)
	_build_watchtower("surface_east_tower", Vector3(14, 0, -11), false)
	_build_gate_mound()
	_build_surface_props()
	_build_city_silhouette()


func _build_palisade() -> void:
	var wood: StandardMaterial3D = ModularPieceFactoryScript.material(Color(0.34, 0.24, 0.14))
	for index in range(22):
		var x: float = -10.5 + index * 1.0
		var post: MeshInstance3D = ModularPieceFactoryScript.mesh_box(Vector3(0.22, 3.6, 0.22), wood)
		post.position = Vector3(x, 1.8, -15.5)
		_register_module(
			"surface_palisade_%02d" % index,
			"surface_gate",
			"wood_palisade",
			"wall",
			post,
			surface_root,
			0.7
		)


func _build_watchtower(room_id: String, origin: Vector3, west: bool) -> void:
	var wood := ModularPieceFactoryScript.material(Color(0.30, 0.22, 0.13))
	var legs := [
		Vector3(-1.1, 2.4, -1.1),
		Vector3(1.1, 2.4, -1.1),
		Vector3(-1.1, 2.4, 1.1),
		Vector3(1.1, 2.4, 1.1),
	]
	for i in range(legs.size()):
		var leg := ModularPieceFactoryScript.mesh_box(Vector3(0.35, 4.8, 0.35), wood)
		leg.position = origin + legs[i]
		_register_module("%s_leg_%d" % [room_id, i], room_id, "watchtower_wood", "structure", leg, surface_root, 1.2)
	var platform := ModularPieceFactoryScript.mesh_box(Vector3(3.2, 0.25, 3.2), wood)
	platform.position = origin + Vector3(0, 4.9, 0)
	_register_module("%s_platform" % room_id, room_id, "watchtower_wood", "structure", platform, surface_root, 1.0)
	var cabin := ModularPieceFactoryScript.mesh_box(Vector3(2.8, 2.2, 2.8), wood)
	cabin.position = origin + Vector3(0, 6.1, 0)
	_register_module("%s_cabin" % room_id, room_id, "watchtower_wood", "structure", cabin, surface_root, 1.4)
	var roof := ModularPieceFactoryScript.mesh_box(Vector3(3.4, 0.2, 3.4), ModularPieceFactoryScript.material(Color(0.18, 0.14, 0.10)))
	roof.position = origin + Vector3(0, 7.3, 0)
	surface_root.add_child(roof)
	var banner := ModularPieceFactoryScript.mesh_box(Vector3(0.08, 1.4, 0.9), ModularPieceFactoryScript.material(Color(0.55, 0.08, 0.06)))
	banner.position = origin + Vector3(0 if west else 0, 6.4, 1.55 if west else -1.55)
	surface_root.add_child(banner)
	ModularPieceFactoryScript.add_spot_light(
		surface_root,
		origin + Vector3(0, 6.8, 0.4),
		Vector3(-35, 0 if west else 180, 0),
		2.4,
		Color(0.95, 0.88, 0.72),
		32.0
	)


func _build_gate_mound() -> void:
	var earth := ModularPieceFactoryScript.material(Color(0.20, 0.17, 0.13))
	var mound := ModularPieceFactoryScript.mesh_box(Vector3(8.5, 3.2, 5.5), earth)
	mound.position = Vector3(0, 1.4, -8.5)
	surface_root.add_child(mound)
	var frame := ModularPieceFactoryScript.material(Color(0.38, 0.39, 0.41), 0.35, 0.7)
	var door_l := ModularPieceFactoryScript.mesh_box(Vector3(1.4, 2.6, 0.18), frame)
	door_l.position = Vector3(-0.85, 1.3, -5.6)
	_register_door("surface_gate_door_l", "surface_gate", door_l, surface_root, -95.0, 2.0)
	var door_r := ModularPieceFactoryScript.mesh_box(Vector3(1.4, 2.6, 0.18), frame)
	door_r.position = Vector3(0.85, 1.3, -5.6)
	_register_door("surface_gate_door_r", "surface_gate", door_r, surface_root, 95.0, 2.0)
	for i in range(6):
		var bag := ModularPieceFactoryScript.mesh_box(Vector3(1.1, 0.55, 0.55), ModularPieceFactoryScript.material(Color(0.36, 0.32, 0.22)))
		var angle := float(i) / 6.0 * TAU
		bag.position = Vector3(cos(angle) * 3.2, 0.35, -7.8 + sin(angle) * 1.2)
		_register_module("surface_gate_sand_%d" % i, "surface_gate", "sandbag_wall", "wall", bag, surface_root, 0.9)
	var antenna := ModularPieceFactoryScript.mesh_cylinder(0.05, 5.5, ModularPieceFactoryScript.material(Color(0.5, 0.52, 0.55), 0.7, 0.4))
	antenna.position = Vector3(1.8, 4.8, -8.2)
	_register_module("surface_gate_antenna", "surface_gate", "antenna", "prop", antenna, surface_root, 0.2)
	var pole := ModularPieceFactoryScript.mesh_cylinder(0.06, 4.0, ModularPieceFactoryScript.material(Color(0.25, 0.22, 0.18)))
	pole.position = Vector3(-2.0, 4.0, -8.0)
	surface_root.add_child(pole)
	var flag := ModularPieceFactoryScript.mesh_box(Vector3(0.05, 0.9, 1.3), ModularPieceFactoryScript.material(Color(0.58, 0.10, 0.08)))
	flag.position = Vector3(-2.0, 5.8, -7.3)
	surface_root.add_child(flag)
	ModularPieceFactoryScript.add_omni_light(surface_root, Vector3(0, 2.8, -5.8), 1.2, Color(0.9, 0.82, 0.65))


func _build_surface_props() -> void:
	var metal := ModularPieceFactoryScript.material(Color(0.28, 0.28, 0.30), 0.6, 0.5)
	var hedgehog_positions := [
		Vector3(-6, 0.25, -3.5),
		Vector3(-2.5, 0.25, -2.2),
		Vector3(5.5, 0.25, -3.0),
		Vector3(8.0, 0.25, -1.5),
	]
	for i in range(hedgehog_positions.size()):
		var hedge := ModularPieceFactoryScript.mesh_box(Vector3(1.3, 0.5, 1.3), metal)
		hedge.position = hedgehog_positions[i]
		hedge.rotation_degrees.y = float(i) * 19.0
		var slot := "surface_yard_left" if hedge.position.x < 0 else "surface_yard_right"
		_register_module("surface_hedgehog_%d" % i, slot, "hedgehog", "prop", hedge, surface_root, 0.5)
	var fire := ModularPieceFactoryScript.mesh_cylinder(0.35, 0.2, ModularPieceFactoryScript.material(Color(0.18, 0.16, 0.14)))
	fire.position = Vector3(-10, 0.2, -2.5)
	surface_root.add_child(fire)
	ModularPieceFactoryScript.add_omni_light(surface_root, Vector3(-10, 0.8, -2.5), 1.8, Color(1.0, 0.55, 0.22))
	_build_shed(Vector3(12.5, 0, -2.5))
	for i in range(4):
		var crate := ModularPieceFactoryScript.mesh_box(Vector3(0.9, 0.9, 0.9), ModularPieceFactoryScript.material(Color(0.32, 0.24, 0.15)))
		crate.position = Vector3(-8.0 + i * 1.1, 0.45, 0.5)
		_register_module("surface_crate_%d" % i, "surface_yard_center", "crate", "prop", crate, props_root, 0.2)


func _build_shed(origin: Vector3) -> void:
	var wood := ModularPieceFactoryScript.material(Color(0.28, 0.20, 0.12))
	var walls := [
		{"pos": Vector3(0, 1.1, -1.2), "size": Vector3(3.6, 2.2, 0.18)},
		{"pos": Vector3(-1.8, 1.1, 0), "size": Vector3(0.18, 2.2, 2.4)},
		{"pos": Vector3(1.8, 1.1, 0), "size": Vector3(0.18, 2.2, 2.4)},
	]
	for i in range(walls.size()):
		var data: Dictionary = walls[i]
		var wall := ModularPieceFactoryScript.mesh_box(data.size, wood)
		wall.position = origin + data.pos
		_register_module("surface_shed_wall_%d" % i, "surface_yard_right", "shed_wall", "wall", wall, surface_root, 0.4)
	var roof := ModularPieceFactoryScript.mesh_box(Vector3(3.8, 0.15, 2.6), wood)
	roof.position = origin + Vector3(0, 2.3, 0)
	surface_root.add_child(roof)


func _build_city_silhouette() -> void:
	var city := Node3D.new()
	city.position = Vector3(0, 0, -24)
	surface_root.add_child(city)
	var mat := ModularPieceFactoryScript.material(Color(0.05, 0.05, 0.06))
	for i in range(18):
		var h := 4.0 + float(i % 5) * 2.2 + float(i % 3) * 1.4
		var building := ModularPieceFactoryScript.mesh_box(Vector3(1.2 + float(i % 4) * 0.5, h, 1.2 + float(i % 3) * 0.4), mat)
		building.position = Vector3(-16.0 + i * 1.9, h * 0.5, float(i % 4) - 1.5)
		city.add_child(building)


func _build_bunker() -> void:
	var concrete := ModularPieceFactoryScript.material(Color(0.28, 0.27, 0.26))
	var floor_y := -0.6
	_add_bunker_floor(Vector3(0, floor_y, -2), Vector3(22, 0.35, 14), "command_post")
	_add_bunker_floor(Vector3(-7.5, floor_y - 5.0, -2), Vector3(7, 0.35, 6), "workshop")
	_add_bunker_floor(Vector3(-7.5, floor_y - 10.0, -2), Vector3(7, 0.35, 6), "storage_room")
	_add_bunker_floor(Vector3(7.5, floor_y - 5.0, -2), Vector3(7, 0.35, 6), "guard_post")
	_add_bunker_floor(Vector3(7.5, floor_y - 10.0, -2), Vector3(7, 0.35, 6), "elena_quarters")
	_build_shaft(Vector3(0, floor_y, -2))
	_build_room_shell("command_post", Vector3(0, floor_y + 2.5, -2), Vector3(10, 5, 8), concrete, true)
	_build_room_shell("workshop", Vector3(-7.5, floor_y - 2.5, -2), Vector3(6.5, 4.5, 5.5), concrete, true)
	_build_room_shell("storage_room", Vector3(-7.5, floor_y - 7.5, -2), Vector3(6.5, 4.5, 5.5), concrete, true)
	_build_room_shell("guard_post", Vector3(7.5, floor_y - 2.5, -2), Vector3(6.5, 4.5, 5.5), concrete, true)
	_build_room_shell("infirmary", Vector3(7.5, floor_y - 2.5, -6.5), Vector3(6.5, 4.5, 4.0), concrete, false)
	_build_ritual_room(Vector3(7.5, floor_y - 7.5, -2))
	_build_bunker_props(floor_y)
	ModularPieceFactoryScript.add_omni_light(bunker_root, Vector3(0, floor_y + 3.0, 0), 1.1, Color(0.95, 0.82, 0.62))
	ModularPieceFactoryScript.add_omni_light(bunker_root, Vector3(-7.5, floor_y - 2.0, 0), 0.9, Color(0.9, 0.78, 0.58))
	ModularPieceFactoryScript.add_omni_light(bunker_root, Vector3(7.5, floor_y - 7.0, 0), 0.7, Color(0.85, 0.25, 0.18))


func _add_bunker_floor(center: Vector3, size: Vector3, room_id: String) -> void:
	var floor := ModularPieceFactoryScript.mesh_box(size, ModularPieceFactoryScript.material(Color(0.22, 0.21, 0.20)))
	floor.position = center
	_register_module("%s_floor" % room_id, room_id, "bunker_floor", "structure", floor, bunker_root, 0.3)


func _build_shaft(center: Vector3) -> void:
	var concrete := ModularPieceFactoryScript.material(Color(0.30, 0.29, 0.28))
	var shaft := ModularPieceFactoryScript.mesh_box(Vector3(2.4, 10.0, 2.4), concrete)
	shaft.position = center + Vector3(0, -4.5, 0)
	_register_module("shaft_shell", "shaft_room", "bunker_wall", "wall", shaft, bunker_root, 1.5)
	for i in range(8):
		var rung := ModularPieceFactoryScript.mesh_box(Vector3(0.12, 0.08, 0.8), ModularPieceFactoryScript.material(Color(0.45, 0.46, 0.48), 0.5, 0.4))
		rung.position = center + Vector3(0.9, 1.0 - i * 1.2, 0)
		bunker_root.add_child(rung)


func _build_room_shell(room_id: String, center: Vector3, size: Vector3, mat: StandardMaterial3D, furnished: bool) -> void:
	var half := size * 0.5
	var wall_specs := [
		{"pos": center + Vector3(0, 0, half.z), "size": Vector3(size.x, size.y, 0.28)},
		{"pos": center + Vector3(-half.x, 0, 0), "size": Vector3(0.28, size.y, size.z)},
		{"pos": center + Vector3(half.x, 0, 0), "size": Vector3(0.28, size.y, size.z)},
		{"pos": center + Vector3(0, half.y, 0), "size": Vector3(size.x, 0.24, size.z)},
	]
	for i in range(wall_specs.size()):
		var spec: Dictionary = wall_specs[i]
		var wall := ModularPieceFactoryScript.mesh_box(spec.size, mat)
		wall.position = spec.pos
		_register_module("%s_wall_%d" % [room_id, i], room_id, "bunker_wall", "wall", wall, bunker_root, 1.1)
	if furnished:
		_furnish_room(room_id, center, size)


func _furnish_room(room_id: String, center: Vector3, size: Vector3) -> void:
	var wood := ModularPieceFactoryScript.material(Color(0.32, 0.24, 0.15))
	match room_id:
		"command_post":
			var table := ModularPieceFactoryScript.mesh_box(Vector3(3.6, 0.18, 1.6), wood)
			table.position = center + Vector3(0, -0.8, 0)
			bunker_root.add_child(table)
			for i in range(3):
				var map := ModularPieceFactoryScript.mesh_box(Vector3(0.8, 0.02, 0.6), ModularPieceFactoryScript.material(Color(0.55, 0.48, 0.32)))
				map.position = center + Vector3(-0.8 + i * 0.9, -0.68, 0.2)
				bunker_root.add_child(map)
		"workshop":
			var bench := ModularPieceFactoryScript.mesh_box(Vector3(2.8, 0.9, 1.0), wood)
			bench.position = center + Vector3(0, -1.2, 0.8)
			bunker_root.add_child(bench)
		"storage_room":
			for i in range(4):
				var barrel := ModularPieceFactoryScript.mesh_cylinder(0.45, 1.1, ModularPieceFactoryScript.material(Color(0.28, 0.22, 0.16)))
				barrel.position = center + Vector3(-1.5 + (i % 2) * 1.5, -1.5, -1.0 + int(i / 2) * 1.4)
				_register_module("storage_barrel_%d" % i, room_id, "crate", "prop", barrel, props_root, 0.2)
		"guard_post":
			for i in range(2):
				var bunk := ModularPieceFactoryScript.mesh_box(Vector3(1.8, 0.45, 0.9), wood)
				bunk.position = center + Vector3(-1.0 + i * 2.0, -1.4, 0.5)
				bunker_root.add_child(bunk)


func _build_ritual_room(center: Vector3) -> void:
	_build_room_shell("elena_quarters", center, Vector3(6.5, 4.5, 5.5), ModularPieceFactoryScript.material(Color(0.20, 0.19, 0.18)), false)
	var circle := ModularPieceFactoryScript.mesh_cylinder(2.0, 0.06, ModularPieceFactoryScript.material(Color(0.55, 0.08, 0.06), 0.2, 0.4))
	circle.position = center + Vector3(0, -1.75, 0)
	_register_module("ritual_circle", "elena_quarters", "ritual_floor", "structure", circle, bunker_root, 0.3)
	for i in range(6):
		var candle := ModularPieceFactoryScript.mesh_cylinder(0.05, 0.35, ModularPieceFactoryScript.material(Color(0.9, 0.85, 0.65)))
		var angle := float(i) / 6.0 * TAU
		candle.position = center + Vector3(cos(angle) * 1.5, -1.55, sin(angle) * 1.5)
		bunker_root.add_child(candle)


func _build_bunker_props(floor_y: float) -> void:
	var infirmary_center := Vector3(7.5, floor_y - 2.5, -6.5)
	var bed := ModularPieceFactoryScript.mesh_box(Vector3(1.8, 0.35, 0.9), ModularPieceFactoryScript.material(Color(0.42, 0.40, 0.38)))
	bed.position = infirmary_center + Vector3(0, -1.3, 0)
	bunker_root.add_child(bed)


func _build_room_zones() -> void:
	_add_room_zone("shaft_room", "bunker", Vector3(0, -3.0, -2), Vector3(2.8, 10, 2.8))
	_add_room_zone("command_post", "bunker", Vector3(0, -1.0, -2), Vector3(10, 5, 8))
	_add_room_zone("workshop", "bunker", Vector3(-7.5, -3.5, -2), Vector3(7, 4.5, 5.5))
	_add_room_zone("storage_room", "bunker", Vector3(-7.5, -8.5, -2), Vector3(7, 4.5, 5.5))
	_add_room_zone("guard_post", "bunker", Vector3(7.5, -3.5, -2), Vector3(7, 4.5, 5.5))
	_add_room_zone("infirmary", "bunker", Vector3(7.5, -3.5, -6.5), Vector3(7, 4.5, 4))
	_add_room_zone("elena_quarters", "bunker", Vector3(7.5, -8.5, -2), Vector3(7, 4.5, 5.5))
	_add_room_zone("surface_west_tower", "surface", Vector3(-14, 3.5, -11), Vector3(4, 8, 4))
	_add_room_zone("surface_east_tower", "surface", Vector3(14, 3.5, -11), Vector3(4, 8, 4))
	_add_room_zone("surface_gate", "surface", Vector3(0, 1.5, -8), Vector3(10, 5, 6))
	_add_room_zone("surface_yard_left", "surface", Vector3(-8, 0.5, -3), Vector3(8, 3, 6))
	_add_room_zone("surface_yard_center", "surface", Vector3(0, 0.5, -2), Vector3(8, 3, 5))
	_add_room_zone("surface_yard_right", "surface", Vector3(10, 0.5, -3), Vector3(8, 3, 6))


func _add_room_zone(room_id: String, zone_type: String, center: Vector3, size: Vector3) -> void:
	var zone := BaseRoomZoneScript.new()
	zone.name = "Zone_%s" % room_id
	zone.room_id = room_id
	zone.zone_type = zone_type
	zone.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	add_child(zone)
	room_zones[room_id] = zone


func _register_module(
	module_id: String,
	room_id: String,
	piece_type: String,
	category: String,
	visual: MeshInstance3D,
	parent: Node3D,
	defense_weight: float
) -> Node:
	var module: Node = ModularPieceFactoryScript.create_module(parent, module_id, room_id, piece_type, category, visual, defense_weight)
	if not module.destroyed.is_connected(_on_module_destroyed):
		module.destroyed.connect(_on_module_destroyed)
	modules[module_id] = module
	return module


func _register_door(
	module_id: String,
	room_id: String,
	visual: MeshInstance3D,
	parent: Node3D,
	open_angle: float,
	defense_weight: float
) -> Node:
	var door: Node = ModularPieceFactoryScript.create_door(parent, module_id, room_id, visual, open_angle, defense_weight)
	if not door.destroyed.is_connected(_on_module_destroyed):
		door.destroyed.connect(_on_module_destroyed)
	modules[module_id] = door
	return door


func _on_module_destroyed(module_id: String) -> void:
	module_destroyed.emit(module_id)


func _update_room_visibility() -> void:
	for room_id in DataCatalog.base_rooms:
		var unlocked: bool = GameState.is_room_unlocked(str(room_id))
		var zone: Node = room_zones.get(str(room_id))
		if zone:
			zone.visible = unlocked or str(room_id) == "shaft_room"
		for module_id in modules:
			var module: Node = modules[module_id]
			if str(module.get("room_id")) == str(room_id) and str(module.get("category")) != "wall":
				module.visible = unlocked or str(room_id) == "shaft_room"


func _refresh_surface_placements() -> void:
	if placements_root == null:
		return
	for module_id in _placement_ids:
		modules.erase(module_id)
	_placement_ids.clear()
	for child in placements_root.get_children():
		child.queue_free()
	for slot_id in DataCatalog.surface_slots():
		var structure_id: String = GameState.surface_placement(str(slot_id))
		if structure_id.is_empty():
			continue
		var anchor: Vector3 = StructureVisualFactoryScript.anchor_for_slot(str(slot_id))
		var module_id: String = "placement_%s" % slot_id
		var module: Node = ModularPieceFactoryScript.create_structure_module(
			placements_root,
			module_id,
			str(slot_id),
			structure_id,
			anchor
		)
		if not module.destroyed.is_connected(_on_module_destroyed):
			module.destroyed.connect(_on_module_destroyed)
		modules[module_id] = module
		_placement_ids.append(module_id)


func _update_gate_doors() -> void:
	var gate_open: bool = GameState.is_room_unlocked("surface_gate")
	for door_id in ["surface_gate_door_l", "surface_gate_door_r"]:
		var door: Node = modules.get(door_id)
		if door == null:
			continue
		if gate_open and not bool(door.get("is_destroyed")):
			door.call("open_door", 0.6)
		else:
			door.call("close_door", 0.4)
