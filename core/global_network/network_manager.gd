extends Node

## Сетевой слой: хостинг и подключение по ENet, опциональный пароль, LAN-поиск.
##
## Хост авторитетен по миру, клиент только подключается и получает состояние.
## Игрок попадает в список участников лишь после рукопожатия: так пароль нельзя
## обойти сторонним клиентом.
##
## Режим DEDICATED — то же самое, но за машиной сервера нет игрока: её нет в списке
## участников, а матч стартует сам, когда подключится нужное число игроков.

signal server_started()
signal server_stopped()
signal participant_joined(_peer_id: int)
signal participant_left(_peer_id: int)
signal connection_succeeded()
signal connection_failed(_reason: String)
signal server_disconnected(_reason: String)
signal join_rejected(_reason: String)

enum Mode { OFFLINE, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 8910
const GAME_SCENE_PATH := "res://core/scenes/map_1/map_1.tscn"
const MENU_SCENE_PATH := "res://core/scenes/menu/menu.tscn"
const HANDSHAKE_TIMEOUT := 5.0
const DEFAULT_NAME := "Игрок"
const DEDICATED_NAME := "Выделенный сервер"
# пауза перед отключением отклонённого клиента, чтобы причина успела дойти
const REJECT_GRACE := 0.4

var mode: Mode = Mode.OFFLINE
var player_name: String = DEFAULT_NAME
var lan: LanDiscovery
## Сообщение для следующего экрана (например, почему выкинуло из игры).
var last_notice: String = ""

# хост занимает одно место из MatchState.MAX_PLAYERS
var max_clients: int = MatchState.MAX_PLAYERS - 1

var _password: String = ""
var _pending_password: String = ""
var _pending_address: String = ""
var _accepted: bool = false
var _rejected: bool = false
var _game_started: bool = false
var _handshake_left: float = 0.0
# выделенный сервер: сколько игроков ждать до автостарта
var _min_players: int = 1


func _ready() -> void:
	lan = LanDiscovery.new()
	lan.name = "LanDiscovery"
	add_child(lan)
	
	# клиенты не соединяются напрямую, весь трафик идёт через хост
	multiplayer.server_relay = true
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# запуск вида «godot --headless --path . -- --server»
	var args := _cmdline_args()
	
	if args.has("server"):
		_start_dedicated_from_args(args)


func is_connected_to_game() -> bool:
	return mode != Mode.OFFLINE


## Мы серверная сторона: и обычный хост, и выделенный сервер.
func is_hosting() -> bool:
	return mode == Mode.HOST or mode == Mode.DEDICATED


func is_dedicated() -> bool:
	return mode == Mode.DEDICATED


## Пинг до пира в миллисекундах или -1, если измерить нельзя.
## При релее через сервер клиент видит напрямую только хост, остальные — «—».
func peer_ping(_peer_id: int) -> int:
	if mode == Mode.OFFLINE:
		return -1
	
	if _peer_id == multiplayer.get_unique_id():
		return -1
	
	var peer := multiplayer.multiplayer_peer
	
	if not (peer is ENetMultiplayerPeer):
		return -1
	
	var packet_peer := (peer as ENetMultiplayerPeer).get_peer(_peer_id)
	
	if packet_peer == null:
		return -1
	
	return int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


## Создать игру. Возвращает текст ошибки или пустую строку.
func host_game(_name: String, _game_password: String = "") -> String:
	disconnect_game()
	
	max_clients = MatchState.MAX_PLAYERS - 1
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
	print("HOST LOCAL ADDRESSES: ", ", ".join(local_addresses()))
	server_started.emit()
	
	return ""


## Поднять выделенный сервер: за этой машиной нет игрока, её нет в списке
## участников, а матч стартует сам, когда подключится _min_players игроков.
## Возвращает текст ошибки или пустую строку.
func start_dedicated(
	_game_password: String = "",
	_min_players_count: int = 1,
	_server_name: String = DEDICATED_NAME
) -> String:
	disconnect_game()
	
	# на выделенном сервере хост не занимает место: входят все MAX_PLAYERS
	max_clients = MatchState.MAX_PLAYERS
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(DEFAULT_PORT, max_clients)
	
	if error != OK:
		return _host_error_text(error)
	
	_password = _game_password
	_min_players = maxi(1, _min_players_count)
	mode = Mode.DEDICATED
	# игрока-хозяина нет, поэтому «хостом» не помечается никто
	MatchState.is_host = false
	multiplayer.multiplayer_peer = peer
	
	MatchState.clear_participants()
	lan.start_broadcasting(_server_name, DEFAULT_PORT, _password != "")
	print("SERVER LOCAL ADDRESSES: ", ", ".join(local_addresses()))
	server_started.emit()
	
	return ""


## Аргументы командной строки (и движка, и после `--`) в виде словаря.
func _cmdline_args() -> Dictionary:
	var args := {}
	
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		
		var parts := argument.lstrip("-").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	
	return args


func _start_dedicated_from_args(_args: Dictionary) -> void:
	var error := start_dedicated(
		str(_args.get("password", "")),
		int(_args.get("min-players", "1")),
		str(_args.get("name", DEDICATED_NAME))
	)
	
	if error != "":
		push_error(error)
		print("SERVER FAILED: ", error)
		get_tree().quit(1)
		return
	
	print("SERVER READY: порт %d, игроков до %d, автостарт от %d" % [
		DEFAULT_PORT, max_clients, _min_players
	])
## Адреса, по которым до этой машины могут дотянуться другие: без loopback и
## автоконфигурации, только IPv4 (ENet в проекте ходит по IPv4).
## Интерфейсов бывает много (Ethernet, Hamachi, Hyper-V, VPN) — какой из них видят
## остальные, знает только сам игрок, поэтому показываем все.
func local_addresses() -> PackedStringArray:
	var addresses := PackedStringArray()
	
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if addresses.has(address):
			continue
		
		addresses.append(address)
	
	return addresses


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
	var was_host := is_hosting()
	
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
	_game_started = false
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
	if not is_hosting():
		return
	
	# в список участников игрок попадёт после рукопожатия
	print_debug("peer connected: ", _peer_id)


func _on_peer_disconnected(_peer_id: int) -> void:
	if not is_hosting():
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
	connection_failed.emit(
		"Не удалось подключиться к %s:%d. Проверьте адрес (для Hamachi или VPN нужен его IP) и что на машине хоста разрешён входящий UDP %d в файрволе." % [
			address, DEFAULT_PORT, DEFAULT_PORT
		]
	)


func _on_server_disconnected() -> void:
	if mode != Mode.CLIENT:
		return
	
	# отключение до окончания рукопожатия — это отказ, а не уход хоста
	var rejected := _rejected or not _accepted
	var in_game := _in_game_scene()
	disconnect_game()
	
	if rejected:
		join_rejected.emit("Хост отклонил подключение")
		return
	
	server_disconnected.emit("Хост закрыл игру")
	
	if in_game:
		# иначе игрок останется в замершем мире без сервера
		last_notice = "Хост закрыл игру"
		get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _in_game_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with("map_1.tscn")


# Рукопожатие и список участников

## Клиент сообщает имя и пароль сразу после подключения.
@rpc("any_peer", "call_remote", "reliable")
func _submit_join(_client_name: String, _client_password: String) -> void:
	if not is_hosting():
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
	
	# выделенному серверу кнопка «начать» недоступна: стартуем сами, когда набралось
	var started_now := false
	
	if mode == Mode.DEDICATED and not _game_started and MatchState.participants.size() >= _min_players:
		start_game()
		started_now = true
	
	# игрок подключился к идущей игре — сразу отправляем его на карту
	if _game_started and not started_now:
		rpc_id(sender, "_load_game_scene")
	
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


# Начало игры

## Сервер начинает игру: все пиры синхронно переходят на карту.
func start_game() -> void:
	if not is_hosting():
		return
	
	print("GAME STARTED: участников %d" % MatchState.participants.size())
	_game_started = true
	rpc("_load_game_scene")
	_load_game_scene()


@rpc("authority", "call_remote", "reliable")
func _load_game_scene() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
