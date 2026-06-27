# Purpose: Pack idle frame PNGs into atlases and generate combat/portrait variants.
# Run: Godot --headless --path . --script res://scripts/dev/run_character_atlas_bake.gd
class_name CharacterAtlasBake
extends RefCounted

const COLUMNS := 10
const COMBAT_SCALE := 0.4
const PORTRAIT_SIZE := 128
const COMBAT_STATIC_SIZE := 256

const ANIMATION_SETS: Array[Dictionary] = [
	{
		"folder": "res://assets/characters/mara_hollow/idle",
		"frame_count": 98,
		"pattern": "stand_%03d.png",
		"portrait": true,
	},
	{
		"folder": "res://assets/characters/priest/idle",
		"frame_count": 98,
		"pattern": "stand_%03d.png",
		"portrait": true,
	},
	{
		"folder": "res://assets/characters/priest/hit",
		"frame_count": 98,
		"pattern": "hit_%03d.png",
		"portrait": false,
	},
	{
		"folder": "res://assets/characters/mara_hollow/hit",
		"frame_count": 98,
		"pattern": "hit_%03d.png",
		"portrait": false,
	},
]

const STATIC_APPEARANCES: Array[String] = ["mechanic", "guardian"]
const STATIC_GENDERS: Array[String] = ["female", "male"]


static func bake_all() -> Dictionary:
	var results: Dictionary = {"animations": [], "static": []}
	for spec in ANIMATION_SETS:
		results.animations.append(_bake_animation_set(spec))
	results.static = _bake_static_variants()
	return results


static func _bake_animation_set(spec: Dictionary) -> Dictionary:
	var folder := str(spec.folder)
	var frame_count := int(spec.frame_count)
	var pattern := str(spec.pattern)
	var frames: Array[Image] = []
	for index in range(1, frame_count + 1):
		var frame_path := "%s/%s" % [folder, pattern % index]
		var image := _load_image(frame_path)
		if image == null:
			push_error("CharacterAtlasBake: missing frame %s" % frame_path)
			return {"ok": false, "folder": folder}
		frames.append(image)
	var frame_size := Vector2i(frames[0].get_width(), frames[0].get_height())
	var rows := int(ceilf(float(frame_count) / float(COLUMNS)))
	var showcase := Image.create(COLUMNS * frame_size.x, rows * frame_size.y, false, Image.FORMAT_RGBA8)
	showcase.fill(Color(0, 0, 0, 0))
	var combat_frame_size := Vector2i(
		maxi(1, int(round(float(frame_size.x) * COMBAT_SCALE))),
		maxi(1, int(round(float(frame_size.y) * COMBAT_SCALE)))
	)
	var combat := Image.create(
		COLUMNS * combat_frame_size.x,
		rows * combat_frame_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	combat.fill(Color(0, 0, 0, 0))
	for index in range(frame_count):
		var column := index % COLUMNS
		var row := int(index / COLUMNS)
		var source_rect := Rect2i(0, 0, frame_size.x, frame_size.y)
		var showcase_target := Vector2i(column * frame_size.x, row * frame_size.y)
		showcase.blit_rect(frames[index], source_rect, showcase_target)
		var combat_frame := frames[index].duplicate()
		combat_frame.resize(combat_frame_size.x, combat_frame_size.y, Image.INTERPOLATE_LANCZOS)
		combat.blit_rect(
			combat_frame,
			Rect2i(0, 0, combat_frame_size.x, combat_frame_size.y),
			Vector2i(column * combat_frame_size.x, row * combat_frame_size.y)
		)
	var portrait := _fit_cover(frames[0], PORTRAIT_SIZE, PORTRAIT_SIZE)
	_save_image(showcase, "%s/showcase_atlas.png" % folder)
	_save_image(combat, "%s/combat_atlas.png" % folder)
	if bool(spec.get("portrait", false)):
		_save_image(portrait, "%s/portrait.png" % folder)
	return {
		"ok": true,
		"folder": folder,
		"frame_count": frame_count,
		"frame_size": frame_size,
		"combat_frame_size": combat_frame_size,
		"columns": COLUMNS,
	}


static func _bake_static_variants() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for gender in STATIC_GENDERS:
		for appearance in STATIC_APPEARANCES:
			var source_path := "res://assets/characters/player_variants/%s_%s.png" % [gender, appearance]
			var image := _load_image(source_path)
			if image == null:
				push_error("CharacterAtlasBake: missing static variant %s" % source_path)
				results.append({"ok": false, "path": source_path})
				continue
			var combat := _fit_contain(image, COMBAT_STATIC_SIZE, COMBAT_STATIC_SIZE)
			var portrait := _fit_cover(image, PORTRAIT_SIZE, PORTRAIT_SIZE)
			var combat_path := "res://assets/characters/player_variants/combat/%s_%s.png" % [gender, appearance]
			var portrait_path := "res://assets/characters/player_variants/portraits/%s_%s.png" % [gender, appearance]
			_ensure_parent_dir(combat_path)
			_ensure_parent_dir(portrait_path)
			_save_image(combat, combat_path)
			_save_image(portrait, portrait_path)
			results.append({"ok": true, "path": source_path})
	return results


static func _load_image(path: String) -> Image:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var error := image.load(absolute)
	if error != OK:
		return null
	return _ensure_rgba(image)


static func _ensure_rgba(image: Image) -> Image:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func _save_image(image: Image, path: String) -> void:
	_ensure_parent_dir(path)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("CharacterAtlasBake: failed to save %s (%s)" % [path, error])


static func _ensure_parent_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)


static func _fit_contain(source: Image, width: int, height: int) -> Image:
	var canvas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var scale := minf(float(width) / float(source.get_width()), float(height) / float(source.get_height()))
	var target := Vector2i(
		maxi(1, int(round(float(source.get_width()) * scale))),
		maxi(1, int(round(float(source.get_height()) * scale)))
	)
	var resized := source.duplicate()
	resized.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var offset := Vector2i(int((width - target.x) / 2), int((height - target.y) / 2))
	canvas.blit_rect(resized, Rect2i(0, 0, target.x, target.y), offset)
	return canvas


static func _fit_cover(source: Image, width: int, height: int) -> Image:
	var scale := maxf(float(width) / float(source.get_width()), float(height) / float(source.get_height()))
	var target := Vector2i(
		maxi(1, int(round(float(source.get_width()) * scale))),
		maxi(1, int(round(float(source.get_height()) * scale)))
	)
	var resized := source.duplicate()
	resized.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var offset := Vector2i(int((target.x - width) / 2), int((target.y - height) / 2))
	var cropped := Image.create(width, height, false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0, 0, 0, 0))
	cropped.blit_rect(resized, Rect2i(offset.x, offset.y, width, height), Vector2i.ZERO)
	return cropped
