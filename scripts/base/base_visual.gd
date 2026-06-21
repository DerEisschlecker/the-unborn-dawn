# Purpose: Interactive bunker cutaway with unlockable rooms, surface defenses, and Elena patrol.
# Public API: room_selected, surface_selected signals; click rooms/slots to interact.
# Dependencies: GameState, DataCatalog, EventBus, TimeSystem.
class_name BaseVisual
extends Control

signal room_selected(room_id: String)
signal surface_selected(slot_id: String)

const BACKGROUND_PATH := "res://assets/environments/base_scenes/bunker_cutaway.png"

var elena_texture: Texture2D
var elena_pos := Vector2.ZERO
var elena_target := Vector2.ZERO
var walk_timer := 0.0
var walk_interval := 5.0
var hover_id := ""


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 360 if UiFactory.is_compact_screen() else 560)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	elena_texture = load("res://assets/characters/elena/elena_late.svg" if TimeSystem.current_day >= 200 else "res://assets/characters/elena/elena_early.svg")
	_reset_elena_position()
	if not EventBus.stats_changed.is_connected(queue_redraw):
		EventBus.stats_changed.connect(_on_state_changed)
	if not EventBus.inventory_changed.is_connected(queue_redraw):
		EventBus.inventory_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	if elena_pos.distance_to(elena_target) > 1.5:
		elena_pos = elena_pos.lerp(elena_target, clampf(delta * 2.4, 0.0, 1.0))
		queue_redraw()
		return
	walk_timer += delta
	if walk_timer >= walk_interval:
		walk_timer = 0.0
		_pick_elena_destination()
		queue_redraw()


func _on_state_changed() -> void:
	_reset_elena_position()
	queue_redraw()


func _reset_elena_position() -> void:
	var room_id := str(GameState.base_state.get("elena_room", "shaft_room"))
	elena_pos = GameState.room_center(room_id, size)
	elena_target = elena_pos


func _pick_elena_destination() -> void:
	var rooms := GameState.elena_allowed_rooms()
	if rooms.is_empty():
		return
	var next_room := rooms[randi() % rooms.size()]
	GameState.set_elena_room(next_room)
	elena_target = GameState.room_center(next_room, size)


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var tex := load(BACKGROUND_PATH) as Texture2D
	if tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, s), false, Color(1, 1, 1, 1.0))
	else:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.06, 0.07))
	for room_id in DataCatalog.base_rooms:
		_draw_zone(str(room_id))
	_draw_elena()
	_draw_status(s)


func _draw_zone(room_id: String) -> void:
	var data := DataCatalog.base_room(room_id)
	if data.is_empty():
		return
	var rect := _room_rect(data, size)
	var unlocked := GameState.is_room_unlocked(room_id)
	var hovered := hover_id == room_id
	if not unlocked:
		draw_rect(rect, Color(0.01, 0.01, 0.015, 0.88))
		draw_rect(rect, Color(0.35, 0.35, 0.38, 0.55), false, 2.0)
		_draw_centered_text("?", rect, 28, Color(0.55, 0.55, 0.58, 0.75))
		return
	if str(data.get("zone", "")) == "surface":
		var placed := GameState.surface_placement(room_id)
		if hovered:
			draw_rect(rect, Color(0.85, 0.72, 0.28, 0.18))
		if placed.is_empty():
			_draw_centered_text("+", rect, 22, Color(0.92, 0.86, 0.55, 0.9))
		else:
			var structure := DataCatalog.structure(placed)
			_draw_centered_text(str(structure.get("name", placed)).substr(0, 10), rect, 11, Color(0.95, 0.92, 0.82))
	else:
		if hovered:
			draw_rect(rect, Color(0.45, 0.72, 0.95, 0.16))
		var linked := str(data.get("structure_id", ""))
		if not linked.is_empty():
			var level := int(GameState.base_state.structures.get(linked, 0))
			if level > 0:
				_draw_centered_text("St.%d" % level, rect, 12, Color(0.92, 0.82, 0.45, 0.95))


func _draw_elena() -> void:
	if not GameState.is_room_unlocked("elena_quarters") and not GameState.is_room_unlocked("shaft_room"):
		return
	var rect := Rect2(elena_pos - Vector2(22, 48), Vector2(44, 56))
	if elena_texture:
		draw_texture_rect(elena_texture, rect, false, Color(1, 1, 1, 0.96))
	else:
		draw_circle(elena_pos, 10, Color(0.84, 0.70, 0.66))
	_draw_centered_text("Elena", Rect2(elena_pos.x - 30, elena_pos.y + 8, 60, 20), 11, Color(0.95, 0.88, 0.78))


func _draw_status(s: Vector2) -> void:
	var bar := Rect2(12, s.y - 28, s.x - 24, 16)
	draw_rect(bar, Color(0.02, 0.02, 0.03, 0.82))
	var integrity := clampf(float(GameState.base_state.integrity) / maxf(1.0, float(GameState.base_state.max_integrity)), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * integrity, bar.size.y)), Color(0.38, 0.72, 0.42, 0.95))
	var surface_power := GameState.surface_defense_damage()
	var unlocked_count := int(GameState.base_state.get("unlocked_rooms", []).size())
	var text := "Basis %.0f%%  |  Raeume %d  |  Oberflaeche %.0f Schaden  |  Elena %.0f Leben  |  %d Dawn-Credits" % [
		float(GameState.base_state.integrity),
		unlocked_count,
		surface_power,
		float(GameState.elena.health),
		InventorySystem.money
	]
	draw_string(ThemeDB.fallback_font, bar.position + Vector2(6, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.88, 0.78))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var old_hover := hover_id
		hover_id = _pick_zone(event.position)
		if old_hover != hover_id:
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var picked := _pick_zone(event.position)
		if picked.is_empty():
			return
		accept_event()
		var data := DataCatalog.base_room(picked)
		if str(data.get("zone", "")) == "surface":
			surface_selected.emit(picked)
		else:
			room_selected.emit(picked)


func _pick_zone(pos: Vector2) -> String:
	for room_id in DataCatalog.base_rooms:
		var data := DataCatalog.base_room(str(room_id))
		if _room_rect(data, size).has_point(pos):
			return str(room_id)
	return ""


func _room_rect(data: Dictionary, canvas: Vector2) -> Rect2:
	var rect: Dictionary = data.get("rect", {})
	return Rect2(
		float(rect.get("x", 0.0)) * canvas.x,
		float(rect.get("y", 0.0)) * canvas.y,
		float(rect.get("w", 0.1)) * canvas.x,
		float(rect.get("h", 0.1)) * canvas.y
	)


func _draw_centered_text(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y) * 0.5)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
