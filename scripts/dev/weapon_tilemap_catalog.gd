# Purpose: Read weapon item_id / labels from TileMapLayer custom data (TileSet Select tab).
class_name WeaponTilemapCatalog
extends RefCounted


static func item_id_at_global(layer: TileMapLayer, global_position: Vector2) -> String:
	if layer == null:
		return ""
	var local := layer.to_local(global_position)
	return item_id_at_map(layer, layer.local_to_map(local))


static func item_id_at_map(layer: TileMapLayer, cell: Vector2i) -> String:
	var tile_data := tile_data_at(layer, cell)
	if tile_data == null:
		return ""
	return str(tile_data.get_custom_data("item_id"))


static func display_name_at_map(layer: TileMapLayer, cell: Vector2i) -> String:
	var tile_data := tile_data_at(layer, cell)
	if tile_data == null:
		return ""
	var custom_name := str(tile_data.get_custom_data("display_name"))
	if not custom_name.is_empty():
		return custom_name
	var item_id := str(tile_data.get_custom_data("item_id"))
	if item_id.is_empty():
		return ""
	return str(DataCatalog.item(item_id).get("name", item_id))


static func description_at_map(layer: TileMapLayer, cell: Vector2i) -> String:
	var tile_data := tile_data_at(layer, cell)
	if tile_data == null:
		return ""
	var custom_desc := str(tile_data.get_custom_data("description"))
	if not custom_desc.is_empty():
		return custom_desc
	var item_id := str(tile_data.get_custom_data("item_id"))
	if item_id.is_empty():
		return ""
	return str(DataCatalog.item(item_id).get("description", ""))


static func tile_data_at(layer: TileMapLayer, cell: Vector2i) -> TileData:
	if layer == null or layer.get_cell_source_id(cell) == -1:
		return null
	return layer.get_cell_tile_data(cell)
