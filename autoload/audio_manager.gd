# Purpose: Central music routing, UI click sounds, and trade/coin effects for all scenes.
# Public API: play_scene_music(), play_button_click(), play_coin_sfx(), play_trade_sfx().
# Dependencies: DataCatalog, TimeSystem.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "Dialogue"]

const MUSIC_MENU_THEME := "res://assets/audio/music/menu/start.mp3"
const MUSIC_MENU_VOLUME_DB := -11.0
const MUSIC_MENU_PRIMARY := "res://assets/audio/music/ambient_night/below_the_walls.wav"
const MUSIC_MENU_DRONE := "res://assets/audio/music/menu/horror_ambience.wav"
const MUSIC_MENU := MUSIC_MENU_PRIMARY
const MUSIC_MENU_FALLBACK := "res://assets/audio/music/menu/menu_embers.wav"
const MENU_RAIN_LOOP := "res://assets/audio/sfx/environment/rain_loop.wav"
const SFX_DISTANT_SCREAM := "res://assets/audio/sfx/environment/distant_scream.wav"
const SFX_DISTANT_GUNSHOT := "res://assets/audio/sfx/weapons/gunshot.wav"
const SFX_UI_CLICK := "res://assets/audio/sfx/ui/click.wav"
const SFX_UI_CLICK_MENU := "res://assets/audio/sfx/environment/wave_warning.wav"
const SFX_UI_CLICK_DANGER := "res://assets/audio/sfx/enemies/growl.wav"
const SFX_UI_CLICK_CONFIRM := "res://assets/audio/sfx/weapons/melee_hit.wav"
const SFX_UI_CLICK_TOGGLE := "res://assets/audio/sfx/ui/craft.wav"
const MUSIC_DAY := "res://assets/audio/music/ambient_day/fragile_morning.wav"
const MUSIC_NIGHT := "res://assets/audio/music/ambient_night/below_the_walls.wav"
const MUSIC_COMBAT_THEME := "res://assets/audio/music/combat/fight_1.mp3"
const MUSIC_COMBAT_FALLBACK := "res://assets/audio/music/combat/hold_the_line.wav"
const MUSIC_COMBAT_VOLUME_DB := -11.0
const MUSIC_BASE_THEME := "res://assets/audio/music/base/base_1.mp3"
const MUSIC_BASE_VOLUME_DB := -11.0
const MUSIC_WORLD_MAP_THEME := "res://assets/audio/music/world_map/map_1.mp3"
const MUSIC_WORLD_MAP_VOLUME_DB := -11.0
const MUSIC_CROSSFADE_SEC := 1.8
const SFX_COIN := "res://assets/audio/sfx/ui/coin.wav"
const SFX_COIN_FALLBACK := SFX_UI_CLICK

enum UiClickKind {
	DEFAULT,
	MENU,
	DANGER,
	CONFIRM,
	TOGGLE,
}

var music_player: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var _music_active_player: AudioStreamPlayer
var _music_crossfade_tween: Tween
var menu_drone_player: AudioStreamPlayer
var menu_rain_player: AudioStreamPlayer
var menu_ambience_timer: Timer
var sfx_players: Array[AudioStreamPlayer] = []
var current_music_path := ""
var menu_ambience_active := false
var confirm_skip_turn_with_ap := true


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	music_player.finished.connect(_on_music_stream_finished.bind(music_player))
	music_player_b = AudioStreamPlayer.new()
	music_player_b.name = "MusicPlayerB"
	music_player_b.bus = "Music"
	add_child(music_player_b)
	music_player_b.finished.connect(_on_music_stream_finished.bind(music_player_b))
	_music_active_player = music_player
	for index in range(6):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	load_settings()
	if _is_main_menu_boot():
		call_deferred("play_menu_ambience")


func play_music(path: String, volume_db: float = -8.0, pitch_scale: float = 1.0) -> void:
	if current_music_path == path and _music_active_player.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_apply_stream_loop(stream)
	var incoming := _inactive_music_player()
	var outgoing := _music_active_player
	if not outgoing.playing or current_music_path.is_empty():
		_stop_music_crossfade()
		current_music_path = path
		outgoing.stream = stream
		outgoing.volume_db = volume_db
		outgoing.pitch_scale = pitch_scale
		_music_active_player = outgoing
		incoming.stop()
		outgoing.play()
		return
	_stop_music_crossfade()
	current_music_path = path
	incoming.stream = stream
	incoming.pitch_scale = pitch_scale
	incoming.volume_db = volume_db - 36.0
	incoming.play()
	_music_crossfade_tween = create_tween()
	_music_crossfade_tween.set_parallel(true)
	_music_crossfade_tween.tween_property(outgoing, "volume_db", -80.0, MUSIC_CROSSFADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_crossfade_tween.tween_property(incoming, "volume_db", volume_db, MUSIC_CROSSFADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_crossfade_tween.finished.connect(func() -> void:
		outgoing.stop()
		_music_active_player = incoming
	, CONNECT_ONE_SHOT)


func play_scene_music(scene: String, location_id: String = "") -> void:
	if scene != "main_menu":
		stop_menu_ambience()
	var spec := _resolve_scene_music(scene, location_id)
	play_music(spec.path, spec.volume, float(spec.get("pitch", 1.0)))


func play_menu_ambience() -> void:
	menu_ambience_active = true
	_play_menu_music_layers()
	if _uses_custom_menu_theme():
		return
	_start_menu_rain_loop()
	_schedule_menu_atmosphere()


func stop_menu_ambience() -> void:
	menu_ambience_active = false
	if is_instance_valid(menu_ambience_timer):
		menu_ambience_timer.stop()
	if is_instance_valid(menu_drone_player):
		menu_drone_player.stop()
	if is_instance_valid(menu_rain_player):
		menu_rain_player.stop()


func play_coin_sfx(strength: int = 1) -> void:
	var path := SFX_COIN if ResourceLoader.exists(SFX_COIN) else SFX_COIN_FALLBACK
	var hits := clampi(strength, 1, 4)
	for index in range(hits):
		play_sfx(path, -5.5 - float(index) * 1.5, 0.92 + float(index) * 0.06)


func play_button_click(kind: UiClickKind = UiClickKind.DEFAULT) -> void:
	match kind:
		UiClickKind.MENU:
			# wave_warning allein war bei hohem Pitch und leiser Lautstaerke unhoerbar
			# hinter Menu-Ambience — tiefer Klick bleibt hoerbar.
			play_sfx(SFX_UI_CLICK, randf_range(-6.0, -3.0), randf_range(0.52, 0.68))
			if ResourceLoader.exists(SFX_UI_CLICK_MENU):
				play_sfx(SFX_UI_CLICK_MENU, randf_range(-18.0, -14.0), randf_range(1.15, 1.35))
		UiClickKind.DANGER:
			play_sfx(SFX_UI_CLICK_DANGER, randf_range(-12.0, -8.0), randf_range(1.35, 1.65))
		UiClickKind.CONFIRM:
			play_sfx(SFX_UI_CLICK_CONFIRM, randf_range(-9.0, -6.0), randf_range(1.05, 1.18))
		UiClickKind.TOGGLE:
			play_sfx(SFX_UI_CLICK_TOGGLE, randf_range(-15.0, -12.0), randf_range(0.72, 0.86))
		_:
			play_sfx(SFX_UI_CLICK, randf_range(-11.0, -8.0), randf_range(0.62, 0.78))


func play_trade_sfx(kind: String) -> void:
	match kind:
		"sell":
			play_coin_sfx(1)
		"sell_big":
			play_coin_sfx(3)
		"buy":
			play_button_click(UiClickKind.DEFAULT)
		"confirm":
			play_coin_sfx(2)
			play_button_click(UiClickKind.CONFIRM)
		_:
			play_button_click(UiClickKind.DEFAULT)


func stop_music() -> void:
	_stop_music_crossfade()
	current_music_path = ""
	music_player.stop()
	music_player_b.stop()


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


func _resolve_scene_music(scene: String, location_id: String) -> Dictionary:
	match scene:
		"main_menu", "story":
			return {"path": _menu_music_path(), "volume": MUSIC_MENU_VOLUME_DB, "pitch": 1.0}
		"trader":
			return {"path": MUSIC_MENU, "volume": -10.0}
		"crafting", "build":
			return {"path": MUSIC_DAY, "volume": -12.0}
		"equipment", "level", "inventory":
			return {"path": MUSIC_DAY, "volume": -13.0}
		"elena":
			return {"path": MUSIC_NIGHT, "volume": -14.0}
		"combat":
			return {"path": _combat_music_path(), "volume": MUSIC_COMBAT_VOLUME_DB, "pitch": 1.0}
		"defense_wave":
			return {"path": _combat_music_path(), "volume": MUSIC_COMBAT_VOLUME_DB, "pitch": 1.0}
		"base":
			return _base_music()
		"exploration":
			return _exploration_music(location_id)
		"world_map":
			return _world_map_music()
	return _ambient_music(-10.0)


func _ambient_music(volume: float) -> Dictionary:
	if TimeSystem.is_night():
		return {"path": MUSIC_NIGHT, "volume": volume}
	return {"path": MUSIC_DAY, "volume": volume}


func _base_music() -> Dictionary:
	if ResourceLoader.exists(MUSIC_BASE_THEME):
		return {"path": MUSIC_BASE_THEME, "volume": MUSIC_BASE_VOLUME_DB, "pitch": 1.0}
	return _ambient_music(-11.0)


func _world_map_music() -> Dictionary:
	if ResourceLoader.exists(MUSIC_WORLD_MAP_THEME):
		return {"path": MUSIC_WORLD_MAP_THEME, "volume": MUSIC_WORLD_MAP_VOLUME_DB, "pitch": 1.0}
	return _ambient_music(-10.0)


func _exploration_music(location_id: String) -> Dictionary:
	var loc_type := str(DataCatalog.location(location_id).get("type", ""))
	match loc_type:
		"Dungeon", "Industrie":
			return {"path": MUSIC_COMBAT_FALLBACK, "volume": -13.0}
		"Militaerposten", "Krankenhaus":
			return {"path": MUSIC_NIGHT, "volume": -12.0}
		"Wald", "Versteckter Ort":
			return {"path": MUSIC_DAY, "volume": -12.0}
		"Haendler":
			return {"path": MUSIC_MENU, "volume": -10.0}
	return _ambient_music(-12.0)


func _on_music_stream_finished(player: AudioStreamPlayer) -> void:
	if player != _music_active_player:
		return
	if not current_music_path.is_empty():
		player.play()


func _inactive_music_player() -> AudioStreamPlayer:
	return music_player_b if _music_active_player == music_player else music_player


func _stop_music_crossfade() -> void:
	if not is_instance_valid(_music_crossfade_tween):
		return
	_music_crossfade_tween.kill()
	_music_crossfade_tween = null
	_inactive_music_player().stop()


func _combat_music_path() -> String:
	if ResourceLoader.exists(MUSIC_COMBAT_THEME):
		return MUSIC_COMBAT_THEME
	return MUSIC_COMBAT_FALLBACK


func _menu_music_path() -> String:
	if ResourceLoader.exists(MUSIC_MENU_THEME):
		return MUSIC_MENU_THEME
	if ResourceLoader.exists(MUSIC_MENU_PRIMARY):
		return MUSIC_MENU_PRIMARY
	if ResourceLoader.exists(MUSIC_MENU_DRONE):
		return MUSIC_MENU_DRONE
	return MUSIC_MENU_FALLBACK


func _uses_custom_menu_theme() -> bool:
	return ResourceLoader.exists(MUSIC_MENU_THEME)


func _is_main_menu_boot() -> bool:
	return str(ProjectSettings.get_setting("application/run/main_scene", "")).contains("main_menu")


func _apply_stream_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _play_menu_music_layers() -> void:
	var primary_path := _menu_music_path()
	var volume := MUSIC_MENU_VOLUME_DB if _uses_custom_menu_theme() else -10.0
	play_music(primary_path, volume, 1.0)
	if _uses_custom_menu_theme():
		if is_instance_valid(menu_drone_player):
			menu_drone_player.stop()
		return
	if not ResourceLoader.exists(MUSIC_MENU_DRONE):
		return
	if not is_instance_valid(menu_drone_player):
		menu_drone_player = AudioStreamPlayer.new()
		menu_drone_player.name = "MenuDronePlayer"
		menu_drone_player.bus = "Music"
		add_child(menu_drone_player)
	var drone := load(MUSIC_MENU_DRONE) as AudioStreamWAV
	if drone == null:
		return
	drone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	menu_drone_player.stream = drone
	menu_drone_player.volume_db = -19.0
	menu_drone_player.pitch_scale = 0.72
	if not menu_drone_player.playing:
		menu_drone_player.play()


func _start_menu_rain_loop() -> void:
	if not ResourceLoader.exists(MENU_RAIN_LOOP):
		return
	if not is_instance_valid(menu_rain_player):
		menu_rain_player = AudioStreamPlayer.new()
		menu_rain_player.name = "MenuRainPlayer"
		menu_rain_player.bus = "Music"
		add_child(menu_rain_player)
	var stream := load(MENU_RAIN_LOOP) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	menu_rain_player.stream = stream
	menu_rain_player.volume_db = -14.0
	if not menu_rain_player.playing:
		menu_rain_player.play()


func _schedule_menu_atmosphere() -> void:
	if not menu_ambience_active:
		return
	if not is_instance_valid(menu_ambience_timer):
		menu_ambience_timer = Timer.new()
		menu_ambience_timer.name = "MenuAmbienceTimer"
		menu_ambience_timer.one_shot = true
		menu_ambience_timer.timeout.connect(_on_menu_ambience_timer)
		add_child(menu_ambience_timer)
	menu_ambience_timer.wait_time = randf_range(7.0, 16.0)
	menu_ambience_timer.start()


func _on_menu_ambience_timer() -> void:
	if not menu_ambience_active:
		return
	_play_random_menu_atmosphere()
	_schedule_menu_atmosphere()


func _play_random_menu_atmosphere() -> void:
	var roll := randf()
	if roll < 0.48 and ResourceLoader.exists(SFX_DISTANT_SCREAM):
		play_sfx(SFX_DISTANT_SCREAM, randf_range(-24.0, -17.0), randf_range(0.78, 1.05))
	elif roll < 0.78 and ResourceLoader.exists(SFX_DISTANT_GUNSHOT):
		play_sfx(SFX_DISTANT_GUNSHOT, randf_range(-28.0, -21.0), randf_range(0.58, 0.82))


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
	config.set_value("gameplay", "confirm_skip_turn_with_ap", confirm_skip_turn_with_ap)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus_name in BUS_NAMES:
		set_bus_volume(bus_name, float(config.get_value("audio", bus_name.to_lower(), 100.0)))
	confirm_skip_turn_with_ap = bool(config.get_value("gameplay", "confirm_skip_turn_with_ap", true))
