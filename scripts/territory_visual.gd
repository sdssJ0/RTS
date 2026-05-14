extends Node2D

@export var grid_system_path: NodePath = "../../Systems/GridSystem"
@export var territory_system_path: NodePath = "../../Systems/TerritorySystem"

@export var border_width: float = 3.0
@export var preview_border_width: float = 2.0

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem
@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem


func _ready() -> void:
	z_as_relative = false
	z_index = 5

	if grid_system == null:
		push_error("TerritoryVisual: GridSystem not found. Path = " + str(grid_system_path))

	if territory_system == null:
		push_error("TerritoryVisual: TerritorySystem not found. Path = " + str(territory_system_path))
	else:
		territory_system.territory_changed.connect(_on_territory_changed)
		territory_system.territory_preview_changed.connect(_on_territory_preview_changed)

	queue_redraw()


func _draw() -> void:
	if grid_system == null:
		return

	if territory_system == null:
		return

	_draw_owned_territory_border()
	_draw_expansion_preview()


func _draw_owned_territory_border() -> void:
	var color: Color = territory_system.country_color
	var cell_size: float = float(grid_system.cell_size)

	var directions: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 0)
	]

	for cell in territory_system.get_owned_cells():
		var world_origin: Vector2 = grid_system.cell_to_world(cell)
		var p: Vector2 = to_local(world_origin)

		var top_left: Vector2 = p
		var top_right: Vector2 = p + Vector2(cell_size, 0)
		var bottom_left: Vector2 = p + Vector2(0, cell_size)
		var bottom_right: Vector2 = p + Vector2(cell_size, cell_size)

		var up: Vector2i = cell + directions[0]
		var down: Vector2i = cell + directions[1]
		var left: Vector2i = cell + directions[2]
		var right: Vector2i = cell + directions[3]

		if not territory_system.is_cell_owned(up):
			draw_line(top_left, top_right, color, border_width, true)

		if not territory_system.is_cell_owned(down):
			draw_line(bottom_left, bottom_right, color, border_width, true)

		if not territory_system.is_cell_owned(left):
			draw_line(top_left, bottom_left, color, border_width, true)

		if not territory_system.is_cell_owned(right):
			draw_line(top_right, bottom_right, color, border_width, true)


func _draw_expansion_preview() -> void:
	if not territory_system.is_expansion_mode:
		return

	var preview_cells: Array[Vector2i] = territory_system.get_preview_cells()

	if preview_cells.is_empty():
		return

	var cell_size: float = float(grid_system.cell_size)
	var fill_color: Color = territory_system.preview_color
	var outline_color: Color = Color(
		fill_color.r,
		fill_color.g,
		fill_color.b,
		0.95
	)

	for i in range(preview_cells.size()):
		var cell: Vector2i = preview_cells[i]
		var world_origin: Vector2 = grid_system.cell_to_world(cell)
		var p: Vector2 = to_local(world_origin)

		var rect: Rect2 = Rect2(
			p,
			Vector2(cell_size, cell_size)
		)

		draw_rect(rect, fill_color, true)
		draw_rect(rect, outline_color, false, preview_border_width)

		var number_position: Vector2 = p + Vector2(4, 14)

		draw_string(
			ThemeDB.fallback_font,
			number_position,
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			outline_color
		)

	for i in range(preview_cells.size() - 1):
		var current_cell: Vector2i = preview_cells[i]
		var next_cell: Vector2i = preview_cells[i + 1]

		var current_center: Vector2 = to_local(
			grid_system.cell_to_world(current_cell)
		) + Vector2(cell_size * 0.5, cell_size * 0.5)

		var next_center: Vector2 = to_local(
			grid_system.cell_to_world(next_cell)
		) + Vector2(cell_size * 0.5, cell_size * 0.5)

		draw_line(
			current_center,
			next_center,
			outline_color,
			preview_border_width,
			true
		)


func _on_territory_changed() -> void:
	queue_redraw()


func _on_territory_preview_changed() -> void:
	queue_redraw()
