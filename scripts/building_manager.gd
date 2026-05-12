class_name BuildingManager
extends Node

signal building_placed(building: BasicBuilding, config: BuildingConfig, cell: Vector2i)

@export var grid_system_path: NodePath = "../GridSystem"
@export var building_root_path: NodePath = "../../World2D/BuildingRoot"
@export var building_scene: PackedScene

@onready var grid_system: GridSystem = get_node(grid_system_path)
@onready var building_root: Node2D = get_node(building_root_path)

func try_place_building(config: BuildingConfig, cell: Vector2i) -> bool:
	if config == null:
		push_error("BuildingManager: config is null.")
		return false

	if building_scene == null:
		push_error("BuildingManager: building_scene is not assigned.")
		return false

	if not grid_system.can_place_area(cell, config.size_in_cells):
		print("Cannot place building. Area occupied:", cell, " size:", config.size_in_cells)
		return false

	var building := building_scene.instantiate() as BasicBuilding

	if building == null:
		push_error("BuildingManager: building_scene root must be BasicBuilding.")
		return false

	building_root.add_child(building)

	building.position = grid_system.cell_to_world(cell)
	building.setup(config, cell)

	grid_system.occupy_area(cell, config.size_in_cells, building)

	emit_signal("building_placed", building, config, cell)

	return true
