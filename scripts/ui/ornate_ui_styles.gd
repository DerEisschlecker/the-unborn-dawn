# Purpose: Shared ornate spike-frame StyleBoxTexture for buttons and text fields.
# Public API: frame_style(), menu_button_style(), list_button_style(), apply_button_theme().
# Dependencies: res://assets/ui/frames/ornate_frame.png
class_name OrnateUiStyles
extends RefCounted

const FRAME_PATH := "res://assets/ui/frames/ornate_frame.png"
const HUD_TOP_BAR_PATH := "res://assets/ui/frames/hud_top_bar.png"
const HUD_BAR_PATCH_LEFT := 96.0
const HUD_BAR_PATCH_TOP := 14.0
const HUD_BAR_PATCH_RIGHT := 96.0
const HUD_BAR_PATCH_BOTTOM := 14.0
const TEXTURE_MARGIN_LEFT := 46.0
const TEXTURE_MARGIN_TOP := 11.0
const TEXTURE_MARGIN_RIGHT := 46.0
const TEXTURE_MARGIN_BOTTOM := 11.0
const CONTENT_MARGIN_LEFT := 50.0
const CONTENT_MARGIN_TOP := 6.0
const CONTENT_MARGIN_RIGHT := 50.0
const CONTENT_MARGIN_BOTTOM := 6.0


static func frame_style(state: String = "normal") -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(FRAME_PATH) as Texture2D
	style.draw_center = true
	style.texture_margin_left = TEXTURE_MARGIN_LEFT
	style.texture_margin_top = TEXTURE_MARGIN_TOP
	style.texture_margin_right = TEXTURE_MARGIN_RIGHT
	style.texture_margin_bottom = TEXTURE_MARGIN_BOTTOM
	style.content_margin_left = CONTENT_MARGIN_LEFT
	style.content_margin_top = CONTENT_MARGIN_TOP
	style.content_margin_right = CONTENT_MARGIN_RIGHT
	style.content_margin_bottom = CONTENT_MARGIN_BOTTOM
	match state:
		"hover":
			style.modulate_color = Color(1.14, 1.10, 1.02, 1.0)
		"pressed":
			style.modulate_color = Color(0.78, 0.74, 0.70, 1.0)
		"disabled":
			style.modulate_color = Color(0.58, 0.58, 0.58, 0.72)
		"focus":
			style.modulate_color = Color(1.18, 1.06, 0.90, 1.0)
		_:
			style.modulate_color = Color(1.0, 1.0, 1.0, 1.0)
	return style


static func menu_button_style(highlighted: bool = false, disabled: bool = false) -> StyleBoxTexture:
	if disabled:
		return frame_style("disabled")
	if highlighted:
		return frame_style("focus")
	return frame_style("normal")


static func list_button_style(highlighted: bool = false, muted: bool = false) -> StyleBoxTexture:
	if highlighted:
		return frame_style("focus")
	if muted:
		return frame_style("disabled")
	return frame_style("normal")


static func apply_button_theme(button: BaseButton, highlighted: bool = false, disabled: bool = false) -> void:
	button.flat = false
	button.add_theme_stylebox_override("normal", menu_button_style(highlighted, disabled))
	button.add_theme_stylebox_override("hover", frame_style("hover"))
	button.add_theme_stylebox_override("pressed", frame_style("pressed"))
	button.add_theme_stylebox_override("focus", frame_style("focus"))
	button.add_theme_stylebox_override("disabled", frame_style("disabled"))


static func apply_input_theme(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", frame_style("normal"))
	input.add_theme_stylebox_override("focus", frame_style("focus"))
	input.add_theme_stylebox_override("read_only", frame_style("disabled"))


static func apply_text_edit_theme(input: TextEdit) -> void:
	input.add_theme_stylebox_override("normal", frame_style("normal"))
	input.add_theme_stylebox_override("focus", frame_style("focus"))
	input.add_theme_stylebox_override("read_only", frame_style("disabled"))


static func hud_bar_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(HUD_TOP_BAR_PATH) as Texture2D
	style.draw_center = true
	style.texture_margin_left = HUD_BAR_PATCH_LEFT
	style.texture_margin_top = HUD_BAR_PATCH_TOP
	style.texture_margin_right = HUD_BAR_PATCH_RIGHT
	style.texture_margin_bottom = HUD_BAR_PATCH_BOTTOM
	style.content_margin_left = 32.0
	style.content_margin_top = 10.0
	style.content_margin_right = 32.0
	style.content_margin_bottom = 10.0
	style.modulate_color = Color(1.0, 1.0, 1.0, 1.0)
	return style


static func configure_hud_bar_patch(bar: NinePatchRect) -> void:
	bar.texture = load(HUD_TOP_BAR_PATH) as Texture2D
	bar.draw_center = true
	bar.patch_margin_left = int(HUD_BAR_PATCH_LEFT)
	bar.patch_margin_top = int(HUD_BAR_PATCH_TOP)
	bar.patch_margin_right = int(HUD_BAR_PATCH_RIGHT)
	bar.patch_margin_bottom = int(HUD_BAR_PATCH_BOTTOM)
	bar.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	bar.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
