class_name GameCamera
extends Camera2D

@export_group("Grid Map Bounds")
@export var grid_system_path: NodePath = "../../Systems/GridSystem"
@export var hud_path: NodePath = "../../UI/HUD"
@export var use_map_bounds: bool = true

@export var map_origin_cell: Vector2i = Vector2i.ZERO
@export var map_size_in_cells: Vector2i = Vector2i(100, 100)
@export var map_padding_pixels: float = 0.0

@export_group("Keyboard Move")
@export var enable_keyboard_move: bool = true
@export var move_speed: float = 600.0

@export_group("Mouse Drag")
@export var enable_middle_mouse_drag: bool = true
@export var drag_button: int = MOUSE_BUTTON_MIDDLE

@export_group("Zoom")
@export var enable_mouse_wheel_zoom: bool = true
@export var zoom_step: float = 1.12
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_to_mouse: bool = true

@export_group("Edge Scroll")
@export var enable_edge_scroll: bool = false
@export var edge_scroll_margin: float = 20.0
@export var edge_scroll_speed: float = 500.0

@onready var grid_system: GridSystem = get_node_or_null(grid_system_path) as GridSystem
@onready var hud: HUD = get_node_or_null(hud_path) as HUD

var is_dragging: bool = false


func _ready() -> void:
	set_process(true)
	set_process_input(true)

	make_current()

	_clamp_zoom()
	_clamp_camera_to_map_bounds()

	print("GameCamera ready.")

	if grid_system == null:
		push_warning("GameCamera: GridSystem not found. Path = " + str(grid_system_path))
	else:
		print("GameCamera: GridSystem found:", grid_system.name)

	if hud == null:
		push_warning("GameCamera: HUD not found. Path = " + str(hud_path))


func _process(delta: float) -> void:
	var move_direction: Vector2 = Vector2.ZERO

	if enable_keyboard_move:
		move_direction += _get_keyboard_move_direction()

	if enable_edge_scroll:
		move_direction += _get_edge_scroll_direction()

	if move_direction.length_squared() > 0.0:
		move_direction = move_direction.normalized()

		var zoom_factor: float = max(zoom.x, 0.001)
		position += move_direction * move_speed * delta / zoom_factor

		_clamp_camera_to_map_bounds()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		_handle_mouse_button(mouse_event)

	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_mouse_motion(motion_event)


func _handle_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if enable_middle_mouse_drag and mouse_event.button_index == drag_button:
		if mouse_event.pressed:
			if _should_block_camera_input_by_ui():
				return

			is_dragging = true
			get_viewport().set_input_as_handled()
			return
		else:
			is_dragging = false
			get_viewport().set_input_as_handled()
			return

	if _should_block_camera_input_by_ui():
		return

	if not enable_mouse_wheel_zoom:
		return

	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_camera(zoom.x * zoom_step)
		get_viewport().set_input_as_handled()
		return

	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_camera(zoom.x / zoom_step)
		get_viewport().set_input_as_handled()
		return


func _handle_mouse_motion(motion_event: InputEventMouseMotion) -> void:
	if not is_dragging:
		return

	var zoom_factor: float = max(zoom.x, 0.001)

	position -= motion_event.relative / zoom_factor

	_clamp_camera_to_map_bounds()

	get_viewport().set_input_as_handled()


func _get_keyboard_move_direction() -> Vector2:
	var direction: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	return direction


func _get_edge_scroll_direction() -> Vector2:
	if _should_block_camera_input_by_ui():
		return Vector2.ZERO

	var direction: Vector2 = Vector2.ZERO
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = get_viewport_rect().size

	if mouse_position.x <= edge_scroll_margin:
		direction.x -= 1.0
	elif mouse_position.x >= viewport_size.x - edge_scroll_margin:
		direction.x += 1.0

	if mouse_position.y <= edge_scroll_margin:
		direction.y -= 1.0
	elif mouse_position.y >= viewport_size.y - edge_scroll_margin:
		direction.y += 1.0

	return direction


func _zoom_camera(target_zoom_value: float) -> void:
	var old_zoom_value: float = zoom.x
	var new_zoom_value: float = clamp(target_zoom_value, min_zoom, max_zoom)

	if is_equal_approx(old_zoom_value, new_zoom_value):
		return

	if zoom_to_mouse:
		_zoom_to_mouse_position(old_zoom_value, new_zoom_value)
	else:
		zoom = Vector2(new_zoom_value, new_zoom_value)

	_clamp_zoom()
	_clamp_camera_to_map_bounds()


func _zoom_to_mouse_position(old_zoom_value: float, new_zoom_value: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_screen_position: Vector2 = get_viewport().get_mouse_position()
	var mouse_offset_from_center: Vector2 = mouse_screen_position - viewport_size * 0.5

	var old_world_offset: Vector2 = mouse_offset_from_center / old_zoom_value
	var new_world_offset: Vector2 = mouse_offset_from_center / new_zoom_value

	position += old_world_offset - new_world_offset
	zoom = Vector2(new_zoom_value, new_zoom_value)


func _clamp_zoom() -> void:
	var clamped_zoom: float = clamp(zoom.x, min_zoom, max_zoom)
	zoom = Vector2(clamped_zoom, clamped_zoom)


func _clamp_camera_to_map_bounds() -> void:
	if not use_map_bounds:
		return

	var map_rect: Rect2 = _get_map_world_rect()
	var visible_world_size: Vector2 = _get_visible_world_size()
	var half_visible_size: Vector2 = visible_world_size * 0.5

	var min_camera_position: Vector2 = map_rect.position + half_visible_size
	var max_camera_position: Vector2 = map_rect.position + map_rect.size - half_visible_size

	if min_camera_position.x > max_camera_position.x:
		position.x = map_rect.position.x + map_rect.size.x * 0.5
	else:
		position.x = clamp(position.x, min_camera_position.x, max_camera_position.x)

	if min_camera_position.y > max_camera_position.y:
		position.y = map_rect.position.y + map_rect.size.y * 0.5
	else:
		position.y = clamp(position.y, min_camera_position.y, max_camera_position.y)


func _get_visible_world_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size

	var zoom_x: float = max(zoom.x, 0.001)
	var zoom_y: float = max(zoom.y, 0.001)

	return Vector2(
		viewport_size.x / zoom_x,
		viewport_size.y / zoom_y
	)


func _get_map_world_rect() -> Rect2:
	var cell_size: float = 16.0

	if grid_system != null:
		cell_size = float(grid_system.cell_size)

	var map_position: Vector2 = Vector2(
		map_origin_cell.x * cell_size,
		map_origin_cell.y * cell_size
	)

	var map_size: Vector2 = Vector2(
		map_size_in_cells.x * cell_size,
		map_size_in_cells.y * cell_size
	)

	map_position -= Vector2(map_padding_pixels, map_padding_pixels)
	map_size += Vector2(map_padding_pixels * 2.0, map_padding_pixels * 2.0)

	return Rect2(map_position, map_size)


func _should_block_camera_input_by_ui() -> bool:
	if hud == null:
		return false

	return hud.is_blocking_world_input()
