extends Node

const GRID := 0.5

var active: bool    = false
var _shelf:     Node    = null
var _orig_pos:  Vector3 = Vector3.ZERO
var _orig_rot:  Vector3 = Vector3.ZERO

signal shelf_placed(shelf: Node, new_pos: Vector3)
signal placement_cancelled

func start(shelf: Node) -> void:
	if active:
		return
	_shelf     = shelf
	_orig_pos  = shelf.global_position
	_orig_rot  = shelf.rotation
	active = true
	_tint(true)
	_notify("Move shelf: aim at floor  |  E: Confirm  |  X: Cancel", 99.0)

func update_preview(ray: RayCast3D) -> void:
	if not active or not _shelf:
		return
	if ray.is_colliding():
		var n := ray.get_collision_normal()
		if n.dot(Vector3.UP) > 0.6:
			var pt := ray.get_collision_point()
			_shelf.global_position = Vector3(
				snapped(pt.x, GRID),
				_orig_pos.y,
				snapped(pt.z, GRID)
			)

func confirm() -> void:
	if not active:
		return
	active = false
	_tint(false)
	shelf_placed.emit(_shelf, _shelf.global_position)
	_notify("Shelf placed!", 2.0)
	_shelf = null

func cancel() -> void:
	if not active:
		return
	_shelf.global_position = _orig_pos
	_shelf.rotation        = _orig_rot
	active = false
	_tint(false)
	placement_cancelled.emit()
	_shelf = null

func _tint(on: bool) -> void:
	if not _shelf:
		return
	var mi := _shelf.get_node_or_null("MeshInstance3D")
	if mi is MeshInstance3D:
		if on:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.4, 0.85, 1.0, 0.75)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode    = BaseMaterial3D.CULL_DISABLED
			mi.material_override = m
		else:
			mi.material_override = null

func _notify(msg: String, dur: float) -> void:
	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_notification"):
		ui.show_notification(msg, dur)
