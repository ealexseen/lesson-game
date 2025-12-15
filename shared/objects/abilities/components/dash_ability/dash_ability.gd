extends AbilityBase
class_name DashAbility

@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.2

var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0


func activate() -> bool:
	if not super():
		return false
	
	dash_direction = player.get_input_direction()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT.rotated(player.rotation)
	
	dash_timer = 0.0
	player.set_collision_mask_value(1, false) # Отключаем столкновения
	
	return true


func physics_process_ability(delta: float):
	if not is_active:
		return
	
	dash_timer += delta
	player.velocity = dash_direction * dash_speed
	
	if dash_timer >= dash_duration:
		deactivate()

func deactivate():
	super()
	player.velocity = Vector2.ZERO
	player.set_collision_mask_value(1, true) # Включаем столкновения
