class_name NetworkSmokeProbe extends Node

## Логика сетевого смоука этапов M1–M4. Запускается двумя-тремя процессами:
##
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --password=secret
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Client --password=secret
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --password=wrong --expect-reject
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --lan-search
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --start-game [--world]
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --solo-start --world
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Client --expect-game [--world]
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --stress --hold=20
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Bot1 --bot --hold=20
##   godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Watcher --expect-game --watch-name=Bot
##
## Успех печатает SMOKE CLIENT CONNECTED / SMOKE CLIENT REJECTED: … / SMOKE LAN FOUND n /
## SMOKE CLIENT SEES MOTION / SMOKE CLIENT SEES PEER n MOTION / SMOKE CLIENT SEES TREE GONE /
## SMOKE CLIENT WORLD OK / SMOKE STRESS OK / SMOKE BOT DONE.
##
## --watch-name=<ник> или --watch-peer=<id> (по умолчанию хост) — за движением чьего игрока
## следить. Так проверяется, что движение клиента доходит до другого клиента, а не только
## от хоста: peer_id в ENet случайный, поэтому надёжнее ник.
## Жёсткий таймаут гарантирует выход даже при ошибке.

const CLIENT_TIMEOUT := 8.0
const HOST_WAIT_PLAYERS := 20.0
const HOST_LIFETIME := 25.0
const GAME_SETTLE_TIME := 8.0
const GAME_WATCH_TIME := 12.0
const WORLD_WATCH_TIME := 30.0
const LAN_SEARCH_TIME := 5.0
const MOTION_DELTA := 200.0
const HOST_MOVE := Vector2(400.0, 0.0)
const HARD_TIMEOUT := 60.0
const STRESS_HOLD := 25.0
const BOT_STEP := 5.0
const REPORT_DIR := "res://_dsh_reports/"
const ADMIN_DELAY := 3.0
const ADMIN_QUIT_DELAY := 2.0
const TELEPORT_DELAY := 6.0
const TELEPORT_CHECK_DELAY := 2.0
const TELEPORT_DELTA := Vector2(2000.0, 0.0)

# тайминги мира: считаются от момента, когда карта загрузилась
const BREAK_DELAY := 6.0
const PICKUP_DELAY := 9.0
const EQUIP_DELAY := 3.0
const EQUIP_FALLBACK_DELAY := 5.0
const EQUIP_WALK_TIME := 1.5
const USE_DELAY := 8.0
const USE_STOP_DELAY := 25.0
const PICKUP_CHECK_DELAY := 1.5
const HITS_TO_BREAK := 40
const RAY_HALF := 40.0
const RAY_HEIGHTS := [40.0, 100.0, 160.0, 220.0]

var _args := {}
var _elapsed := 0.0
var _finished := false
var _expect_reject := false
var _game_started_at := -1.0
var _world_started_at := -1.0
var _host_moved := false
var _client_checked := false
var _watch_position := Vector2.ZERO
var _watch_peer := 1 # за чьим игроком следим в движении (--watch-peer)
var _watch_name := "" # либо по нику (--watch-name): peer_id в ENet случайный
var _watch_resolved := 0
var _watch_seen := false

var _motion_seen := false
var _tree_path := ""
var _tree_gone := false
var _break_attempted := false
var _loot_reported := false
var _pickup_item_path := ""
var _pickup_slots_before := -1
var _pickup_asked := false
var _pickup_checked := false
var _bot_phase := -1
var _net_cached := ""
var _fail_reason := ""
var _fail_at := 0.0
var _host_equipped := false
var _host_equip_fallback := false
var _host_walk_released := false
var _equip_checked := false
var _host_used := false
var _host_use_released := false
var _use_checked := false
var _spawn_reported := {}
var _admin_sent := false
var _admin_sent_at := 0.0
var _expect_kick := false
var _teleported := false
var _teleport_checked := false
var _teleport_before := Vector2.ZERO


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		_args[parts[0].lstrip("-")] = parts[1] if parts.size() > 1 else ""
	
	print("SMOKE ARGS: ", _args)
	_expect_reject = _args.has("expect-reject")
	_expect_kick = _args.has("expect-kick")
	
	if _args.has("watch-peer"):
		_watch_peer = int(_args["watch-peer"])
	
	if _args.has("watch-name"):
		_watch_name = str(_args["watch-name"])
	_write_report(0, "started")
	
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
	
	if _fail_at > 0.0 and _elapsed >= _fail_at:
		_finish(1, "SMOKE FAIL: %s" % _fail_reason)
		return
	
	if _elapsed >= HARD_TIMEOUT:
		_finish(1, "SMOKE FAIL: общий таймаут %.0f с" % HARD_TIMEOUT)
		return
	
	_track_world_time()
	
	if _args.has("autohost"):
		_tick_host()
	elif _args.has("autoconnect"):
		_tick_client()
	elif _elapsed >= LAN_SEARCH_TIME:
		_finish(1, "SMOKE LAN FAIL: хосты не найдены за %.0f с" % LAN_SEARCH_TIME)


func _track_world_time() -> void:
	if _world_started_at >= 0.0:
		return
	if MatchState.local_player == null:
		return
	
	_world_started_at = _elapsed


func _world_elapsed() -> float:
	if _world_started_at < 0.0:
		return 0.0
	return _elapsed - _world_started_at


## Стресс: поднять игру и держать её, пока боты подключаются и ходят.
## Печатаем точки появления: так видно, что игроки не встали в одну кучу.
func _report_spawns() -> void:
	for peer_id in MatchState.players:
		if _spawn_reported.has(peer_id):
			continue
		
		_spawn_reported[peer_id] = true
		var player: Player = MatchState.players[peer_id]
		print("SMOKE SPAWN %d: %s" % [peer_id, player.position])


func _tick_host_stress() -> void:
	if _game_started_at < 0.0:
		_game_started_at = _elapsed
		NetworkManager.start_game()
		print("SMOKE HOST STARTS GAME")
		return
	
	if _world_started_at < 0.0:
		if _elapsed - _game_started_at > GAME_SETTLE_TIME:
			_finish(1, "SMOKE HOST FAIL: игрок не появился в мире")
		return
	
	if _world_elapsed() < _hold_seconds():
		return
	
	print("SMOKE STRESS players=%d peers=%d %s" % [
		MatchState.player_count(), multiplayer.get_peers().size(), _net_report()
	])
	_finish(0, "SMOKE STRESS OK")


func _hold_seconds() -> float:
	if _args.has("hold"):
		return float(_args["hold"])
	
	return STRESS_HOLD


## Сколько байт ушло и пришло за сессию (счётчики ENet, читаются с обнулением).
func _net_report() -> String:
	if _net_cached != "":
		return _net_cached
	
	var peer := multiplayer.multiplayer_peer
	
	if not (peer is ENetMultiplayerPeer):
		return "net=нет ENet"
	
	var connection := (peer as ENetMultiplayerPeer).host
	
	if connection == null:
		return "net=нет соединения"
	
	var sent := int(connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))
	var received := int(connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
	
	_net_cached = "sent=%d received=%d" % [sent, received]
	return _net_cached


func _finish(_code: int, _message: String) -> void:
	_finished = true
	print(_message)
	_write_report(_code, _message)
	
	if is_instance_valid(NetworkManager):
		NetworkManager.disconnect_game()
	
	get_tree().quit(_code)


## Отчёт в файл: у процессов, запущенных через Start-Process, stdout буферизуется
## и хвост теряется, поэтому итог пишем ещё и в файл (--report=<имя файла>).
func _write_report(_code: int, _message: String) -> void:
	if not _args.has("report"):
		return
	
	var file := FileAccess.open(REPORT_DIR + str(_args["report"]), FileAccess.WRITE)
	
	if file == null:
		return
	
	# пира может уже не быть: отчёт пишется и после отключения
	var peers := 0
	
	if multiplayer.multiplayer_peer != null:
		peers = multiplayer.get_peers().size()
	
	file.store_line("%s | exit=%d players=%d peers=%d scene=%s %s" % [
		_message, _code, MatchState.player_count(),
		peers, _current_scene_path(), _net_report()
	])
	file.close()


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	
	if scene == null:
		return "-"
	
	return scene.scene_file_path.get_file()


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
	_report_spawns()
	
	if _args.has("stress"):
		_tick_host_stress()
		return
	
	if not _args.has("start-game") and not _args.has("solo-start"):
		if _elapsed >= HOST_LIFETIME:
			_finish(0, "SMOKE HOST DONE")
		return
	
	# ждём второго участника и начинаем игру
	if _game_started_at < 0.0:
		if (
			_args.has("solo-start")
			or MatchState.participants.size() >= 2
			or _elapsed >= HOST_WAIT_PLAYERS
		):
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
	
	if _args.has("world"):
		_tick_host_world()
		return
	
	if _elapsed - _game_started_at > GAME_WATCH_TIME:
		_finish(0, "SMOKE HOST DONE")


func _tick_host_world() -> void:
	_tick_host_equip()
	
	if not _tree_gone and _tree_path != "" and get_node_or_null(_tree_path) == null:
		_tree_gone = true # queue_free срабатывает в конце кадра
	
	if not _break_attempted and _world_elapsed() >= BREAK_DELAY:
		_break_attempted = true
		_break_tree()
	
	if not _pickup_asked and _world_elapsed() >= PICKUP_DELAY:
		_try_pickup("HOST")
	
	if _pickup_asked and not _pickup_checked and _world_elapsed() >= PICKUP_DELAY + PICKUP_CHECK_DELAY:
		_check_pickup("HOST")
	
	if _world_elapsed() < WORLD_WATCH_TIME:
		return
	
	print("SMOKE HOST SUMMARY: tree_gone=%s loot=%d" % [_tree_gone, _loot_count()])
	_finish(0, "SMOKE HOST DONE")


## Хост берёт оружие и разворачивается вправо: клиент должен увидеть и то, и другое.
func _tick_host_equip() -> void:
	var player := MatchState.local_player
	
	if player == null:
		return
	
	if not _host_equipped and _world_elapsed() >= EQUIP_DELAY:
		_host_equipped = true
		Input.action_press("right")
		EventSystem.EQU_hotkey_pressed.emit(player, 1)
		print("SMOKE HOST EQUIPS: слот 1")
	
	# если хотбар пуст, экипируем тем же сигналом, каким это делает хотбар
	if _host_equipped and not _host_equip_fallback and _world_elapsed() >= EQUIP_FALLBACK_DELAY:
		_host_equip_fallback = true
		
		if player.equippable_item_holder.current_item == null:
			EventSystem.EQU_equip_item.emit(player, ItemConfig.Keys.Axe)
			print("SMOKE HOST EQUIPS: напрямую (хотбар пуст)")
	
	if _host_equipped and not _host_walk_released and _world_elapsed() >= EQUIP_DELAY + EQUIP_WALK_TIME:
		_host_walk_released = true
		Input.action_release("right")
	
	# машем предметом долго: так его застанет и тот, кто подключится позже
	if _host_equipped and not _host_used and _world_elapsed() >= USE_DELAY:
		_host_used = true
		Input.action_press("use_item")
		print("SMOKE HOST USES: предмет")
	
	if _host_used and not _host_use_released and _world_elapsed() >= USE_STOP_DELAY:
		_host_use_released = true
		Input.action_release("use_item")


## Клиент проверяет, что видит чужую анимацию использования.
func _check_remote_use() -> void:
	if _use_checked:
		return
	
	var host_player: Player = MatchState.players.get(1)
	
	if host_player == null or host_player.equippable_item_holder == null:
		return
	
	var item = host_player.equippable_item_holder.current_item
	
	if item == null or item.animation_player == null:
		return
	if not item.animation_player.is_playing():
		return
	
	_use_checked = true
	print("SMOKE USE CLIENT: %s playing=true" % item.name)


## Клиент проверяет, что видит чужое оружие и правильную сторону.
func _check_remote_equip() -> void:
	if _equip_checked:
		return
	
	var host_player: Player = MatchState.players.get(1)
	
	if host_player == null or host_player.equippable_item_holder == null:
		return
	if host_player.equippable_item_holder.current_item == null:
		return
	
	_equip_checked = true
	print("SMOKE EQUIP CLIENT: %s face_right=%s own_empty=%s" % [
		host_player.equippable_item_holder.current_item.name,
		host_player.equippable_item_holder.scale.x > 0,
		MatchState.local_player.equippable_item_holder.current_item == null,
	])


func _break_tree() -> void:
	var tree := _find_hittable()
	
	if tree == null:
		_finish(1, "SMOKE HOST FAIL: не нашёл объект для удара")
		return
	
	_tree_path = str(tree.get_path())
	var center: Vector2 = tree.global_position
	
	# бьём на нескольких высотах: хитбокс у ствола выше основания
	for _i in HITS_TO_BREAK:
		for height in RAY_HEIGHTS:
			WorldSync.apply_hit(
				center + Vector2(-RAY_HALF, -height),
				center + Vector2(RAY_HALF, -height),
				ItemConfig.Keys.Axe
			)
	
	_tree_gone = get_node_or_null(_tree_path) == null
	print("SMOKE HOST TREE BROKEN: %s" % _tree_path)
	print("SMOKE HOST TREE GONE: %s" % _tree_gone)
	print("SMOKE HOST LOOT: %d" % _loot_count())


# Клиент

func _tick_client() -> void:
	# админ-клиент: подключается, шлёт одну команду серверу и уходит
	if _args.has("admin-kick") or _args.has("admin-stop") or _args.has("admin-status"):
		_tick_admin()
		return
	
	if not _args.has("expect-game") and not _args.has("bot"):
		return
	
	if MatchState.local_player == null:
		if _elapsed >= GAME_SETTLE_TIME + CLIENT_TIMEOUT:
			_finish(1, "SMOKE CLIENT FAIL: игрок не появился в мире")
		return
	
	if _args.has("bot"):
		_tick_bot()
		return
	
	if not _client_checked:
		_client_checked = true
		_check_client_game()
		return
	
	_tick_client_motion()
	
	if not _args.has("world"):
		if _motion_seen:
			_finish(0, _motion_marker())
		elif _elapsed >= GAME_WATCH_TIME + CLIENT_TIMEOUT:
			_finish(1, "SMOKE CLIENT FAIL: движение игрока %s не дошло" % _watch_label())
		return
	
	_tick_client_world()


## Следим за сетевой целью чужого игрока: она не двигается, если репликация не дошла.
func _tick_client_motion() -> void:
	if _motion_seen:
		return
	
	_watch_first()
	
	var target := _watch_target()
	
	if target == null or not _watch_seen:
		return
	
	if target.net_target.position.distance_to(_watch_position) > MOTION_DELTA:
		_motion_seen = true
		print(_motion_marker(), ": ", target.net_target.position)


## Позицию для сравнения берём как можно раньше: иначе первое же штатное обновление
## от чужого игрока зачтётся за движение.
func _watch_first() -> void:
	if _watch_seen:
		return
	
	var target := _watch_target()
	
	if target == null:
		return
	
	_watch_seen = true
	_watch_position = target.net_target.position
	print("SMOKE CLIENT WATCH: ", _watch_position)


## Кого смотрим: по нику (--watch-name) или по peer_id (--watch-peer, по умолчанию хост).
## Ник надёжнее: peer_id в ENet случайный, а не «2, 3, 4…».
func _watch_target() -> Player:
	if _watch_name == "":
		return MatchState.players.get(_watch_peer)
	
	for peer_id in MatchState.participants:
		if MatchState.participant_name(peer_id) == _watch_name:
			_watch_resolved = peer_id
			return MatchState.players.get(peer_id)
	
	return null


func _watch_label() -> String:
	if _watch_name != "":
		return _watch_name
	
	return str(_watch_peer)


func _motion_marker() -> String:
	var peer_id := _watch_peer
	
	if _watch_name != "":
		peer_id = _watch_resolved
	
	if peer_id == 1:
		return "SMOKE CLIENT SEES MOTION"
	
	return "SMOKE CLIENT SEES PEER %d MOTION" % peer_id


func _tick_client_world() -> void:
	_remember_tree()
	_check_remote_equip()
	_check_remote_use()
	
	if not _tree_gone and _tree_path != "" and get_node_or_null(_tree_path) == null:
		_tree_gone = true
		print("SMOKE CLIENT SEES TREE GONE")
	
	if _tree_gone and not _loot_reported:
		_loot_reported = true
		print("SMOKE CLIENT LOOT: %d" % _loot_count())
	
	if not _pickup_asked and _world_elapsed() >= PICKUP_DELAY:
		_try_pickup("CLIENT")
	
	if _pickup_asked and not _pickup_checked and _world_elapsed() >= PICKUP_DELAY + PICKUP_CHECK_DELAY:
		_check_pickup("CLIENT")
	
	if _tree_gone and _pickup_checked and _equip_checked and _use_checked:
		_finish(0, "SMOKE CLIENT WORLD OK")
		return
	
	if _world_elapsed() >= WORLD_WATCH_TIME:
		_finish(1, "SMOKE CLIENT FAIL: tree_gone=%s pickup=%s equip=%s use=%s" % [
			_tree_gone, _pickup_checked, _equip_checked, _use_checked
		])


func _remember_tree() -> void:
	if _tree_path != "":
		return
	
	var tree := _find_hittable()
	
	if tree != null:
		_tree_path = str(tree.get_path())
		print("SMOKE WORLD TREE PATH: %s" % _tree_path)


## Бот для стресса: ходит влево-вправо и в конце отчитывается о трафике.
## Админ-клиент: даём остальным подключиться и отправляем одну команду серверу.
func _tick_admin() -> void:
	if not _admin_sent:
		if _elapsed < ADMIN_DELAY:
			return
		
		_admin_sent = true
		_admin_sent_at = _elapsed
		var token := str(_args.get("admin-token", ""))
		
		if _args.has("admin-kick"):
			NetworkManager.send_admin_command(token, "kick", str(_args["admin-kick"]))
			print("SMOKE ADMIN KICK: %s" % _args["admin-kick"])
		elif _args.has("admin-stop"):
			NetworkManager.send_admin_command(token, "stop")
			print("SMOKE ADMIN STOP")
		else:
			NetworkManager.send_admin_command(token, "status")
			print("SMOKE ADMIN STATUS")
		return
	
	if _elapsed - _admin_sent_at >= ADMIN_QUIT_DELAY:
		_finish(0, "SMOKE ADMIN OK")


func _tick_bot() -> void:
	if not _client_checked:
		_client_checked = true
		print("SMOKE BOT READY players=%d dedicated=%s" % [
			MatchState.player_count(), MatchState.is_dedicated_server
		])
	
	var phase := int(_elapsed / BOT_STEP) % 2
	
	if phase != _bot_phase:
		_bot_phase = phase
		Input.action_release("left")
		Input.action_release("right")
		Input.action_press("left" if phase == 0 else "right")
	
	if _args.has("teleport") and not _teleported and _elapsed >= TELEPORT_DELAY:
		_teleported = true
		_teleport_before = MatchState.local_player.position
		# подделка: клиент двигает себя сам, сервер об этом не просил
		MatchState.local_player.position += TELEPORT_DELTA
		# дальше стоим на месте: так видно, откатила ли серверная правда подделку
		Input.action_release("left")
		Input.action_release("right")
		print("SMOKE CLIENT TELEPORTS: %s -> %s" % [
			_teleport_before, MatchState.local_player.position
		])
	
	if _teleported and not _teleport_checked and _elapsed >= TELEPORT_DELAY + TELEPORT_CHECK_DELAY:
		_teleport_checked = true
		print("SMOKE CLIENT AFTER TELEPORT: %s (до подделки %s)" % [
			MatchState.local_player.position, _teleport_before
		])
	
	if _elapsed < _hold_seconds():
		return
	
	Input.action_release("left")
	Input.action_release("right")
	print("SMOKE BOT DONE players=%d %s" % [MatchState.player_count(), _net_report()])
	_finish(0, "SMOKE BOT DONE")


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
	
	_watch_first()


# Подбор предмета: обе стороны целятся в один и тот же предмет

func _try_pickup(_who: String) -> void:
	_pickup_asked = true
	_pickup_slots_before = _free_slots()
	
	var item := _find_shared_item()
	
	if item == null:
		print("SMOKE PICKUP %s: предмет не найден" % _who)
		_pickup_item_path = ""
		return
	
	var pickuppable: PickuppableItem = item.get_node_or_null("Pickuppable")
	
	if pickuppable == null:
		print("SMOKE PICKUP %s: у предмета нет зоны подбора" % _who)
		_pickup_item_path = ""
		return
	
	_pickup_item_path = str(item.get_path())
	print("SMOKE PICKUP %s ASKS: %s" % [_who, _pickup_item_path])
	WorldSync.request_pickup(item, MatchState.local_player, pickuppable.item_key)


func _check_pickup(_who: String) -> void:
	_pickup_checked = true
	
	var after := _free_slots()
	var won := after >= 0 and _pickup_slots_before >= 0 and after < _pickup_slots_before
	var gone := _pickup_item_path != "" and get_node_or_null(_pickup_item_path) == null
	
	print("SMOKE PICKUP %s: %s free=%d→%d item_gone=%s" % [
		_who, "won" if won else "lost", _pickup_slots_before, after, gone
	])


# Вспомогательное

func _free_slots() -> int:
	var player := MatchState.local_player
	
	if player == null:
		return -1
	
	var inventory := player.get_node_or_null("Managers/ManagerInventory")
	
	if inventory == null:
		return -1
	
	return inventory.get_free_slots()


func _loot_count() -> int:
	# группа задана в level_1.tscn на узле ManagerSpawner
	var spawner := get_tree().get_first_node_in_group("world_spawner")
	
	if spawner == null:
		return -1
	
	var items := spawner.get_node_or_null("Items")
	
	if items == null:
		return -1
	
	return items.get_child_count()


func _level_root() -> Node:
	var scene := get_tree().current_scene
	
	if scene == null:
		return null
	
	var stage := scene.get_node_or_null("Managers/StageManager")
	
	if stage == null or stage.get_child_count() == 0:
		return null
	
	return stage.get_child(0)


## Берём объект, у которого есть настоящий дроп: ломать надо то, что даёт лут.
func _find_hittable() -> Node2D:
	var level := _level_root()
	
	if level == null:
		return null
	
	var env := level.get_node_or_null("env")
	
	if env == null:
		return null
	
	var fallback: Node2D = null
	
	for child in env.get_children():
		if not (child is HittableObjectTemplate):
			continue
		if fallback == null:
			fallback = child
		if ItemConfig.get_pickuppable_item(child.attributes.drop_item_key) != null:
			return child
	
	return fallback


func _find_shared_item() -> Node:
	var level := _level_root()
	
	if level == null:
		return null
	
	var items := level.get_node_or_null("Items")
	
	if items == null:
		return null
	
	for child in items.get_children():
		if child.get_node_or_null("Pickuppable") is PickuppableItem:
			return child
	
	return null


# Сигналы

func _on_connection_succeeded() -> void:
	# админ-клиенту сцена не нужна: он только отправляет команду
	if _args.has("admin-kick") or _args.has("admin-stop") or _args.has("admin-status"):
		print("SMOKE ADMIN CONNECTED")
		return
	
	if _args.has("expect-game") or _args.has("bot"):
		print("SMOKE CLIENT CONNECTED")
		return
	
	if _expect_reject:
		_finish(1, "SMOKE CLIENT FAIL: подключение принято, а ожидался отказ")
		return
	
	_finish(0, "SMOKE CLIENT CONNECTED")


func _on_join_rejected(_reason: String) -> void:
	if _expect_kick:
		_finish(0, "SMOKE CLIENT KICKED OK: %s" % _reason)
		return
	
	if _expect_reject:
		_finish(0, "SMOKE CLIENT REJECTED: %s" % _reason)
		return
	
	_finish(1, "SMOKE CLIENT FAIL: отказ — %s" % _reason)


func _on_failed(_reason: String) -> void:
	# сервер остановлен по админ-команде — это и был сценарий
	if _admin_sent and _args.has("admin-stop"):
		_finish(0, "SMOKE ADMIN STOP OK")
		return
	
	# даём кадру перейти в меню, если хост ушёл во время игры
	_fail_reason = _reason
	_fail_at = _elapsed + 0.6


func _on_participant_joined(_peer_id: int) -> void:
	print("SMOKE HOST SEES PLAYER %d: %s" % [_peer_id, MatchState.participants.values()])


func _on_servers_changed(_servers: Dictionary) -> void:
	print("SMOKE LAN SEES: ", _servers)
	
	if _args.has("lan-search"):
		_finish(0, "SMOKE LAN FOUND %d" % _servers.size())
