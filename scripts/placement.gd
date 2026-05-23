class_name PlacementSystem
extends Node

@export var building_manager_path: NodePath = "../BuildingManager"
@export var hud_path: NodePath = "../../UI/HUD"
@export var preview_root_path: NodePath = "../../World2D/PreviewRoot"

@export var preview_building_scene: PackedScene
@export var debug_mouse_position: bool = false

@onready var building_manager: BuildingManager = get_node_or_null(building_manager_path) as BuildingManager
@onready var hud: HUD = get_node_or_null(hud_path) as HUD
@onready var preview_root: Node2D = get_node_or_null(preview_root_path) as Node2D

var is_placing: bool = false
var current_config: BuildingConfig = null

var preview_instance: BasicBuilding = null

var current_cell: Vector2i = Vector2i.ZERO
var current_grid_can_place: bool = false
var current_can_afford: bool = false
var current_is_own_territory: bool = false
var current_can_place: bool = false
var current_mouse_world_position: Vector2 = Vector2.ZERO

var ignore_place_until_next_frame: bool = false


func _ready() -> void:
	set_process_input(true)

	if building_manager == null:
		push_error("PlacementSystem: BuildingManager not found. Path = " + str(building_manager_path))

	if hud == null:
		push_warning("PlacementSystem: HUD not found. Path = " + str(hud_path))

	if preview_root == null:
		push_error("PlacementSystem: PreviewRoot not found. Path = " + str(preview_root_path))

	if preview_building_scene == null:
		push_warning("PlacementSystem: Preview Building Scene is not assigned.")

	print("PlacementSystem ready.")


func _process(_delta: float) -> void:
	if not is_placing:
		return

	if ignore_place_until_next_frame:
		ignore_place_until_next_frame = false

	if _should_block_world_input_by_ui():
		return

	_update_mouse_cell_from_screen_position(get_viewport().get_mouse_position())
	_update_preview_visual()


func _input(event: InputEvent) -> void:
	if not is_placing:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return

		if _should_block_world_input_by_ui():
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if ignore_place_until_next_frame:
				get_viewport().set_input_as_handled()
				return

			_update_mouse_cell_from_screen_position(mouse_event.position)
			_update_preview_visual()

			if debug_mouse_position:
				_print_place_debug()

			_try_place_current_building()
			get_viewport().set_input_as_handled()

		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placing()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			cancel_placing()
			get_viewport().set_input_as_handled()


func start_placing(config: BuildingConfig) -> void:
	cancel_placing()

	if config == null:
		push_error("PlacementSystem: config is null.")
		return

	if building_manager == null:
		push_error("PlacementSystem: building_manager is null.")
		return

	if preview_root == null:
		push_error("PlacementSystem: preview_root is null.")
		return

	if preview_building_scene == null:
		push_error("PlacementSystem: preview_building_scene is not assigned.")
		return

	current_config = config
	is_placing = true
	ignore_place_until_next_frame = true

	_create_preview()

	_update_mouse_cell_from_screen_position(get_viewport().get_mouse_position())
	_update_preview_visual()


func cancel_placing() -> void:
	is_placing = false
	current_config = null
	current_cell = Vector2i.ZERO
	current_grid_can_place = false
	current_can_afford = false
	current_is_own_territory = false
	current_can_place = false
	current_mouse_world_position = Vector2.ZERO
	ignore_place_until_next_frame = false

	if preview_instance != null:
		preview_instance.queue_free()
		preview_instance = null


func _create_preview() -> void:
	if current_config == null:
		return

	if preview_building_scene == null:
		push_error("PlacementSystem: preview_building_scene is not assigned.")
		return

	var instance: Node = preview_building_scene.instantiate()
	preview_instance = instance as BasicBuilding

	if preview_instance == null:
		push_error("PlacementSystem: preview scene root must be BasicBuilding.")
		instance.queue_free()
		return

	preview_root.add_child(preview_instance)

	preview_instance.set_preview_mode(true)
	preview_instance.setup(current_config, Vector2i.ZERO)

	var active_faction_id: StringName = FactionSystem.active_faction_id
	var preview_texture: Texture2D = TerritoryService.get_building_texture_for_faction(
		active_faction_id,
		current_config
	)

	preview_instance.owner_faction_id = active_faction_id
	preview_instance.owner_texture = preview_texture
	preview_instance.apply_owner_visual()

	preview_instance.z_as_relative = false
	preview_instance.z_index = 10000
	preview_instance.visible = true


func _screen_to_world_position(screen_position: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position


func _update_mouse_cell_from_screen_position(screen_position: Vector2) -> void:
	if current_config == null:
		return

	current_mouse_world_position = _screen_to_world_position(screen_position)
	current_cell = GridSystem.world_to_cell(current_mouse_world_position)

	current_grid_can_place = GridSystem.can_place_area(
		current_cell,
		current_config.size_in_cells
	)

	var active_faction_id: StringName = FactionSystem.active_faction_id
	current_can_afford = EconomySystem.can_afford_config(active_faction_id, current_config)

	current_is_own_territory = TerritoryService.is_area_owned_by_faction(
		current_cell,
		current_config.size_in_cells,
		active_faction_id
	)

	current_can_place = current_grid_can_place and current_can_afford and current_is_own_territory


func _update_preview_visual() -> void:
	if preview_instance == null:
		return

	if current_config == null:
		return

	var snapped_position: Vector2 = GridSystem.cell_to_world(current_cell)
	preview_instance.global_position = snapped_position

	preview_instance.set_preview_valid(current_can_place)


func _try_place_current_building() -> void:
	if current_config == null:
		return

	if building_manager == null:
		return

	if debug_mouse_position:
		_print_place_debug()

	if not current_grid_can_place:
		return

	if not current_is_own_territory:
		return

	if not current_can_afford:
		return

	building_manager.try_place_building(current_config, current_cell)


func _print_place_debug() -> void:
	print("PlacementSystem debug:")
	print("  Active faction:", FactionSystem.active_faction_id)
	print("  Mouse world:", current_mouse_world_position)
	print("  Cell:", current_cell)
	print("  Cell owner:", TerritoryService.get_cell_owner(current_cell))
	print("  Grid can place:", current_grid_can_place)
	print("  Can afford:", current_can_afford)
	print("  Own territory:", current_is_own_territory)
	print("  Can place:", current_can_place)


func _should_block_world_input_by_ui() -> bool:
	if hud == null:
		return false

	return hud.is_blocking_world_input()
