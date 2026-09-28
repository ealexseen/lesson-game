extends CharacterBody2D
class_name Player

@export var speed: float = 500.0 # speed
@export var jump_velocity: float = -400.0 # скорость прыжка
@export var friction: float = 0.15 # трение
@export var acceleration: float = 0.1 # ускорение
@export var bullet_schene: PackedScene
@export var walking_energy_change_per_1m := -0.005 # walking - потребление
@export var spawn: Marker2D

const REMOTE_SMOOTH_SPEED := 15.0 # плавность чужого игрока
const REMOTE_TELEPORT_DISTANCE := 300.0 # скачок сетевой цели — это телепорт

@onready var equippable_item_holder: EquippableItemHolder = %EquippableItemHolder
@onready var camera: Camera2D = $Camera2D
@onready var net_target: Node2D = $NetTarget
@onready var nameplate: Label = $Nameplate

var peer_id: int = MatchState.OFFLINE_PEER_ID
var save_equippable_item_holder_position = Vector2.ZERO

var abilities: Dictionary = {}
var can_shoot: bool = true

# Получаем гравитацию из проекта
var gravity: float = ProjectSettings.get_setting('physics/2d/default_gravity')


func _enter_tree() -> void:
	# peer_id выставляет спавнер до добавления в дерево
	MatchState.register_player(self, peer_id)
	EventSystem.PLA_freeze_player.connect(_on_freeze_player)
	EventSystem.PLA_unfreeze_player.connect(_on_unfreeze_player)


func _exit_tree() -> void:
	MatchState.unregister_player(self)


func _ready() -> void:
	save_equippable_item_holder_position = equippable_item_holder.position
	camera.enabled = is_local()
	# цель стартует на месте появления, иначе чужой игрок поедет к нулю
	net_target.position = position
	_setup_nameplate()


## Ник и цвет показываем только у чужих игроков: своя табличка перед глазами мешает.
func _setup_nameplate() -> void:
	if is_local() or not MatchState.participants.has(peer_id):
		nameplate.visible = false
		return
	
	nameplate.text = MatchState.participant_name(peer_id)
	nameplate.add_theme_color_override("font_color", MatchState.participant_color(peer_id))
	nameplate.visible = true


## Локальный игрок — тот, чьим вводом управляет этот клиент.
func is_local() -> bool:
	return MatchState.local_player == self


func _process(_delta: float) -> void:
	if is_local():
		return
	
	# чужой игрок плавно едет за сетевой целью: своей физикой он не управляет
	if position.distance_to(net_target.position) > REMOTE_TELEPORT_DISTANCE:
		position = net_target.position
	else:
		position = position.lerp(
			net_target.position,
			clampf(_delta * REMOTE_SMOOTH_SPEED, 0.0, 1.0)
		)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_local():
		return
	
	if event.is_action_pressed("open_crafting_menu"):
		EventSystem.UI_create.emit(UIConfig.Keys.CraftingMenu)
	elif event.is_action_pressed("esc"):	
		EventSystem.UI_create.emit(UIConfig.Keys.MenuGame)
	elif event.is_action_pressed("input_hot_key"):
		EventSystem.EQU_hotkey_pressed.emit(self, int(event.as_text()))


func _physics_process(_delta: float) -> void:
	if not is_local():
		return
	
	move(_delta)
	check_walking_energy_change(_delta)
	save_player()
	
	# это значение уходит по сети остальным
	net_target.position = position
	
	if Input.is_action_pressed("use_item"):
		equippable_item_holder.try_to_use_item()


func check_walking_energy_change(_delta: float) -> void:
	if velocity.x:
		EventSystem.PLA_change_energy.emit(
			self,
			_delta *
			walking_energy_change_per_1m *
			Vector2(velocity.x, 0).length()
		)


func save_player() -> void:
	if position.y >= 2500 and spawn:
		position = spawn.position


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


func _on_freeze_player(_player: Player) -> void:
	if _player != self:
		return
	
	set_freeze(true)


func _on_unfreeze_player(_player: Player) -> void:
	if _player != self:
		return
	
	set_freeze(false)


func set_freeze(_value: bool) -> void:
	set_process(!_value)
	set_physics_process(!_value)
	set_process_input(!_value)
	set_process_unhandled_input(!_value)
