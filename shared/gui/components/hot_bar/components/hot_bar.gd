class_name HotBar extends PanelContainer

@onready var h_box_container: HBoxContainer = %HBoxContainer


func _enter_tree() -> void:
	EventSystem.INV_hotbar_updated.connect(on_hotbar_updated)
	EventSystem.EQU_active_hotbar_slot_updated.connect(on_active_hotbar_slot_updated)


func _ready() -> void:
	EventSystem.EQU_active_hotbar_slot_updated.emit(MatchState.local_player, null)


func on_hotbar_updated(player: Player, hotbar: Array) -> void:
	if not MatchState.is_local_event(player):
		return
	
	for slot in h_box_container.get_children():
		if slot is HotbarSlot:
			slot._set_item_key(hotbar[slot.get_index()])


func on_active_hotbar_slot_updated(player: Player, index) -> void:
	if not MatchState.is_local_event(player):
		return
	
	for slot in h_box_container.get_children():
		if slot is HotbarSlot:
			slot.set_highlighter(slot.get_index() == index)
