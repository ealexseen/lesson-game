extends Node

@export var player: Player
@export var available_abilities: Array[PackedScene] = []

var equipped_abilities: Dictionary = {}

func _ready():
	# Загружаем начальные способности
	for ability_scene in available_abilities:
		add_ability(ability_scene)

func add_ability(ability_scene: PackedScene):
	var ability_instance = ability_scene.instantiate()
	player.add_child(ability_instance)
	equipped_abilities[ability_instance.ability_name] = ability_instance

func remove_ability(ability_name: String):
	if equipped_abilities.has(ability_name):
		equipped_abilities[ability_name].queue_free()
		equipped_abilities.erase(ability_name)

func has_ability(ability_name: String) -> bool:
	return equipped_abilities.has(ability_name)

func get_ability(ability_name: String) -> AbilityBase:
	return equipped_abilities.get(ability_name)

# Сохранение/загрузка способностей
func save_abilities() -> Dictionary:
	var save_data = {}
	for ability in equipped_abilities:
		save_data[ability.ability_name] = {
			"cooldown": ability.cooldown,
			"enabled": ability.enabled
		}
	return save_data

func load_abilities(save_data: Dictionary):
	for data in save_data:
		var ability_name = data.ability_name
		
		if equipped_abilities.has(ability_name):
			equipped_abilities[ability_name].cooldown = data["cooldown"]
			equipped_abilities[ability_name].enabled = data["enabled"]
