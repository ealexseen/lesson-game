extends Node

var bulletins: Dictionary[BulletinConfig.Keys, Bulletin] = {}


func _enter_tree() -> void:
	EventSystem.BUL_create_bulletin.connect(_on_create_bulletin)
	EventSystem.BUL_destroy_bulletin.connect(_on_destroy_bulletin)
	EventSystem.BUL_update_bulletin.connect(_on_update_bulletin)


func _on_update_bulletin(key: BulletinConfig.Keys, collider: Node2D) -> void:
	_on_destroy_bulletin(key)
	_on_create_bulletin(key, collider)


func _on_create_bulletin(key: BulletinConfig.Keys, collider: Node2D) -> void:
	var prompt = ''
	var position = Vector2.ZERO
	
	if bulletins.has(key):
		return
	
	prompt = collider.prompt
	position = collider.point_prompt.global_position
		
	if not prompt: return
	
	var new_bulletin := BulletinConfig.get_bulletin(key)
	new_bulletin.initialize(prompt)
	new_bulletin.global_position = position
	
	add_child(new_bulletin)
	bulletins[key] = new_bulletin
	

func _on_destroy_bulletin(key: BulletinConfig.Keys) -> void:
	if not bulletins.has(key):
		return
	
	bulletins[key].queue_free()
	bulletins.erase(key)
