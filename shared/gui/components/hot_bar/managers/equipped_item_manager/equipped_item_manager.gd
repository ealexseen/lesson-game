extends Node


var active_hotbar_slot
var hotbar: Array = []

func _enter_tree() -> void:
	EventSystem.INV_hotbar_updated.connect(on_hotbar_updated)
	EventSystem.EQU_hotkey_pressed.connect(on_hotkey_pressed)


func on_hotbar_updated(_hotbar: Array) -> void:
	hotbar = _hotbar
	
	if active_hotbar_slot == null:
		return
	if hotbar[active_hotbar_slot] == null:
		active_hotbar_slot = null
		EventSystem.EQU_unequip_item.emit()
		EventSystem.EQU_active_hotbar_slot_updated.emit(null)


func on_hotkey_pressed(key_input: int) -> void:
	var index = key_input - 1
	
	if hotbar[index] == null:
		return
	
	if active_hotbar_slot != index:
		active_hotbar_slot = index
		EventSystem.EQU_equip_item.emit(hotbar[index])
		EventSystem.EQU_active_hotbar_slot_updated.emit(index)
	else:
		active_hotbar_slot = null
		EventSystem.EQU_unequip_item.emit()
		EventSystem.EQU_active_hotbar_slot_updated.emit(null)
	
