@tool
extends "res://addons/godot_ai/testing/test_suite.gd"


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
	var exploration_source := FileAccess.get_file_as_string("res://scripts/exploration/exploration_scene.gd")
	assert_contains(exploration_source, "MOVE_POINTS_PER_ROUND := 6")
	assert_contains(exploration_source, "ACTION_POINTS_PER_ROUND := 2")
	assert_contains(exploration_source, "KEY_W")
	assert_contains(exploration_source, "KEY_A")
	assert_contains(exploration_source, "KEY_S")
	assert_contains(exploration_source, "KEY_D")


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
	assert_contains(loot_popup_source, "Leerer Behaelter")
	assert_contains(loot_popup_source, "Schliessen")


func test_inventory_uses_backpack_and_clothing_containers() -> void:
	var inventory_source := FileAccess.get_file_as_string("res://autoload/inventory_system.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_screen.gd")
	var equipment_source := FileAccess.get_file_as_string("res://scripts/ui/equipment_screen.gd")
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
	assert_contains(screen_source, "RUCKSACK")
	assert_contains(screen_source, "LAGER")
	assert_contains(screen_source, "SCHNELLZUGRIFF")
	assert_contains(screen_source, "_refresh_actions")
	assert_contains(screen_source, "Entsorgen")
	assert_contains(screen_source, "_slot_preview_text")
	assert_contains(screen_source, "AUSRUESTUNG")
	assert_contains(screen_source, "Helm")
	assert_contains(screen_source, "Brust")
	assert_contains(screen_source, "Beine")
	assert_contains(screen_source, "Stiefel")
	assert_contains(screen_source, "Ring")
	assert_contains(screen_source, "Guertel")
	assert_contains(screen_source, "Amulett")
	assert_contains(inventory_source, "\"shield\"")
	assert_contains(inventory_source, "\"ring\"")
	assert_contains(inventory_source, "\"belt\"")
	assert_contains(inventory_source, "\"amulet\"")
	assert_contains(screen_source, "Shift + Rechtsklick")
	assert_contains(screen_source, "Strg + Rechtsklick")
	assert_contains(screen_source, "KEY_ESCAPE")
	assert_contains(screen_source, "extends Control")
	assert_contains(screen_source, "CenterContainer")
	assert_contains(screen_source, "queue_free")
	assert_contains(screen_source, "visible_size.x *")
	assert_contains(screen_source, "InventorySlotScript")
	assert_contains(screen_source, "_on_item_dropped")
	assert_contains(screen_source, "_equip_from_source")
	assert_contains(screen_source, "_assign_quick_from_source")
	assert_contains(screen_source, "apply_item_rarity_frame")
	assert_contains(screen_source, "attach_item_tooltip")
	assert_contains(slot_source, "_get_drag_data")
	assert_contains(slot_source, "_drop_data")
	assert_contains(slot_source, "item_dropped")
	assert_contains(combat_source, "quick_slot_items")
	assert_contains(combat_source, "Schnellzugriff aus")
	assert_contains(gameplay_source, "INVENTORY_SCENE")
	assert_contains(gameplay_source, "InventoryOverlay")
	assert_contains(gameplay_source, "inventory.name = \"InventoryOverlay\"")
	assert_contains(hud_source, "current.call(\"open_inventory\")")
	assert_false(gameplay_source.contains("go_to(\"res://scenes/ui/inventory_screen.tscn\")"))
	assert_false(hud_source.contains("change_scene_to_file(\"res://scenes/ui/inventory_screen.tscn\")"))
	assert_has_key(structures, "storage_chest")
	assert_contains(equipment_source, "EQUIPMENT_COMPARE_ROWS")
	assert_contains(equipment_source, "compare_label")
	assert_contains(equipment_source, "_equipment_compare_text")
	assert_contains(equipment_source, "_condition_bar")
	assert_contains(equipment_source, "_plain_item_tooltip")
	assert_contains(equipment_source, "TabContainer.new()")
	assert_contains(equipment_source, "_sync_tab_pages")
	assert_contains(equipment_source, "_compact_panel_style")
	assert_contains(equipment_source, "attach_item_tooltip")
	assert_contains(project_source, "ItemTooltip")
	assert_contains(tooltip_source, "SHOW_DELAY := 1.0")
	assert_contains(tooltip_source, "show_item_delayed")
	assert_contains(tooltip_source, "DataCatalog.item_value")
	assert_true(FileAccess.file_exists("res://assets/ui/item_tooltip_reference.png"))
	assert_contains(ui_source, "RARITY_NORMAL")
	assert_contains(ui_source, "RARITY_RARE")
	assert_contains(ui_source, "RARITY_EPIC")
	assert_contains(ui_source, "RARITY_LEGENDARY")
	assert_contains(ui_source, "rarity_legend")
	assert_contains(ui_source, "condition_color")
	assert_contains(ui_source, "_animate_legendary_frame")
	assert_contains(ui_source, "style.border_color = color")
	assert_false(screen_source.contains("ScrollContainer.new()"))
	assert_gt(int(armor.patched_jacket.get("pocket_slots", 0)), 0)
	assert_gt(int(armor.leather_vest.get("pocket_slots", 0)), 0)


func test_world_map_uses_player_map_and_path_rules() -> void:
	var locations := _entries("res://data/world/locations.tres")
	var source := FileAccess.get_file_as_string("res://scripts/world_map/world_map.gd")
	var gameplay_source := FileAccess.get_file_as_string("res://scripts/ui/gameplay_screen.gd")
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	var ui_factory_source := FileAccess.get_file_as_string("res://scripts/ui/ui_factory.gd")
	assert_true(FileAccess.file_exists("res://assets/environments/map_overview/player_region_map.png"))
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
	assert_contains(source, "MAX_ROUTE_POINTS")
	assert_contains(source, "_rest_on_map")
	assert_contains(source, "_requirement_blocker")
	assert_contains(source, "_try_unlock_requirement")
	assert_contains(source, "MapPathLayerScript")
	assert_contains(source, "_confirm_travel")
	assert_contains(source, "_refresh_travel_preview")
	assert_contains(source, "_add_travel_bar")
	assert_contains(source, "_position_side_panel")
	assert_contains(source, "DETAIL_PANEL_TEXTURE")
	assert_contains(source, "_resource_max_for_bar")
	assert_contains(source, "harbor_pier")
	assert_contains(source, "watchtower_key")
	assert_contains(source, "_travel_stamina_cost")
	assert_contains(source, "selected_node_id")
	assert_contains(source, "preview_node_id")
	assert_contains(source, "node_labels")
	assert_contains(source, "_map_label_text")
	assert_contains(source, "trader_screen.tscn")
	assert_contains(source, "_preview_node")
	assert_contains(source, "NODE_SIZE := Vector2(52, 52)")
	assert_contains(source, "HUD_SCENE.instantiate")
	assert_contains(source, "map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)")
	assert_contains(source, "Pfad reparieren")
	assert_contains(source, "_build_map_legend")
	assert_contains(source, "_kind_icon")
	assert_contains(source, "icon_alignment")
	assert_contains(source, "_map_point_to_canvas")
	assert_contains(source, "_visible_map_nodes")
	assert_contains(source, "Vector2(0.0884, 0.3162)")
	assert_contains(source, "Vector2(0.9108, 0.3871)")
	assert_contains(source, "Vector2(0.7268, 0.8457)")
	assert_contains(gameplay_source, "compact_screen")
	assert_contains(gameplay_source, "UiFactory.is_compact_screen")
	assert_contains(ui_factory_source, "visible_screen_size")
	assert_contains(ui_factory_source, "DisplayServer.window_get_size")
	assert_contains(hud_source, "compact_hud")
	assert_contains(hud_source, "ClockFaceScript")
	assert_contains(hud_source, "inventory_button")
	assert_contains(hud_source, "_open_inventory")
	assert_contains(hud_source, "offset_bottom = 102")
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
	assert_contains(trader_source, "Dawn-Credits")
	assert_contains(trader_source, "ITEMS_PER_PAGE")
	assert_contains(card_source, "_get_drag_data")
	assert_contains(drop_source, "_can_drop_data")
	assert_contains(drop_source, "_drop_data")


func test_gameplay_menus_do_not_use_scroll_containers() -> void:
	for path in [
		"res://scripts/ui/inventory_screen.gd",
		"res://scripts/ui/equipment_screen.gd",
		"res://scripts/ui/level_screen.gd",
		"res://scripts/ui/crafting_screen.gd",
		"res://scripts/ui/admin_item_screen.gd",
		"res://scripts/ui/trader_screen.gd",
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
	assert_contains(gameplay_source, "KEY_F6")
	assert_contains(admin_source, "KEY_F6")
	assert_contains(admin_source, "F6 schliesst")
	assert_contains(admin_source, "LineEdit.new()")
	assert_contains(admin_source, "_matching_items")
	assert_contains(admin_source, "ADMIN_ITEMS_PER_PAGE")
	assert_contains(admin_source, "DataCatalog.all_admin_items()")
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


func test_player_appearance_templates_load_and_persist() -> void:
	var appearance_ids := ["wanderer", "mechanic", "medic", "guardian"]
	for gender in ["female", "male"]:
		for appearance_id in appearance_ids:
			assert_true(FileAccess.file_exists("res://assets/characters/player_variants/%s_%s.png" % [gender, appearance_id]))
	var source := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	assert_contains(source, "player_appearance")
	assert_contains(source, "player_appearance_path")


func test_main_menu_has_apocalyptic_animation() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main_menu/main_menu.gd")
	assert_contains(source, "menu_embers.wav")
	assert_contains(source, "_spawn_ash")
	assert_contains(source, "_spawn_smoke")
	assert_contains(source, "_trigger_lightning")
	assert_contains(source, "thunder.wav")
	assert_contains(source, "menu_panel")


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
	var base_visual_source := FileAccess.get_file_as_string("res://scripts/base/base_visual.gd")
	var defense_source := FileAccess.get_file_as_string("res://scripts/base/defense_wave.gd")
	assert_contains(game_state_source, "unlock_room")
	assert_contains(game_state_source, "place_surface_defense")
	assert_contains(game_state_source, "surface_defense_damage")
	assert_contains(game_state_source, "elena_allowed_rooms")
	assert_contains(base_visual_source, "bunker_cutaway.png")
	assert_contains(base_visual_source, "room_selected")
	assert_contains(defense_source, "surface_defense_damage")
	assert_true(FileAccess.file_exists("res://assets/environments/base_scenes/bunker_cutaway.png"))


func test_hud_shows_dawn_credits() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	assert_contains(hud_source, "Dawn-Credits")
	assert_contains(hud_source, "InventorySystem.money")


func test_scripts_and_scenes_load() -> void:
	for path in [
		"res://autoload/game_state.gd",
		"res://autoload/rpg_rules.gd",
		"res://autoload/inventory_system.gd",
		"res://scripts/main_menu/main_menu.gd",
		"res://scripts/world_map/map_path_layer.gd",
		"res://scripts/ui/clock_face.gd",
		"res://scripts/ui/equipment_screen.gd",
		"res://scripts/ui/level_screen.gd",
		"res://scripts/ui/ability_drag_button.gd",
		"res://scripts/ui/ability_hotbar_button.gd",
		"res://scripts/ui/ability_tree_overlay.gd",
		"res://scripts/ui/admin_item_screen.gd",
		"res://scripts/ui/trader_screen.gd",
		"res://scripts/ui/trade_item_card.gd",
		"res://scripts/ui/trade_drop_zone.gd",
		"res://scripts/base/base_visual.gd",
		"res://scripts/base/defense_wave.gd",
		"res://scripts/combat/combat_scene.gd",
		"res://scripts/exploration/exploration_scene.gd",
		"res://data/items/accessories.tres",
		"res://scenes/main_menu/main_menu.tscn",
		"res://scenes/world_map/world_map.tscn",
		"res://scenes/ui/equipment_screen.tscn",
		"res://scenes/ui/level_screen.tscn",
		"res://scenes/ui/admin_item_screen.tscn",
		"res://scenes/ui/trader_screen.tscn",
		"res://scenes/base/base_scene.tscn",
		"res://scenes/base/defense_wave.tscn",
		"res://scenes/combat/combat_scene.tscn"
	]:
		assert_ne(load(path), null, "%s should load" % path)
