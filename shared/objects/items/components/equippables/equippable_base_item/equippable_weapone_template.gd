class_name EquippableWeaponeTemplate extends EquippableItemTemplate

@onready var hit_check_marker: Marker2D = $HitCheckMarker

var weapon_item_resource: WeaponItemResource


func _ready() -> void:
	owner_player = MatchState.find_owner_player(self)
	hit_check_marker.position.x += weapon_item_resource.range_weapon


func change_energy() -> void:
	if not is_owner_local():
		return
	
	EventSystem.PLA_change_energy.emit(owner_player, weapon_item_resource.energy_change_pre_use)


## Урон считает сервер: сюда приходит только намерение ударить.
## У чужой копии оружия анимация тоже играет, но удар отсюда не уходит.
func check_hit() -> void:
	if not is_owner_local():
		return
	
	WorldSync.request_hit(
		global_position,
		hit_check_marker.global_position,
		weapon_item_resource.item_key
	)
