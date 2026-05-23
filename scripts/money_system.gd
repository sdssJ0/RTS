extends Node

signal resources_changed(faction_id: StringName)
signal resource_changed(faction_id: StringName, resource_id: StringName, amount: int)

# key = faction_id (StringName)
# value = Dictionary { resource_id (StringName) -> amount (int) }
var resources_by_faction: Dictionary = {}


func _ready() -> void:
	_init_pools_from_factions()
	print("EconomySystem ready.")
	_debug_print_all_pools()


func _init_pools_from_factions() -> void:
	resources_by_faction.clear()

	for faction in FactionSystem.get_all_factions():
		if faction == null:
			continue

		_ensure_pool(faction.id)
		var pool: Dictionary = resources_by_faction[faction.id]
		pool[&"gold"] = faction.starting_gold
		pool[&"food"] = faction.starting_food
		pool[&"stone"] = faction.starting_stone

		emit_signal("resources_changed", faction.id)


func _ensure_pool(faction_id: StringName) -> void:
	if not resources_by_faction.has(faction_id):
		resources_by_faction[faction_id] = {}


func _debug_print_all_pools() -> void:
	for faction_id in resources_by_faction.keys():
		var pool: Dictionary = resources_by_faction[faction_id]
		print("  ", faction_id, ":  gold=", pool.get(&"gold", 0),
			"  food=", pool.get(&"food", 0),
			"  stone=", pool.get(&"stone", 0))


func get_resource_amount(faction_id: StringName, resource_id: StringName) -> int:
	if not resources_by_faction.has(faction_id):
		return 0

	var pool: Dictionary = resources_by_faction[faction_id]
	return int(pool.get(resource_id, 0))


func set_resource_amount(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	_ensure_pool(faction_id)
	var pool: Dictionary = resources_by_faction[faction_id]
	pool[resource_id] = max(0, amount)

	emit_signal("resource_changed", faction_id, resource_id, get_resource_amount(faction_id, resource_id))
	emit_signal("resources_changed", faction_id)


func add_resource(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	_ensure_pool(faction_id)
	var pool: Dictionary = resources_by_faction[faction_id]

	var old_amount: int = int(pool.get(resource_id, 0))
	var new_amount: int = max(0, old_amount + amount)
	pool[resource_id] = new_amount

	print("EconomySystem: ", faction_id, " ", resource_id, " ", old_amount, " -> ", new_amount)

	emit_signal("resource_changed", faction_id, resource_id, new_amount)
	emit_signal("resources_changed", faction_id)


func can_afford(faction_id: StringName, resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true

	return get_resource_amount(faction_id, resource_id) >= amount


func try_spend(faction_id: StringName, resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true

	if not can_afford(faction_id, resource_id, amount):
		print("EconomySystem: not enough resource.")
		print("  Faction:", faction_id)
		print("  Resource:", resource_id)
		print("  Need:", amount)
		print("  Have:", get_resource_amount(faction_id, resource_id))
		return false

	add_resource(faction_id, resource_id, -amount)
	return true


func can_afford_config(faction_id: StringName, config: BuildingConfig) -> bool:
	if config == null:
		return false

	if config.cost <= 0:
		return true

	var resource_id: StringName = config.cost_resource_id

	if String(resource_id) == "":
		resource_id = &"gold"

	return can_afford(faction_id, resource_id, config.cost)


func try_spend_config(faction_id: StringName, config: BuildingConfig) -> bool:
	if config == null:
		return false

	if config.cost <= 0:
		return true

	var resource_id: StringName = config.cost_resource_id

	if String(resource_id) == "":
		resource_id = &"gold"

	return try_spend(faction_id, resource_id, config.cost)


func get_debug_text(faction_id: StringName) -> String:
	return "金币:%d  食物:%d  石头:%d" % [
		get_resource_amount(faction_id, &"gold"),
		get_resource_amount(faction_id, &"food"),
		get_resource_amount(faction_id, &"stone")
	]
