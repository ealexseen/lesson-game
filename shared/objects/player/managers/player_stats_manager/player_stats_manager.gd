extends Node

const MAX_ENERGY = 100.0
const MAX_HEALTH = 100.0
const MAX_MANA = 20.0

var current_energy = MAX_ENERGY
var current_health = MAX_HEALTH
var current_mana = MAX_MANA


func _enter_tree() -> void:
	EventSystem.PLA_change_energy.connect(on_change_energy)
	EventSystem.PLA_change_health.connect(on_change_health)
	EventSystem.PLA_change_mana.connect(on_change_mana)
	
	# emit data
	EventSystem.PLA_updated_energy.emit(MAX_ENERGY, current_energy)
	EventSystem.PLA_updated_health.emit(MAX_HEALTH, current_health)
	EventSystem.PLA_updated_mana.emit(MAX_MANA, current_mana)


func on_change_energy(value: float) -> void:
	current_energy += value
	
	if current_energy < 0:
		on_change_health(current_energy)
	
	current_energy = clampf(current_energy, 0, MAX_ENERGY)
	
	EventSystem.PLA_updated_energy.emit(MAX_ENERGY, current_energy)


func on_change_health(value: float) -> void:
	current_health = clampf(current_health + value, 0, MAX_HEALTH)
	
	EventSystem.PLA_updated_health.emit(MAX_HEALTH, current_health)


func on_change_mana(value: float) -> void:
	current_mana = clampf(current_mana + value, 0, MAX_MANA)
	
	EventSystem.PLA_updated_mana.emit(MAX_MANA, current_mana)
