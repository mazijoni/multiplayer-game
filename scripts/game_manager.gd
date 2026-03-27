extends Node

signal customer_spawned(customer: Node)
signal tape_rented(tape_name: String, success: bool)
signal score_changed(new_score: int)

var held_tape:         Node = null
var active_customer:   Node = null
var score:             int  = 0
var rentals_completed: int  = 0
var wrong_tapes_given: int  = 0

func pick_up_tape(tape: Node) -> bool:
	held_tape = tape
	return true

func drop_tape() -> void:
	held_tape = null

func try_rent_tape(customer: Node) -> void:
	if held_tape == null or customer == null:
		return
	var tape: Node = held_tape
	held_tape  = null
	var ok: bool = customer.receive_tape(tape)
	_record(tape.tape_name, ok)

func process_counter_rental(customer: Node) -> void:
	if customer == null:
		return
	var tape: Node = customer._carried_tape
	var ok: bool  = tape != null and tape.genre == customer.requested_genre
	_record(customer.requested_genre, ok)
	customer.complete_rental(ok)

func auto_complete_rental(customer: Node, tape: Node) -> bool:
	var ok: bool = tape != null and tape.genre == customer.requested_genre
	_record(customer.requested_genre if customer else "?", ok)
	return ok

func on_customer_left() -> void:
	active_customer = null

func _record(tape_name: String, success: bool) -> void:
	if success:
		score += 10
		rentals_completed += 1
	else:
		score = max(0, score - 2)
		wrong_tapes_given += 1
	score_changed.emit(score)
	tape_rented.emit(tape_name, success)
