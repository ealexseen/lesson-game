class_name Hitbox extends Area2D


signal register_hit


func take_hit(weapon_item_resource: WeaponItemResource) -> void:
	register_hit.emit(weapon_item_resource)
