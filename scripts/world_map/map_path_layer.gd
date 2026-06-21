# Purpose: Draws the connected world-map routes behind animated location nodes.
# Public API: configure().
extends Control

var nodes: Dictionary = {}
var route_states: Dictionary = {}


func configure(map_nodes: Dictionary, states: Dictionary) -> void:
	nodes = map_nodes
	route_states = states
	queue_redraw()


func _draw() -> void:
	if nodes.is_empty():
		return
	var drawn := {}
	for node_id in nodes:
		var data: Dictionary = nodes[node_id]
		for neighbor in data.get("neighbors", []):
			var target_id := str(neighbor)
			var edge_key := _edge_key(str(node_id), target_id)
			if drawn.has(edge_key) or not nodes.has(target_id):
				continue
			drawn[edge_key] = true
			var state := str(route_states.get(edge_key, "distant"))
			var color := Color(0.22, 0.24, 0.26, 0.26)
			var width := 2.0
			if state == "available":
				color = Color(0.86, 0.65, 0.32, 0.92)
				width = 4.2
			elif state == "selected":
				var pulse := (sin(float(Time.get_ticks_msec()) * 0.006) + 1.0) * 0.5
				color = Color(0.40, 0.72, 1.0, lerpf(0.72, 0.96, pulse))
				width = lerpf(4.2, 5.8, pulse)
			elif state == "locked":
				color = Color(0.62, 0.18, 0.16, 0.36)
				width = 2.3
			elif state == "current":
				color = Color(0.58, 0.72, 0.96, 0.82)
				width = 3.5
			draw_line(_node_point(str(node_id)), _node_point(target_id), color, width, true)


func _node_point(node_id: String) -> Vector2:
	var data: Dictionary = nodes.get(node_id, {})
	var pos: Vector2 = data.get("pos", Vector2(0.5, 0.5))
	return Vector2(pos.x * size.x, pos.y * size.y)


func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
