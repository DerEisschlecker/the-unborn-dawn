# Purpose: Generic editable data container used by item, enemy, recipe, building, wave, and location .tres files.
# Public API: The exported entries dictionary is read by DataCatalog.
# Dependencies: None.
class_name CatalogData
extends Resource

@export var entries: Dictionary = {}

