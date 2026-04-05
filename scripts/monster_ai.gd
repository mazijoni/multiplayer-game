extends CharacterBody3D
## Monster AI — state machine: PATROL → ALERTED → SEARCHING → CHASING → KILLING

enum State { PATROL, ALERTED, SEARCHING, CHASING, KILLING }

# ── Tuning ─────────────────────────────────────────────────────────────────────────────
@export var patrol_speed    : float = 2.0
@export var search_speed    : float = 3.5
@export var chase_speed     : float = 8.5
@export var sight_dist      : float = 20.0
@export var sight_fov       : float = 85.0   # degrees, each side of forward
@export var hear_dist_walk  : float = 8.0
@export var hear_dist_sprint: float = 20.0
@export var kill_dist       : float = 1.3
@export var search_time     : float = 12.0
@export var patrol_pause    : float = 2.5

# ── Node refs ───────────────────────────────────────────────────────────────────────────
@onready var nav      : NavigationAgent3D = $NavigationAgent3D
@onready var eye      : Node3D            = $Eye
@onready var eye_ray  : RayCast3D         = $Eye/SightRay

var _state        : State          = State.PATROL
var _player       : Node3D         = null
var _last_known   : Vector3        = Vector3.ZERO
var _search_t     : float          = 0.0
var _waypoints    : Array[Vector3] = []
var _wp_idx       : int            = 0
var _pause_t      : float          = 0.0
var _waiting      : bool           = false
var _gravity      : float          = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("monster")
	eye_ray.add_exception(self)
	_player = get_tree().get_first_node_in_group("player")
	for wp in get_tree().get_nodes_in_group("patrol_points"):
		_waypoints.append((wp as Node3D).global_position)
	if _waypoints.is_empty():
		_gen_default_waypoints()
	_set_dest(_waypoints[_wp_idx])

func _gen_default_waypoints() -> void:
	var o := global_position
	_waypoints = [
		o + Vector3( 6, 0,  0),
		o + Vector3( 0, 0,  6),
		o + Vector3(-6, 0,  0),
		o + Vector3( 0, 0, -6),
	]

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _player == null:
		move_and_slide()
		return
	match _state:
		State.PATROL:    _do_patrol(delta)
		State.ALERTED:   _do_alerted()
		State.SEARCHING: _do_searching(delta)
		State.CHASING:   _do_chasing()
		State.KILLING:   pass

# ── States ────────────────────────────────────────────────────────────────────────────
func _do_patrol(delta: float) -> void:
	if _can_see_player():
		_enter_chase()
		return
	if _can_hear_player():
		_enter_alerted()
		return
	if _waiting:
		_pause_t -= delta
		if _pause_t <= 0.0:
			_waiting = false
			_wp_idx  = (_wp_idx + 1) % _waypoints.size()
			_set_dest(_waypoints[_wp_idx])
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_move(patrol_speed)
	if nav.is_navigation_finished():
		_waiting = true
		_pause_t = patrol_pause

func _do_alerted() -> void:
	if _can_see_player():
		_enter_chase()
		return
	_last_known = _player.global_position
	_enter_search()

func _do_searching(delta: float) -> void:
	if _can_see_player():
		_enter_chase()
		return
	_search_t -= delta
	if _search_t <= 0.0:
		_state = State.PATROL
		_set_dest(_waypoints[_wp_idx])
		return
	_move(search_speed)
	if nav.is_navigation_finished():
		var sweep := _last_known + Vector3(
			randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		_set_dest(sweep)

func _do_chasing() -> void:
	if not _can_see_player():
		_last_known = _player.global_position
		_enter_search()
		return
	_last_known = _player.global_position
	_set_dest(_last_known)
	_move(chase_speed)
	if global_position.distance_to(_player.global_position) <= kill_dist:
		_state = State.KILLING
		if _player.has_method("die"):
			_player.die()

# ── Transitions ───────────────────────────────────────────────────────────────────────────
func _enter_alerted() -> void:
	_state      = State.ALERTED
	_last_known = _player.global_position

func _enter_search() -> void:
	_state    = State.SEARCHING
	_search_t = search_time
	_set_dest(_last_known)

func _enter_chase() -> void:
	_state = State.CHASING

# ── Perception ────────────────────────────────────────────────────────────────────────────
func _can_see_player() -> bool:
	if _player == null:
		return false
	var to_p := _player.global_position - eye.global_position
	if to_p.length() > sight_dist:
		return false
	var fwd   := -eye.global_transform.basis.z
	var angle := rad_to_deg(fwd.angle_to(to_p.normalized()))
	if angle > sight_fov:
		return false
	eye_ray.target_position = eye.to_local(_player.global_position + Vector3(0.0, 0.8, 0.0))
	eye_ray.force_raycast_update()
	if not eye_ray.is_colliding():
		return true
	return eye_ray.get_collider() == _player

func _can_hear_player() -> bool:
	if _player == null:
		return false
	var dist      : float = global_position.distance_to(_player.global_position)
	var p_spd     : float = Vector2(
		(_player as CharacterBody3D).velocity.x,
		(_player as CharacterBody3D).velocity.z).length()
	var threshold : float = hear_dist_sprint if p_spd > 5.0 else hear_dist_walk
	return dist <= threshold

# ── Navigation ────────────────────────────────────────────────────────────────────────────
func _move(spd: float) -> void:
	if nav.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var next : Vector3 = nav.get_next_path_position()
	var dir  : Vector3 = (next - global_position).normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.15)
	move_and_slide()

func _set_dest(pos: Vector3) -> void:
	nav.target_position = pos

# ── Called by GameManager when footsteps are heard ────────────────────────────────────────
func alert_sound(world_pos: Vector3, _is_sprint: bool) -> void:
	if _state == State.PATROL or _state == State.SEARCHING:
		_last_known = world_pos
		_enter_alerted()
