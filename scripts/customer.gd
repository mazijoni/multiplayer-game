extends Node3D

signal customer_left

enum State {
	ENTERING,
	SEARCHING,
	WALKING_TO_SHELF,
	PICKING_TAPE,
	WALKING_TO_COUNTER,
	WAITING_AT_COUNTER,
	REACTING,
	LEAVING,
}

const GENRES: Array[String] = ["Action", "Horror", "Comedy", "Drama", "Sci-Fi", "Romance"]
const WALK_SPEED    := 2.5
const REACTION_TIME := 2.5
const MAX_WAIT_TIME := 20.0

@onready var request_label: Label3D          = $Label3D
@onready var nav_agent:     NavigationAgent3D = $NavigationAgent3D

@export var requested_genre: String = ""

var state: State = State.ENTERING

var _counter_pos:    Vector3 = Vector3.ZERO
var _exit_pos:       Vector3 = Vector3.ZERO
var _target_shelf:   Node3D  = null
var _carried_tape:   Node    = null
var _reaction_timer: float   = 0.0
var _wait_timer:     float   = 0.0

func _ready() -> void:
	add_to_group("customer")
	if requested_genre.is_empty():
		requested_genre = GENRES[randi() % GENRES.size()]
	request_label.text = ""
	nav_agent.path_desired_distance   = 0.5
	nav_agent.target_desired_distance = 0.8

func setup(counter_pos: Vector3, exit_pos: Vector3) -> void:
	_counter_pos = counter_pos
	_exit_pos    = exit_pos
	_set_nav(counter_pos + Vector3(0.0, 0.0, 3.5))
	state = State.ENTERING

func _process(delta: float) -> void:
	match state:
		State.ENTERING:
			_move(delta)
			if _close_to(nav_agent.target_position, 1.5):
				_set_state(State.SEARCHING)

		State.WALKING_TO_SHELF:
			_move(delta)
			if _close_to(nav_agent.target_position, 1.2):
				_set_state(State.PICKING_TAPE)

		State.WALKING_TO_COUNTER:
			_move(delta)
			if _close_to(nav_agent.target_position, 1.2):
				_set_state(State.WAITING_AT_COUNTER)

		State.WAITING_AT_COUNTER:
			_wait_timer -= delta
			if _wait_timer <= 0.0:
				_auto_complete()

		State.REACTING:
			_reaction_timer -= delta
			if _reaction_timer <= 0.0:
				_set_state(State.LEAVING)

		State.LEAVING:
			_move(delta)
			if _close_to(nav_agent.target_position, 1.0):
				customer_left.emit()
				queue_free()

func _set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.SEARCHING:
			request_label.text = "I want\n%s!" % requested_genre
			GameManager.active_customer = self
			_search_for_shelf()

		State.PICKING_TAPE:
			_do_pick()

		State.WAITING_AT_COUNTER:
			_wait_timer = MAX_WAIT_TIME
			request_label.text = "Ready to\ncheck out!\n[E] at counter"
			GameManager.active_customer = self

		State.REACTING:
			_reaction_timer = REACTION_TIME

		State.LEAVING:
			request_label.text = "Goodbye!"
			GameManager.on_customer_left()
			_set_nav(_exit_pos)

func _search_for_shelf() -> void:
	var shelves := get_tree().get_nodes_in_group("shelf")
	_target_shelf = null
	for s in shelves:
		if s.has_method("get_label_text") and s.get_label_text() == requested_genre:
			_target_shelf = s
			break
	if not _target_shelf:
		for s in shelves:
			if s.has_method("has_genre") and s.has_genre(requested_genre):
				_target_shelf = s
				break
	if _target_shelf:
		var front := _target_shelf.global_position + \
			_target_shelf.global_transform.basis.z * 1.2
		_set_nav(front)
		state = State.WALKING_TO_SHELF
		request_label.text = "Going to\nget a tape..."
	else:
		request_label.text = "No %s\ntapes found..." % requested_genre
		var t := get_tree().create_timer(1.8)
		t.timeout.connect(_on_no_shelf)

func _on_no_shelf() -> void:
	if is_instance_valid(self) and state == State.SEARCHING:
		_set_state(State.LEAVING)

func _do_pick() -> void:
	if not is_instance_valid(_target_shelf) or \
		not _target_shelf.has_method("get_tape_of_genre"):
		_target_shelf = null
		_set_state(State.SEARCHING)
		return
	var tape: Node = _target_shelf.get_tape_of_genre(requested_genre)
	if tape:
		_target_shelf.remove_tape(tape)
		_carried_tape = tape
		tape.visible  = false
		_set_nav(_counter_pos)
		state = State.WALKING_TO_COUNTER
		request_label.text = "Got it!\nGoing to\ncounter..."
	else:
		_target_shelf = null
		_set_state(State.SEARCHING)

func is_waiting_at_counter() -> bool:
	return state == State.WAITING_AT_COUNTER

func _auto_complete() -> void:
	var ok := _carried_tape != null
	GameManager.auto_complete_rental(self, _carried_tape)
	_finish_rental(ok)

func complete_rental(success: bool) -> void:
	_finish_rental(success)

func _finish_rental(success: bool) -> void:
	if _carried_tape:
		if success:
			_carried_tape.queue_free()
		else:
			_carried_tape.on_dropped(_counter_pos + Vector3(0.5, 0.6, 0.0))
		_carried_tape = null
	_set_state(State.LEAVING)

func receive_tape(tape: Node) -> bool:
	var ok: bool = (tape.genre == requested_genre)
	if ok:
		request_label.text = "Thanks!\nPerfect choice!"
		tape.mark_not_rewound()
		tape.on_picked_up()
	else:
		request_label.text = "Hmm...\nThat is not\n%s!" % requested_genre
		tape.on_dropped(global_position + Vector3(0.8, 0.5, 0.0))
	_set_state(State.REACTING)
	return ok

func _set_nav(pos: Vector3) -> void:
	nav_agent.target_position = pos

func _close_to(pos: Vector3, dist: float) -> bool:
	return global_position.distance_to(pos) < dist

func _move(delta: float) -> void:
	var target := nav_agent.target_position
	if global_position.distance_to(target) < 0.3:
		return
	var next := nav_agent.get_next_path_position()
	if next.distance_to(global_position) < 0.1:
		next = target
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		global_position += dir.normalized() * WALK_SPEED * delta
		var lp := global_position + dir.normalized()
		look_at(Vector3(lp.x, global_position.y, lp.z), Vector3.UP)
