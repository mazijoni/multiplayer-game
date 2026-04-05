extends Node
## Attach as a child of any Light3D to simulate a worn fluorescent tube.

@export var base_energy  : float = 0.85
@export var min_energy   : float = 0.05
@export var max_energy   : float = 1.40
@export var flicker_prob : float = 0.04   # chance per frame of a flicker event
@export var lerp_spd     : float = 12.0

var _target : float = 0.85

func _ready() -> void:
	var light := get_parent() as Light3D
	if light:
		base_energy = light.light_energy
	_target = base_energy

func _process(delta: float) -> void:
	var light := get_parent() as Light3D
	if light == null:
		return
	if randf() < flicker_prob:
		_target = randf_range(min_energy, max_energy)
	else:
		_target = move_toward(_target, base_energy, delta * 1.5)
	light.light_energy = lerp(light.light_energy, _target, lerp_spd * delta)
