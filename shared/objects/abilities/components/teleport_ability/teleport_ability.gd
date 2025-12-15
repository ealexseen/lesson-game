extends AbilityBase
class_name TeleportAbility

@export var teleport_distance: float = 200.0

func activate() -> bool:
	if not super():
		return false
	
	var direction = player.get_input_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(player.rotation)
	
	# Создаем эффект телепортации
	create_teleport_effect()
	
	# Телепортируем
	player.global_position += direction * teleport_distance
	
	# Создаем эффект появления
	create_appear_effect()
	
	return true

func create_teleport_effect():
	#var effect = preload("res://Effects/TeleportOut.tscn").instantiate()
	#player.get_parent().add_child(effect)
	#effect.global_position = player.global_position
	pass

func create_appear_effect():
	#var effect = preload("res://Effects/TeleportIn.tscn").instantiate()
	#player.get_parent().add_child(effect)
	#effect.global_position = player.global_position
	pass
