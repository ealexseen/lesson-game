extends Node2D


@onready var items: Node2D = $Items


func _enter_tree() -> void:
	EventSystem.SPA_spawn_scene.connect(on_spawn_scene)


func on_spawn_scene(scene: PackedScene, tform: Transform2D) -> void:
	var object: Node2D = scene.instantiate()
	
	object.global_transform = tform
	
	items.add_child(object)
