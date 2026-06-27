# Purpose: Interactive bunker cutaway with unlockable rooms, surface defenses, and Elena patrol.
# Public API: room_selected, surface_selected signals; click rooms/slots to interact.
# Dependencies: GameState, DataCatalog, EventBus, TimeSystem.
class_name BaseVisual
extends Control

signal room_selected(room_id: String)
signal surface_selected(slot_id: String)

const BACKGROUND_PATH := "res://assets/environments/base_scenes/bunker_cutaway.png"

var elena_texture: Texture2D
var background_texture: Texture2D
var elena_pos := Vector2.ZERO
var elena_target := Vector2.ZERO
var walk_interval := 5.0
var hover_id := ""
var gate_open_anim := 0.0
var damage_flash := 0.0

const GATE_DOOR_RECT := Rect2(0.415, 0.31, 0.17, 0.10)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	elena_texture = load("res://assets/characters/elena/elena_late.svg" if TimeSystem.current_day >= 200 else "res://assets/characters/elena/elena_early.svg")
	background_texture = load(BACKGROUND_PATH) as Texture2D
	_reset_elena_position()
	if not EventBus.stats_changed.is_connected(_on_state_changed):
		EventBus.stats_changed.connect(_on_state_changed)
	if not EventBus.inventory_changed.is_connected(_on_state_changed):
		EventBus.inventory_changed.connect(_on_state_changed)
	if not EventBus.base_wave_damage.is_connected(_on_wave_damage):
		EventBus.base_wave_damage.connect(_on_wave_damage)
	var elena_timer := Timer.new()
	elena_timer.name = "ElenaWalkTimer"
	elena_timer.wait_time = walk_interval
	elena_timer.autostart = true
	elena_timer.timeout.connect(_on_elena_walk_tick)
	add_child(elena_timer)
	set_process(false)


func _on_elena_walk_tick() -> void:
	if elena_pos.distance_to(elena_target) > 1.5:
		return
	_pick_elena_destination()
	_ensure_animating()


func _ensure_animating() -> void:
	if not is_processing():
		set_process(true)


func _needs_process() -> bool:
	var target_gate: float = 1.0 if GameState.is_room_unlocked("surface_gate") else 0.0
	if not is_equal_approx(gate_open_anim, target_gate):
		return true
	if damage_flash > 0.0:
		return true
	if elena_pos.distance_to(elena_target) > 1.5:
		return true
	return false


func _process(delta: float) -> void:
	var target_gate: float = 1.0 if GameState.is_room_unlocked("surface_gate") else 0.0
	if not is_equal_approx(gate_open_anim, target_gate):
		gate_open_anim = move_toward(gate_open_anim, target_gate, delta * 1.8)
		queue_redraw()
	if damage_flash > 0.0:
		damage_flash = maxf(0.0, damage_flash - delta * 1.6)
		queue_redraw()
	if elena_pos.distance_to(elena_target) > 1.5:
		elena_pos = elena_pos.lerp(elena_target, clampf(delta * 2.4, 0.0, 1.0))
		queue_redraw()
	if not _needs_process():
		set_process(false)


func _on_wave_damage(_amount: float) -> void:
	damage_flash = 1.0
	queue_redraw()
	_ensure_animating()


func _on_state_changed() -> void:
	_reset_elena_position()
	queue_redraw()
	_ensure_animating()


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
	_ensure_animating()


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var tex := background_texture
	if tex == null:
		tex = load(BACKGROUND_PATH) as Texture2D
		background_texture = tex
	if tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, s), false, Color(1, 1, 1, 1.0))
	else:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.06, 0.07))
	_draw_gate_doors(s)
	_draw_tower_spotlights(s)
	for room_id in DataCatalog.base_rooms:
		_draw_zone(str(room_id))
	_draw_elena()
	_draw_status(s)
	if damage_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.9, 0.25, 0.18, damage_flash * 0.22))


func _draw_zone(room_id: String) -> void:
	var data := DataCatalog.base_room(room_id)
	if data.is_empty():
		return
	var rect := _room_rect(data, size)
	var unlocked := GameState.is_room_unlocked(room_id)
	var hovered := hover_id == room_id
	var is_bunker := str(data.get("zone", "")) == "bunker"
	if not unlocked:
		var veil: Color = Color(0.0, 0.0, 0.0, 0.82 if is_bunker else 0.72)
		draw_rect(rect, veil)
		draw_rect(rect, Color(0.55, 0.62, 0.68, 0.38), false, 1.5)
		_draw_centered_text("?", rect, 24, Color(0.72, 0.76, 0.82, 0.82))
		return
	if str(data.get("zone", "")) == "surface":
		var placed := GameState.surface_placement(room_id)
		if hovered:
			draw_rect(rect, Color(0.85, 0.72, 0.28, 0.14))
		draw_rect(rect, Color(0.78, 0.84, 0.92, 0.22), false, 1.0 if not hovered else 2.0)
		if placed.is_empty():
			_draw_centered_text("+", rect, 22, Color(0.92, 0.86, 0.55, 0.9))
	else:
		if hovered:
			draw_rect(rect, Color(0.45, 0.72, 0.95, 0.12))
		draw_rect(rect, Color(0.62, 0.78, 0.95, 0.18), false, 1.0 if not hovered else 2.0)
		var linked := str(data.get("structure_id", ""))
		if not linked.is_empty():
			var level := int(GameState.base_state.structures.get(linked, 0))
			if level > 0:
				_draw_centered_text("St.%d" % level, rect, 12, Color(0.92, 0.82, 0.45, 0.95))
		_draw_bunker_door_hint(room_id, rect)
		if room_id == "elena_quarters":
			draw_rect(rect, Color(0.55, 0.08, 0.06, 0.12))


func _draw_tower_spotlights(canvas: Vector2) -> void:
	if not GameState.is_room_unlocked("surface_west_tower") and not GameState.is_room_unlocked("surface_east_tower"):
		return
	for tower_id in ["surface_west_tower", "surface_east_tower"]:
		if not GameState.is_room_unlocked(tower_id):
			continue
		var data := DataCatalog.base_room(tower_id)
		var rect := _room_rect(data, canvas)
		var apex := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.85)
		var spread := rect.size.x * 1.6
		var ground_y := canvas.y * 0.48
		var left := Vector2(apex.x - spread, ground_y)
		var right := Vector2(apex.x + spread, ground_y)
		draw_colored_polygon(PackedVector2Array([apex, left, right]), Color(0.95, 0.88, 0.62, 0.08))


func _draw_gate_doors(canvas: Vector2) -> void:
	if gate_open_anim <= 0.02 and not GameState.is_room_unlocked("surface_gate"):
		return
	var gate_rect := Rect2(
		GATE_DOOR_RECT.position.x * canvas.x,
		GATE_DOOR_RECT.position.y * canvas.y,
		GATE_DOOR_RECT.size.x * canvas.x,
		GATE_DOOR_RECT.size.y * canvas.y
	)
	var slide := gate_rect.size.x * 0.22 * gate_open_anim
	var door_h := gate_rect.size.y * 0.92
	var door_w := gate_rect.size.x * 0.46
	var door_y := gate_rect.position.y + (gate_rect.size.y - door_h) * 0.5
	var left := Rect2(gate_rect.position.x - slide, door_y, door_w, door_h)
	var right := Rect2(gate_rect.position.x + gate_rect.size.x - door_w + slide, door_y, door_w, door_h)
	draw_rect(left, Color(0.22, 0.23, 0.25, 0.92))
	draw_rect(right, Color(0.22, 0.23, 0.25, 0.92))
	draw_rect(left, Color(0.45, 0.46, 0.48, 0.55), false, 1.0)
	draw_rect(right, Color(0.45, 0.46, 0.48, 0.55), false, 1.0)


func _draw_bunker_door_hint(room_id: String, rect: Rect2) -> void:
	if room_id == "shaft_room":
		return
	var door_w := rect.size.x * 0.18
	var door_h := rect.size.y * 0.55
	var door_rect := Rect2(rect.position.x + rect.size.x * 0.5 - door_w * 0.5, rect.position.y + rect.size.y * 0.08, door_w, door_h)
	draw_rect(door_rect, Color(0.18, 0.17, 0.16, 0.35))
	draw_rect(door_rect, Color(0.55, 0.50, 0.42, 0.25), false, 1.0)


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
	var bar := Rect2(14, s.y - 24, s.x - 28, 12)
	draw_rect(bar, Color(0.02, 0.02, 0.03, 0.42))
	var integrity := clampf(float(GameState.base_state.integrity) / maxf(1.0, float(GameState.base_state.max_integrity)), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * integrity, bar.size.y)), Color(0.38, 0.72, 0.42, 0.78))


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
