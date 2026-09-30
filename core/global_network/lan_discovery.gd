class_name LanDiscovery extends Node

## Поиск игр в локальной сети: хост раз в секунду шлёт бродкаст-бекон,
## клиенты слушают и собирают список найденных игр.
##
## Порт обнаружения отдельный от игрового (NetworkManager.DEFAULT_PORT = 8910),
## иначе слушатель и ENet-сервер конфликтовали бы на одной машине.
## Слушатель на машине может быть только один, поэтому занятый порт — не приговор:
## пока лобби открыто, попытки занять порт повторяются.

signal servers_changed(_servers: Dictionary)

const DISCOVERY_PORT := 8911
const BROADCAST_ADDRESS := "255.255.255.255"
const BEACON_INTERVAL := 1.0
const SERVER_TIMEOUT := 3.5
const RETRY_INTERVAL := 2.0

var _udp: PacketPeerUDP
var _broadcasting := false
var _listen_requested := false
var _retry_left := 0.0
var _elapsed := 0.0
var _server_name := ""
var _server_port := 0
var _has_password := false
var _servers: Dictionary[String, Dictionary] = {}
var _ages: Dictionary[String, float] = {}
var _dtls_enabled := false


func _ready() -> void:
	set_process(false)


func start_broadcasting(_name: String, _port: int, _passworded: bool, _dtls: bool = false) -> void:
	stop()
	
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_udp.set_dest_address(BROADCAST_ADDRESS, DISCOVERY_PORT)
	_server_name = _name
	_server_port = _port
	_has_password = _passworded
	_dtls_enabled = _dtls
	_broadcasting = true
	_elapsed = BEACON_INTERVAL
	set_process(true)


func start_listening() -> void:
	stop()
	_listen_requested = true
	_try_listen()


func stop() -> void:
	set_process(false)
	_close_socket()
	
	_listen_requested = false
	_retry_left = 0.0
	_broadcasting = false
	_elapsed = 0.0
	_servers.clear()
	_ages.clear()


func is_searching() -> bool:
	return _udp != null and not _broadcasting


## Слушать пытаемся, но порт занят другим экземпляром игры — поиск пока недоступен.
func search_unavailable() -> bool:
	return _listen_requested and _udp == null


func get_servers() -> Dictionary[String, Dictionary]:
	return _servers.duplicate()


func _try_listen() -> void:
	_close_socket()
	
	var udp := PacketPeerUDP.new()
	var error := udp.bind(DISCOVERY_PORT)
	
	if error != OK:
		udp.close()
		_retry_left = RETRY_INTERVAL
		set_process(true)
		return
	
	_udp = udp
	_broadcasting = false
	_retry_left = 0.0
	set_process(true)


func _close_socket() -> void:
	if _udp == null:
		return
	
	_udp.close()
	_udp = null


func _process(_delta: float) -> void:
	if _udp == null:
		_retry_if_needed(_delta)
		return
	
	if _broadcasting:
		_elapsed += _delta
		
		if _elapsed >= BEACON_INTERVAL:
			_elapsed = 0.0
			_send_beacon()
		
		return
	
	_receive_beacons(_delta)


func _retry_if_needed(_delta: float) -> void:
	if not _listen_requested:
		set_process(false)
		return
	
	_retry_left -= _delta
	
	if _retry_left <= 0.0:
		_try_listen()


func _send_beacon() -> void:
	var payload := JSON.stringify({
		"name": _server_name,
		"port": _server_port,
		"dtls": _dtls_enabled,
		"players": MatchState.participants.size(),
		"max": MatchState.MAX_PLAYERS,
		"has_password": _has_password,
	}).to_utf8_buffer()
	
	for address in _beacon_targets():
		_udp.set_dest_address(address, DISCOVERY_PORT)
		_udp.put_packet(payload)


## Куда шлём бекон: ограниченный бродкаст плюс направленный бродкаст каждой частной
## подсети. Интерфейсов на машине обычно несколько (Ethernet, Hamachi, Hyper-V, VPN),
## а ограниченный бродкаст уходит только в один из них — тот, что выбрала таблица
## маршрутизации, поэтому в списке найденных игр может оказаться недостижимый адрес.
func _beacon_targets() -> PackedStringArray:
	var targets := PackedStringArray([BROADCAST_ADDRESS])
	
	for address in IP.get_local_addresses():
		var directed := _directed_broadcast(address)
		
		if directed != "" and not targets.has(directed):
			targets.append(directed)
	
	return targets


## Направленный бродкаст считаем только для частных диапазонов: там маска /24 в быту
## почти всегда верна. У Hamachi (25.x) своя маска, угадывать её нельзя — ему хватает
## ограниченного бродкаста.
func _directed_broadcast(_address: String) -> String:
	var parts := _address.split(".")
	
	if parts.size() != 4 or _address.contains(":"):
		return ""
	
	var first := int(parts[0])
	var second := int(parts[1])
	var is_private := (
		first == 10
		or (first == 172 and second >= 16 and second <= 31)
		or (first == 192 and second == 168)
	)
	
	if not is_private:
		return ""
	
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]


func _receive_beacons(_delta: float) -> void:
	var changed := false
	
	for address in _ages.keys():
		_ages[address] += _delta
		
		if _ages[address] > SERVER_TIMEOUT:
			_ages.erase(address)
			_servers.erase(address)
			changed = true
	
	while _udp.get_available_packet_count() > 0:
		var parsed = JSON.parse_string(_udp.get_packet().get_string_from_utf8())
		
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		
		var address := _udp.get_packet_ip()
		var previous: Dictionary = _servers.get(address, {})
		
		if (
			previous.get("name") != parsed.get("name")
			or previous.get("players") != parsed.get("players")
			or previous.get("has_password") != parsed.get("has_password")
		):
			changed = true
		
		_servers[address] = parsed
		_ages[address] = 0.0
	
	if changed:
		servers_changed.emit(get_servers())
