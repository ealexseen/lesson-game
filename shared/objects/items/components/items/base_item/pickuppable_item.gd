class_name PickuppableItem extends InteractablesItem

@export var item_key: ItemConfig.Keys

var pickup_active = false
var parent


func _ready() -> void:
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)
	
	parent = get_parent()


func start_interaction() -> void:
	EventSystem.INV_try_to_pickup_item.emit(item_key, destroy_self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed('active'):
		if pickup_active:
			start_interaction()


func destroy_self() -> void:
	if not parent:
		return
	
	parent.queue_free()


func set_pickup_active(value: bool) -> void:
	pickup_active = value
	
	var resource_item = ItemConfig.get_item_resource(item_key)
	
	if (pickup_active):
		set_prompt('Нажмите E')
	else:
		set_prompt(resource_item.display_name)
	
	


func on_body_entered(_body: Node2D) -> void:
	if _body is not Player: return
	
	set_pickup_active(true)


func on_body_exited(_body: Node2D) -> void:
	set_pickup_active(false)
