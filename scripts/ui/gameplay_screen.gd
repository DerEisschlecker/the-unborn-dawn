# Purpose: Shared base class for gameplay screens, providing HUD, pause, hotkeys, and global transitions.
# Public API: setup_gameplay(), go_to(), open_inventory(), open_crafting(), open_level(), open_pause().
# Dependencies: HUD, SettingsMenu, EventBus, WaveManager, and GameState.
class_name GameplayScreen
extends Control

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const INVENTORY_SCENE := preload("res://scenes/ui/inventory_screen.tscn")

const PRESERVED_SCENE_CHILDREN := ["HUD"]

const MENU_RETURN_SCENES := {
	"res://scenes/ui/admin_item_screen.tscn": true,
	"res://scenes/ui/crafting_screen.tscn": true,
	"res://scenes/ui/level_screen.tscn": true,
	"res://scenes/ui/trader_screen.tscn": true,
	"res://scenes/base/build_menu.tscn": true,
	"res://scenes/world_map/rest_camp_scene.tscn": true,
}

var content: VBoxContainer


func _enter_tree() -> void:
	if not scene_file_path.is_empty() and not MENU_RETURN_SCENES.has(scene_file_path):
		GameState.return_scene = scene_file_path
	EventBus.wave_due.connect(_on_wave_due)
	EventBus.story_due.connect(_on_story_due)
	EventBus.game_over.connect(_on_game_over)


func setup_gameplay(title: String, subtitle: String = "", background_path: String = "") -> VBoxContainer:
	var resolved_background := background_path if not background_path.is_empty() else _default_background_path()
	content = UiFactory.prepare_screen(self, title, subtitle, resolved_background, 0.66)
	var page_margin := content.get_parent() as MarginContainer
	if page_margin:
		var compact_screen := UiFactory.is_compact_screen(self)
		var margins := UiFactory.screen_margins(self, compact_screen)
		page_margin.add_theme_constant_override("margin_left", margins.left)
		page_margin.add_theme_constant_override("margin_right", margins.right)
		page_margin.add_theme_constant_override("margin_top", margins.top)
		page_margin.add_theme_constant_override("margin_bottom", UiFactory.hud_bottom_inset(self))
	attach_hud()
	return content


func clear_dynamic_children() -> void:
	for child in get_children():
		if child.name in PRESERVED_SCENE_CHILDREN:
			continue
		remove_child(child)
		child.queue_free()


func attach_hud() -> Control:
	var existing := get_node_or_null("HUD")
	if existing:
		move_child(existing, get_child_count() - 1)
		return existing as Control
	var hud := HUD_SCENE.instantiate()
	hud.name = "HUD"
	add_child(hud)
	move_child(hud, get_child_count() - 1)
	return hud as Control


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


func return_to_previous(fallback: String = "res://scenes/world_map/world_map.tscn") -> void:
	var target := GameState.return_scene
	if target.is_empty() or target == scene_file_path:
		target = fallback
	go_to(target)


func open_inventory() -> void:
	var existing := get_node_or_null("InventoryOverlay")
	if existing:
		remove_child(existing)
		existing.queue_free()
		return
	var inventory := INVENTORY_SCENE.instantiate()
	inventory.name = "InventoryOverlay"
	inventory.z_index = 200
	add_child(inventory)
	move_child(inventory, get_child_count() - 1)


func open_crafting() -> void:
	if scene_file_path == "res://scenes/ui/crafting_screen.tscn":
		return
	GameState.return_scene = scene_file_path
	call_deferred("go_to", "res://scenes/ui/crafting_screen.tscn")


func open_level() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/level_screen.tscn")


func rest_action() -> void:
	TimeSystem.advance(4, "Du rastest eine Weile.")
	GameState.rest_player()


func open_admin_items() -> void:
	GameState.return_scene = scene_file_path
	go_to("res://scenes/ui/admin_item_screen.tscn")


func open_pause() -> void:
	var existing := get_node_or_null("PauseMenuLayer/SettingsMenu")
	if existing == null:
		existing = get_node_or_null("SettingsMenu")
	if existing:
		existing.call("close_menu")
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.name = "PauseMenuLayer"
	add_child(layer)
	var menu := SETTINGS_SCENE.instantiate()
	menu.name = "SettingsMenu"
	layer.add_child(menu)
	var screen := self
	menu.tree_exited.connect(func() -> void:
		if is_instance_valid(screen) and screen.has_method("_on_pause_menu_closed"):
			screen._on_pause_menu_closed()
		if is_instance_valid(layer):
			layer.queue_free()
	)
	if has_method("_on_pause_menu_opened"):
		call("_on_pause_menu_opened")


func _is_pause_menu_open() -> bool:
	return get_node_or_null("PauseMenuLayer/SettingsMenu") != null or get_node_or_null("SettingsMenu") != null


func _is_inventory_open() -> bool:
	return get_node_or_null("InventoryOverlay") != null


func _close_scene_popup() -> bool:
	return false


func close_active_popup() -> bool:
	if _close_scene_popup():
		return true
	if _is_inventory_open():
		open_inventory()
		return true
	return false


func _handle_escape_key() -> void:
	if close_active_popup():
		return
	open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			accept_event()
			_handle_escape_key()
			return
		elif event.keycode == KEY_I:
			open_inventory()
		elif event.keycode == KEY_B:
			accept_event()
			open_crafting()
		elif event.keycode == KEY_K:
			open_level()
		elif event.keycode == KEY_F6 and OS.is_debug_build():
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
