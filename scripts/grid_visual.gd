extends Node2D

@export var cell_size: int = 16
@export var columns: int = 80
@export var rows: int = 45
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.22)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var width: int = columns * cell_size
	var height: int = rows * cell_size

	for x in range(columns + 1):
		var x_position: float = x * cell_size

		draw_line(
			Vector2(x_position, 0),
			Vector2(x_position, height),
			line_color,
			1.0
		)

	for y in range(rows + 1):
		var y_position: float = y * cell_size

		draw_line(
			Vector2(0, y_position),
			Vector2(width, y_position),
			line_color,
			1.0
		)
