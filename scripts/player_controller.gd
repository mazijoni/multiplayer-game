extends CharacterBody3D
class_name PlayerController
## First-person player: movement, stamina, head-bob, camera sway, crouch.

# ── Movement ──────────────────────────────────────────────────────────────────────────────
@export var walk_speed    : float = 3.5
@export var sprint_speed  : float = 7.5
@export var crouch_speed  : float = 1.5
@export var mouse_sens    : float = 0.002
@export var move_accel    : float = 10.0
@export var move_decel    : float = 14.0

# ── Stamina ───────────────────────────────────────────────────────────────────────────
@export var max_stamina   : float = 100.0
@export var stamina_drain : float = 22.0
@export var stamina_regen : float = 12.0

# ── Head bob ──────────────────────────────────────────────────────────────────────────
@export var bob_freq_walk   : float = 2.0
@export var bob_freq_sprint : float = 3.5
@export var bob_amp_v       : float = 0.04
@export var bob_amp_h       : float = 0.02

# ── Crouch ────────────────────────────────────────────────────────────────────────────
@export var stand_height    : float = 1.75
@export var crouch_height   : float = 0.90
@export var crouch_lerp_spd : float = 10.0

# ── Node refs ───────────────────────────────────────────────────────────────────────────
@onready var cam_pivot  : Node3D           = $CameraPivot
@onready var cam_node   : Camera3D         = $CameraPivot/Camera3D
@onready var col_shape  : CollisionShape3D = $CollisionShape3D

var _gravity      : float   = ProjectSettings.get_setting("physics/3d/default_gravity")
var _stamina      : float   = 100.0
var _crouching    : bool    = false
var _dead         : bool    = false
var _bob_t        : float   = 0.0
var _pivot_base_y : float   = 0.0
var _mouse_delta  : Vector2 = Vector2.ZERO
var _step_accum   : float   = 0.0

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pivot_base_y = cam_pivot.position.y
	var cap := col_shape.shape as CapsuleShape3D
	if cap:
		col_shape.position.y = cap.height * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative
		rotate_y(-event.relative.x * mouse_sens)
		cam_pivot.rotate_x(-event.relative.y * mouse_sens)
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_apply_gravity(delta)
	_update_crouch(delta)
	_update_stamina(delta)
	_update_movement(delta)
	_update_head_bob(delta)
	_update_sway(delta)
	move_and_slide()
	_tick_footstep(delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

func _update_crouch(delta: float) -> void:
	var target_h : float = crouch_height if Input.is_action_pressed("crouch") else stand_height
	_crouching = (target_h == crouch_height)
	var cap := col_shape.shape as CapsuleShape3D
	if cap:
		cap.height           = lerp(cap.height, target_h, crouch_lerp_spd * delta)
		col_shape.position.y = cap.height * 0.5
	var target_y := _pivot_base_y * (target_h / stand_height)
	cam_pivot.position.y = lerp(cam_pivot.position.y, target_y, crouch_lerp_spd * delta)

func _update_stamina(delta: float) -> void:
	var h_spd     := Vector2(velocity.x, velocity.z).length()
	var sprinting := Input.is_action_pressed("sprint") and not _crouching \
					 and h_spd > 0.1 and _stamina > 0.0
	if sprinting:
		_stamina = max(0.0, _stamina - stamina_drain * delta)
	else:
		_stamina = min(max_stamina, _stamina + stamina_regen * delta)
	GameManager.update_stamina(_stamina / max_stamina)

func _update_movement(delta: float) -> void:
	var xf       := global_transform
	var move_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): move_dir -= xf.basis.z
	if Input.is_action_pressed("move_back"):    move_dir += xf.basis.z
	if Input.is_action_pressed("move_left"):    move_dir -= xf.basis.x
	if Input.is_action_pressed("move_right"):   move_dir += xf.basis.x
	move_dir.y = 0.0
	if move_dir.length_squared() > 0.0:
		move_dir = move_dir.normalized()

	var sprinting := Input.is_action_pressed("sprint") and not _crouching and _stamina > 0.0
	var spd : float
	if _crouching:
		spd = crouch_speed
	elif sprinting:
		spd = sprint_speed
	else:
		spd = walk_speed

	var target := move_dir * spd
	var rate   := move_accel if move_dir.length_squared() > 0.0 else move_decel
	velocity.x = lerp(velocity.x, target.x, rate * delta)
	velocity.z = lerp(velocity.z, target.z, rate * delta)

func _update_head_bob(delta: float) -> void:
	var h_spd := Vector2(velocity.x, velocity.z).length()
	if h_spd < 0.2:
		_bob_t = 0.0
		cam_node.position.y = lerp(cam_node.position.y, 0.0, 8.0 * delta)
		cam_node.position.x = lerp(cam_node.position.x, 0.0, 8.0 * delta)
		return
	var freq := bob_freq_sprint if h_spd > walk_speed + 0.5 else bob_freq_walk
	_bob_t += delta * freq * TAU
	cam_node.position.y = sin(_bob_t) * bob_amp_v
	cam_node.position.x = sin(_bob_t * 0.5) * bob_amp_h

func _update_sway(delta: float) -> void:
	_mouse_delta    = _mouse_delta.lerp(Vector2.ZERO, 10.0 * delta)
	cam_node.rotation.z = lerp(cam_node.rotation.z, -_mouse_delta.x * 0.0006, 8.0 * delta)

func _tick_footstep(delta: float) -> void:
	var h_spd := Vector2(velocity.x, velocity.z).length()
	if h_spd < 0.3 or not is_on_floor():
		_step_accum = 0.0
		return
	var interval := 0.35 if h_spd > walk_speed + 0.5 else 0.55
	_step_accum += delta
	if _step_accum >= interval:
		_step_accum = 0.0
		GameManager.on_player_footstep(global_position, h_spd > walk_speed + 0.5)

func die() -> void:
	if _dead:
		return
	_dead    = true
	velocity = Vector3.ZERO
	GameManager.on_player_died()
