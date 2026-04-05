extends Node
## Tracks the player's sanity and drives the vignette / HUD effects.
## Attach as a child of the Player node.

@export var max_sanity          : float = 100.0
@export var near_monster_drain  : float = 18.0   # per second at zero distance
@export var near_monster_radius : float = 14.0
@export var passive_regen       : float = 2.0    # per second when safe

var sanity   : float  = 100.0
var _monster : Node3D = null

func _ready() -> void:
	# Monster is spawned after nav bake, so defer the lookup
	call_deferred("_find_monster")

func _find_monster() -> void:
	_monster = get_tree().get_first_node_in_group("monster")

func _process(delta: float) -> void:
	# Retry monster ref if not found yet
	if _monster == null or not is_instance_valid(_monster):
		_monster = get_tree().get_first_node_in_group("monster")

	var drain := 0.0
	if _monster != null and is_instance_valid(_monster):
		var owner_node := get_parent() as Node3D
		if owner_node:
			var dist := owner_node.global_position.distance_to(_monster.global_position)
			if dist < near_monster_radius:
				drain += near_monster_drain * (1.0 - dist / near_monster_radius)

	if drain > 0.0:
		sanity = max(0.0, sanity - drain * delta)
	else:
		sanity = min(max_sanity, sanity + passive_regen * delta)

	GameManager.update_sanity(sanity / max_sanity)
