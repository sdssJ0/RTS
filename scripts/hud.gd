class_name HUD
extends Control

signal ui_mouse_block_changed(is_blocking: bool)

@export var placement_system_path: NodePath = "../../Systems/PlacementSystem"
@export var building_catalog_path: NodePath = "../../Systems/BuildingCatalog"
@export var economy_system_path: NodePath = "../../Systems/EconomySystem"
@export var territory_system_path: NodePath = "../../Systems/TerritorySystem"
@export var faction_system_path: NodePath = "../../Systems/FactionSystem"

@export var block_world_input_when_mouse_over_ui: bool = true

@export_group("Button Size")
@export var build_button_size: Vector2 = Vector2(192, 48)
@export var expand_button_size: Vector2 = Vector2(192, 48)
@export var faction_button_size: Vector2 = Vector2(110, 40)

@onready var placement_system: PlacementSystem = get_node_or_null(placement_system_path) as PlacementSystem
@onready var building_catalog: BuildingCatalog = get_node_or_null(building_catalog_path) as BuildingCatalog
@onready var economy_system: EconomySystem = get_node_or_null(economy_system_path) as EconomySystem
@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem
@onready var faction_system: FactionSystem = get_node_or_null(faction_system_path) as FactionSystem

@onready var build_panel: VBoxContainer = get_node_or_null("BuildPanel") as VBoxContainer

var resource_label: Label = null
var faction_panel: HBoxContainer = null
var is_mouse_over_ui: bool = false


func _ready() -> void:
	print("HUD ready.")

	if placement_system == null:
		push_error("HUD: PlacementSystem not found. Path = " + str(placement_system_path))
		return

	if building_catalog == null:
		push_error("HUD: BuildingCatalog not found. Path = " + str(building_catalog_path))
		return

	if economy_system == null:
		push_error("HUD: EconomySystem not found. Path = " + str(economy_system_path))
		return

	if territory_system == null:
		push_error("HUD: TerritorySystem not found. Path = " + str(territory_system_path))
		return

	if faction_system == null:
		push_error("HUD: FactionSystem not found. Path = " + str(faction_system_path))
		return

	if build_panel == null:
		push_error("HUD: BuildPanel not found.")
		return

	mouse_filter = Control.MOUSE_FILTER_PASS

	build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	build_panel.position = Vector2(10, 100)
	build_panel.custom_minimum_size = Vector2(200, 0)
	build_panel.size = Vector2(200, 0)
	build_panel.add_theme_constant_override("separation", 4)

	_create_resource_label()
	_create_faction_panel()

	_connect_ui_mouse_block_signals()
	set_process(true)

	economy_system.resources_changed.connect(_on_resources_changed)
	territory_system.expansion_mode_changed.connect(_on_expansion_mode_changed)
	faction_system.active_faction_changed.connect(_on_active_faction_changed)

	_update_resource_label()
	_rebuild_faction_buttons()
	_rebuild_panel_buttons()


func _process(_delta: float) -> void:
	_update_mouse_over_ui_state()


func is_blocking_world_input() -> bool:
	if not block_world_input_when_mouse_over_ui:
		return false

	return is_mouse_over_ui


func _create_resource_label() -> void:
	resource_label = get_node_or_null("ResourceLabel") as Label

	if resource_label == null:
		resource_label = Label.new()
		resource_label.name = "ResourceLabel"
		add_child(resource_label)

	resource_label.position = Vector2(10, 10)
	resource_label.custom_minimum_size = Vector2(600, 30)
	resource_label.mouse_filter = Control.MOUSE_FILTER_STOP


func _create_faction_panel() -> void:
	faction_panel = get_node_or_null("FactionPanel") as HBoxContainer

	if faction_panel == null:
		faction_panel = HBoxContainer.new()
		faction_panel.name = "FactionPanel"
		add_child(faction_panel)

	faction_panel.position = Vector2(10, 50)
	faction_panel.custom_minimum_size = Vector2(700, 40)
	faction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	faction_panel.add_theme_constant_override("separation", 6)


func _connect_ui_mouse_block_signals() -> void:
	if build_panel != null:
		build_panel.mouse_entered.connect(func() -> void:
			_set_mouse_over_ui(true)
		)

		build_panel.mouse_exited.connect(func() -> void:
			_update_mouse_over_ui_state()
		)

	if resource_label != null:
		resource_label.mouse_entered.connect(func() -> void:
			_set_mouse_over_ui(true)
		)

		resource_label.mouse_exited.connect(func() -> void:
			_update_mouse_over_ui_state()
		)

	if faction_panel != null:
		faction_panel.mouse_entered.connect(func() -> void:
			_set_mouse_over_ui(true)
		)

		faction_panel.mouse_exited.connect(func() -> void:
			_update_mouse_over_ui_state()
		)


func _update_mouse_over_ui_state() -> void:
	var new_value: bool = _is_mouse_inside_blocking_ui()
	_set_mouse_over_ui(new_value)


func _set_mouse_over_ui(value: bool) -> void:
	if is_mouse_over_ui == value:
		return

	is_mouse_over_ui = value

	print("HUD: is_mouse_over_ui =", is_mouse_over_ui)

	emit_signal("ui_mouse_block_changed", is_mouse_over_ui)


func _is_mouse_inside_blocking_ui() -> bool:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()

	if _is_mouse_inside_control(build_panel, mouse_position):
		return true

	if _is_mouse_inside_control(resource_label, mouse_position):
		return true

	if _is_mouse_inside_control(faction_panel, mouse_position):
		return true

	return false


func _is_mouse_inside_control(control: Control, mouse_position: Vector2) -> bool:
	if control == null:
		return false

	if not control.is_visible_in_tree():
		return false

	return control.get_global_rect().has_point(mouse_position)


func _update_resource_label() -> void:
	if resource_label == null:
		return

	if economy_system == null:
		return

	resource_label.text = economy_system.get_debug_text()


func _rebuild_faction_buttons() -> void:
	if faction_panel == null:
		return

	if faction_system == null:
		return

	for child in faction_panel.get_children():
		faction_panel.remove_child(child)
		child.queue_free()

	for faction in faction_system.get_all_factions():
		if faction == null:
			continue

		var captured_faction_id: StringName = faction.id

		var button: Button = Button.new()
		button.custom_minimum_size = faction_button_size
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		if faction_system.active_faction_id == captured_faction_id:
			button.text = "✓ " + faction.display_name
		else:
			button.text = faction.display_name

		button.modulate = faction.ui_color

		faction_panel.add_child(button)

		button.pressed.connect(func() -> void:
			_on_faction_button_pressed(captured_faction_id)
		)


func _rebuild_panel_buttons() -> void:
	for child in build_panel.get_children():
		build_panel.remove_child(child)
		child.queue_free()

	_create_expand_button()
	_create_separator()
	_create_build_buttons()

	call_deferred("_fit_build_panel_to_content")


func _fit_build_panel_to_content() -> void:
	if build_panel == null:
		return

	var content_size: Vector2 = build_panel.get_combined_minimum_size()
	content_size.x = max(content_size.x, 200.0)

	build_panel.custom_minimum_size = Vector2(200, 0)
	build_panel.size = content_size

	_update_mouse_over_ui_state()


func _create_expand_button() -> void:
	var button: Button = Button.new()

	if territory_system != null and territory_system.is_expansion_mode:
		button.text = "扩张中：左键扩张%d格 / 右键取消" % territory_system.expansion_cells_per_click
	else:
		button.text = "扩张领土"

	button.custom_minimum_size = expand_button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	build_panel.add_child(button)

	button.pressed.connect(func() -> void:
		_on_expand_button_pressed()
	)


func _create_separator() -> void:
	var separator: HSeparator = HSeparator.new()
	build_panel.add_child(separator)


func _create_build_buttons() -> void:
	var configs: Array[BuildingConfig] = building_catalog.get_all_configs()

	print("HUD: Building config count =", configs.size())

	for config in configs:
		if config == null:
			continue

		var captured_config: BuildingConfig = config

		var button: Button = Button.new()
		button.text = _get_button_text(config)
		button.custom_minimum_size = build_button_size
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		if economy_system != null:
			button.disabled = not economy_system.can_afford_config(config)

		build_panel.add_child(button)

		button.pressed.connect(func() -> void:
			_on_build_button_pressed(captured_config)
		)

		print("HUD: Button created:", config.display_name)


func _get_button_text(config: BuildingConfig) -> String:
	if config.cost > 0:
		return "%s  %s:%d" % [
			config.display_name,
			_get_resource_display_name(config.cost_resource_id),
			config.cost
		]

	return config.display_name


func _get_resource_display_name(resource_id: StringName) -> String:
	match resource_id:
		&"gold":
			return "金币"
		&"food":
			return "食物"
		&"stone":
			return "石头"
		_:
			return String(resource_id)


func _on_faction_button_pressed(faction_id: StringName) -> void:
	print("HUD: faction button pressed:", faction_id)

	if placement_system != null:
		placement_system.cancel_placing()

	if territory_system != null:
		territory_system.stop_expansion_mode()

	if faction_system != null:
		print("HUD: active faction before =", faction_system.active_faction_id)
		faction_system.set_active_faction(faction_id)
		print("HUD: active faction after =", faction_system.active_faction_id)


func _on_expand_button_pressed() -> void:
	print("HUD: expand territory button pressed.")

	if placement_system != null:
		placement_system.cancel_placing()

	if territory_system == null:
		push_error("HUD: territory_system is null.")
		return

	territory_system.toggle_expansion_mode()


func _on_build_button_pressed(config: BuildingConfig) -> void:
	print("HUD: selected building:", config.display_name)

	if territory_system != null:
		territory_system.stop_expansion_mode()

	if placement_system == null:
		push_error("HUD: placement_system is null.")
		return

	placement_system.start_placing(config)


func _on_resources_changed() -> void:
	_update_resource_label()
	_rebuild_panel_buttons()


func _on_expansion_mode_changed(_is_expanding: bool) -> void:
	_rebuild_panel_buttons()


func _on_active_faction_changed(_faction_id: StringName) -> void:
	_rebuild_faction_buttons()
	_rebuild_panel_buttons()
