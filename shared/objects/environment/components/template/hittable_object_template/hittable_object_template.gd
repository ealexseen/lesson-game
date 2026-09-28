class_name HittableObjectTemplate extends Node2D

@export var attributes : HittableObjectAttributes

@onready var item_spawn_points: Node2D = %ItemSpawnPoints
@onready var hitbox: Hitbox = %Hitbox
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var current_health : float


func _ready() -> void:
	current_health = attributes.max_health
	
	hitbox.register_hit.connect(register_hit)


## Урон применяет только сервер: клиентам приходит готовый результат.
func register_hit(weapon_item_resource: WeaponItemResource) -> void:
	if not WorldSync.is_server():
		return
	if is_queued_for_deletion():
		return # уже сломан в этом кадре, второй раз лут не сыпем
	
	if not attributes.weapon_filter.is_empty() and not weapon_item_resource.item_key in attributes.weapon_filter:
		return
	
	current_health -= weapon_item_resource.damage
	
	if current_health <= 0:
		die()
		return
	
	if NetworkManager.is_connected_to_game():
		rpc("_play_hit_remote")
	
	_play_hit()


func _play_hit() -> void:
	if animation_player.is_playing():
		return
	
	animation_player.play("hit")


@rpc("authority", "call_remote", "reliable")
func _play_hit_remote() -> void:
	_play_hit()


## Сломанный объект: сервер рассылает лут, остальные просто убирают копию.
func die() -> void:
	var scene_to_spawn := ItemConfig.get_pickuppable_item(attributes.drop_item_key)
	
	if scene_to_spawn != null:
		for marker in item_spawn_points.get_children():
			if marker is Node2D:
				EventSystem.SPA_spawn_scene.emit(scene_to_spawn, marker.global_transform)
	
	WorldSync.mark_dead(self)
	queue_free()


## Приказ сервера: лут придёт отдельным спавном, спавнить его самим нельзя.
func apply_remote_death() -> void:
	queue_free()
