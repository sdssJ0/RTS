class_name TerritoryVisual
extends Node2D

@export var territory_system_path: NodePath = "../../Systems/TerritorySystem"

@export var border_width: float = 2.0
@export var preview_line_width: float = 2.0
@export var draw_preview_numbers: bool = true

@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem


func _ready() -> void:
	if territory_system == null:
		push_error("TerritoryVisual: TerritorySystem not found. Path = " + str(territory_system_path))
		return

	territory_system.territory_changed.connect(_on_territory_changed)
	territory_system.territory_preview_changed.connect(_on_territory_preview_changed)

	queue_redraw()


func _draw() -> void:
	if territory_system == null:
		return

	_draw_all_faction_borders()
	_draw_preview_cells()


func _draw_all_faction_borders() -> void:
	var owners: Dictionary = territory_system.get_all_owned_cell_owners()

	for key in owners.keys():
		var cell: Vector2i = key as Vector2i
		var owner_id: StringName = owners[cell] as StringName
		var color: Color = territory_system.get_territory_color_for_faction(owner_id)

		_draw_cell_border_edges(cell, owner_id, owners, color)


func _draw_cell_border_edges(
	cell: Vector2i,
	owner_id: StringName,
	owners: Dictionary,
	color: Color
) -> void:
	var cell_size: Vector2 = _get_cell_size_vector()
	var world_pos: Vector2 = GridSystem.cell_to_world(cell)

	var top_left: Vector2 = world_pos
	var top_right: Vector2 = world_pos + Vector2(cell_size.x, 0)
	var bottom_left: Vector2 = world_pos + Vector2(0, cell_size.y)
	var bottom_right: Vector2 = world_pos + cell_size

	if _get_owner_from_dictionary(owners, cell + Vector2i(0, -1)) != owner_id:
		draw_line(top_left, top_right, color, border_width)

	if _get_owner_from_dictionary(owners, cell + Vector2i(0, 1)) != owner_id:
		draw_line(bottom_left, bottom_right, color, border_width)

	if _get_owner_from_dictionary(owners, cell + Vector2i(-1, 0)) != owner_id:
		draw_line(top_left, bottom_left, color, border_width)

	if _get_owner_from_dictionary(owners, cell + Vector2i(1, 0)) != owner_id:
		draw_line(top_right, bottom_right, color, border_width)


func _draw_preview_cells() -> void:
	var preview_cells: Array[Vector2i] = territory_system.get_preview_cells()

	if preview_cells.is_empty():
		return

	var cell_size: Vector2 = _get_cell_size_vector()
	var fill_color: Color = territory_system.get_preview_color_for_active_faction()

	var line_color: Color = fill_color
	line_color.a = min(fill_color.a + 0.35, 1.0)

	var centers: Array[Vector2] = []

	for i in range(preview_cells.size()):
		var cell: Vector2i = preview_cells[i]
		var world_pos: Vector2 = GridSystem.cell_to_world(cell)
		var rect: Rect2 = Rect2(world_pos, cell_size)

		draw_rect(rect, fill_color, true)
		draw_rect(rect, line_color, false, 1.0)

		var center: Vector2 = world_pos + cell_size * 0.5
		centers.append(center)

		if draw_preview_numbers:
			_draw_preview_number(str(i + 1), center, line_color)

	for i in range(centers.size() - 1):
		draw_line(centers[i], centers[i + 1], line_color, preview_line_width)


func _draw_preview_number(text: String, center: Vector2, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size

	if font == null:
		return

	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position: Vector2 = center - text_size * 0.5

	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _get_owner_from_dictionary(owners: Dictionary, cell: Vector2i) -> StringName:
	if not owners.has(cell):
		return &""

	return owners[cell] as StringName


func _get_cell_size_vector() -> Vector2:
	var raw_cell_size: Variant = GridSystem.get("cell_size")

	match typeof(raw_cell_size):
		TYPE_VECTOR2:
			return raw_cell_size as Vector2
		TYPE_VECTOR2I:
			var value: Vector2i = raw_cell_size as Vector2i
			return Vector2(value.x, value.y)
		TYPE_INT:
			var size_i: int = raw_cell_size as int
			return Vector2(size_i, size_i)
		TYPE_FLOAT:
			var size_f: float = raw_cell_size as float
			return Vector2(size_f, size_f)
		_:
			return Vector2(32, 32)


func _on_territory_changed() -> void:
	queue_redraw()


func _on_territory_preview_changed() -> void:
	queue_redraw()
