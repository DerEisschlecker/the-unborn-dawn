# Purpose: Generic data-driven exploration view with turn-limited click movement, loot hotspots, NPC recruitment, and encounters.
# Public API: Move on the local grid, spend actions on hotspots, recruit a survivor, enter combat, or return to the map.
# Dependencies: DataCatalog, InventorySystem, GameState, TimeSystem.
extends GameplayScreen

const MAP_COLUMNS := 6
const MAP_ROWS := 4
const MOVE_POINTS_PER_ROUND := 6
const ACTION_POINTS_PER_ROUND := 2
const START_CELL := Vector2i(0, 2)

var location_id: String
var location: Dictionary
var log_label: Label
var context_box: VBoxContainer
var map_grid: GridContainer
var round_label: Label
var player_cell := START_CELL
var selected_cell := START_CELL
var combat_cell := Vector2i(5, 2)
var recruit_cell := Vector2i(2, 3)
var hotspot_cells: Array[Vector2i] = []
var blocked_cells: Array[Vector2i] = []
var move_points := MOVE_POINTS_PER_ROUND
var action_points := ACTION_POINTS_PER_ROUND
var round_index := 1


func _ready() -> void:
	AudioManager.play_music(
		"res://assets/audio/music/ambient_night/below_the_walls.wav" if TimeSystem.is_night()
		else "res://assets/audio/music/ambient_day/fragile_morning.wav",
		-12.0
	)
	location_id = GameState.current_location
	if location_id.is_empty():
		location_id = "ruined_town"
	location = DataCatalog.location(location_id)
	_configure_route()
	var root := setup_gameplay(
		str(location.get("name", "UNBEKANNTER ORT")).to_upper(),
		"Klicke auf benachbarte Felder oder bewege dich mit WASD. Bewegung und Aktionen sind pro Runde begrenzt."
	)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var scene_panel := PanelContainer.new()
	scene_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scene_panel)
	var scene_box := VBoxContainer.new()
	scene_box.add_theme_constant_override("separation", 10)
	scene_panel.add_child(scene_box)
	var artwork := TextureRect.new()
	artwork.texture = load(str(location.get("background", "res://assets/environments/backgrounds/menu_ruins.png")))
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.custom_minimum_size = Vector2(900, 250)
	artwork.modulate = TimeSystem.scene_light_color()
	scene_box.add_child(artwork)
	round_label = UiFactory.body_label("", 20, UiFactory.COLOR_GOLD)
	scene_box.add_child(round_label)
	map_grid = GridContainer.new()
	map_grid.columns = MAP_COLUMNS
	map_grid.add_theme_constant_override("h_separation", 6)
	map_grid.add_theme_constant_override("v_separation", 6)
	scene_box.add_child(map_grid)
	log_label = UiFactory.body_label("Du betrittst den Rand des Gebiets. Jeder Schritt zaehlt.", 19)
	scene_box.add_child(log_label)
	context_box = VBoxContainer.new()
	context_box.custom_minimum_size.x = 480
	context_box.add_theme_constant_override("separation", 10)
	split.add_child(context_box)
	_refresh()


func _configure_route() -> void:
	player_cell = START_CELL
	selected_cell = player_cell
	hotspot_cells = [Vector2i(1, 1), Vector2i(3, 2), Vector2i(4, 0)]
	combat_cell = Vector2i(5, 2)
	recruit_cell = Vector2i(2, 3)
	blocked_cells = [Vector2i(2, 1), Vector2i(4, 2)]
	var danger := int(location.get("danger", 0))
	if danger <= 0:
		combat_cell = Vector2i(5, 1)


func _build_map() -> void:
	UiFactory.clear_container(map_grid)
	for y in range(MAP_ROWS):
		for x in range(MAP_COLUMNS):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(132, 76)
			button.text = _cell_text(cell)
			button.tooltip_text = _cell_tooltip(cell)
			button.disabled = not _cell_clickable(cell)
			button.pressed.connect(Callable(self, "_click_cell").bind(cell))
			map_grid.add_child(button)


func _build_context() -> void:
	UiFactory.clear_container(context_box)
	context_box.add_child(UiFactory.title_label("Unterwegs", 28))
	context_box.add_child(UiFactory.body_label(
		"Runde %d\nBewegungspunkte: %d/%d\nAktionspunkte: %d/%d\nWASD bewegt ein Feld." % [
			round_index,
			move_points,
			MOVE_POINTS_PER_ROUND,
			action_points,
			ACTION_POINTS_PER_ROUND
		],
		19,
		UiFactory.COLOR_GOLD
	))
	var hotspot_index := _hotspot_index(player_cell)
	var searched := int(GameState.quest_flags.get("search_" + location_id, 0))
	if hotspot_index >= 0:
		if hotspot_index < searched:
			context_box.add_child(UiFactory.body_label("Dieser Ort ist bereits abgesucht.", 18, UiFactory.COLOR_MUTED))
		elif hotspot_index == searched:
			var search_button := UiFactory.button("Durchsuchen (1 Aktion)", _search_current, 440)
			search_button.disabled = action_points <= 0
			context_box.add_child(search_button)
		else:
			context_box.add_child(UiFactory.body_label("Du brauchst erst eine klarere Spur in diesem Gebiet.", 18, UiFactory.COLOR_MUTED))
	if int(location.get("danger", 0)) > 0 and player_cell == combat_cell:
		var combat_button := UiFactory.button("Kampf beginnen (1 Aktion)", _start_combat_from_context, 440)
		combat_button.disabled = action_points <= 0
		context_box.add_child(combat_button)
	var recruit_data := _recruit_data()
	if not recruit_data.is_empty() and player_cell == recruit_cell and not _already_recruited(recruit_data):
		var recruit_button := UiFactory.button("%s ansprechen (1 Aktion)" % recruit_data[1], func() -> void: _recruit_from_context(recruit_data), 440)
		recruit_button.disabled = action_points <= 0
		context_box.add_child(recruit_button)
	context_box.add_child(UiFactory.button("Rasten / neue Runde", _new_round, 440))
	context_box.add_child(UiFactory.button("Zurueck zur Karte", func() -> void: go_to("res://scenes/world_map/world_map.tscn"), 440))


func _search(index: int) -> void:
	if action_points <= 0:
		log_label.text = "Keine Aktion uebrig. Raste kurz oder starte eine neue Runde."
		return
	var seed_value := TimeSystem.current_day * 1009 + TimeSystem.current_hour() * 131 + index * 37 + int(GameState.quest_flags.get("search_" + location_id, 0))
	var loot := DataCatalog.weighted_loot(location_id, seed_value)
	if loot.is_empty():
		log_label.text = "Hier ist nichts mehr."
		return
	var item_id := str(loot.get("item_id", ""))
	var amount := int(loot.get("amount", 1))
	if InventorySystem.add_item(item_id, amount):
		AudioManager.play_sfx("res://assets/audio/sfx/ui/loot.wav", -4.0)
		log_label.text = "Gefunden: %s x%d" % [DataCatalog.item(item_id).get("name", item_id), amount]
		GameState.quest_flags["search_" + location_id] = index + 1
		_reveal_clues(index)
		action_points = maxi(0, action_points - 1)
		move_points = 0
		GameState.spend_for_action(6.0, 4.0)
		TimeSystem.advance(1)
		if not WaveManager.pending_wave and GameState.pending_story.is_empty():
			_refresh()


func _reveal_clues(index: int) -> void:
	if location_id == "ruined_town" and index >= 0:
		GameState.quest_flags.discovered_radio = true
		log_label.text += "\nEine Frequenz auf einem Zettel weist zum Funkturm Nord."
	if location_id == "forest" and index >= 1:
		GameState.quest_flags.discovered_chapel = true
		log_label.text += "\nZwischen den Baeumen findest du einen Pfad zur versunkenen Kapelle."


func _refresh() -> void:
	round_label.text = "%s - Runde %d - BP %d/%d - AP %d/%d" % [
		str(location.get("type", "Ruine")).to_upper(),
		round_index,
		move_points,
		MOVE_POINTS_PER_ROUND,
		action_points,
		ACTION_POINTS_PER_ROUND
	]
	_build_map()
	_build_context()


func _click_cell(cell: Vector2i) -> void:
	selected_cell = cell
	if cell == player_cell:
		log_label.text = _cell_tooltip(cell)
		_refresh()
		return
	_move_to_cell(cell)


func _move_to_cell(cell: Vector2i) -> void:
	if not _can_move_to(cell):
		log_label.text = "Dieses Feld ist in dieser Runde nicht erreichbar."
		_refresh()
		return
	player_cell = cell
	move_points = maxi(0, move_points - 1)
	AudioManager.play_sfx("res://assets/audio/sfx/ui/click.wav", -8.0, 1.08)
	log_label.text = _cell_tooltip(cell)
	_refresh()


func _can_move_to(cell: Vector2i) -> bool:
	return move_points > 0 and _distance(player_cell, cell) == 1 and _cell_walkable(cell)


func _cell_clickable(cell: Vector2i) -> bool:
	return cell == player_cell or _can_move_to(cell)


func _cell_walkable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_COLUMNS and cell.y >= 0 and cell.y < MAP_ROWS and not blocked_cells.has(cell)


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _cell_text(cell: Vector2i) -> String:
	if cell == player_cell:
		return "DU\nStand"
	if blocked_cells.has(cell):
		return "X\nBlockiert"
	var hotspot_index := _hotspot_index(cell)
	if hotspot_index >= 0:
		var searched := int(GameState.quest_flags.get("search_" + location_id, 0))
		if hotspot_index < searched:
			return "OK\nAbgesucht"
		if hotspot_index == searched:
			return "?\nSpur"
		return "?\nFern"
	if int(location.get("danger", 0)) > 0 and cell == combat_cell:
		return "!\nGefahr"
	var recruit_data := _recruit_data()
	if not recruit_data.is_empty() and cell == recruit_cell and not _already_recruited(recruit_data):
		return "+\nKontakt"
	if cell == START_CELL:
		return "<\nKarte"
	return "."


func _cell_tooltip(cell: Vector2i) -> String:
	if cell == player_cell:
		return "Aktuelle Position. Waehle ein benachbartes Feld."
	if blocked_cells.has(cell):
		return "Eingestuerzter Bereich. Kein Durchkommen."
	var hotspot_index := _hotspot_index(cell)
	if hotspot_index >= 0:
		return "Moeglicher Fundort. Betritt das Feld und gib eine Aktion aus."
	if int(location.get("danger", 0)) > 0 and cell == combat_cell:
		return "Tiefe Erkundung. Hier kann ein Kampf beginnen."
	if cell == START_CELL:
		return "Rueckweg zur Gebietskarte."
	return "Bewegbares Feld."


func _hotspot_index(cell: Vector2i) -> int:
	for index in range(hotspot_cells.size()):
		if hotspot_cells[index] == cell:
			return index
	return -1


func _search_current() -> void:
	var hotspot_index := _hotspot_index(player_cell)
	if hotspot_index < 0:
		log_label.text = "Hier gibt es nichts Sinnvolles zu durchsuchen."
		return
	_search(hotspot_index)


func _start_combat_from_context() -> void:
	if action_points <= 0:
		log_label.text = "Keine Aktion uebrig. Raste kurz oder starte eine neue Runde."
		return
	action_points = maxi(0, action_points - 1)
	move_points = 0
	_start_combat()


func _new_round() -> void:
	round_index += 1
	move_points = MOVE_POINTS_PER_ROUND
	action_points = ACTION_POINTS_PER_ROUND
	GameState.change_stat("stamina", 8.0)
	GameState.change_stat("energy", -3.0)
	TimeSystem.advance(1, "Kurze Rast im Gebiet.")
	if not WaveManager.pending_wave and GameState.pending_story.is_empty():
		log_label.text = "Neue Runde. Du hast wieder Bewegung und eine Aktion."
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var direction := Vector2i.ZERO
		match event.keycode:
			KEY_W:
				direction = Vector2i.UP
			KEY_A:
				direction = Vector2i.LEFT
			KEY_S:
				direction = Vector2i.DOWN
			KEY_D:
				direction = Vector2i.RIGHT
		if direction != Vector2i.ZERO:
			accept_event()
			_move_to_cell(player_cell + direction)
			return
	super._unhandled_input(event)


func _start_combat() -> void:
	var danger := int(location.get("danger", 1))
	var enemy_id := "demon_basic"
	if danger >= 4:
		enemy_id = "demon_brute"
	elif danger >= 3 and TimeSystem.current_day % 2 == 0:
		enemy_id = "demon_runner"
	GameState.quest_flags.current_enemy = enemy_id
	GameState.return_scene = scene_file_path
	go_to("res://scenes/combat/combat_scene.tscn")


func _recruit_data() -> Array:
	var recruit_data := {
		"hospital": ["mara", "Mara", "arzt"],
		"radio_tower": ["jonas", "Jonas", "waechter"],
		"forest": ["liv", "Liv", "sammler"]
	}
	if not recruit_data.has(location_id):
		return []
	return recruit_data[location_id]


func _already_recruited(data: Array) -> bool:
	for survivor in GameState.survivors:
		if survivor.id == data[0]:
			return true
	return false


func _recruit_from_context(data: Array) -> void:
	if action_points <= 0:
		log_label.text = "Keine Aktion uebrig. Raste kurz oder starte eine neue Runde."
		return
	if _recruit(data):
		action_points = maxi(0, action_points - 1)
		move_points = 0
		TimeSystem.advance(1)
		if not WaveManager.pending_wave and GameState.pending_story.is_empty():
			_refresh()


func _recruit(data: Array) -> bool:
	if GameState.recruit_survivor(str(data[0]), str(data[1]), str(data[2])):
		log_label.text = "%s schliesst sich der Zuflucht als %s an." % [data[1], GameState.survivor_role_name(str(data[2]))]
		return true
	return false
