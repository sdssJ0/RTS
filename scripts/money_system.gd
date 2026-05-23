extends Node

signal resources_changed
signal resource_changed(resource_id: StringName, amount: int)

@export var starting_gold: int = 200
@export var starting_food: int = 0
@export var starting_stone: int = 0

var resources: Dictionary = {}


func _ready() -> void:
	resources[&"gold"] = starting_gold
	resources[&"food"] = starting_food
	resources[&"stone"] = starting_stone

	print("EconomySystem ready.")
	print("  Gold:", get_resource_amount(&"gold"))
	print("  Food:", get_resource_amount(&"food"))
	print("  Stone:", get_resource_amount(&"stone"))

	emit_signal("resources_changed")


func get_resource_amount(resource_id: StringName) -> int:
	return int(resources.get(resource_id, 0))


func set_resource_amount(resource_id: StringName, amount: int) -> void:
	resources[resource_id] = max(0, amount)

	emit_signal("resource_changed", resource_id, get_resource_amount(resource_id))
	emit_signal("resources_changed")


func add_resource(resource_id: StringName, amount: int) -> void:
	var old_amount: int = get_resource_amount(resource_id)
	var new_amount: int = max(0, old_amount + amount)

	resources[resource_id] = new_amount

	print("EconomySystem: resource changed:", resource_id, old_amount, "->", new_amount)

	emit_signal("resource_changed", resource_id, new_amount)
	emit_signal("resources_changed")


func can_afford(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true

	return get_resource_amount(resource_id) >= amount


func try_spend(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true

	if not can_afford(resource_id, amount):
		print("EconomySystem: not enough resource.")
		print("  Resource:", resource_id)
		print("  Need:", amount)
		print("  Have:", get_resource_amount(resource_id))
		return false

	add_resource(resource_id, -amount)
	return true


func can_afford_config(config: BuildingConfig) -> bool:
	if config == null:
		return false

	if config.cost <= 0:
		return true

	var resource_id: StringName = config.cost_resource_id

	if String(resource_id) == "":
		resource_id = &"gold"

	return can_afford(resource_id, config.cost)


func try_spend_config(config: BuildingConfig) -> bool:
	if config == null:
		return false

	if config.cost <= 0:
		return true

	var resource_id: StringName = config.cost_resource_id

	if String(resource_id) == "":
		resource_id = &"gold"

	return try_spend(resource_id, config.cost)


func get_debug_text() -> String:
	return "金币:%d  食物:%d  石头:%d" % [
		get_resource_amount(&"gold"),
		get_resource_amount(&"food"),
		get_resource_amount(&"stone")
	]
