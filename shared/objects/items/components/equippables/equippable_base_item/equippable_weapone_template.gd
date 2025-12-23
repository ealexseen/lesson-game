class_name EquippableWeaponeTemplate extends EquippableItemTemplate

@onready var hit_check_marker: Marker2D = $HitCheckMarker

var weapon_item_resource: WeaponItemResource


func _ready() -> void:
	hit_check_marker.position.x += weapon_item_resource.range


func change_energy() -> void:
	EventSystem.PLA_change_energy.emit(weapon_item_resource.energy_change_pre_use)


func check_hit() -> void:
	var from = global_position
	var to = hit_check_marker.global_position
	
	# debug
	#var line := Line2D.new()
	#line.add_point(from)
	#line.add_point(to)
	#line.width = 2.0
	#line.default_color = Color.RED
	
	#get_tree().current_scene.add_child(line)
	
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 64
	query.from = from
	query.to = to
	
	var result := space_state.intersect_ray(query)
	
	if not result.is_empty():
		result.collider.take_hit(weapon_item_resource)
		
	##debug
	#await get_tree().create_timer(3.0).timeout
	#line.queue_free()
