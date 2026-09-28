class_name LanDiscovery extends Node

## Поиск игр в локальной сети: хост раз в секунду шлёт бродкаст-бекон,
## клиенты слушают и собирают список найденных игр.
##
## Порт обнаружения отдельный от игрового (NetworkManager.DEFAULT_PORT = 8910),
## иначе слушатель и ENet-сервер конфликтовали бы на одной машине.

signal servers_changed(_servers: Dictionary)

const DISCOVERY_PORT := 8911
const BROADCAST_ADDRESS := "255.255.255.255"
const BEACON_INTERVAL := 1.0
const SERVER_TIMEOUT := 3.5

var _udp: PacketPeerUDP
var _broadcasting := false
var _elapsed := 0.0
var _server_name := ""
var _server_port := 0
var _has_password := false
var _servers: Dictionary[String, Dictionary] = {}
var _ages: Dictionary[String, float] = {}


func _ready() -> void:
	set_process(false)


func start_broadcasting(_name: String, _port: int, _passworded: bool) -> void:
	stop()
	
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_udp.set_dest_address(BROADCAST_ADDRESS, DISCOVERY_PORT)
	_server_name = _name
	_server_port = _port
	_has_password = _passworded
	_broadcasting = true
	_elapsed = BEACON_INTERVAL
	set_process(true)


func start_listening() -> void:
	stop()
	
	_udp = PacketPeerUDP.new()
	var error := _udp.bind(DISCOVERY_PORT)
	
	if error != OK:
		# на одной машине слушатель может быть только один
		push_warning("LAN-поиск недоступен: порт %d занят (%d)" % [DISCOVERY_PORT, error])
		_udp = null
		return
	
	_broadcasting = false
	set_process(true)


func stop() -> void:
	set_process(false)
	
	if _udp != null:
		_udp.close()
		_udp = null
	
	_broadcasting = false
	_elapsed = 0.0
	_servers.clear()
	_ages.clear()


func is_searching() -> bool:
	return _udp != null and not _broadcasting


func get_servers() -> Dictionary[String, Dictionary]:
	return _servers.duplicate()


func _process(_delta: float) -> void:
	if _udp == null:
		return
	
	if _broadcasting:
		_elapsed += _delta
		
		if _elapsed >= BEACON_INTERVAL:
			_elapsed = 0.0
			_send_beacon()
		
		return
	
	_receive_beacons(_delta)


func _send_beacon() -> void:
	var payload := JSON.stringify({
		"name": _server_name,
		"port": _server_port,
		"players": MatchState.participants.size(),
		"max": MatchState.MAX_PLAYERS,
		"has_password": _has_password,
	})
	
	_udp.put_packet(payload.to_utf8_buffer())


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
