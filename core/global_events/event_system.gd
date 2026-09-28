extends Node

## Шина межсистемных сигналов.
##
## Игровые сигналы (PLA_*, INV_*, EQU_*) первым аргументом несут игрока-владельца:
## подписчик сравнивает его со своим игроком и игнорирует чужие события. Без этого
## при нескольких игроках событие одного срабатывает у всех.

signal BUL_create_bulletin()
signal BUL_destroy_bulletin()
signal BUL_update_bulletin()

signal UI_create(_ui_key: UIConfig.Keys)
signal UI_destroy(_ui_key: UIConfig.Keys)
signal UI_replace(_ui_key: UIConfig.Keys)
signal UI_last()
signal UI_check_count(_count_ui: int)

# inventory
signal INV_try_to_pickup_item(_player: Player, _item_key: ItemConfig.Keys, _callback: Callable)
signal INV_ask_update_inventory(_player: Player)
signal INV_inventory_updated(_player: Player, _inventory: Array)
signal INV_switch_two_item_indexes(
	_player: Player,
	_from_index: int,
	_from_is_hot_bar: bool,
	_to_index: int,
	_to_is_hot_bar: bool
)
signal INV_add_item(_player: Player, _item_key: ItemConfig.Keys)
signal INV_remove_items(_player: Player, _keys: Array[ItemConfig.Keys])
# hotbar
signal INV_hotbar_updated(_player: Player, _hotbar: Array)
signal INV_delete_item_by_index(_player: Player, _index: int, _is_in_hotbar: bool)

signal PLA_freeze_player(_player: Player)
signal PLA_unfreeze_player(_player: Player)
signal PLA_change_energy(_player: Player, _value: float)
signal PLA_updated_energy(_player: Player, _max_value: float, _current_value: float)
signal PLA_change_health(_player: Player, _value: float)
signal PLA_updated_health(_player: Player, _max_value: float, _current_value: float)
signal PLA_change_mana(_player: Player, _value: float)
signal PLA_updated_mana(_player: Player, _max_value: float, _current_value: float)

signal EQU_hotkey_pressed(_player: Player, _number_slot: int)
signal EQU_equip_item(_player: Player, _item_key: ItemConfig.Keys)
signal EQU_unequip_item(_player: Player)
signal EQU_active_hotbar_slot_updated(_player: Player, _index)
signal EQU_delete_equiped_item(_player: Player)

signal SPA_spawn_scene(scene: PackedScene, tform: Transform2D)
