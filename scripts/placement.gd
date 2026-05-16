class_name PlacementSystem
extends Node

@export var grid_system_path: NodePath = "../GridSystem"
@export var building_manager_path: NodePath = "../BuildingManager"
@export var economy_system_path: NodePath = "../EconomySystem"
@export var territory_system_path: NodePath = "../TerritorySystem"
@export var hud_path: NodePath = "../../UI/HUD"
@export var preview_root_path: NodePath = "../../World2D/PreviewRoot"

@export var preview_building_scene: PackedScene
@export var debug_mouse_position: bool = false

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem
@onready var building_manager: BuildingManager = get_node_or_null(building_manager_path) as BuildingManager
@onready var economy_system: EconomySystem = get_node_or_null(economy_system_path) as EconomySystem
@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem
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

	print("PlacementSystem ready.")

	if grid_system == null:
		push_error("PlacementSystem: GridSystem not found. Path = " + str(grid_system_path))

	if building_manager == null:
		push_error("PlacementSystem: BuildingManager not found. Path = " + str(building_manager_path))

	if economy_system == null:
		push_error("PlacementSystem: EconomySystem not found. Path = " + str(economy_system_path))

	if territory_system == null:
		push_error("PlacementSystem: TerritorySystem not found. Path = " + str(territory_system_path))

	if hud == null:
		push_warning("PlacementSystem: HUD not found. Path = " + str(hud_path))

	if preview_root == null:
		push_error("PlacementSystem: PreviewRoot not found. Path = " + str(preview_root_path))

	if preview_building_scene == null:
		push_warning("PlacementSystem: Preview Building Scene is not assigned.")


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

	if grid_system == null:
		push_error("PlacementSystem: grid_system is null.")
		return

	if building_manager == null:
		push_error("PlacementSystem: building_manager is null.")
		return

	if economy_system == null:
		push_error("PlacementSystem: economy_system is null.")
		return

	if territory_system == null:
		push_error("PlacementSystem: territory_system is null.")
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

	print("Start placing:", config.display_name, " faction:", territory_system.get_active_faction_id())


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

	if territory_system != null:
		var active_faction_id: StringName = territory_system.get_active_faction_id()
		var preview_texture: Texture2D = territory_system.get_building_texture_for_faction(
			active_faction_id,
			current_config
		)

		print("Preview faction =", active_faction_id)
		print("Preview building =", current_config.display_name)
		print("Preview texture =", preview_texture)

		preview_instance.owner_faction_id = active_faction_id
		preview_instance.owner_texture = preview_texture
		preview_instance.apply_owner_visual()

	preview_instance.z_as_relative = false
	preview_instance.z_index = 10000
	preview_instance.visible = true

	print("PlacementSystem: preview created.")


func _screen_to_world_position(screen_position: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position


func _update_mouse_cell_from_screen_position(screen_position: Vector2) -> void:
	if current_config == null:
		return

	if grid_system == null:
		return

	current_mouse_world_position = _screen_to_world_position(screen_position)
	current_cell = grid_system.world_to_cell(current_mouse_world_position)

	current_grid_can_place = grid_system.can_place_area(
		current_cell,
		current_config.size_in_cells
	)

	if economy_system != null:
		current_can_afford = economy_system.can_afford_config(current_config)
	else:
		current_can_afford = false

	if territory_system != null:
		current_is_own_territory = territory_system.is_area_owned(
			current_cell,
			current_config.size_in_cells
		)
	else:
		current_is_own_territory = false

	current_can_place = current_grid_can_place and current_can_afford and current_is_own_territory


func _update_preview_visual() -> void:
	if preview_instance == null:
		return

	if current_config == null:
		return

	if grid_system == null:
		return

	var snapped_position: Vector2 = grid_system.cell_to_world(current_cell)
	preview_instance.global_position = snapped_position

	preview_instance.set_preview_valid(current_can_place)


func _try_place_current_building() -> void:
	if current_config == null:
		print("PlacementSystem: current_config is null.")
		return

	if building_manager == null:
		print("PlacementSystem: building_manager is null.")
		return

	if debug_mouse_position:
		_print_place_debug()

	if not current_grid_can_place:
		print("Cannot place building here. Grid blocked:", current_cell)
		return

	if not current_is_own_territory:
		print("Cannot place building. Not current faction territory:", current_cell)
		if territory_system != null:
			print("  Active faction:", territory_system.get_active_faction_id())
			print("  Cell owner:", territory_system.get_cell_owner(current_cell))
		return

	if not current_can_afford:
		print("Cannot place building. Not enough resource.")
		print("  Cost Resource:", current_config.cost_resource_id)
		print("  Cost:", current_config.cost)
		return

	var success: bool = building_manager.try_place_building(
		current_config,
		current_cell
	)

	print("PlacementSystem: BuildingManager result =", success)

	if success:
		print("Building placed:", current_config.display_name, " at cell:", current_cell)
	else:
		print("Building place failed.")


func _print_place_debug() -> void:
	print("PlacementSystem debug:")
	print("  Active faction:", territory_system.get_active_faction_id() if territory_system != null else &"")
	print("  Mouse world:", current_mouse_world_position)
	print("  Cell:", current_cell)
	print("  Cell owner:", territory_system.get_cell_owner(current_cell) if territory_system != null else &"")
	print("  Grid can place:", current_grid_can_place)
	print("  Can afford:", current_can_afford)
	print("  Own territory:", current_is_own_territory)
	print("  Can place:", current_can_place)


func _should_block_world_input_by_ui() -> bool:
	if hud == null:
		return false

	return hud.is_blocking_world_input()
