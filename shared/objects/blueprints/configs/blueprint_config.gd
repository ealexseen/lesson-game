class_name BlueprintConfig extends Node


const CRAFTABLE_ITEM_KEYS: Array[ItemConfig.Keys] = [
	ItemConfig.Keys.Axe, # топор
	#Keys.Pickaxe, # Кирка
	#Keys.Campfire, # Костер
	#Keys.Multitool, # Инструмент
	ItemConfig.Keys.Rope, # Веревка
	#Keys.Tinderbox, # Трутница
	#Keys.Torch, # Факел
	#Keys.Tent, # Палатка
	#Keys.Raft, # Плот
]


const CRAFTING_BLUEPRINT_RESOURCE_PATSH := {
   ItemConfig.Keys.Axe: "res://shared/objects/blueprints/resources/axe_blueprint.tres",
   ItemConfig.Keys.Rope: "res://shared/objects/blueprints/resources/rope_blueprint.tres"
}

static func get_crafring_blueprint_resource(key: ItemConfig.Keys) -> CraftingBlueprintResource:
	return load(CRAFTING_BLUEPRINT_RESOURCE_PATSH.get(key))
