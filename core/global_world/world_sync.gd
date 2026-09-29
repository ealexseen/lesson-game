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

var _destroyed: Dictionary[String, bool] = {}
var _spawned: Dictionary[int, Dictionary] = {}
var _peers_in_world: Dictionary[int, bool] = {}
var _next_spawn_id := 0
var _snapshot_scene: Node = null


func _ready() -> void:
	NetworkManager.server_started.connect(reset)


## В одиночной игре сервером считаем себя.
func is_server() -> bool:
	return not NetworkManager.is_connected_to_game() or NetworkManager.is_hosting()


func reset() -> void:
	_destroyed.clear()
	_spawned.clear()
	_peers_in_world.clear()
	_next_spawn_id = 0
	_snapshot_scene = null


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
	peer_entered_world.emit(sender)
	rpc("_peer_in_world_remote", sender)
	rpc_id(sender, "_apply_snapshot", snapshot())


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
