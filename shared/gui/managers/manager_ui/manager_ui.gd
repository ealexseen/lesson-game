extends Node

var items: Dictionary[UIConfig.Keys, Control] = {}


func _enter_tree() -> void:
	EventSystem.UI_create.connect(_on_create_ui)
	EventSystem.UI_destroy.connect(_on_destroy_ui)


func _on_create_ui(key: UIConfig.Keys) -> void:
	if items.has(key): return
	if items.size(): return
	
	EventSystem.PLA_freeze_player.emit()
	
	var item := UIConfig.get_ui(key)
	
	add_child(item)
	items[key] = item
	
	EventSystem.UI_check_count.emit(items.size())


func _on_destroy_ui(key: BulletinConfig.Keys) -> void:
	if not items.has(key): return
	
	items[key].queue_free()
	items.erase(key)
	 
	if not items.size():
		EventSystem.PLA_unfreeze_player.emit()
	
	EventSystem.UI_check_count.emit(items.size())
