extends StaticBody3D
@export var group_name: String = ""

func _ready() -> void:
	if group_name != "":
		add_to_group(group_name)
