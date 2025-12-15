class_name ActionBar extends MarginContainer

@onready var h_box_container: HBoxContainer = %HBoxContainer


func _enter_tree() -> void:
	EventSystem.INV_hotbar_updated.connect(on_hotbar_updated)
	EventSystem.EQU_active_hotbar_slot_updated.connect(on_active_hotbar_slot_updated)


func _ready() -> void:
	EventSystem.EQU_active_hotbar_slot_updated.emit(null)


func on_hotbar_updated(hotbar: Array) -> void:
	for slot in h_box_container.get_children():
		if slot is HotbarSlot:
			slot._set_item_key(hotbar[slot.get_index()])


func on_active_hotbar_slot_updated(index) -> void:
	for slot in h_box_container.get_children():
		if slot is HotbarSlot:
			slot.set_highlighter(slot.get_index() == index)
