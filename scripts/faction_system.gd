extends Node

signal active_faction_changed(faction_id: StringName)

@export var factions: Array[FactionConfig] = []
@export var default_active_faction_id: StringName = &"blue"

var active_faction_id: StringName = &""


func _enter_tree() -> void:
	_load_default_factions_if_empty()
	_ensure_active_faction()


func _ready() -> void:
	_load_default_factions_if_empty()
	_ensure_active_faction()

	print("FactionSystem ready. Active faction =", active_faction_id)

	for faction in get_all_factions():
		print("  Faction:", faction.id, faction.display_name)


func _load_default_factions_if_empty() -> void:
	if not factions.is_empty():
		return

	factions = [
		preload("res://resources/factions/BlueFaction.tres"),
		preload("res://resources/factions/RedFaction.tres"),
	]


func _ensure_active_faction() -> void:
	if active_faction_id != &"":
		return

	if factions.is_empty():
		active_faction_id = default_active_faction_id
		return

	if has_faction(default_active_faction_id):
		active_faction_id = default_active_faction_id
	else:
		active_faction_id = factions[0].id


func get_all_factions() -> Array[FactionConfig]:
	var result: Array[FactionConfig] = []

	for faction in factions:
		if faction != null:
			result.append(faction)

	return result


func has_faction(faction_id: StringName) -> bool:
	return get_faction(faction_id) != null


func get_faction(faction_id: StringName) -> FactionConfig:
	for faction in factions:
		if faction == null:
			continue

		if faction.id == faction_id:
			return faction

	return null


func get_active_faction() -> FactionConfig:
	_ensure_active_faction()
	return get_faction(active_faction_id)


func set_active_faction(faction_id: StringName) -> void:
	_ensure_active_faction()

	if active_faction_id == faction_id:
		print("FactionSystem: active faction already =", active_faction_id)
		return

	if not has_faction(faction_id):
		push_warning("FactionSystem: faction not found: " + str(faction_id))
		return

	active_faction_id = faction_id

	print("FactionSystem: active faction changed to:", active_faction_id)

	emit_signal("active_faction_changed", active_faction_id)


func get_territory_color(faction_id: StringName) -> Color:
	var faction: FactionConfig = get_faction(faction_id)

	if faction == null:
		return Color.WHITE

	return faction.territory_color


func get_preview_color(faction_id: StringName) -> Color:
	var faction: FactionConfig = get_faction(faction_id)

	if faction == null:
		return Color(1.0, 1.0, 1.0, 0.35)

	return faction.preview_color


func get_ui_color(faction_id: StringName) -> Color:
	var faction: FactionConfig = get_faction(faction_id)

	if faction == null:
		return Color.WHITE

	return faction.ui_color


func get_building_texture(
	faction_id: StringName,
	building_id: StringName,
	fallback_texture: Texture2D = null
) -> Texture2D:
	var faction: FactionConfig = get_faction(faction_id)

	if faction == null:
		return fallback_texture

	return faction.get_building_texture(building_id, fallback_texture)


func get_active_building_texture(
	building_id: StringName,
	fallback_texture: Texture2D = null
) -> Texture2D:
	_ensure_active_faction()
	return get_building_texture(active_faction_id, building_id, fallback_texture)


func get_active_preview_color() -> Color:
	_ensure_active_faction()
	return get_preview_color(active_faction_id)


func get_active_territory_color() -> Color:
	_ensure_active_faction()
	return get_territory_color(active_faction_id)
