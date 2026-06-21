# Purpose: Step-based base defense where player attacks, structures, traps, and recruited guards oppose a growing wave.
# Public API: Attack, brace, trigger traps, and resolve victory or Elena's loss.
# Dependencies: WaveManager, GameState, DataCatalog, TimeSystem, InventorySystem.
extends GameplayScreen

var wave: Dictionary
var remaining_enemies: int
var enemy_health_pool: float
var round_index := 1
var trap_used := false
var status_label: Label
var log_label: Label
var trap_button: Button
var action_buttons: Array[Button] = []
var refuge_art: TextureRect
var wave_art: TextureRect


func _ready() -> void:
	AudioManager.play_music("res://assets/audio/music/combat/hold_the_line.wav", -6.0)
	AudioManager.play_sfx("res://assets/audio/sfx/environment/wave_warning.wav", -3.0)
	if not WaveManager.pending_wave:
		WaveManager.prepare_wave(TimeSystem.current_day)
	wave = WaveManager.current_wave()
	remaining_enemies = int(wave.get("enemy_count", 1))
	enemy_health_pool = remaining_enemies * float(wave.get("enemy_health", 30.0))
	var root := setup_gameplay(str(wave.get("title", "ANGRIFF")), "Die Angriffswelle haemmert gegen die Zuflucht.")
	status_label = UiFactory.title_label("", 28)
	root.add_child(status_label)
	var battlefield := HBoxContainer.new()
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battlefield)
	battlefield.add_child(_side_panel(
		"DIE ZUFLUCHT",
		"#314255",
		"MORGENROT",
		"res://assets/environments/base_scenes/base_evening_painted.png",
		"refuge"
	))
	battlefield.add_child(_side_panel(
		"DIE WELLE",
		"#5c292d",
		"ANGREIFER",
		"res://assets/enemies/demon_boss/demon_boss.svg",
		"wave"
	))
	log_label = UiFactory.body_label("Runde 1. Die ersten Schatten erreichen das Aussenfeld.\n%s" % _trap_status(), 20)
	root.add_child(log_label)
	var actions := UiFactory.horizontal_actions()
	root.add_child(actions)
	for data in [
		["Persoenlich angreifen", Callable(self, "_attack")],
		["Verteidigung koordinieren", Callable(self, "_brace")],
		["Fallenlinie ausloesen", Callable(self, "_trigger_traps")]
	]:
		var button := UiFactory.button(str(data[0]), data[1], 280)
		actions.add_child(button)
		action_buttons.append(button)
	trap_button = action_buttons[2]
	trap_button.disabled = _trap_damage() <= 0.0
	_refresh()


func _side_panel(title: String, color: String, text: String, texture_path: String, role: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiFactory.title_label(title, 26))
	var field := ColorRect.new()
	field.color = Color(color)
	field.custom_minimum_size = Vector2(700, 360)
	box.add_child(field)
	var art := TextureRect.new()
	art.texture = load(texture_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(1, 1, 1, 0.72)
	art.pivot_offset = Vector2(350, 180)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(art)
	if role == "refuge":
		refuge_art = art
	elif role == "wave":
		wave_art = art
	var label := UiFactory.title_label(text, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.add_child(label)
	if role == "refuge":
		box.add_child(UiFactory.body_label(_trap_status(), 17, UiFactory.COLOR_GOLD))
	return panel


func _attack() -> void:
	var result := _player_damage()
	AudioManager.play_sfx(
		"res://assets/audio/sfx/weapons/gunshot.wav" if bool(result.get("ranged", false))
		else "res://assets/audio/sfx/weapons/melee_hit.wav",
		-3.0
	)
	_pulse_art(refuge_art, Color(1.0, 0.92, 0.65, 0.85), 1.035)
	_shake_art(wave_art, Color(1.0, 0.45, 0.38, 0.85))
	_resolve_round(float(result.damage), 1.0, "%s haelt persoenlich die Linie. %s" % [GameState.player_name, result.text])


func _player_damage() -> Dictionary:
	for item_id in InventorySystem.attack_candidates():
		var data := DataCatalog.item(item_id)
		if data.is_empty():
			continue
		var ammo_id := str(data.get("ammo", ""))
		var ranged := not ammo_id.is_empty()
		if ranged and not InventorySystem.remove_item(ammo_id, 1):
			continue
		var damage := float(data.get("damage", 8.0))
		damage += float(GameState.player_stats.get("ranged" if ranged else "melee", 0.0)) * (1.8 if ranged else 1.5)
		damage += InventorySystem.total_equipment_bonus("damage_bonus")
		return {
			"damage": damage,
			"ranged": ranged,
			"text": "%s verursacht %.0f Schaden." % [data.get("name", item_id), damage]
		}
	var damage := 6.0 + float(GameState.player_stats.get("melee", 0.0))
	return {"damage": damage, "ranged": false, "text": "Der improvisierte Schlag verursacht %.0f Schaden." % damage}


func _brace() -> void:
	AudioManager.play_sfx("res://assets/audio/sfx/environment/wave_warning.wav", -9.0, 1.25)
	_pulse_art(refuge_art, Color(0.65, 0.82, 1.0, 0.86), 1.025)
	var defense_bonus := 5.0 + float(GameState.player_stats.get("defense", 0.0)) * 2.0 + InventorySystem.armor_value() * 0.25
	_resolve_round(defense_bonus, 0.42, "Du koordinierst Feuerwinkel und verstaerkst die schwaechste Mauer.")


func _trigger_traps() -> void:
	if trap_used:
		return
	trap_used = true
	trap_button.disabled = true
	var damage := _trap_damage()
	AudioManager.play_sfx("res://assets/audio/sfx/weapons/melee_hit.wav", -4.0, 0.68)
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -7.0, 1.2)
	_shake_art(wave_art, Color(1.0, 0.35, 0.25, 0.9))
	_resolve_round(damage, 0.76, "Die Fallenlinie schnappt zu und reisst Luecken in die Angreifer.")


func _resolve_round(player_damage: float, incoming_multiplier: float, message: String) -> void:
	var auto_damage := _automatic_damage()
	var surface_damage := GameState.surface_defense_damage()
	var guard_damage := maxf(0.0, auto_damage - surface_damage)
	var total_damage := player_damage + auto_damage
	enemy_health_pool -= total_damage
	remaining_enemies = maxi(0, ceili(enemy_health_pool / float(wave.get("enemy_health", 30.0))))
	var detail := "%s\n%.0f Schaden gesamt (%.0f persoenlich, %.0f Oberflaeche, %.0f Wachen)." % [
		message, total_damage, player_damage, surface_damage, guard_damage
	]
	log_label.text = detail
	if enemy_health_pool <= 0.0:
		_victory()
		return
	var defense := _defense_score() + float(GameState.player_stats.get("defense", 0.0)) + InventorySystem.armor_value() * 0.2
	var incoming := maxf(2.0, remaining_enemies * float(wave.get("enemy_damage", 6.0)) * 0.18 - defense * 0.45) * incoming_multiplier
	GameState.damage_base(incoming)
	AudioManager.play_sfx("res://assets/audio/sfx/enemies/growl.wav", -9.0, 0.85)
	_shake_art(refuge_art, Color(0.9, 0.36, 0.32, 0.82))
	if float(GameState.base_state.integrity) <= 0.0:
		GameState.damage_elena(8.0 + remaining_enemies * 0.9)
		log_label.text += "\nDie Mauer ist gebrochen. Angreifer dringen zu Elena vor."
	if GameState.count_role("arzt") > 0:
		GameState.elena.health = minf(float(GameState.elena.max_health), float(GameState.elena.health) + 1.5)
	round_index += 1
	_refresh()


func _automatic_damage() -> float:
	return GameState.surface_defense_damage() + GameState.count_role("waechter") * 6.0


func _defense_score() -> float:
	var score := 0.0
	for structure_id in GameState.base_state.structures:
		var level := int(GameState.base_state.structures[structure_id])
		score += float(DataCatalog.structure(str(structure_id)).get("defense", 0)) * level
	return score


func _trap_damage() -> float:
	var damage := 0.0
	for structure_id in GameState.base_state.structures:
		var data := DataCatalog.structure(str(structure_id))
		if str(data.get("category", "")) != "Falle":
			continue
		damage += float(data.get("trap_damage", 18.0)) * int(GameState.base_state.structures[structure_id])
	return damage


func _trap_count() -> int:
	var count := 0
	for structure_id in GameState.base_state.structures:
		var data := DataCatalog.structure(str(structure_id))
		if str(data.get("category", "")) == "Falle":
			count += int(GameState.base_state.structures[structure_id])
	return count


func _trap_status() -> String:
	if _trap_count() <= 0:
		return "Fallenlinie: leer"
	return "Fallenlinie: %d platziert - %.0f vorbereiteter Schaden" % [_trap_count(), _trap_damage()]


func _victory() -> void:
	for button in action_buttons:
		button.disabled = true
	WaveManager.complete_wave()
	GameState.grant_xp(35 + int(wave.get("enemy_count", 1)) * 2, "Welle ueberstanden")
	AudioManager.play_sfx("res://assets/audio/sfx/weapons/melee_hit.wav", -7.0, 0.58)
	_fade_art(wave_art)
	log_label.text = "Der letzte Angreifer faellt. Die Zuflucht steht noch."
	GameState.elena.stress = maxf(0.0, float(GameState.elena.stress) - 6.0)
	if int(wave.get("day", 0)) == GameState.MAX_DAY:
		GameState.pending_story = "finale"
		GameState.story_return_scene = "res://scenes/main_menu/main_menu.tscn"
		go_to("res://scenes/cinematics/story_slide.tscn")
		return
	TimeSystem.advance(1, "Der Morgen nach dem Angriff beginnt.")
	if GameState.pending_story.is_empty():
		go_to("res://scenes/base/base_scene.tscn")


func _refresh() -> void:
	status_label.text = "Runde %d - Verbleibende Gegner %d - Feindstaerke %.0f\nBasis %.0f%% - Elena %.0f Leben / %.0f Stress - Verteidigungswert %.0f\n%s" % [
		round_index,
		remaining_enemies,
		maxf(0.0, enemy_health_pool),
		float(GameState.base_state.integrity),
		float(GameState.elena.health),
		float(GameState.elena.stress),
		_defense_score(),
		_trap_status()
	]


func _pulse_art(art: TextureRect, tint: Color, scale_to: float) -> void:
	if not is_instance_valid(art):
		return
	var tween := create_tween()
	tween.tween_property(art, "scale", Vector2(scale_to, scale_to), 0.08)
	tween.parallel().tween_property(art, "modulate", tint, 0.08)
	tween.tween_property(art, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(art, "modulate", Color(1, 1, 1, 0.72), 0.14)


func _shake_art(art: TextureRect, tint: Color) -> void:
	if not is_instance_valid(art):
		return
	var origin := art.position
	var tween := create_tween()
	tween.tween_property(art, "position", origin + Vector2(12, 0), 0.04)
	tween.parallel().tween_property(art, "modulate", tint, 0.04)
	tween.tween_property(art, "position", origin + Vector2(-10, 0), 0.04)
	tween.tween_property(art, "position", origin, 0.05)
	tween.parallel().tween_property(art, "modulate", Color(1, 1, 1, 0.72), 0.08)


func _fade_art(art: TextureRect) -> void:
	if not is_instance_valid(art):
		return
	var tween := create_tween()
	tween.tween_property(art, "modulate", Color(0.35, 0.35, 0.35, 0.25), 0.18)
