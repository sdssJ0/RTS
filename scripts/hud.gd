extends Control

@export var placement_system_path: NodePath = "../../Systems/PlacementSystem"
@export var building_catalog_path: NodePath = "../../Systems/BuildingCatalog"
@export var economy_system_path: NodePath = "../../Systems/EconomySystem"
@export var territory_system_path: NodePath = "../../Systems/TerritorySystem"

@onready var placement_system: PlacementSystem = get_node_or_null(placement_system_path) as PlacementSystem
@onready var building_catalog: BuildingCatalog = get_node_or_null(building_catalog_path) as BuildingCatalog
@onready var economy_system: EconomySystem = get_node_or_null(economy_system_path) as EconomySystem
@onready var territory_system: TerritorySystem = get_node_or_null(territory_system_path) as TerritorySystem

@onready var build_panel: VBoxContainer = get_node_or_null("BuildPanel") as VBoxContainer

var resource_label: Label = null


func _ready() -> void:
	print("HUD ready.")

	if placement_system == null:
		push_error("HUD: PlacementSystem not found.")
		return

	if building_catalog == null:
		push_error("HUD: BuildingCatalog not found.")
		return

	if economy_system == null:
		push_error("HUD: EconomySystem not found.")
		return

	if territory_system == null:
		push_error("HUD: TerritorySystem not found.")
		return

	if build_panel == null:
		push_error("HUD: BuildPanel not found.")
		return

	mouse_filter = Control.MOUSE_FILTER_PASS
	build_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	build_panel.position = Vector2(10, 50)
	build_panel.custom_minimum_size = Vector2(200, 300)

	_create_resource_label()

	economy_system.resources_changed.connect(_on_resources_changed)
	territory_system.expansion_mode_changed.connect(_on_expansion_mode_changed)

	_update_resource_label()
	_rebuild_panel_buttons()


func _create_resource_label() -> void:
	resource_label = get_node_or_null("ResourceLabel") as Label

	if resource_label == null:
		resource_label = Label.new()
		resource_label.name = "ResourceLabel"
		add_child(resource_label)

	resource_label.position = Vector2(10, 10)
	resource_label.custom_minimum_size = Vector2(600, 30)
	resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_resource_label() -> void:
	if resource_label == null:
		return

	if economy_system == null:
		return

	resource_label.text = economy_system.get_debug_text()


func _rebuild_panel_buttons() -> void:
	for child in build_panel.get_children():
		child.queue_free()

	_create_expand_button()
	_create_separator()
	_create_build_buttons()


func _create_expand_button() -> void:
	var button := Button.new()

	if territory_system != null and territory_system.is_expansion_mode:
		button.text = "扩张中：左键扩张5格 / 右键取消"
	else:
		button.text = "扩张领土"

	button.custom_minimum_size = Vector2(180, 40)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	build_panel.add_child(button)

	button.pressed.connect(func():
		_on_expand_button_pressed()
	)


func _create_separator() -> void:
	var separator := HSeparator.new()
	build_panel.add_child(separator)


func _create_build_buttons() -> void:
	var configs: Array[BuildingConfig] = building_catalog.get_all_configs()

	print("HUD: Building config count =", configs.size())

	for config in configs:
		if config == null:
			continue

		var button := Button.new()
		button.text = _get_button_text(config)
		button.custom_minimum_size = Vector2(180, 36)
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		if economy_system != null:
			button.disabled = not economy_system.can_afford_config(config)

		build_panel.add_child(button)

		button.pressed.connect(func():
			_on_build_button_pressed(config)
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
