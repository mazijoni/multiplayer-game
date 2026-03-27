extends CharacterBody3D

@export var speed:        float = 4.0
@export var sprint_speed: float = 7.0
@export var mouse_sens:   float = 0.002

@onready var head:      Node3D    = $Head
@onready var camera:    Camera3D  = $Head/Camera3D
@onready var ray:       RayCast3D = $Head/Camera3D/RayCast3D
@onready var carry:     Node      = $CarryInventory
@onready var placement: Node      = $PlacementSystem

var _cur_interactable: Node   = null
var _cur_prompt:       String = ""

const GRAVITY := 9.8

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		head.rotate_x(-event.relative.y * mouse_sens)
		head.rotation.x = clamp(head.rotation.x, -PI * 0.45, PI * 0.45)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_move(delta)
	if placement.active:
		placement.update_preview(ray)
		if Input.is_action_just_pressed("interact"):
			placement.confirm()
		elif Input.is_action_just_pressed("cancel_action"):
			placement.cancel()
		return
	_update_interaction()
	if Input.is_action_just_pressed("interact") and _cur_interactable != null:
		_do_interact(_cur_interactable)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_move(_delta: float) -> void:
	var spd := sprint_speed if Input.is_action_pressed("sprint") else speed
	var dir := Vector3.ZERO
	var move_basis := global_transform.basis
	if Input.is_action_pressed("move_forward"):  dir -= move_basis.z
	if Input.is_action_pressed("move_back"):     dir += move_basis.z
	if Input.is_action_pressed("move_left"):     dir -= move_basis.x
	if Input.is_action_pressed("move_right"):    dir += move_basis.x
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()

# ── Interaction scanning ──────────────────────────────────────────────────────
# RayCast3D must have: collision_mask=6, collide_with_areas=true
#   Layer 2 (value 2) = tape StaticBody3D
#   Layer 3 (value 4) = interaction Area3D (shelves, counter, rewind)
func _update_interaction() -> void:
	_cur_interactable = null
	_cur_prompt       = ""
	if not ray.is_colliding():
		_update_ui_prompt("")
		return
	var col: Node = ray.get_collider()
	if col == null:
		return

	# Tape (StaticBody3D, layer 2)
	if col.is_in_group("tape"):
		if carry.is_full():
			_set_prompt(null, "Inventory full (10/10)")
		else:
			_set_prompt(col, "[E]  Pick up " + col.tape_name)
	# All other interactables (Area3D, layer 3)
	elif col is Area3D:
		var parent: Node = col.get_parent()
		if parent != null and parent.is_in_group("shelf"):
			if not carry.is_empty():
				if parent.has_space():
					_set_prompt(col, "[E]  Place tape on shelf")
				else:
					_set_prompt(null, "Shelf is full")
			else:
				_set_prompt(col, "[E]  Move shelf")
		elif col.is_in_group("counter"):
			var cust: Node = GameManager.active_customer
			if cust != null and cust.has_method("is_waiting_at_counter") and cust.is_waiting_at_counter():
				_set_prompt(col, "[E]  Complete rental")
			elif not carry.is_empty():
				_set_prompt(col, "[E]  Set tape on counter")
		elif col.is_in_group("rewind_machine") and not carry.is_empty():
			_set_prompt(col, "[E]  Rewind tapes")

func _set_prompt(interactable: Node, text: String) -> void:
	_cur_interactable = interactable
	_cur_prompt       = text
	_update_ui_prompt(text)

func _update_ui_prompt(text: String) -> void:
	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("set_prompt"):
		ui.set_prompt(text)

# ── Perform interaction ───────────────────────────────────────────────────────
func _do_interact(col: Node) -> void:
	if col.is_in_group("tape") and not carry.is_full():
		carry.add_tape(col)
		col.on_picked_up()
		return
	if not (col is Area3D):
		return
	var parent: Node = col.get_parent()
	if parent != null and parent.is_in_group("shelf"):
		if not carry.is_empty():
			var tape: Node = carry.pop_first()
			if not parent.add_tape(tape):
				carry.add_tape(tape)  # return tape if shelf is full
		else:
			placement.start(parent)
		return
	if col.is_in_group("counter"):
		var cust: Node = GameManager.active_customer
		if cust != null and cust.has_method("is_waiting_at_counter") and cust.is_waiting_at_counter():
			GameManager.process_counter_rental(cust)
		elif not carry.is_empty():
			var tape: Node = carry.pop_first()
			tape.on_dropped(col.global_position + Vector3(0.0, 0.5, 0.0))
		return
	if col.is_in_group("rewind_machine"):
		_rewind_all()

func _rewind_all() -> void:
	for tape: Node in carry.get_tapes():
		if tape.has_method("rewind"):
			tape.rewind()
