extends Node3D

# ── Store dimensions ──────────────────────────────────────────────────────────
const W  := 12.0   # width  (X)
const D  := 16.0   # depth  (Z)
const H  :=  3.5   # height (Y)
const WT :=  0.3   # wall thickness

func _ready() -> void:
	_build_floor()
	_build_ceiling()
	_build_walls()
	_build_counter()
	_build_rewind_machine()
	_build_lights()

# ── Helper: make a coloured static box with collision ─────────────────────────
func _box(size: Vector3, pos: Vector3, color: Color, grp: String = "") -> StaticBody3D:
	var body      := StaticBody3D.new()
	body.position  = pos
	if grp != "":
		body.add_to_group(grp)

	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size  = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.mesh  = bm
	mi.set_surface_override_material(0, mat)

	var cs    := CollisionShape3D.new()
	var bs    := BoxShape3D.new()
	bs.size   = size
	cs.shape  = bs

	body.add_child(mi)
	body.add_child(cs)
	add_child(body)
	return body

# ── Room geometry ─────────────────────────────────────────────────────────────
func _build_floor() -> void:
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), Color(0.40, 0.34, 0.26))

func _build_ceiling() -> void:
	_box(Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), Color(0.88, 0.86, 0.82))

func _build_walls() -> void:
	var c := Color(0.72, 0.67, 0.60)
	_box(Vector3(W,  H, WT), Vector3(0,      H*0.5,  D*0.5), c)   # back  (+Z entrance)
	_box(Vector3(W,  H, WT), Vector3(0,      H*0.5, -D*0.5), c)   # front (-Z)
	_box(Vector3(WT, H, D),  Vector3(-W*0.5, H*0.5,  0),     c)   # left  (-X)
	_box(Vector3(WT, H, D),  Vector3( W*0.5, H*0.5,  0),     c)   # right (+X)

# ── Counter ───────────────────────────────────────────────────────────────────
func _build_counter() -> void:
	# Body
	_box(Vector3(6.5, 1.0, 1.0), Vector3(0, 0.50, -4.2), Color(0.50, 0.34, 0.18), "counter")
	# Top surface (lighter wood)
	_box(Vector3(6.5, 0.07, 1.0), Vector3(0, 1.04, -4.2), Color(0.62, 0.48, 0.28), "counter")

# ── Rewind machine (sits on the counter) ─────────────────────────────────────
func _build_rewind_machine() -> void:
	# Main body
	_box(Vector3(0.55, 0.28, 0.38), Vector3(-2.0, 1.22, -4.2),
		Color(0.12, 0.12, 0.12), "rewind_machine")
	# Cassette slot (dark)
	_box(Vector3(0.26, 0.05, 0.30), Vector3(-2.0, 1.37, -4.10),
		Color(0.04, 0.04, 0.04))
	# Power LED (glowing green)
	_box(Vector3(0.05, 0.05, 0.05), Vector3(-1.77, 1.42, -4.01),
		Color(0.0, 1.0, 0.3))

# ── Ceiling lights ────────────────────────────────────────────────────────────
func _build_lights() -> void:
	for pos: Vector3 in [
		Vector3( 0.0, H - 0.3,  1.0),
		Vector3(-3.5, H - 0.3,  2.5),
		Vector3( 3.5, H - 0.3,  2.5),
		Vector3(-3.5, H - 0.3, -1.0),
		Vector3( 3.5, H - 0.3, -1.0),
		Vector3( 0.0, H - 0.3, -3.5),
	]:
		var light              := OmniLight3D.new()
		light.position          = pos
		light.light_color       = Color(1.0, 0.94, 0.82)
		light.light_energy      = 1.5
		light.omni_range        = 6.5
		light.shadow_enabled    = false
		add_child(light)
