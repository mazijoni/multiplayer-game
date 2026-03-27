extends StaticBody3D

@export var tape_name:  String = "Unknown Film"
@export var genre:      String = "Action"
@export var is_rewound: bool   = true

@onready var mesh_instance:    MeshInstance3D   = $MeshInstance3D
@onready var collision:        CollisionShape3D  = $CollisionShape3D
@onready var rewind_indicator: MeshInstance3D   = $RewindIndicator

var current_shelf: Node = null

const GENRE_COLORS: Dictionary = {
	"Action":  Color(0.85, 0.15, 0.15),
	"Horror":  Color(0.08, 0.05, 0.10),
	"Comedy":  Color(0.95, 0.85, 0.10),
	"Drama":   Color(0.20, 0.35, 0.80),
	"Sci-Fi":  Color(0.10, 0.80, 0.60),
	"Romance": Color(0.90, 0.35, 0.60),
}

func _ready() -> void:
	add_to_group("tape")
	_apply_visuals()

func _apply_visuals() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GENRE_COLORS.get(genre, Color(0.5, 0.5, 0.5))
	mesh_instance.set_surface_override_material(0, mat)
	_update_rewind_indicator()

func _update_rewind_indicator() -> void:
	var ind := StandardMaterial3D.new()
	ind.albedo_color               = Color.GREEN if is_rewound else Color.RED
	ind.emission_enabled           = true
	ind.emission                   = ind.albedo_color
	ind.emission_energy_multiplier = 0.7
	rewind_indicator.set_surface_override_material(0, ind)

# Called by shelf.add_tape() after reparenting to TapeContainer.
# Sets the local-space slot position and makes the tape visible.
func on_shelved(local_pos: Vector3) -> void:
	position            = local_pos
	rotation            = Vector3.ZERO
	visible             = true
	collision.disabled  = false

# Called when the player or customer picks this tape up.
# remove_tape() handles reparenting back to the scene root.
func on_picked_up() -> void:
	if current_shelf != null:
		current_shelf.remove_tape(self)
		# current_shelf is now null (set inside remove_tape)
	visible            = false
	collision.disabled = true

func on_placed() -> void:
	visible            = true
	collision.disabled = false

# Called when dropped into the world (not onto a shelf).
func on_dropped(drop_position: Vector3) -> void:
	global_position    = drop_position
	visible            = true
	collision.disabled = false

func rewind() -> void:
	if is_rewound:
		_notify_ui("Tape is already rewound!")
		return
	is_rewound = true
	_update_rewind_indicator()
	_notify_ui("Rewound: " + tape_name)

func mark_not_rewound() -> void:
	is_rewound = false
	_update_rewind_indicator()

func _notify_ui(msg: String) -> void:
	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_notification"):
		ui.show_notification(msg)
