extends StaticBody3D

## initial_genre seeds the first tape batch. Does not lock the label.
@export var initial_genre: String = "Action"
@export var max_tapes:     int    = 5

@onready var genre_label:    Label3D = $Label3D
@onready var tape_container: Node3D  = $TapeContainer

var stored_tapes: Array[Node] = []

func _ready() -> void:
	add_to_group("shelf")
	update_label()

# ── Slot layout ───────────────────────────────────────────────────────────────
# Local position for the nth tape inside TapeContainer.
# x spreads tapes along the shelf; y places them on the lower row;
# z = 0.22 makes them protrude past the shelf face (half-depth 0.175 m).
func _slot_local(index: int) -> Vector3:
	var span := (max_tapes - 1) * 0.17
	var x    := -span * 0.5 + index * 0.17
	return Vector3(x, -0.55, 0.22)

# ── Public API ────────────────────────────────────────────────────────────────
func add_tape(tape: Node) -> bool:
	if stored_tapes.size() >= max_tapes:
		return false
	stored_tapes.append(tape)
	tape.current_shelf = self
	# Reparent into TapeContainer (global transform preserved then overwritten).
	tape.reparent(tape_container, true)
	tape.on_shelved(_slot_local(stored_tapes.size() - 1))
	update_label()
	return true

func remove_tape(tape: Node) -> bool:
	var idx := stored_tapes.find(tape)
	if idx < 0:
		return false
	stored_tapes.remove_at(idx)
	tape.current_shelf = null
	# Move tape back to the scene root, preserving its world position.
	tape.reparent(get_tree().current_scene, true)
	update_label()
	return true

## Returns the first stored tape whose genre matches, or null.
func get_tape_of_genre(genre: String) -> Node:
	for t in stored_tapes:
		if t.genre == genre:
			return t
	return null

func has_genre(genre: String) -> bool:
	for t in stored_tapes:
		if t.genre == genre:
			return true
	return false

func has_space() -> bool:
	return stored_tapes.size() < max_tapes

# ── Genre label ───────────────────────────────────────────────────────────────
func get_label_text() -> String:
	if stored_tapes.is_empty():
		return "Empty"
	var first: String = stored_tapes[0].genre
	for t in stored_tapes:
		if t.genre != first:
			return "Mixed"
	return first

func update_label() -> void:
	if genre_label:
		genre_label.text = get_label_text()
