class_name BuildingManager
extends Node

signal building_placed(building: BasicBuilding, cell: Vector2i)

@export var grid_system_path: NodePath = "../GridSystem"
@export var building_root_path: NodePath = "../../World2D/BuildingRoot"

@onready var grid_system: GridSystem = get_node(grid_system_path)
@onready var building_root: Node2D = get_node(building_root_path)

func try_place_building(building_scene: PackedScene, cell: Vector2i) -> bool:
	if building_scene == null:
		push_error("Building scene is null.")
		return false

	if not grid_system.can_place_at(cell):
		print("This cell is already occupied:", cell)
		return false

	var building := building_scene.instantiate() as BasicBuilding

	if building == null:
		push_error("Building scene root must be BasicBuilding with BasicBuilding.gd attached.")
		return false

	building_root.add_child(building)

	building.position = grid_system.cell_to_world(cell)
	building.setup(cell)

	grid_system.occupy_cell(cell, building)

	building_placed.emit(building, cell)

	return true
