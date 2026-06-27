# Purpose: Compact combat UI frames for abilities, actions, and icon buttons.
# Public API: apply_ability_button(), apply_action_button(), apply_icon_button().
# Dependencies: None.
class_name CombatUiStyles
extends RefCounted

const GOLD_BORDER := Color(0.58, 0.40, 0.18, 0.92)
const GOLD_BORDER_HOVER := Color(0.72, 0.52, 0.28, 0.96)


static func _flat_box(bg: Color, border: Color, border_width: int = 2, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


static func ability_style(state: String, accent: Color = GOLD_BORDER) -> StyleBoxFlat:
	match state:
		"hover":
			return _flat_box(Color(0.10, 0.08, 0.06, 0.96), accent.lightened(0.14), 2, 4)
		"pressed":
			return _flat_box(Color(0.05, 0.04, 0.04, 0.98), accent.darkened(0.08), 2, 4)
		"disabled":
			return _flat_box(Color(0.03, 0.03, 0.035, 0.55), Color(0.30, 0.28, 0.26, 0.45), 1, 4)
		"cooldown":
			return _flat_box(Color(0.04, 0.03, 0.05, 0.80), Color(0.48, 0.30, 0.58, 0.82), 2, 4)
		_:
			return _flat_box(Color(0.07, 0.05, 0.04, 0.94), accent, 2, 4)


static func apply_ability_button(
	button: Button,
	accent: Color = GOLD_BORDER,
	disabled: bool = false,
	on_cooldown: bool = false
) -> void:
	button.flat = true
	var base_state: String = "disabled" if disabled else ("cooldown" if on_cooldown else "normal")
	button.add_theme_stylebox_override("normal", ability_style(base_state, accent))
	button.add_theme_stylebox_override("hover", ability_style("hover", accent))
	button.add_theme_stylebox_override("pressed", ability_style("pressed", accent))
	button.add_theme_stylebox_override("disabled", ability_style("disabled", accent))
	button.add_theme_stylebox_override("focus", ability_style("hover", accent))


static func action_style(state: String) -> StyleBoxFlat:
	match state:
		"hover":
			return _flat_box(Color(0.11, 0.08, 0.05, 0.96), GOLD_BORDER_HOVER, 2, 6)
		"pressed":
			return _flat_box(Color(0.05, 0.04, 0.03, 0.98), GOLD_BORDER.darkened(0.08), 2, 6)
		"disabled":
			return _flat_box(Color(0.03, 0.03, 0.035, 0.60), Color(0.28, 0.26, 0.24, 0.50), 1, 6)
		_:
			return _flat_box(Color(0.08, 0.06, 0.04, 0.94), GOLD_BORDER, 2, 6)


static func apply_action_button(button: Button) -> void:
	button.flat = true
	button.add_theme_stylebox_override("normal", action_style("normal"))
	button.add_theme_stylebox_override("hover", action_style("hover"))
	button.add_theme_stylebox_override("pressed", action_style("pressed"))
	button.add_theme_stylebox_override("disabled", action_style("disabled"))
	button.add_theme_stylebox_override("focus", action_style("hover"))


static func icon_style(state: String) -> StyleBoxFlat:
	match state:
		"hover":
			return _flat_box(Color(0.09, 0.07, 0.05, 0.95), GOLD_BORDER_HOVER, 2, 6)
		"pressed":
			return _flat_box(Color(0.04, 0.03, 0.03, 0.98), GOLD_BORDER.darkened(0.06), 2, 6)
		_:
			return _flat_box(Color(0.06, 0.05, 0.04, 0.90), GOLD_BORDER, 2, 6)


static func apply_icon_button(button: Button) -> void:
	button.flat = true
	button.add_theme_stylebox_override("normal", icon_style("normal"))
	button.add_theme_stylebox_override("hover", icon_style("hover"))
	button.add_theme_stylebox_override("pressed", icon_style("pressed"))
	button.add_theme_stylebox_override("focus", icon_style("hover"))
	button.add_theme_stylebox_override("disabled", action_style("disabled"))


static func square_slot_style(state: String, accent: Color = GOLD_BORDER) -> StyleBoxFlat:
	match state:
		"hover":
			return _flat_box(Color(0.11, 0.08, 0.05, 0.98), accent.lightened(0.16), 2, 3)
		"pressed":
			return _flat_box(Color(0.04, 0.03, 0.03, 0.98), accent.darkened(0.10), 2, 3)
		"disabled":
			return _flat_box(Color(0.025, 0.025, 0.03, 0.62), Color(0.28, 0.26, 0.24, 0.48), 1, 3)
		"cooldown":
			return _flat_box(Color(0.05, 0.03, 0.06, 0.86), Color(0.50, 0.32, 0.62, 0.88), 2, 3)
		_:
			return _flat_box(Color(0.08, 0.06, 0.04, 0.96), accent, 2, 3)


static func apply_square_slot_button(
	button: Button,
	accent: Color = GOLD_BORDER,
	disabled: bool = false,
	on_cooldown: bool = false
) -> void:
	button.flat = true
	var base_state: String = "disabled" if disabled else ("cooldown" if on_cooldown else "normal")
	button.add_theme_stylebox_override("normal", square_slot_style(base_state, accent))
	button.add_theme_stylebox_override("hover", square_slot_style("hover", accent))
	button.add_theme_stylebox_override("pressed", square_slot_style("pressed", accent))
	button.add_theme_stylebox_override("disabled", square_slot_style("disabled", accent))
	button.add_theme_stylebox_override("focus", square_slot_style("hover", accent))
