class_name BuildingManager
extends Node

signal building_placed(building: BasicBuilding, config: BuildingConfig, cell: Vector2i)

@export var grid_system_path: NodePath = "../GridSystem"
@export var economy_system_path: NodePath = "../EconomySystem"
@export var territory_system_path: NodePath = "../TerritorySystem"
@export var building_root_path: NodePath = "../../World2D/BuildingRoot"

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem
@onready var economy_system: EconomySystem = get_node_or_null(economy_system_path) as EconomySystem
@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem
@onready var building_root: Node2D = get_node_or_null(building_root_path) as Node2D


func _ready() -> void:
	if grid_system == null:
		push_error("BuildingManager: GridSystem not found. Path = " + str(grid_system_path))

	if economy_system == null:
		push_error("BuildingManager: EconomySystem not found. Path = " + str(economy_system_path))

	if territory_system == null:
		push_error("BuildingManager: TerritorySystem not found. Path = " + str(territory_system_path))

	if building_root == null:
		push_error("BuildingManager: BuildingRoot not found. Path = " + str(building_root_path))
#调试代码
	print("BuildingManager ready.")


func try_place_building(config: BuildingConfig, cell: Vector2i) -> bool:
	print("")
	print("========== BuildingManager.try_place_building ==========")

	if config == null:
		push_error("BuildingManager: config is null.")
		print("========================================================")
		return false

	print("BuildingManager: config =", config.display_name)
	print("BuildingManager: target cell =", cell)

	if grid_system == null:
		push_error("BuildingManager: grid_system is null.")
		print("========================================================")
		return false

	if economy_system == null:
		push_error("BuildingManager: economy_system is null.")
		print("========================================================")
		return false

	if territory_system == null:
		push_error("BuildingManager: territory_system is null.")
		print("========================================================")
		return false

	if building_root == null:
		push_error("BuildingManager: building_root is null.")
		print("========================================================")
		return false

	var building_scene: PackedScene = _get_building_scene_from_config(config)

	if building_scene == null:
		push_error("BuildingManager: building scene is null for config: " + str(config.display_name))
		print("BuildingManager: 请检查 BuildingConfig.tres 里是否配置了 scene 或 building_scene。")
		print("========================================================")
		return false

	var size_in_cells: Vector2i = config.size_in_cells
	var active_faction_id: StringName = territory_system.get_active_faction_id()

	var grid_can_place: bool = grid_system.can_place_area(cell, size_in_cells)
	var area_owned: bool = territory_system.is_area_owned_by_faction(
		cell,
		size_in_cells,
		active_faction_id
	)
	var can_afford: bool = economy_system.can_afford_config(config)

	print("BuildingManager place check:")
	print("  active_faction_id =", active_faction_id)
	print("  cell =", cell)
	print("  size =", size_in_cells)
	print("  cell owner =", territory_system.get_cell_owner(cell))
	print("  grid can place =", grid_can_place)
	print("  area owned by faction =", area_owned)
	print("  can afford =", can_afford)
	print("  cost resource =", config.cost_resource_id)
	print("  cost =", config.cost)

	if active_faction_id == &"":
		push_warning("BuildingManager: active faction is empty.")
		print("========================================================")
		return false

	if not grid_can_place:
		print("BuildingManager: cannot place. Grid area occupied or invalid.")
		print("  Failed cell =", cell)
		print("========================================================")
		return false

	if not area_owned:
		print("BuildingManager: cannot place. Area not owned by active faction.")
		print("  Active faction =", active_faction_id)
		print("  Cell owner =", territory_system.get_cell_owner(cell))
		print("========================================================")
		return false

	if not can_afford:
		print("BuildingManager: cannot place. Not enough resources.")
		print("  Cost Resource =", config.cost_resource_id)
		print("  Cost =", config.cost)
		print("========================================================")
		return false

	if not economy_system.try_spend_config(config):
		print("BuildingManager: cannot place. Spend failed.")
		print("========================================================")
		return false

	var instance: Node = building_scene.instantiate()

	if instance == null:
		push_error("BuildingManager: instantiate returned null.")
		print("========================================================")
		return false

	var building: BasicBuilding = instance as BasicBuilding

	if building == null:
		push_error("BuildingManager: building scene root is not BasicBuilding.")
		print("BuildingManager: instantiated root class =", instance.get_class())
		print("BuildingManager: 请确认真实建筑场景的根节点挂载了 BasicBuilding.gd。")
		instance.queue_free()
		print("========================================================")
		return false

	building.config = config
	building.grid_cell = cell
	building.economy_system = economy_system
	building.is_preview = false
	building.owner_faction_id = active_faction_id
	building.owner_texture = territory_system.get_building_texture_for_faction(
		active_faction_id,
		config
	)

	building.position = grid_system.cell_to_world(cell)

	building_root.add_child(building)

	building.apply_config_visual()
	building.apply_owner_visual()

	grid_system.occupy_area(cell, size_in_cells, building)

	print("BuildingManager: building placed successfully.")
	print("  Building =", config.display_name)
	print("  Cell =", cell)
	print("  Faction =", active_faction_id)
	print("========================================================")

	emit_signal("building_placed", building, config, cell)#释放放置信号

	return true


func _get_building_scene_from_config(config: BuildingConfig) -> PackedScene:
	if config == null:
		print("BuildingManager: config is null when getting scene.")
		return null

	print("BuildingManager: checking building scene for config:", config.display_name)

	var scene_value: Variant = config.get("scene")

	if scene_value is PackedScene:
		print("BuildingManager: found scene field.")
		return scene_value as PackedScene

	scene_value = config.get("building_scene")

	if scene_value is PackedScene:
		print("BuildingManager: found building_scene field.")
		return scene_value as PackedScene

	print("BuildingManager: no scene or building_scene found in config:", config.display_name)
	print("BuildingManager: config resource path =", config.resource_path)

	return null
