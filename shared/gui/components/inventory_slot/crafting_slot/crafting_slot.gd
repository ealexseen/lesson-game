class_name CraftingSlot extends PanelContainer


@onready var icon_texture_rect: TextureRect = %IconTextureRect
@onready var button: Button = $Button

var item_key

func _set_item_key(_item_key) -> void:
	item_key = _item_key
	icon_texture_rect.texture = ItemConfig.get_item_resource(item_key).icon
