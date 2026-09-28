extends Node


var owner_player: Player
var active_hotbar_slot
var hotbar: Array = []

func _enter_tree() -> void:
	owner_player = MatchState.find_owner_player(self)
	
	EventSystem.INV_hotbar_updated.connect(on_hotbar_updated)
	EventSystem.EQU_hotkey_pressed.connect(on_hotkey_pressed)
	EventSystem.EQU_delete_equiped_item.connect(on_delete_equiped_item)


func on_delete_equiped_item(player: Player) -> void:
	if player != owner_player:
		return
	
	EventSystem.INV_delete_item_by_index.emit(owner_player, active_hotbar_slot, true)
	EventSystem.EQU_active_hotbar_slot_updated.emit(owner_player, null)
	active_hotbar_slot = null

func on_hotbar_updated(player: Player, _hotbar: Array) -> void:
	if player != owner_player:
		return
	
	hotbar = _hotbar
	
	if active_hotbar_slot == null:
		return
	if hotbar[active_hotbar_slot] == null:
		active_hotbar_slot = null
		EventSystem.EQU_unequip_item.emit(owner_player)
		EventSystem.EQU_active_hotbar_slot_updated.emit(owner_player, null)


func on_hotkey_pressed(player: Player, key_input: int) -> void:
	if player != owner_player:
		return
	
	var index = key_input - 1
	
	if hotbar[index] == null:
		return
	
	if active_hotbar_slot != index:
		active_hotbar_slot = index
		EventSystem.EQU_equip_item.emit(owner_player, hotbar[index])
		EventSystem.EQU_active_hotbar_slot_updated.emit(owner_player, index)
	else:
		active_hotbar_slot = null
		EventSystem.EQU_unequip_item.emit(owner_player)
		EventSystem.EQU_active_hotbar_slot_updated.emit(owner_player, null)
	
