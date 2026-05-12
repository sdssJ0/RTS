class_name BasicBuilding
extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D

var grid_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	sprite_2d.centered = false

func setup(new_grid_cell: Vector2i) -> void:
	grid_cell = new_grid_cell
