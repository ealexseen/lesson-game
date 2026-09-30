extends Node

## Авторитет над миром: удары и урон считает сервер, он же решает, кому достанется
## предмет, и рассылает спавн лута остальным.
##
## Здесь же хранится состояние мира (что сломано и подобрано), чтобы поздний вход
## получил снапшот и увидел мир таким же, как все.
## class_name здесь нельзя: имя занято автолоадом WorldSync.

## Пир вошёл в мир: владельцы досылают ему то, что он пропустил (экипировку).
signal peer_entered_world(_peer_id: int)

const HITBOX_LAYER_MASK := 64 # слой hitbox (layer_7)
const MAX_HIT_DISTANCE := 250.0 # насколько далеко от игрока может начаться удар
const DEBUG_RAY := false # рисовать отладочный луч удара
const VISIBILITY_INTERVAL := 0.5 # как часто сервер пересчитывает видимость движения

var _destroyed: Dictionary[String, bool] = {}
var _spawned: Dictionary[int, Dictionary] = {}
var _peers_in_world: Dictionary[int, bool] = {}
var _visible_cache := {}
var _visibility_elapsed := 0.0
var _next_spawn_id := 0
var _snapshot_scene: Node = null


func _ready() -> void:
	NetworkManager.server_started.connect(reset)
	# состав меняется — сразу пересчитываем, кому какое движение слать
	MatchState.participants_changed.connect(refresh_visibility)
	multiplayer.peer_connected.connect(_on_peer_connected)


## В одиночной игре сервером считаем себя.
func is_server() -> bool:
	return not NetworkManager.is_connected_to_game() or NetworkManager.is_hosting()


func reset() -> void:
	_destroyed.clear()
	_spawned.clear()
	_peers_in_world.clear()
	_visible_cache.clear()
	_next_spawn_id = 0
	_snapshot_scene = null


# Движение: ввод владельца и поправки сервера

## Владелец сообщает серверу свой ввод: номер кадра, оси, прыжок и своё предсказание.
func send_input(_seq: int, _axis: float, _jump: bool, _position: Vector2) -> void:
	if is_server() or not NetworkManager.is_connected_to_game():
		return
	
	rpc_id(1, "_submit_input", _seq, _axis, _jump, _position)


## Ввод принимаем только за своего игрока: отправитель и есть его владелец,
## поэтому подделать чужое движение этой ручкой нельзя.
@rpc("any_peer", "call_remote", "reliable")
func _submit_input(_seq: int, _axis: float, _jump: bool, _position: Vector2) -> void:
	if not is_server():
		return
	
	var player: Player = MatchState.players.get(multiplayer.get_remote_sender_id())
	
	if player == null:
		return
	
	player.apply_remote_input(_seq, _axis, _jump, _position)


## Сервер подтверждает владельцу: «на этом твоём кадре ты стоял вот здесь».
func send_reconcile(_peer_id: int, _seq: int, _position: Vector2) -> void:
	if not is_server() or not NetworkManager.is_connected_to_game():
		return
	if _peer_id == multiplayer.get_unique_id() or _peer_id == 1:
		return
	
	rpc_id(_peer_id, "_reconcile", _seq, _position)


@rpc("authority", "call_remote", "reliable")
func _reconcile(_seq: int, _position: Vector2) -> void:
	var player: Player = MatchState.local_player
	
	if player != null:
		player.reconcile(_seq, _position)


# Видимость движения: решает сервер, потому что движение рассылает он

func _on_peer_connected(_peer_id: int) -> void:
	refresh_visibility()


## Пересчитать видимость всем игрокам сразу (состав изменился).
func refresh_visibility() -> void:
	if not is_server():
		return
	
	for peer_id in MatchState.players:
		_apply_player_visibility(MatchState.players[peer_id])


func _tick_visibility(_delta: float) -> void:
	if not is_server():
		return
	
	_visibility_elapsed += _delta
	
	if _visibility_elapsed < VISIBILITY_INTERVAL:
		return
	
	_visibility_elapsed = 0.0
	refresh_visibility()


func _apply_player_visibility(_player: Player) -> void:
	var synchronizer: MultiplayerSynchronizer = _player.net_target.get_node_or_null(
		"MultiplayerSynchronizer"
	)
	
	if synchronizer == null:
		return
	
	# видимость по умолчанию выключена: первый пакет уходит только тому, у кого
	# уже есть наши узлы, иначе кэш путей у получателя не подтвердится и
	# репликация в эту сторону залипнет (разбор — §10 плана)
	synchronizer.set_visibility_public(false)
	
	for peer_id in multiplayer.get_peers():
		synchronizer.set_visibility_for(peer_id, _is_visible_to(_player, peer_id))
	
	synchronizer.update_visibility()


func _is_visible_to(_player: Player, _peer_id: int) -> bool:
	# пока пир не на карте, у него наших узлов нет
	if not is_peer_in_world(_peer_id):
		return false
	
	# владельцу своё движение не шлём: он его предсказывает сам
	if _player.peer_id == _peer_id:
		return false
	
	if not Player.INTEREST_RADIUS_ENABLED:
		return true
	
	var other: Player = MatchState.players.get(_peer_id)
	
	if other == null:
		return false
	
	var key := "%d:%d" % [_player.peer_id, _peer_id]
	var limit := Player.VISIBILITY_RADIUS
	
	if _visible_cache.get(key, false):
		limit += Player.VISIBILITY_HYSTERESIS
	
	var visible := _player.global_position.distance_to(other.global_position) <= limit
	_visible_cache[key] = visible
	return visible


## Пир уже на карте: только таким шлём движение, иначе у них сыплются ошибки
## о несуществующих узлах — они ещё в лобби.
func is_peer_in_world(_peer_id: int) -> bool:
	if _peer_id == 1:
		return true # хост и есть сервер, он всегда в мире
	if _peer_id == multiplayer.get_unique_id():
		return true
	
	return _peers_in_world.has(_peer_id)


func _process(_delta: float) -> void:
	_check_snapshot_request()
	_tick_visibility(_delta)


# Удары

## Клиент присылает луч, сервер считает урон сам.
func request_hit(_from: Vector2, _to: Vector2, _item_key: int) -> void:
	if is_server():
		apply_hit(_from, _to, _item_key)
		return
	
	if NetworkManager.is_connected_to_game():
		rpc_id(1, "_request_hit", _from, _to, _item_key)


@rpc("any_peer", "call_remote", "reliable")
func _request_hit(_from: Vector2, _to: Vector2, _item_key: int) -> void:
	if not is_server():
		return
	
	var sender := multiplayer.get_remote_sender_id()
	var player: Player = MatchState.players.get(sender)
	
	if player == null:
		return
	if player.global_position.distance_to(_from) > MAX_HIT_DISTANCE:
		return
	
	apply_hit(_from, _to, _item_key)


## Урон по лучу: выполняет только сервер.
func apply_hit(_from: Vector2, _to: Vector2, _item_key: int) -> void:
	var weapon := ItemConfig.get_item_resource(_item_key)
	
	if not (weapon is WeaponItemResource):
		return
	
	var query := PhysicsRayQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = HITBOX_LAYER_MASK
	query.from = _from
	query.to = _to
	
	var result := get_tree().root.world_2d.direct_space_state.intersect_ray(query)
	
	if result.is_empty():
		return
	
	var collider = result.collider
	
	if collider.has_method("take_hit"):
		collider.take_hit(weapon)
	
	if DEBUG_RAY:
		_draw_debug_ray(_from, _to)


func _draw_debug_ray(_from: Vector2, _to: Vector2) -> void:
	var scene := get_tree().current_scene
	
	if scene == null:
		return
	
	var line := Line2D.new()
	line.add_point(_from)
	line.add_point(_to)
	line.width = 2.0
	line.default_color = Color.RED
	scene.add_child(line)


# Уничтожение объектов

## Объект уничтожен сервером: запоминаем путь и рассылаем всем.
func mark_dead(_node: Node) -> void:
	if not is_server():
		return
	
	var path := str(_node.get_path())
	_destroyed[path] = true
	
	if NetworkManager.is_connected_to_game():
		rpc("_apply_death", path)


func is_removed(_path: String) -> bool:
	return _destroyed.has(_path)


@rpc("authority", "call_remote", "reliable")
func _apply_death(_path: String) -> void:
	_destroyed[_path] = true
	var node := get_node_or_null(_path)
	
	if node == null:
		return
	
	if node.has_method("apply_remote_death"):
		node.apply_remote_death()
		return
	
	# у простых предметов корень без скрипта — просто убираем узел
	node.queue_free()


# Подбор предметов

## Подбор решает сервер: предмет достаётся тому, чей запрос пришёл первым.
func request_pickup(_node: Node, _player: Player, _item_key: int) -> void:
	if is_server():
		_grant_pickup(_node, _player, _item_key)
		return
	
	if NetworkManager.is_connected_to_game():
		rpc_id(1, "_request_pickup", str(_node.get_path()), _item_key)


@rpc("any_peer", "call_remote", "reliable")
func _request_pickup(_path: String, _item_key: int) -> void:
	if not is_server():
		return
	if _destroyed.has(_path):
		return # предмет уже забрали
	
	var node := get_node_or_null(_path)
	
	if node == null:
		return
	
	var sender := multiplayer.get_remote_sender_id()
	var player: Player = MatchState.players.get(sender)
	
	if player == null:
		return
	
	_grant_pickup(node, player, _item_key)


func _grant_pickup(_node: Node, _player: Player, _item_key: int) -> void:
	if not is_instance_valid(_node) or _destroyed.has(str(_node.get_path())):
		return
	
	mark_dead(_node)
	_node.queue_free()
	
	if _player.is_local():
		# на сервере локальный игрок — сам хост
		EventSystem.INV_add_item.emit(_player, _item_key)
		return
	
	if NetworkManager.is_connected_to_game():
		rpc_id(_player.peer_id, "_grant_pickup_remote", _item_key)


@rpc("authority", "call_remote", "reliable")
func _grant_pickup_remote(_item_key: int) -> void:
	var player := MatchState.local_player
	
	if player != null:
		EventSystem.INV_add_item.emit(player, _item_key)


# Снапшот мира для позднего входа

## Клиент, попав на карту, просит у сервера текущее состояние мира.
func _check_snapshot_request() -> void:
	if is_server() or not NetworkManager.is_connected_to_game():
		return
	# заявку шлём только со своим игроком на руках: с этого момента остальные включают
	# нам репликацию, а она требует, чтобы наши узлы уже существовали
	if MatchState.local_player == null:
		return
	
	var scene := get_tree().current_scene
	
	if scene == null or scene == _snapshot_scene:
		return
	if not scene.scene_file_path.ends_with("map_1.tscn"):
		return
	
	_snapshot_scene = scene
	rpc_id(1, "_request_snapshot")


## Сервер отмечает пира как вошедшего в мир и сообщает остальным.
@rpc("authority", "call_remote", "reliable")
func _peer_in_world_remote(_peer_id: int) -> void:
	_peers_in_world[_peer_id] = true
	peer_entered_world.emit(_peer_id)


func snapshot() -> Dictionary:
	return {
		"destroyed": _destroyed.keys(),
		"spawned": _spawned.duplicate(true),
		"next_spawn_id": _next_spawn_id,
	}


@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	if not is_server():
		return
	
	var sender := multiplayer.get_remote_sender_id()
	_peers_in_world[sender] = true
	ServerLog.line("%s вошёл в мир" % MatchState.participant_name(sender), ServerLog.COLOR_EVENTS)
	peer_entered_world.emit(sender)
	rpc("_peer_in_world_remote", sender)
	rpc_id(sender, "_apply_snapshot", snapshot())


## Пир ушёл: забываем его, чтобы видимость движения не считала его на карте.
func forget_peer(_peer_id: int) -> void:
	_peers_in_world.erase(_peer_id)
	_visible_cache.clear()


@rpc("authority", "call_remote", "reliable")
func _apply_snapshot(_data: Dictionary) -> void:
	_destroyed.clear()
	_spawned.clear()
	_next_spawn_id = int(_data.get("next_spawn_id", 0))
	
	for path in _data.get("destroyed", []):
		var string_path := str(path)
		_destroyed[string_path] = true
		var node := get_node_or_null(string_path)
		
		if node != null:
			node.queue_free()
	
	var spawner := get_tree().get_first_node_in_group(SPAWNER_GROUP)
	var spawned: Dictionary = _data.get("spawned", {})
	
	for id in spawned:
		var info: Dictionary = spawned[id]
		_spawned[int(id)] = info
		
		if spawner != null:
			spawner.restore_spawn(
				int(id),
				str(info.get("scene", "")),
				info.get("transform", Transform2D.IDENTITY)
			)


# Спавн лута

const SPAWNER_GROUP := "world_spawner"


func next_spawn_id() -> int:
	var id := _next_spawn_id
	_next_spawn_id += 1
	return id


func register_spawn(_id: int, _scene_path: String, _transform: Transform2D) -> void:
	_spawned[_id] = {"scene": _scene_path, "transform": _transform}


func spawned_count() -> int:
	return _spawned.size()


func destroyed_count() -> int:
	return _destroyed.size()
