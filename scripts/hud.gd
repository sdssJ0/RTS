extends Control

@export var placement_system_path: NodePath = "../../Systems/PlacementSystem"
@export var basic_building_scene: PackedScene

@onready var placement_system: PlacementSystem = get_node(placement_system_path)
@onready var build_panel: VBoxContainer = $BuildPanel
@onready var build_basic_button: Button = $BuildPanel/BuildBasicButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	build_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	build_basic_button.mouse_filter = Control.MOUSE_FILTER_STOP

	build_basic_button.text = "放置建筑"
	build_basic_button.pressed.connect(_on_build_basic_button_pressed)

func _on_build_basic_button_pressed() -> void:
	if basic_building_scene == null:
		push_error("Basic building scene is not assigned on HUD.")
		return

	placement_system.start_placing(basic_building_scene)
