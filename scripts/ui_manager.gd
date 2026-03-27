extends CanvasLayer

var interaction_label:  Label
var held_tape_label:    Label
var carry_label:        Label
var customer_label:     Label
var score_label:        Label
var crosshair_label:    Label
var notification_label: Label

var _notification_timer: float = 0.0

func _ready() -> void:
	add_to_group("ui")
	_build_ui()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.tape_rented.connect(_on_tape_rented)
	GameManager.customer_spawned.connect(_on_customer_spawned)

func _build_ui() -> void:
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	crosshair_label = _lbl(root, "+", Color.WHITE, 28)
	_pin(crosshair_label, Control.PRESET_CENTER, -12, -16, 12, 16)
	crosshair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	interaction_label = _lbl(root, "", Color.YELLOW, 17)
	_pin(interaction_label, Control.PRESET_BOTTOM_WIDE, 0, -76, 0, -44)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	held_tape_label = _lbl(root, "", Color(0.75, 0.95, 1.0), 15)
	_pin(held_tape_label, Control.PRESET_BOTTOM_LEFT, 12, -108, 380, -12)

	carry_label = _lbl(root, "Tapes: 0 / 10", Color(0.5, 1.0, 0.6), 18)
	_pin(carry_label, Control.PRESET_TOP_LEFT, 12, 50, 250, 82)

	customer_label = _lbl(root, "", Color(1.0, 0.85, 0.3), 17)
	_pin(customer_label, Control.PRESET_TOP_RIGHT, -320, 12, -12, 90)
	customer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	score_label = _lbl(root, "Score: 0", Color.WHITE, 20)
	_pin(score_label, Control.PRESET_TOP_LEFT, 12, 12, 230, 46)

	notification_label = _lbl(root, "", Color(0.4, 1.0, 0.5), 17)
	_pin(notification_label, Control.PRESET_TOP_WIDE, 0, 90, 0, 128)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hints := _lbl(root,
		"WASD: Move  |  Mouse: Look  |  E: Interact  |  F: Confirm  |  Q: Drop  |  R: Rewind  |  Esc: Unlock",
		Color(0.5, 0.5, 0.5), 12)
	_pin(hints, Control.PRESET_BOTTOM_WIDE, 0, -30, 0, -8)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _lbl(parent: Control, text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text         = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _pin(ctrl: Control, preset: int, ol: float, ot: float, or_: float, ob: float) -> void:
	ctrl.set_anchors_preset(preset)
	ctrl.offset_left   = ol
	ctrl.offset_top    = ot
	ctrl.offset_right  = or_
	ctrl.offset_bottom = ob

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("CarryInventory"):
		var c := player.get_node("CarryInventory")
		var n: int = c.get_count()
		held_tape_label.text = ("Carrying %d tape%s" % [n, "s" if n != 1 else ""]) if n > 0 else ""
	elif GameManager.held_tape != null:
		var t  := GameManager.held_tape
		var rw := "Rewound" if t.is_rewound else "NOT Rewound - press R!"
		held_tape_label.text = "Holding: %s  [%s]   %s" % [t.tape_name, t.genre, rw]
	else:
		held_tape_label.text = ""

	if GameManager.active_customer != null:
		customer_label.text = "Customer wants:\n> %s" % GameManager.active_customer.requested_genre
	else:
		customer_label.text = ""

	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			notification_label.text = ""

func set_interaction_prompt(text: String) -> void:
	interaction_label.text = text

func update_carry_count(count: int, max_count: int) -> void:
	carry_label.text = "Tapes: %d / %d" % [count, max_count]

func show_notification(text: String, duration: float = 3.0) -> void:
	notification_label.text = text
	_notification_timer     = duration

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func _on_tape_rented(tape_name: String, success: bool) -> void:
	if success:
		show_notification("Rented: %s   (+10 pts)" % tape_name)
	else:
		show_notification("Wrong genre! Customer unhappy.   (-2 pts)")

func _on_customer_spawned(_customer: Node) -> void:
	show_notification("A customer has entered the store!", 2.5)
