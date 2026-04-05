extends Node
## Autoload singleton. Holds cross-system signals so scripts stay decoupled.

signal player_died
signal stamina_changed(ratio: float)
signal sanity_changed(ratio: float)
signal footstep_heard(world_pos: Vector3, is_sprint: bool)

func update_stamina(ratio: float) -> void:
	stamina_changed.emit(ratio)

func update_sanity(ratio: float) -> void:
	sanity_changed.emit(ratio)

func on_player_footstep(world_pos: Vector3, is_sprint: bool) -> void:
	footstep_heard.emit(world_pos, is_sprint)

func on_player_died() -> void:
	player_died.emit()
	get_tree().create_timer(2.0).timeout.connect(
		func() -> void: get_tree().reload_current_scene()
	)
