# Purpose: Provides persistent volume settings for Master, Music, SFX, and Dialogue.
# Public API: set_bus_volume(), get_bus_volume(), save_settings(), load_settings().
# Dependencies: Godot AudioServer and default_bus_layout.tres.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "Dialogue"]

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var current_music_path := ""
var confirm_skip_turn_with_ap := true


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	music_player.finished.connect(_restart_music)
	for index in range(6):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	load_settings()


func play_music(path: String, volume_db: float = -8.0) -> void:
	if current_music_path == path and music_player.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	current_music_path = path
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()


func stop_music() -> void:
	current_music_path = ""
	music_player.stop()


func play_sfx(path: String, volume_db: float = -4.0, pitch_scale: float = 1.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := sfx_players[0]
	for candidate in sfx_players:
		if not candidate.playing:
			player = candidate
			break
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _restart_music() -> void:
	if not current_music_path.is_empty():
		music_player.play()


func set_bus_volume(bus_name: String, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var linear := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear) if linear > 0.001 else -80.0)


func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 100.0
	return db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0


func should_confirm_skip_turn_with_ap() -> bool:
	return confirm_skip_turn_with_ap


func set_confirm_skip_turn_with_ap(enabled: bool) -> void:
	confirm_skip_turn_with_ap = enabled
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	for bus_name in BUS_NAMES:
		config.set_value("audio", bus_name.to_lower(), get_bus_volume(bus_name))
	config.set_value("graphics", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.set_value("graphics", "vsync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	config.set_value("gameplay", "confirm_skip_turn_with_ap", confirm_skip_turn_with_ap)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus_name in BUS_NAMES:
		set_bus_volume(bus_name, float(config.get_value("audio", bus_name.to_lower(), 100.0)))
	var fullscreen := bool(config.get_value("graphics", "fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var vsync := bool(config.get_value("graphics", "vsync", true))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	confirm_skip_turn_with_ap = bool(config.get_value("gameplay", "confirm_skip_turn_with_ap", true))
