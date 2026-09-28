extends Node

## Сетевой смоук M1: запускается двумя процессами на одной машине.
##
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --password=secret
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Client --password=secret
##   ... --autoconnect=127.0.0.1 --password=wrong --expect-reject
##
## Хост печатает "SMOKE HOST READY" и живёт до таймаута, затем "SMOKE HOST DONE".
## Клиент печатает "SMOKE CLIENT CONNECTED" или "SMOKE CLIENT REJECTED: причина" и выходит.
## Жёсткий таймаут гарантирует выход даже при ошибке инициализации.

const CLIENT_TIMEOUT := 8.0
const HOST_LIFETIME := 12.0
const HARD_TIMEOUT := 16.0
const LAN_SEARCH_TIME := 5.0

var _args := {}
var _left := 0.0
var _elapsed := 0.0
var _expect_reject := false
var _finished := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		_args[parts[0].lstrip("-")] = parts[1] if parts.size() > 1 else ""
	
	print("SMOKE ARGS: ", _args)
	
	_expect_reject = _args.has("expect-reject")
	
	if not is_instance_valid(NetworkManager):
		_finish(1, "SMOKE FAIL: автолоад NetworkManager недоступен")
		return
	
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.join_rejected.connect(_on_join_rejected)
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.server_disconnected.connect(_on_failed)
	NetworkManager.participant_joined.connect(_on_participant_joined)
	
	if _args.has("autohost"):
		var error := NetworkManager.host_game(_name(), _args.get("password", ""))
		
		if error != "":
			_finish(1, "SMOKE HOST FAIL: %s" % error)
			return
		
		_left = HOST_LIFETIME
		print("SMOKE HOST READY")
	elif _args.has("autoconnect"):
		var error := NetworkManager.join_game(_args["autoconnect"], _name(), _args.get("password", ""))
		
		if error != "":
			_finish(1, "SMOKE CLIENT FAIL: %s" % error)
			return
		
		_left = CLIENT_TIMEOUT
	elif _args.has("lan-search"):
		NetworkManager.lan.servers_changed.connect(_on_servers_changed)
		NetworkManager.lan.start_listening()
		_left = LAN_SEARCH_TIME
		print("SMOKE LAN LISTENING")
	else:
		_finish(1, "SMOKE FAIL: нужен --autohost, --autoconnect или --lan-search")


func _process(_delta: float) -> void:
	if _finished:
		return
	
	_elapsed += _delta
	
	if _elapsed >= HARD_TIMEOUT:
		_finish(1, "SMOKE FAIL: общий таймаут %.0f с" % HARD_TIMEOUT)
		return
	
	if _left <= 0.0:
		return
	
	_left -= _delta
	
	if _left > 0.0:
		return
	
	if _args.has("autohost"):
		_finish(0, "SMOKE HOST DONE")
	elif _args.has("lan-search"):
		_finish(1, "SMOKE LAN FAIL: хосты не найдены за %.0f с" % LAN_SEARCH_TIME)
	else:
		_finish(1, "SMOKE CLIENT FAIL: таймаут")


func _name() -> String:
	return _args.get("name", "Игрок")


func _finish(_code: int, _message: String) -> void:
	_finished = true
	print(_message)
	
	if is_instance_valid(NetworkManager):
		NetworkManager.disconnect_game()
	
	get_tree().quit(_code)


func _on_connection_succeeded() -> void:
	if _expect_reject:
		_finish(1, "SMOKE CLIENT FAIL: подключение принято, а ожидался отказ")
		return
	
	_finish(0, "SMOKE CLIENT CONNECTED")


func _on_join_rejected(_reason: String) -> void:
	if _expect_reject:
		_finish(0, "SMOKE CLIENT REJECTED: %s" % _reason)
		return
	
	_finish(1, "SMOKE CLIENT FAIL: отказ — %s" % _reason)


func _on_failed(_reason: String) -> void:
	_finish(1, "SMOKE FAIL: %s" % _reason)


func _on_participant_joined(_peer_id: int) -> void:
	print("SMOKE HOST SEES PLAYER %d: %s" % [_peer_id, MatchState.participants.values()])


func _on_servers_changed(_servers: Dictionary) -> void:
	print("SMOKE LAN SEES: ", _servers)
	
	if _args.has("lan-search"):
		_finish(0, "SMOKE LAN FOUND %d" % _servers.size())
