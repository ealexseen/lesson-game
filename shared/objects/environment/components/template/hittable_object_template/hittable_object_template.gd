class_name HittableObjectTemplate extends Node2D

@export var attributes : HittableObjectAttributes

@onready var item_spawn_points: Node2D = %ItemSpawnPoints
@onready var hitbox: Hitbox = %Hitbox

var current_health : float


func _ready() -> void:
	current_health = attributes.max_health
	
	hitbox.register_hit.connect(register_hit)


func register_hit(weapon_item_resource: WeaponItemResource) -> void:
	print(weapon_item_resource)
	
	if not attributes.weapon_filter.is_empty() and not weapon_item_resource.item_key in attributes.weapon_filter:
		return
	
	current_health -= weapon_item_resource.damage
	
	if current_health <= 0:
		die()


func die() -> void:
	var scene_to_spawn = ItemConfig.get_pickuppable_item(attributes.drop_item_key)
	
	for marker in item_spawn_points.get_children():
		if marker is Node2D:
			EventSystem.SPA_spawn_scene.emit(scene_to_spawn, marker.global_transform)
	
	queue_free()
