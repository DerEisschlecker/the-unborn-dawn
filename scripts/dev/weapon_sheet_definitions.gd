# Purpose: Source rects for the Darkest-Dungeon-style weapon sheet (non-uniform layout).
# Public API: slice_entries(), entry_for_item(), sheet_path().
class_name WeaponSheetDefinitions
extends RefCounted

const SHEET_PATH := "res://assets/tilesets/source/darkest_dungeon_weapons_sheet.png"
const ICON_SIZE := 128
const BLACK_KEY_THRESHOLD := 22

# rect: source crop on the sheet; icon: output under assets/items/weapons/
const SLICE_ENTRIES: Array[Dictionary] = [
	{"item_id": "scrap_greatsword", "icon": "res://assets/items/weapons/melee/scrap_greatsword.png", "rect": Rect2i(4, 2, 86, 94)},
	{"item_id": "machete", "icon": "res://assets/items/weapons/melee/machete.png", "rect": Rect2i(176, 184, 52, 44)},
	{"item_id": "rusty_knife", "icon": "res://assets/items/weapons/melee/rusty_knife.png", "rect": Rect2i(36, 186, 44, 72)},
	{"item_id": "fire_axe", "icon": "res://assets/items/weapons/melee/fire_axe.png", "rect": Rect2i(6, 266, 58, 56)},
	{"item_id": "war_axe", "icon": "res://assets/items/weapons/melee/war_axe.png", "rect": Rect2i(878, 252, 132, 122)},
	{"item_id": "old_revolver", "icon": "res://assets/items/weapons/ranged/old_revolver.png", "rect": Rect2i(78, 504, 98, 44)},
	{"item_id": "service_pistol", "icon": "res://assets/items/weapons/ranged/service_pistol.png", "rect": Rect2i(6, 508, 72, 40)},
	{"item_id": "hunting_rifle", "icon": "res://assets/items/weapons/ranged/hunting_rifle.png", "rect": Rect2i(182, 500, 112, 48)},
	{"item_id": "pump_shotgun", "icon": "res://assets/items/weapons/ranged/pump_shotgun.png", "rect": Rect2i(412, 498, 110, 50)},
	{"item_id": "compact_smg", "icon": "res://assets/items/weapons/ranged/compact_smg.png", "rect": Rect2i(524, 496, 108, 52)},
	{"item_id": "scoped_sniper", "icon": "res://assets/items/weapons/ranged/scoped_sniper.png", "rect": Rect2i(632, 494, 114, 54)},
	{"item_id": "heavy_crossbow", "icon": "res://assets/items/weapons/ranged/heavy_crossbow.png", "rect": Rect2i(908, 4, 98, 204)},
	{"item_id": "frag_grenade", "icon": "res://assets/items/weapons/ranged/frag_grenade.png", "rect": Rect2i(888, 572, 62, 82)},
	{"item_id": "dd_skull_dagger", "icon": "res://assets/items/weapons/melee/dd_skull_dagger.png", "rect": Rect2i(334, 96, 44, 72)},
	{"item_id": "dd_shortsword", "icon": "res://assets/items/weapons/melee/dd_shortsword.png", "rect": Rect2i(188, 0, 68, 95)},
	{"item_id": "dd_throw_knife", "icon": "res://assets/items/weapons/melee/dd_throw_knife.png", "rect": Rect2i(254, 38, 32, 52)},
	{"item_id": "dd_ritual_dagger", "icon": "res://assets/items/weapons/melee/dd_ritual_dagger.png", "rect": Rect2i(418, 100, 38, 70)},
	{"item_id": "dd_war_pick", "icon": "res://assets/items/weapons/melee/dd_war_pick.png", "rect": Rect2i(128, 274, 52, 50)},
	{"item_id": "dd_hatchet", "icon": "res://assets/items/weapons/melee/dd_hatchet.png", "rect": Rect2i(70, 270, 56, 54)},
	{"item_id": "dd_halberd", "icon": "res://assets/items/weapons/melee/dd_halberd.png", "rect": Rect2i(198, 326, 168, 62)},
	{"item_id": "dd_war_pike", "icon": "res://assets/items/weapons/melee/dd_war_pike.png", "rect": Rect2i(188, 404, 228, 62)},
	{"item_id": "dd_morning_star", "icon": "res://assets/items/weapons/melee/dd_morning_star.png", "rect": Rect2i(932, 412, 78, 100)},
	{"item_id": "dd_hunter_bow", "icon": "res://assets/items/weapons/ranged/dd_hunter_bow.png", "rect": Rect2i(862, 6, 46, 200)},
	{"item_id": "dd_longbow", "icon": "res://assets/items/weapons/ranged/dd_longbow.png", "rect": Rect2i(908, 4, 98, 204)},
	{"item_id": "dd_scrap_carbine", "icon": "res://assets/items/weapons/ranged/dd_scrap_carbine.png", "rect": Rect2i(296, 500, 114, 48)},
	{"item_id": "dd_combat_rifle", "icon": "res://assets/items/weapons/ranged/dd_combat_rifle.png", "rect": Rect2i(746, 492, 110, 56)},
	{"item_id": "dd_stick_grenade", "icon": "res://assets/items/weapons/ranged/dd_stick_grenade.png", "rect": Rect2i(948, 568, 66, 86)},
	{"item_id": "dd_mine_ball", "icon": "res://assets/items/weapons/ranged/dd_mine_ball.png", "rect": Rect2i(844, 606, 50, 54)},
]


static func slice_entries() -> Array[Dictionary]:
	return SLICE_ENTRIES.duplicate(true)


static func entry_for_item(item_id: String) -> Dictionary:
	for entry in SLICE_ENTRIES:
		if str(entry.get("item_id", "")) == item_id:
			return entry.duplicate(true)
	return {}


static func sheet_path() -> String:
	return SHEET_PATH
