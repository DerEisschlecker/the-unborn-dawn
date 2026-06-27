# Purpose: Procedural 6x4 exploration grids seeded per location visit.
# Public API: generate(location_id, danger, seed) -> layout dictionary.
extends Object

const MAP_COLUMNS := 6
const MAP_ROWS := 4


static func generate(location_id: String, danger: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [location_id, seed_value])
	var blocked: Array[Vector2i] = []
	var block_count := rng.randi_range(2, 4) + clampi(danger, 0, 4)
	while blocked.size() < block_count:
		var cell := Vector2i(rng.randi_range(1, MAP_COLUMNS - 2), rng.randi_range(0, MAP_ROWS - 1))
		if not blocked.has(cell):
			blocked.append(cell)
	var start := Vector2i(0, rng.randi_range(0, MAP_ROWS - 1))
	var combat := Vector2i(MAP_COLUMNS - 1, rng.randi_range(0, MAP_ROWS - 1))
	var recruit := Vector2i(rng.randi_range(1, MAP_COLUMNS - 2), rng.randi_range(0, MAP_ROWS - 1))
	var hotspot_count := clampi(2 + danger / 2, 2, 4)
	var hotspots: Array[Vector2i] = []
	while hotspots.size() < hotspot_count:
		var spot := Vector2i(rng.randi_range(0, MAP_COLUMNS - 1), rng.randi_range(0, MAP_ROWS - 1))
		if spot == start or spot == combat or spot == recruit or blocked.has(spot) or hotspots.has(spot):
			continue
		hotspots.append(spot)
	return {
		"start": start,
		"hotspots": hotspots,
		"combat": combat,
		"recruit": recruit,
		"blocked": blocked
	}
