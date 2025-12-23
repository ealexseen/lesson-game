class_name ManagerUI extends Node

var items: Dictionary[UIConfig.Keys, Control] = {}
var last_item


func _enter_tree() -> void:
	EventSystem.UI_create.connect(_on_create_ui)
	EventSystem.UI_destroy.connect(_on_destroy_ui)
	EventSystem.UI_replace.connect(_on_replace_ui)
	EventSystem.UI_last.connect(_on_last)


func _on_last() -> void:
	if not last_item:
		destroy_all()
		return
	
	_on_replace_ui(last_item)


func _on_replace_ui(_key: UIConfig.Keys) -> void:
	for key in items.keys():
		items[key].queue_free()
		items.erase(key)
		last_item = key
	
	add_ui(_key)


func add_ui(_key: UIConfig.Keys) -> void:
	var item := UIConfig.get_ui(_key)
	
	add_child(item)
	items[_key] = item


func destroy_all() -> void:
	for key in items.keys():
		items[key].queue_free()
		items.erase(key)


func _on_create_ui(key: UIConfig.Keys) -> void:
	if items.has(key): return
	if items.size(): return
	
	EventSystem.PLA_freeze_player.emit()
	
	add_ui(key)
	
	EventSystem.UI_check_count.emit(items.size())


func _on_destroy_ui(key: BulletinConfig.Keys) -> void:
	if not items.has(key): return
	
	items[key].queue_free()
	items.erase(key)
	last_item = key
	 
	if not items.size():
		EventSystem.PLA_unfreeze_player.emit()
	
	EventSystem.UI_check_count.emit(items.size())
