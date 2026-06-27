# Purpose: Dev scene for painting / selecting weapons on a TileMapLayer (Godot TileSet workflow).
# Editor: open bottom panel "TileSet", use Setup to slice atlas, Select to edit Custom Data (item_id).
@tool
extends Node2D

const BakeScript := preload("res://scripts/dev/weapon_tileset_bake.gd")
const SlicerScript := preload("res://scripts/dev/weapon_sheet_slicer.gd")
const TILESET_PATH := "res://resources/tilesets/weapon_tileset.tres"
const SOURCE_SHEET_PATH := "res://assets/tilesets/source/darkest_dungeon_weapons_sheet.png"

@export var setup_manual_sheet: bool = false:
	set(value):
		if not value:
			return
		setup_manual_sheet = false
		_run_manual_setup()

@export var slice_icons_now: bool = false:
	set(value):
		if not value:
			return
		slice_icons_now = false
		_run_slice()

@export var bake_now: bool = false:
	set(value):
		if not value:
			return
		bake_now = false
		_run_bake()

@export var repaint_catalog: bool = false:
	set(value):
		if not value:
			return
		repaint_catalog = false
		_paint_catalog_row()

@onready var catalog_layer: TileMapLayer = $WeaponCatalog
@onready var layout_layer: TileMapLayer = $WeaponLayout
@onready var info_label: Label = $CanvasLayer/InfoLabel


func _ready() -> void:
	if Engine.is_editor_hint():
		if not FileAccess.file_exists(TILESET_PATH):
			_run_manual_setup()
		_ensure_tileset_assigned()
		if catalog_layer.get_used_cells().is_empty() and _catalog_auto_paint_supported():
			_paint_catalog_row()
		return
	info_label.text = "Klicke ein Waffen-Tile. Custom Data kommt aus dem TileSet (item_id)."


func _run_manual_setup() -> void:
	var result: Dictionary = BakeScript.save_manual_sheet_tileset()
	print("WeaponTilesetBake manual: ", result)
	_ensure_tileset_assigned()
	if is_instance_valid(info_label):
		info_label.text = (
			"TileSet bereit: %s\n"
			+ "1) WeaponLayout anklicken\n"
			+ "2) Unten Tab 'TileSet' oeffnen (oder Inspektor > Tile Set > Stift)\n"
			+ "3) Setup: Bereiche auf dem Waffen-Sheet selektieren\n"
			+ "4) Select: item_id eintragen (z.B. dd_halberd)"
		) % str(result.get("source_sheet", SOURCE_SHEET_PATH))


func _run_bake() -> void:
	var result: Dictionary = BakeScript.save_all()
	print("WeaponTilesetBake: ", result)
	_ensure_tileset_assigned()
	_paint_catalog_row()
	if is_instance_valid(info_label):
		info_label.text = "Atlas + TileSet neu gebaut (%d Waffen)." % int(result.get("entries", 0))


func _run_slice() -> void:
	var result: Dictionary = SlicerScript.slice_all()
	print("WeaponSheetSlicer: ", result)
	if is_instance_valid(info_label):
		info_label.text = "Icons aus Sheet geschnitten (%d)." % int(result.get("saved", 0))


func _ensure_tileset_assigned() -> void:
	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		push_warning("weapon_tilemap_editor: TileSet missing. Enable 'Bake Now' on the root node.")
		return
	if is_instance_valid(catalog_layer):
		catalog_layer.tile_set = tileset
	if is_instance_valid(layout_layer):
		layout_layer.tile_set = tileset


func _paint_catalog_row() -> void:
	if not is_instance_valid(catalog_layer) or catalog_layer.tile_set == null:
		return
	if not _catalog_auto_paint_supported():
		return
	catalog_layer.clear()
	for index in range(BakeScript.entry_count()):
		var coords := BakeScript.atlas_coords_for_index(index)
		catalog_layer.set_cell(Vector2i(index, 0), 0, coords)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var layer := layout_layer if _has_weapon_at(layout_layer, click.global_position) else catalog_layer
	var item_id := WeaponTilemapCatalog.item_id_at_global(layer, click.global_position)
	if item_id.is_empty():
		return
	var data := DataCatalog.item(item_id)
	info_label.text = "%s (%s)\n%s" % [
		data.get("name", item_id),
		item_id,
		data.get("description", "")
	]


func _has_weapon_at(layer: TileMapLayer, global_position: Vector2) -> bool:
	if layer == null:
		return false
	var local := layer.to_local(global_position)
	var cell := layer.local_to_map(local)
	return layer.get_cell_source_id(cell) != -1


func _catalog_auto_paint_supported() -> bool:
	var tileset := catalog_layer.tile_set if is_instance_valid(catalog_layer) else null
	if tileset == null or tileset.get_source_count() == 0:
		return false
	var atlas := tileset.get_source(0) as TileSetAtlasSource
	if atlas == null:
		return false
	return atlas.get_tiles_count() >= BakeScript.entry_count()
