class_name CursorGame extends Area2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
	global_position = get_global_mouse_position()


func _on_area_entered(collider: Area2D) -> void:
	if collider is not InteractablesDoor and collider is not InteractablesItem: return
	
	EventSystem.BUL_create_bulletin.emit(BulletinConfig.Keys.InteractionPrompt, collider)


func _on_area_exited(_area: Area2D) -> void:
	EventSystem.BUL_destroy_bulletin.emit(BulletinConfig.Keys.InteractionPrompt)


func check_hit() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF
	query.from = global_position
	query.to = global_position + Vector2(20, 20)
	
	var result := space_state.intersect_ray(query)
