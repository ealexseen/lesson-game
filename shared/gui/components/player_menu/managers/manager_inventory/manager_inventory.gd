extends Node


const INVENTORY_SIZE = 28
const HOTBAR_SIZE = 9

var inventory : Array = [
	ItemConfig.Keys.Coin,
	ItemConfig.Keys.Crystal,
	ItemConfig.Keys.Stick,
	ItemConfig.Keys.Stone,
]
var hotbar: Array = [
	ItemConfig.Keys.Axe
]


func _enter_tree() -> void:
	EventSystem.INV_try_to_pickup_item.connect(on_try_to_pickup_item)
	EventSystem.INV_ask_update_inventory.connect(sent_inventory)
	EventSystem.INV_switch_two_item_indexes.connect(_on_change_order)
	EventSystem.INV_add_item.connect(_on_add_item)
	EventSystem.INV_remove_items.connect(_on_remove_items)


func _ready() -> void:
	inventory.resize(INVENTORY_SIZE)
	hotbar.resize(HOTBAR_SIZE)
	
	EventSystem.INV_hotbar_updated.emit(hotbar)


func _on_change_order(
	_from_index: int, 
	_from_is_hot_bar: bool, 
	_to_index: int, 
	_to_is_hot_bar: bool
) -> void:
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
	
	EventSystem.INV_inventory_updated.emit(inventory)
	EventSystem.INV_hotbar_updated.emit(hotbar)


func sent_inventory() -> void:
	EventSystem.INV_inventory_updated.emit(inventory)


func on_try_to_pickup_item(item_key: ItemConfig.Keys, callback: Callable) -> void:
	if not get_free_slots(): return
	
	add_item(item_key)
	callback.call()


func _on_add_item(item_key: ItemConfig.Keys) -> void:
	if not get_free_slots(): return
	
	add_item(item_key)
	EventSystem.INV_inventory_updated.emit(inventory)


func _on_remove_items(keys: Array[ItemConfig.Keys]) -> void:
	for item_key in keys:
		remove_item(item_key)
	
	EventSystem.INV_inventory_updated.emit(inventory)


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
