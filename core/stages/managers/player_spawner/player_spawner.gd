class_name PlayerSpawner extends Node

## Спавн игроков в мире: по одному на каждого участника матча.
##
## Узлы создаются детерминированно на всех пирах из списка MatchState.participants,
## поэтому имена и пути совпадают и репликация движения работает. Авторитет отдаётся
## владельцу — только он шлёт своё движение остальным.

const PLAYER_SCENE_PATH := "res://shared/actors/player/player.tscn"
const BULLET_SCENE_PATH := "res://shared/objects/bullet/bullet.tscn"
const SPAWN_GROUP := "player_spawn"
const SPAWN_OFFSET := Vector2(70.0, 0.0) # чтобы игроки не стояли друг в друге

var _players: Dictionary[int, Player] = {}
var _player_scene: PackedScene
var _bullet_scene: PackedScene


func _ready() -> void:
	_player_scene = load(PLAYER_SCENE_PATH)
	_bullet_scene = load(BULLET_SCENE_PATH)
	
	MatchState.participants_changed.connect(_sync_players)
	# сцена ещё достраивается, добавлять детей можно только после этого
	_sync_players.call_deferred()


func get_player(_peer_id: int) -> Player:
	return _players.get(_peer_id)


## Состав игроков в мире должен совпадать с составом матча на всех пирах.
func _sync_players() -> void:
	var wanted := _wanted_peer_ids()
	
	for index in wanted.size():
		var peer_id: int = wanted[index]
		
		if not _players.has(peer_id):
			_spawn(peer_id, index)
	
	for peer_id in _players.keys():
		if not wanted.has(peer_id):
			_despawn(peer_id)


func _wanted_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	
	# одиночная игра: матча нет, играет один локальный игрок
	if MatchState.participants.is_empty():
		ids.append(MatchState.OFFLINE_PEER_ID)
		return ids
	
	for peer_id in MatchState.participants:
		ids.append(peer_id)
	
	ids.sort()
	return ids


func _spawn(_peer_id: int, _index: int) -> void:
	var player: Player = _player_scene.instantiate()
	var marker := _spawn_marker()
	
	player.name = "Player_%d" % _peer_id
	player.peer_id = _peer_id
	player.bullet_schene = _bullet_scene
	player.spawn = marker
	
	if marker != null:
		player.position = marker.position + SPAWN_OFFSET * _index
	
	player.set_multiplayer_authority(_peer_id)
	get_parent().add_child(player)
	_players[_peer_id] = player


func _despawn(_peer_id: int) -> void:
	var player: Player = _players.get(_peer_id)
	_players.erase(_peer_id)
	
	if is_instance_valid(player):
		player.queue_free()


func _spawn_marker() -> Marker2D:
	return get_tree().get_first_node_in_group(SPAWN_GROUP) as Marker2D
