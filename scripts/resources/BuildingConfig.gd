class_name BuildingConfig
extends Resource

@export var id: StringName = &"building"
@export var display_name: String = "建筑"

@export var texture: Texture2D
@export var size_in_cells: Vector2i = Vector2i.ONE
@export var building_scene: PackedScene = null

@export_group("Cost")
@export var cost_resource_id: StringName = &"gold"
@export var cost: int = 0

@export_group("Production")
@export var production_resource_id: StringName = &""
@export var production_amount: int = 0
@export var production_interval: float = 3.0


func has_production() -> bool:
	if String(production_resource_id) == "":
		return false

	if production_amount == 0:
		return false

	if production_interval <= 0.0:
		return false

	return true
