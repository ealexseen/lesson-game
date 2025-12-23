class_name BaseItem extends PickuppableItem

@onready var point_prompt: Marker2D = %PointPrompt
@onready var texture_rect: TextureRect = %TextureRect

func _ready() -> void:
	super()
	
	var item_resource = ItemConfig.get_item_resource(item_key)
	
	texture_rect.texture = item_resource.icon
	set_prompt(item_resource.display_name)
