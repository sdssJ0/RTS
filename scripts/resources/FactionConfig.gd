class_name FactionConfig
extends Resource

@export var id: StringName = &"player"
@export var display_name: String = "玩家"

@export_group("Colors")
@export var territory_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var preview_color: Color = Color(0.2, 1.0, 1.0, 0.35)

# 这个颜色以后可以只给 UI 按钮用，不再用于建筑本体上色。
@export var ui_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Initial Territory")
@export var initial_origin: Vector2i = Vector2i(20, 25)
@export var initial_size: Vector2i = Vector2i(10, 10)

@export_group("Building Textures")
@export var building_textures: Array[FactionBuildingTexture] = []


func get_building_texture(building_id: StringName, fallback_texture: Texture2D = null) -> Texture2D:
	for item in building_textures:
		if item == null:
			continue

		if item.building_id == building_id:
			if item.texture != null:
				return item.texture

	return fallback_texture
