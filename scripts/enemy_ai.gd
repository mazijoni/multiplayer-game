extends CharacterBody3D

# ── tunables ──────────────────────────────────────────────────────────────────
@export var patrol_speed      : float = 2.5
@export var search_speed      : float = 4.0
@export var chase_speed       : float = 7.5
@export var sight_range       : float = 18.0
@export var sight_fov_deg     : float = 90.0
@export var hear_range_walk   : float = 8.0
@export var hear_range_sprint : float = 18.0
@export var kill_range        : float = 1.2
@export var search_duration   : float = 10.0   # seconds to search before giving up
@export var patrol_wait_time  : float = 2.0    # pause at each patrol point

# ── state machine ─────────────────────────────────────────────────────────────
enum State { PATROL, ALERTED, SEARCHING, CHASING, KILLING }
var state : State = State.PATROL

# ── internal refs ─────────────────────────────────────────────────────────────
@onready var nav_agent   : NavigationAgent3D = $NavigationAgent3D
@onready var eye         : Node3D            = $Eye          # raycast origin
@onready var sight_ray   : RayCast3D         = $Eye/SightRay

var player              : CharacterBody3D = null
var last_known_pos      : Vector3         = Vector3.ZERO
var search_timer        : float           = 0.0
var patrol_points       : Array[Vector3]  = []
var patrol_index        : int             = 0
var patrol_wait_timer   : float           = 0.0
var is_waiting_at_point : bool            = false
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ── ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	# Collect patrol waypoints from the Patrol group (Node3D markers in scene)
	for node in get_tree().get_nodes_in_group("patrol_points"):
		patrol_points.append(node.global_position)

	if patrol_points.is_empty():
		# Fall back: pace back and forth near spawn
		var o := global_position
		patrol_points = [o + Vector3(4, 0, 0), o + Vector3(-4, 0, 0)]

	_set_nav_target(patrol_points[patrol_index])

# ── physics process ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if player == null:
		return

	match state:
		State.PATROL:    _patrol(delta)
		State.ALERTED:   _alerted()
		State.SEARCHING: _searching(delta)
		State.CHASING:   _chasing(delta)
		State.KILLING:   pass   # handled in _chasing when close enough

# ── patrol ────────────────────────────────────────────────────────────────────
func _patrol(delta: float) -> void:
	if _can_see_player():
		_enter_chase()
		return

	if _can_hear_player():
		_enter_alerted()
		return

	if is_waiting_at_point:
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0.0:
			is_waiting_at_point = false
			patrol_index = (patrol_index + 1) % patrol_points.size()
			_set_nav_target(patrol_points[patrol_index])
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	_move_toward_nav_target(patrol_speed)

	if nav_agent.is_navigation_finished():
		is_waiting_at_point = true
		patrol_wait_timer   = patrol_wait_time

# ── alerted (heard something) ─────────────────────────────────────────────────
func _alerted() -> void:
	# Move toward last heard position; transition to chase if player seen
	if _can_see_player():
		_enter_chase()
		return
	last_known_pos = player.global_position
	_enter_search()

# ── searching ─────────────────────────────────────────────────────────────────
func _searching(delta: float) -> void:
	if _can_see_player():
		_enter_chase()
		return

	search_timer -= delta
	if search_timer <= 0.0:
		state = State.PATROL
		_set_nav_target(patrol_points[patrol_index])
		return

	_move_toward_nav_target(search_speed)

	if nav_agent.is_navigation_finished():
		# Sweep a small random offset from last known pos
		var sweep := last_known_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		_set_nav_target(sweep)

# ── chasing ───────────────────────────────────────────────────────────────────
func _chasing(_delta: float) -> void:
	if not _can_see_player():
		last_known_pos = player.global_position
		_enter_search()
		return

	last_known_pos = player.global_position
	_set_nav_target(last_known_pos)
	_move_toward_nav_target(chase_speed)

	if global_position.distance_to(player.global_position) <= kill_range:
		_kill_player()

# ── transitions ───────────────────────────────────────────────────────────────
func _enter_alerted() -> void:
	state          = State.ALERTED
	last_known_pos = player.global_position

func _enter_search() -> void:
	state        = State.SEARCHING
	search_timer = search_duration
	_set_nav_target(last_known_pos)

func _enter_chase() -> void:
	state = State.CHASING

func _kill_player() -> void:
	state = State.KILLING
	player.die()

# ── perception helpers ────────────────────────────────────────────────────────
func _can_see_player() -> bool:
	if player == null:
		return false
	var to_player := player.global_position - eye.global_position
	if to_player.length() > sight_range:
		return false
	# Field-of-view check
	var forward := -eye.global_transform.basis.z
	var angle   := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > sight_fov_deg * 0.5:
		return false
	# Line-of-sight raycast
	sight_ray.target_position = eye.to_local(player.global_position + Vector3(0, 0.8, 0))
	sight_ray.force_raycast_update()
	return not sight_ray.is_colliding()

func _can_hear_player() -> bool:
	if player == null:
		return false
	var dist    := global_position.distance_to(player.global_position)
	var p_speed := player.velocity.length()
	var hear_dist := hear_range_sprint if p_speed > 5.0 else hear_range_walk
	return dist <= hear_dist

# ── movement ──────────────────────────────────────────────────────────────────
func _move_toward_nav_target(speed: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var next := nav_agent.get_next_path_position()
	var dir  := (next - global_position).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	# Face movement direction
	if dir.length() > 0.1:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.15)

	move_and_slide()

func _set_nav_target(pos: Vector3) -> void:
	nav_agent.target_position = pos

# ── called by sound emitters (footsteps, etc.) ────────────────────────────────
func alert_at(pos: Vector3) -> void:
	if state == State.PATROL or state == State.SEARCHING:
		last_known_pos = pos
		_enter_alerted()
