extends Node2D

## Спавн объектов мира: создаёт предмет сервер, остальные получают копию.
## Имя узла детерминировано (Item_<id>), иначе пути разъедутся и предмет
## нельзя будет убрать у всех разом.

@onready var items: Node2D = $Items


func _enter_tree() -> void:
	EventSystem.SPA_spawn_scene.connect(on_spawn_scene)


func on_spawn_scene(scene: PackedScene, tform: Transform2D) -> void:
	if scene == null or not WorldSync.is_server():
		return
	
	var spawn_id := WorldSync.next_spawn_id()
	var scene_path := scene.resource_path
	WorldSync.register_spawn(spawn_id, scene_path, tform)
	_instantiate(spawn_id, scene_path, tform)
	
	if NetworkManager.is_connected_to_game():
		rpc("_spawn_remote", spawn_id, scene_path, tform)


@rpc("authority", "call_remote", "reliable")
func _spawn_remote(_spawn_id: int, _scene_path: String, _tform: Transform2D) -> void:
	_instantiate(_spawn_id, _scene_path, _tform)


## Восстановление предмета из снапшота мира (поздний вход).
func restore_spawn(_spawn_id: int, _scene_path: String, _tform: Transform2D) -> void:
	_instantiate(_spawn_id, _scene_path, _tform)


func _instantiate(_spawn_id: int, _scene_path: String, _tform: Transform2D) -> void:
	var scene: PackedScene = load(_scene_path)
	
	if scene == null:
		return
	
	var object: Node2D = scene.instantiate()
	object.name = "Item_%d" % _spawn_id
	object.global_transform = _tform
	items.add_child(object)
