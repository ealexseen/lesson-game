extends Node

## Состояние матча: кто локальный игрок и кто вообще участвует в игре.
##
## В одиночной игре локальным становится единственный игрок. В мультиплеере —
## игрок своего peer: без этого игровые события одного игрока срабатывают у всех.
## class_name здесь нельзя: имя занято автолоадом MatchState.

signal local_player_changed(_player: Player)
signal players_changed()
signal participants_changed()

const MAX_PLAYERS := 20
const OFFLINE_PEER_ID := 0

var local_player: Player = null
var players: Dictionary[int, Player] = {}
# участники матча из лобби: peer_id -> имя (игроки в мире появятся на этапе M2)
var participants: Dictionary[int, String] = {}
var is_host: bool = true


func is_networked() -> bool:
	var peer := multiplayer.multiplayer_peer
	
	if peer == null:
		return false
	
	# движок подставляет OfflineMultiplayerPeer, когда сети нет
	if peer is OfflineMultiplayerPeer:
		return false
	
	return true


func register_player(_player: Player, _peer_id: int = OFFLINE_PEER_ID) -> void:
	_player.peer_id = _free_peer_id(_peer_id)
	players[_player.peer_id] = _player
	players_changed.emit()
	
	if local_player == null and is_local_peer(_player.peer_id):
		set_local_player(_player)


## Свободный peer_id: без сети игроки приходят без него и не должны затирать друг друга.
func _free_peer_id(_peer_id: int) -> int:
	if not players.has(_peer_id):
		return _peer_id
	
	var candidate := OFFLINE_PEER_ID + 1
	
	while players.has(candidate):
		candidate += 1
	
	return candidate


func unregister_player(_player: Player) -> void:
	if players.get(_player.peer_id) != _player:
		return
	
	players.erase(_player.peer_id)
	players_changed.emit()
	
	if local_player == _player:
		set_local_player(null)


func set_local_player(_player: Player) -> void:
	if local_player == _player:
		return
	
	local_player = _player
	local_player_changed.emit(local_player)


func get_player(_peer_id: int) -> Player:
	return players.get(_peer_id) as Player


func player_count() -> int:
	return players.size()


func is_local_peer(_peer_id: int) -> bool:
	# без сети всё локальное
	if not is_networked():
		return true
	
	return _peer_id == multiplayer.get_unique_id()


## Адресовано ли событие этому клиенту: событие без владельца считаем общим.
func is_local_event(_player: Player) -> bool:
	return local_player == null or _player == local_player


## Игрок-владелец узла: поднимаемся по дереву до Player.
func find_owner_player(_node: Node) -> Player:
	var current := _node.get_parent()
	
	while current:
		if current is Player:
			return current
		current = current.get_parent()
	
	return null


func set_participants(_participants: Dictionary[int, String]) -> void:
	participants = _participants
	participants_changed.emit()


func add_participant(_peer_id: int, _name: String) -> void:
	participants[_peer_id] = _name
	participants_changed.emit()


func clear_participants() -> void:
	if participants.is_empty():
		return
	
	participants.clear()
	participants_changed.emit()


func remove_participant(_peer_id: int) -> void:
	if not participants.has(_peer_id):
		return
	
	participants.erase(_peer_id)
	participants_changed.emit()


func get_participants() -> Dictionary[int, String]:
	return participants.duplicate()


func participant_name(_peer_id: int) -> String:
	return participants.get(_peer_id, "?")


## Цвет игрока выводится из peer_id: он одинаков на всех пирах и не требует синхронизации.
func participant_color(_peer_id: int) -> Color:
	const GOLDEN_RATIO := 0.618033988749895
	const SATURATION := 0.75
	const VALUE := 1.0
	
	var hue := fmod(absf(float(_peer_id)) * GOLDEN_RATIO, 1.0)
	return Color.from_hsv(hue, SATURATION, VALUE)
