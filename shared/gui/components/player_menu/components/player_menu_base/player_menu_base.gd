class_name PlayerMenuBase extends Bulletin

@onready var close_button: ButtonBase = %CloseButton
@onready var inventory_container: GridContainer = %InventoryContainer

# Info
@onready var info_description: Label = %InfoDescription


func _enter_tree() -> void:
	EventSystem.INV_inventory_updated.connect(updated_inventory)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	EventSystem.INV_ask_update_inventory.emit()
	close_button.pressed.connect(close)
	
	for slot in inventory_container.get_children():
		if slot is InventorySlot:
			slot.mouse_entered.connect(on_mouse_slot_entered.bind(slot))
			slot.mouse_exited.connect(on_mouse_slot_exited)
	
	for slot in get_tree().get_nodes_in_group('hotbar_slots'):
		if slot is HotbarSlot:
			slot.mouse_entered.connect(on_mouse_slot_entered.bind(slot))
			slot.mouse_exited.connect(on_mouse_slot_exited)


func on_mouse_slot_entered(slot: InventorySlot) -> void:
	if slot.item_key == null:
		return
	
	var info = ItemConfig.get_item_resource(slot.item_key)
	info_description.text = info.get_description()


func on_mouse_slot_exited() -> void:
	info_description.text = ''


func close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventSystem.UI_destroy.emit(UIConfig.Keys.CraftingMenu)


func updated_inventory(inventory: Array) -> void:
	for slot in inventory_container.get_children():
		if slot is InventorySlot:
			slot._set_item_key(inventory[slot.get_index()])
	
	# old logic
	
	#for i in inventory.size():
		#var item_key = inventory[i]
		#var inventory_slot = inventory_container.get_child(i)
		#
		#if inventory_slot is InventorySlot:
			#if item_key != null:
				#inventory_slot._set_item_key(item_key)
			#else:
				#inventory_slot._set_item_key(null)
		
