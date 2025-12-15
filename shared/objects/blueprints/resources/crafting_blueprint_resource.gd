class_name CraftingBlueprintResource extends Resource


@export var item_key := ItemConfig.Keys.Axe
@export var costs: Array[BlueprintCostData] = []
@export var needs_multitool := false # что можно использовать в игре как оружие и дт
@export var needs_tinderbox := false # предмет который можно использовать как расходник


func get_all_keys() -> Array[ItemConfig.Keys]:
	var keys: Array[ItemConfig.Keys] = []
	
	for cost in costs:
		for _i in cost.amount:
			keys.append(cost.item_key)
	
	return keys


func get_disabled_crafting(inventory: Array) -> bool:
	var is_disabled = false
	
	for cost in costs:
		var count_inventory_items_by_key = inventory.count(cost.item_key)
		var count_blue_print_items_count = cost.amount
		
		if count_inventory_items_by_key < count_blue_print_items_count:
			is_disabled = true
			break
	
	return is_disabled


func get_blueprint_info() -> String:
	var name := 'Крафт:'
	
	if needs_multitool:
		name += '\n- Инструмент'
	
	if needs_tinderbox:
		name += '\n- Расходник'
	
	for cost in costs:
		if cost.item_key == null:
			break
		
		var info = ItemConfig.get_item_resource(cost.item_key)
		
		if not info:
			break
		
		name += "\n%s = %d" % [
			info.display_name,
			cost.amount
		]
	
	return name
