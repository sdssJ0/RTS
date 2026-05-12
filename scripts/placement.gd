class_name PlacementSystem
extends Node

@export var grid_system_path: NodePath = "../GridSystem"
@export var building_manager_path: NodePath = "../BuildingManager"
@export var preview_root_path: NodePath = "../../World/PreviewRoot"
@export var camera_path: NodePath = "../../World/Camera2D"

@onready var grid_system: GridSystem = get_node(grid_system_path)
@onready var building_manager: BuildingManager = get_node(building_manager_path)
@onready var preview_root: Node2D = get_node(preview_root_path)
@onready var camera_2d: Camera2D = get_node(camera_path)

var is_placing: bool = false
var current_building_scene: PackedScene = null

var preview_instance: BasicBuilding = null
var current_cell: Vector2i = Vector2i.ZERO
var current_can_place: bool = false

func _process(_delta: float) -> void:
	if not is_placing:
		return

	_update_preview()

func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_place_current_building()
			get_viewport().set_input_as_handled()

		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			cancel_placing()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			cancel_placing()
			get_viewport().set_input_as_handled()

func start_placing(building_scene: PackedScene) -> void:
	cancel_placing()

	if building_scene == null:
		push_error("Cannot start placing. Building scene is null.")
		return

	current_building_scene = building_scene
	is_placing = true

	_create_preview()

	print("Start placing building.")

func cancel_placing() -> void:
	is_placing = false
	current_building_scene = null
	current_cell = Vector2i.ZERO
	current_can_place = false

	if preview_instance != null:
		preview_instance.queue_free()
		preview_instance = null

func _create_preview() -> void:
	if current_building_scene == null:
		return

	preview_instance = current_building_scene.instantiate() as BasicBuilding

	if preview_instance == null:
		push_error("Preview scene root must be BasicBuilding.")
		return

	preview_root.add_child(preview_instance)

	preview_instance.z_index = 1000
	preview_instance.modulate = Color(0.2, 1.0, 0.2, 0.55)

func _update_preview() -> void:
	if preview_instance == null:
		return

	var mouse_world_position: Vector2 = camera_2d.get_global_mouse_position()

	current_cell = grid_system.world_to_cell(mouse_world_position)

	var snapped_position: Vector2 = grid_system.cell_to_world(current_cell)
	preview_instance.position = snapped_position

	current_can_place = grid_system.can_place_at(current_cell)

	if current_can_place:
		preview_instance.modulate = Color(0.2, 1.0, 0.2, 0.55)
	else:
		preview_instance.modulate = Color(1.0, 0.2, 0.2, 0.55)

func _try_place_current_building() -> void:
	if current_building_scene == null:
		return

	if not current_can_place:
		print("Cannot place building here:", current_cell)
		return

	var success: bool = building_manager.try_place_building(
		current_building_scene,
		current_cell
	)

	if success:
		print("Building placed at cell:", current_cell)

		# 当前是连续放置模式：
		# 左键可以一直放多个建筑。
		# 如果你希望放一个后自动退出放置模式，取消下面这一行注释：
		# cancel_placing()
