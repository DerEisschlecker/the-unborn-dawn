# Purpose: Crop weapon icons from the DD-style sheet into inventory-ready PNGs.
# Run: File > Run > run_weapon_sheet_slice.gd or WeaponTilemapEditor export.
class_name WeaponSheetSlicer
extends RefCounted

const Defs := preload("res://scripts/dev/weapon_sheet_definitions.gd")


static func slice_all() -> Dictionary:
	_ensure_output_dirs()
	var sheet := Image.load_from_file(Defs.SHEET_PATH)
	if sheet == null or sheet.is_empty():
		push_error("WeaponSheetSlicer: sheet missing at %s" % Defs.SHEET_PATH)
		return {"ok": false, "saved": 0}
	var saved := 0
	var paths: PackedStringArray = []
	for entry in Defs.slice_entries():
		var icon_path := str(entry.get("icon", ""))
		var rect: Rect2i = entry.get("rect", Rect2i())
		if icon_path.is_empty() or rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var cropped := _crop_and_fit(sheet, rect)
		if cropped == null:
			push_warning("WeaponSheetSlicer: crop failed for %s" % entry.get("item_id", ""))
			continue
		var disk_path := ProjectSettings.globalize_path(icon_path)
		var error := cropped.save_png(disk_path)
		if error != OK:
			push_error("WeaponSheetSlicer: save failed for %s (%s)" % [icon_path, error])
			continue
		saved += 1
		paths.append(icon_path)
	if Engine.is_editor_hint():
		var filesystem = EditorInterface.get_resource_filesystem()
		if filesystem:
			filesystem.scan()
	return {"ok": saved > 0, "saved": saved, "paths": paths}


static func _crop_and_fit(sheet: Image, rect: Rect2i) -> Image:
	var safe := Rect2i(
		clampi(rect.position.x, 0, maxi(0, sheet.get_width() - 1)),
		clampi(rect.position.y, 0, maxi(0, sheet.get_height() - 1)),
		rect.size.x,
		rect.size.y
	)
	safe.size.x = mini(safe.size.x, sheet.get_width() - safe.position.x)
	safe.size.y = mini(safe.size.y, sheet.get_height() - safe.position.y)
	if safe.size.x <= 0 or safe.size.y <= 0:
		return null
	var cropped := sheet.get_region(safe)
	_key_black_background(cropped)
	var fitted := Image.create(Defs.ICON_SIZE, Defs.ICON_SIZE, false, Image.FORMAT_RGBA8)
	fitted.fill(Color(0.0, 0.0, 0.0, 0.0))
	var scale := float(Defs.ICON_SIZE - 12) / float(maxi(cropped.get_width(), cropped.get_height()))
	var draw_w := maxi(1, int(round(cropped.get_width() * scale)))
	var draw_h := maxi(1, int(round(cropped.get_height() * scale)))
	cropped.resize(draw_w, draw_h, Image.INTERPOLATE_LANCZOS)
	var offset := Vector2i(int((Defs.ICON_SIZE - draw_w) / 2), int((Defs.ICON_SIZE - draw_h) / 2))
	fitted.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), offset)
	return fitted


static func _key_black_background(image: Image) -> void:
	var threshold := Defs.BLACK_KEY_THRESHOLD
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r <= threshold / 255.0 and color.g <= threshold / 255.0 and color.b <= threshold / 255.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))


static func _ensure_output_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/items/weapons/melee"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/items/weapons/ranged"))
