extends SceneTree

const BakeScript := preload("res://scripts/dev/character_atlas_bake.gd")


func _initialize() -> void:
	var result: Dictionary = BakeScript.bake_all()
	print("Character atlas bake finished: ", result)
	quit(0)
