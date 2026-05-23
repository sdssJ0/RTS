extends Node

signal territory_changed

# key = Vector2i (cell)
# value = faction_id (StringName)
var cell_owner: Dictionary = {}


func _ready() -> void:
	_create_initial_territory()

	print("TerritoryService ready.")
	debug_print_faction_territory_counts()

	emit_signal("territory_changed")


# ─── Active-faction convenience passthroughs ──────────────────────────

func get_active_faction_id() -> StringName:
	if FactionSystem.active_faction_id == &"":
		return &""
	return FactionSystem.active_faction_id


# ─── Cell queries ─────────────────────────────────────────────────────

func get_cell_owner(cell: Vector2i) -> StringName:
	if not cell_owner.has(cell):
		return &""
	return cell_owner[cell] as StringName


func is_cell_owned(cell: Vector2i) -> bool:
	return is_cell_owned_by_faction(cell, get_active_faction_id())


func is_cell_owned_by_faction(cell: Vector2i, faction_id: StringName) -> bool:
	if faction_id == &"":
		return false
	if not cell_owner.has(cell):
		return false
	return cell_owner[cell] == faction_id


func is_area_owned(origin_cell: Vector2i, size_in_cells: Vector2i) -> bool:
	return is_area_owned_by_faction(origin_cell, size_in_cells, get_active_faction_id())


func is_area_owned_by_faction(
	origin_cell: Vector2i,
	size_in_cells: Vector2i,
	faction_id: StringName
) -> bool:
	if faction_id == &"":
		return false

	for y in range(size_in_cells.y):
		for x in range(size_in_cells.x):
			var cell: Vector2i = origin_cell + Vector2i(x, y)
			if not is_cell_owned_by_faction(cell, faction_id):
				return false

	return true


# ─── Cell modifications ───────────────────────────────────────────────

func add_owned_cell(cell: Vector2i) -> void:
	add_owned_cell_for_faction(cell, get_active_faction_id())


func add_owned_cell_for_faction(cell: Vector2i, faction_id: StringName) -> void:
	if faction_id == &"":
		return
	if cell_owner.has(cell):
		return
	cell_owner[cell] = faction_id


func add_owned_cells_for_faction(cells: Array[Vector2i], faction_id: StringName) -> int:
	if faction_id == &"":
		return 0

	var added: int = 0
	for cell in cells:
		if cell_owner.has(cell):
			continue
		cell_owner[cell] = faction_id
		added += 1

	if added > 0:
		emit_signal("territory_changed")

	return added


# ─── Cell listings ────────────────────────────────────────────────────

func get_owned_cells() -> Array[Vector2i]:
	return get_owned_cells_for_faction(get_active_faction_id())


func get_owned_cells_for_faction(faction_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in cell_owner.keys():
		var cell: Vector2i = key as Vector2i
		if cell_owner[cell] == faction_id:
			result.append(cell)
	return result


func get_all_owned_cell_owners() -> Dictionary:
	return cell_owner.duplicate()


# ─── Faction visual passthroughs ──────────────────────────────────────

func get_territory_color_for_faction(faction_id: StringName) -> Color:
	return FactionSystem.get_territory_color(faction_id)


func get_preview_color_for_active_faction() -> Color:
	return FactionSystem.get_preview_color(get_active_faction_id())


func get_building_texture_for_faction(
	faction_id: StringName,
	config: BuildingConfig
) -> Texture2D:
	if config == null:
		return null

	var fallback_texture: Texture2D = config.texture
	var building_id: StringName = _get_building_id_from_config(config)

	return FactionSystem.get_building_texture(
		faction_id,
		building_id,
		fallback_texture
	)


func get_building_texture_for_active_faction(config: BuildingConfig) -> Texture2D:
	return get_building_texture_for_faction(get_active_faction_id(), config)


func _get_building_id_from_config(config: BuildingConfig) -> StringName:
	if config == null:
		return &""

	var id_value: Variant = config.get("id")

	if typeof(id_value) == TYPE_STRING_NAME:
		return id_value as StringName

	if typeof(id_value) == TYPE_STRING:
		return StringName(id_value as String)

	if config.resource_path != "":
		return StringName(config.resource_path.get_file().get_basename())

	return StringName(config.display_name)


# ─── Initial territory ────────────────────────────────────────────────

func _create_initial_territory() -> void:
	cell_owner.clear()

	for faction in FactionSystem.get_all_factions():
		if faction == null:
			continue

		print("Create initial territory for faction:", faction.id, faction.display_name)

		for y in range(faction.initial_size.y):
			for x in range(faction.initial_size.x):
				var cell: Vector2i = faction.initial_origin + Vector2i(x, y)

				if cell_owner.has(cell):
					push_warning(
						"TerritoryService: initial territory overlap at "
						+ str(cell)
						+ ". Existing owner = "
						+ str(cell_owner[cell])
						+ ", ignored owner = "
						+ str(faction.id)
					)
					continue

				cell_owner[cell] = faction.id


# ─── Debug ────────────────────────────────────────────────────────────

func debug_print_faction_territory_counts() -> void:
	print("========== Territory Counts ==========")
	print("Total cells =", cell_owner.size())

	for faction in FactionSystem.get_all_factions():
		if faction == null:
			continue

		print(
			"Faction ",
			faction.id,
			" / ",
			faction.display_name,
			" cells = ",
			get_owned_cells_for_faction(faction.id).size()
		)

	print("======================================")
