class_name BasicBuilding
extends Node2D

@export var sprite_path: NodePath = "Sprite2D"

var config: BuildingConfig = null
var grid_cell: Vector2i = Vector2i.ZERO
var is_preview: bool = false

var owner_faction_id: StringName = &""
var owner_texture: Texture2D = null

var production_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D


func _ready() -> void:
	_ensure_sprite()
	apply_config_visual()
	apply_owner_visual()


func _process(delta: float) -> void:
	if is_preview:
		return

	if config == null:
		return

	if not _has_valid_production():
		return

	production_timer += delta

	if production_timer >= config.production_interval:
		production_timer -= config.production_interval

		EconomySystem.add_resource(
			owner_faction_id,
			config.production_resource_id,
			config.production_amount
		)


func setup(building_config: BuildingConfig, cell: Vector2i) -> void:
	config = building_config
	grid_cell = cell

	apply_config_visual()
	apply_owner_visual()


func set_preview_mode(value: bool) -> void:
	is_preview = value

	if is_preview:
		set_preview_valid(false)
	else:
		apply_owner_visual()


func set_preview_valid(can_place: bool) -> void:
	_ensure_sprite()

	if not is_preview:
		return

	var preview_color: Color

	if can_place:
		preview_color = Color(0.2, 1.0, 0.2, 0.65)
	else:
		preview_color = Color(1.0, 0.2, 0.2, 0.65)

	if sprite != null:
		sprite.modulate = preview_color
	else:
		modulate = preview_color


func set_display_texture(texture: Texture2D) -> void:
	_ensure_sprite()

	if texture == null:
		return

	if sprite != null:
		sprite.texture = texture


func apply_config_visual() -> void:
	_ensure_sprite()

	if config == null:
		return

	if config.texture != null:
		set_display_texture(config.texture)


func apply_owner_visual() -> void:
	_ensure_sprite()

	if owner_texture != null:
		set_display_texture(owner_texture)

	if is_preview:
		return

	if sprite != null:
		sprite.modulate = Color.WHITE
	else:
		modulate = Color.WHITE


func _ensure_sprite() -> void:
	if sprite != null:
		return

	sprite = get_node_or_null(sprite_path) as Sprite2D

	if sprite != null:
		return

	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	add_child(sprite)


func _has_valid_production() -> bool:
	if config == null:
		return false

	if config.has_method("has_production"):
		return config.has_production()

	if config.production_resource_id == &"":
		return false

	if config.production_amount == 0:
		return false

	if config.production_interval <= 0.0:
		return false

	return true
