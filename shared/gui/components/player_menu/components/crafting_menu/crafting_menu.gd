extends PlayerMenuBase

@export var crafting_slot_scene: PackedScene

@onready var info_craft: Label = %InfoCraft
@onready var crafting_button_container: GridContainer = %CraftingButtonContainer


func _ready() -> void:
	for item_key in BlueprintConfig.CRAFTABLE_ITEM_KEYS:
		var crafting_slot: CraftingSlot = crafting_slot_scene.instantiate()
		
		crafting_button_container.add_child(crafting_slot)
		crafting_slot._set_item_key(item_key)
		crafting_slot.button.mouse_entered.connect(on_show_item_info.bind(crafting_slot.item_key))
		crafting_slot.button.mouse_exited.connect(on_hide_item_info)
		crafting_slot.button.pressed.connect(on_button_pressed.bind(crafting_slot.item_key))
	
	super()


func on_show_item_info(item_key: ItemConfig.Keys) -> void:
	if item_key == null:
		return
	
	var info_item = ItemConfig.get_item_resource(item_key)
	var info_blueprint = BlueprintConfig.get_crafring_blueprint_resource(item_key)
	
	info_description.text = info_item.get_description()
	info_craft.text = info_blueprint.get_blueprint_info()


func on_hide_item_info() -> void:
	info_description.text = ''
	info_craft.text = ''


func on_button_pressed(item_key: ItemConfig.Keys) -> void:
	var blueprint = BlueprintConfig.get_crafring_blueprint_resource(item_key)
	
	EventSystem.INV_remove_items.emit(blueprint.get_all_keys())
	EventSystem.INV_add_item.emit(item_key)
	


func updated_inventory(inventory: Array) -> void:
	super(inventory)
	
	for crafting_slot in crafting_button_container.get_children():
		var slot: CraftingSlot = crafting_slot
		var item_key = slot.item_key
		
		if item_key == null:
			break
		
		var blueprint = BlueprintConfig.get_crafring_blueprint_resource(item_key)
		
		slot.button.disabled = blueprint.get_disabled_crafting(inventory)
	
		
