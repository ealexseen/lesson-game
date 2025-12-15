class_name InventorySlot extends PanelContainer

@onready var icon_texture_rect: TextureRect = %IconTextureRect

var item_key


func _set_item_key(_item_key) -> void:
	item_key = _item_key
	update_icon()


func update_icon() -> void:
	if item_key == null:
		icon_texture_rect.texture = null
		return
	
	icon_texture_rect.texture = ItemConfig.get_item_resource(item_key).icon


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_key != null:
		var drag_preview: PreviewSlot = load("res://shared/gui/components/inventory_slot/preview_slot/preview_slot.tscn").instantiate()
		drag_preview.set_texture(icon_texture_rect.texture)
		var c = Control.new()
		c.add_child(drag_preview)
		
		drag_preview.position = Vector2.ZERO - _at_position
		
		set_drag_preview(c)
		
		return self
	
	return null


func _can_drop_data(_at_position: Vector2, origin_slot: Variant) -> bool:
	return origin_slot is InventorySlot


func _drop_data(_at_position: Vector2, origin_slot: Variant) -> void:
	if origin_slot is InventorySlot:
		var from_index = origin_slot.get_index()
		var from_is_hot_bar = origin_slot is HotbarSlot
		var to_index = self.get_index()
		var to_is_hot_bar = self is HotbarSlot
		
		EventSystem.INV_switch_two_item_indexes.emit(
			from_index,
			from_is_hot_bar,
			to_index, 
			to_is_hot_bar
		)
