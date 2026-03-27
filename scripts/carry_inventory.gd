extends Node

const MAX_TAPES := 10

var held_tapes: Array[Node] = []

signal inventory_changed(count: int, max_count: int)
signal inventory_full

func add_tape(tape: Node) -> bool:
	if held_tapes.size() >= MAX_TAPES:
		inventory_full.emit()
		return false
	held_tapes.append(tape)
	inventory_changed.emit(held_tapes.size(), MAX_TAPES)
	return true

func remove_tape(tape: Node) -> bool:
	var idx := held_tapes.find(tape)
	if idx < 0:
		return false
	held_tapes.remove_at(idx)
	inventory_changed.emit(held_tapes.size(), MAX_TAPES)
	return true

func pop_first() -> Node:
	if held_tapes.is_empty():
		return null
	var t := held_tapes[0]
	remove_tape(t)
	return t

func get_count() -> int:
	return held_tapes.size()

func is_empty() -> bool:
	return held_tapes.is_empty()

func is_full() -> bool:
	return held_tapes.size() >= MAX_TAPES
