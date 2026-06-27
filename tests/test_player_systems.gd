@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const MaraHollowIdleFramesScript := preload("res://scripts/characters/mara_hollow_idle_frames.gd")
const MaraHollowHitFramesScript := preload("res://scripts/characters/mara_hollow_hit_frames.gd")
const PriestIdleFramesScript := preload("res://scripts/characters/priest_idle_frames.gd")
const PriestHitFramesScript := preload("res://scripts/characters/priest_hit_frames.gd")
const TurnLogic := preload("res://scripts/combat/combat_turn_logic.gd")
const DisplayManagerScript := preload("res://autoload/display_manager.gd")


func suite_name() -> String:
	return "player_systems"


func _entries(path: String) -> Dictionary:
	var resource := load(path)
	if resource == null:
		return {}
	return resource.entries.duplicate(true)


func test_catalog_resources_contain_equipment_and_traps() -> void:
	var armor := _entries("res://data/items/armor.tres")
	var melee := _entries("res://data/items/weapons_melee.tres")
	var ranged := _entries("res://data/items/weapons_ranged.tres")
	var structures := _entries("res://data/building/structures.tres")
	assert_has_key(armor, "work_boots")
	assert_has_key(armor, "scrap_helmet")
	assert_has_key(armor, "scrap_shield")
	assert_has_key(armor, "reinforced_shield")
	assert_has_key(melee, "fire_axe")
	assert_eq(armor.work_boots.get("equip_slot", ""), "shoes")
	assert_eq(armor.scrap_shield.get("equip_slot", ""), "shield")
	assert_eq(ranged.old_revolver.get("equip_slot", ""), "firearm")
	assert_eq(structures.spike_trap.get("category", ""), "Falle")
	assert_gt(float(structures.shrapnel_trap.get("trap_damage", 0.0)), 0.0)


func test_weapon_rarities_durability_and_admin_catalog() -> void:
	var melee := _entries("res://data/items/weapons_melee.tres")
	var ranged := _entries("res://data/items/weapons_ranged.tres")
	for item_id in ["rusty_knife", "rusty_knife_rare", "rusty_knife_epic", "rusty_knife_legendary"]:
		assert_has_key(melee, item_id)
		assert_gt(int(melee[item_id].get("max_condition", 0)), 0)
	for item_id in ["service_pistol", "compact_smg", "scoped_sniper", "frag_grenade"]:
		assert_has_key(ranged, item_id)
		assert_true(FileAccess.file_exists(str(ranged[item_id].get("icon", ""))))
		assert_gt(int(ranged[item_id].get("spawn_weight", 0)), 0)
	assert_eq(ranged.frag_grenade.get("equip_slot", ""), "throwable")
	assert_eq(ranged.compact_smg.get("ammo_cost", 0), 2)
	var inventory_source := FileAccess.get_file_as_string("res://autoload/inventory_system.gd")
	assert_contains(inventory_source, "item_condition")
	assert_contains(inventory_source, "repair_item")
	assert_contains(inventory_source, "admin_grant_item")


func test_time_system_has_twenty_four_rounds() -> void:
	var source := FileAccess.get_file_as_string("res://autoload/time_system.gd")
	assert_contains(source, "HOURS_PER_DAY := 24")
	assert_contains(source, "enemy_strength_multiplier")
	assert_contains(source, "scene_light_color")
	assert_contains(source, "GameState.MAX_DAY")
	assert_contains(source, "laengsten Nacht")


func test_player_classes_have_abilities_and_progression_stats() -> void:
	var player := _entries("res://data/player/player_stats_base.tres")
	assert_has_key(player, "base")
	var config: Dictionary = player.base
	var stats: Dictionary = config.stats
	assert_has_key(stats, "level")
	assert_has_key(stats, "skill_points")
	assert_has_key(stats, "strength")
	assert_has_key(stats, "dexterity")
	assert_has_key(stats, "intelligence")
	assert_has_key(stats, "vitality")
	assert_has_key(stats, "willpower")
	assert_has_key(stats, "physical_resistance")
	assert_has_key(stats, "chaos_resistance")
	assert_has_key(stats, "melee")
	assert_has_key(stats, "accuracy")
	assert_has_key(stats, "crafting")
	for class_id in ["scout", "medic", "guardian", "tinker"]:
		assert_has_key(config.classes, class_id)
		assert_has_key(config.classes[class_id], "ability")
		assert_has_key(config.classes[class_id].ability, "name")
	var source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	assert_contains(source, "CLASS_ABILITIES")
	assert_contains(source, "ABILITY_UNLOCK_LEVELS")
	assert_contains(source, "MAX_EQUIPPED_ABILITIES")
	assert_contains(source, "pending_ability_picks")
	assert_contains(source, "ability_action_points")
	assert_contains(source, "ability_cooldown")
	assert_contains(source, "ability_unlock_level")
	assert_contains(source, "set_ability_slot")
	assert_contains(source, "effective_player_stats")
	assert_contains(source, "\"accuracy\"")
	assert_contains(source, "SURVIVOR_ROLE_NAMES")
	assert_contains(source, "survivor_role_name")


func test_rpg_rules_define_modular_damage_resistance_and_effects() -> void:
	var source := FileAccess.get_file_as_string("res://autoload/rpg_rules.gd")
	assert_contains(source, "PRIMARY_ATTRIBUTES")
	assert_contains(source, "DAMAGE_TYPES")
	assert_contains(source, "BUFF_DEFINITIONS")
	assert_contains(source, "DEBUFF_DEFINITIONS")
	assert_contains(source, "ENDGAME_STATS")
	assert_contains(source, "calculate_damage")
	assert_contains(source, "hit_chance")
	assert_contains(source, "chaos")


func test_combat_and_exploration_have_turn_point_rules() -> void:
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat/combat_scene.gd")
	assert_contains(combat_source, "PLAYER_ACTION_POINTS_PER_TURN := 4")
	assert_contains(combat_source, "ability_cooldowns")
	assert_contains(combat_source, "_spend_combat_action_points")
	assert_contains(combat_source, "_success_chance")
	assert_contains(combat_source, "_roll_success")
	assert_contains(combat_source, "_request_end_turn")
	assert_contains(combat_source, "KEY_SPACE")
	assert_contains(combat_source, "accuracy")
	assert_contains(combat_source, "RpgRules.calculate_damage")
	assert_contains(combat_source, "RpgRules.hit_chance")
	assert_contains(combat_source, "player_stat_bars")
	assert_contains(combat_source, "_set_combat_preview")
	assert_contains(combat_source, "_ability_preview_deltas")
	assert_contains(combat_source, "_estimate_attack_damage_on_hit")
	assert_contains(combat_source, "_refresh_enemy_health_preview")
	assert_contains(combat_source, "attach_stat_bar_preview")
	assert_contains(combat_source, "_refresh_combat_summary")
	assert_contains(combat_source, "combat_totals")
	assert_contains(combat_source, "_record_damage_dealt")
	assert_contains(combat_source, "SUMMARY_COLOR_DAMAGE")
	assert_contains(combat_source, "combat_events")
	assert_contains(combat_source, "_push_combat_event")
	assert_contains(combat_source, "combat_summary_label")
	assert_contains(combat_source, "KAMPFUEBERSICHT")
	assert_contains(combat_source, "\"VERLAUF\"")
	assert_contains(combat_source, "COMBAT_STATUS_DESCRIPTIONS")
	assert_contains(combat_source, "combat_debuff_row")
	assert_contains(combat_source, "_track_health_healing")
	var exploration_source := FileAccess.get_file_as_string("res://scripts/exploration/exploration_scene.gd")
	assert_contains(exploration_source, "MOVE_POINTS_PER_ROUND := 6")
	assert_contains(exploration_source, "ACTION_POINTS_PER_ROUND := 2")
	assert_contains(exploration_source, "KEY_W")
	assert_contains(exploration_source, "KEY_A")
	assert_contains(exploration_source, "KEY_S")
	assert_contains(exploration_source, "KEY_D")
	assert_contains(exploration_source, "LootPopupScene")
	assert_contains(exploration_source, "_open_loot_popup")


func test_enemy_death_opens_loot_exchange_with_stat_compare() -> void:
	var enemies := _entries("res://data/enemies/enemy_stats.tres")
	for enemy_id in ["demon_basic", "demon_runner", "demon_brute", "demon_boss"]:
		assert_has_key(enemies, enemy_id)
		assert_gt(enemies[enemy_id].get("loot", []).size(), 0)
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat/combat_scene.gd")
	var loot_popup_source := FileAccess.get_file_as_string("res://scripts/exploration/loot_popup.gd")
	assert_contains(combat_source, "enemy_loot")
	assert_contains(combat_source, "_show_enemy_loot_menu")
	assert_contains(combat_source, "_equip_enemy_loot")
	assert_contains(combat_source, "_comparison_text")
	assert_contains(combat_source, "loot_slot_bar")
	assert_contains(combat_source, "loot_weight_bar")
	assert_contains(combat_source, "_add_loot_usage_bar")
	assert_contains(combat_source, "▲")
	assert_contains(combat_source, "▼")
	assert_contains(combat_source, "Alles nehmen")
	assert_contains(combat_source, "Plaetze")
	assert_contains(combat_source, "Traglast")
	assert_contains(combat_source, "_add_combat_condition_strip")
	assert_contains(combat_source, "InventorySlotScript")
	assert_contains(combat_source, "ItemDragDrop")
	assert_contains(combat_source, "transient_loot")
	assert_contains(loot_popup_source, "Leerer Behaelter")
	assert_contains(loot_popup_source, "Schliessen")
	assert_contains(loot_popup_source, "InventorySlotScript")
	assert_contains(loot_popup_source, "enemy_loot")
	assert_contains(loot_popup_source, "ItemDragDrop.apply_drop")


func test_inventory_uses_backpack_and_clothing_containers() -> void:
	var inventory_source := FileAccess.get_file_as_string("res://autoload/inventory_system.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_screen.gd")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/ui_factory.gd")
	var slot_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_slot.gd")
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat/combat_scene.gd")
	var gameplay_source := FileAccess.get_file_as_string("res://scripts/ui/gameplay_screen.gd")
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	var structures := _entries("res://data/building/structures.tres")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var tooltip_source := FileAccess.get_file_as_string("res://autoload/item_tooltip.gd")
	var armor := _entries("res://data/items/armor.tres")
	assert_contains(inventory_source, "backpack_slot_capacity")
	assert_contains(inventory_source, "clothing_slot_capacity")
	assert_contains(inventory_source, "sorted_items_for_layout")
	assert_contains(inventory_source, "usable_item")
	assert_contains(inventory_source, "combat_item_action_points")
	assert_contains(inventory_source, "money")
	assert_contains(inventory_source, "can_add_item")
	assert_contains(inventory_source, "storage_items")
	assert_contains(inventory_source, "storage_max_weight")
	assert_contains(inventory_source, "storage_chest")
	assert_contains(inventory_source, "quick_slots")
	assert_contains(inventory_source, "set_quick_slot")
	assert_contains(inventory_source, "split_stack_to_other_container")
	assert_contains(inventory_source, "transfer_to_storage")
	assert_contains(inventory_source, "transfer_to_backpack")
	assert_contains(inventory_source, "discard_storage_item")
	assert_contains(inventory_source, "has_craft_materials")
	assert_contains(inventory_source, "take_craft_materials")
	assert_contains(inventory_source, "restore_craft_materials")
	assert_contains(inventory_source, "crafting_uses_storage")
	assert_contains(screen_source, "RUCKSACK")
	assert_contains(screen_source, "LAGER")
	assert_contains(screen_source, "SCHNELLZUGRIFF")
	assert_contains(screen_source, "_refresh_actions")
	assert_contains(screen_source, "Entsorgen")
	assert_contains(screen_source, "_slot_preview_text")
	assert_contains(screen_source, "AUSRUESTUNG")
	assert_contains(screen_source, "AUSRUESTUNGSWERTE")
	assert_contains(screen_source, "_stat_display_rows")
	assert_contains(screen_source, "_refresh_stats")
	assert_contains(screen_source, "COLOR_STAT_BETTER")
	assert_contains(screen_source, "COLOR_STAT_WORSE")
	assert_contains(screen_source, "EQUIPMENT_EXTRA_SLOTS")
	assert_contains(screen_source, "_equipment_weapon_column")
	assert_contains(screen_source, "AUSRÜSTUNG")
	assert_false(screen_source.contains("equipped_summary_label"))
	assert_false(screen_source.contains("Trage deine Gegenstaende bei dir."))
	assert_contains(screen_source, "_set_compare_equip")
	assert_contains(screen_source, "_set_compare_unequip")
	assert_contains(screen_source, "_compare_context")
	assert_contains(screen_source, "projected_equipment_stat_bonuses")
	assert_contains(screen_source, "Widerstand gegen %s")
	assert_contains(inventory_source, "projected_equipment_stat_bonuses")
	assert_contains(inventory_source, "projected_armor_value")
	assert_contains(inventory_source, "\"shield\"")
	assert_contains(inventory_source, "\"ring\"")
	assert_contains(inventory_source, "\"belt\"")
	assert_contains(inventory_source, "\"amulet\"")
	assert_contains(inventory_source, "is_two_handed")
	assert_contains(inventory_source, "equipped_two_handed_weapon")
	assert_contains(inventory_source, "is_slot_blocked")
	assert_contains(screen_source, "_backpack_equipment_slot")
	assert_contains(screen_source, "backpack_slot")
	assert_contains(screen_source, "COLOR_SLOT_BLOCKED")
	assert_contains(combat_source, "_backpack_slot_frame")
	assert_contains(screen_source, "Shift + Rechtsklick")
	assert_contains(screen_source, "Strg + Rechtsklick")
	assert_contains(screen_source, "KEY_ESCAPE")
	assert_contains(screen_source, "extends Control")
	assert_contains(screen_source, "CenterContainer")
	assert_contains(screen_source, "queue_free")
	assert_contains(screen_source, "_resolve_overlay_layout")
	assert_contains(screen_source, "overlay_safe_height")
	assert_contains(screen_source, "InventorySlotScript")
	assert_contains(screen_source, "_on_item_dropped")
	assert_contains(screen_source, "_equip_from_source")
	assert_contains(screen_source, "ItemDragDrop.apply_drop")
	assert_contains(slot_source, "decorate")
	assert_contains(slot_source, "apply_item_rarity_frame")
	assert_contains(slot_source, "attach_item_tooltip")
	assert_contains(slot_source, "_get_drag_data")
	assert_contains(slot_source, "_drop_data")
	assert_contains(slot_source, "item_dropped")
	var drag_drop_source := FileAccess.get_file_as_string("res://autoload/item_drag_drop.gd")
	var admin_source := FileAccess.get_file_as_string("res://scripts/ui/admin_item_screen.gd")
	assert_contains(project_source, "ItemDragDrop=\"*res://autoload/item_drag_drop.gd\"")
	assert_false(drag_drop_source.contains("class_name ItemDragDrop"))
	assert_contains(drag_drop_source, "apply_drop")
	assert_contains(drag_drop_source, "create_drag_preview")
	assert_contains(drag_drop_source, "z_index = 4096")
	assert_contains(drag_drop_source, "enemy_loot")
	assert_contains(admin_source, "InventorySlotScript")
	assert_contains(admin_source, "_admin_drag_slot")
	assert_contains(combat_source, "quick_slot_items")
	assert_contains(combat_source, "Schnellzugriff aus")
	assert_contains(gameplay_source, "INVENTORY_SCENE")
	assert_contains(gameplay_source, "InventoryOverlay")
	assert_contains(gameplay_source, "inventory.name = \"InventoryOverlay\"")
	assert_false(gameplay_source.contains("open_equipment"))
	assert_false(gameplay_source.contains("EquipmentOverlay"))
	assert_false(gameplay_source.contains("KEY_C"))
	assert_contains(hud_source, "current.call(\"open_inventory\")")
	assert_false(gameplay_source.contains("go_to(\"res://scenes/ui/inventory_screen.tscn\")"))
	assert_false(hud_source.contains("change_scene_to_file(\"res://scenes/ui/inventory_screen.tscn\")"))
	assert_has_key(structures, "storage_chest")
	assert_false(project_source.contains("window/size/mode=3"))
	assert_contains(ui_source, "viewport_size")
	assert_contains(ui_source, "menu_panel_size")
	assert_contains(ui_source, "overlay_safe_height")
	assert_contains(ui_source, "overlay_screen_margins")
	assert_contains(ui_source, "gameplay_hud_clearance")
	assert_contains(screen_source, "_estimate_body_height")
	assert_contains(screen_source, "_resolve_overlay_layout")
	assert_contains(screen_source, "_build_quick_bar")
	assert_contains(screen_source, "SIZE_SHRINK_END")
	assert_contains(ui_source, "content_max_width")
	assert_contains(ui_source, "menu_button")
	assert_contains(ui_source, "scroll_wrap")
	assert_contains(project_source, "ItemTooltip")
	assert_contains(tooltip_source, "SHOW_DELAY := 1.0")
	assert_contains(tooltip_source, "show_item_delayed")
	assert_contains(tooltip_source, "DataCatalog.item_value")
	assert_contains(ui_source, "RARITY_NORMAL")
	assert_contains(ui_source, "RARITY_RARE")
	assert_contains(ui_source, "RARITY_EPIC")
	assert_contains(ui_source, "RARITY_LEGENDARY")
	assert_contains(ui_source, "rarity_legend")
	assert_contains(ui_source, "condition_color")
	assert_contains(ui_source, "_animate_legendary_frame")
	assert_contains(ui_source, "style.border_color = color")
	assert_gt(int(armor.patched_jacket.get("pocket_slots", 0)), 0)
	assert_gt(int(armor.leather_vest.get("pocket_slots", 0)), 0)


func test_world_map_uses_player_map_and_path_rules() -> void:
	var locations := _entries("res://data/world/locations.tres")
	var source := FileAccess.get_file_as_string("res://scripts/world_map/world_map.gd")
	var gameplay_source := FileAccess.get_file_as_string("res://scripts/ui/gameplay_screen.gd")
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	var ui_factory_source := FileAccess.get_file_as_string("res://scripts/ui/ui_factory.gd")
	assert_true(FileAccess.file_exists("res://assets/environments/map_overview/world_main_map.jpg"))
	assert_true(FileAccess.file_exists("res://assets/environments/map_overview/route_detail_reference.png"))
	assert_gt(locations.size(), 20)
	assert_has_key(locations, "ash_market")
	assert_has_key(locations, "collapsed_bridge")
	assert_has_key(locations, "harbor_pier")
	assert_has_key(locations, "drowned_quay")
	assert_has_key(locations, "black_forge")
	assert_has_key(locations, "cathedral_gate")
	assert_has_key(locations, "watchtower")
	assert_has_key(locations, "south_roadblock")
	assert_has_key(locations, "old_bunker")
	assert_has_key(locations, "sealed_metro")
	assert_has_key(locations, "signal_observatory")
	assert_contains(source, "MAP_NODES")
	assert_contains(source, "_open_travel_popup")
	assert_contains(source, "travel_popup_open")
	assert_contains(source, "travel_overlay")
	assert_contains(source, "consumable_pick_counts")
	assert_contains(source, "consumable_rows")
	assert_contains(source, "travel_food_drink_items")
	assert_contains(source, "_requirement_blocker")
	assert_contains(source, "_try_unlock_requirement")
	assert_contains(source, "_confirm_travel")
	assert_contains(source, "_refresh_travel_preview")
	assert_contains(source, "_add_travel_bar")
	assert_contains(source, "TRAVEL_PREVIEW_ALPHA")
	assert_contains(source, "_apply_travel_stat_preview")
	assert_contains(source, "HOURS_PER_DAY")
	assert_contains(source, "TRAVEL_HOURS_PER_TIER")
	assert_contains(source, "TRAVEL_BAR_ANIM_SEC")
	assert_contains(source, "enter_button.visible")
	assert_contains(source, "_position_travel_popup")
	assert_contains(source, "DETAIL_PANEL_TEXTURE")
	assert_contains(source, "_resource_max_for_bar")
	assert_contains(source, "harbor_pier")
	assert_contains(source, "watchtower_key")
	assert_contains(source, "_travel_stamina_cost")
	assert_contains(source, "selected_node_id")
	assert_contains(source, "current_badge")
	assert_contains(source, "node_labels")
	assert_contains(source, "_map_label_text")
	assert_contains(source, "trader_screen.tscn")
	assert_contains(source, "_preview_node")
	assert_contains(source, "NODE_SIZE := Vector2(52, 52)")
	assert_contains(source, "attach_hud")
	assert_contains(source, "clear_dynamic_children")
	assert_contains(source, "map_texture_size")
	assert_contains(source, "_resolve_map_size")
	assert_contains(source, "map_viewport")
	assert_contains(source, "_on_map_drag_input")
	assert_contains(source, "_map_cover_zoom")
	assert_contains(source, "_try_unlock_requirement")
	assert_contains(source, "_kind_icon")
	assert_contains(source, "icon_alignment")
	assert_contains(source, "_map_point_to_canvas")
	assert_contains(source, "_update_current_badge")
	assert_contains(source, "Vector2(0.060, 0.140)")
	assert_contains(source, "Vector2(0.750, 0.170)")
	assert_contains(source, "Vector2(0.730, 0.870)")
	assert_contains(gameplay_source, "compact_screen")
	assert_contains(gameplay_source, "UiFactory.is_compact_screen")
	assert_contains(ui_factory_source, "visible_screen_size")
	assert_contains(ui_factory_source, "viewport_size")
	assert_contains(ui_factory_source, "wire_button_sound")
	assert_contains(ui_factory_source, "ornate_panel_style")
	assert_contains(ui_factory_source, "framed_column")
	assert_contains(hud_source, "compact_hud")
	assert_contains(hud_source, "day_icon")
	assert_contains(hud_source, "UiFactory.stat_bar_color")
	assert_contains(hud_source, "UiFactory.apply_stat_bar")
	assert_contains(hud_source, "backpack_button")
	assert_contains(hud_source, "abilities_button")
	assert_contains(hud_source, "rest_button")
	assert_contains(hud_source, "icon_size")
	assert_contains(hud_source, "_open_inventory")
	assert_contains(hud_source, "UiFactory.hud_height(self)")
	assert_contains(hud_source, "PRESET_BOTTOM_WIDE")
	assert_contains(hud_source, "configure_hud_bar_background")
	assert_contains(hud_source, "_on_stat_preview_changed")
	var preview_source := FileAccess.get_file_as_string("res://autoload/hud_stat_preview.gd")
	assert_contains(preview_source, "stat_preview_changed")
	assert_contains(preview_source, "apply_deltas")
	assert_contains(ui_factory_source, "attach_stat_bar_preview")
	assert_contains(source, "_sync_hud_travel_preview")
	assert_contains(source, "HudStatPreview.set_projected")
	assert_contains(hud_source, "hud.tscn")
	var hud_scene_source := FileAccess.get_file_as_string("res://scenes/ui/hud.tscn")
	assert_contains(hud_scene_source, "NinePatchRect")
	assert_contains(hud_scene_source, "clock_face.gd")
	assert_contains(hud_scene_source, "HealthIcon")
	assert_contains(hud_scene_source, "HudRow")
	assert_contains(gameplay_source, "clear_dynamic_children")
	assert_contains(gameplay_source, "PRESERVED_SCENE_CHILDREN")
	assert_false(hud_source.contains("backpack_slots"))
	var path_source := FileAccess.get_file_as_string("res://scripts/world_map/map_path_layer.gd")
	assert_contains(path_source, "selected")
	assert_contains(path_source, "Time.get_ticks_msec")


func test_trader_screen_buys_sells_and_uses_item_values() -> void:
	var catalog_source := FileAccess.get_file_as_string("res://autoload/data_catalog.gd")
	var inventory_source := FileAccess.get_file_as_string("res://autoload/inventory_system.gd")
	var trader_source := FileAccess.get_file_as_string("res://scripts/ui/trader_screen.gd")
	var card_source := FileAccess.get_file_as_string("res://scripts/ui/trade_item_card.gd")
	var drop_source := FileAccess.get_file_as_string("res://scripts/ui/trade_drop_zone.gd")
	assert_ne(load("res://scenes/ui/trader_screen.tscn"), null)
	assert_contains(catalog_source, "item_value")
	assert_contains(catalog_source, "item_buy_price")
	assert_contains(catalog_source, "item_sell_price")
	assert_contains(inventory_source, "money")
	assert_contains(inventory_source, "spend_money")
	assert_contains(inventory_source, "add_money")
	assert_contains(trader_source, "BASE_STOCK")
	assert_contains(trader_source, "buy_cart")
	assert_contains(trader_source, "sell_cart")
	assert_contains(trader_source, "_handle_drop")
	assert_contains(trader_source, "_confirm_trade")
	assert_contains(trader_source, "_cart_fits_after_trade")
	assert_contains(trader_source, "_add_all_to_sell")
	assert_contains(trader_source, "Dawn-Credits")
	assert_contains(trader_source, "ITEMS_PER_PAGE")
	assert_contains(card_source, "MOUSE_FILTER_IGNORE")
	assert_contains(card_source, "_gui_input")
	assert_contains(drop_source, "_can_drop_data")
	assert_contains(drop_source, "_drop_data")


func test_gameplay_menus_do_not_use_scroll_containers() -> void:
	for path in [
		"res://scripts/ui/inventory_screen.gd",
		"res://scripts/ui/level_screen.gd",
		"res://scripts/ui/crafting_screen.gd",
		"res://scripts/ui/admin_item_screen.gd",
		"res://scripts/ui/trader_screen.gd",
		"res://scripts/ui/settings_menu.gd",
		"res://scripts/base/build_menu.gd",
		"res://scripts/world_map/world_map.gd",
		"res://scripts/combat/combat_scene.gd"
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("ScrollContainer.new()"), "%s should not create scroll containers" % path)


func test_admin_menu_uses_f6_hotkey() -> void:
	var gameplay_source := FileAccess.get_file_as_string("res://scripts/ui/gameplay_screen.gd")
	var admin_source := FileAccess.get_file_as_string("res://scripts/ui/admin_item_screen.gd")
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	assert_contains(gameplay_source, "MENU_RETURN_SCENES")
	assert_contains(gameplay_source, "admin_item_screen.tscn")
	assert_contains(gameplay_source, "return_to_previous")
	assert_contains(gameplay_source, "KEY_F6")
	assert_contains(gameplay_source, "OS.is_debug_build()")
	assert_contains(admin_source, "KEY_F6")
	assert_contains(admin_source, "ui_cancel")
	assert_contains(admin_source, "func _input")
	assert_contains(admin_source, "func _unhandled_input")
	assert_contains(admin_source, "Esc oder F6 schliesst")
	assert_contains(admin_source, "menu_panel_style")
	assert_contains(admin_source, "ornate_muted_label")
	assert_contains(admin_source, "Zurück")
	assert_contains(admin_source, "UiFactory.line_edit")
	assert_contains(admin_source, "_matching_items")
	assert_contains(admin_source, "ADMIN_ITEMS_PER_PAGE")
	assert_contains(admin_source, "DataCatalog.all_admin_items()")
	assert_contains(admin_source, "TAB_GROUPS")
	assert_contains(admin_source, "reload_all")
	assert_contains(admin_source, "scroll_wrap_fill")
	assert_contains(hud_source, "Inventar (I)")
	assert_false(gameplay_source.contains("KEY_F8"))


func test_level_menu_and_updated_hotkeys() -> void:
	var gameplay_source := FileAccess.get_file_as_string("res://scripts/ui/gameplay_screen.gd")
	var crafting_source := FileAccess.get_file_as_string("res://scripts/ui/crafting_screen.gd")
	var level_source := FileAccess.get_file_as_string("res://scripts/ui/level_screen.gd")
	var settings_source := FileAccess.get_file_as_string("res://scripts/ui/settings_menu.gd")
	assert_contains(gameplay_source, "KEY_B")
	assert_contains(gameplay_source, "KEY_K")
	assert_contains(gameplay_source, "open_level")
	assert_contains(crafting_source, "KEY_B")
	assert_false(crafting_source.contains("KEY_K"))
	assert_contains(crafting_source, "has_craft_materials")
	assert_contains(crafting_source, "take_craft_materials")
	assert_contains(crafting_source, "crafting_uses_storage")
	assert_contains(crafting_source, "SORT_NAME_ASC")
	assert_contains(crafting_source, "REZEPTE")
	assert_contains(crafting_source, "RUCKSACK")
	assert_contains(crafting_source, "LAGER")
	assert_contains(crafting_source, "TAB_ALL")
	assert_contains(crafting_source, "TabBar")
	assert_contains(crafting_source, "Alles")
	assert_contains(crafting_source, "Ausruestung")
	assert_contains(crafting_source, "_craft_tab_for_item")
	assert_contains(level_source, "Faehigkeitenleiste 1-9")
	assert_contains(level_source, "ability_unlock_level")
	assert_contains(level_source, "set_ability_slot")
	assert_contains(level_source, "AbilityDragButtonScript")
	assert_contains(level_source, "AbilityHotbarButtonScript")
	assert_contains(level_source, "AbilityTreeOverlayScript")
	assert_contains(level_source, "Faehigkeitsbaum")
	assert_contains(level_source, "Ausgewaehlte Faehigkeit")
	assert_contains(level_source, "TabContainer.new()")
	assert_contains(level_source, "_sync_tab_pages")
	assert_contains(level_source, "_compact_panel_style")
	assert_contains(level_source, "ability_detail_label")
	assert_contains(level_source, "preview_ability_id")
	assert_contains(level_source, "_preview_ability")
	assert_contains(level_source, "_ability_dropped_on_slot")
	assert_contains(level_source, "MOUSE_BUTTON_RIGHT")
	var tree_source := FileAccess.get_file_as_string("res://scripts/ui/ability_tree_overlay.gd")
	assert_contains(tree_source, "_refresh_compact_tree")
	assert_contains(tree_source, "_add_compact_ability_node")
	assert_contains(settings_source, "Allgemein")
	assert_contains(settings_source, "should_confirm_skip_turn_with_ap")
	assert_contains(settings_source, "DisplayManager")
	assert_contains(settings_source, "_make_tab_container")
	assert_contains(settings_source, "embedded_mode")
	assert_contains(settings_source, "Automatisch erkennen")


func test_player_appearance_templates_load_and_persist() -> void:
	var appearance_ids := ["priest", "mechanic", "mara_hollow", "guardian"]
	for gender in ["female", "male"]:
		for appearance_id in appearance_ids:
			match appearance_id:
				"priest":
					assert_true(FileAccess.file_exists("res://assets/characters/priest/idle/showcase_atlas.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/priest/idle/combat_atlas.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/priest/idle/portrait.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/priest/hit/showcase_atlas.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/priest/hit/combat_atlas.png"))
				"mara_hollow":
					assert_true(FileAccess.file_exists("res://assets/characters/mara_hollow/idle/showcase_atlas.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/mara_hollow/idle/combat_atlas.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/mara_hollow/idle/portrait.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/mara_hollow/hit/showcase_atlas.png"))
					assert_true(FileAccess.file_exists("res://assets/characters/mara_hollow/hit/combat_atlas.png"))
				_:
					assert_true(
						FileAccess.file_exists(
							"res://assets/characters/player_variants/%s_%s.png" % [gender, appearance_id]
						)
					)
					assert_true(
						FileAccess.file_exists(
							"res://assets/characters/player_variants/combat/%s_%s.png" % [gender, appearance_id]
						)
					)
					assert_true(
						FileAccess.file_exists(
							"res://assets/characters/player_variants/portraits/%s_%s.png" % [gender, appearance_id]
						)
					)
	var source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	assert_contains(source, "player_appearance")
	assert_contains(source, "player_appearance_path")
	assert_contains(source, "player_appearance_portrait_path")
	assert_contains(source, "appearance_uses_idle_animation")
	assert_contains(source, "appearance_has_hit_animation")
	assert_contains(source, "appearance_for_class")
	assert_contains(source, "PriestIdleFrames")
	assert_contains(source, "Priest")
	assert_contains(source, "CharacterVisualContext")
	var visual_source := FileAccess.get_file_as_string("res://scripts/characters/player_character_visual.gd")
	assert_contains(visual_source, "play_hit")
	assert_contains(visual_source, "PriestHitFrames")
	assert_contains(visual_source, "priest")
	assert_contains(source, "Dr. Mara Hollow")
	assert_contains(visual_source, "is_playing_hit")
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat/combat_scene.gd")
	assert_contains(combat_source, "_try_play_hit_animation")
	assert_eq(MaraHollowIdleFramesScript.FRAME_COUNT, 98)
	assert_eq(MaraHollowHitFramesScript.FRAME_COUNT, 98)
	assert_eq(MaraHollowHitFramesScript.ANIMATION_FPS, 24.0)
	assert_eq(GameState.appearance_for_class("medic"), "mara_hollow")
	assert_eq(GameState.appearance_for_class("scout"), "priest")
	assert_eq(PriestIdleFramesScript.FRAME_COUNT, 98)
	assert_eq(PriestHitFramesScript.FRAME_COUNT, 98)
	assert_eq(PriestHitFramesScript.ANIMATION_FPS, 24.0)


func test_main_menu_has_apocalyptic_animation() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main_menu/main_menu.gd")
	var audio_source := FileAccess.get_file_as_string("res://autoload/audio_manager.gd")
	assert_contains(source, "play_menu_ambience()")
	assert_contains(source, "main_menu_bunker.png")
	assert_false(source.contains("ScrollContainer.new()"))
	assert_contains(source, "_build_center_menu")
	assert_contains(source, "menu_root")
	assert_contains(source, "WEITERSPIELEN")
	assert_contains(source, "NEUES SPIEL")
	assert_contains(source, "SPIEL LADEN")
	assert_contains(source, "EINSTELLUNGEN")
	assert_contains(source, "BEENDEN")
	assert_contains(source, "_show_load_menu")
	assert_contains(source, "_load_save_slot")
	assert_contains(source, "_open_settings")
	assert_contains(source, "embedded_mode = true")
	assert_contains(source, "_spawn_rain")
	assert_contains(source, "_spawn_ash")
	assert_contains(source, "_spawn_smoke")
	assert_contains(source, "_trigger_lightning")
	assert_contains(source, "horror_tint")
	assert_contains(source, "vignette_shade")
	assert_contains(source, "thunder.wav")
	assert_true(FileAccess.file_exists("res://assets/environments/backgrounds/main_menu_bunker.png"))
	assert_contains(audio_source, "play_menu_ambience")
	assert_contains(audio_source, "horror_ambience.wav")
	assert_contains(audio_source, "below_the_walls.wav")
	assert_contains(audio_source, "play_button_click")
	assert_contains(audio_source, "rain_loop.wav")
	assert_contains(audio_source, "distant_scream.wav")


func test_recipes_and_locations_include_new_equipment() -> void:
	var recipes := _entries("res://data/crafting/recipes.tres")
	var locations := _entries("res://data/world/locations.tres")
	var accessories := _entries("res://data/items/accessories.tres")
	assert_has_key(recipes, "work_boots")
	assert_has_key(recipes, "scrap_helmet")
	assert_has_key(recipes, "fire_axe")
	assert_has_key(recipes, "wire_ring")
	assert_has_key(recipes, "leather_belt")
	assert_has_key(recipes, "salt_amulet")
	assert_has_key(recipes, "scrap_shield")
	assert_has_key(recipes, "reinforced_shield")
	assert_has_key(accessories, "wire_ring")
	assert_has_key(accessories, "leather_belt")
	assert_has_key(accessories, "salt_amulet")
	assert_eq(accessories.wire_ring.get("equip_slot", ""), "ring")
	assert_eq(accessories.leather_belt.get("equip_slot", ""), "belt")
	assert_eq(accessories.salt_amulet.get("equip_slot", ""), "amulet")
	assert_true(FileAccess.file_exists(str(accessories.signet_ring.get("icon", ""))))
	assert_contains(locations.factory.loot, "fire_axe")
	assert_contains(locations.military.loot, "scrap_helmet")
	assert_contains(locations.ruined_town.loot, "patched_jacket")
	assert_contains(locations.chapel.loot, "salt_amulet")
	assert_contains(locations.cathedral_gate.loot, "signet_ring")
	assert_contains(locations.military.loot, "scrap_shield")


func _all_items() -> Dictionary:
	var items := {}
	for path in [
		"res://data/items/weapons_melee.tres",
		"res://data/items/weapons_ranged.tres",
		"res://data/items/ammo.tres",
		"res://data/items/food.tres",
		"res://data/items/drinks.tres",
		"res://data/items/medical.tres",
		"res://data/items/armor.tres",
		"res://data/items/backpacks.tres",
		"res://data/items/materials.tres",
		"res://data/items/misc.tres",
		"res://data/items/accessories.tres"
	]:
		items.merge(_entries(path), true)
	return items


func test_catalog_cross_references_resolve() -> void:
	var items := _all_items()
	var missing: Array[String] = []
	for recipe_id in _entries("res://data/crafting/recipes.tres"):
		var recipe: Dictionary = _entries("res://data/crafting/recipes.tres")[recipe_id]
		for item_id in recipe.get("inputs", {}):
			if not items.has(str(item_id)):
				missing.append("recipe:%s input:%s" % [recipe_id, item_id])
		var output := str(recipe.get("output", ""))
		if not output.is_empty() and not items.has(output):
			missing.append("recipe:%s output:%s" % [recipe_id, output])
	for location_id in _entries("res://data/world/locations.tres"):
		var location: Dictionary = _entries("res://data/world/locations.tres")[location_id]
		for item_id in location.get("loot", []):
			if not items.has(str(item_id)):
				missing.append("location:%s loot:%s" % [location_id, item_id])
	for enemy_id in _entries("res://data/enemies/enemy_stats.tres"):
		var enemy: Dictionary = _entries("res://data/enemies/enemy_stats.tres")[enemy_id]
		for item_id in enemy.get("loot", []):
			if not items.has(str(item_id)):
				missing.append("enemy:%s loot:%s" % [enemy_id, item_id])
	for item_id in items:
		var icon := str(items[item_id].get("icon", ""))
		if icon.begins_with("res://") and not FileAccess.file_exists(icon):
			missing.append("item:%s icon:%s" % [item_id, icon])
	assert_eq(missing.size(), 0, "Missing catalog references: %s" % ", ".join(missing))


func test_world_map_nodes_match_locations() -> void:
	var locations := _entries("res://data/world/locations.tres")
	var source := FileAccess.get_file_as_string("res://scripts/world_map/world_map.gd")
	var missing: Array[String] = []
	for location_id in locations:
		if not source.contains('"%s":' % location_id):
			missing.append(location_id)
	assert_eq(missing.size(), 0, "MAP_NODES missing locations: %s" % ", ".join(missing))


func test_story_sequences_and_scenes_exist() -> void:
	var story_source := FileAccess.get_file_as_string("res://scripts/cinematics/story_slide.gd")
	assert_contains(story_source, "KEY_SPACE")
	assert_contains(story_source, "Leertaste")
	assert_contains(story_source, "STRETCH_KEEP_ASPECT_COVERED")
	var stories := _entries("res://data/story/story_slides.tres")
	for story_id in ["prologue", "act_2", "act_3", "finale", "game_over"]:
		assert_has_key(stories, story_id)
		assert_gt(stories[story_id].get("slides", []).size(), 0)
	for path in [
		"res://scenes/cinematics/story_slide.tscn",
		"res://scenes/exploration/exploration_scene.tscn",
		"res://scenes/characters/elena.tscn",
		"res://scenes/ui/inventory_screen.tscn",
		"res://scenes/ui/crafting_screen.tscn",
		"res://scenes/ui/settings_menu.tscn"
	]:
		assert_ne(load(path), null, "%s should load" % path)
	assert_ne(load("res://scripts/ui/inventory_screen.gd"), null)


func test_equipment_slots_have_valid_items_or_crafting() -> void:
	var items := _all_items()
	for slot in ["ring", "belt", "amulet", "shield"]:
		var found := false
		for item_id in items:
			if str(items[item_id].get("equip_slot", "")) == slot:
				found = true
				break
		assert_true(found, "No item for equipment slot %s" % slot)


func test_ornate_ui_frame_theme() -> void:
	var theme_source := FileAccess.get_file_as_string("res://ui/themes/dark_theme.tres")
	var ornate_source := FileAccess.get_file_as_string("res://scripts/ui/ornate_ui_styles.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	assert_contains(theme_source, "StyleBoxTexture")
	assert_contains(theme_source, "ornate_frame.png")
	assert_contains(ornate_source, "frame_style")
	assert_contains(project_source, "theme/custom")
	assert_true(FileAccess.file_exists("res://assets/ui/frames/ornate_frame.png"))


func test_weapon_slots_separate_ranged_and_melee() -> void:
	var inventory_source := FileAccess.get_file_as_string("res://autoload/inventory_system.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_screen.gd")
	assert_contains(inventory_source, "is_ranged_weapon_item")
	assert_contains(inventory_source, "is_melee_weapon_item")
	assert_contains(inventory_source, "item_fits_equipment_slot")
	assert_contains(screen_source, "Fernkampf")
	assert_contains(screen_source, "Nahkampf")
	InventorySystem.reset_inventory({"machete": 1, "old_revolver": 1})
	assert_true(InventorySystem.equip_item("machete"))
	assert_true(InventorySystem.equip_item("old_revolver"))
	assert_eq(InventorySystem.equipped_item("melee"), "machete")
	assert_eq(InventorySystem.equipped_item("firearm"), "old_revolver")
	assert_false(InventorySystem.item_fits_equipment_slot("machete", "firearm"))
	assert_false(InventorySystem.item_fits_equipment_slot("old_revolver", "melee"))


func test_two_handed_weapons_block_shield_and_dual_wield() -> void:
	var melee := _entries("res://data/items/weapons_melee.tres")
	var ranged := _entries("res://data/items/weapons_ranged.tres")
	assert_true(bool(melee.scrap_greatsword.get("two_handed", false)))
	assert_true(bool(melee.war_axe.get("two_handed", false)))
	assert_true(bool(ranged.heavy_crossbow.get("two_handed", false)))
	assert_eq(str(melee.scrap_greatsword.get("equip_slot", "")), "melee")
	assert_eq(str(ranged.heavy_crossbow.get("equip_slot", "")), "firearm")
	assert_gt(float(melee.scrap_greatsword.get("damage", 0.0)), float(melee.machete.get("damage", 0.0)))
	InventorySystem.reset_inventory({"scrap_greatsword": 1, "scrap_shield": 1, "old_revolver": 1})
	assert_true(InventorySystem.equip_item("scrap_greatsword"))
	assert_true(InventorySystem.is_slot_blocked("shield"))
	assert_true(InventorySystem.is_slot_blocked("firearm"))
	assert_false(InventorySystem.is_slot_blocked("melee"))
	assert_false(InventorySystem.equip_item("scrap_shield"))
	assert_false(InventorySystem.equip_item("old_revolver"))
	assert_eq(InventorySystem.equipped_item("melee"), "scrap_greatsword")


func test_bunker_base_rooms_unlock_and_surface_defense() -> void:
	var rooms := _entries("res://data/building/base_rooms.tres")
	var structures := _entries("res://data/building/structures.tres")
	assert_has_key(rooms, "shaft_room")
	assert_has_key(rooms, "workshop")
	assert_has_key(rooms, "surface_west_tower")
	assert_true(bool(rooms.shaft_room.get("starts_unlocked", false)))
	assert_false(bool(rooms.workshop.get("starts_unlocked", false)))
	assert_eq(rooms.surface_west_tower.get("zone", ""), "surface")
	assert_gt(float(structures.watchtower.get("surface_damage", 0.0)), 0.0)
	var game_state_source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	var defense_source := FileAccess.get_file_as_string("res://scripts/base/defense_wave.gd")
	assert_contains(game_state_source, "unlock_room")
	assert_contains(game_state_source, "place_surface_defense")
	assert_contains(game_state_source, "surface_defense_damage")
	assert_contains(game_state_source, "elena_allowed_rooms")
	assert_contains(game_state_source, "module_health")
	assert_contains(game_state_source, "damage_module")
	assert_contains(game_state_source, "apply_placement_wave_damage")
	var fortress_source := FileAccess.get_file_as_string("res://scripts/base/base_fortress_3d.gd")
	var fortress_view_source := FileAccess.get_file_as_string("res://scripts/base/base_fortress_view.gd")
	var module_source := FileAccess.get_file_as_string("res://scripts/base/destructible_module.gd")
	assert_contains(fortress_source, "BaseFortress3D")
	assert_contains(fortress_source, "DestructibleModule")
	assert_contains(fortress_source, "_refresh_surface_placements")
	assert_contains(fortress_source, "_register_door")
	assert_contains(fortress_view_source, "BaseVisual")
	assert_contains(fortress_view_source, "BaseStructureOverlay")
	assert_contains(fortress_view_source, "room_selected")
	assert_contains(fortress_view_source, "surface_selected")
	assert_contains(module_source, "apply_damage")
	assert_contains(defense_source, "surface_defense_damage")
	assert_true(FileAccess.file_exists("res://scenes/base/base_fortress_3d.tscn"))


func test_hud_shows_dawn_credits() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	assert_contains(hud_source, "Dawn-Credits")
	assert_contains(hud_source, "InventorySystem.money")


func test_audio_manager_scene_music_and_coin_sfx() -> void:
	var source := FileAccess.get_file_as_string("res://autoload/audio_manager.gd")
	assert_contains(source, "play_scene_music")
	assert_contains(source, "play_coin_sfx")
	assert_contains(source, "play_trade_sfx")
	assert_contains(source, "play_button_click")
	assert_contains(source, "MUSIC_MENU")
	assert_contains(source, "_exploration_music")
	assert_true(FileAccess.file_exists("res://assets/audio/sfx/ui/coin.wav"))


func test_rest_for_hours_scales_recovery() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	var rest_source := FileAccess.get_file_as_string("res://scripts/world_map/rest_camp_scene.gd")
	assert_contains(game_state_source, "rest_for_hours")
	assert_contains(game_state_source, "REST_MAX_HOURS")
	assert_contains(game_state_source, "_stat_maximum")
	assert_contains(rest_source, "CampfireButton")
	assert_contains(rest_source, "_make_hour_button")
	assert_contains(rest_source, "advance_rest")
	assert_true(FileAccess.file_exists("res://assets/environments/backgrounds/rest_camp_painted.jpg"))
	GameState.new_game("scout")
	GameState.player_stats.stamina = 25.0
	GameState.player_stats.energy = 30.0
	GameState.player_stats.health = 40.0
	var gains := GameState.rest_for_hours(4)
	assert_true(float(gains.stamina) > 0.0)
	assert_true(float(GameState.player_stats.stamina) > 25.0)


func test_map_and_travel_events_exist() -> void:
	var map_events := _entries("res://data/world/map_events.tres")
	var travel_events := _entries("res://data/world/travel_events.tres")
	assert_has_key(map_events, "harbor_pier")
	assert_has_key(map_events, "grave_crossroads")
	assert_has_key(travel_events, "roadside_cache")
	assert_has_key(travel_events, "lost_refugee")
	var catalog_source := FileAccess.get_file_as_string("res://autoload/data_catalog.gd")
	assert_contains(catalog_source, "map_event")
	assert_contains(catalog_source, "random_travel_event")
	var world_source := FileAccess.get_file_as_string("res://scripts/world_map/world_map.gd")
	assert_contains(world_source, "_start_map_event")
	assert_contains(world_source, "_pick_event_choice")
	assert_contains(world_source, "_try_random_travel_event")
	assert_contains(FileAccess.get_file_as_string("res://scripts/ui/trader_screen.gd"), "play_trade_sfx")


func test_scripts_and_scenes_load() -> void:
	for path in [
		"res://autoload/game_state.gd",
		"res://autoload/rpg_rules.gd",
		"res://autoload/inventory_system.gd",
		"res://scripts/main_menu/main_menu.gd",
		"res://scripts/world_map/map_path_layer.gd",
		"res://scripts/ui/clock_face.gd",
		"res://scripts/ui/inventory_screen.gd",
		"res://scripts/ui/ability_drag_button.gd",
		"res://scripts/ui/ability_hotbar_button.gd",
		"res://scripts/ui/ability_tree_overlay.gd",
		"res://scripts/ui/admin_item_screen.gd",
		"res://scripts/ui/trader_screen.gd",
		"res://scripts/ui/trade_item_card.gd",
		"res://scripts/ui/trade_drop_zone.gd",
		"res://scripts/base/base_scene.gd",
		"res://scripts/base/base_fortress_3d.gd",
		"res://scripts/base/base_fortress_view.gd",
		"res://scripts/base/base_visual.gd",
		"res://scripts/base/base_structure_overlay.gd",
		"res://scripts/base/destructible_module.gd",
		"res://scripts/base/destructible_door.gd",
		"res://scripts/base/base_camera_rig.gd",
		"res://scripts/base/structure_visual_factory.gd",
		"res://scripts/base/modular_piece_factory.gd",
		"res://scripts/base/defense_wave.gd",
		"res://scripts/combat/combat_scene.gd",
		"res://scripts/exploration/exploration_scene.gd",
		"res://data/items/accessories.tres",
		"res://data/world/map_events.tres",
		"res://data/world/travel_events.tres",
		"res://scenes/main_menu/main_menu.tscn",
		"res://scenes/world_map/world_map.tscn",
		"res://scenes/world_map/rest_camp_scene.tscn",
		"res://scenes/ui/level_screen.tscn",
		"res://scenes/ui/admin_item_screen.tscn",
		"res://scenes/ui/trader_screen.tscn",
		"res://scenes/base/base_scene.tscn",
		"res://scenes/base/base_fortress_3d.tscn",
		"res://scenes/base/defense_wave.tscn",
		"res://scenes/combat/combat_scene.tscn",
		"res://autoload/item_drag_drop.gd",
		"res://scripts/exploration/loot_popup.gd",
		"res://scenes/base/build_menu.tscn",
		"res://scenes/ui/crafting_screen.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/dialogue_box.tscn",
		"res://scenes/ui/inventory_screen.tscn",
		"res://scenes/exploration/exploration_scene.tscn",
		"res://scenes/exploration/lootable_container.tscn",
		"res://scenes/characters/elena.tscn",
		"res://scenes/characters/player.tscn",
		"res://scenes/characters/survivor_npc.tscn",
		"res://scenes/cinematics/story_slide.tscn"
	]:
		assert_ne(load(path), null, "%s should load" % path)


func test_item_drag_drop_runtime() -> void:
	var drag_drop_source := FileAccess.get_file_as_string("res://autoload/item_drag_drop.gd")
	assert_contains(drag_drop_source, "func make_payload")
	assert_contains(drag_drop_source, "func apply_drop")
	assert_contains(drag_drop_source, "source_key: String, target_slot: String")
	assert_contains(drag_drop_source, "func _assign_quick_from_source(item_id: String, source: String, source_key: String, index: int)")
	assert_contains(drag_drop_source, "enemy_loot")
	assert_contains(drag_drop_source, "loot_backpack")
	assert_contains(drag_drop_source, "\"player\"")
	assert_contains(drag_drop_source, "_take_transient_loot")
	var slot_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_slot.gd")
	assert_contains(slot_source, "ItemDragDrop.make_payload")
	assert_contains(slot_source, "ItemDragDrop.is_item_payload")


func test_save_resume_and_event_damage_rules() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	var save_source := FileAccess.get_file_as_string("res://autoload/save_system.gd")
	var world_source := FileAccess.get_file_as_string("res://scripts/world_map/world_map.gd")
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat/combat_scene.gd")
	var exploration_source := FileAccess.get_file_as_string("res://scripts/exploration/exploration_scene.gd")
	var time_source := FileAccess.get_file_as_string("res://autoload/time_system.gd")
	assert_contains(game_state_source, "resume_scene_after_load")
	assert_contains(game_state_source, "pending_map_event_data")
	assert_contains(save_source, "save_autosave")
	assert_contains(save_source, "AUTOSAVE_PATH")
	assert_contains(world_source, "GameState.change_stat(\"health\", -amount)")
	assert_contains(world_source, "_restore_pending_map_event")
	assert_contains(combat_source, "framed_column")
	assert_contains(combat_source, "ornate_heading")
	assert_contains(combat_source, "KAMPFLOG")
	assert_contains(combat_source, "CombatUiStyles")
	assert_contains(combat_source, "inventory_button")
	assert_contains(combat_source, "open_inventory")
	assert_contains(combat_source, "_combat_layout_metrics")
	assert_contains(exploration_source, "EnemySpawnService")
	assert_contains(exploration_source, "LayoutGenerator")
	assert_contains(time_source, "SaveSystem.save_autosave()")
	assert_contains(save_source, "load_autosave")
	assert_contains(save_source, "load_latest_save")
	assert_contains(save_source, "latest_save_info")
	assert_contains(save_source, "any_save_exists")
	assert_contains(save_source, "autosave_info")
	assert_contains(FileAccess.get_file_as_string("res://scripts/main_menu/main_menu.gd"), "_continue_autosave")
	assert_contains(FileAccess.get_file_as_string("res://scripts/main_menu/main_menu.gd"), "load_latest_save")
	assert_contains(FileAccess.get_file_as_string("res://scripts/main_menu/main_menu.gd"), "_load_save_slot")
	assert_contains(FileAccess.get_file_as_string("res://scripts/ui/settings_menu.gd"), "resume_scene_after_load")


func test_weapon_tilemap_dev_setup_exists() -> void:
	var bake_source := FileAccess.get_file_as_string("res://scripts/dev/weapon_tileset_bake.gd")
	var editor_source := FileAccess.get_file_as_string("res://scripts/dev/weapon_tilemap_editor.gd")
	var defs_source := FileAccess.get_file_as_string("res://scripts/dev/weapon_sheet_definitions.gd")
	assert_contains(bake_source, "weapon_tileset.tres")
	assert_contains(bake_source, "item_id")
	assert_contains(bake_source, "WEAPON_ENTRIES")
	assert_contains(bake_source, "dd_halberd")
	assert_contains(editor_source, "WeaponCatalog")
	assert_contains(editor_source, "WeaponLayout")
	assert_contains(editor_source, "slice_icons_now")
	assert_contains(defs_source, "darkest_dungeon_weapons_sheet.png")
	assert_true(FileAccess.file_exists("res://scenes/dev/weapon_tilemap_editor.tscn"))
	assert_true(FileAccess.file_exists("res://assets/tilesets/source/darkest_dungeon_weapons_sheet.png"))
	assert_true(FileAccess.file_exists("res://assets/items/weapons/melee/dd_skull_dagger.png"))
	assert_ne(load("res://scripts/dev/weapon_tileset_bake.gd"), null)
	assert_ne(load("res://resources/tilesets/weapon_tileset.tres"), null)


func test_dd_sheet_weapons_catalog_and_damage() -> void:
	var dd := _entries("res://data/items/weapons_dd_sheet.tres")
	assert_has_key(dd, "dd_halberd")
	assert_eq(int(dd.dd_halberd.get("damage", 0)), 26)
	assert_eq(str(dd.dd_halberd.get("weapon_type", "")), "melee")
	assert_eq(str(dd.dd_combat_rifle.get("weapon_type", "")), "burst")
	assert_eq(int(dd.dd_stick_grenade.get("damage", 0)), 36)
	assert_true(FileAccess.file_exists(str(dd.dd_hunter_bow.get("icon", ""))))
	var admin_source := FileAccess.get_file_as_string("res://scripts/ui/admin_item_screen.gd")
	assert_contains(admin_source, "TAB_GROUPS")
	assert_contains(admin_source, "\"Waffen\"")
	assert_contains(admin_source, "godmode_checkbox")
	assert_contains(admin_source, "is_admin_godmode")
	assert_contains(FileAccess.get_file_as_string("res://scripts/world_map/world_map.gd"), "_teleport_to_node")


func test_all_scenes_instantiate() -> void:
	for path in [
		"res://scenes/main_menu/main_menu.tscn",
		"res://scenes/world_map/world_map.tscn",
		"res://scenes/world_map/rest_camp_scene.tscn",
		"res://scenes/base/base_scene.tscn",
		"res://scenes/base/build_menu.tscn",
		"res://scenes/base/defense_wave.tscn",
		"res://scenes/base/base_fortress_3d.tscn",
		"res://scenes/ui/crafting_screen.tscn",
		"res://scenes/ui/inventory_screen.tscn",
		"res://scenes/ui/level_screen.tscn",
		"res://scenes/ui/trader_screen.tscn",
		"res://scenes/ui/tavern_screen.tscn",
		"res://scenes/ui/admin_item_screen.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/dialogue_box.tscn",
		"res://scenes/combat/combat_scene.tscn",
		"res://scenes/exploration/exploration_scene.tscn",
		"res://scenes/cinematics/story_slide.tscn",
		"res://scenes/characters/elena.tscn",
		"res://scenes/characters/player.tscn",
		"res://scenes/characters/survivor_npc.tscn",
		"res://scenes/exploration/loot_popup.tscn",
		"res://scenes/exploration/lootable_container.tscn",
		"res://scenes/dev/weapon_tilemap_editor.tscn",
	]:
		var packed: PackedScene = load(path) as PackedScene
		assert_ne(packed, null, "%s should load as PackedScene" % path)
		var node: Node = packed.instantiate()
		assert_ne(node, null, "%s should instantiate" % path)
		node.free()


func test_combat_simulations_solo_and_companion() -> void:
	var logic := load("res://scripts/combat/combat_turn_logic.gd")
	assert_ne(logic, null)
	assert_ne(load("res://scripts/combat/combat_scene.gd"), null)
	var solo := TurnLogic.build_turn_order(
		false,
		false,
		{"initiative": 10.0},
		{},
		{"initiative": 5.0, "speed": 2}
	)
	assert_eq(solo.turn_order.size(), 2)
	assert_true(solo.turn_order.has("player"))
	assert_true(solo.turn_order.has("enemy"))
	var team := TurnLogic.build_turn_order(
		true,
		true,
		{"initiative": 10.0},
		{"initiative": 8.0},
		{"initiative": 5.0, "speed": 2}
	)
	assert_eq(team.turn_order.size(), 3)
	assert_true(team.turn_order.has("companion"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var solo_fight := TurnLogic.simulate_fight({
		"seed": 42,
		"has_companion": false,
		"player_hp": 100.0,
		"enemy_hp": 30.0,
		"player_damage": 10.0,
		"enemy_damage": 5.0,
	})
	assert_true(solo_fight.victory)
	assert_gt(int(solo_fight.actions), 0)
	assert_true(float(solo_fight.player_hp) <= 100.0)
	var team_fight := TurnLogic.simulate_fight({
		"seed": 77,
		"has_companion": true,
		"player_hp": 100.0,
		"companion_hp": 80.0,
		"enemy_hp": 60.0,
		"player_damage": 9.0,
		"companion_damage": 7.0,
		"enemy_damage": 6.0,
	})
	assert_true(team_fight.victory)
	assert_true(team_fight.log.has("companion_attack"))
	var dead_companion := TurnLogic.next_actor(
		["player", "companion", "enemy"],
		0,
		true,
		0.0
	)
	assert_eq(str(dead_companion.actor_id), "enemy")
	GameState.recruit_companion("medic")
	assert_true(GameState.has_companion())
	var first_name := str(GameState.companion.get("name", ""))
	GameState.recruit_companion("guardian")
	assert_true(GameState.has_companion())
	assert_ne(str(GameState.companion.get("name", "")), first_name)
	assert_eq(str(GameState.companion.get("class_id", "")), "guardian")
	GameState.dismiss_companion()


func test_initiative_and_companion_systems() -> void:
	var rules_source := FileAccess.get_file_as_string("res://autoload/rpg_rules.gd")
	var game_state_source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat/combat_scene.gd")
	assert_contains(rules_source, "initiative")
	assert_contains(game_state_source, "recruit_companion")
	assert_contains(game_state_source, "available_companion_classes")
	assert_contains(combat_source, "_build_turn_order")
	assert_contains(combat_source, "TurnLogic")
	assert_contains(combat_source, "_refresh_turn_order_strip")
	assert_contains(combat_source, "_ui_actor_id")
	assert_contains(game_state_source, "\"initiative\"")


func test_procedural_exploration_and_enemy_spawn() -> void:
	var layout := load("res://scripts/world/exploration_layout_generator.gd")
	var spawn := load("res://scripts/world/enemy_spawn_service.gd")
	assert_ne(layout, null)
	assert_ne(spawn, null)
	var generated: Dictionary = layout.generate("ruined_town", 2, 12345)
	assert_has_key(generated, "start")
	assert_has_key(generated, "combat")
	var location := {"danger": 2, "type": "Zone"}
	var enemy_id: String = spawn.pick_enemy(location, 3, 99)
	assert_true(enemy_id.begins_with("demon_"))


func test_display_manager_resolution_and_monitor_settings() -> void:
	var display_source := FileAccess.get_file_as_string("res://autoload/display_manager.gd")
	var settings_source := FileAccess.get_file_as_string("res://scripts/ui/settings_menu.gd")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/ui_factory.gd")
	var event_source := FileAccess.get_file_as_string("res://autoload/event_bus.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	assert_ne(load("res://autoload/display_manager.gd"), null)
	assert_contains(project_source, "DisplayManager=")
	assert_contains(display_source, "auto_detect")
	assert_contains(display_source, "apply_settings")
	assert_contains(display_source, "get_screen_count")
	assert_contains(display_source, "get_available_resolutions")
	assert_contains(display_source, "window_mode")
	assert_contains(display_source, "RESOLUTION_PRESETS")
	assert_contains(display_source, "Window.MODE_WINDOWED")
	assert_contains(settings_source, "Monitor")
	assert_contains(settings_source, "Aufloesung")
	assert_contains(settings_source, "Fenstermodus")
	assert_false(settings_source.contains("scroll_wrap"))
	assert_contains(ui_source, "design_size")
	assert_contains(event_source, "display_settings_changed")
	var display_script: Script = DisplayManagerScript
	assert_ne(display_script, null)
	var display_probe: Node = display_script.new()
	assert_eq(display_probe.snap_resolution(Vector2i(1919, 1079)), Vector2i(1918, 1078))
	display_probe.window_mode = 2
	display_probe.set_resolution(Vector2i(1280, 720), false)
	assert_eq(int(display_probe.window_mode), 0)
	var presets: Array[Vector2i] = display_probe.get_available_resolutions(0)
	assert_gt(presets.size(), 0)
	display_probe.free()

