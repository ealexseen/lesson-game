class_name EquippableItemHolder extends Node2D

## Предмет в руках. Владелец применяет экипировку у себя, а остальным её раздаёт
## сервер: клиент видит напрямую только сервер, поэтому своё сообщение он шлёт ему,
## а тот пересылает остальным — иначе выбор предмета не доходил бы до других игроков.

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


## Что у нас в руках и куда мы смотрим: это уходит и снапшотом, и по изменениям.
func state() -> Dictionary:
	return {"key": current_key, "direction": _last_direction}


func try_to_use_item() -> void:
	if current_item == null:
		return
	
	# рассылаем только когда анимация действительно началась, а не каждый кадр
	if current_item.try_to_use() and _is_owner_peer():
		WorldSync.send_equipment("use")


func on_equip_item(player: Player, item_key) -> void:
	if player != owner_player:
		return
	
	_equip(item_key)
	
	if _is_owner_peer():
		WorldSync.send_equipment("equip", item_key)


func on_unequip_item(player: Player) -> void:
	if player != owner_player:
		return
	
	_unequip()
	
	if _is_owner_peer():
		WorldSync.send_equipment("unequip")


func direction_flip(direction: int) -> void:
	if direction == _last_direction:
		return
	
	_last_direction = direction
	_apply_flip(direction)
	
	# 0 — это «стою на месте», сторона не меняется, рассылать нечего
	if direction != 0 and _is_owner_peer():
		WorldSync.send_equipment("flip", direction)


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


# Приём у остальных: приходит от сервера (по изменению или снапшотом)

## Применить состояние чужого игрока: предмет, сторона взгляда, анимация.
func apply_equipment(_action: String, _value = null) -> void:
	match _action:
		"equip":
			_equip(_value)
		"unequip":
			_unequip()
		"flip":
			_last_direction = int(_value)
			_apply_flip(int(_value))
		"use":
			if current_item != null:
				current_item.try_to_use()


## Состояние из снапшота: новичок должен увидеть то же, что и все остальные.
func apply_state(_state: Dictionary) -> void:
	var key = _state.get("key", null)
	
	if key != null:
		_equip(key)
	
	var direction := int(_state.get("direction", 0))
	
	if direction != 0:
		_last_direction = direction
		_apply_flip(direction)
