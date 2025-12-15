extends Node

signal BUL_create_bulletin()
signal BUL_destroy_bulletin()
signal BUL_update_bulletin()

signal UI_create(_ui_key: UIConfig.Keys)
signal UI_destroy(_ui_key: UIConfig.Keys)
signal UI_check_count(_count_ui: int)

# inventory
signal INV_try_to_pickup_item()
signal INV_ask_update_inventory()
signal INV_inventory_updated()
signal INV_switch_two_item_indexes()
signal INV_add_item()
signal INV_remove_items()
# hotbar
signal INV_hotbar_updated()

signal PLA_freeze_player()
signal PLA_unfreeze_player()

signal EQU_hotkey_pressed(number_slot: int)
signal EQU_equip_item(item_key: ItemConfig.Keys)
signal EQU_unequip_item()
signal EQU_active_hotbar_slot_updated(index)
