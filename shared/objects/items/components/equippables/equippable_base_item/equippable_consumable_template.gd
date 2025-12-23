class_name EquippableConsumableTemplate extends EquippableItemTemplate

var consumable_item_resource: ConsumableItemResource


func consume() -> void:
	EventSystem.PLA_change_health.emit(consumable_item_resource.health_change)
	EventSystem.PLA_change_energy.emit(consumable_item_resource.enegry_change)
	EventSystem.PLA_change_mana.emit(consumable_item_resource.mana_change)
	EventSystem.EQU_delete_equiped_item.emit()


func destroy_self() -> void:
	EventSystem.EQU_unequip_item.emit()
