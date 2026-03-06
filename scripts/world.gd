extends Node3D

const PORT := 6767

var peer := ENetMultiplayerPeer.new()
@export var player_scene: PackedScene

# Authoritative on server; synced to all clients.
var lobby_players: Dictionary = {}  # peer_id -> display name

@onready var connect_panel: Control = $CanvasLayer/ConnectPanel
@onready var lobby_panel: Control = $CanvasLayer/LobbyPanel
@onready var name_input: LineEdit = $CanvasLayer/ConnectPanel/Center/VBox/NameInput
@onready var ip_input: LineEdit = $CanvasLayer/ConnectPanel/Center/VBox/IPInput
@onready var player_list: VBoxContainer = $CanvasLayer/LobbyPanel/Center/VBox/PlayerList
@onready var start_button: Button = $CanvasLayer/LobbyPanel/Center/VBox/StartButton
@onready var server_ip_label: Label = $CanvasLayer/LobbyPanel/Center/VBox/ServerIPLabel
@onready var status_label: Label = $CanvasLayer/LobbyPanel/Center/VBox/StatusLabel

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	peer.create_server(PORT)  # binds to 0.0.0.0 (all interfaces) by default
	multiplayer.multiplayer_peer = peer
	lobby_players = {1: _get_display_name()}
	_show_lobby()
	_refresh_player_list()
	server_ip_label.text = "Your IP: %s  —  port %d" % [_get_lan_ip(), PORT]
	server_ip_label.show()

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	_show_lobby()

func _on_connected_to_server() -> void:
	# Register our name with the server; it will broadcast the updated lobby to everyone.
	_register_player.rpc_id(1, _get_display_name())

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connect_panel.show()
	lobby_panel.hide()

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		lobby_players.erase(id)
		_sync_lobby.rpc(lobby_players)
		_del_player.rpc(id)

# Client → server: register name and receive back the full lobby state.
@rpc("any_peer")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	lobby_players[id] = player_name
	_sync_lobby.rpc(lobby_players)

@rpc("authority", "call_local")
func _sync_lobby(players: Dictionary) -> void:
	lobby_players = players
	_refresh_player_list()

func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for id in lobby_players:
		var label := Label.new()
		var display: String = lobby_players[id]
		if id == multiplayer.get_unique_id():
			display += " (you)"
		label.text = display
		player_list.add_child(label)

func _get_display_name() -> String:
	var n := name_input.text.strip_edges()
	return n if not n.is_empty() else "Player"

func _get_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		# Match private IPv4 ranges (LAN addresses)
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func _show_lobby() -> void:
	connect_panel.hide()
	lobby_panel.show()
	var is_host := multiplayer.is_server()
	start_button.visible = is_host
	status_label.visible = not is_host

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	_start_game.rpc()

@rpc("authority", "call_local")
func _start_game() -> void:
	lobby_panel.hide()
	if multiplayer.is_server():
		for id in lobby_players:
			add_player(id)

func add_player(id: int = 1) -> void:
	var player := player_scene.instantiate()
	player.name = str(id)
	var points := $SpawnPoints.get_children()
	if points.size() > 0:
		var index := lobby_players.keys().find(id) % points.size()
		player.position = points[index].position
	call_deferred("add_child", player)

func exit_game(id: int) -> void:
	_del_player.rpc(id)

@rpc("any_peer", "call_local")
func _del_player(id: int) -> void:
	var node := get_node_or_null(str(id))
	if node:
		node.queue_free()
