class_name BasicBuilding
extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D

var config: BuildingConfig = null
var grid_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	sprite_2d.centered = false
	_apply_config()

func setup(new_config: BuildingConfig, new_grid_cell: Vector2i) -> void:
	config = new_config
	grid_cell = new_grid_cell

	if is_node_ready():
		_apply_config()

func _apply_config() -> void:
	if config == null:
		return

	if sprite_2d == null:
		return

	if config.texture != null:
		sprite_2d.texture = config.texture
