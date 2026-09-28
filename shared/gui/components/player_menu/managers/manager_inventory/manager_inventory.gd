extends Node


const INVENTORY_SIZE = 28
const HOTBAR_SIZE = 9

var owner_player: Player

var inventory : Array = [
	ItemConfig.Keys.Coin,
	ItemConfig.Keys.Crystal,
	ItemConfig.Keys.Stick,
	ItemConfig.Keys.Stone,
]
var hotbar: Array = [
	ItemConfig.Keys.Axe,
	ItemConfig.Keys.Pickaxe,
]


func _enter_tree() -> void:
	owner_player = MatchState.find_owner_player(self)
	
	EventSystem.INV_try_to_pickup_item.connect(_on_try_to_pickup_item)
	EventSystem.INV_ask_update_inventory.connect(_on_sent_inventory)
	EventSystem.INV_switch_two_item_indexes.connect(_on_change_order)
	EventSystem.INV_add_item.connect(_on_add_item)
	EventSystem.INV_remove_items.connect(_on_remove_items)
	EventSystem.INV_delete_item_by_index.connect(_on_delete_item_by_index)


func _ready() -> void:
	inventory.resize(INVENTORY_SIZE)
	hotbar.resize(HOTBAR_SIZE)
	
	EventSystem.INV_hotbar_updated.emit(owner_player, hotbar)


func _on_delete_item_by_index(player: Player, index: int, is_in_hotbar: bool) -> void:
	if player != owner_player:
		return
	
	if is_in_hotbar:
		hotbar[index] = null
		EventSystem.INV_hotbar_updated.emit(owner_player, hotbar)
	else:
		inventory[index] = null
		EventSystem.INV_inventory_updated.emit(owner_player, inventory)


func _on_change_order(
	player: Player,
	_from_index: int, 
	_from_is_hot_bar: bool, 
	_to_index: int, 
	_to_is_hot_bar: bool
) -> void:
	if player != owner_player:
		return
	
	var _item_from_key = inventory[_from_index] if not _from_is_hot_bar else hotbar[_from_index]
	var _item_to_key = inventory[_to_index] if not _to_is_hot_bar else hotbar[_to_index]
	
	if not _from_is_hot_bar:
		inventory[_from_index] = _item_to_key
	else:
		hotbar[_from_index] = _item_to_key
	
	
	if not _to_is_hot_bar:
		inventory[_to_index] = _item_from_key
	else:
		hotbar[_to_index] = _item_from_key
	
	EventSystem.INV_inventory_updated.emit(owner_player, inventory)
	EventSystem.INV_hotbar_updated.emit(owner_player, hotbar)


func _on_sent_inventory(player: Player) -> void:
	if player != owner_player:
		return
	
	EventSystem.INV_inventory_updated.emit(owner_player, inventory)


## Подбор решает сервер: предмет достанется первому, остальным придёт отмена.
func _on_try_to_pickup_item(player: Player, item_key: ItemConfig.Keys, item: Node) -> void:
	if player != owner_player:
		return
	
	if not get_free_slots(): return
	
	WorldSync.request_pickup(item, player, item_key)


func _on_add_item(player: Player, item_key: ItemConfig.Keys) -> void:
	if player != owner_player:
		return
	
	if not get_free_slots(): return
	
	add_item(item_key)
	EventSystem.INV_inventory_updated.emit(owner_player, inventory)


func _on_remove_items(player: Player, keys: Array[ItemConfig.Keys]) -> void:
	if player != owner_player:
		return
	
	for item_key in keys:
		remove_item(item_key)
	
	EventSystem.INV_inventory_updated.emit(owner_player, inventory)


func get_free_slots() -> int:
	return inventory.count(null)


func add_item(item_key: ItemConfig.Keys) -> void:
	for i in inventory.size():
		if inventory[i] == null:
			inventory[i] = item_key
			return


func remove_item(item_key: ItemConfig.Keys) -> void:
	if not inventory.has(item_key):
		return
	
	inventory[inventory.rfind(item_key)] = null
