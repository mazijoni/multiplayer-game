extends CharacterBody3D

# --- Movement ---
@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 5.0
@export var air_control: float = 4.0

# --- Look ---
@export_group("Look")
@export var mouse_sensitivity: float = 0.003
@export var vertical_clamp_deg: float = 85.0

# --- Head Bob ---
@export_group("Head Bob")
@export var bob_frequency: float = 2.5
@export var bob_amplitude: float = 0.05

# --- Crouch ---
@export_group("Crouch")
@export var stand_height: float = 1.6
@export var crouch_height: float = 0.9
@export var crouch_capsule_height: float = 1.1
@export var stand_capsule_height: float = 1.8
@export var crouch_speed_multiplier: float = 10.0

# --- FOV ---
@export_group("FOV")
@export var base_fov: float = 75.0
@export var sprint_fov_bonus: float = 15.0
@export var fov_lerp_speed: float = 8.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var col: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Body
@onready var head_mesh: MeshInstance3D = $Head/HeadMesh

const GRAVITY := 9.8

var _bob_time: float = 0.0
var _is_crouching: bool = false

@onready var cam: Camera3D = $Head/Camera3D

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	camera.fov = base_fov
	cam.current = is_multiplayer_authority()
	head.position.y = stand_height
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		body_mesh.hide()
		head_mesh.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(-vertical_clamp_deg),
			deg_to_rad(vertical_clamp_deg)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_handle_crouch(delta)
		_apply_gravity(delta)
		_handle_jump()
		_handle_movement(delta)
		_handle_head_bob(delta)
		_handle_fov(delta)
		move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		velocity.y = jump_velocity

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed("sprint") and is_on_floor() and not _is_crouching
	var target_speed: float
	if _is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	else:
		target_speed = walk_speed

	if is_on_floor():
		# Instant response on the ground — no sliding
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		# Preserve momentum in the air, allow limited steering
		if direction != Vector3.ZERO:
			velocity.x = move_toward(velocity.x, direction.x * target_speed, air_control * delta)
			velocity.z = move_toward(velocity.z, direction.z * target_speed, air_control * delta)
	
	if Input.is_action_just_pressed("quit"):
		$"../".exit_game(name.to_int())
		get_tree().quit()

func _handle_crouch(delta: float) -> void:
	var want_crouch := Input.is_action_pressed("crouch") and is_on_floor()

	# Prevent standing up into a ceiling
	if _is_crouching and not want_crouch:
		if _can_stand_up():
			_is_crouching = false
	elif want_crouch:
		_is_crouching = true

	var target_head_y := crouch_height if _is_crouching else stand_height
	head.position.y = lerp(head.position.y, target_head_y, crouch_speed_multiplier * delta)

	var capsule := col.shape as CapsuleShape3D
	if capsule:
		var target_cap_h := crouch_capsule_height if _is_crouching else stand_capsule_height
		capsule.height = lerp(capsule.height, target_cap_h, crouch_speed_multiplier * delta)
		col.position.y = capsule.height * 0.5

	# Scale body mesh to match crouch
	var target_body_scale_y := 0.65 if _is_crouching else 1.0
	body_mesh.scale.y = lerp(body_mesh.scale.y, target_body_scale_y, crouch_speed_multiplier * delta)
	body_mesh.position.y = lerp(body_mesh.position.y, 0.7 * target_body_scale_y, crouch_speed_multiplier * delta)

func _can_stand_up() -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.UP * stand_capsule_height,
		collision_mask,
		[self]
	)
	var result := space.intersect_ray(params)
	return result.is_empty()

func _handle_head_bob(delta: float) -> void:
	var flat_vel := Vector2(velocity.x, velocity.z).length()
	if flat_vel > 0.5 and is_on_floor():
		var is_sprinting := Input.is_action_pressed("sprint") and not _is_crouching
		var speed_mult := 1.5 if is_sprinting else 1.0
		_bob_time += delta * bob_frequency * speed_mult
		camera.transform.origin.y = sin(_bob_time * 2.0) * bob_amplitude
		camera.transform.origin.x = sin(_bob_time) * bob_amplitude * 0.5
	else:
		camera.transform.origin.y = lerp(camera.transform.origin.y, 0.0, delta * 10.0)
		camera.transform.origin.x = lerp(camera.transform.origin.x, 0.0, delta * 10.0)
		if flat_vel <= 0.1:
			_bob_time = 0.0

func _handle_fov(delta: float) -> void:
	var flat_vel := Vector2(velocity.x, velocity.z).length()
	var is_sprinting := Input.is_action_pressed("sprint") and flat_vel > 0.5 and not _is_crouching
	var target_fov := base_fov + sprint_fov_bonus if is_sprinting else base_fov
	camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)
