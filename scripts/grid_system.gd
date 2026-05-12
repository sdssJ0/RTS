class_name GridSystem
extends Node

@export var cell_size: int = 16

var occupied_cells: Dictionary = {}

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / float(cell_size)),
		floori(world_position.y / float(cell_size))
	)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * cell_size,
		cell.y * cell_size
	)

func snap_world_position(world_position: Vector2) -> Vector2:
	var cell: Vector2i = world_to_cell(world_position)
	return cell_to_world(cell)

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)

func can_place_at(cell: Vector2i) -> bool:
	return not is_cell_occupied(cell)

func occupy_cell(cell: Vector2i, owner: Node) -> void:
	occupied_cells[cell] = owner

func release_cell(cell: Vector2i) -> void:
	if occupied_cells.has(cell):
		occupied_cells.erase(cell)

func get_owner_at_cell(cell: Vector2i) -> Node:
	if occupied_cells.has(cell):
		return occupied_cells[cell]

	return null
