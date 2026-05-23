extends Node

signal turn_started(faction_id: StringName)
signal turn_ended(faction_id: StringName)
signal turn_changed

var current_turn: int = 1
var turn_order: Array[StringName] = []
var current_index: int = 0


func _ready() -> void:
	_build_turn_order()
	_sync_active_faction_to_current_index()

	print("TurnSystem ready. turn=", current_turn, " active=", get_current_faction())


func _build_turn_order() -> void:
	turn_order.clear()
	for faction in FactionSystem.get_all_factions():
		if faction == null:
			continue
		turn_order.append(faction.id)


func _sync_active_faction_to_current_index() -> void:
	if turn_order.is_empty():
		return

	var current: StringName = turn_order[current_index]
	if FactionSystem.active_faction_id != current:
		FactionSystem.set_active_faction(current)


func get_current_faction() -> StringName:
	if turn_order.is_empty():
		return &""
	return turn_order[current_index]


func end_turn() -> void:
	if turn_order.is_empty():
		push_warning("TurnSystem: end_turn called but turn_order is empty.")
		return

	var ending_faction: StringName = turn_order[current_index]
	emit_signal("turn_ended", ending_faction)

	current_index = (current_index + 1) % turn_order.size()
	if current_index == 0:
		current_turn += 1

	var starting_faction: StringName = turn_order[current_index]
	FactionSystem.set_active_faction(starting_faction)

	print("TurnSystem: turn=", current_turn, " ", ending_faction, " -> ", starting_faction)

	emit_signal("turn_started", starting_faction)
	emit_signal("turn_changed")
