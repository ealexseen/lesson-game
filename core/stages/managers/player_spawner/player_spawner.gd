class_name PlayerSpawner extends Node

## Спавн игроков в мире: по одному на каждого участника матча.
##
## Узлы создаются детерминированно на всех пирах из списка MatchState.participants,
## поэтому имена и пути совпадают и репликация движения работает. Авторитет отдаётся
## владельцу — только он шлёт своё движение остальным.

const PLAYER_SCENE_PATH := "res://shared/actors/player/player.tscn"
const BULLET_SCENE_PATH := "res://shared/objects/bullet/bullet.tscn"
const SPAWN_GROUP := "player_spawn"
const SPAWN_COLUMNS := 10 # сколько игроков в ряду
const SPAWN_STEP := 60.0 # шаг внутри ряда, шире персонажа
const SPAWN_ROW_HEIGHT := 70.0 # высота ряда, чтобы не толкались в одной точке

var _players: Dictionary[int, Player] = {}
var _slots: Dictionary[int, int] = {} # peer_id → место на площадке
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


## Раскладываем игроков сеткой вокруг маркера. Линией пускать нельзя: площадка на
## карте конечная, крайние оказываются за ней, падают и возвращаются `save_player`
## в одну точку — получается та самая куча.
static func spawn_offset(_index: int) -> Vector2:
	var column := _index % SPAWN_COLUMNS
	var row := int(float(_index) / float(SPAWN_COLUMNS))
	var offset := Vector2(
		column * SPAWN_STEP - SPAWN_STEP * float(SPAWN_COLUMNS - 1) * 0.5,
		-row * SPAWN_ROW_HEIGHT
	)
	
	# нечётные ряды сдвигаем на полшага: иначе второй ряд падает на головы первого
	if row % 2 == 1:
		offset.x += SPAWN_STEP * 0.5
	
	return offset


## Место выдаём явно, а не по позиции в списке участников: список сортирован по
## peer_id, а он случайный, и подключение «в середину» сдвигало бы индексы —
## новые игроки вставали бы в уже занятые точки.
func _slot_for(_peer_id: int) -> int:
	if _slots.has(_peer_id):
		return _slots[_peer_id]
	
	var slot := 0
	var taken: Array = _slots.values()
	
	while taken.has(slot):
		slot += 1
	
	_slots[_peer_id] = slot
	return slot


func _spawn(_peer_id: int, _index: int) -> void:
	var player: Player = _player_scene.instantiate()
	var marker := _spawn_marker()
	
	player.name = "Player_%d" % _peer_id
	player.peer_id = _peer_id
	player.bullet_schene = _bullet_scene
	player.spawn = marker
	
	if marker != null:
		player.position = marker.position + spawn_offset(_slot_for(_peer_id))
	
	player.set_multiplayer_authority(_peer_id)
	get_parent().add_child(player)
	# движение считает сервер: цель синхронизатора принадлежит ему, а не владельцу,
	# поэтому владелец своё движение предсказывает, а рассылает истину сервер
	player.net_target.set_multiplayer_authority(1)
	_players[_peer_id] = player


func _despawn(_peer_id: int) -> void:
	var player: Player = _players.get(_peer_id)
	_players.erase(_peer_id)
	_slots.erase(_peer_id)
	
	if is_instance_valid(player):
		player.queue_free()


func _spawn_marker() -> Marker2D:
	return get_tree().get_first_node_in_group(SPAWN_GROUP) as Marker2D
