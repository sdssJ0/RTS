class_name HUD
extends Control

signal ui_mouse_block_changed(is_blocking: bool)

@export var placement_system_path: NodePath = "../../Systems/PlacementSystem"
@export var expansion_controller_path: NodePath = "../../Systems/ExpansionController"

@export var block_world_input_when_mouse_over_ui: bool = true

@export_group("Button Size")
@export var build_button_size: Vector2 = Vector2(192, 48)
@export var expand_button_size: Vector2 = Vector2(192, 48)
@export var faction_button_size: Vector2 = Vector2(110, 40)

@onready var placement_system: PlacementSystem = get_node_or_null(placement_system_path) as PlacementSystem
@onready var expansion_controller: ExpansionController = get_node_or_null(expansion_controller_path) as ExpansionController

@onready var build_panel: VBoxContainer = get_node_or_null("BuildPanel") as VBoxContainer

var resource_panel: VBoxContainer = null
var faction_resource_labels: Dictionary = {}
var faction_panel: HBoxContainer = null
var is_mouse_over_ui: bool = false


func _ready() -> void:
	print("HUD ready.")

	if placement_system == null:
		push_error("HUD: PlacementSystem not found. Path = " + str(placement_system_path))
		return

	if expansion_controller == null:
		push_error("HUD: ExpansionController not found. Path = " + str(expansion_controller_path))
		return

	if build_panel == null:
		push_error("HUD: BuildPanel not found.")
		return

	mouse_filter = Control.MOUSE_FILTER_PASS

	build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	build_panel.position = Vector2(10, 120)
	build_panel.custom_minimum_size = Vector2(200, 0)
	build_panel.size = Vector2(200, 0)
	build_panel.add_theme_constant_override("separation", 4)

	_create_resource_panel()
	_create_faction_panel()

	_connect_ui_mouse_block_signals()
	set_process(true)

	EconomySystem.resources_changed.connect(_on_resources_changed)
	expansion_controller.expansion_mode_changed.connect(_on_expansion_mode_changed)
	FactionSystem.active_faction_changed.connect(_on_active_faction_changed)
	TurnSystem.turn_changed.connect(_on_turn_changed)

	_update_resource_panel()
	_rebuild_turn_panel()
	_rebuild_panel_buttons()


func _process(_delta: float) -> void:
	_update_mouse_over_ui_state()


func is_blocking_world_input() -> bool:
	if not block_world_input_when_mouse_over_ui:
		return false

	return is_mouse_over_ui


func _create_resource_panel() -> void:
	resource_panel = get_node_or_null("ResourcePanel") as VBoxContainer

	if resource_panel == null:
		resource_panel = VBoxContainer.new()
		resource_panel.name = "ResourcePanel"
		add_child(resource_panel)

	resource_panel.position = Vector2(10, 10)
	resource_panel.custom_minimum_size = Vector2(600, 0)
	resource_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	resource_panel.add_theme_constant_override("separation", 2)

	_rebuild_faction_resource_labels()


func _rebuild_faction_resource_labels() -> void:
	if resource_panel == null:
		return

	for child in resource_panel.get_children():
		resource_panel.remove_child(child)
		child.queue_free()

	faction_resource_labels.clear()

	for faction in FactionSystem.get_all_factions():
		if faction == null:
			continue

		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.add_theme_color_override("font_color", faction.ui_color)
		resource_panel.add_child(label)

		faction_resource_labels[faction.id] = label


func _create_faction_panel() -> void:
	faction_panel = get_node_or_null("FactionPanel") as HBoxContainer

	if faction_panel == null:
		faction_panel = HBoxContainer.new()
		faction_panel.name = "FactionPanel"
		add_child(faction_panel)

	faction_panel.position = Vector2(10, 70)
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

	if resource_panel != null:
		resource_panel.mouse_entered.connect(func() -> void:
			_set_mouse_over_ui(true)
		)

		resource_panel.mouse_exited.connect(func() -> void:
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

	emit_signal("ui_mouse_block_changed", is_mouse_over_ui)


func _is_mouse_inside_blocking_ui() -> bool:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()

	if _is_mouse_inside_control(build_panel, mouse_position):
		return true

	if _is_mouse_inside_control(resource_panel, mouse_position):
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


func _update_resource_panel() -> void:
	for faction_id in faction_resource_labels.keys():
		var label: Label = faction_resource_labels[faction_id]
		if label == null:
			continue

		var faction: FactionConfig = FactionSystem.get_faction(faction_id)
		var marker: String = "▶ " if faction_id == FactionSystem.active_faction_id else "  "
		var name_str: String = faction.display_name if faction != null else String(faction_id)

		label.text = "%s%s  %s" % [marker, name_str, EconomySystem.get_debug_text(faction_id)]


func _rebuild_turn_panel() -> void:
	if faction_panel == null:
		return

	for child in faction_panel.get_children():
		faction_panel.remove_child(child)
		child.queue_free()

	var faction_id: StringName = FactionSystem.active_faction_id
	var faction: FactionConfig = FactionSystem.get_faction(faction_id)
	var faction_name: String = faction.display_name if faction != null else String(faction_id)

	var turn_label: Label = Label.new()
	turn_label.text = "回合 %d  ▶ %s" % [TurnSystem.current_turn, faction_name]
	if faction != null:
		turn_label.add_theme_color_override("font_color", faction.ui_color)
	turn_label.mouse_filter = Control.MOUSE_FILTER_STOP
	faction_panel.add_child(turn_label)

	var end_turn_button: Button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = faction_button_size
	end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	faction_panel.add_child(end_turn_button)

	end_turn_button.pressed.connect(_on_end_turn_pressed)


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

	if expansion_controller != null and expansion_controller.is_expansion_mode:
		button.text = "扩张中：左键扩张%d格 / 右键取消" % expansion_controller.expansion_cells_per_click
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
	var configs: Array[BuildingConfig] = BuildingCatalog.get_all_configs()

	for config in configs:
		if config == null:
			continue

		var captured_config: BuildingConfig = config

		var button: Button = Button.new()
		button.text = _get_button_text(config)
		button.custom_minimum_size = build_button_size
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		button.disabled = not EconomySystem.can_afford_config(FactionSystem.active_faction_id, config)

		build_panel.add_child(button)

		button.pressed.connect(func() -> void:
			_on_build_button_pressed(captured_config)
		)


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


func _on_end_turn_pressed() -> void:
	if placement_system != null:
		placement_system.cancel_placing()

	if expansion_controller != null:
		expansion_controller.stop_expansion_mode()

	TurnSystem.end_turn()


func _on_expand_button_pressed() -> void:
	if placement_system != null:
		placement_system.cancel_placing()

	if expansion_controller == null:
		push_error("HUD: expansion_controller is null.")
		return

	expansion_controller.toggle_expansion_mode()


func _on_build_button_pressed(config: BuildingConfig) -> void:
	if expansion_controller != null:
		expansion_controller.stop_expansion_mode()

	if placement_system == null:
		push_error("HUD: placement_system is null.")
		return

	placement_system.start_placing(config)


func _on_resources_changed(_faction_id: StringName) -> void:
	_update_resource_panel()
	_rebuild_panel_buttons()


func _on_expansion_mode_changed(_is_expanding: bool) -> void:
	_rebuild_panel_buttons()


func _on_active_faction_changed(_faction_id: StringName) -> void:
	_update_resource_panel()
	_rebuild_turn_panel()
	_rebuild_panel_buttons()


func _on_turn_changed() -> void:
	_rebuild_turn_panel()
