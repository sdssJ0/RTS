class_name BuildingManager
extends Node

signal building_placed(building: BasicBuilding, config: BuildingConfig, cell: Vector2i)

@export var building_root_path: NodePath = "../../World2D/BuildingRoot"

@onready var building_root: Node2D = get_node_or_null(building_root_path) as Node2D


func _ready() -> void:
	if building_root == null:
		push_error("BuildingManager: BuildingRoot not found. Path = " + str(building_root_path))

	TurnSystem.turn_started.connect(_on_turn_started)
#调试代码
	print("BuildingManager ready.")


func _on_turn_started(faction_id: StringName) -> void:
	if building_root == null:
		return

	var produced_count: int = 0

	for child in building_root.get_children():
		var building: BasicBuilding = child as BasicBuilding
		if building == null:
			continue
		if building.owner_faction_id != faction_id:
			continue

		building.produce_one_cycle()
		produced_count += 1

	print("BuildingManager: turn produce. faction=", faction_id, " buildings=", produced_count)


func try_place_building(config: BuildingConfig, cell: Vector2i) -> bool:
	print("")
	print("========== BuildingManager.try_place_building ==========")

	if config == null:
		push_error("BuildingManager: config is null.")
		print("========================================================")
		return false

	print("BuildingManager: config =", config.display_name)
	print("BuildingManager: target cell =", cell)

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
	var active_faction_id: StringName = FactionSystem.active_faction_id

	var grid_can_place: bool = GridSystem.can_place_area(cell, size_in_cells)
	var area_owned: bool = TerritoryService.is_area_owned_by_faction(
		cell,
		size_in_cells,
		active_faction_id
	)
	var can_afford: bool = EconomySystem.can_afford_config(active_faction_id, config)

	print("BuildingManager place check:")
	print("  active_faction_id =", active_faction_id)
	print("  cell =", cell)
	print("  size =", size_in_cells)
	print("  cell owner =", TerritoryService.get_cell_owner(cell))
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
		print("  Cell owner =", TerritoryService.get_cell_owner(cell))
		print("========================================================")
		return false

	if not can_afford:
		print("BuildingManager: cannot place. Not enough resources.")
		print("  Cost Resource =", config.cost_resource_id)
		print("  Cost =", config.cost)
		print("========================================================")
		return false

	if not EconomySystem.try_spend_config(active_faction_id, config):
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
	building.is_preview = false
	building.owner_faction_id = active_faction_id
	building.owner_texture = TerritoryService.get_building_texture_for_faction(
		active_faction_id,
		config
	)

	building.position = GridSystem.cell_to_world(cell)

	building_root.add_child(building)

	building.apply_config_visual()
	building.apply_owner_visual()

	GridSystem.occupy_area(cell, size_in_cells, building)

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
