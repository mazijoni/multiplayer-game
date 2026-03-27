extends Node3D

const TAPE_SCENE     := preload("res://scenes/tape.tscn")
const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")

@onready var tapes_root:    Node3D = $Tapes
@onready var customer_root: Node3D = $Customers

const CUSTOMER_SPAWN_INTERVAL := 15.0
var _spawn_timer: float = CUSTOMER_SPAWN_INTERVAL

var _shelves: Array[Node] = []

const GENRES  := ["Action","Horror","Comedy","Drama","Sci-Fi","Romance"]
const TITLES  := {
	"Action":  ["Explodinator 2","Steel Fist","Danger Zone","Thunder Road","Iron Hawk"],
	"Horror":  ["Night Creeper","The Lurking","Scream Again","Dungeon Dread","Dark Hours"],
	"Comedy":  ["Laugh Now","Silly Season","Ha Ha Ha","The Funny Guy","Chuckle Farm"],
	"Drama":   ["The Crying Hour","Long Road Home","Tender Lies","Quiet Storm","Broken Wings"],
	"Sci-Fi":  ["Galaxy X","Robot Uprising","Star Patrol","Void Runner","Alien Days"],
	"Romance": ["Love Letters","Endless Summer","Two Hearts","Paris Rain","Sweet Nothing"],
}

func _ready() -> void:
	_shelves = get_tree().get_nodes_in_group("shelf")
	_populate_tapes()
	# Counter / rewind machine groups are set directly on Area3D nodes
	# in MainStore.tscn -- no runtime registration needed.

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_customer()
		_spawn_timer = CUSTOMER_SPAWN_INTERVAL

func _populate_tapes() -> void:
	if _shelves.is_empty():
		push_warning("main.gd: no shelves found in group shelf.")
		return
	var genre_cycle: Array = GENRES.duplicate()
	var title_idx: Dictionary = {}
	for g in GENRES:
		title_idx[g] = 0
	for shelf: Node in _shelves:
		var genre: String = genre_cycle[0]
		genre_cycle.append(genre_cycle.pop_front())
		var count: int = min(shelf.max_tapes, TITLES[genre].size())
		for i in count:
			var tape: Node = TAPE_SCENE.instantiate()
			var idx: int   = title_idx[genre]
			tape.tape_name   = TITLES[genre][idx]
			tape.genre       = genre
			tape.is_rewound  = true
			title_idx[genre] = (idx + 1) % TITLES[genre].size()
			# Add to scene tree first (fires _ready + applies visuals).
			tapes_root.add_child(tape)
			# Shelf reparents the tape into its own TapeContainer.
			shelf.add_tape(tape)

func _spawn_customer() -> void:
	if customer_root.get_child_count() >= 3:
		return
	var cust: Node = CUSTOMER_SCENE.instantiate()
	customer_root.add_child(cust)
	GameManager.customer_spawned.emit(cust)
