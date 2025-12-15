class_name EquippableWeaponeTemplate extends EquippableItemTemplate

@onready var hit_check_marker: Marker2D = $HitCheckMarker

var weapon_item_resource: WeaponItemResource


func _ready() -> void:
	hit_check_marker.position.x = weapon_item_resource.range


func check_hit() -> void:
	var space_state := get_world_2d().direct_space_state
	var ray_query_params := PhysicsRayQueryParameters2D.new()
	ray_query_params.collide_with_areas = true
	ray_query_params.collide_with_bodies = false
	ray_query_params.collision_mask = 7
	ray_query_params.from = global_position
	ray_query_params.to = hit_check_marker.global_position
	
	var result := space_state.intersect_ray(ray_query_params)
	
	if not result.is_empty():
		result.collider.take_hit(weapon_item_resource)
