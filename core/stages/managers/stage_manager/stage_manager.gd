extends Node


func _ready() -> void:
	change_stage(StagesConfig.Keys.Level1)


func change_stage(key: StagesConfig.Keys) -> void:
	for child in get_children():
		child.queue_free()
	
	var new_state := StagesConfig.get_stage(key)
	add_child(new_state)
