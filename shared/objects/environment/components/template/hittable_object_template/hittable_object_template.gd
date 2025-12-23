class_name HittableObjectTemplate extends Node2D

@export var attributes : HittableObjectAttributes

@onready var item_spawn_points: Node2D = %ItemSpawnPoints
@onready var hitbox: Hitbox = %Hitbox
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var current_health : float


func _ready() -> void:
	current_health = attributes.max_health
	
	hitbox.register_hit.connect(register_hit)


func register_hit(weapon_item_resource: WeaponItemResource) -> void:
	if not attributes.weapon_filter.is_empty() and not weapon_item_resource.item_key in attributes.weapon_filter:
		return
	
	current_health -= weapon_item_resource.damage
	
	if current_health <= 0:
		die()
	else:
		if animation_player.is_playing():
			return
		
		animation_player.play("hit")


func die() -> void:
	var scene_to_spawn = ItemConfig.get_pickuppable_item(attributes.drop_item_key)
	
	for marker in item_spawn_points.get_children():
		if marker is Node2D:
			EventSystem.SPA_spawn_scene.emit(scene_to_spawn, marker.global_transform)
	
	queue_free()
