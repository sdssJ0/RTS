class_name TerritorySystem
extends Node

signal territory_changed
signal territory_preview_changed
signal expansion_mode_changed(is_expanding: bool)

@export var grid_system_path: NodePath = "../GridSystem"

@export var country_color: Color = Color(0.983, 0.337, 0.316, 1.0)
@export var preview_color: Color = Color(0.2, 1.0, 1.0, 0.35)

@export_group("Initial Territory")
@export var initial_origin: Vector2i = Vector2i(20, 25)
@export var initial_size: Vector2i = Vector2i(10, 10)

@export_group("Expansion")
@export var expansion_cells_per_click: int = 5
@export var debug_expansion: bool = true

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem

var owned_cells: Dictionary = {}

var is_expansion_mode: bool = false
var ignore_click_until_next_frame: bool = false

var current_hover_cell: Vector2i = Vector2i(999999, 999999)
var preview_cells: Array[Vector2i] = []


func _ready() -> void:
	set_process_input(true)

	if grid_system == null:
		push_error("TerritorySystem: GridSystem not found. Path = " + str(grid_system_path))
		return

	_create_initial_territory()

	print("TerritorySystem ready.")
	print("  Owned cells:", owned_cells.size())

	emit_signal("territory_changed")


func _process(_delta: float) -> void:
	if ignore_click_until_next_frame:
		ignore_click_until_next_frame = false

	if is_expansion_mode:
		_update_preview_from_screen_position(get_viewport().get_mouse_position())


func _input(event: InputEvent) -> void:
	if not is_expansion_mode:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return

		if _should_block_world_input_by_ui():
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if ignore_click_until_next_frame:
				get_viewport().set_input_as_handled()
				return

			_update_preview_from_screen_position(mouse_event.position)
			_apply_current_preview_expansion()

			get_viewport().set_input_as_handled()

		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			stop_expansion_mode()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			stop_expansion_mode()
			get_viewport().set_input_as_handled()


func start_expansion_mode() -> void:
	is_expansion_mode = true
	ignore_click_until_next_frame = true
	current_hover_cell = Vector2i(999999, 999999)
	preview_cells.clear()

	print("TerritorySystem: expansion mode started.")

	emit_signal("expansion_mode_changed", true)
	emit_signal("territory_preview_changed")


func stop_expansion_mode() -> void:
	if not is_expansion_mode:
		return

	is_expansion_mode = false
	ignore_click_until_next_frame = false
	current_hover_cell = Vector2i(999999, 999999)
	preview_cells.clear()

	print("TerritorySystem: expansion mode stopped.")

	emit_signal("expansion_mode_changed", false)
	emit_signal("territory_preview_changed")


func toggle_expansion_mode() -> void:
	if is_expansion_mode:
		stop_expansion_mode()
	else:
		start_expansion_mode()


func is_cell_owned(cell: Vector2i) -> bool:
	return owned_cells.has(cell)


func is_area_owned(origin_cell: Vector2i, size_in_cells: Vector2i) -> bool:
	for y in range(size_in_cells.y):
		for x in range(size_in_cells.x):
			var cell: Vector2i = origin_cell + Vector2i(x, y)

			if not is_cell_owned(cell):
				return false

	return true


func add_owned_cell(cell: Vector2i) -> void:
	if owned_cells.has(cell):
		return

	owned_cells[cell] = true


func get_owned_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for key in owned_cells.keys():
		var cell: Vector2i = key as Vector2i
		result.append(cell)

	return result


func get_preview_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for cell in preview_cells:
		result.append(cell)

	return result


func has_preview() -> bool:
	return not preview_cells.is_empty()


func _create_initial_territory() -> void:
	owned_cells.clear()

	for y in range(initial_size.y):
		for x in range(initial_size.x):
			var cell: Vector2i = initial_origin + Vector2i(x, y)
			add_owned_cell(cell)


func _update_preview_from_screen_position(screen_position: Vector2) -> void:
	if grid_system == null:
		return

	if _should_block_world_input_by_ui():
		_clear_preview()
		return

	var world_position: Vector2 = _screen_to_world_position(screen_position)
	var hover_cell: Vector2i = grid_system.world_to_cell(world_position)

	if hover_cell == current_hover_cell:
		return

	current_hover_cell = hover_cell
	preview_cells = _generate_continuous_expansion_path(current_hover_cell)

	if debug_expansion:
		if preview_cells.is_empty():
			print("TerritorySystem: no valid expansion preview at:", current_hover_cell)
		else:
			print("TerritorySystem: preview from:", current_hover_cell, " cells:", preview_cells)

	emit_signal("territory_preview_changed")


func _clear_preview() -> void:
	current_hover_cell = Vector2i(999999, 999999)

	if preview_cells.is_empty():
		return

	preview_cells.clear()
	emit_signal("territory_preview_changed")


func _apply_current_preview_expansion() -> void:
	if preview_cells.is_empty():
		print("TerritorySystem: cannot expand here. Invalid start cell:", current_hover_cell)
		return

	var added_count: int = 0

	for cell in preview_cells:
		if not owned_cells.has(cell):
			add_owned_cell(cell)
			added_count += 1

	if added_count > 0:
		print("TerritorySystem: expanded from:", preview_cells[0])
		print("TerritorySystem: added cells:", added_count)
		print("TerritorySystem: total owned cells:", owned_cells.size())

		emit_signal("territory_changed")

	preview_cells.clear()
	current_hover_cell = Vector2i(999999, 999999)
	emit_signal("territory_preview_changed")


func _generate_continuous_expansion_path(start_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if expansion_cells_per_click <= 0:
		return result

	if not _is_expansion_start_candidate(start_cell):
		return result

	var path: Array[Vector2i] = []
	var path_set: Dictionary = {}

	path.append(start_cell)
	path_set[start_cell] = true

	var target_count: int = expansion_cells_per_click

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _get_seed_for_cell(start_cell)

	var found_path: Array[Vector2i] = _search_path_recursive(
		path,
		path_set,
		target_count,
		rng
	)

	return found_path


func _search_path_recursive(
	path: Array[Vector2i],
	path_set: Dictionary,
	target_count: int,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	if path.size() >= target_count:
		return _duplicate_vector2i_array(path)

	var best_path: Array[Vector2i] = _duplicate_vector2i_array(path)

	var last_cell: Vector2i = path[path.size() - 1]
	var candidates: Array[Vector2i] = _get_next_path_candidates(last_cell, path_set)

	_shuffle_vector2i_array(candidates, rng)

	for candidate in candidates:
		path.append(candidate)
		path_set[candidate] = true

		var found_path: Array[Vector2i] = _search_path_recursive(
			path,
			path_set,
			target_count,
			rng
		)

		if found_path.size() >= target_count:
			return found_path

		if found_path.size() > best_path.size():
			best_path = _duplicate_vector2i_array(found_path)

		path.pop_back()
		path_set.erase(candidate)

	return best_path


func _get_next_path_candidates(cell: Vector2i, path_set: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for direction in directions:
		var neighbor: Vector2i = cell + direction

		if owned_cells.has(neighbor):
			continue

		if path_set.has(neighbor):
			continue

		candidates.append(neighbor)

	return candidates


func _is_expansion_start_candidate(cell: Vector2i) -> bool:
	if owned_cells.has(cell):
		return false

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for direction in directions:
		var neighbor: Vector2i = cell + direction

		if owned_cells.has(neighbor):
			return true

	return false


func _get_seed_for_cell(cell: Vector2i) -> int:
	var seed_value: int = abs(
		cell.x * 73856093
		+ cell.y * 19349663
		+ owned_cells.size() * 83492791
	)

	if seed_value == 0:
		seed_value = 1

	return seed_value


func _shuffle_vector2i_array(array: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)

		var temp: Vector2i = array[i]
		array[i] = array[j]
		array[j] = temp


func _duplicate_vector2i_array(source: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for cell in source:
		result.append(cell)

	return result


func _screen_to_world_position(screen_position: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position


func _should_block_world_input_by_ui() -> bool:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()

	if hovered_control == null:
		return false

	var current: Control = hovered_control

	while current != null:
		if current is Button:
			return true

		if current.name == "BuildPanel":
			return true

		var parent: Node = current.get_parent()
		current = parent as Control

	return false
