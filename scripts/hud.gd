extends Control

@export var placement_system_path: NodePath = "../../Systems/PlacementSystem"
@export var building_catalog_path: NodePath = "../../Systems/BuildingCatalog"
@export var economy_system_path: NodePath = "../../Systems/EconomySystem"

@onready var placement_system: PlacementSystem = get_node_or_null(placement_system_path) as PlacementSystem
@onready var building_catalog: BuildingCatalog = get_node_or_null(building_catalog_path) as BuildingCatalog
@onready var economy_system: EconomySystem = get_node_or_null(economy_system_path) as EconomySystem

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

	if build_panel == null:
		push_error("HUD: BuildPanel not found.")
		return

	mouse_filter = Control.MOUSE_FILTER_PASS
	build_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	build_panel.position = Vector2(10, 50)
	build_panel.custom_minimum_size = Vector2(180, 240)

	_create_resource_label()

	economy_system.resources_changed.connect(_on_resources_changed)

	_update_resource_label()
	_rebuild_build_buttons()


func _create_resource_label() -> void:
	resource_label = get_node_or_null("ResourceLabel") as Label

	if resource_label == null:
		resource_label = Label.new()
		resource_label.name = "ResourceLabel"
		add_child(resource_label)

	resource_label.position = Vector2(10, 10)
	resource_label.custom_minimum_size = Vector2(500, 30)
	resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_resource_label() -> void:
	if resource_label == null:
		return

	if economy_system == null:
		return

	resource_label.text = economy_system.get_debug_text()


func _rebuild_build_buttons() -> void:
	for child in build_panel.get_children():
		child.queue_free()

	var configs: Array[BuildingConfig] = building_catalog.get_all_configs()

	print("HUD: Building config count =", configs.size())

	for config in configs:
		if config == null:
			continue

		var button := Button.new()
		button.text = _get_button_text(config)
		button.custom_minimum_size = Vector2(160, 36)
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


func _on_build_button_pressed(config: BuildingConfig) -> void:
	print("HUD: selected building:", config.display_name)

	if placement_system == null:
		push_error("HUD: placement_system is null.")
		return

	placement_system.start_placing(config)


func _on_resources_changed() -> void:
	_update_resource_label()
	_rebuild_build_buttons()
