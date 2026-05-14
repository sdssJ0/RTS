class_name BuildingManager
extends Node

signal building_placed(building: BasicBuilding, config: BuildingConfig, cell: Vector2i)

@export var grid_system_path: NodePath = "../GridSystem"
@export var economy_system_path: NodePath = "../EconomySystem"
@export var territory_system_path: NodePath = "../TerritorySystem"
@export var building_root_path: NodePath = "../../World2D/BuildingRoot"

@export var building_scene: PackedScene

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem
@onready var economy_system: EconomySystem = get_node_or_null(economy_system_path) as EconomySystem
@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem
@onready var building_root: Node2D = get_node_or_null(building_root_path) as Node2D


func _ready() -> void:
	print("BuildingManager ready.")

	if grid_system == null:
		push_error("BuildingManager: GridSystem not found. Path = " + str(grid_system_path))
	else:
		print("BuildingManager: GridSystem found:", grid_system.name)

	if economy_system == null:
		push_error("BuildingManager: EconomySystem not found. Path = " + str(economy_system_path))
	else:
		print("BuildingManager: EconomySystem found:", economy_system.name)

	if territory_system == null:
		push_error("BuildingManager: TerritorySystem not found. Path = " + str(territory_system_path))
	else:
		print("BuildingManager: TerritorySystem found:", territory_system.name)

	if building_root == null:
		push_error("BuildingManager: BuildingRoot not found. Path = " + str(building_root_path))
	else:
		print("BuildingManager: BuildingRoot found:", building_root.name)

	if building_scene == null:
		push_warning("BuildingManager: Building Scene is not assigned.")
	else:
		print("BuildingManager: Building Scene assigned.")


func try_place_building(config: BuildingConfig, cell: Vector2i) -> bool:
	print("BuildingManager: try_place_building called.")
	print("  Config:", config.display_name if config != null else "null")
	print("  Cell:", cell)

	if config == null:
		print("BuildingManager: config is null.")
		return false

	if grid_system == null:
		print("BuildingManager: grid_system is null.")
		return false

	if economy_system == null:
		print("BuildingManager: economy_system is null.")
		return false

	if territory_system == null:
		print("BuildingManager: territory_system is null.")
		return false

	if building_root == null:
		print("BuildingManager: building_root is null.")
		return false

	if building_scene == null:
		print("BuildingManager: building_scene is not assigned.")
		return false

	if not grid_system.can_place_area(cell, config.size_in_cells):
		print("BuildingManager: cannot place. Area occupied or invalid.")
		print("  Cell:", cell)
		print("  Size:", config.size_in_cells)
		return false

	if not territory_system.is_area_owned(cell, config.size_in_cells):
		print("BuildingManager: cannot place. Not owned territory.")
		print("  Cell:", cell)
		print("  Size:", config.size_in_cells)
		return false

	if not economy_system.can_afford_config(config):
		print("BuildingManager: cannot place. Not enough resource.")
		print("  Cost Resource:", config.cost_resource_id)
		print("  Cost:", config.cost)
		print("  Have:", economy_system.get_resource_amount(config.cost_resource_id))
		return false

	var instance := building_scene.instantiate()
	var building := instance as BasicBuilding

	if building == null:
		print("BuildingManager: building_scene root must be BasicBuilding.")
		instance.queue_free()
		return false

	if not economy_system.try_spend_config(config):
		print("BuildingManager: spend failed.")
		instance.queue_free()
		return false

	building.set_preview_mode(false)
	building.set_economy_system(economy_system)

	building_root.add_child(building)

	var world_position: Vector2 = grid_system.cell_to_world(cell)

	building.global_position = world_position
	building.visible = true
	building.z_as_relative = false
	building.z_index = 100

	building.setup(config, cell)

	grid_system.occupy_area(cell, config.size_in_cells, building)

	print("BuildingManager: building added.")
	print("  Parent:", building.get_parent().name)
	print("  Global position:", building.global_position)
	print("  Visible:", building.visible)
	print("  Z index:", building.z_index)

	emit_signal("building_placed", building, config, cell)

	return true
