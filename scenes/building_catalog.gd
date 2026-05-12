class_name BuildingCatalog
extends Node

@export var building_configs: Array[BuildingConfig] = []

func get_all_configs() -> Array[BuildingConfig]:
	return building_configs
