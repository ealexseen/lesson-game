extends CharacterBody2D
class_name Player

@export var speed: float = 500.0 # speed
@export var jump_velocity: float = -400.0 # скорость прыжка
@export var friction: float = 0.15 # трение
@export var acceleration: float = 0.1 # ускорение
@export var bullet_schene: PackedScene
@export var walking_energy_change_per_1m := -0.005 # walking - потребление

@onready var equippable_item_holder: EquippableItemHolder = %EquippableItemHolder

var save_equippable_item_holder_position = Vector2.ZERO

var abilities: Dictionary = {}
var can_shoot: bool = true

# Получаем гравитацию из проекта
var gravity: float = ProjectSettings.get_setting('physics/2d/default_gravity')


func _enter_tree() -> void:
	EventSystem.PLA_freeze_player.connect(set_freeze.bind(true))
	EventSystem.PLA_unfreeze_player.connect(set_freeze.bind(false))


func _ready() -> void:
	save_equippable_item_holder_position = equippable_item_holder.position


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_crafting_menu"):
		EventSystem.UI_create.emit(UIConfig.Keys.CraftingMenu)
	elif event.is_action_pressed("esc"):	
		EventSystem.UI_create.emit(UIConfig.Keys.MenuGame)
	elif event.is_action_pressed("input_hot_key"):
		EventSystem.EQU_hotkey_pressed.emit(int(event.as_text()))


func _physics_process(_delta: float) -> void:
	move(_delta)
	check_walking_energy_change(_delta)
	
	if Input.is_action_pressed("use_item"):
		equippable_item_holder.try_to_use_item()


func check_walking_energy_change(_delta: float) -> void:
	if velocity.x:
		EventSystem.PLA_change_energy.emit(
			_delta *
			walking_energy_change_per_1m *
			Vector2(velocity.x, 0).length()
		)

func move(_delta: float) -> void:
	# Применяем гравитацию
	if not is_on_floor():
		velocity.y += gravity * _delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	var direction = Input.get_axis("left", "right")
	
	if direction != 0:
		velocity.x = lerp(velocity.x, direction * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction)
	
	equippable_item_holder.direction_flip(direction)

	move_and_slide()


func shoot() -> void:
	if bullet_schene == null:
		return 
	
	can_shoot = false
	
	var bullet: Bullet = bullet_schene.instantiate()
	get_parent().add_child(bullet)
	
	bullet.global_position = global_position
	
	var mouse_direction = (get_global_mouse_position() - global_position).normalized()
	
	bullet._move(mouse_direction)
	
	await get_tree().create_timer(0.3).timeout
	
	can_shoot = true


func set_freeze(_value: bool) -> void:
	set_process(!_value)
	set_physics_process(!_value)
	set_process_input(!_value)
	set_process_unhandled_input(!_value)
