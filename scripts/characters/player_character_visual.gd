# Purpose: Renders player appearance via idle/hit atlas loops or static portrait texture.
# Public API: setup(gender, appearance, context), play_hit().
# Dependencies: GameState, MaraHollowIdleFrames, MaraHollowHitFrames, PriestIdleFrames, PriestHitFrames, CharacterVisualContext.
class_name PlayerCharacterVisual
extends Control

enum Clip {
	IDLE,
	HIT,
}

var _display: TextureRect
var _gender := "female"
var _appearance := "priest"
var _context: CharacterVisualContext.Context = CharacterVisualContext.Context.SHOWCASE
var _animated := false
var _clip: Clip = Clip.IDLE
var _frame_index := 1
var _frame_time := 0.0
var _atlas_view: AtlasTexture
var _idle_atlas: Texture2D
var _hit_atlas: Texture2D

static var _atlas_cache: Dictionary = {}


func setup(
	gender: String,
	appearance: String,
	context: CharacterVisualContext.Context = CharacterVisualContext.Context.SHOWCASE
) -> void:
	var same_config := _gender == gender and _appearance == appearance and _context == context
	_gender = gender
	_appearance = appearance
	_context = context
	_animated = GameState.appearance_uses_idle_animation(_appearance)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if same_config and _clip == Clip.HIT:
		return
	_rebuild()


func play_hit() -> void:
	if not _animated or not GameState.appearance_has_hit_animation(_appearance):
		return
	if not is_instance_valid(_atlas_view):
		return
	_start_hit_clip()


func is_playing_hit() -> bool:
	return _clip == Clip.HIT


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_display = TextureRect.new()
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
	_clip = Clip.IDLE
	_frame_index = 1
	_frame_time = 0.0
	_atlas_view = null
	_idle_atlas = null
	_hit_atlas = null
	if _animated:
		_atlas_view = AtlasTexture.new()
		_idle_atlas = _load_atlas(_idle_atlas_path())
		if GameState.appearance_has_hit_animation(_appearance):
			_hit_atlas = _load_atlas(_hit_atlas_path())
		_atlas_view.atlas = _idle_atlas
		_apply_current_frame()
		_display.texture = _atlas_view
		set_process(true)
	else:
		_display.texture = load(GameState.player_appearance_path(_gender, _appearance, _context))
		set_process(false)


func _process(delta: float) -> void:
	if not _animated or not is_instance_valid(_display) or _atlas_view == null:
		return
	_frame_time += delta
	if _frame_time < _current_frame_duration():
		return
	_frame_time = 0.0
	var frame_count := _current_frame_count()
	if frame_count <= 0:
		return
	if _clip == Clip.HIT:
		if _frame_index >= frame_count:
			_resume_idle_clip()
			return
		_frame_index += 1
	else:
		_frame_index = (_frame_index % frame_count) + 1
	_apply_current_frame()


func _start_hit_clip() -> void:
	_clip = Clip.HIT
	_frame_index = 1
	_frame_time = 0.0
	_atlas_view.atlas = _hit_atlas
	_apply_current_frame()
	if is_instance_valid(_display):
		_display.texture = _atlas_view
	set_process(true)


func _resume_idle_clip() -> void:
	_clip = Clip.IDLE
	_frame_index = 1
	_frame_time = 0.0
	_atlas_view.atlas = _idle_atlas
	_apply_current_frame()


func _apply_current_frame() -> void:
	_atlas_view.region = _current_frame_region(_frame_index)
	_atlas_view.emit_changed()


func _load_atlas(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _atlas_cache.has(path):
		return _atlas_cache[path]
	var texture: Texture2D = load(path)
	_atlas_cache[path] = texture
	return texture


func _idle_atlas_path() -> String:
	match _appearance:
		"mara_hollow":
			return MaraHollowIdleFrames.atlas_path(_context)
		"priest":
			return PriestIdleFrames.atlas_path(_context)
		_:
			return ""


func _hit_atlas_path() -> String:
	match _appearance:
		"mara_hollow":
			return MaraHollowHitFrames.atlas_path(_context)
		"priest":
			return PriestHitFrames.atlas_path(_context)
		_:
			return ""


func _current_frame_region(index: int) -> Rect2:
	if _clip == Clip.HIT:
		match _appearance:
			"mara_hollow":
				return MaraHollowHitFrames.frame_region(index, _context)
			"priest":
				return PriestHitFrames.frame_region(index, _context)
			_:
				return Rect2()
	match _appearance:
		"mara_hollow":
			return MaraHollowIdleFrames.frame_region(index, _context)
		"priest":
			return PriestIdleFrames.frame_region(index, _context)
		_:
			return Rect2()


func _current_frame_count() -> int:
	if _clip == Clip.HIT:
		match _appearance:
			"mara_hollow":
				return MaraHollowHitFrames.FRAME_COUNT
			"priest":
				return PriestHitFrames.FRAME_COUNT
			_:
				return 0
	match _appearance:
		"mara_hollow":
			return MaraHollowIdleFrames.FRAME_COUNT
		"priest":
			return PriestIdleFrames.FRAME_COUNT
		_:
			return 0


func _current_frame_duration() -> float:
	if _clip == Clip.HIT:
		match _appearance:
			"mara_hollow":
				return MaraHollowHitFrames.frame_duration()
			"priest":
				return PriestHitFrames.frame_duration()
			_:
				return 1.0 / 16.0
	match _appearance:
		"mara_hollow":
			return MaraHollowIdleFrames.frame_duration()
		"priest":
			return PriestIdleFrames.frame_duration()
		_:
			return 1.0 / 16.0
