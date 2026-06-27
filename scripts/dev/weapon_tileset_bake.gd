# Purpose: Build the weapon spritesheet + TileSet for editor-driven weapon picking.
# Run from the dev scene export "Bake Now" or: File > Run > run_weapon_tileset_bake.gd
class_name WeaponTilesetBake
extends RefCounted

const ATLAS_PATH := "res://assets/tilesets/weapons_atlas.png"
const TILESET_PATH := "res://resources/tilesets/weapon_tileset.tres"
const SOURCE_SHEET_PATH := "res://assets/tilesets/source/darkest_dungeon_weapons_sheet.png"
const TILE_SIZE := 32
const MANUAL_TILE_SIZE := 16
const GRID_COLUMNS := 8

const WEAPON_ENTRIES: Array[Dictionary] = [
	{"item_id": "rusty_knife", "icon": "res://assets/items/weapons/melee/rusty_knife.png"},
	{"item_id": "dd_throw_knife", "icon": "res://assets/items/weapons/melee/dd_throw_knife.png"},
	{"item_id": "dd_skull_dagger", "icon": "res://assets/items/weapons/melee/dd_skull_dagger.png"},
	{"item_id": "dd_ritual_dagger", "icon": "res://assets/items/weapons/melee/dd_ritual_dagger.png"},
	{"item_id": "machete", "icon": "res://assets/items/weapons/melee/machete.png"},
	{"item_id": "dd_shortsword", "icon": "res://assets/items/weapons/melee/dd_shortsword.png"},
	{"item_id": "dd_hatchet", "icon": "res://assets/items/weapons/melee/dd_hatchet.png"},
	{"item_id": "dd_war_pick", "icon": "res://assets/items/weapons/melee/dd_war_pick.png"},
	{"item_id": "fire_axe", "icon": "res://assets/items/weapons/melee/fire_axe.png"},
	{"item_id": "dd_morning_star", "icon": "res://assets/items/weapons/melee/dd_morning_star.png"},
	{"item_id": "scrap_greatsword", "icon": "res://assets/items/weapons/melee/scrap_greatsword.png"},
	{"item_id": "dd_halberd", "icon": "res://assets/items/weapons/melee/dd_halberd.png"},
	{"item_id": "dd_war_pike", "icon": "res://assets/items/weapons/melee/dd_war_pike.png"},
	{"item_id": "war_axe", "icon": "res://assets/items/weapons/melee/war_axe.png"},
	{"item_id": "crowbar", "icon": "res://assets/items/weapons/melee/crowbar.svg"},
	{"item_id": "service_pistol", "icon": "res://assets/items/weapons/ranged/service_pistol.png"},
	{"item_id": "old_revolver", "icon": "res://assets/items/weapons/ranged/old_revolver.png"},
	{"item_id": "dd_hunter_bow", "icon": "res://assets/items/weapons/ranged/dd_hunter_bow.png"},
	{"item_id": "dd_longbow", "icon": "res://assets/items/weapons/ranged/dd_longbow.png"},
	{"item_id": "heavy_crossbow", "icon": "res://assets/items/weapons/ranged/heavy_crossbow.png"},
	{"item_id": "dd_scrap_carbine", "icon": "res://assets/items/weapons/ranged/dd_scrap_carbine.png"},
	{"item_id": "hunting_rifle", "icon": "res://assets/items/weapons/ranged/hunting_rifle.png"},
	{"item_id": "compact_smg", "icon": "res://assets/items/weapons/ranged/compact_smg.png"},
	{"item_id": "dd_combat_rifle", "icon": "res://assets/items/weapons/ranged/dd_combat_rifle.png"},
	{"item_id": "pump_shotgun", "icon": "res://assets/items/weapons/ranged/pump_shotgun.png"},
	{"item_id": "scoped_sniper", "icon": "res://assets/items/weapons/ranged/scoped_sniper.png"},
	{"item_id": "frag_grenade", "icon": "res://assets/items/weapons/ranged/frag_grenade.png"},
	{"item_id": "dd_stick_grenade", "icon": "res://assets/items/weapons/ranged/dd_stick_grenade.png"},
	{"item_id": "dd_mine_ball", "icon": "res://assets/items/weapons/ranged/dd_mine_ball.png"},
]


static func entry_count() -> int:
	return WEAPON_ENTRIES.size()


static func grid_rows() -> int:
	return int(ceilf(float(WEAPON_ENTRIES.size()) / float(GRID_COLUMNS)))


static func atlas_coords_for_index(index: int) -> Vector2i:
	return Vector2i(index % GRID_COLUMNS, int(index / GRID_COLUMNS))


static func item_data(item_id: String) -> Dictionary:
	return DataCatalog.item(item_id)


static func display_name(item_id: String) -> String:
	return str(item_data(item_id).get("name", item_id))


static func description(item_id: String) -> String:
	return str(item_data(item_id).get("description", ""))


static func save_manual_sheet_tileset(tile_size: int = MANUAL_TILE_SIZE) -> Dictionary:
	_ensure_output_dirs()
	var texture := load(SOURCE_SHEET_PATH) as Texture2D
	if texture == null:
		push_error("WeaponTilesetBake: source sheet missing at %s" % SOURCE_SHEET_PATH)
		return {"ok": false, "tileset_path": TILESET_PATH}
	var tileset := _new_tileset_with_custom_data(tile_size)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(tile_size, tile_size)
	atlas.margins = Vector2i.ZERO
	atlas.separation = Vector2i.ZERO
	atlas.use_texture_padding = true
	tileset.add_source(atlas, 0)
	var error := ResourceSaver.save(tileset, TILESET_PATH)
	if error != OK:
		push_error("WeaponTilesetBake: failed to save manual tileset (%s)" % error)
		return {"ok": false, "tileset_path": TILESET_PATH}
	_scan_filesystem()
	return {
		"ok": true,
		"tileset_path": TILESET_PATH,
		"source_sheet": SOURCE_SHEET_PATH,
		"tile_size": tile_size,
		"mode": "manual",
	}


static func save_all() -> Dictionary:
	_ensure_output_dirs()
	var atlas_result := _save_atlas_png()
	var tileset_result := _save_tileset_resource(atlas_result.texture)
	return {
		"atlas_path": ATLAS_PATH,
		"tileset_path": TILESET_PATH,
		"tile_size": TILE_SIZE,
		"entries": WEAPON_ENTRIES.size(),
		"atlas_size": atlas_result.size,
		"tileset_saved": tileset_result,
	}


static func _save_atlas_png() -> Dictionary:
	var rows := grid_rows()
	var width := GRID_COLUMNS * TILE_SIZE
	var height := rows * TILE_SIZE
	var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	for index in range(WEAPON_ENTRIES.size()):
		var entry: Dictionary = WEAPON_ENTRIES[index]
		var tile_image := _icon_to_tile_image(str(entry.get("icon", "")))
		if tile_image == null or tile_image.is_empty():
			push_warning("WeaponTilesetBake: placeholder used for %s" % entry.get("item_id", ""))
			tile_image = _placeholder_tile_image(float(index) / maxf(1.0, float(WEAPON_ENTRIES.size())))
		var coords := atlas_coords_for_index(index)
		atlas.blit_rect(tile_image, Rect2i(Vector2i.ZERO, tile_image.get_size()), coords * TILE_SIZE)
	var error := atlas.save_png(ATLAS_PATH)
	if error != OK:
		push_error("WeaponTilesetBake: failed to save atlas (%s)" % error)
		return {"texture": null, "size": Vector2i(width, height)}
	_scan_filesystem()
	var texture := load(ATLAS_PATH) as Texture2D
	return {"texture": texture, "size": Vector2i(width, height)}


static func _save_tileset_resource(texture: Texture2D) -> bool:
	if texture == null:
		push_error("WeaponTilesetBake: atlas texture missing")
		return false
	var tileset := _new_tileset_with_custom_data(TILE_SIZE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas.margins = Vector2i.ZERO
	atlas.separation = Vector2i.ZERO
	atlas.use_texture_padding = true
	tileset.add_source(atlas, 0)
	for index in range(WEAPON_ENTRIES.size()):
		var entry: Dictionary = WEAPON_ENTRIES[index]
		var item_id := str(entry.get("item_id", ""))
		var coords := atlas_coords_for_index(index)
		atlas.create_tile(coords)
		var tile_data := atlas.get_tile_data(coords, 0)
		if tile_data == null:
			continue
		tile_data.set_custom_data("item_id", item_id)
		tile_data.set_custom_data("display_name", display_name(item_id))
		tile_data.set_custom_data("description", description(item_id))
	var error := ResourceSaver.save(tileset, TILESET_PATH)
	if error != OK:
		push_error("WeaponTilesetBake: failed to save tileset (%s)" % error)
		return false
	_scan_filesystem()
	return true


static func _new_tileset_with_custom_data(tile_size: int) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(tile_size, tile_size)
	tileset.add_custom_data_layer()
	var item_layer := tileset.get_custom_data_layers_count() - 1
	tileset.set_custom_data_layer_name(item_layer, "item_id")
	tileset.set_custom_data_layer_type(item_layer, TYPE_STRING)
	tileset.add_custom_data_layer()
	var name_layer := tileset.get_custom_data_layers_count() - 1
	tileset.set_custom_data_layer_name(name_layer, "display_name")
	tileset.set_custom_data_layer_type(name_layer, TYPE_STRING)
	tileset.add_custom_data_layer()
	var desc_layer := tileset.get_custom_data_layers_count() - 1
	tileset.set_custom_data_layer_name(desc_layer, "description")
	tileset.set_custom_data_layer_type(desc_layer, TYPE_STRING)
	return tileset


static func _scan_filesystem() -> void:
	if Engine.is_editor_hint():
		var filesystem = EditorInterface.get_resource_filesystem()
		if filesystem:
			filesystem.scan()


static func _icon_to_tile_image(icon_path: String) -> Image:
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	image = image.duplicate()
	image.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	return image


static func _placeholder_tile_image(hue: float) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.from_hsv(hue, 0.42, 0.62, 1.0))
	return image


static func _ensure_output_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/tilesets"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/tilesets"))
