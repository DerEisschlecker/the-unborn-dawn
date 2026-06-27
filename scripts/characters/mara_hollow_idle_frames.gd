# Purpose: Frame paths and timing for Dr. Mara Hollow idle animation loop.
# Public API: atlas_path(), frame_region(), frame_duration(), portrait_path().
# Dependencies: res://assets/characters/mara_hollow/idle/*_atlas.png
class_name MaraHollowIdleFrames
extends RefCounted

const FRAME_COUNT := 98
const FRAME_PATH := "res://assets/characters/mara_hollow/idle/stand_%03d.png"
const SHOWCASE_ATLAS := "res://assets/characters/mara_hollow/idle/showcase_atlas.png"
const COMBAT_ATLAS := "res://assets/characters/mara_hollow/idle/combat_atlas.png"
const PORTRAIT_PATH := "res://assets/characters/mara_hollow/idle/portrait.png"
const FRAME_SIZE := Vector2i(560, 752)
const COMBAT_FRAME_SIZE := Vector2i(224, 301)
const COLUMNS := 10
const ANIMATION_FPS := 16.0


static func frame_path(index: int) -> String:
	return FRAME_PATH % clampi(index, 1, FRAME_COUNT)


static func atlas_path(context: CharacterVisualContext.Context = CharacterVisualContext.Context.SHOWCASE) -> String:
	match context:
		CharacterVisualContext.Context.COMBAT:
			return COMBAT_ATLAS
		_:
			return SHOWCASE_ATLAS


static func frame_size(context: CharacterVisualContext.Context = CharacterVisualContext.Context.SHOWCASE) -> Vector2i:
	match context:
		CharacterVisualContext.Context.COMBAT:
			return COMBAT_FRAME_SIZE
		_:
			return FRAME_SIZE


static func portrait_path() -> String:
	return PORTRAIT_PATH


static func frame_region(index: int, context: CharacterVisualContext.Context = CharacterVisualContext.Context.SHOWCASE) -> Rect2:
	var frame_index := clampi(index, 1, FRAME_COUNT) - 1
	var cell_size := frame_size(context)
	var column := frame_index % COLUMNS
	var row := int(frame_index / COLUMNS)
	return Rect2(column * cell_size.x, row * cell_size.y, cell_size.x, cell_size.y)


static func frame_duration() -> float:
	return 1.0 / ANIMATION_FPS
