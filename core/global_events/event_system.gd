extends Node

signal BUL_create_bulletin()
signal BUL_destroy_bulletin()
signal BUL_update_bulletin()

signal UI_create(_ui_key: UIConfig.Keys)
signal UI_destroy(_ui_key: UIConfig.Keys)
signal UI_replace(_ui_key: UIConfig.Keys)
signal UI_last()
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
signal INV_delete_item_by_index()

signal PLA_freeze_player()
signal PLA_unfreeze_player()
signal PLA_change_energy(value: float)
signal PLA_updated_energy(max_value: float, current_value: float)
signal PLA_change_health(value: float)
signal PLA_updated_health(max_value: float, current_value: float)
signal PLA_change_mana(value: float)
signal PLA_updated_mana(max_value: float, current_value: float)

signal EQU_hotkey_pressed(number_slot: int)
signal EQU_equip_item(item_key: ItemConfig.Keys)
signal EQU_unequip_item()
signal EQU_active_hotbar_slot_updated(index)
signal EQU_delete_equiped_item()

signal SPA_spawn_scene(scene: PackedScene, tform: Transform2D)
