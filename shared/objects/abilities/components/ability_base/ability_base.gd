class_name AbilityBase
extends Node

@export_category("Ability Settings")
@export var ability_name: String = "Unnamed Ability"
@export var item_key: AbilityConfig.Keys
@export var cooldown: float = 1.0 # остывать таймер

@export_category("Input")
@export var input_action: String = ""

var is_active: bool = false
var is_on_cooldown: bool = false
var player: Player


func _ready() -> void:
	player = get_parent() as Player
	assert(player != null, "Ability must be a child of Player") # Способность должна быть потомком игрока


func start_interaction() -> void:
	pass


# Вызывается когда способность активируется
func activate():
	if is_on_cooldown:
		return false
	
	is_active = true
	start_cooldown()
	return true

# Вызывается когда способность деактивируется
func deactivate():
	is_active = false

# Логика способности (переопределяется в дочерних классах)
func process_ability(_delta: float):
	pass

# Логика физики (переопределяется в дочерних классах)
func physics_process_ability(_delta: float):
	pass

# Начало перезарядки
func start_cooldown():
	is_on_cooldown = true
	await get_tree().create_timer(cooldown).timeout
	is_on_cooldown = false
