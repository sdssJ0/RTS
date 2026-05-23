class_name BuildingManager
extends Node

signal building_placed(building: BasicBuilding, config: BuildingConfig, cell: Vector2i)

@export var building_root_path: NodePath = "../../World2D/BuildingRoot"

@onready var building_root: Node2D = get_node_or_null(building_root_path) as Node2D


func _ready() -> void:
	if building_root == null:
		push_error("BuildingManager: BuildingRoot not found. Path = " + str(building_root_path))

	TurnSystem.turn_started.connect(_on_turn_started)

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

	if produced_count > 0:
		print("BuildingManager: turn produce. faction=", faction_id, " buildings=", produced_count)


func try_place_building(config: BuildingConfig, cell: Vector2i) -> bool:
	if config == null:
		push_error("BuildingManager: config is null.")
		return false

	if building_root == null:
		push_error("BuildingManager: building_root is null.")
		return false

	var building_scene: PackedScene = _get_building_scene_from_config(config)

	if building_scene == null:
		push_error("BuildingManager: missing building scene for " + str(config.display_name))
		return false

	var size_in_cells: Vector2i = config.size_in_cells
	var active_faction_id: StringName = FactionSystem.active_faction_id

	if active_faction_id == &"":
		push_warning("BuildingManager: active faction is empty.")
		return false

	if not GridSystem.can_place_area(cell, size_in_cells):
		print("BuildingManager: cannot place at ", cell, " - grid blocked.")
		return false

	if not TerritoryService.is_area_owned_by_faction(cell, size_in_cells, active_faction_id):
		print("BuildingManager: cannot place at ", cell, " - not owned by ", active_faction_id)
		return false

	if not EconomySystem.can_afford_config(active_faction_id, config):
		print("BuildingManager: cannot place ", config.display_name, " - not enough ", config.cost_resource_id)
		return false

	if not EconomySystem.try_spend_config(active_faction_id, config):
		push_error("BuildingManager: spend failed unexpectedly.")
		return false

	var instance: Node = building_scene.instantiate()

	if instance == null:
		push_error("BuildingManager: instantiate returned null.")
		return false

	var building: BasicBuilding = instance as BasicBuilding

	if building == null:
		push_error("BuildingManager: building scene root is not BasicBuilding (got " + instance.get_class() + ")")
		instance.queue_free()
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

	print("BuildingManager: placed ", config.display_name, " at ", cell, " for ", active_faction_id)

	emit_signal("building_placed", building, config, cell)

	return true


func _get_building_scene_from_config(config: BuildingConfig) -> PackedScene:
	if config == null:
		return null

	var scene_value: Variant = config.get("scene")
	if scene_value is PackedScene:
		return scene_value as PackedScene

	scene_value = config.get("building_scene")
	if scene_value is PackedScene:
		return scene_value as PackedScene

	return null
