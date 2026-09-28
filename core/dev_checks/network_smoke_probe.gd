class_name NetworkSmokeProbe extends Node

## Логика сетевого смоука этапов M1–M2. Запускается двумя-тремя процессами:
##
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --password=secret
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Client --password=secret
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --password=wrong --expect-reject
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --lan-search
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --start-game
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Client --expect-game
##
## Успех печатает SMOKE CLIENT CONNECTED / SMOKE CLIENT REJECTED: … / SMOKE LAN FOUND n /
## SMOKE CLIENT SEES MOTION. Жёсткий таймаут гарантирует выход даже при ошибке.

const CLIENT_TIMEOUT := 8.0
const HOST_WAIT_PLAYERS := 20.0
const HOST_LIFETIME := 25.0
const GAME_SETTLE_TIME := 8.0
const GAME_WATCH_TIME := 12.0
const HARD_TIMEOUT := 60.0
const LAN_SEARCH_TIME := 5.0
const MOTION_DELTA := 200.0
const HOST_MOVE := Vector2(400.0, 0.0)

var _args := {}
var _elapsed := 0.0
var _finished := false
var _expect_reject := false
var _game_started_at := -1.0
var _host_moved := false
var _client_checked := false
var _watch_position := Vector2.ZERO


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
		_start_host()
	elif _args.has("autoconnect"):
		_start_client()
	elif _args.has("lan-search"):
		_start_lan_search()
	else:
		_finish(1, "SMOKE FAIL: нужен --autohost, --autoconnect или --lan-search")


func _process(_delta: float) -> void:
	if _finished:
		return
	
	_elapsed += _delta
	
	if _elapsed >= HARD_TIMEOUT:
		_finish(1, "SMOKE FAIL: общий таймаут %.0f с" % HARD_TIMEOUT)
		return
	
	if _args.has("autohost"):
		_tick_host()
	elif _args.has("autoconnect"):
		_tick_client()
	elif _elapsed >= LAN_SEARCH_TIME:
		_finish(1, "SMOKE LAN FAIL: хосты не найдены за %.0f с" % LAN_SEARCH_TIME)


func _finish(_code: int, _message: String) -> void:
	_finished = true
	print(_message)
	
	if is_instance_valid(NetworkManager):
		NetworkManager.disconnect_game()
	
	get_tree().quit(_code)


func _name() -> String:
	return _args.get("name", "Игрок")


# Запуск режимов

func _start_host() -> void:
	var error := NetworkManager.host_game(_name(), _args.get("password", ""))
	
	if error != "":
		_finish(1, "SMOKE HOST FAIL: %s" % error)
		return
	
	print("SMOKE HOST READY")


func _start_client() -> void:
	var error := NetworkManager.join_game(
		_args["autoconnect"], _name(), _args.get("password", "")
	)
	
	if error != "":
		_finish(1, "SMOKE CLIENT FAIL: %s" % error)


func _start_lan_search() -> void:
	NetworkManager.lan.servers_changed.connect(_on_servers_changed)
	NetworkManager.lan.start_listening()
	print("SMOKE LAN LISTENING")


# Хост

func _tick_host() -> void:
	if not _args.has("start-game"):
		if _elapsed >= HOST_LIFETIME:
			_finish(0, "SMOKE HOST DONE")
		return
	
	# ждём второго участника и начинаем игру
	if _game_started_at < 0.0:
		if MatchState.participants.size() >= 2 or _elapsed >= HOST_WAIT_PLAYERS:
			_game_started_at = _elapsed
			NetworkManager.start_game()
			print("SMOKE HOST STARTS GAME")
		return
	
	var player: Player = MatchState.local_player
	
	if player == null:
		if _elapsed - _game_started_at > GAME_SETTLE_TIME:
			_finish(1, "SMOKE HOST FAIL: игрок не появился в мире")
		return
	
	if not _host_moved:
		_host_moved = true
		print("SMOKE GAME PLAYERS: %d" % MatchState.player_count())
		player.position += HOST_MOVE
		player.net_target.position = player.position
		print("SMOKE HOST MOVED: ", player.position)
		print("SMOKE HOST COLOR: %s" % MatchState.participant_color(1).to_html(false))
		return
	
	if _elapsed - _game_started_at > GAME_WATCH_TIME:
		_finish(0, "SMOKE HOST DONE")


# Клиент

func _tick_client() -> void:
	if not _args.has("expect-game"):
		return
	
	if MatchState.local_player == null:
		if _elapsed >= GAME_SETTLE_TIME + CLIENT_TIMEOUT:
			_finish(1, "SMOKE CLIENT FAIL: игрок не появился в мире")
		return
	
	if not _client_checked:
		_client_checked = true
		_check_client_game()
		return
	
	var host_player: Player = MatchState.players.get(1)
	
	if host_player != null and host_player.net_target.position.distance_to(_watch_position) > MOTION_DELTA:
		print("SMOKE CLIENT SEES MOTION: ", host_player.net_target.position)
		_finish(0, "SMOKE CLIENT SEES MOTION")
		return
	
	if _elapsed >= GAME_WATCH_TIME + CLIENT_TIMEOUT:
		_finish(1, "SMOKE CLIENT FAIL: движение хоста не дошло")


func _check_client_game() -> void:
	var me: Player = MatchState.local_player
	var host_player: Player = MatchState.players.get(1)
	
	print("SMOKE GAME PLAYERS: %d" % MatchState.player_count())
	
	if host_player == null:
		_finish(1, "SMOKE CLIENT FAIL: нет игрока хоста")
		return
	
	if me.peer_id != multiplayer.get_unique_id():
		_finish(1, "SMOKE CLIENT FAIL: локальный игрок не мой (peer %d)" % me.peer_id)
		return
	
	if not me.is_local() or me.camera.enabled == false:
		_finish(1, "SMOKE CLIENT FAIL: локальный игрок или его камера неактивны")
		return
	
	if host_player.is_local() or host_player.camera.enabled:
		_finish(1, "SMOKE CLIENT FAIL: чужой игрок считается локальным")
		return
	
	# ник-табличка: у чужого игрока видна и с правильным цветом, у своего скрыта
	var expected_color := MatchState.participant_color(host_player.peer_id)
	
	if not host_player.nameplate.visible:
		_finish(1, "SMOKE CLIENT FAIL: табличка чужого игрока скрыта")
		return
	
	if host_player.nameplate.text != MatchState.participant_name(host_player.peer_id):
		_finish(1, "SMOKE CLIENT FAIL: в табличке не тот ник — %s" % host_player.nameplate.text)
		return
	
	if host_player.nameplate.get_theme_color("font_color") != expected_color:
		_finish(1, "SMOKE CLIENT FAIL: цвет таблички не совпал с цветом игрока")
		return
	
	if me.nameplate.visible:
		_finish(1, "SMOKE CLIENT FAIL: своя табличка видна")
		return
	
	print("SMOKE CLIENT NAMEPLATE: %s %s" % [
		host_player.nameplate.text, expected_color.to_html(false)
	])
	
	_watch_position = host_player.net_target.position
	print("SMOKE CLIENT WATCH: ", _watch_position)


# Сигналы

func _on_connection_succeeded() -> void:
	if _args.has("expect-game"):
		print("SMOKE CLIENT CONNECTED")
		return
	
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
