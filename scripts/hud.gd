extends Control

@export var placement_system_path: NodePath = "../../Systems/PlacementSystem"
@export var building_catalog_path: NodePath = "../../Systems/BuildingCatalog"

@onready var placement_system: PlacementSystem = get_node(placement_system_path)
@onready var building_catalog: BuildingCatalog = get_node(building_catalog_path)
@onready var build_panel: VBoxContainer = $BuildPanel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	build_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	_rebuild_build_buttons()

func _rebuild_build_buttons() -> void:
	for child in build_panel.get_children():
		child.queue_free()

	var configs := building_catalog.get_all_configs()

	for config in configs:
		if config == null:
			continue

		var button := Button.new()
		button.text = _get_button_text(config)
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		build_panel.add_child(button)

		button.pressed.connect(_on_build_button_pressed.bind(config))

func _get_button_text(config: BuildingConfig) -> String:
	if config.cost > 0:
		return "%s  $%d" % [config.display_name, config.cost]

	return config.display_name

func _on_build_button_pressed(config: BuildingConfig) -> void:
	print("HUD: selected building:", config.display_name)
	placement_system.start_placing(config)
