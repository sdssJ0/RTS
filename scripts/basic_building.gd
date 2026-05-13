class_name BasicBuilding
extends Node2D

@onready var sprite_2d: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

var config: BuildingConfig = null
var grid_cell: Vector2i = Vector2i.ZERO

var economy_system: EconomySystem = null

var is_preview: bool = false
var production_timer: float = 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 100
	visible = true

	if sprite_2d == null:
		push_error("BasicBuilding: Sprite2D node not found. Please add child Sprite2D.")
		return

	sprite_2d.visible = true
	sprite_2d.centered = false
	sprite_2d.position = Vector2.ZERO
	sprite_2d.z_as_relative = false
	sprite_2d.z_index = 101

	_apply_config()


func _process(delta: float) -> void:
	if is_preview:
		return

	if config == null:
		return

	if economy_system == null:
		return

	if not config.has_production():
		return

	production_timer += delta

	if production_timer >= config.production_interval:
		production_timer -= config.production_interval
		_produce_resource()


func setup(new_config: BuildingConfig, new_grid_cell: Vector2i) -> void:
	config = new_config
	grid_cell = new_grid_cell
	production_timer = 0.0

	if is_node_ready():
		_apply_config()


func set_economy_system(new_economy_system: EconomySystem) -> void:
	economy_system = new_economy_system


func set_preview_mode(value: bool) -> void:
	is_preview = value

	if is_preview:
		production_timer = 0.0


func _apply_config() -> void:
	if sprite_2d == null:
		return

	if config != null and config.texture != null:
		sprite_2d.texture = config.texture
	else:
		sprite_2d.texture = _create_fallback_texture()

	sprite_2d.centered = false
	sprite_2d.position = Vector2.ZERO
	sprite_2d.visible = true

	if not is_preview:
		sprite_2d.modulate = Color.WHITE


func _produce_resource() -> void:
	if economy_system == null:
		return

	if config == null:
		return

	if not config.has_production():
		return

	economy_system.add_resource(
		config.production_resource_id,
		config.production_amount
	)

	print(
		"Building produced:",
		config.display_name,
		" +",
		config.production_amount,
		" ",
		config.production_resource_id
	)


func _create_fallback_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	for x in range(16):
		image.set_pixel(x, 0, Color.BLACK)
		image.set_pixel(x, 15, Color.BLACK)

	for y in range(16):
		image.set_pixel(0, y, Color.BLACK)
		image.set_pixel(15, y, Color.BLACK)

	return ImageTexture.create_from_image(image)
