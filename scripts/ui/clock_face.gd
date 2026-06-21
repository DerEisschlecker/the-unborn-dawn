# Purpose: Small HUD clock face that visualizes the current campaign hour.
# Public API: set_hour().
extends Control

var hour := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hour(value: int) -> void:
	hour = clampi(value, 0, 23)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.46
	var center := size * 0.5
	draw_circle(center, radius, Color(0.025, 0.03, 0.038, 0.94))
	draw_arc(center, radius, 0.0, TAU, 32, Color("#d8b36a"), 2.0, true)
	for mark in range(12):
		var angle := -PI * 0.5 + float(mark) / 12.0 * TAU
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 2.0)
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - 6.0)
		draw_line(inner, outer, Color(0.55, 0.48, 0.34, 0.86), 1.0, true)
	var hand_angle := -PI * 0.5 + float(hour % 12) / 12.0 * TAU
	var hand_end := center + Vector2(cos(hand_angle), sin(hand_angle)) * (radius * 0.62)
	draw_line(center, hand_end, Color("#f0b84c"), 3.0, true)
	draw_circle(center, 3.0, Color("#f0b84c"))
