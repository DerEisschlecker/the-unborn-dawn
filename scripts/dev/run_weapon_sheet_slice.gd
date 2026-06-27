@tool
extends EditorScript

const SlicerScript := preload("res://scripts/dev/weapon_sheet_slicer.gd")

func _run() -> void:
	var result: Dictionary = SlicerScript.slice_all()
	print("Weapon sheet slice finished: ", result)
