@tool
extends EditorScript

const BakeScript := preload("res://scripts/dev/weapon_tileset_bake.gd")

func _run() -> void:
	var result: Dictionary = BakeScript.save_all()
	print("Weapon tileset bake finished: ", result)
