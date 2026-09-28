class_name EquippableConsumableTemplate extends EquippableItemTemplate

var owner_player: Player
var consumable_item_resource: ConsumableItemResource


func _ready() -> void:
	owner_player = MatchState.find_owner_player(self)


func consume() -> void:
	EventSystem.PLA_change_health.emit(owner_player, consumable_item_resource.health_change)
	EventSystem.PLA_change_energy.emit(owner_player, consumable_item_resource.enegry_change)
	EventSystem.PLA_change_mana.emit(owner_player, consumable_item_resource.mana_change)
	EventSystem.EQU_delete_equiped_item.emit(owner_player)


func destroy_self() -> void:
	EventSystem.EQU_unequip_item.emit(owner_player)
