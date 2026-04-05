extends Node3D
## Procedurally generates a Backrooms-style maze of connected rooms,
## bakes a NavMesh, then spawns the player, monster, and HUD.

const CELL_W  : float = 8.0    # room width (X)
const CELL_D  : float = 8.0    # room depth (Z)
const WALL_H  : float = 3.2    # ceiling height
const WALL_T  : float = 0.22   # wall/floor thickness
const GRID    : int   = 24     # cells per axis (24 × 24 grid)
const STEPS   : int   = 200    # drunk-walk steps = number of rooms

const FlickerScript = preload("res://scripts/flickering_light.gd")

# Preload spawnable scenes
const PlayerScene  = preload("res://scenes/player/player.tscn")
const MonsterScene = preload("res://scenes/enemy/monster.tscn")
const HudScene     = preload("res://scenes/ui/hud.tscn")

@onready var nav_region : NavigationRegion3D = $NavigationRegion3D

var _grid      : Dictionary = {}   # Vector2i → true
var _wall_mat  : StandardMaterial3D
var _floor_mat : StandardMaterial3D
var _ceil_mat  : StandardMaterial3D

func _ready() -> void:
	randomize()
	_build_materials()
	_generate_grid()
	_build_geometry()
	_bake_navigation()

# ── Materials ─────────────────────────────────────────────────────────────────
func _build_materials() -> void:
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.83, 0.80, 0.55)   # yellowish wallpaper
	_wall_mat.roughness    = 0.95

	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(0.37, 0.34, 0.27)  # dingy carpet
	_floor_mat.roughness    = 1.0

	_ceil_mat = StandardMaterial3D.new()
	_ceil_mat.albedo_color = Color(0.88, 0.87, 0.72)   # off-white ceiling
	_ceil_mat.roughness    = 0.85

# ── Grid (drunk walk) ─────────────────────────────────────────────────────────
func _generate_grid() -> void:
	var center := Vector2i(GRID / 2, GRID / 2)
	var cur    := center
	_grid[cur] = true
	var dirs   := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for _i in STEPS:
		var d   : Vector2i = dirs[randi() % 4]
		var nxt := cur + d
		if nxt.x >= 1 and nxt.x < GRID - 1 and nxt.y >= 1 and nxt.y < GRID - 1:
			cur = nxt
		_grid[cur] = true

# ── Geometry ──────────────────────────────────────────────────────────────────
func _build_geometry() -> void:
	for cell in _grid:
		_build_cell(cell as Vector2i)

func _build_cell(cell: Vector2i) -> void:
	var cx := cell.x * CELL_W
	var cz := cell.y * CELL_D

	# Floor
	_add_box(Vector3(cx, -WALL_T * 0.5, cz),
			 Vector3(CELL_W, WALL_T, CELL_D), _floor_mat)
	# Ceiling
	_add_box(Vector3(cx, WALL_H + WALL_T * 0.5, cz),
			 Vector3(CELL_W, WALL_T, CELL_D), _ceil_mat)

	# Walls — only where no neighbour exists
	var north := Vector2i(cell.x, cell.y + 1)
	var south := Vector2i(cell.x, cell.y - 1)
	var east  := Vector2i(cell.x + 1, cell.y)
	var west  := Vector2i(cell.x - 1, cell.y)

	if not _grid.has(north):
		_add_box(Vector3(cx, WALL_H * 0.5, cz + CELL_D * 0.5),
				 Vector3(CELL_W, WALL_H, WALL_T), _wall_mat)
	if not _grid.has(south):
		_add_box(Vector3(cx, WALL_H * 0.5, cz - CELL_D * 0.5),
				 Vector3(CELL_W, WALL_H, WALL_T), _wall_mat)
	if not _grid.has(east):
		_add_box(Vector3(cx + CELL_W * 0.5, WALL_H * 0.5, cz),
				 Vector3(WALL_T, WALL_H, CELL_D), _wall_mat)
	if not _grid.has(west):
		_add_box(Vector3(cx - CELL_W * 0.5, WALL_H * 0.5, cz),
				 Vector3(WALL_T, WALL_H, CELL_D), _wall_mat)

	# Flickering light — roughly one per three rooms
	if randi() % 3 == 0:
		_add_light(Vector3(cx, WALL_H - 0.2, cz))

func _add_box(pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.global_position = pos

	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)

	var cs      := CollisionShape3D.new()
	var bshape  := BoxShape3D.new()
	bshape.size = sz
	cs.shape    = bshape
	body.add_child(cs)

func _add_light(pos: Vector3) -> void:
	var light              := OmniLight3D.new()
	light.light_color       = Color(1.0, 0.95, 0.72)
	light.light_energy      = 0.85
	light.omni_range        = 9.0
	light.shadow_enabled    = false   # many lights — keep perf manageable
	add_child(light)
	light.global_position   = pos

	var flicker := Node.new()
	flicker.set_script(FlickerScript)
	light.add_child(flicker)

# ── Navigation ────────────────────────────────────────────────────────────────
func _bake_navigation() -> void:
	if nav_region == null:
		push_warning("RoomGenerator: NavigationRegion3D missing — skipping bake.")
		_spawn_entities()
		return
	nav_region.bake_finished.connect(_on_nav_baked, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh()

func _on_nav_baked() -> void:
	_spawn_entities()

# ── Entity spawning ───────────────────────────────────────────────────────────
func _spawn_entities() -> void:
	var center      := Vector2i(GRID / 2, GRID / 2)
	var player_pos  := _cell_world(center) + Vector3(0.0, 1.0, 0.0)

	var player := PlayerScene.instantiate()
	add_child(player)
	player.global_position = player_pos

	var monster_cell := _pick_far_cell(center, 6)
	var monster      := MonsterScene.instantiate()
	add_child(monster)
	monster.global_position = _cell_world(monster_cell) + Vector3(0.0, 1.0, 0.0)

	# Wire monster hearing to player footsteps
	GameManager.footstep_heard.connect(monster.alert_sound)

	var hud := HudScene.instantiate()
	add_child(hud)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _cell_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_W, 0.0, cell.y * CELL_D)

func _pick_far_cell(origin: Vector2i, min_dist: int) -> Vector2i:
	var candidates : Array[Vector2i] = []
	for cell in _grid:
		var c := cell as Vector2i
		if abs(c.x - origin.x) + abs(c.y - origin.y) >= min_dist:
			candidates.append(c)
	if candidates.is_empty():
		return origin + Vector2i(4, 0)
	return candidates[randi() % candidates.size()]
