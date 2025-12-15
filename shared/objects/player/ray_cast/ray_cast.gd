class_name RayCast2DPlayer extends RayCast2D

@export var rotation_speed: float = 10.0
var is_hitting := false

func check_interaction() -> void:
	if is_colliding():
		var collider := get_collider()
		
		if collider is CursorGame: return
		if collider is not InteractablesDoor: return
		
		if not is_hitting:
			is_hitting = true
		
			EventSystem.BUL_create_bulletin.emit(BulletinConfig.Keys.InteractionPrompt, collider)
	elif is_hitting:
		is_hitting = false
		EventSystem.BUL_destroy_bulletin.emit(BulletinConfig.Keys.InteractionPrompt)
		



func _process(_delta: float) -> void:
	var mouse_position = get_global_mouse_position()
	var mouse_direction = (mouse_position - global_position).normalized()
	var target_rotation = mouse_direction.angle() - deg_to_rad(90)
	
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * _delta)
