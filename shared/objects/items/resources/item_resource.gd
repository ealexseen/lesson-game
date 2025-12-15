class_name ItemResource extends Resource

@export var item_key: ItemConfig.Keys
@export var display_name := 'item name'
@export var icon: Texture2D
@export_multiline var description := ''
@export var is_equippable := false # оснащаемый

func get_description() -> String:
	return "%s \n %s" % [
		display_name,
		description
	]
