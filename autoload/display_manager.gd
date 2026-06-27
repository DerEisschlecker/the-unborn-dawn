# Purpose: Display resolution, monitor selection, window mode, and auto-detect for all screens.
# Public API: apply_settings(), auto_detect(), set_screen(), set_resolution(), set_window_mode().
# Dependencies: EventBus, user://settings.cfg.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DESIGN_SIZE := Vector2i(1920, 1080)

enum WindowMode {
	WINDOWED,
	FULLSCREEN,
	BORDERLESS,
	MAXIMIZED,
}

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const WINDOW_MODE_LABELS := {
	WindowMode.WINDOWED: "Fenster",
	WindowMode.FULLSCREEN: "Vollbild",
	WindowMode.BORDERLESS: "Randlos",
	WindowMode.MAXIMIZED: "Maximiert",
}

var screen_index := 0
var resolution := Vector2i(1920, 1080)
var window_mode: WindowMode = WindowMode.WINDOWED
var vsync_enabled := true
var settings_loaded := false


func _ready() -> void:
	load_settings()
	if not settings_loaded:
		auto_detect()
	apply_settings()


func design_size() -> Vector2:
	return Vector2(DESIGN_SIZE)


func get_screen_count() -> int:
	return maxi(1, DisplayServer.get_screen_count())


func get_screen_label(index: int) -> String:
	var safe_index := clampi(index, 0, get_screen_count() - 1)
	var screen_size := DisplayServer.screen_get_size(safe_index)
	var primary_tag := " · Primaer" if safe_index == DisplayServer.get_primary_screen() else ""
	return "Monitor %d%s (%dx%d)" % [safe_index + 1, primary_tag, screen_size.x, screen_size.y]


func get_available_resolutions(screen_idx: int) -> Array[Vector2i]:
	var safe_index := clampi(screen_idx, 0, get_screen_count() - 1)
	var max_size := DisplayServer.screen_get_size(safe_index)
	var result: Array[Vector2i] = []
	for preset in RESOLUTION_PRESETS:
		if preset.x <= max_size.x and preset.y <= max_size.y:
			result.append(preset)
	var native := snap_resolution(max_size)
	if not result.has(native):
		result.append(native)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x * a.y) < (b.x * b.y)
	)
	if result.is_empty():
		result.append(Vector2i(1280, 720))
	return result


func snap_resolution(res_size: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(640, res_size.x - (res_size.x % 2)),
		maxi(480, res_size.y - (res_size.y % 2))
	)


func best_preset_for_screen(screen_idx: int) -> Vector2i:
	var options := get_available_resolutions(screen_idx)
	if options.is_empty():
		return Vector2i(1920, 1080)
	var preferred := Vector2i(1920, 1080)
	if options.has(preferred):
		return preferred
	return options[options.size() - 1]


func auto_detect() -> void:
	screen_index = DisplayServer.get_primary_screen()
	resolution = best_preset_for_screen(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	if resolution == snap_resolution(screen_size):
		window_mode = WindowMode.BORDERLESS
	else:
		window_mode = WindowMode.WINDOWED
	vsync_enabled = true


func set_screen(index: int, apply_now: bool = true) -> void:
	screen_index = clampi(index, 0, get_screen_count() - 1)
	var options := get_available_resolutions(screen_index)
	if not options.has(resolution):
		resolution = best_preset_for_screen(screen_index)
	if apply_now:
		apply_settings()
		save_settings()


func set_resolution(res_size: Vector2i, apply_now: bool = true) -> void:
	resolution = snap_resolution(res_size)
	if window_mode in [WindowMode.BORDERLESS, WindowMode.MAXIMIZED]:
		window_mode = WindowMode.WINDOWED
	if apply_now:
		apply_settings()
		save_settings()


func set_window_mode(mode: int, apply_now: bool = true) -> void:
	window_mode = clampi(mode, WindowMode.WINDOWED, WindowMode.MAXIMIZED) as WindowMode
	if apply_now:
		apply_settings()
		save_settings()


func set_vsync(enabled: bool, apply_now: bool = true) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	if apply_now:
		save_settings()


func is_fullscreen_mode() -> bool:
	return window_mode in [WindowMode.FULLSCREEN, WindowMode.BORDERLESS, WindowMode.MAXIMIZED]


func apply_settings() -> void:
	screen_index = clampi(screen_index, 0, get_screen_count() - 1)
	resolution = snap_resolution(resolution)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	call_deferred("_apply_window_state")


func _main_window() -> Window:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root


func _apply_window_state() -> void:
	var window := _main_window()
	if window == null:
		_apply_window_state_display_server()
		EventBus.display_settings_changed.emit()
		return
	window.min_size = Vector2i(640, 480)
	window.current_screen = screen_index
	DisplayServer.window_set_current_screen(screen_index)
	match window_mode:
		WindowMode.FULLSCREEN:
			if window.mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
				window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			window.size = resolution
		WindowMode.BORDERLESS:
			if window.mode != Window.MODE_FULLSCREEN:
				window.mode = Window.MODE_FULLSCREEN
			window.size = DisplayServer.screen_get_size(screen_index)
		WindowMode.MAXIMIZED:
			if window.mode != Window.MODE_MAXIMIZED:
				window.mode = Window.MODE_MAXIMIZED
		_:
			if window.mode != Window.MODE_WINDOWED:
				window.mode = Window.MODE_WINDOWED
			window.size = resolution
			_center_window(window)
			if window.size != resolution:
				_refresh_window_size(window, resolution)
	EventBus.display_settings_changed.emit()


func _refresh_window_size(window: Window, target_size: Vector2i) -> void:
	# Windows sometimes needs a mode nudge before the viewport follows a smaller size.
	var previous_mode := window.mode
	window.mode = Window.MODE_WINDOWED
	window.size = target_size
	_center_window(window)
	if window.size != target_size:
		window.size = Vector2i(maxi(640, target_size.x - 64), maxi(480, target_size.y - 48))
		_center_window(window)
		window.size = target_size
		_center_window(window)
	if previous_mode != Window.MODE_WINDOWED:
		match window_mode:
			WindowMode.FULLSCREEN:
				window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			WindowMode.BORDERLESS:
				window.mode = Window.MODE_FULLSCREEN
			WindowMode.MAXIMIZED:
				window.mode = Window.MODE_MAXIMIZED


func _apply_window_state_display_server() -> void:
	DisplayServer.window_set_current_screen(screen_index)
	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_size(resolution)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen_index))
		WindowMode.MAXIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			_center_window()


func save_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		pass
	config.set_value("graphics", "screen", screen_index)
	config.set_value("graphics", "width", resolution.x)
	config.set_value("graphics", "height", resolution.y)
	config.set_value("graphics", "window_mode", int(window_mode))
	config.set_value("graphics", "vsync", vsync_enabled)
	config.set_value("graphics", "fullscreen", is_fullscreen_mode())
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	screen_index = clampi(int(config.get_value("graphics", "screen", DisplayServer.get_primary_screen())), 0, get_screen_count() - 1)
	resolution = snap_resolution(Vector2i(
		int(config.get_value("graphics", "width", DESIGN_SIZE.x)),
		int(config.get_value("graphics", "height", DESIGN_SIZE.y))
	))
	if config.has_section_key("graphics", "window_mode"):
		window_mode = int(config.get_value("graphics", "window_mode", WindowMode.WINDOWED)) as WindowMode
	else:
		var fullscreen := bool(config.get_value("graphics", "fullscreen", false))
		window_mode = WindowMode.FULLSCREEN if fullscreen else WindowMode.WINDOWED
	vsync_enabled = bool(config.get_value("graphics", "vsync", true))
	settings_loaded = true


func _center_window(window: Window = null) -> void:
	var screen_pos := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var window_size := resolution
	var position := Vector2i(
		screen_pos.x + maxi(0, (screen_size.x - window_size.x) >> 1),
		screen_pos.y + maxi(0, (screen_size.y - window_size.y) >> 1)
	)
	if window != null:
		window.position = position
	else:
		DisplayServer.window_set_position(position)
