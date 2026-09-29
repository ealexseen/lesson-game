class_name EquippableItemHolder extends Node2D

## Предмет в руках. Владелец применяет экипировку у себя и рассылает остальным,
## чтобы чужой игрок видел то же оружие и ту же сторону.

var owner_player: Player
var current_item
var current_key
var save_position
var _last_direction := 0


func _enter_tree() -> void:
	owner_player = MatchState.find_owner_player(self)
	
	EventSystem.EQU_equip_item.connect(on_equip_item)
	EventSystem.EQU_unequip_item.connect(on_unequip_item)


func _ready() -> void:
	save_position = position
	WorldSync.peer_entered_world.connect(_on_peer_entered_world)


## Новичку досылаем то, что у нас уже в руках: он это пропустил.
func _on_peer_entered_world(_peer_id: int) -> void:
	if not _is_owner_peer():
		return
	
	# о себе заботиться не нужно, а rpc_id на себя движок запрещает
	if _peer_id == owner_player.peer_id:
		return
	
	if current_key != null:
		rpc_id(_peer_id, "_remote_equip", current_key)
	if _last_direction != 0:
		rpc_id(_peer_id, "_remote_flip", _last_direction)


func try_to_use_item() -> void:
	if current_item == null:
		return
	
	# рассылаем только когда анимация действительно началась, а не каждый кадр
	if current_item.try_to_use() and _is_owner_peer():
		rpc("_remote_use")


func on_equip_item(player: Player, item_key) -> void:
	if player != owner_player:
		return
	
	_equip(item_key)
	
	if _is_owner_peer():
		rpc("_remote_equip", item_key)


func on_unequip_item(player: Player) -> void:
	if player != owner_player:
		return
	
	_unequip()
	
	if _is_owner_peer():
		rpc("_remote_unequip")


func direction_flip(direction: int) -> void:
	if direction == _last_direction:
		return
	
	_last_direction = direction
	_apply_flip(direction)
	
	if _is_owner_peer():
		rpc("_remote_flip", direction)


## Рассылает только владелец игрока: у остальных это чужая экипировка.
func _is_owner_peer() -> bool:
	return (
		owner_player != null
		and owner_player.is_local()
		and NetworkManager.is_connected_to_game()
	)


# Применение — одинаковое у владельца и у остальных

func _equip(item_key) -> void:
	_unequip()
	
	if not item_key:
		return
	
	var equippable_item: PackedScene = ItemConfig.get_equippable_item(item_key)
	
	if not equippable_item:
		return
	
	current_item = equippable_item.instantiate()
	current_key = item_key
	
	if current_item is EquippableWeaponeTemplate:
		current_item.weapon_item_resource = ItemConfig.get_item_resource(item_key)
	elif current_item is EquippableConsumableTemplate:
		current_item.consumable_item_resource = ItemConfig.get_item_resource(item_key)
	
	add_child(current_item)


func _unequip() -> void:
	if not current_item:
		return
	
	current_item.queue_free()
	current_item = null
	current_key = null


func _apply_flip(direction: int) -> void:
	if direction > 0:
		scale.x = abs(scale.x)
		position = save_position
	elif direction < 0:
		scale.x = -abs(scale.x)
		position = Vector2(-save_position.x, save_position.y)


# Приём у остальных

@rpc("authority", "call_remote", "reliable")
func _remote_equip(item_key) -> void:
	_equip(item_key)


@rpc("authority", "call_remote", "reliable")
func _remote_unequip() -> void:
	_unequip()


@rpc("authority", "call_remote", "reliable")
func _remote_flip(direction: int) -> void:
	_apply_flip(direction)


## Чужое использование: играем ту же анимацию, эффекты остаются у владельца.
@rpc("authority", "call_remote", "reliable")
func _remote_use() -> void:
	if current_item == null:
		return
	
	current_item.try_to_use()
