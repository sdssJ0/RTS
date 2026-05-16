class_name TerritorySystem
extends Node

signal territory_changed
signal territory_preview_changed
signal expansion_mode_changed(is_expanding: bool)

@export var grid_system_path: NodePath = "../GridSystem"
@export var hud_path: NodePath = "../../UI/HUD"
@export var faction_system_path: NodePath = "../FactionSystem"

@export var country_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var preview_color: Color = Color(0.2, 1.0, 1.0, 0.35)

@export_group("Initial Territory Fallback")
@export var initial_origin: Vector2i = Vector2i(20, 25)
@export var initial_size: Vector2i = Vector2i(10, 10)

@export_group("Expansion")
@export var expansion_cells_per_click: int = 5
@export var debug_expansion: bool = true

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem
@onready var hud: HUD = get_node_or_null(hud_path) as HUD
@onready var faction_system: FactionSystem = get_node_or_null(faction_system_path) as FactionSystem

# key = Vector2i
# value = faction_id: StringName
var cell_owner: Dictionary = {}

var is_expansion_mode: bool = false
var ignore_click_until_next_frame: bool = false

var current_hover_cell: Vector2i = Vector2i(999999, 999999)
var preview_cells: Array[Vector2i] = []


func _ready() -> void:
	set_process_input(true)

	if grid_system == null:
		push_error("TerritorySystem: GridSystem not found. Path = " + str(grid_system_path))
		return

	if hud == null:
		push_warning("TerritorySystem: HUD not found. Path = " + str(hud_path))

	if faction_system == null:
		push_error("TerritorySystem: FactionSystem not found. Path = " + str(faction_system_path))
		return

	faction_system.active_faction_changed.connect(_on_active_faction_changed)

	_create_initial_territory()

	print("TerritorySystem ready.")
	debug_print_faction_territory_counts()

	emit_signal("territory_changed")


func _process(_delta: float) -> void:
	if ignore_click_until_next_frame:
		ignore_click_until_next_frame = false

	if is_expansion_mode:
		if _should_block_world_input_by_ui():
			_clear_preview()
			return

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

	print("TerritorySystem: expansion mode started. Active faction =", get_active_faction_id())

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


func get_active_faction_id() -> StringName:
	if faction_system == null:
		return &""

	if faction_system.active_faction_id == &"":
		return &""

	return faction_system.active_faction_id


func get_cell_owner(cell: Vector2i) -> StringName:
	if not cell_owner.has(cell):
		return &""

	return cell_owner[cell] as StringName


func is_cell_owned(cell: Vector2i) -> bool:
	return is_cell_owned_by_faction(cell, get_active_faction_id())


func is_cell_owned_by_faction(cell: Vector2i, faction_id: StringName) -> bool:
	if faction_id == &"":
		return false

	if not cell_owner.has(cell):
		return false

	return cell_owner[cell] == faction_id


func is_area_owned(origin_cell: Vector2i, size_in_cells: Vector2i) -> bool:
	return is_area_owned_by_faction(origin_cell, size_in_cells, get_active_faction_id())


func is_area_owned_by_faction(
	origin_cell: Vector2i,
	size_in_cells: Vector2i,
	faction_id: StringName
) -> bool:
	if faction_id == &"":
		return false

	for y in range(size_in_cells.y):
		for x in range(size_in_cells.x):
			var cell: Vector2i = origin_cell + Vector2i(x, y)

			if not is_cell_owned_by_faction(cell, faction_id):
				return false

	return true


func add_owned_cell(cell: Vector2i) -> void:
	add_owned_cell_for_faction(cell, get_active_faction_id())


func add_owned_cell_for_faction(cell: Vector2i, faction_id: StringName) -> void:
	if faction_id == &"":
		return

	if cell_owner.has(cell):
		return

	cell_owner[cell] = faction_id


func get_owned_cells() -> Array[Vector2i]:
	return get_owned_cells_for_faction(get_active_faction_id())


func get_owned_cells_for_faction(faction_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for key in cell_owner.keys():
		var cell: Vector2i = key as Vector2i

		if cell_owner[cell] == faction_id:
			result.append(cell)

	return result


func get_all_owned_cell_owners() -> Dictionary:
	return cell_owner.duplicate()


func get_preview_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for cell in preview_cells:
		result.append(cell)

	return result


func has_preview() -> bool:
	return not preview_cells.is_empty()


func get_territory_color_for_faction(faction_id: StringName) -> Color:
	if faction_system == null:
		return country_color

	return faction_system.get_territory_color(faction_id)


func get_preview_color_for_active_faction() -> Color:
	if faction_system == null:
		return preview_color

	return faction_system.get_preview_color(get_active_faction_id())


func get_building_texture_for_faction(
	faction_id: StringName,
	config: BuildingConfig
) -> Texture2D:
	if config == null:
		return null

	var fallback_texture: Texture2D = config.texture
	var building_id: StringName = _get_building_id_from_config(config)

	if faction_system == null:
		return fallback_texture

	return faction_system.get_building_texture(
		faction_id,
		building_id,
		fallback_texture
	)


func get_building_texture_for_active_faction(config: BuildingConfig) -> Texture2D:
	return get_building_texture_for_faction(get_active_faction_id(), config)


func _get_building_id_from_config(config: BuildingConfig) -> StringName:
	if config == null:
		return &""

	var id_value: Variant = config.get("id")

	if typeof(id_value) == TYPE_STRING_NAME:
		return id_value as StringName

	if typeof(id_value) == TYPE_STRING:
		return StringName(id_value as String)

	if config.resource_path != "":
		return StringName(config.resource_path.get_file().get_basename())

	return StringName(config.display_name)


func _create_initial_territory() -> void:
	cell_owner.clear()

	var factions: Array[FactionConfig] = faction_system.get_all_factions()

	if factions.is_empty():
		var fallback_faction_id: StringName = get_active_faction_id()

		if fallback_faction_id == &"":
			fallback_faction_id = &"blue"

		for y in range(initial_size.y):
			for x in range(initial_size.x):
				var fallback_cell: Vector2i = initial_origin + Vector2i(x, y)
				add_owned_cell_for_faction(fallback_cell, fallback_faction_id)

		return

	for faction in factions:
		if faction == null:
			continue

		print("Create initial territory for faction:", faction.id, faction.display_name)

		for y in range(faction.initial_size.y):
			for x in range(faction.initial_size.x):
				var cell: Vector2i = faction.initial_origin + Vector2i(x, y)

				if cell_owner.has(cell):
					push_warning(
						"TerritorySystem: initial territory overlap at "
						+ str(cell)
						+ ". Existing owner = "
						+ str(cell_owner[cell])
						+ ", ignored owner = "
						+ str(faction.id)
					)
					continue

				add_owned_cell_for_faction(cell, faction.id)


func debug_print_faction_territory_counts() -> void:
	print("========== Territory Counts ==========")
	print("Total cells =", cell_owner.size())

	if faction_system == null:
		print("FactionSystem is null.")
		return

	for faction in faction_system.get_all_factions():
		if faction == null:
			continue

		print(
			"Faction ",
			faction.id,
			" / ",
			faction.display_name,
			" cells = ",
			get_owned_cells_for_faction(faction.id).size()
		)

	print("======================================")


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
			print(
				"TerritorySystem: no valid expansion preview. faction=",
				get_active_faction_id(),
				" cell=",
				current_hover_cell
			)
		else:
			print(
				"TerritorySystem: preview. faction=",
				get_active_faction_id(),
				" from=",
				current_hover_cell,
				" cells=",
				preview_cells
			)

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

	var active_faction_id: StringName = get_active_faction_id()

	if active_faction_id == &"":
		push_warning("TerritorySystem: cannot expand. Active faction is empty.")
		return

	var added_count: int = 0

	for cell in preview_cells:
		if not cell_owner.has(cell):
			add_owned_cell_for_faction(cell, active_faction_id)
			added_count += 1

	if added_count > 0:
		print("TerritorySystem: expanded faction:", active_faction_id)
		print("TerritorySystem: added cells:", added_count)
		print("TerritorySystem: total territory cells:", cell_owner.size())

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

	return _search_path_recursive(path, path_set, target_count, rng)


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

	for direction in _get_cardinal_directions():
		var neighbor: Vector2i = cell + direction

		if cell_owner.has(neighbor):
			continue

		if path_set.has(neighbor):
			continue

		candidates.append(neighbor)

	return candidates


func _is_expansion_start_candidate(cell: Vector2i) -> bool:
	if cell_owner.has(cell):
		return false

	var active_faction_id: StringName = get_active_faction_id()

	if active_faction_id == &"":
		return false

	for direction in _get_cardinal_directions():
		var neighbor: Vector2i = cell + direction

		if is_cell_owned_by_faction(neighbor, active_faction_id):
			return true

	return false


func _get_seed_for_cell(cell: Vector2i) -> int:
	var seed_value: int = abs(
		cell.x * 73856093
		+ cell.y * 19349663
		+ cell_owner.size() * 83492791
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


func _get_cardinal_directions() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]


func _screen_to_world_position(screen_position: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position


func _should_block_world_input_by_ui() -> bool:
	if hud == null:
		return false

	return hud.is_blocking_world_input()


func _on_active_faction_changed(faction_id: StringName) -> void:
	print("TerritorySystem: active faction changed to:", faction_id)
	print("TerritorySystem: total territory cells =", cell_owner.size())
	print("TerritorySystem: active faction cells =", get_owned_cells_for_faction(faction_id).size())

	stop_expansion_mode()
	_clear_preview()
	emit_signal("territory_changed")
