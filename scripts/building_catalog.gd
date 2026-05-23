extends Node

@export var building_configs: Array[BuildingConfig] = []


func _ready() -> void:
	if building_configs.is_empty():
		building_configs = [
			preload("res://resources/bulidings/farm.tres"),
			preload("res://resources/bulidings/house.tres"),
			preload("res://resources/bulidings/mine.tres"),
		]


func get_all_configs() -> Array[BuildingConfig]:
	return building_configs
