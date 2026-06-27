# Purpose: Invisible pick volume mapping 3D clicks to bunker/surface room ids.
# Public API: room_id identifies the gameplay zone for selection.
class_name BaseRoomZone
extends Area3D

@export var room_id: String = ""
@export var zone_type: String = "bunker"
