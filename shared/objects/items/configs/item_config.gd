class_name ItemConfig extends Node

enum Keys {
	# pickapables
	Plant = 0, # Растение
	Coin = 1, # Манетка
	Stick = 2, # Палка
	Stone = 3, # Камень
	Crystal = 4, # Кристал
	Mushroom = 5, # гриб
	Fruit = 6, # фрукт
	Log = 7, # Бревно
	Coal = 8, # уголь
	Flintstone = 9, # Кремний
	RawMeat = 10, # Сырое мясо
	CookedMeat = 11, # Сырое мясо
	
	# craftables
	Axe = 12, # топор
	Pickaxe = 13, # Кирка
	Campfire = 14, # Костер
	Multitool = 15, # Инструмент
	Rope = 16, # Веревка
	Tinderbox = 17, # Трутница
	Torch = 18, # Факел
	Tent = 19, # Палатка
	Raft = 20, # Плот
}


const ITEM_RESOURCE_PATHS := {
	Keys.Plant: "res://shared/objects/items/resources/plant_item_resource.tres",
	Keys.Coin: "res://shared/objects/items/resources/coin_item_resource.tres",
	Keys.Stick: "res://shared/objects/items/resources/stick_item_resource.tres",
	Keys.Stone: "res://shared/objects/items/resources/stone_item_resource.tres",
	Keys.Crystal: "res://shared/objects/items/resources/crystal_item_resource.tres",
	Keys.Rope: "res://shared/objects/items/resources/rope_item_resource.tres",
	Keys.Axe: "res://shared/objects/items/resources/axe_item_resource.tres",
}


static func get_item_resource(key: Keys) -> ItemResource:
	return load(ITEM_RESOURCE_PATHS.get(key))


const EQUIPPABLE_ITEM_PATSH := {
	Keys.Axe: "res://shared/objects/items/components/weapone/weapone_axe/weapone_axe.tscn"
}

static func get_equippable_item(key: Keys) -> PackedScene:
	return load(EQUIPPABLE_ITEM_PATSH.get(key))
