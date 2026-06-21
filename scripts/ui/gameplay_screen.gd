# Purpose: Shared base class for gameplay screens, providing HUD, pause, hotkeys, and global transitions.
# Public API: setup_gameplay(), go_to(), open_inventory(), open_equipment(), open_crafting(), open_level(), open_pause().
# Dependencies: HUD, SettingsMenu, EventBus, WaveManager, and GameState.
class_name GameplayScreen
extends Control

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const INVENTORY_SCENE := preload("res://scenes/ui/inventory_screen.tscn")

var content: VBoxContainer


func _enter_tree() -> void:
	EventBus.wave_due.connect(_on_wave_due)
	EventBus.story_due.connect(_on_story_due)
	EventBus.game_over.connect(_on_game_over)


func setup_gameplay(title: String, subtitle: String = "", background_path: String = "") -> VBoxContainer:
	var resolved_background := background_path if not background_path.is_empty() else _default_background_path()
	content = UiFactory.prepare_screen(self, title, subtitle, resolved_background, 0.66)
	var page_margin := content.get_parent() as MarginContainer
	if page_margin:
		var compact_screen := UiFactory.is_compact_screen()
		page_margin.add_theme_constant_override("margin_left", 24 if compact_screen else 42)
		page_margin.add_theme_constant_override("margin_right", 24 if compact_screen else 42)
		page_margin.add_theme_constant_override("margin_top", 112 if compact_screen else 134)
		page_margin.add_theme_constant_override("margin_bottom", 24 if compact_screen else 34)
	add_child(HUD_SCENE.instantiate())
	return content


func _default_background_path() -> String:
	if scene_file_path.contains("/world_map/"):
		return "res://assets/environments/map_overview/region_map_painted.png"
	if scene_file_path.contains("/base/") or scene_file_path.contains("/characters/elena"):
		return "res://assets/environments/base_scenes/base_evening_painted.png"
	if scene_file_path.contains("/combat/") or scene_file_path.contains("/ui/"):
		var location := DataCatalog.location(GameState.current_location)
		return str(location.get("background", "res://assets/environments/backgrounds/menu_ruins.png"))
	if scene_file_path.contains("/exploration/"):
		var location := DataCatalog.location(GameState.current_location)
		return str(location.get("background", "res://assets/environments/backgrounds/menu_ruins.png"))
	return "res://assets/environments/backgrounds/menu_ruins.png"


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func open_inventory() -> void:
	var existing := get_node_or_null("InventoryOverlay")
	if existing:
		remove_child(existing)
		existing.queue_free()
		return
	var inventory := INVENTORY_SCENE.instantiate()
	inventory.name = "InventoryOverlay"
	add_child(inventory)
	move_child(inventory, get_child_count() - 1)


func open_equipment() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/equipment_screen.tscn")


func open_crafting() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/crafting_screen.tscn")


func open_level() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/level_screen.tscn")


func open_admin_items() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/admin_item_screen.tscn")


func open_pause() -> void:
	var existing := get_node_or_null("SettingsMenu")
	if existing:
		existing.call("close_menu")
		return
	var menu := SETTINGS_SCENE.instantiate()
	menu.name = "SettingsMenu"
	add_child(menu)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			open_pause()
		elif event.keycode == KEY_I:
			open_inventory()
		elif event.keycode == KEY_C:
			open_equipment()
		elif event.keycode == KEY_B:
			open_crafting()
		elif event.keycode == KEY_K:
			open_level()
		elif event.keycode == KEY_F6:
			open_admin_items()


func _on_wave_due(_day: int) -> void:
	call_deferred("go_to", "res://scenes/base/defense_wave.tscn")


func _on_story_due(story_id: String) -> void:
	GameState.pending_story = story_id
	GameState.story_return_scene = scene_file_path
	call_deferred("go_to", "res://scenes/cinematics/story_slide.tscn")


func _on_game_over(reason: String) -> void:
	GameState.pending_story = "game_over"
	GameState.quest_flags.game_over_reason = reason
	GameState.story_return_scene = "res://scenes/main_menu/main_menu.tscn"
	call_deferred("go_to", "res://scenes/cinematics/story_slide.tscn")
