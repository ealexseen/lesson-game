class_name EquippableItemHolder extends Node2D


var current_item: EquippableWeaponeTemplate
var save_position

func _enter_tree() -> void:
	EventSystem.EQU_equip_item.connect(on_equip_item)
	EventSystem.EQU_unequip_item.connect(on_unequip_item)


func _ready() -> void:
	save_position = position


func try_to_use_item() -> void:
	if current_item == null:
		return
	
	current_item.try_to_use()


func on_equip_item(item_key) -> void:
	on_unequip_item()
	
	if not item_key:
		return
	
	var equippable_item: PackedScene = ItemConfig.get_equippable_item(item_key)
	
	if not equippable_item:
		return
	
	current_item = equippable_item.instantiate()
	
	if current_item is EquippableWeaponeTemplate:
		var resource = ItemConfig.get_item_resource(item_key)

		current_item.weapon_item_resource = resource
	
	add_child(current_item)


func on_unequip_item() -> void:
	if not current_item:
		return
	
	current_item.queue_free()


func direction_flip(direction: int) -> void:
	if direction != 0:
		if direction > 0:
			scale.x = abs(scale.x)
			position = save_position
		elif direction < 0:
			scale.x = -abs(scale.x)
			position = Vector2(
				-save_position.x, 
				save_position.y
			)
