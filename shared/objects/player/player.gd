extends CharacterBody2D
class_name Player

@export var speed: float = 500.0 # speed
@export var jump_velocity: float = -400.0 # скорость прыжка
@export var friction: float = 0.15 # трение
@export var acceleration: float = 0.1 # ускорение
@export var bullet_schene: PackedScene

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
	
	for child in get_children():
		if child is AbilityBase:
			abilities[child.ability_name] = child
			print("Loaded ability: ", child.ability_name)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_crafting_menu"):
		EventSystem.UI_create.emit(UIConfig.Keys.CraftingMenu)
	elif event.is_action_pressed("game_menu"):
		EventSystem.UI_create.emit(UIConfig.Keys.MenuGame)
	elif event.is_action_pressed("input_hot_key"):
		EventSystem.EQU_hotkey_pressed.emit(int(event.as_text()))


func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("use_item"):
		equippable_item_holder.try_to_use_item()
	
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

	#handle_abilities_input()
	#process_abilities(_delta)
	move_and_slide()


func handle_abilities_input():
	for ability in abilities.values():
		if ability.input_action != "" and Input.is_action_just_pressed(ability.input_action):
			ability.activate()


func process_abilities(delta: float):
	for ability in abilities.values():
		ability.physics_process_ability(delta)


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


# API для способностей
func get_input_direction() -> Vector2:
	return Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("ui_up", "ui_down")
	)

func get_player_velocity() -> Vector2:
	return velocity

func set_player_velocity(new_velocity: Vector2):
	velocity = new_velocity

func get_player_position() -> Vector2:
	return global_position

func set_player_position(new_position: Vector2):
	global_position = new_position
