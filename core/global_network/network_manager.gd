extends Node

## Сетевой слой: хостинг и подключение по ENet, опциональный пароль, LAN-поиск.
##
## Хост авторитетен по миру, клиент только подключается и получает состояние.
## Игрок попадает в список участников лишь после рукопожатия: так пароль нельзя
## обойти сторонним клиентом. Игроки в мире появятся на этапе M2.

signal server_started()
signal server_stopped()
signal participant_joined(_peer_id: int)
signal participant_left(_peer_id: int)
signal connection_succeeded()
signal connection_failed(_reason: String)
signal server_disconnected(_reason: String)
signal join_rejected(_reason: String)

enum Mode { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT := 8910
const HANDSHAKE_TIMEOUT := 5.0
const DEFAULT_NAME := "Игрок"
# пауза перед отключением отклонённого клиента, чтобы причина успела дойти
const REJECT_GRACE := 0.4

var mode: Mode = Mode.OFFLINE
var player_name: String = DEFAULT_NAME
var lan: LanDiscovery

# хост занимает одно место из MatchState.MAX_PLAYERS
var max_clients: int = MatchState.MAX_PLAYERS - 1

var _password: String = ""
var _pending_password: String = ""
var _pending_address: String = ""
var _accepted: bool = false
var _rejected: bool = false
var _handshake_left: float = 0.0


func _ready() -> void:
	lan = LanDiscovery.new()
	lan.name = "LanDiscovery"
	add_child(lan)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_connected_to_game() -> bool:
	return mode != Mode.OFFLINE


func is_hosting() -> bool:
	return mode == Mode.HOST


## Создать игру. Возвращает текст ошибки или пустую строку.
func host_game(_name: String, _game_password: String = "") -> String:
	disconnect_game()
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(DEFAULT_PORT, max_clients)
	
	if error != OK:
		return _host_error_text(error)
	
	player_name = _clean_name(_name)
	_password = _game_password
	mode = Mode.HOST
	MatchState.is_host = true
	multiplayer.multiplayer_peer = peer
	
	MatchState.clear_participants()
	MatchState.add_participant(multiplayer.get_unique_id(), player_name)
	lan.start_broadcasting(player_name, DEFAULT_PORT, _password != "")
	server_started.emit()
	
	return ""


## Подключиться к игре. Возвращает текст ошибки или пустую строку.
func join_game(_address: String, _name: String, _game_password: String = "") -> String:
	disconnect_game()
	
	var address := _address.strip_edges()
	
	if address.is_empty():
		return "Укажите адрес хоста"
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, DEFAULT_PORT)
	
	if error != OK:
		return "Не удалось подключиться к «%s» (код %d)" % [address, error]
	
	player_name = _clean_name(_name)
	_pending_password = _game_password
	_pending_address = address
	_accepted = false
	_rejected = false
	_handshake_left = 0.0
	mode = Mode.CLIENT
	MatchState.is_host = false
	multiplayer.multiplayer_peer = peer
	
	return ""


func disconnect_game() -> void:
	var was_host := mode == Mode.HOST
	
	_close_peer()
	
	if was_host:
		server_stopped.emit()


func start_lan_search() -> void:
	if mode == Mode.OFFLINE:
		lan.start_listening()


func stop_lan_search() -> void:
	if mode == Mode.OFFLINE:
		lan.stop()


func _process(_delta: float) -> void:
	if _handshake_left <= 0.0:
		return
	
	_handshake_left -= _delta
	
	if _handshake_left <= 0.0:
		disconnect_game()
		connection_failed.emit("Хост не ответил")


func _close_peer() -> void:
	_handshake_left = 0.0
	_accepted = false
	_rejected = false
	lan.stop()
	
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	
	multiplayer.multiplayer_peer = null
	mode = Mode.OFFLINE
	MatchState.is_host = false
	MatchState.clear_participants()


func _clean_name(_value: String) -> String:
	var cleaned := _value.strip_edges()
	
	if cleaned.is_empty():
		return DEFAULT_NAME
	
	return cleaned.left(20)


func _host_error_text(_error: int) -> String:
	match _error:
		ERR_ALREADY_IN_USE:
			return "Порт %d уже занят" % DEFAULT_PORT
		ERR_CANT_CREATE:
			return "Не удалось создать игру на порту %d" % DEFAULT_PORT
		_:
			return "Не удалось создать игру (код %d)" % _error


# Сигналы MultiplayerAPI

func _on_peer_connected(_peer_id: int) -> void:
	if mode != Mode.HOST:
		return
	
	# в список участников игрок попадёт после рукопожатия
	print_debug("peer connected: ", _peer_id)


func _on_peer_disconnected(_peer_id: int) -> void:
	if mode != Mode.HOST:
		return
	
	MatchState.remove_participant(_peer_id)
	participant_left.emit(_peer_id)
	_sync_participants()


func _on_connected_to_server() -> void:
	rpc_id(1, "_submit_join", player_name, _pending_password)
	_handshake_left = HANDSHAKE_TIMEOUT


func _on_connection_failed() -> void:
	var address := _pending_address
	disconnect_game()
	connection_failed.emit("Не удалось подключиться к %s:%d" % [address, DEFAULT_PORT])


func _on_server_disconnected() -> void:
	if mode != Mode.CLIENT:
		return
	
	# отключение до окончания рукопожатия — это отказ, а не уход хоста
	var rejected := _rejected or not _accepted
	disconnect_game()
	
	if rejected:
		join_rejected.emit("Хост отклонил подключение")
	else:
		server_disconnected.emit("Хост закрыл игру")


# Рукопожатие и список участников

## Клиент сообщает имя и пароль сразу после подключения.
@rpc("any_peer", "call_remote", "reliable")
func _submit_join(_client_name: String, _client_password: String) -> void:
	if mode != Mode.HOST:
		return
	
	var sender := multiplayer.get_remote_sender_id()
	
	if _password != "" and _client_password != _password:
		_reject(sender, "Неверный пароль")
		return
	
	if MatchState.participants.size() >= MatchState.MAX_PLAYERS:
		_reject(sender, "Все места заняты")
		return
	
	MatchState.add_participant(sender, _clean_name(_client_name))
	_sync_participants()
	participant_joined.emit(sender)


func _reject(_peer_id: int, _reason: String) -> void:
	print_debug("reject peer %d: %s" % [_peer_id, _reason])
	rpc_id(_peer_id, "_notify_rejected", _reason)
	
	# даём причине дойти до клиента и лишь затем отключаем
	await get_tree().create_timer(REJECT_GRACE).timeout
	
	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(_peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(_peer_id)


@rpc("authority", "call_remote", "reliable")
func _notify_rejected(_reason: String) -> void:
	if mode != Mode.CLIENT:
		return
	
	_rejected = true
	disconnect_game()
	join_rejected.emit(_reason)


func _sync_participants() -> void:
	var list := MatchState.get_participants()
	_receive_participants(list)
	rpc("_receive_participants", list)


@rpc("authority", "call_remote", "reliable")
func _receive_participants(_list: Dictionary) -> void:
	var converted: Dictionary[int, String] = {}
	
	for peer_id in _list:
		converted[int(peer_id)] = str(_list[peer_id])
	
	MatchState.set_participants(converted)
	
	if mode == Mode.CLIENT and not _accepted:
		_accepted = true
		_handshake_left = 0.0
		connection_succeeded.emit()
