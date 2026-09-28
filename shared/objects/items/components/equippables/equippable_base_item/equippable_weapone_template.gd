class_name EquippableWeaponeTemplate extends EquippableItemTemplate

@onready var hit_check_marker: Marker2D = $HitCheckMarker

var owner_player: Player
var weapon_item_resource: WeaponItemResource


func _ready() -> void:
	owner_player = MatchState.find_owner_player(self)
	hit_check_marker.position.x += weapon_item_resource.range_weapon


func change_energy() -> void:
	EventSystem.PLA_change_energy.emit(owner_player, weapon_item_resource.energy_change_pre_use)


## Урон считает сервер: сюда приходит только намерение ударить.
func check_hit() -> void:
	WorldSync.request_hit(
		global_position,
		hit_check_marker.global_position,
		weapon_item_resource.item_key
	)
